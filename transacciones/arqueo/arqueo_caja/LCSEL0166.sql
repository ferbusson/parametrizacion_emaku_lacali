-- LCSEL0166 — Datos de un informe diario (resumen de ventas por concepto)
--
-- Suma `libro_auxiliar.haber - libro_auxiliar.debe` por grupo de cuentas
-- (mercancía excluida, exenta, gravada 5%/19%, IVA, INC, retenciones...) para
-- los documentos del día que aún no fueron incluidos en un arqueo activo
-- del codigo_tipo input. Usada en el formulario MTR00238 "Nuevo informe
-- diario de facturación por almacén".
--
-- Más simple que LCSEL0164/0177 — no usa `tipo_arqueo` ni `datos_arqueo_ok`,
-- construye `aux_docs` directo desde documentos (sin filtro `estado`) y
-- hace EXCEPT contra arqueos del codigo_tipo input.
--
-- Optimización 2026-10-28 — Phase 1 (tres cambios, semántica idéntica):
--
--   A) `d.fecha::date = a.fecha` -> rango de timestamp en aux_docs
--      (igual que LCSEL0164 Phase 1).
--
--   B) `ANALYZE <temp_table>` después de cada CREATE TEMP TABLE
--      (ver [[feedback-analyze-temp-tables]]).
--
--   C) `arqueo_except` EXCEPT -> `(SELECT 1 ... LIMIT 1) IS NULL` escalar
--      (patrón confirmado en LCSEL0177: driver = aux_docs pequeño,
--      nested-loop por idx_datos_arqueo_ndocumento, dev 7.5x más rápido).
--
-- Las 9 ramas UNION en `ventas_ok` (una por grupo de cuentas) quedan
-- intactas — son cleanup, no performance. Podrían colapsarse en una sola
-- query con CASE en Phase 2 si fuera necesario.
--
-- Compatible con PG 9.5.

-- La combinación de estos reportes permiten detectar algun descuadre en los documentos generados en la fecha, para revisar:
-- 1 buscar documentos sin partida doble
-- 2 comparar aux_docs entre las dos consultas, deben tener el mismo numero de documentos
-- 3 buscar el documento problema con limit para reducir el numero de documentos hasta detectar en qué documento se descuadra

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::CHARACTER(2) AS codigo_tipo,
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
-- Driver aux_docs + nested-loop por idx_datos_arqueo_ndocumento.
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


DROP TABLE IF EXISTS error_msg_proveedor;
CREATE TEMP TABLE error_msg_proveedor AS
SELECT
	1
FROM
	(SELECT
		error_text('El informe diario para la fecha seleccionada ya fue generado')
	FROM
		(SELECT
			COUNT(1) AS c
		FROM
			arqueo_except
		HAVING
			COUNT(1) = 0) AS foo) AS foo;


DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	l.*
FROM
	libro_auxiliar l,
	arqueo_except ae
WHERE
	l.ndocumento=ae.ndocumento;
ANALYZE aux_medios;


DROP TABLE IF EXISTS ventas_ok;
CREATE TEMP TABLE ventas_ok AS
SELECT
	orden,
	concepto,
	valor
FROM
	(SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		1::INT as orden,
		'Mercancia Excluida'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta IN ('41355610','41755610')
		HAVING
			SUM(haber)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		2::INT as orden,
		'Mercancia Exenta'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta  IN ('41355615','41755615')
		HAVING
			SUM(haber)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		3::INT as orden,
		'Mercancia Gravada 5%'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta  IN ('4135560501','4175560501')
		HAVING
			SUM(haber)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		4::INT as orden,
		'Mercancia Gravada al 19%'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta IN ('4135560502','4175560502')
		HAVING
			SUM(haber)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		5::INT as orden,
		'Servicios Gravados 19%'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta ='4135562001'
		HAVING
			SUM(haber)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		6::INT as orden,
		'Impuesto sobre el valor agregado - IVA  5%'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta  in ('24080501','24081005') -- VENTAS Y DEV EN VENTAS
		HAVING
			SUM(haber)-SUM(debe)!=0
		) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		7::INT as orden,
		'Impuesto sobre el valor agregado - IVA  19%'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			SUM(haber)-SUM(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta IN ('24080502','24081006')
		HAVING
			SUM(haber)-SUM(debe)!=0) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		8::INT as orden,
		'INC Bolsas Plasticas'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			c.char_cta ='240905') AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(valor,0) AS valor
	FROM
	(SELECT
		9::INT as orden,
		'Retenciones que nos Practicaron'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta AND
			(c.char_cta like ('135515%') or --Junio 16 2025: pongo el ilike para no tener añadir cuentas de retencion nuevas, filtro anterior c.char_cta in ('13551501','13551502','13551503','135517','135518')
			c.char_cta in ('135517','135518'))
		--HAVING comentado Feb 27 2025 para evitar descuadre fac G1-59417 que tuvo retenciones
			--SUM(haber)!=0
			) AS f
	ON
		true) AS f;

SELECT
	concepto,
	valor
	--ROUND(valor::NUMERIC,0) AS valor
FROM
	ventas_ok
ORDER BY
	orden;
