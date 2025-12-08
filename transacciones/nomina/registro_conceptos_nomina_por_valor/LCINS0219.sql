with aux_parametros_insercion as (
SELECT
	'?'::BIGINT AS ndocumento,
	'?'::CHARACTER(14) AS id_char,
    '?'::float8 AS valor
)
/*	
DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('El número de identificación: ('||a.id_char||') no existe en el sistema. Revise el archivo excel por favor')
	FROM
	 	aux_parametros_insercion a
	WHERE NOT EXISTS
	 	(SELECT
			a.id_char
		FROM
			aux_parametros_insercion a,
		 	general g
		WHERE
		 	TRIM(a.id_char) = g.id_char)
			) AS foo;
*/
	
INSERT INTO
	importacion_desde_excel_empleados_valor(
		ndocumento,
		id_tercero,
		valor)
SELECT
	a.ndocumento,
	g.id,
	coalesce(a.valor, 0)
FROM
	aux_parametros_insercion a
INNER JOIN
	general g
ON
	TRIM(a.id_char) = g.id_char;