-- Por Barra
SELECT
	substring(i.ref_proveedor,1,13),
	substring(i.nombre,1,30),
	substring(c.descripcion,1,14),
	t.talla,
	-1 as saldo1,
	pv.pventa AS pventa1,
	pv.pventa AS pventa2,
	1,
	current_date AS fecha,
	p.id_prod_serv,
	-1 as saldo2,
	pv.id_catalogo
FROM
	item i,
	prod_serv p,
	tallas t,
	colores c,
	pventa pv
WHERE
	p.id_item=i.id_item AND
	p.id_prod_serv=pv.id_prod_serv and
	p.id_talla=t.id_talla AND
	p.id_color=c.id_color and
	pv.id_catalogo = 1 and
	p.codigo='?';