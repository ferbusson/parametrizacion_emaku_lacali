DROP TABLE IF EXISTS aux_parametros_01;
CREATE TEMP TABLE aux_parametros_01 AS
SELECT
	'?'::INTEGER AS ndocumento,
	'?'::TIMESTAMP AS fecha,
	'?'::CHARACTER(100) AS detalle,
	'?'::CHARACTER(4) AS centro,
	'?'::CHARACTER(4) AS scentro,
	'?'::CHARACTER(6) AS vinculo,
	'?'::INTEGER AS id_cta,
	'?'::INTEGER AS id_tercero,
	'?'::INTEGER AS id_prod_serv,
	'?'::BIGINT AS ndocumento_enlace,
	'?'::FLOAT8 AS debe,
	'?'::FLOAT8 AS haber,
	'?'::INTEGER AS id_activo,
	'?'::VARCHAR(30) AS ex_documento;
	
INSERT INTO 
	libro_auxiliar(
		ndocumento,
		fecha,
		detalle,
		id_centrocosto,
		id_scentrocosto,
		id_vinculo_movimiento,
		id_cta,
		id_tercero,
		id_prod_serv,
        ndocumento_enlace,
		debe,
		haber,
		id_activo,
		ex_documento
		)
SELECT
	a.ndocumento,
	a.fecha,
	a.detalle,
	cc.id_centrocosto,
	NULL AS id_scentrocosto,
	v.id_vinculo_movimiento,
	a.id_cta,
	a.id_tercero,
	a.id_prod_serv,
    a.ndocumento_enlace,
	a.debe,
	a.haber,
	a.id_activo,
	A.ex_documento
FROM
	aux_parametros_01 a
LEFT OUTER JOIN
	centrocosto cc
ON
	TRIM(a.centro) = cc.codigo
LEFT OUTER JOIN
	vinculo_movimientos v
ON	
	TRIM(a.vinculo) = v.codigo;