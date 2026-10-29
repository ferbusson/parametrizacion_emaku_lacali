-- LCSEL0177 — Arqueos correspondientes a informe diario
--
-- Lista los arqueos de un cajero que están pendientes de incluir en un
-- informe diario (devuelve fecha, numero, login, usuario, narqueo).
-- Usada en el formulario MTR00238 "Nuevo informe diario de facturación
-- por almacén".
--
-- Hermana estructural de LCSEL0164 — mismo set de temp tables de setup,
-- misma lógica de arqueo_except. Nota semántica: el informe reporta
-- documentos tipo ARQUEO (codigo_tipo en `tipo_arqueo`) de toda la
-- administracion_sucursales del tipo input, lo que coincide con el
-- scope de `tipo_arqueo` → agregar el filtro en `datos_arqueo_ok`
-- preserva la semántica.
--
-- Optimización 2026-10-28 — Phase 1 (cuatro cambios, semántica idéntica):
--
--   A) Agregar filtro `d.codigo_tipo = ta.codigo_tipo` a datos_arqueo_ok
--      (igual que LCSEL0164). En prod reduce el scan de 2.78M arqueos
--      a los del tipo correspondiente a la sucursal del input.
--
--   B) `d.fecha::date = a.fecha` -> rango de timestamp en aux_docs
--      (igual que LCSEL0164 Phase 1).
--
--   C) `ANALYZE <temp_table>` después de cada CREATE TEMP TABLE
--      (sin esto PG 9.5 asume 2040 filas default -> plan catastrófico;
--      ver [[feedback-analyze-temp-tables]]).
--
--   D) `arqueo_except` EXCEPT -> `(SELECT 1 ... LIMIT 1) IS NULL` escalar.
--      El EXCEPT original agregaba 1.3M filas (hash de todos los hijos
--      de arqueos del codigo_tipo). El LIMIT 1 scalar fuerza nested-loop
--      por `idx_datos_arqueo_ndocumento` con driver = aux_docs (~850 filas),
--      haciendo ~850 index-lookups rápidos. Dev: 158ms -> 21ms (7.5x).
--
-- Compatible con PG 9.5.

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::DATE AS fecha;
ANALYZE args_arqueo_medios;

DROP TABLE IF EXISTS tipo_arqueo;
CREATE TEMP TABLE tipo_arqueo AS
SELECT
	dv.codigo_tipo
FROM
	documentos_standar ds,
	administracion_sucursales ad,
	documentos_sucursales du,
	documentos_sucursales dv,
	args_arqueo_medios a
WHERE
	ds.id_documento=dv.id_documento AND
	dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
	ad.id_administracion_sucursales=du.id_administracion_sucursales AND
	du.codigo_tipo=a.codigo_tipo AND
	ds.nombre IN ('ARQUEO');
ANALYZE tipo_arqueo;

DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT
	dv.codigo_tipo
FROM
	documentos_standar ds,
	administracion_sucursales ad,
	documentos_sucursales du,
	documentos_sucursales dv,
	args_arqueo_medios a
WHERE
	ds.id_documento=dv.id_documento AND
	dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
	ad.id_administracion_sucursales=du.id_administracion_sucursales AND
	du.codigo_tipo=a.codigo_tipo AND
	ds.nombre IN ('FACTURACION','FCREDITO','CAMBIOS','FELECTRONICAPOS','FCONTINGENCIA','FCONTINGENCIAE');
ANALYZE tipo_docs;

-- Phase 1 (2026-10-28): agregado filtro `d.codigo_tipo = ta.codigo_tipo`
-- para no leer los 2.78M arqueos de todos los tipos en prod. El scope
-- de tipo_arqueo coincide con el del informe (administracion_sucursales
-- del codigo_tipo input), así que la semántica es idéntica.
DROP TABLE IF EXISTS datos_arqueo_ok;
CREATE TEMP TABLE datos_arqueo_ok AS
select
	da.narqueo,
	da.ndocumento
FROM
	datos_arqueo da,
	documentos d,
	tipo_arqueo ta
WHERE
	d.codigo_tipo = ta.codigo_tipo AND
	da.narqueo = d.ndocumento and
	d.estado;
ANALYZE datos_arqueo_ok;

-- Phase 1 (2026-10-28): fecha::date = a.fecha -> rango timestamp.
DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	COALESCE(da.narqueo,0) AS narqueo,
	da.ndocumento
from
	args_arqueo_medios a,
	tipo_arqueo t,
	tipo_docs td,
	datos_arqueo_ok da,
	documentos d, -- documento arqueo
	documentos d2 -- documentos del arqueo
WHERE
	d.estado AND
	d.fecha >= a.fecha::timestamp AND
	d.fecha <  a.fecha::timestamp + INTERVAL '1 day' AND
	d.codigo_tipo = t.codigo_tipo AND
	d.ndocumento = da.narqueo AND
	da.ndocumento = d2.ndocumento AND
	d2.codigo_tipo = td.codigo_tipo; -- Solo tipos documento fac, fac credito y cambios
ANALYZE aux_docs;



-- Phase 1 (2026-10-28): EXCEPT -> subquery escalar con LIMIT 1.
-- Driver aux_docs (~pequeño) + nested-loop por idx_datos_arqueo_ndocumento.
DROP TABLE IF EXISTS arqueo_except;
CREATE TEMP TABLE arqueo_except AS
SELECT DISTINCT ad.ndocumento
FROM   aux_docs ad
WHERE  (SELECT 1
          FROM datos_arqueo       da
          JOIN documentos         d  ON d.ndocumento = da.narqueo AND d.estado
          JOIN args_arqueo_medios a  ON a.codigo_tipo = d.codigo_tipo
         WHERE da.ndocumento = ad.ndocumento
         LIMIT 1) IS NULL;
ANALYZE arqueo_except;


SELECT DISTINCT
	d.fecha,
	d.codigo_tipo||'-'||d.numero::int AS numero,
	u.login,
	nombre1||' '||apellido1 as usuario,
	da.narqueo
FROM
	usuarios u,
	info_documento i,
	general g,
	documentos d,
	tipo_arqueo ta,
	arqueo_except foo,
	datos_arqueo da
WHERE
	da.ndocumento = foo.ndocumento AND
	da.narqueo = i.ndocumento AND
	i.id_usuario = u.id_usuario AND
	g.id = u.id_usuario AND
	d.ndocumento = da.narqueo AND
	d.codigo_tipo = ta.codigo_tipo
ORDER BY
	d.fecha,
	numero;
