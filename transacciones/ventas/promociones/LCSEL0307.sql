SELECT
	FALSE,
	'PRINCIPAL' AS descripcion,
	'F1' as codigo_tipo	
UNION
SELECT
	FALSE,
	'LAS CUADRAS' AS descripcion,
	'F3' as codigo_tipo	
UNION
SELECT
	FALSE,
	'UNICO' AS descripcion,
	'F4' as codigo_tipo	
UNION
SELECT
	FALSE,
	'GRAN PLAZA' AS descripcion,
	'F5' as codigo_tipo	
ORDER BY
	codigo_tipo;