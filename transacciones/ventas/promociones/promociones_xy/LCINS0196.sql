DROP TABLE IF EXISTS aux_parametros_insercion;
CREATE TEMP TABLE aux_parametros_insercion AS
SELECT
	'?'::BIGINT AS ndocumento,
	'?'::CHARACTER(14) AS codigo;
	
DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('El código: ('||a.codigo||') no existe en el sistema. Revise el archivo excel por favor')
	FROM
	 	aux_parametros_insercion a
	WHERE NOT EXISTS
	 	(SELECT
			a.codigo
		FROM
			aux_parametros_insercion a,
		 	prod_serv ps
		WHERE
		 	TRIM(a.codigo) = ps.codigo)
			) AS foo;

	
INSERT INTO
	datos_prod(
		ndocumento,
		id_prod_serv,
		cant)
SELECT
	a.ndocumento,
	ps.id_prod_serv,
	1::INTEGER AS cant
FROM
	aux_parametros_insercion a,
	prod_serv ps
WHERE
	TRIM(a.codigo) = ps.codigo;