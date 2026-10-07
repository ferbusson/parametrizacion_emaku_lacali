-- LCSEL0866
DROP TABLE IF EXISTS aux_args;
CREATE TEMP TABLE aux_args AS
SELECT
	foo.id_bodega,
	foo.fechai,
	foo.fechaf,
	COALESCE(g.id,-1) AS id,
	foo.id_char,
	foo.id_marca,
	g2.nombre1 AS nombre_bodega
FROM
	(SELECT
	    '?'::VARCHAR id_bodega,
	    '?'::TIMESTAMP AS fechai,
	    '?'::TIMESTAMP AS fechaf,
	    TRIM('?'::VARCHAR) AS id_char,
	    ''::VARCHAR AS id_marca) AS foo
LEFT OUTER JOIN
	general g
ON
	foo.id_char = g.id_char
LEFT OUTER JOIN
	general g2
ON
	foo.id_bodega = g2.id::VARCHAR;
	


DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('No es posible generar el reporte, la sucursal ('||foo.dbname||') no tiene conexión. Intente más tarde por favor')
	FROM
		(SELECT
			'CNX'||round((random()*1000000)::numeric,0) AS cnx,
			host,
			dbname,
			usuario,
			clave
		FROM
			dblink_sucursales d,
			aux_args a
		WHERE
			d.id_bodega = a.id_bodega::INTEGER AND
			d.online = FALSE
			) AS foo) AS foo;


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
    aux_args a
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


DROP TABLE IF EXISTS aux_crea_reporte_remoto;
CREATE TEMP TABLE aux_crea_reporte_remoto AS
SELECT
(SELECT
	dblink_exec((SELECT cnx FROM remote_cnx),
	'DROP TABLE IF EXISTS aux_codigo_tipo;
	CREATE TEMP TABLE aux_codigo_tipo AS
	SELECT
	    ds.codigo_tipo
	FROM
	    administracion_sucursales s,
	    documentos_sucursales ds,
	    documentos_standar dst
	WHERE
	    s.id_administracion_sucursales = ds.id_administracion_sucursales AND
	    ds.id_documento = dst.id_documento AND
	    dst.nombre IN (''FACTURACION'',''CAMBIOS'',''FCREDITO'',''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'',''FELECTRONICAPOS'',''FCONTINGENCIA'',''FCONTINGENCIAE'') AND
	    s.id_bodega_ppal = '||a.id_bodega||';

	DROP TABLE IF EXISTS aux_facs;
	CREATE TEMP TABLE aux_facs AS
	SELECT DISTINCT
	    d.ndocumento,
		d.fecha,
		COALESCE(rf.prefijo,d.codigo_tipo) AS codigo_tipo
	FROM	    
	    aux_codigo_tipo ac,
	    tercero_def td,
		documentos d
	LEFT OUTER JOIN
		resolucion_documento rd
	ON
		d.ndocumento = rd.ndocumento
	LEFT OUTER JOIN
		resolucion_facturacion rf
	ON
		rd.id_resolucion_facturacion = rf.id_resolucion_facturacion
	WHERE
	    d.ndocumento = td.ndocumento AND
	    d.estado AND
	    d.codigo_tipo = ac.codigo_tipo AND
		CASE WHEN TRIM('''||a.id||''') = ''-1'' THEN TRUE ELSE td.id = '''||a.id||''' END and
	    d.fecha::TIMESTAMP BETWEEN '''||a.fechai||''' AND '''||a.fechaf||'''
	order by
		d.fecha desc
	limit 110;
				
DROP TABLE IF EXISTS aux_proveedor_marca;
CREATE TEMP TABLE aux_proveedor_marca AS
SELECT
		pm.id_marca,
		MAX(pm.id_proveedor) AS id_proveedor
FROM
		proveedor_marca pm
GROUP BY
	pm.id_marca;

DROP TABLE IF EXISTS aux_listado_productos_reporte;
CREATE TEMP TABLE aux_listado_productos_reporte AS
SELECT
    ps.id_prod_serv,
    g.id_char||''-''||g.dv AS nit_proveedor,
    TRIM(COALESCE(g.nombre1,'''')||'' ''||COALESCE(g.nombre2,'''')||'' ''||COALESCE(g.apellido1,'''')||'' ''||COALESCE(g.apellido2,'''')||'' ''||COALESCE(g.razon_social,'''')) AS proveedor,
    TRIM(m.descripcion) AS marca,
    TRIM(sm.descripcion) AS submarca,
    TRIM(l.descripcion) AS linea,
    TRIM(gr.descripcion) AS grupo,
    TRIM(sg.descripcion) AS subgrupo,
	af.codigo_tipo||''-''||d.numero::BIGINT AS documento,
    TRIM(ps.codigo) AS codigo_producto,
    CASE WHEN ps.pcosto = 0 THEN ''*Costo en cero ''||TRIM(i.nombre) ELSE TRIM(i.nombre) END AS descripcion_producto,
    TRIM(i.ref_proveedor) AS referencia,
    TRIM(INITCAP(age.descripcion)) AS tipo_impuesto,
    SUM(CASE WHEN dp.cambio = FALSE THEN dp.cant ELSE dp.cant*-1 END) AS unidades_vendidas,
    ps.pcosto AS costo_original,
    dp.pventa,
    dp.descuento1,
    dp.iva
FROM
    aux_facs af,
    documentos d,
    datos_prod dp,
    prod_serv ps,
    asientos_genericos age,    
	marcas m,    
    item i
LEFT OUTER JOIN
	aux_proveedor_marca pm
ON
	i.id_marca = pm.id_marca
LEFT OUTER JOIN
    general g
ON
	pm.id_proveedor = g.id
LEFT OUTER JOIN
	linea l
ON
	i.id_linea = l.id_linea
LEFT OUTER JOIN
	grupo gr
ON
	i.id_grupo = gr.id_grupo
LEFT OUTER JOIN
	sgrupo sg
ON
	i.id_sgrupo = sg.id_sgrupo
LEFT OUTER JOIN
	submarcas sm
ON
	i.id_submarca = sm.id_submarca
WHERE
    af.ndocumento = d.ndocumento AND
    d.ndocumento = dp.ndocumento AND
    dp.id_prod_serv = ps.id_prod_serv AND
    ps.id_item = i.id_item AND
    ps.id_asiento_generico = age.id_asiento_generico AND
    i.id_marca = m.id_marca AND    
    g.id = pm.id_proveedor AND
    CASE WHEN TRIM('''||a.id_marca||''') = '''' THEN TRUE ELSE m.id_marca::varchar = '''||a.id_marca||''' END
GROUP BY
    ps.id_prod_serv,
    nit_proveedor,
    proveedor,
    marca,
    submarca,
    linea,
    grupo,
    subgrupo,
	documento,
    codigo_producto,
    descripcion_producto,
    referencia,
    tipo_impuesto,
    costo_original,
    dp.pventa,
    descuento1,
    dp.iva;

    DROP TABLE IF EXISTS aux_pinventario_productos;
    CREATE TEMP TABLE aux_pinventario_productos AS
    SELECT DISTINCT ON(i.id_bodega,i.id_prod_serv)
        i.id_bodega,
        i.id_prod_serv,
		CASE WHEN i.salida IS NOT NULL AND i.salida > 0 THEN ROUND(i.valor_sal::NUMERIC,2) ELSE CASE WHEN i.entrada IS NOT NULL AND i.entrada > 0 THEN ROUND(i.valor_ent::NUMERIC,2) END END AS pinventario
        --ROUND(i.pinventario::NUMERIC,2) AS pinventario
    FROM
        inventarios i,
        aux_listado_productos_reporte lp
    WHERE
        lp.id_prod_serv = i.id_prod_serv AND
        i.id_bodega = '||a.id_bodega||' AND
        i.fecha::DATE <= '''||a.fechaf||'''
    ORDER BY
        i.id_bodega,
        i.id_prod_serv,
        i.fecha DESC;
                

DROP TABLE IF EXISTS aux_reporte;
CREATE TEMP TABLE aux_reporte AS
SELECT
		'''||a.nombre_bodega||''' AS nombre_bodega,
        lp.id_prod_serv,
        lp.nit_proveedor,
        lp.proveedor,
        lp.marca,
        lp.submarca,
        lp.linea,
        lp.grupo,
        lp.subgrupo,
		lp.documento,
        lp.codigo_producto,
        lp.descripcion_producto,
        lp.referencia,
        lp.tipo_impuesto,
        lp.unidades_vendidas,
        lp.costo_original,
        lp.pventa,
        lp.descuento1 AS porcentaje_descuento,
        lp.iva,
        COALESCE(api.pinventario,0) AS pinventario,
    ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2) AS pventa_antes_iva,    
    CASE WHEN ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2) != 0 THEN
    ROUND((((ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2)-COALESCE(api.pinventario,0))/ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2))*100)::NUMERIC,2) 
ELSE
	-100 END
	AS porcentaje_utilidad
FROM
      aux_listado_productos_reporte lp
LEFT OUTER JOIN
      aux_pinventario_productos api
ON
      lp.id_prod_serv = api.id_prod_serv;
	'))
FROM
		aux_args a;

DROP TABLE IF EXISTS aux_reporte_remoto;
CREATE TEMP TABLE aux_reporte_remoto AS
SELECT
	nombre_bodega,
    id_prod_serv,
	nit_proveedor,
	proveedor,
	marca,
	submarca,
	linea,
	grupo,
	subgrupo,
	documento,
	codigo_producto,
	descripcion_producto,
	referencia,
	tipo_impuesto,
	unidades_vendidas,
	costo_original,
	pventa,
	porcentaje_descuento,
    iva,
    pinventario,
	pventa_antes_iva,
	porcentaje_utilidad
FROM
	dblink((SELECT cnx FROM remote_cnx),
	'SELECT
		nombre_bodega,
        id_prod_serv,
		nit_proveedor,
		proveedor,
		marca,
		submarca,
		linea,
		grupo,
		subgrupo,
		documento,
		codigo_producto,
		descripcion_producto,
		referencia,
		tipo_impuesto,
		unidades_vendidas,
		costo_original,
		pventa,
		porcentaje_descuento,
        iva,
        pinventario,
		pventa_antes_iva,
		porcentaje_utilidad
	FROM
		aux_reporte') AS r(
		nombre_bodega TEXT,
        id_prod_serv INTEGER,
		nit_proveedor TEXT,
		proveedor TEXT,
		marca TEXT,
		submarca TEXT,
		linea TEXT,
		grupo TEXT,
		subgrupo TEXT,
		documento TEXT,
		codigo_producto TEXT,
		descripcion_producto TEXT,
		referencia TEXT,
		tipo_impuesto TEXT,
		unidades_vendidas FLOAT8,
		costo_original FLOAT8,
		pventa FLOAT8,
		porcentaje_descuento FLOAT8,
        iva FLOAT8,
        pinventario FLOAT8,
		pventa_antes_iva NUMERIC,
		porcentaje_utilidad NUMERIC
);

DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;

--
DROP TABLE IF EXISTS aux_pinventario_ultima_entrada_productos;
CREATE TEMP TABLE aux_pinventario_ultima_entrada_productos AS
SELECT DISTINCT ON(i.id_prod_serv)
    i.id_prod_serv,
    ROUND(i.valor_ent::NUMERIC,2) AS pinventario
FROM
    documentos d,
    inventarios i,
    aux_reporte_remoto lp,
    aux_args a
WHERE
    d.ndocumento = i.ndocumento AND
    d.estado AND
    d.codigo_tipo IN ('EA','RC','IM','AT','IP') AND
    lp.id_prod_serv = i.id_prod_serv AND
    i.fecha::DATE <= a.fechaf
ORDER BY
    i.id_prod_serv,
    i.fecha DESC;
--
DROP TABLE IF EXISTS aux_pinventario_productos_bonificados;
CREATE TEMP TABLE aux_pinventario_productos_bonificados AS
SELECT DISTINCT ON(i.id_prod_serv)
    i.id_prod_serv,
    i.valor_ent AS pinventario
FROM
    documentos d,
    inventarios i,
    aux_pinventario_ultima_entrada_productos apb,
    aux_args a
WHERE
    d.ndocumento = i.ndocumento AND
    d.estado AND
    d.codigo_tipo IN ('EA','RC','IM','AT','IP') AND
    apb.id_prod_serv = i.id_prod_serv AND
    apb.pinventario = 0 AND
    i.valor_ent > 0 AND
    i.fecha::DATE <= a.fechaf
ORDER BY
    i.id_prod_serv,
    i.fecha DESC;


--
DROP TABLE IF EXISTS aux_facs;
CREATE TEMP TABLE aux_facs AS
SELECT DISTINCT
    d.ndocumento,
	rf.prefijo
FROM    
    datos_prod dp,
    aux_args a,
	documentos d
	LEFT OUTER JOIN
		resolucion_documento rd
	ON
		d.ndocumento = rd.ndocumento
	LEFT OUTER JOIN
		resolucion_facturacion rf
	ON
		rd.id_resolucion_facturacion = rf.id_resolucion_facturacion
WHERE
    d.ndocumento = dp.ndocumento AND
    d.estado AND
    d.codigo_tipo IN ('FW','DW','PW') AND
    d.fecha::TIMESTAMP BETWEEN a.fechai AND a.fechaf AND
	a.id_bodega = '1252';
	

DROP TABLE IF EXISTS aux_plataforma_web_documentos;
CREATE TEMP TABLE aux_plataforma_web_documentos AS
SELECT DISTINCT
	a.ndocumento,
	cc.nombre
FROM
	centrocosto cc,
	aux_facs a,
	libro_auxiliar l
WHERE
	a.ndocumento = l.ndocumento AND
	l.id_centrocosto = cc.id_centrocosto;
	
	
DROP TABLE IF EXISTS aux_proveedor_marca;
CREATE TEMP TABLE aux_proveedor_marca AS
SELECT
		pm.id_marca,
		MAX(pm.id_proveedor) AS id_proveedor
FROM
		proveedor_marca pm,
		aux_args a
WHERE
		CASE WHEN a.id = -1 THEN TRUE ELSE pm.id_proveedor = a.id END
GROUP BY
	pm.id_marca;

DROP TABLE IF EXISTS aux_listado_productos_reporte_local;
CREATE TEMP TABLE aux_listado_productos_reporte_local AS
SELECT
    a.nombre_bodega,
	apw.nombre AS plataforma,
    ps.id_prod_serv,
    CASE WHEN a.id = -1 THEN '' ELSE TRIM(g.id_char||'-'||g.dv) END AS nit_proveedor,
    CASE WHEN a.id = -1 THEN '' ELSE TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')) END AS proveedor,
    TRIM(m.descripcion) AS marca,
    TRIM(sm.descripcion) AS submarca,
    TRIM(l.descripcion) AS linea,
    TRIM(gr.descripcion) AS grupo,
    TRIM(sg.descripcion) AS subgrupo,
	COALESCE(af.prefijo,d.codigo_tipo)||'-'||d.numero::BIGINT AS documento,
    TRIM(ps.codigo) AS codigo_producto,
    CASE WHEN ps.pcosto = 0 THEN '*Costo en cero '||TRIM(i.nombre) ELSE TRIM(i.nombre) END AS descripcion_producto,
    TRIM(i.ref_proveedor) AS referencia,
    TRIM(INITCAP(age.descripcion)) AS tipo_impuesto,
    SUM(CASE WHEN dp.cambio = FALSE THEN dp.cant ELSE dp.cant*-1 END) AS unidades_vendidas,	
    ps.pcosto AS costo_original,
    dp.pventa,
    dp.descuento1,
    dp.iva
FROM
    aux_args a,
    aux_facs af,
	aux_plataforma_web_documentos apw,
    documentos d,
    datos_prod dp,
    prod_serv ps,
    asientos_genericos age,
    marcas m,
    item i
LEFT OUTER JOIN
	aux_proveedor_marca pm
ON
	i.id_marca = pm.id_marca
LEFT OUTER JOIN
    general g
ON
	pm.id_proveedor = g.id	
LEFT OUTER JOIN
	linea l
ON
	i.id_linea = l.id_linea
LEFT OUTER JOIN
	grupo gr
ON
	i.id_grupo = gr.id_grupo
LEFT OUTER JOIN
	sgrupo sg
ON
	i.id_sgrupo = sg.id_sgrupo
LEFT OUTER JOIN
	submarcas sm
ON
	i.id_submarca = sm.id_submarca
WHERE
    af.ndocumento = d.ndocumento AND
	af.ndocumento = apw.ndocumento AND
    d.ndocumento = dp.ndocumento AND
    dp.id_prod_serv = ps.id_prod_serv AND
    ps.id_item = i.id_item AND
    ps.id_asiento_generico = age.id_asiento_generico AND
    i.id_marca = m.id_marca AND
    CASE WHEN a.id = -1 THEN TRUE ELSE g.id = a.id END AND
    CASE WHEN TRIM(a.id_marca) = '' THEN TRUE ELSE m.id_marca::VARCHAR  = a.id_marca END
GROUP BY
    a.nombre_bodega,
	apw.nombre,
    ps.id_prod_serv,
    nit_proveedor,
    proveedor,
    marca,
    submarca,
    linea,
    grupo,
    subgrupo,
	documento,
    codigo_producto,
    descripcion_producto,
    referencia,
    tipo_impuesto,
    costo_original,
    dp.pventa,
    dp.descuento1,
    dp.iva;



--
DROP TABLE IF EXISTS aux_pinventario_productos;
CREATE TEMP TABLE aux_pinventario_productos AS
SELECT DISTINCT ON(i.id_bodega,i.id_prod_serv)
    i.id_bodega,
    i.id_prod_serv,
    CASE WHEN i.salida IS NOT NULL AND i.salida > 0 THEN ROUND(i.valor_sal::NUMERIC,2) ELSE CASE WHEN i.entrada IS NOT NULL AND i.entrada > 0 THEN ROUND(i.valor_ent::NUMERIC,2) END END AS pinventario
	--ROUND(i.pinventario::NUMERIC,2) AS pinventario
FROM
    inventarios i,
    aux_listado_productos_reporte_local lp,
    aux_args a
WHERE
    lp.id_prod_serv = i.id_prod_serv AND
    i.id_bodega::VARCHAR = a.id_bodega AND
    i.fecha::DATE <= a.fechaf
ORDER BY
    i.id_bodega,
    i.id_prod_serv,
    i.fecha DESC;
    
--
DROP TABLE IF EXISTS aux_reporte_local;
CREATE TEMP TABLE aux_reporte_local AS
SELECT
		lp.nombre_bodega,
		lp.plataforma,
        lp.id_prod_serv,
        lp.nit_proveedor,
        lp.proveedor,
        lp.marca,
        lp.submarca,
        lp.linea,
        lp.grupo,
        lp.subgrupo,
		lp.documento,
        lp.codigo_producto,
        lp.descripcion_producto,
        lp.referencia,
        lp.tipo_impuesto,
        lp.unidades_vendidas,
        lp.costo_original,
        lp.pventa,
        lp.descuento1 AS porcentaje_descuento,
        lp.iva,
        COALESCE(a.pinventario,0) AS pinventario,
    ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2) AS pventa_antes_iva,    
    CASE WHEN ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2) != 0 THEN
    ROUND((((ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2)-COALESCE(a.pinventario,0))/ROUND((ROUND(((lp.pventa)-((lp.pventa)*(lp.descuento1/100)))::NUMERIC,0)/(1+(lp.iva/100)))::NUMERIC,2))*100)::NUMERIC,2) 
ELSE
	-100 END
	AS porcentaje_utilidad
FROM
    aux_listado_productos_reporte_local lp
LEFT OUTER JOIN
      aux_pinventario_productos a
ON
      lp.id_prod_serv = a.id_prod_serv;

DROP TABLE IF EXISTS aux_pinventario_ultima_entrada_productos_local;
CREATE TEMP TABLE aux_pinventario_ultima_entrada_productos_local AS
SELECT DISTINCT ON(i.id_prod_serv)
    i.id_prod_serv,
    i.valor_ent AS pinventario
FROM
    documentos d,
    inventarios i,
    aux_listado_productos_reporte_local lp,
    aux_args a
WHERE
    d.ndocumento = i.ndocumento AND
    d.estado AND
    d.codigo_tipo IN ('EA','RC','IM','AT','IP') AND
    lp.id_prod_serv = i.id_prod_serv AND
    i.fecha::DATE <= a.fechaf
ORDER BY
    i.id_prod_serv,
    i.fecha DESC;
--
DROP TABLE IF EXISTS aux_pinventario_productos_bonificados_local;
CREATE TEMP TABLE aux_pinventario_productos_bonificados_local AS
SELECT DISTINCT ON(i.id_prod_serv)
    i.id_prod_serv,
    i.valor_ent AS pinventario
FROM
    documentos d,
    inventarios i,
    aux_pinventario_ultima_entrada_productos_local apb,
    aux_args a
WHERE
    d.ndocumento = i.ndocumento AND
    d.estado AND
    d.codigo_tipo IN ('EA','RC','IM','AT','IP') AND
    apb.id_prod_serv = i.id_prod_serv AND
    apb.pinventario = 0 AND
    i.valor_ent > 0 AND
    i.fecha::DATE <= a.fechaf
ORDER BY
    i.id_prod_serv,
    i.fecha DESC;

    
--

SELECT
	nombre_bodega,
	'' AS plataforma,
	nit_proveedor,
	proveedor,
	marca,
	submarca,
	linea,
	grupo,
	subgrupo,
	documento,
	codigo_producto,
	descripcion_producto,
	referencia,
	tipo_impuesto,
	unidades_vendidas,
	foo.pinventario AS costo_unidad, -- costo promedio
	CASE WHEN ROUND(aue.pinventario::NUMERIC,2) > 0 THEN ROUND(aue.pinventario::NUMERIC,2) ELSE CASE WHEN ROUND(apb.pinventario::NUMERIC,2) > 0 THEN ROUND(apb.pinventario::NUMERIC,2) ELSE CASE WHEN foo.costo_original > 0 THEN ROUND(foo.costo_original::NUMERIC,2) ELSE 0 END END END AS pcosto_ult_compra,
	pventa,
	porcentaje_descuento,
	pventa_antes_iva,
	unidades_vendidas*pventa_antes_iva AS valor_total_venta,
	porcentaje_utilidad,    
    CASE WHEN ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2) != 0 THEN
    ROUND((((ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2)-COALESCE(
		CASE WHEN ROUND(aue.pinventario::NUMERIC,2) > 0 THEN ROUND(aue.pinventario::NUMERIC,2) ELSE CASE WHEN ROUND(apb.pinventario::NUMERIC,2) > 0 THEN ROUND(apb.pinventario::NUMERIC,2) ELSE CASE WHEN foo.costo_original > 0 THEN ROUND(foo.costo_original::NUMERIC,2) ELSE 0 END END END,
		0))/ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2))*100)::NUMERIC,2) 
ELSE
	-100 END
	AS porcentaje_utilidad_ult_compra
FROM
	aux_reporte_remoto foo
LEFT OUTER JOIN
    aux_pinventario_ultima_entrada_productos aue
ON
    foo.id_prod_serv = aue.id_prod_serv
LEFT OUTER JOIN
    aux_pinventario_productos_bonificados apb
ON
    foo.id_prod_serv = apb.id_prod_serv
WHERE
	unidades_vendidas != 0
UNION ALL
SELECT
	nombre_bodega,
	plataforma,
	nit_proveedor,
	proveedor,
	marca,
	submarca,
	linea,
	grupo,
	subgrupo,
	documento,
	codigo_producto,
	descripcion_producto,
	referencia,
	tipo_impuesto,
	unidades_vendidas,
	foo.pinventario AS costo_unidad, -- costo promedio
	CASE WHEN ROUND(aue.pinventario::NUMERIC,2) > 0 THEN ROUND(aue.pinventario::NUMERIC,2) ELSE CASE WHEN ROUND(apb.pinventario::NUMERIC,2) > 0 THEN ROUND(apb.pinventario::NUMERIC,2) ELSE CASE WHEN foo.costo_original > 0 THEN ROUND(foo.costo_original::NUMERIC,2) ELSE 0 END END END AS pcosto_ult_compra,
	pventa,
	porcentaje_descuento,
	pventa_antes_iva,
	unidades_vendidas*pventa_antes_iva AS valor_total_venta,
	porcentaje_utilidad,	
    CASE WHEN ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2) != 0 THEN
    ROUND((((ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2)-COALESCE(
		CASE WHEN ROUND(aue.pinventario::NUMERIC,2) > 0 THEN ROUND(aue.pinventario::NUMERIC,2) ELSE CASE WHEN ROUND(apb.pinventario::NUMERIC,2) > 0 THEN ROUND(apb.pinventario::NUMERIC,2) ELSE CASE WHEN foo.costo_original > 0 THEN ROUND(foo.costo_original::NUMERIC,2) ELSE 0 END END END,
		0))/ROUND((ROUND(((foo.pventa)-((foo.pventa)*(foo.porcentaje_descuento/100)))::NUMERIC,0)/(1+(foo.iva/100)))::NUMERIC,2))*100)::NUMERIC,2) 
ELSE
	-100 END
	AS porcentaje_utilidad_ult_compra
FROM
	aux_reporte_local AS foo
LEFT OUTER JOIN
    aux_pinventario_ultima_entrada_productos_local aue
ON
    foo.id_prod_serv = aue.id_prod_serv
LEFT OUTER JOIN
    aux_pinventario_productos_bonificados_local apb
ON
    foo.id_prod_serv = apb.id_prod_serv
WHERE
	foo.unidades_vendidas != 0 AND
	(SELECT COUNT(1) FROM aux_reporte_remoto) = 0
ORDER BY
	nombre_bodega,
	documento,
    marca,
    descripcion_producto;