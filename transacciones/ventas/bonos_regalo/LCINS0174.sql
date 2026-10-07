DROP TABLE IF EXISTS aux_enf_params;
CREATE TEMP TABLE aux_enf_params AS
SELECT
	COALESCE('?',0)::INTEGER AS id_tipo_salario,
	UPPER('?'::CHARACTER VARYING) AS descripcion;

UPDATE
	tipos_salario
SET
	descripcion = a.descripcion
FROM
	aux_enf_params a
WHERE
	tipos_salario.id_tipo_salario = a.id_tipo_salario AND
	a.id_tipo_salario != 0;

	
INSERT INTO
	tipos_salario(
		descripcion)
SELECT
	UPPER(descripcion) AS descripcion
FROM
	aux_enf_params
WHERE
	id_tipo_salario = 0
EXCEPT
SELECT
	UPPER(descripcion) AS descripcion
FROM
	tipos_salario;

INSERT INTO
	aux_tipossalario_ok(
		id_tipo_salario,
		descripcion)
SELECT
	id_tipo_salario,
	descripcion
FROM
	aux_enf_params;
