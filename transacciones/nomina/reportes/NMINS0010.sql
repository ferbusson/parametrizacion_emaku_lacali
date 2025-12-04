DROP TABLE IF EXISTS aux_parametros_causacion;
CREATE TEMP TABLE aux_parametros_causacion AS
SELECT
	'?'::BIGINT AS ndocumento,
	(SELECT id FROM general WHERE id_char = '?') AS id_tercero,
	'?'::INTEGER AS id_concepto_causacion,
	(select id_cta from cuentas where char_cta='?') AS id_cta_debito,
	(select id_cta from cuentas where char_cta='?') AS id_cta_credito,
	'?'::FLOAT8 AS id_tercero_debito,
	'?'::FLOAT8 AS id_tercero_credito,
	'?'::FLOAT8 AS valor,
    '?'::INTEGER AS dias,
	(SELECT valor FROM concepto_causacion WHERE id_concepto_causacion = 1) AS valor_salario_minimo;

INSERT INTO 
	causacion_nomina(
		ndocumento,
		id_tercero,
		id_concepto_causacion,
		id_cta_debito,
		id_cta_credito,
		id_tercero_debito,
		id_tercero_credito,
		valor,
		dias,
		id_division_nomina,
		salario_minimo,
		salario_basico)
SELECT
    foo.ndocumento,
	foo.id_tercero,
	foo.id_concepto_causacion,
	foo.id_cta_debito,
	foo.id_cta_credito,
	foo.id_tercero_debito::INTEGER,
	foo.id_tercero_credito::INTEGER,
	foo.valor,
    foo.dias,
	dd.id_division,
	CASE WHEN cc.id_clasificacion_concepto_causacion = 1 THEN foo.valor_salario_minimo ELSE 0.0 END AS salario_minimo,
	CASE WHEN cc.id_clasificacion_concepto_causacion = 1 THEN cc.valor ELSE 0.0 END AS salario_basico
FROM
	aux_parametros_causacion foo,
	datos_division dd,
	concepto_causacion cc
WHERE
	foo.id_tercero = dd.id_tercero AND
	foo.id_concepto_causacion = cc.id_concepto_causacion;