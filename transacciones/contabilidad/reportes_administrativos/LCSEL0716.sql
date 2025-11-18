-- LCSEL0716

DROP TABLE IF EXISTS aux_parametros_reporte;
CREATE TEMP TABLE aux_parametros_reporte AS
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
    aux_parametros_reporte a
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
'DROP TABLE IF EXISTS repo_gerencia_ventas_linea_marca;
DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT DISTINCT
    ad.id_administracion_sucursales,
    ad.nombre AS nom_suc,
    CASE WHEN ds.nombre IN (''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'') THEN FALSE ELSE TRUE END AS suma,
    dv.codigo_tipo
FROM
    documentos_standar ds,
    administracion_sucursales ad,
    documentos_sucursales dv
WHERE
    ds.id_documento=dv.id_documento AND
    dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal='''||a.id_bodega_ppal||''' END AND
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
    t.id_administracion_sucursales,
    t.nom_suc,
    d.codigo_tipo,
    d.fecha::DATE AS fecha,
    d.ndocumento,
    t.suma,
    '''||a.id_bodega_ppal||'''::VARCHAR AS id_bodega_ppal,
    '''||a.fechai||'''::DATE AS fechai,
    '''||a.fechaf||'''::DATE AS fechaf
from
    tipo_docs t,
    documentos d
WHERE
    d.fecha::date BETWEEN '''||a.fechai||''' AND '''||a.fechaf||''' and
    d.estado AND
    d.codigo_tipo = t.codigo_tipo ; -- Solo documentos de la sucursal seleccionada

--

DROP TABLE IF EXISTS aux_ventas_sin_iva;
CREATE TEMP TABLE aux_ventas_sin_iva AS
SELECT
    i.id_linea,
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
	i.id_linea NOT IN (16) AND -- agregada
    c.id_cta = l.id_cta AND
    c.char_cta IN (''41355610'',''41755610'', -- mercancia excluida
                  ''41355615'',''41755615'', -- mercancia exenta
                  ''4135560501'',''4175560501'', -- mercancia 5%
                  ''4135560502'',''4175560502'', --mercancia 19%
                  ''4135562001'' -- servicios 19%
                  )
GROUP BY
    i.id_linea
HAVING
    SUM(l.haber)!=0;

--
--

DROP TABLE IF EXISTS total_und_vendidas;
CREATE TEMP TABLE total_und_vendidas AS
SELECT
    l.id_linea,
    l.descripcion AS linea,
    a.id_bodega_ppal,
    a.fechai,
    a.fechaf,
    --SUM(CASE WHEN i.id_linea NOT IN (16) AND dp.cambio = FALSE THEN dp.cant WHEN dp.cambio = TRUE THEN dp.cant*-1 ELSE 0 END) AS unidades_vendidas -- servicios, servicios decoracion, impuestos bolsas
    SUM(CASE WHEN i.id_linea NOT IN (16) AND dp.cambio = FALSE THEN dp.cant WHEN i.id_linea NOT IN (16) AND dp.cambio = TRUE THEN dp.cant*-1 WHEN i.id_linea IN (16) THEN 0 END) AS unidades_vendidas -- servicios, servicios decoracion, impuestos bolsas agregada
FROM
    datos_prod dp,
    aux_docs a,
    prod_serv ps,
    item i,
    linea l,
    marcas m
WHERE   
    a.ndocumento = dp.ndocumento AND
    ps.id_prod_serv = dp.id_prod_serv AND
    ps.id_item = i.id_item AND
    i.id_linea = l.id_linea AND
    i.id_marca = m.id_marca
GROUP BY
    l.id_linea,
    l.descripcion,
    a.id_bodega_ppal,
    a.fechai,
    a.fechaf
ORDER BY
    unidades_vendidas DESC;
--

DROP TABLE IF EXISTS total_costo_linea;
CREATE TEMP TABLE total_costo_linea AS
SELECT  
    i.id_linea,
    --SUM(CASE WHEN i.id_linea NOT IN (16) THEN inv.pinventario * inv.salida ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas
    --SUM(CASE WHEN i.id_linea NOT IN (16) THEN inv.valor_sal * inv.salida ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas
	-- Marzo 12 2024: Se comenta linea anterior porque no tiene en cuenta el movimiento de costo de devoluciones si solo se tiene en cuenta salidas
	--SUM(CASE WHEN i.id_linea NOT IN (16) THEN inv.valor_sal * inv.salida ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas agregada
	SUM(CASE WHEN i.id_linea NOT IN (16) THEN (coalesce(inv.valor_sal,0) * coalesce(inv.salida,0)) - (coalesce(inv.valor_ent,0) * coalesce(inv.entrada,0) )ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas
FROM
    inventarios inv,
    aux_docs a,
    prod_serv ps,
    item i
WHERE   
    a.ndocumento = inv.ndocumento AND
    --a.suma AND
    -- Marzo 12 2024: Se comenta linea anterior porque no tiene en cuenta el movimiento de costo de devoluciones si solo se tiene en cuenta salidas
    --inv.salida IS NOT NULL AND inv.salida != 0 AND
	-- Marzo 12 2024: Se comenta linea anterior porque no tiene en cuenta el movimiento de costo de devoluciones si solo se tiene en cuenta salidas
    ps.id_prod_serv = inv.id_prod_serv AND
    ps.id_item = i.id_item
GROUP BY
    i.id_linea;

--

CREATE TABLE repo_gerencia_ventas_linea_marca AS
SELECT
    tuv.linea,
    ROUND(CASE WHEN si.valor != 0 THEN ROUND(((si.valor / SUM(si.valor) OVER())*100)::NUMERIC,2) ELSE 0 END::NUMERIC,2) AS participacion,
    si.valor,
    tuv.unidades_vendidas,
    cl.costo,
    --CASE WHEN si.valor != 0 THEN ROUND((((si.valor - cl.costo) / si.valor)*100)::NUMERIC,2) ELSE 0 END AS utilidad,
	ROUND(CASE WHEN COALESCE(si.valor,0) != 0 THEN ((COALESCE(si.valor,0)-ROUND(cl.costo::NUMERIC,2))/COALESCE(si.valor,0))*100.0 ELSE 0.0 END::NUMERIC,2)AS utilidad, --agregada
    FALSE AS seleccion,
    tuv.id_linea,
    tuv.id_bodega_ppal,
    tuv.fechai,
    tuv.fechaf
FROM
    total_und_vendidas tuv,
    aux_ventas_sin_iva si,
    total_costo_linea cl
WHERE
    tuv.id_linea = si.id_linea AND
    tuv.id_linea = cl.id_linea AND
    tuv.unidades_vendidas != 0
ORDER BY
    si.valor DESC;
    
--
DROP TABLE IF EXISTS aux_resultado_final_repo;
CREATE TEMP TABLE aux_resultado_final_repo AS
SELECT
    linea,
    participacion,
    valor,
    unidades_vendidas,
    costo,
    utilidad,
    seleccion,
    id_linea,
	id_bodega_ppal,
    ROW_NUMBER() OVER() AS orden
FROM
    repo_gerencia_ventas_linea_marca
ORDER BY
    valor DESC;

'))
FROM
    aux_parametros_reporte a;

DROP TABLE IF EXISTS aux_reporte_final_remoto;
CREATE TEMP TABLE aux_reporte_final_remoto AS
SELECT
    linea,
    participacion,
    valor,
    unidades_vendidas,
    costo,
    utilidad,
    seleccion,
    id_linea,
	id_bodega_ppal,
    orden
FROM
    dblink((SELECT cnx FROM remote_cnx),
    'SELECT
        linea,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        seleccion,
        id_linea,
		id_bodega_ppal,
        orden
    FROM
        aux_resultado_final_repo') AS r(
        linea VARCHAR,
        participacion FLOAT8,
        valor FLOAT8,
        unidades_vendidas INTEGER,
        costo FLOAT8,
        utilidad FLOAT8,
        seleccion BOOLEAN,
        id_linea INTEGER,
		id_bodega_ppal INTEGER,
        orden INTEGER
);

DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;


--

DROP TABLE IF EXISTS aux_suma_resultado_final_repo;
CREATE TEMP TABLE aux_suma_resultado_final_repo AS
SELECT
    'TOTAL'::VARCHAR AS linea,
    SUM(participacion) AS participacion,
    SUM(valor) AS valor,
    SUM(unidades_vendidas) AS unidades_vendidas,
    SUM(costo) AS costo,
    CASE WHEN SUM(valor) != 0 THEN ROUND((((SUM(valor) - SUM(costo)) / SUM(valor))*100)::NUMERIC,2) ELSE 0 END AS utilidad,
    FALSE AS seleccion,
    -1 AS id_linea,
	id_bodega_ppal,
    999999999 AS orden
FROM
    aux_reporte_final_remoto
GROUP BY
	id_bodega_ppal;
    
    
SELECT
    linea,
    participacion,
    valor,
    unidades_vendidas,
    costo,
    utilidad,
    seleccion,
    id_linea,
	id_bodega_ppal,
    color
FROM
    (SELECT
        linea,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        seleccion,
        id_linea,
	 	id_bodega_ppal,
        orden,
        0::INTEGER AS color
    FROM
        aux_reporte_final_remoto
    UNION
    SELECT
        linea,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        seleccion,
        id_linea,
	 	id_bodega_ppal,
        orden,
        -1::INTEGER AS color
    FROM
        aux_suma_resultado_final_repo) AS foo
ORDER BY
    orden;