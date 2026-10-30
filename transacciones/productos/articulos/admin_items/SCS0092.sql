SELECT 
	p.id_prod_serv,
	eg.id_asientos_prod_serv,
	eg.id_asientos_pr 
FROM 
	prod_serv p,
	asientos_genericos g,
	enlace_asientos_genericos eg 
WHERE 
	g.id_asiento_generico=eg.id_asiento_generico AND 
	p.id_asiento_generico=g.id_asiento_generico AND 
	p.id_prod_serv>'?'