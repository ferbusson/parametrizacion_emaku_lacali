DROP TABLE IF EXISTS productos;
CREATE TABLE productos AS
SELECT
        CAST('?' AS int) AS id_asiento_generico,
	CAST('?' AS character(14)) AS codigo,
	CAST('?' AS float8) AS costo,
	CAST('?' AS float8) AS pventa1,
	CAST('?' AS float8) AS pventa2,
	CAST('?' AS float8) AS pventa3;
	
INSERT INTO prod_serv(
        id_asiento_generico,
	id_color,
	codigo,
	estado,
	codigo_b,
	descripcion,
	iva,
	pcosto,
	comision,
	id_item,
	id_talla,
        id_tipo_prod_serv)
SELECT
        p.id_asiento_generico, 
	1 AS id_color,
	trim(p.codigo),
	TRUE,
	trim(p.codigo),
	'',
	a.tarifa,
	--p.costo,
    0 AS costo,
	'0',
	CURRVAL('item_id_item_seq'),
	1 AS id_talla,
	'001'
FROM 
	productos p,
	asientos_genericos a
WHERE
	p.id_asiento_generico = a.id_asiento_generico;

INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT	
	1,
	CURRVAL('prod_serv_id_prod_serv_seq'),
	pventa1
FROM
	productos;

INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT	
	2,
	CURRVAL('prod_serv_id_prod_serv_seq'),
	pventa2
FROM
	productos;

INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT	
	6,
	CURRVAL('prod_serv_id_prod_serv_seq'),
	pventa3
FROM
	productos;