DROP TABLE IF EXISTS aux_args_repo;
CREATE TEMP TABLE aux_args_repo AS
SELECT
    '?'::VARCHAR AS id_bodega, -- aqui llega el id_bodega de la plataforma
    '?'::TIMESTAMP AS fechai,
    '?'::TIMESTAMP AS fechaf;

DROP TABLE IF EXISTS remote_cnx;
CREATE TEMP TABLE remote_cnx AS
SELECT
    'CNX'||round((random()*1000000)::numeric,0) AS cnx,
    host,
    dbname,
    usuario,
    clave
FROM
    dblink_sucursales d,
    aux_args_repo a
WHERE
    d.id_bodega = a.id_bodega::INTEGER AND
    d.online;

-- SE ESTABLECE EL LINK CON EL SERVIDOR 
DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT
    (SELECT dblink_connect(cnx,'host='||dl.host||' dbname='||dl.dbname||' user='||dl.usuario||' port=5432 password='||dl.clave||''))
FROM
    remote_cnx AS dl;

--

DROP TABLE IF EXISTS aux_reporte_decoracion;
CREATE TEMP TABLE aux_reporte_decoracion AS 
SELECT
	sucursal,
	factura,
	fecha,
	linea,
	codigo,
	ref_proveedor,
	descripcion,
	cant,
	pventa,
	descuento1,
	total,
	sigla,
	vendedor,
	devolucion,
	cantidad_devolucion
FROM
	aux_args_repo a,
	dblink((SELECT cnx FROM remote_cnx),
	'drop table if exists aux_reporte_deco_previo;
	create temp table aux_reporte_deco_previo as
	SELECT
	a.nombre AS sucursal,
	COALESCE(rf.prefijo,d.codigo_tipo)||''-''||d.numero::BIGINT AS factura,
	d.fecha,
	l.descripcion as linea,
	ps.codigo,
	i.ref_proveedor,
	i.nombre AS descripcion,
	dp.cant,
	pventa-COALESCE(((pventa*descuento1)/100),0) AS pventa,
	dp.descuento1,
	dp.cant*(pventa-COALESCE(((pventa*descuento1)/100),0)) AS total,
	ie.sigla,
	COALESCE(ge.nombre1,'''')||'' ''||COALESCE(ge.nombre2,'''')||'' ''||COALESCE(ge.apellido1,'''')||'' ''||COALESCE(ge.apellido2,'''')||'' ''||COALESCE(ge.razon_social,'''') AS vendedor,
	coalesce(d2.codigo_tipo||d2.numero::bigint::varchar,''--'') as devolucion,
	d2.ndocumento as ndocumento_devolucion,
	dp.id_prod_serv
FROM
	administracion_sucursales a,
	info_documento id,
	datos_prod dp,
	prod_serv ps,
	item i,
	linea l,
	grupo g,
	general ge,
	info_empleado ie,
	documentos d
LEFT OUTER JOIN
	resolucion_documento rd
ON
	d.ndocumento = rd.ndocumento
LEFT OUTER JOIN
	resolucion_facturacion rf
ON
	rd.id_resolucion_facturacion = rf.id_resolucion_facturacion
left join
	info_documento id2
on
	d.ndocumento = id2.rf_documento
left join
	documentos d2
on
	id2.ndocumento = d2.ndocumento and
	d2.estado and
	d2.codigo_tipo LIKE ''M%''
WHERE
	d.codigo_tipo NOT like ''H%'' AND
	d.ndocumento = dp.ndocumento AND
	d.ndocumento = id.ndocumento AND
	id.id_vendedor IS NOT NULL AND
	id.id_vendedor != 911 AND
	dp.id_prod_serv = ps.id_prod_serv AND
	d.estado AND
	id.id_vendedor = ge.id AND
	ge.id = ie.id AND
	ps.id_item = i.id_item AND	
	i.id_linea = l.id_linea AND
	i.id_linea = g.id_linea AND
	i.id_grupo = g.id_grupo and		
	(l.descripcion = ''NAVIDAD'' OR
	l.descripcion = ''BELLEZA & CUIDADO PERSONAL'' OR
	(l.descripcion = ''SERVICIOS'' AND	
	g.descripcion = ''DECORACION'')) AND
	
	d.fecha::DATE BETWEEN '''||a.fechai||''' AND '''||a.fechaf||''' AND
	a.id_bodega_ppal = '''||a.id_bodega::INTEGER||'''
ORDER BY
	d.codigo_tipo||''-''||d.numero::BIGINT;

select
	a.sucursal,
	a.factura,
	a.fecha,
	a.linea,
	a.codigo,
	a.ref_proveedor,
	a.descripcion,
	a.cant,
	a.pventa,
	a.descuento1,
	a.total,
	a.sigla,
	a.vendedor,
	case when dp.cant is not null then a.devolucion else '''' end as devolucion,
	case when dp.cant is not null then dp.cant::text else '''' end as cantidad_devolucion
from
	aux_reporte_deco_previo a
left join
	datos_prod dp
on
	a.ndocumento_devolucion = dp.ndocumento and
	a.id_prod_serv = dp.id_prod_serv
') AS r(
			sucursal VARCHAR,
			factura VARCHAR,
			fecha VARCHAR,
			linea TEXT,
			codigo VARCHAR,
			ref_proveedor varchar,
			descripcion VARCHAR,
			cant FLOAT8,
			pventa FLOAT8,
	descuento1 FLOAT8,
			total FLOAT8,
			sigla VARCHAR,
			vendedor VARCHAR,
			devolucion text,
			cantidad_devolucion text
);

DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;

--

SELECT
	sucursal,
	factura,
	fecha,
	linea,
	codigo,
	ref_proveedor,
	descripcion,
	cant,
	pventa,
	total,
	sigla,
	vendedor,
	devolucion,
	cantidad_devolucion
FROM
	aux_reporte_decoracion
ORDER BY
	factura;