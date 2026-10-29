-- LCSEL0168 — Recibos de caja efectivo por almacén (resumen por host/cajero)
--
-- Para los documentos del día que todavía no fueron incluidos en un arqueo
-- activo del codigo_tipo input, agrupa por host/IP del terminal, cajero,
-- ubicación y serial, devolviendo cantidad de documentos y valor total.
-- Usada en el formulario MTR00238.
--
-- Mismo pipeline que LCSEL0166/0167 pero sin aux_medios/aux_tarjetas —
-- el SELECT final hace joins directos a datos_documento, info_documento,
-- usuarios, documentos, registro_modificacion y equipos_registrados.
--
-- Optimización 2026-10-28 — Phase 1 (tres cambios, semántica idéntica):
--
--   A) `d.fecha::date = a.fecha` -> rango de timestamp en aux_docs.
--   B) `ANALYZE <temp_table>` después de cada CREATE TEMP TABLE
--      (ver [[feedback-analyze-temp-tables]]).
--   C) `arqueo_except` EXCEPT -> `(SELECT 1 ... LIMIT 1) IS NULL` escalar.
--
-- Compatible con PG 9.5.

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::DATE AS fecha;
ANALYZE args_arqueo_medios;

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

-- Phase 1 (2026-10-28): fecha::date = a.fecha -> rango timestamp.
DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	d.ndocumento
from
	args_arqueo_medios a,
	tipo_docs t,
	documentos d
WHERE
	d.fecha >= a.fecha::timestamp AND
	d.fecha <  a.fecha::timestamp + INTERVAL '1 day' AND
	d.codigo_tipo = t.codigo_tipo ; -- Solo tipos documento fac, fac credito y cambios
ANALYZE aux_docs;

-- Phase 1 (2026-10-28): EXCEPT -> subquery escalar con LIMIT 1.
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

SELECT
	COALESCE(e.host,r.ip) AS host,
	u.login,
	COALESCE(e.ubicacion,'NA') AS ubicacion,
	COALESCE(e.serial,'NA') AS serial,
	count(1),
	sum(dd.valor) AS valor
FROM
	datos_documento dd,
	info_documento i,
	usuarios u,
	documentos d,
	arqueo_except ae,
	registro_modificacion r
LEFT OUTER JOIN
	equipos_registrados e
ON
	e.ip=r.ip
WHERE
	dd.ndocumento=d.ndocumento AND
	d.ndocumento=i.ndocumento and
	d.estado and
	i.id_usuario=u.id_usuario AND
	r.ndocumento=d.ndocumento AND
	r.id_tipo_modificacion=0 AND
	d.ndocumento = ae.ndocumento
GROUP BY
	COALESCE(e.host,r.ip),
	u.login,
	e.ubicacion,
	e.serial
ORDER BY
	COALESCE(e.host,r.ip),
	u.login;
