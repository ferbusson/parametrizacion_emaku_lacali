--LCINS0222
DROP TABLE IF EXISTS temp_parametros_query;
CREATE TEMP TABLE temp_parametros_query AS
SELECT
	COALESCE('?',0)::INTEGER AS id,
	UPPER('?'::CHARACTER VARYING) AS descripcion,
	UPPER('?'::CHARACTER VARYING) AS codigo,
	'?'::BOOLEAN AS visible;

UPDATE
	campanias_bono_regalo
SET
	descripcion = a.descripcion,
	codigo = a.codigo,
	visible = a.visible
FROM
	temp_parametros_query a
WHERE
	campanias_bono_regalo.id = a.id AND
	a.id != 0;

	
INSERT INTO
	campanias_bono_regalo(
		descripcion,
		codigo,
		visible)
SELECT
	UPPER(descripcion) AS descripcion,
	UPPER(codigo) AS codigo,
	visible
FROM
	temp_parametros_query
WHERE
	id = 0
EXCEPT
SELECT
	UPPER(descripcion) AS descripcion,
	UPPER(codigo) AS codigo,
	visible
FROM
	campanias_bono_regalo;

INSERT INTO
	aux_campaniasbonosregalo(
		id,
		descripcion,
		codigo,
		visible)
SELECT
	id,
	descripcion,
	codigo,
	visible
FROM
	temp_parametros_query;
