DROP TABLE IF EXISTS args_cambio;
CREATE TEMP TABLE args_cambio AS
SELECT 

	'?'::varchar(14) as codigo,
	'?'::BIGINT as id_catalogo,
	'?'::BIGINT as id_bodega,
	'?'::CHARACTER as bandera,
	'?'::varchar(10) as ndoc_fac;
	
DROP TABLE IF EXISTS aux_info_inc;
CREATE TEMP TABLE aux_info_inc AS 
select
	inc
from
	inc
order by 
	id_inc desc
limit 1;

SELECT
	p.id_prod_serv,
	trim(i.nombre) as nombre,
	COALESCE(dp.pventa,pv.pventa) AS pventa,
	p.iva,
	current_timestamp as fecha,
	'1' as saldo,
	COALESCE(dp.pventa,pv.pventa) AS pventa,
	COALESCE(dp.pventa,pv.pventa) AS pventa,
	(SELECT trm FROM trm, (SELECT MAX(id_trm) AS id_trm FROM trm) AS foo WHERE trm.id_trm = foo.id_trm) AS trm,
	p.id_asiento_generico,
	a.bandera,
	trim(p.codigo) as codigo,
	trim(i.ref_proveedor) as ref_proveedor,
	coalesce(tbe.porcentaje,-1) as porcentaje_bp,
	inc.inc 
FROM
	item i,
	args_cambio a,
	pventa pv,
	prod_serv p
LEFT OUTER JOIN
	(SELECT
		dp.id_prod_serv,
		dp.pventa
	FROM
		datos_prod dp,
		args_cambio a
	WHERE
		a.ndoc_fac!='' AND
		dp.ndocumento=a.ndoc_fac::bigint) AS dp
ON
	dp.id_prod_serv=p.id_prod_serv
left outer join 
	enlace_producto_tarifa_bolsa_eco e 
on
	p.id_prod_serv = e.id_prod_serv
left join 	
	tarifas_bolsas_ecologicas tbe
on
	e.id_nivel_impacto = tbe.id_nivel_impacto
left join
	aux_info_inc inc
on
	true
WHERE
	a.codigo=p.codigo AND
	p.id_prod_serv=pv.id_prod_serv AND
	p.id_item = i.id_item AND
	((a.bandera = '1') OR
	(a.bandera = '2' AND a.ndoc_fac != '' AND dp.id_prod_serv IS NOT NULL)) AND
	pv.id_catalogo=1 ;