SELECT
	ps.codigo,
	TRIM(i.ref_proveedor) AS ref_proveedor,
	TRIM(i.nombre) AS nombre,
	TRIM(m.descripcion) AS marca,
	TRIM(l.descripcion) AS linea,
	COALESCE(inv.valor_ent,0)/inv.entrada AS pcosto,
	inv.entrada
FROM
	documentos d,
	inventarios inv,
	prod_serv ps,
	item i,
	marcas m,
	linea l
WHERE
	d.ndocumento = inv.ndocumento AND
	d.estado AND
	inv.id_prod_serv = ps.id_prod_serv AND
	inv.entrada IS NOT NULL AND
	ps.id_item = i.id_item AND
	i.id_linea = l.id_linea AND
	i.id_marca = m.id_marca AND
	d.codigo_tipo = '?' AND
	d.numero = LPAD('?',10,'0');