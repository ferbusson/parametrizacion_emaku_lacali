SELECT
        TRUE AS seleccion,
	--replace(td.descripcion,'Facturacion ','') AS descripcion,
	CASE WHEN td.codigo_tipo = 'F1' THEN 'PRINCIPAL'
	WHEN td.codigo_tipo = 'F3' THEN 'LAS CUADRAS'
	WHEN td.codigo_tipo = 'F4' THEN 'UNICO'
	WHEN td.codigo_tipo = 'F5' THEN 'GRAN PLAZA' END AS descripcion,
        e.codigo_tipo
FROM
	documentos d,
	registro_promociones_excepciones e,
	tipo_documento td
WHERE
	td.codigo_tipo = e.codigo_tipo and
	d.ndocumento = e.ndocumento AND
	d.ndocumento = '?';