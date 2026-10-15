DROP TABLE IF EXISTS aux_parametros_query;
CREATE TEMP TABLE aux_parametros_query AS
SELECT
    '?'::VARCHAR(14) AS codigo,
    '?'::VARCHAR(15) AS id_proveedor,
    '?'::VARCHAR AS ndocumento_oc;

DROP TABLE IF EXISTS bquery;
CREATE TEMP TABLE bquery AS
SELECT     
	ps.id_prod_serv,
    a.id_proveedor,
    a.ndocumento_oc
FROM 
	prod_serv ps,
    aux_parametros_query a
WHERE 
	ps.codigo=a.codigo;

SELECT
	SUBSTRING(i.ref_proveedor,1,13),		--referencia
	i.nombre,			--nombre
	SUBSTRING(c.codigo||'-'||c.descripcion,1,11),	--colores
	t.talla,					--talla
	pcosto,						--vunitario	
	iva,						--piva
    iva,	   					--tiva
    p.id_prod_serv,					--id
    1,						--factorc
    COALESCE(sdo.sdo,3),
    CASE WHEN TRIM(b.ndocumento_oc) = '' OR TRIM(b.ndocumento_oc) IS NULL THEN '-1' ELSE TRIM(b.ndocumento_oc) END AS ndocumento_oc
FROM 
	prod_serv p,
	item i,
	colores c,
	tallas t,
	marcas m,
	proveedor_marca pm,
	bquery b
LEFT OUTER JOIN
	(SELECT 
		i.id_prod_serv,
		COALESCE(SUM(entrada),0)-COALESCE(SUM(salida),0) AS sdo 
	FROM 
		inventarios i,
		documentos d
	WHERE 
		i.ndocumento = d.ndocumento AND
		d.estado AND
		i.id_prod_serv= (select id_prod_serv from bquery)
	GROUP BY
		i.id_prod_serv) AS sdo
ON
	b.id_prod_serv=sdo.id_prod_serv 
WHERE 
	i.id_marca = m.id_marca AND
	i.id_item = p.id_item AND
	p.id_color = c.id_color AND
	p.id_talla = t.id_talla AND
	pm.id_marca = m.id_marca AND
	p.id_prod_serv=b.id_prod_serv AND
	CAST(pm.id_proveedor AS CHARACTER(15))= b.id_proveedor;

