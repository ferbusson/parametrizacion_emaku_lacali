DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::VARCHAR(10) AS numero;

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


DROP TABLE IF EXISTS arqueos_diarios;
CREATE TEMP TABLE arqueos_diarios AS
SELECT
	da.ndocumento
FROM
	documentos d,
	args_arqueo_medios a,
	datos_arqueo da
WHERE
	d.codigo_tipo=a.codigo_tipo AND
	d.numero=LPAD(a.numero,10,'0') AND
	d.ndocumento=da.narqueo;


DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	l.*
FROM
	documentos d,
	libro_auxiliar l,
	arqueos_diarios a,
	tipo_docs t
WHERE
	a.ndocumento=d.ndocumento AND
	d.codigo_tipo=t.codigo_tipo AND
	d.estado AND
	l.ndocumento=d.ndocumento;


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
			c.char_cta  in ('24080501','24081005')
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
			c.char_cta ='240905'
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
		9::INT as orden,
		'Retenciones que nos Practicaron'::VARCHAR(50) as concepto) AS c
	LEFT OUTER JOIN
		(SELECT
			sum(haber)-sum(debe) AS valor
		FROM
			aux_medios a,
			cuentas c
		WHERE
			c.id_cta=a.id_cta and
			(c.char_cta like ('135515%') or --Junio 16 2025: pongo el ilike para no tener añadir cuentas de retencion nuevas
			c.char_cta in ('135517','135518'))-- 
			) AS f
	ON
		true) AS f;

SELECT
	concepto,
	valor
FROM
	ventas_ok
ORDER BY
	orden;