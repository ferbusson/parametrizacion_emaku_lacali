DROP TABLE IF EXISTS args_arqueo;
CREATE TEMP TABLE args_arqueo AS
SELECT
	d.codigo_tipo,
	f.narqueo,
	u.id_usuario,
	f.id_centrocosto
FROM
	documentos d,
	usuarios u,
	(SELECT
		'?'::BIGINT AS narqueo,
		'?'::VARCHAR(70) AS login,
		'?'::SMALLINT AS id_centrocosto) AS f
WHERE
	u.login=f.login AND
	d.ndocumento=f.narqueo;


-- codigo_tipo_arqueos se usa para exceptuar los documentos que un usuario puede tener en arqueos de otras sucursales
-- ademas de los documentos que se generaron en su sucursal actual
-- lo anterior porque hay usuarios que pueden rotar entre sucursales, como por ejemplo los de
-- sucursal online y principal se debe buscar la forma de mejorarlo
/*
tal vez se puede obviar y poner los prefijos de todos los arqueos en la segunda parte del except y hacer que se tenga 
en cuenta al usuario en esta parte
*/

DROP TABLE IF EXISTS codigo_tipo_arqueos;
CREATE TEMP TABLE codigo_tipo_arqueos as
SELECT DISTINCT
	td.codigo_tipo
from 
	tipo_documento td
where 
	codigo_tipo like 'Q%';

/*
SELECT DISTINCT
	d.codigo_tipo
FROM
	documentos d,
	info_documento i,
	datos_arqueo da,
	args_arqueo a
WHERE
	d.ndocumento = i.ndocumento and
	d.estado and
	i.id_usuario = a.id_usuario AND
	da.narqueo = d.ndocumento;*/





	

DROP TABLE IF EXISTS codigo_tipo_documentos_sucursal_usuario;
CREATE TEMP TABLE codigo_tipo_documentos_sucursal_usuario AS
SELECT DISTINCT
	ds.codigo_tipo
FROM
	args_arqueo a,
	documentos_standar dst,
	documentos_sucursales ds,
	administracion_sucursales asu
WHERE
	asu.id_centrocosto = a.id_centrocosto AND
	asu.id_administracion_sucursales = ds.id_administracion_sucursales AND
	ds.id_documento = dst.id_documento;

--

INSERT INTO 
	datos_arqueo(
			narqueo,
			ndocumento,
			valor
			) 
SELECT
	a.narqueo,
        d.ndocumento,
        COALESCE(dd.valor,0) AS valor
FROM
	args_arqueo a,		
        documentos d, 
        datos_documento dd, 
        info_documento i,
	(SELECT
		d.ndocumento
	FROM
		documentos d,
	 	codigo_tipo_documentos_sucursal_usuario ctu,
		info_documento i,
		args_arqueo a
	WHERE
	 	d.codigo_tipo = ctu.codigo_tipo AND
		d.ndocumento=i.ndocumento AND
		i.id_usuario=a.id_usuario AND
		d.estado
	EXCEPT
	SELECT
		da.ndocumento
	FROM
		datos_arqueo da,
		documentos d,
		info_documento i,
		args_arqueo a,
		codigo_tipo_arqueos cta
	WHERE
		d.codigo_tipo=cta.codigo_tipo AND
		da.narqueo=d.ndocumento and
		da.narqueo = i.ndocumento and 
		i.id_usuario=a.id_usuario AND
		d.estado) AS foo
WHERE
        d.ndocumento=dd.ndocumento AND
        d.ndocumento=i.ndocumento AND
        d.estado AND
		d.codigo_tipo !=a.codigo_tipo AND
        i.id_usuario=a.id_usuario AND
        d.ndocumento=foo.ndocumento;


-- INICIA INSERCION CONTABILIZACIÓN ARQUEO

-- SUMA RETIROS PARCIALES - RECOGIDAS
DROP TABLE IF EXISTS suma_retiros_parciales;
CREATE TEMP TABLE suma_retiros_parciales AS
SELECT
	COALESCE(SUM(dd.valor),0) AS valor
FROM
	documentos d,
	args_arqueo a,
	datos_arqueo da,
	datos_documento dd,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	a.narqueo = da.narqueo AND
	da.ndocumento = d.ndocumento AND
	d.codigo_tipo = ds.codigo_tipo AND
	d.ndocumento = dd.ndocumento AND
	ds.id_documento = dst.id_documento AND
	dst.nombre = 'RETIRO PARCIAL';

-- SUMA ENTREGAS DE BASE SENCILLA
DROP TABLE IF EXISTS suma_base_sencilla;
CREATE TEMP TABLE suma_base_sencilla AS
SELECT
	COALESCE(SUM(dd.valor),0) AS valor
FROM
	documentos d,
	args_arqueo a,
	datos_arqueo da,
	datos_documento dd,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	a.narqueo = da.narqueo AND
	da.ndocumento = d.ndocumento AND
	d.codigo_tipo = ds.codigo_tipo AND
	d.ndocumento = dd.ndocumento AND
	ds.id_documento = dst.id_documento AND
	dst.nombre = 'ENTREGA BASE SENCILLA';


DROP TABLE IF EXISTS suma_devoluciones_venta;
CREATE TEMP TABLE suma_devoluciones_venta AS
SELECT
	COALESCE(SUM(l.haber),0) AS valor -- Aqui solo se tienen en cuenta las devs que se hicieron en efectivo, en el anterior podian ser a credito y genero error en los calculos
FROM
	documentos d,
	args_arqueo a,
	datos_arqueo da,
	libro_auxiliar l,
	cuentas cu,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	a.narqueo = da.narqueo AND
	da.ndocumento = d.ndocumento AND
	d.codigo_tipo = ds.codigo_tipo AND
	d.ndocumento = l.ndocumento AND
	l.id_cta = cu.id_cta AND
	cu.char_cta = '11053501' AND
	ds.id_documento = dst.id_documento AND
	dst.nombre IN ('DEVOLUCION VENTA','DVENTA ELECTRONICA');

-- SUMA DOCUMENTOS EN EFECTIVO
DROP TABLE IF EXISTS suma_documentos_efectivo;
CREATE TEMP TABLE suma_documentos_efectivo AS
SELECT
	foo.valor-sdv.valor-srp.valor AS valor
FROM
	suma_retiros_parciales srp,
	suma_devoluciones_venta sdv,
	(select
		COALESCE(SUM(l.debe),0) AS valor
	FROM
		cuentas cu,
		args_arqueo a,
		datos_arqueo da,
		datos_documento dd, -- la pongo para evitar documentos no POS
		libro_auxiliar l
	WHERE
		a.narqueo = da.narqueo AND
		da.ndocumento = l.ndocumento AND
		da.ndocumento = dd.ndocumento AND
		l.id_cta = cu.id_cta AND
		cu.char_cta = '11053501' AND -- bigpass
		l.debe != 0) AS foo;


-- VALOR EFECTIVO ENTREGADO POR EL CAJERO
DROP TABLE IF EXISTS efectivo_entregado;
CREATE TEMP TABLE efectivo_entregado AS
SELECT
	e."100000"+e."50000"+e."20000"+e."10000"+e."5000"+e."2000"+e."1000"+e.monedas+
	((e."100"+e."50"+e."20"+e."10"+e."5"+e."1"+e.monedasd)*e.trm) AS valor
FROM
	args_arqueo a,
	efectivo e
WHERE
	a.narqueo = e.narqueo;

-- CONTRAPARTIDA ENTREGA BASE SENCILLA

INSERT INTO
	libro_auxiliar(
		id_cta,
		id_centrocosto,
		id_tercero,
		fecha,
		detalle,
		ndocumento,
		debe,
		haber)		
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'CONTRAPARTIDA ENTREGA BASE SENCILLA' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(s.valor,0.0) > 0 THEN COALESCE(s.valor,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(s.valor,0.0) < 0 THEN -1*COALESCE(s.valor,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	suma_base_sencilla s
WHERE 
	cu.char_cta = '11051502' AND
	s.valor != 0
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'CONTRAPARTIDA ENTREGA BASE SENCILLA' AS detalle,
	a.narqueo AS ndocumento,
	--0.0 AS debe,
	--COALESCE(s.valor,0.0) AS haber
	CASE WHEN COALESCE(s.valor,0.0) < 0 THEN -1*COALESCE(s.valor,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(s.valor,0.0) > 0 THEN COALESCE(s.valor,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	suma_base_sencilla s
WHERE 
	cu.char_cta = '11051501' AND
	s.valor != 0;

--

DROP TABLE IF EXISTS unificacion_totales;
CREATE TEMP TABLE unificacion_totales AS
SELECT
	COALESCE(e.valor,0.0) AS documentos_en_efectivo,
	COALESCE(s.valor,0.0) AS sencilla,
	COALESCE(r.valor,0.0) AS recogida,
	COALESCE((e.valor+s.valor),0.0) AS total_registrado,
	COALESCE(ee.valor,0.0) AS efectivo_entregado,
	COALESCE((ee.valor - (e.valor+s.valor)),0) AS diferencia
FROM
	suma_documentos_efectivo e,
	suma_base_sencilla s,
	suma_retiros_parciales r,
	efectivo_entregado ee,
	suma_devoluciones_venta dv;

-- TRANSFERENCIA EFECTIVO

INSERT INTO
	libro_auxiliar(
		id_cta,
		id_centrocosto,
		id_tercero,
		fecha,
		detalle,
		ndocumento,
		debe,
		haber)
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'TRANSFERENCIA EFECTIVO A TESORERIA' AS detalle,
	a.narqueo AS ndocumento,
	--0.0 AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053501'
	
-- SI EL ARQUEO CUADRO EXACTO
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'TRANSFERENCIA EFECTIVO A TESORERIA' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.documentos_en_efectivo,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia = 0
UNION
-- REGISTRO SOBRANTE
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	g.id AS id_tercero,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO SOBRANTE' AS detalle,
	a.narqueo AS ndocumento,
	--0.0 AS debe,
	CASE WHEN COALESCE(ut.diferencia,0.0) < 0 THEN -1*COALESCE(ut.diferencia,0.0) ELSE 0.0 END AS debe,
	CASE WHEN COALESCE(ut.diferencia,0.0) > 0 THEN COALESCE(ut.diferencia,0.0) ELSE 0.0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	general g,
	unificacion_totales ut
WHERE 
	g.id_char = '222222222222' AND
	cu.char_cta = '429553' AND
	ut.diferencia > 0
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO SOBRANTE' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.diferencia+documentos_en_efectivo,0.0) > 0 THEN COALESCE(ut.diferencia+documentos_en_efectivo,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.diferencia+documentos_en_efectivo,0.0) < 0 THEN -1*COALESCE(ut.diferencia+documentos_en_efectivo,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia > 0

-- REGISTRO FALTANTE SUPERIOR A 100 PESOS
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE SUPERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia*-1 > 100 AND
	ut.total_registrado+diferencia != 0
UNION
SELECT -- Agregado Junio 08 2023: cuando el faltante es igual al total_registrado el movimiento 11053502 se registra en el haber, caso especial complementa el registro anterior
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE SUPERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia*-1 > 100 AND
	ut.total_registrado+diferencia = 0
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE SUPERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.diferencia*-1,0.0) > 0 THEN COALESCE(ut.diferencia*-1,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.diferencia*-1,0.0) < 0 THEN -1*COALESCE(ut.diferencia*-1,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '13653001' AND
	ut.diferencia*-1 > 100

-- REGISTRO FALTANTE INFERIOR A 100 PESOS
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE INFERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia*-1 > 0 AND	
	ut.diferencia*-1 <= 100 AND
	ut.total_registrado+diferencia != 0
	
-- REGISTRO FALTANTE INFERIOR A 100 PESOS con diferencia = 0
-- Agregado Diciembre 18 2024: cuando el faltante es igual al total_registrado el movimiento 11053502 se registra en el haber, caso especial complementa el registro anterior
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE INFERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) > 0 THEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.documentos_en_efectivo+diferencia,0.0) < 0 THEN -1*COALESCE(ut.documentos_en_efectivo+diferencia,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '11053502' AND
	ut.diferencia*-1 > 0 AND	
	ut.diferencia*-1 <= 100 AND
	ut.total_registrado+diferencia = 0
UNION
SELECT 
	cu.id_cta,
	a.id_centrocosto,
	g.id AS id_tercero,
	CURRENT_TIMESTAMP AS fecha,
	'REGISTRO FALTANTE INFERIOR A 100' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN COALESCE(ut.diferencia*-1,0.0) > 0 THEN COALESCE(ut.diferencia*-1,0.0) ELSE 0 END AS debe,
	CASE WHEN COALESCE(ut.diferencia*-1,0.0) < 0 THEN -1*COALESCE(ut.diferencia*-1,0.0) ELSE 0 END AS haber
FROM 	
	args_arqueo a,
	cuentas cu,
	general g,
	unificacion_totales ut
WHERE 
	g.id_char = '222222222222' AND
	cu.char_cta = '539581' AND
	ut.diferencia*-1 > 0 AND
	ut.diferencia*-1 <= 100;
	
-- insercion de faltantes mayores a 100 en cartera

INSERT INTO
	cartera(
		idtercero,
		nfactura,
		dcredito,
		neto_factura,
		total_factura,
		movimiento,
		id_cta
		)
SELECT 
	a.id_usuario,
	a.narqueo AS nfactura,
	0::INTEGER AS dcredito,
	COALESCE(ut.diferencia*-1,0.0) AS neto_factura,
	COALESCE(ut.diferencia*-1,0.0) AS total_factura,
	TRUE AS movimiento,
	cu.id_cta
FROM 	
	args_arqueo a,
	cuentas cu,
	unificacion_totales ut
WHERE 
	cu.char_cta = '13653001' AND
	ut.diferencia*-1 > 100;