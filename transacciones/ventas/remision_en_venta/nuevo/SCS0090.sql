SELECT
    NULL AS fecha,
    foo.id_bodega,
    foo.id_prod_serv,    
    0 as saldo,
    0 as valorSaldo
FROM
	(SELECT		
		foo.id_bodega,
		foo.id_prod_serv,
		CASE WHEN 
            foo.id_bodega = 916 THEN 0 
        WHEN 
            foo.id_bodega = 920 THEN 1 
		WHEN
			foo.id_bodega = 138 THEN 2 
        ELSE 
            ROW_NUMBER() OVER(ORDER BY foo.id_bodega) + 2
        END AS orden
	FROM
			(
			/*SELECT DISTINCT
				i.id_bodega,
				i.id_prod_serv
			FROM
				documentos d,
				inventarios i,
				prod_serv ps
			WHERE
				d.ndocumento = i.ndocumento AND
			 	i.id_bodega NOT IN (912,914,918) AND
				d.estado AND
				i.id_prod_serv = ps.id_prod_serv*/
			
			
			SELECT DISTINCT
				i.id_bodega,
				i.id_prod_serv
			FROM
				documentos d,
				registro_modificacion rm,
				inventarios i,
				prod_serv ps
			WHERE
				d.ndocumento = rm.ndocumento AND
			 	(rm.fecha::DATE >= CURRENT_DATE-1 or
				d.codigo_tipo IN ('TU','TL','TG')) and
				d.ndocumento = i.ndocumento AND
			 	i.id_bodega NOT IN (912,914,918) AND
				d.estado AND
				i.id_prod_serv = ps.id_prod_serv
			
			/*select 
	i.id_bodega,
	i.id_prod_serv 
from 
	inventarios i,
	(select 
		i.id_bodega,
		i.id_prod_serv,
		max(i.orden) as orden
	from 	
		inventarios i,
		prod_serv ps 
	where 
		i.id_prod_serv = ps.id_prod_serv and
		ps.codigo not in ('0000','B001','B002') and
		i.id_bodega = 138
	group by
		i.id_bodega,
		i.id_prod_serv) as foo
where 
	foo.orden = i.orden
order by 
	i.saldo limit 100000*/
			
			) AS foo
		) AS foo
ORDER BY
    orden;