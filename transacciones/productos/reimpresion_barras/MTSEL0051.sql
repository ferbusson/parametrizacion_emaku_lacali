-- Por Barra
SELECT
/*0*/	substring(trim(i.ref_proveedor),1,13),
/*1*/	substring(i.nombre,1,100),
/*2*/	substring(c.descripcion,1,14),
/*3*/	t.talla,
/*4*/	-1 as saldo1,
/*5*/	COALESCE(pv.pventa,0) AS pventa1,
/*6*/	COALESCE(pv.pventa,0) AS pventa2,
/*7*/	1,
/*8*/	current_date AS fecha,
/*9*/	p.id_prod_serv,
/*10*/	-1 as saldo2,
/*11*/	pv.id_catalogo,
/*12*/	substring(i.nombre,1,35) AS linea1,
/*13*/	substring(i.nombre,36,70) AS linea2,
/*14*/	trim(m.descripcion) as marca
FROM
	item i,
	prod_serv p,
	tallas t,
	colores c,
	marcas m,
	pventa pv
WHERE
	p.id_item=i.id_item AND
	i.id_marca = m.id_marca and
	p.id_prod_serv=pv.id_prod_serv and
	p.id_talla=t.id_talla AND
	p.id_color=c.id_color and
	pv.id_catalogo = 1 and
	p.codigo='?';