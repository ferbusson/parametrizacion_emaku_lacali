/*
    Logica del reporte:
    Listar los documentos que se hayan seleccionado en el combo que se encuentren en el rango de fechas que se seleccione y que pertenezcan al tercero seleccionado.
    Si no se selecciona tercero listar todos los documentos del periodo.
    Las fechas deben ser las fechas de registro en sistema, para estos documentos es la que corresponde a registro_modificacion.    
    Las DC que se listen deben pertenecer al periodo seleccionado independientemente de que le correspondan al alguna de las entradas pero si deben corresponder al profijo seleccionado y al tercero: EA IM RC o IP (docs de entrada)
    Listar los productos en el mismo orden de cuando se creo el documento (orden de datos_prod)
    Ej: Se listan RC de mes de agosto y DC que correspondan a alguna RC así estas DC no le correspondan a una RC en particular del periodo
    Sep - 16 - 2022     
*/

DROP TABLE IF EXISTS aux_parametros_repo;
CREATE TEMP TABLE aux_parametros_repo AS
SELECT
    foo.codigo_tipo,
    foo.fechai,
    foo.fechaf,
    COALESCE(g.id,'-1') AS id -- si no se selecciona tercero id = -1
FROM
    (SELECT
        '?'::CHARACTER(2) AS codigo_tipo,
        '?'::DATE AS fechai,
        '?'::DATE AS fechaf,
        '?'::VARCHAR AS id_char) AS foo
LEFT OUTER JOIN
    general g
ON
    foo.id_char = g.id_char;

DROP TABLE IF EXISTS aux_devoluciones_reporte;
CREATE TEMP TABLE aux_devoluciones_reporte AS
SELECT    
    d2.ndocumento --ndocumento de devoluciones en compra
FROM    
    aux_parametros_repo a,
    documentos d,
    registro_modificacion rm,
    info_documento i,
    documentos d2
WHERE
    d2.ndocumento = rm.ndocumento AND
    rm.id_tipo_modificacion = 0 AND
    CASE WHEN a.codigo_tipo = 'RC' THEN d.codigo_tipo IN ('RC','AT') ELSE d.codigo_tipo = a.codigo_tipo END AND
    rm.fecha::DATE BETWEEN a.fechai AND a.fechaf AND
    d.ndocumento = i.rf_documento AND
    d.estado AND
    d2.ndocumento = i.ndocumento AND
    d2.estado AND
    d2.codigo_tipo IN ('DC','DO') --DC: dev en compras, DO: dev doc sop en compras
UNION
SELECT
	d2.ndocumento --ndocumento de devoluciones merc en consignacion
FROM	
	aux_parametros_repo a,
	registro_modificacion rm,
	documentos d2
WHERE
	d2.ndocumento = rm.ndocumento AND
	rm.id_tipo_modificacion = 0 AND
	a.codigo_tipo = 'IM' AND
	rm.fecha::DATE BETWEEN a.fechai AND a.fechaf AND
	d2.estado AND
	d2.codigo_tipo IN ('DM'); --DM: dev merc en consignacion


DROP TABLE IF EXISTS aux_valores_base;
CREATE TEMP TABLE aux_valores_base AS
SELECT
    d.ndocumento,
    d.fecha AS fecha_factura_proveedor,
    d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
    m.descripcion AS marca,
    COALESCE(sm.descripcion,'') AS submarca,
    l.descripcion AS linea,
    g.descripcion AS grupo,
    sg.descripcion AS sub_grupo,
    ps.codigo,
    i.ref_proveedor,
    i.nombre AS descripcion,
    dp.descuento1 AS pdcto,
    dp.iva AS piva,
    CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END AS cant,
    dp.pventa AS vunitario, 
    dp.orden,
    ROUND((CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END*dp.pventa)::NUMERIC,2) AS stotal, -- STOTAL
    ROUND((CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END*dp.pventa*(dp.descuento1/100))::NUMERIC,0) AS vdescuento -- VDESCUENTO
FROM
    documentos d,
    registro_modificacion rm,
    datos_documento dd,
    aux_parametros_repo a,
    datos_prod dp,
    tercero_def t,
    prod_serv ps,
    marcas m,
    linea l,
    grupo g,
    sgrupo sg,
    item i
LEFT OUTER JOIN
    submarcas sm
ON
    i.id_submarca = sm.id_submarca
WHERE
    d.ndocumento = rm.ndocumento AND
        rm.id_tipo_modificacion = 0 AND
    d.ndocumento = dp.ndocumento AND
    d.ndocumento = t.ndocumento AND
    CASE WHEN a.id = '-1' THEN TRUE ELSE a.id = t.id END AND
    dp.id_prod_serv = ps.id_prod_serv AND
    ps.id_item = i.id_item AND
    i.id_marca = m.id_marca AND
    i.id_linea = l.id_linea AND
    i.id_grupo = g.id_grupo AND
    i.id_sgrupo = sg.id_sgrupo AND
    d.ndocumento = dd.ndocumento AND
    CASE WHEN a.codigo_tipo = 'RC' THEN d.codigo_tipo IN ('RC','AT') ELSE d.codigo_tipo = a.codigo_tipo END AND
    d.estado AND
    rm.fecha::DATE BETWEEN a.fechai AND a.fechaf
UNION ALL
SELECT
    d.ndocumento,
    d.fecha AS fecha_factura_proveedor,
    d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
    m.descripcion AS marca,
    COALESCE(sm.descripcion,'') AS submarca,
    l.descripcion AS linea,
    g.descripcion AS grupo,
    sg.descripcion AS sub_grupo,
    ps.codigo,
    i.ref_proveedor,
    i.nombre AS descripcion,
    dp.descuento1 AS pdcto,
    dp.iva AS piva,    
    CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END AS cant,
    dp.pventa AS vunitario, 
	dp.orden,
    ROUND((CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END*dp.pventa)::NUMERIC,2) AS stotal, -- STOTAL
    ROUND((CASE WHEN d.codigo_tipo = 'DC' THEN dp.cant*-1 ELSE dp.cant END*dp.pventa*(dp.descuento1/100))::NUMERIC,0) AS vdescuento -- VDESCUENTO
FROM
    documentos d,
	aux_parametros_repo apr,
    aux_devoluciones_reporte a,
    datos_prod dp,
    tercero_def t,
    prod_serv ps,
    marcas m,
    linea l,
    grupo g,
    sgrupo sg,
    item i
LEFT OUTER JOIN
    submarcas sm
ON
    i.id_submarca = sm.id_submarca
WHERE
    d.ndocumento = dp.ndocumento AND
    d.ndocumento = t.ndocumento AND
	CASE WHEN apr.id = '-1' THEN TRUE ELSE apr.id = t.id END AND
    dp.id_prod_serv = ps.id_prod_serv AND
    ps.id_item = i.id_item AND
    i.id_marca = m.id_marca AND
    i.id_linea = l.id_linea AND
    i.id_grupo = g.id_grupo AND
    i.id_sgrupo = sg.id_sgrupo AND
    d.ndocumento = a.ndocumento AND
    d.estado;

DROP TABLE IF EXISTS aux_subtotales;
CREATE TEMP TABLE aux_subtotales AS
SELECT
    a.ndocumento,
    a.fecha_factura_proveedor,
    a.numero,
    TRIM(a.marca) AS marca,
    TRIM(a.submarca) AS submarca,
    TRIM(a.linea) AS linea,
    TRIM(a.grupo) AS grupo,
    TRIM(a.sub_grupo) AS sub_grupo,
    TRIM(a.codigo) AS codigo,
    TRIM(a.ref_proveedor) AS ref_proveedor,
    TRIM(a.descripcion) AS descripcion,
    a.pdcto,
    a.piva,
    a.cant,
    case when a.cant != 0 then ROUND(((a.stotal - a.vdescuento) / a.cant)::NUMERIC,2) else 0 end AS vunitario_neto_adi, -- vunitario neto antes de iva
    a.stotal-a.vdescuento AS total_neto_adi, -- total neto antes de iva
    a.orden
FROM
    aux_valores_base a;

--

DROP TABLE IF EXISTS aux_info_cabecera_documento;
CREATE TEMP TABLE aux_info_cabecera_documento AS
SELECT
    d.ndocumento,
    TRIM(g.id_char) AS id_char,
    TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')) AS tercero,
    LTRIM(g.nombre_comercial) AS nombre_comercial,
    MAX(rm.fecha)::TIMESTAMP AS fecha_registro_sistema,
    d.fecha::DATE AS fecha_fac_proveedor,
    COALESCE(rf.prefijo,d.codigo_tipo) AS prefijo,
    d.numero::BIGINT AS numero_orden,
    COALESCE(rf.prefijo,d.codigo_tipo)||'-'||d.numero::BIGINT AS numero,
    TRIM(i.ex_documento) AS fac_proveedor
FROM    
    tercero_def t,
    info_documento i,
    aux_parametros_repo a,
    general g,
    registro_modificacion rm,
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
    d.ndocumento = t.ndocumento AND
    d.ndocumento = i.ndocumento AND
    d.ndocumento = rm.ndocumento AND
    rm.id_tipo_modificacion = 0 AND
    t.id = g.id AND
    CASE WHEN a.id = '-1' THEN TRUE ELSE a.id = t.id END AND
    CASE WHEN a.codigo_tipo = 'RC' THEN d.codigo_tipo IN ('RC','AT') ELSE d.codigo_tipo = a.codigo_tipo END AND
    d.estado AND
    rm.fecha::DATE BETWEEN a.fechai AND a.fechaf
GROUP BY
    d.ndocumento,
    g.id_char,
    TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')),
    LTRIM(g.nombre_comercial),
    d.fecha::DATE,
    COALESCE(rf.prefijo,d.codigo_tipo),
    d.codigo_tipo||'-'||d.numero::BIGINT,
    CASE WHEN rf.prefijo IS NOT NULL THEN rf.prefijo ELSE d.codigo_tipo END,
    d.numero::BIGINT,
    i.ex_documento
UNION ALL
SELECT
    d.ndocumento,
    TRIM(g.id_char) AS id_char,
    TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')) AS tercero,
    LTRIM(g.nombre_comercial) AS nombre_comercial,
    MAX(rm.fecha)::TIMESTAMP AS fecha_registro_sistema,
    d.fecha::DATE AS fecha_fac_proveedor,
    COALESCE(rf.prefijo,d.codigo_tipo) AS prefijo,
    d.numero::BIGINT AS numero_orden,
    COALESCE(rf.prefijo,d.codigo_tipo)||'-'||d.numero::BIGINT AS numero,
    COALESCE(TRIM(i.ex_documento),'') AS fac_proveedor
FROM    
    tercero_def t,
    info_documento i,
    aux_devoluciones_reporte a,
    general g,
    registro_modificacion rm,
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
    d.ndocumento = t.ndocumento AND
    d.ndocumento = i.ndocumento AND
    d.ndocumento = rm.ndocumento AND
    rm.id_tipo_modificacion = 0 AND
    t.id = g.id AND
    d.ndocumento = a.ndocumento AND
    d.estado
GROUP BY
    d.ndocumento,
    g.id_char,
    TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')),
    LTRIM(g.nombre_comercial),
    d.fecha::DATE,
    COALESCE(rf.prefijo,d.codigo_tipo),
    d.codigo_tipo||'-'||d.numero::BIGINT,
    CASE WHEN rf.prefijo IS NOT NULL THEN rf.prefijo ELSE d.codigo_tipo END,
    d.numero::BIGINT,
    i.ex_documento;

SELECT
    acd.id_char,
    acd.tercero,
    acd.nombre_comercial,
    to_char(acd.fecha_registro_sistema, 'YYYY-MM-dd HH24:MI:SS')::VARCHAR AS fecha_registro_sistema,
    acd.numero,
    acd.fac_proveedor,
    acd.fecha_fac_proveedor::varchar as fecha_fac_proveedor,
    a.marca,
    a.submarca,
    a.linea,
    a.grupo,
    a.sub_grupo,
    a.codigo,
    a.ref_proveedor,
    a.descripcion,
    a.pdcto,
    a.piva,
    a.cant,
    a.vunitario_neto_adi, -- vunitario neto antes de iva
    a.total_neto_adi
FROM
    aux_info_cabecera_documento acd,
    aux_subtotales a
WHERE
    acd.ndocumento = a.ndocumento
ORDER BY
    acd.prefijo DESC,
    a.orden ASC,
    acd.numero_orden ASC;