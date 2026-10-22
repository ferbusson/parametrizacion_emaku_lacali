DELETE FROM --?
	conceptos_importacion 
USING
	(	
	SELECT
		ci.id_concepto_importacion
	FROM
		aux_act_conceptos_imp a,
		conceptos_importacion ci
	WHERE
		ci.id_grupo = a.id_grupo
	EXCEPT
	SELECT
		id_concepto_importacion
	FROM
		aux_act_conceptos_imp) AS foo
WHERE
	conceptos_importacion.id_concepto_importacion = foo.id_concepto_importacion;