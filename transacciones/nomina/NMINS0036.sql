DROP TABLE IF EXISTS aux_parametros_update;
CREATE TEMP TABLE aux_parametros_update AS 
SELECT
	'?'::bigint AS ndocumento,
	'?'::varchar AS cc;

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
		salario_minimo,
		salario_basico,
		id_division_nomina
	)
SELECT
	a.ndocumento,
	foo.id_tercero,
	106 AS id_concepto_causacion, --SALARIO ESCALA 01 VTAS solo se pone para que los reportes se puedan generar
	3027 AS id_cta_debito,
	2902 AS id_cta_credito,
	foo.id_tercero AS id_tercero_debito,
	foo.id_tercero AS id_tercero_credito,
	0 AS valor,
	30 AS dias,
	sm.salario_minimo,
	sm.salario_minimo,
	di.id_division_nomina
FROM
	(SELECT DISTINCT
		id_division_nomina
	FROM
		causacion_nomina cn,
	 	aux_parametros_update a
	WHERE
	 	a.ndocumento = cn.ndocumento) AS di,
	(SELECT
		valor AS salario_minimo
	FROM
		concepto_causacion cc
	WHERE
		id_concepto_causacion = 1) AS sm,
	(SELECT DISTINCT
		cn.id_tercero
	FROM
		causacion_nomina cn,
		aux_parametros_update a
	WHERE
		cn.ndocumento = a.ndocumento
	GROUP BY
		id_tercero
	EXCEPT
	SELECT DISTINCT
		cn.id_tercero
	FROM
		causacion_nomina cn,
		concepto_causacion cc,
		aux_parametros_update a
	WHERE
		cn.id_concepto_causacion = cc.id_concepto_causacion AND
		cc.id_movimiento_nomina = 1 AND
		cc.id_clasificacion_concepto_causacion = 1 AND
		cn.ndocumento = a.ndocumento) AS foo,
	aux_parametros_update a;