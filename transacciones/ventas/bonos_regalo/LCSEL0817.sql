SELECT
	descripcion AS concepto,
	id_tipo_salario
FROM
	tipos_salario
 UNION ALL
 SELECT
    NULL AS concepto,
    0
 FROM
    generate_series(0,10)
ORDER BY
	concepto NULLS LAST;	