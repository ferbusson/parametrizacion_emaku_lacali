DELETE FROM
	tipos_salario
USING
	aux_tipossalario_ok a
WHERE
	tipos_salario.descripcion NOT IN 
				(SELECT
					descripcion
				FROM
					aux_tipossalario_ok);
