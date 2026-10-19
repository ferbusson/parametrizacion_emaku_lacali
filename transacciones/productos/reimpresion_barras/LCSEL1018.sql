DROP TABLE IF EXISTS info_args;
CREATE TEMP TABLE info_args AS
SELECT
	'?'::VARCHAR AS marca,
	'?'::varchar AS submarca,
	'?'::INTEGER AS id_linea,
	'?'::INTEGER AS id_grupo,
	'?'::INTEGER AS id_sgrupo,
	'?'::INTEGER AS id_filtro;
	
DROP TABLE IF EXISTS aux_listado_productos;
CREATE TEMP TABLE aux_listado_productos AS
SELECT
   p.codigo,
	TRIM(i.ref_proveedor) AS ref_prov,
	i.nombre,
	m.descripcion as marca,
	c.descripcion,
	t.talla,
	COALESCE(pv.pventa,0) AS pventa1,
	COALESCE(pv.pventa,0) AS pventa2,
	p.id_prod_serv--,
	--iv.saldo
FROM
	marcas m,
	item i,
	tallas t,
	colores c,
	info_args ia,
	prod_serv p
LEFT OUTER JOIN
	pventa pv
ON
	p.id_prod_serv = pv.id_prod_serv AND
	pv.id_catalogo = 1
where
	ia.id_filtro = 1 and -- 1: buscar 0: borrar
	case when (trim(ia.marca) = '' or ia.marca is null) and (trim(ia.submarca) = '' or ia.submarca is null) and ia.id_linea = 0 and ia.id_grupo = 0 and ia.id_sgrupo = 0 then false
		else true end and
	case when (trim(ia.marca) != '' and ia.marca is not null) then ia.marca::integer = i.id_marca else true end and
	case when (trim(ia.submarca) != '' and ia.submarca is not null) then ia.submarca::integer = i.id_submarca else true end and
	
	
	
	(ia.id_linea = 0 OR ia.id_linea = i.id_linea) AND
	(ia.id_grupo = 0 OR ia.id_grupo = i.id_grupo) AND
	(ia.id_sgrupo = 0 OR ia.id_sgrupo = i.id_sgrupo) and

	m.id_marca=i.id_marca AND
	p.id_item=i.id_item AND		
	p.id_talla=t.id_talla AND
	p.id_color=c.id_color;

DROP TABLE IF EXISTS aux_saldos_productos;
CREATE TEMP TABLE aux_saldos_productos AS
SELECT 
	i.id_prod_serv,
	COALESCE(sum(i.entrada),0)-COALESCE(sum(i.salida),0) AS saldo 
from
	inventarios i	
where
	i.id_prod_serv in (select a.id_prod_serv from aux_listado_productos a) and
	i.id_bodega = 138
GROUP BY 
	i.id_prod_serv;

SELECT
	foo.codigo,
	1,
	substring(foo.ref_prov,1,13) AS referencia,
	substring(foo.nombre,1,100) AS descripcion,
	substring(foo.descripcion,1,14),
	foo.talla,
	1,
	0,
	foo.pventa1,
	foo.pventa2,
	current_date AS fecha,
	foo.id_prod_serv,
	0,
	0,
	0,
	foo.marca,
	substring(nombre,1,35) AS linea1,
	substring(nombre,36,70) AS linea2
FROM
	aux_listado_productos foo
LEFT OUTER JOIN 
	aux_saldos_productos AS iv
	ON 
		iv.id_prod_serv = foo.id_prod_serv
where
	iv.saldo > 0
order by
	descripcion
limit 1000;
		
		
		