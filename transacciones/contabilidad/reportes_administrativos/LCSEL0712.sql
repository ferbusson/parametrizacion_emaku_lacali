-- LCSEL0712
DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT 
	'?'::VARCHAR AS id_bodega_ppal,
	'?'::DATE AS fechai,
	'?'::DATE AS fechaf;


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
    args_arqueo_medios a
WHERE
    d.id_bodega = (CASE WHEN a.id_bodega_ppal::INTEGER = 1252 THEN 138 ELSE a.id_bodega_ppal::INTEGER END) AND
    d.online;

-- SE ESTABLECE EL LINK CON EL SERVIDOR 
DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT
    (SELECT dblink_connect(cnx,'host='||dl.host||' dbname='||dl.dbname||' user='||dl.usuario||' port=5432 password='||dl.clave||''))
FROM
    remote_cnx AS dl;


DROP TABLE IF EXISTS aux_crea_reporte_remoto;
CREATE TEMP TABLE aux_crea_reporte_remoto AS
SELECT
(SELECT
	dblink_exec((SELECT cnx FROM remote_cnx),
'DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT DISTINCT
	ad.id_administracion_sucursales,
	CASE WHEN ds.nombre IN (''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'') THEN FALSE ELSE TRUE END AS suma,
	dv.codigo_tipo
FROM
	documentos_standar ds,
	administracion_sucursales ad,
	documentos_sucursales dv
WHERE
	ds.id_documento=dv.id_documento AND
	dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
	CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal::VARCHAR='''||a.id_bodega_ppal||''' END AND
	ds.nombre IN (''FACTURACION'',
				  ''DEVOLUCION VENTA'',
				  ''FMANUAL'',
				  ''FELECTRONICAPOS'',
				  ''DVENTA ELECTRONICA'',
				  ''FCONTINGENCIAE'',
				  ''FCREDITO'',
				  ''FCONTINGENCIA'',
				  ''CAMBIOS'');

DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	d.ndocumento,
	t.suma
from
	tipo_docs t,
	documentos d
WHERE
	d.fecha::date BETWEEN '''||a.fechai||''' AND '''||a.fechaf||''' AND
	d.estado AND
	d.codigo_tipo = t.codigo_tipo ; -- Solo documentos de la sucursal seleccionada


DROP TABLE IF EXISTS aux_devoluciones;
CREATE TEMP TABLE aux_devoluciones AS
SELECT
	d.fecha::DATE AS fecha,
	SUM(l.haber) AS total
FROM
	administracion_sucursales ads,
	documentos_standar dst,
	documentos_sucursales ds,
	documentos d, 
	aux_docs a,
	libro_auxiliar l, 
	cuentas c
WHERE
	ds.id_administracion_sucursales=ads.id_administracion_sucursales AND
	ds.codigo_tipo = d.codigo_tipo AND
	ds.id_documento = dst.id_documento and
	dst.nombre in (''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'') and
	d.ndocumento=l.ndocumento AND
	d.ndocumento = a.ndocumento AND
	l.id_cta = c.id_cta AND
	(c.char_cta like ''11%'' OR
	c.char_cta like ''1305%'' OR		
	c.char_cta like ''28050502%'' OR
	c.char_cta like ''28050504%'' OR
	c.char_cta like ''2810%'') AND
	d.estado=true
GROUP BY
	d.fecha::DATE;

DROP TABLE IF EXISTS aux_ventas;
CREATE TEMP TABLE aux_ventas AS
SELECT
	d.fecha::DATE AS fecha,
	SUM(l.debe) AS total
FROM
	administracion_sucursales ads,
	documentos_standar dst,
	documentos_sucursales ds,
	documentos d, 
	aux_docs a,
	libro_auxiliar l, 
	cuentas c
WHERE
	ds.id_administracion_sucursales=ads.id_administracion_sucursales AND
	ds.codigo_tipo = d.codigo_tipo AND
	ds.id_documento = dst.id_documento and
	dst.nombre in (''FCREDITO'',''FACTURACION'',''CAMBIOS'',''FCONTINGENCIA'',''FELECTRONICAPOS'',''FCONTINGENCIAE'',''FMANUAL'') and
	d.ndocumento=l.ndocumento AND
	d.ndocumento = a.ndocumento AND
	l.id_cta = c.id_cta AND
	(c.char_cta like ''11%'' OR
	c.char_cta like ''1305%'' OR		
	c.char_cta like ''28050502%'' OR
	c.char_cta like ''28050504%'' OR
	c.char_cta like ''2810%'') AND
	d.estado=true
GROUP BY
	d.fecha::DATE;

--

DROP TABLE IF EXISTS aux_ventas_sin_iva;
CREATE TEMP TABLE aux_ventas_sin_iva AS
SELECT
	l.fecha::DATE AS fecha,
	sum(l.haber)-sum(l.debe) AS valor
FROM
	aux_docs a,
	libro_auxiliar l,
	prod_serv ps,
	item i,
	cuentas c
WHERE
	a.ndocumento = l.ndocumento AND
	l.id_prod_serv = ps.id_prod_serv AND
	ps.id_item = i.id_item AND
	i.id_linea NOT IN (16) AND
	c.id_cta = l.id_cta AND
	c.char_cta IN (''41355610'',''41755610'', -- mercancia excluida
				  ''41355615'',''41755615'', -- mercancia exenta
				  ''4135560501'',''4175560501'', -- mercancia 5%
				  ''4135560502'',''4175560502'', --mercancia 19%
				  ''4135562001'' -- servicios 19%
				  )
GROUP BY
	l.fecha::DATE
HAVING
	SUM(l.haber)!=0;
	
--

DROP TABLE IF EXISTS aux_cant_documentos;
CREATE TEMP TABLE aux_cant_documentos AS
SELECT
	d.fecha::DATE AS fecha,
	COUNT(d.ndocumento) AS cantidad_facturas
FROM
	(SELECT DISTINCT id_administracion_sucursales FROM tipo_docs) td,
	aux_docs ad,
	documentos d,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	td.id_administracion_sucursales = ds.id_administracion_sucursales AND
	dst.id_documento = ds.id_documento AND
	dst.nombre IN (''FACTURACION'',
				  ''FMANUAL'',
				  ''FELECTRONICAPOS'',
				  ''FCONTINGENCIAE'',
				  ''FCREDITO'',
				  ''FCONTINGENCIA'',
				  ''CAMBIOS'') AND
	ds.codigo_tipo = d.codigo_tipo AND
	d.ndocumento = ad.ndocumento
GROUP BY
	d.fecha::DATE;
--

DROP TABLE IF EXISTS total_und_vendidas;
CREATE TEMP TABLE total_und_vendidas AS
SELECT
	d.fecha::DATE AS fecha,
	SUM(CASE WHEN i.id_linea NOT IN (16) AND dp.cambio = FALSE THEN dp.cant WHEN i.id_linea NOT IN (16) AND dp.cambio = TRUE THEN dp.cant*-1 WHEN i.id_linea IN (16) THEN 0 END) AS unidades_vendidas -- servicios, servicios decoracion, impuestos bolsas	
FROM
	(SELECT DISTINCT id_administracion_sucursales FROM tipo_docs) td,
	documentos_standar dst,
	documentos_sucursales ds,
	documentos d,
	datos_prod dp,
	aux_docs a,
	prod_serv ps,
	item i
WHERE	
	ds.id_administracion_sucursales=td.id_administracion_sucursales AND
	ds.id_documento=dst.id_documento AND
	dst.nombre IN (''FACTURACION'',''CAMBIOS'',''FCREDITO'',''FCONTINGENCIA'',''FMANUAL'',''FELECTRONICAPOS'',''FCONTINGENCIAE'',''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'') AND -- solo se cuentan facs no devs Maria E 29 Oct 2020
	d.codigo_tipo = ds.codigo_tipo AND
	a.ndocumento = d.ndocumento AND
	a.ndocumento = dp.ndocumento AND
	ps.id_prod_serv = dp.id_prod_serv AND
	ps.id_item = i.id_item
GROUP BY
	d.fecha::DATE;
--

DROP TABLE IF EXISTS total_costo_ventas;
CREATE TEMP TABLE total_costo_ventas AS
SELECT
	d.fecha::DATE AS fecha,
	SUM(CASE WHEN i.id_linea NOT IN (16) THEN inv.valor_sal * inv.salida ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas
FROM
	(SELECT DISTINCT id_administracion_sucursales FROM tipo_docs) td,
	documentos_standar dst,
	documentos_sucursales ds,
	documentos d,
	inventarios inv,
	aux_docs a,
	prod_serv ps,
	item i
WHERE	
	ds.id_administracion_sucursales=td.id_administracion_sucursales AND
	ds.id_documento=dst.id_documento AND
	dst.nombre IN (''FACTURACION'',''CAMBIOS'',''FCREDITO'',''FCONTINGENCIA'',''FMANUAL'',''FELECTRONICAPOS'',''FCONTINGENCIAE'') AND -- solo se cuentan facs no devs Maria E 29 Oct 2020
	d.codigo_tipo = ds.codigo_tipo AND
	a.ndocumento = d.ndocumento AND
	a.ndocumento = inv.ndocumento AND
	inv.salida IS NOT NULL AND inv.salida != 0 AND
	ps.id_prod_serv = inv.id_prod_serv AND
	ps.id_item = i.id_item
GROUP BY
	d.fecha::DATE;

--
DROP TABLE IF EXISTS aux_resultado_final_repo;
CREATE TEMP TABLE aux_resultado_final_repo AS
SELECT
	a1.fecha,
	COALESCE(a1.total,0) - COALESCE(a2.total,0) AS total_ventas,
	COALESCE(asi.valor,0) AS total_ventas_sin_iva,
	acd.cantidad_facturas,
	tuv.unidades_vendidas,
	ROUND(tcv.costo::NUMERIC,2) AS costo,
	ROUND(CASE WHEN COALESCE(asi.valor,0) != 0 THEN ((COALESCE(asi.valor,0)-ROUND(tcv.costo::NUMERIC,2))/COALESCE(asi.valor,0))*100.0 ELSE 0.0 END::NUMERIC,2)AS putilidad
FROM
	aux_cant_documentos acd,
	total_und_vendidas tuv,
	total_costo_ventas tcv,
	aux_ventas a1
LEFT OUTER JOIN	
	aux_devoluciones a2
ON
	a1.fecha = a2.fecha
LEFT OUTER JOIN
	aux_ventas_sin_iva asi
ON
	a1.fecha = asi.fecha
WHERE	
	a1.fecha = tuv.fecha AND
	a1.fecha = acd.fecha AND
	a1.fecha = tcv.fecha
ORDER BY
	a1.fecha;'))
FROM
	args_arqueo_medios a;

DROP TABLE IF EXISTS aux_reporte_final_remoto;
CREATE TEMP TABLE aux_reporte_final_remoto AS
SELECT
	fecha,
	total_ventas,
	total_ventas_sin_iva,
	cantidad_facturas,
	unidades_vendidas,
	costo,
	putilidad
FROM
	dblink((SELECT cnx FROM remote_cnx),
	'SELECT
		fecha,
		total_ventas,
		total_ventas_sin_iva,
		cantidad_facturas,
		unidades_vendidas,
		costo,
		putilidad
	FROM
		aux_resultado_final_repo') AS r(
		fecha VARCHAR,
		total_ventas FLOAT8,
		total_ventas_sin_iva FLOAT8,
		cantidad_facturas INTEGER,
		unidades_vendidas INTEGER,
		costo FLOAT8,
		putilidad FLOAT8
);

DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;


	

DROP TABLE IF EXISTS aux_suma_resultado_final_repo;
CREATE TEMP TABLE aux_suma_resultado_final_repo AS
SELECT
	'TOTAL'::VARCHAR AS fecha,
	SUM(total_ventas) AS total_ventas,
	SUM(total_ventas_sin_iva) AS total_ventas_sin_iva,
	SUM(cantidad_facturas) AS cantidad_facturas,
	SUM(unidades_vendidas) AS unidades_vendidas,
	SUM(costo) AS costo,
	ROUND(CASE WHEN SUM(total_ventas_sin_iva) != 0 THEN
		((SUM(total_ventas_sin_iva)-SUM(costo))/SUM(total_ventas_sin_iva))*100.0
	ELSE
		0.0
	END::NUMERIC,2) AS putilidad
FROM
	aux_reporte_final_remoto;
	
SELECT
	fecha::VARCHAR AS fecha,
	total_ventas,
	total_ventas_sin_iva,
	cantidad_facturas,
	unidades_vendidas,
	costo,
	putilidad,
	0::INTEGER AS color
FROM
	aux_reporte_final_remoto
UNION
SELECT
	fecha,
	total_ventas,
	total_ventas_sin_iva,
	cantidad_facturas,
	unidades_vendidas,
	costo,
	putilidad,
	-1::INTEGER AS color
FROM
	aux_suma_resultado_final_repo
ORDER BY
	fecha;