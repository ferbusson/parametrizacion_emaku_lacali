DROP TABLE IF EXISTS args_cambio;
CREATE TEMP TABLE args_cambio AS
SELECT 

	'?'::varchar(14) as codigo,
	'?'::BIGINT as id_catalogo,
	'?'::BIGINT as id_bodega,
	'?'::varchar(10) as ndoc_fac;
	
SELECT
	p.id_prod_serv,
	i.nombre,
	dp.pventa,
	p.iva,
	current_timestamp as fecha,
	'1' as saldo,
	dp.pventa,
	dp.pventa,
	(SELECT trm FROM trm, (SELECT MAX(id_trm) AS id_trm FROM trm) AS foo WHERE trm.id_trm = foo.id_trm) AS trm,
	p.id_asiento_generico,
        p.codigo,
        i.ref_proveedor
FROM
	item i,
	args_cambio a,
	prod_serv p,
	(SELECT
		dp.id_prod_serv,
		dp.pventa
	FROM
		datos_prod dp,
		args_cambio a
	WHERE
		a.ndoc_fac!='' AND
		dp.ndocumento=a.ndoc_fac::bigint) AS dp

WHERE
	dp.id_prod_serv=p.id_prod_serv AND
	a.codigo=p.codigo AND
	p.id_item = i.id_item  ;