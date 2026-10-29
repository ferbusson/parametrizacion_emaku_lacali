-- La combinación de estos reportes permiten detectar algun descuadre en los documentos generados en la fecha, para revisar:
-- 1 buscar documentos sin partida doble
-- 2 comparar aux_docs entre las dos consultas, deben tener el mismo numero de documentos
-- 3 buscar el documento problema con limit para reducir el numero de documentos hasta detectar en qué documento se descuadra

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::CHARACTER(2) AS codigo_tipo,
	'?'::DATE AS fecha;


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


DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	d.ndocumento
from
	args_arqueo_medios a,
	tipo_docs t,
	documentos d
WHERE
	d.fecha::date = a.fecha and
	d.codigo_tipo = t.codigo_tipo ; -- Solo tipos documento fac, fac credito y cambios


DROP TABLE IF EXISTS arqueo_except;
CREATE TEMP TABLE arqueo_except AS
SELECT distinct
	ad.ndocumento
FROM
	aux_docs ad
EXCEPT
SELECT DISTINCT
	da.ndocumento
FROM
	datos_arqueo da,
	documentos d,
	args_arqueo_medios a
WHERE
	d.codigo_tipo=a.codigo_tipo AND
	da.narqueo=d.ndocumento AND
	d.estado;


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