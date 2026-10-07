SELECT
	codigo_barras,
	nombre,
	100,
	cantidad,
	valoru,
	iva,
	descuento,
	stotal,
	descu,
	neto,
	tiva,
	total,
	id_prod_serv,
	tag,
	trm,
	ustotal,
	id_asiento_generico,
	basecinco,
	tivacinco,
	basediezynueve,
	tivadiezynueve,
	baseexentos,
	tivaexentos,
	baseexcluidos,
	tivaexcluidos,
	0.00 AS verde,
	0.00 AS subtotalsinbolsa,
	0.00 AS vlrunitarioimp,
	foo.codigo_barras,
	foo.ref_proveedor,
	foo.porcentajebp,
	foo.inc,
	1 as contadorlinea
FROM
	(SELECT DISTINCT
		ps.codigo AS codigo_barras,
		i.nombre,
		dp.cant AS cantidad,
		dp.pventa AS valoru,
		dp.iva AS iva,
		dp.descuento1 AS descuento,
		0.0 AS stotal,
		0.0 AS descu,
		0.0 AS neto,
		0.0 AS tiva,
		0.0 AS total,
		dp.id_prod_serv,
		CURRENT_TIMESTAMP AS tag,
		COALESCE(dd.trm,0.0) AS trm,
		0.0 AS ustotal,
		ps.id_asiento_generico,
		0.0 AS basecinco,
		0.0 AS tivacinco,
		0.0 AS basediezynueve,
		0.0 AS tivadiezynueve,
		0.0 AS baseexentos,
		0.0 AS tivaexentos,
		0.0 AS baseexcluidos,
		0.0 AS tivaexcluidos,
		i.ref_proveedor,
		dp.orden,
		coalesce(dp.porcentajebp,-1) as porcentajebp,
		coalesce(dp.inc,-1) as inc
	FROM
		documentos d,
		datos_documento dd,
		datos_prod dp,
		prod_serv ps,
		item i
	WHERE 
		d.codigo_tipo = '?' AND
		d.numero = LPAD('?',10,'0') AND
		d.ndocumento = dp.ndocumento AND
		d.ndocumento = dd.ndocumento AND
		dp.id_prod_serv = ps.id_prod_serv AND
		dp.cambio AND
		ps.id_item = i.id_item) AS foo
ORDER BY
	foo.orden;