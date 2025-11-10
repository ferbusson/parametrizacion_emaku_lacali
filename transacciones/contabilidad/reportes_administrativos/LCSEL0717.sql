-- LCSEL0717
--se crea repo_gerencia_ventas_linea_marca en la LCSEL0716

DROP TABLE IF EXISTS temp_lineas_seleccion_reporte;
CREATE TABLE temp_lineas_seleccion_reporte
(       
    seleccion BOOLEAN,
    id_linea SMALLINT,
    id_bodega_ppal SMALLINT
); 

INSERT INTO temp_lineas_seleccion_reporte (seleccion, id_linea, id_bodega_ppal) VALUES
?;
--(4394, FALSE); 
    
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
    (select distinct id_bodega_ppal from temp_lineas_seleccion_reporte) a
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

DROP TABLE IF EXISTS aux_tipo_tercero;
CREATE TEMP TABLE aux_tipo_tercero AS 
SELECT
    (SELECT
        dblink_exec((SELECT cnx FROM remote_cnx),
		'
		DROP TABLE IF EXISTS temp_parametros_reporte_gerencia_lm;
		CREATE TABLE temp_parametros_reporte_gerencia_lm (seleccion boolean,id_bodega_ppal INT, id_linea INT,id_marca INT);
	
		'));

DROP TABLE IF EXISTS aux_tipo_tercero;
CREATE TEMP TABLE aux_tipo_tercero AS 
SELECT
    (SELECT
        dblink_exec((SELECT cnx FROM remote_cnx),
            'INSERT INTO temp_parametros_reporte_gerencia_lm SELECT '''||ps.seleccion||''','||ps.id_bodega_ppal||','||ps.id_linea||''))
FROM
	(SELECT
		t.seleccion,
	    t.id_bodega_ppal,
	    t.id_linea
	from
		temp_lineas_seleccion_reporte t) as ps; -- las paso todas no solo las seleccionadas para que las temporales
												-- la bd remota se creen incluso cuando no hay nada seleccionado,
												-- si no se hace asi se presenta error porque la tabla aux_resultado_final_repo
												-- no existe


DROP TABLE IF EXISTS aux_crea_reporte_remoto;
CREATE TEMP TABLE aux_crea_reporte_remoto AS
SELECT
(SELECT
    dblink_exec((SELECT cnx FROM remote_cnx),
'DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT DISTINCT
    ad.id_administracion_sucursales,
    ad.id_bodega_ppal,
    ad.nombre AS nom_suc,
    CASE WHEN ds.nombre IN (''DEVOLUCION VENTA'',''DVENTA ELECTRONICA'') THEN FALSE ELSE TRUE END AS suma,
    dv.codigo_tipo
FROM
    documentos_standar ds,
    administracion_sucursales ad,
    documentos_sucursales dv,
    (SELECT DISTINCT id_bodega_ppal, fechai, fechaf FROM repo_gerencia_ventas_linea_marca) a
WHERE
    ds.id_documento=dv.id_documento AND
    dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
    CASE WHEN TRIM(a.id_bodega_ppal) = '''' THEN TRUE ELSE ad.id_bodega_ppal=a.id_bodega_ppal::INTEGER END AND
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
    t.id_bodega_ppal,
    d.codigo_tipo,
    d.fecha::DATE AS fecha,
    d.ndocumento,
    t.suma
from
    (SELECT DISTINCT id_bodega_ppal, fechai, fechaf FROM repo_gerencia_ventas_linea_marca) a,
    tipo_docs t,
    documentos d
WHERE
    d.fecha::date BETWEEN a.fechai AND a.fechaf and
    d.estado AND
    d.codigo_tipo = t.codigo_tipo ; -- Solo documentos de la sucursal seleccionada

--

DROP TABLE IF EXISTS aux_ventas_sin_iva;
CREATE TEMP TABLE aux_ventas_sin_iva AS
SELECT
    i.id_linea,
    i.id_marca,
    sum(l.haber)-sum(l.debe) AS valor
FROM
    aux_docs a,
    libro_auxiliar l,
	temp_parametros_reporte_gerencia_lm t,
    prod_serv ps,
    item i,
    cuentas c
WHERE
    a.ndocumento = l.ndocumento AND
	t.seleccion AND
    l.id_prod_serv = ps.id_prod_serv AND
    i.id_linea = t.id_linea AND
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
    i.id_linea,
    i.id_marca
HAVING
    SUM(l.haber)!=0;

--
--
--select sum(unidades_vendidas) from total_und_vendidas
DROP TABLE IF EXISTS total_und_vendidas;
CREATE TEMP TABLE total_und_vendidas AS
SELECT
    a.id_bodega_ppal,
    l.id_linea,
    l.descripcion AS linea,
    m.id_marca,
    m.descripcion AS marca,
    --SUM(CASE WHEN i.id_linea NOT IN (16) AND dp.cambio = FALSE THEN dp.cant WHEN dp.cambio = TRUE THEN dp.cant*-1 ELSE 0 END) AS unidades_vendidas -- servicios, servicios decoracion, impuestos bolsas
	SUM(CASE WHEN i.id_linea NOT IN (16) AND dp.cambio = FALSE THEN dp.cant WHEN i.id_linea NOT IN (16) AND dp.cambio = TRUE THEN dp.cant*-1 WHEN i.id_linea IN (16) THEN 0 END) AS unidades_vendidas -- servicios, servicios decoracion, impuestos bolsas agregada
FROM
    datos_prod dp,
    aux_docs a,
    prod_serv ps,
	temp_parametros_reporte_gerencia_lm t,
    item i,
    linea l,
    marcas m
WHERE   
    a.ndocumento = dp.ndocumento AND
	t.seleccion AND
    ps.id_prod_serv = dp.id_prod_serv AND
    ps.id_item = i.id_item AND
    i.id_linea = l.id_linea AND
    i.id_linea = t.id_linea AND
    i.id_marca = m.id_marca
GROUP BY
    a.id_bodega_ppal,
    l.id_linea,
    l.descripcion,
    m.id_marca,
    m.descripcion;
--

DROP TABLE IF EXISTS total_costo_linea;
CREATE TEMP TABLE total_costo_linea AS
SELECT  
    i.id_linea,
    i.id_marca,
    SUM(CASE WHEN i.id_linea NOT IN (16) THEN inv.valor_sal * inv.salida ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas agregada
	--SUM(CASE WHEN i.id_linea NOT IN (16) THEN (coalesce(inv.valor_sal,0) * coalesce(inv.salida,0)) - (coalesce(inv.valor_ent,0) * coalesce(inv.entrada,0) )ELSE 0 END) AS costo --servicios, servicios decoracion, impuestos bolsas
FROM
    inventarios inv,
    aux_docs a,
	temp_parametros_reporte_gerencia_lm t,
    prod_serv ps,
    item i
WHERE   
    a.ndocumento = inv.ndocumento AND
    --a.suma AND
	t.seleccion AND
    --inv.salida IS NOT NULL AND inv.salida != 0 AND
    ps.id_prod_serv = inv.id_prod_serv AND
    ps.id_item = i.id_item AND
    i.id_linea = t.id_linea
GROUP BY
    i.id_linea,
    i.id_marca;

--
DROP TABLE IF EXISTS aux_resultado_final_repo;
CREATE TEMP TABLE aux_resultado_final_repo AS
SELECT
    tuv.id_bodega_ppal,
    tuv.id_linea,
    tuv.id_marca,
    tuv.linea,  
    tuv.marca,
    ROUND(CASE WHEN si.valor != 0 THEN ROUND(((si.valor / SUM(si.valor) OVER())*100)::NUMERIC,2) ELSE 0 END::NUMERIC,2) AS participacion,
    si.valor,
    tuv.unidades_vendidas,
    cl.costo,
    CASE WHEN si.valor != 0 THEN ROUND((((si.valor - cl.costo) / si.valor)*100)::NUMERIC,2) ELSE 0 END AS utilidad,
    ROW_NUMBER() OVER(ORDER BY tuv.linea,si.valor DESC) AS orden
FROM
    total_und_vendidas tuv,
    aux_ventas_sin_iva si,
    total_costo_linea cl
WHERE
    tuv.id_linea = si.id_linea AND
    tuv.id_marca = si.id_marca AND
    tuv.id_linea = cl.id_linea AND
    tuv.id_marca = cl.id_marca AND
    tuv.unidades_vendidas != 0
ORDER BY
	tuv.linea,
    si.valor DESC
'))
FROM
    temp_parametros_reporte_gerencia_lm a;
--

DROP TABLE IF EXISTS aux_reporte_final_remoto;
CREATE TEMP TABLE aux_reporte_final_remoto AS
select
    id_bodega_ppal::varchar as id_bodega_ppal,
    id_linea::varchar as id_linea,
    id_marca::varchar as id_marca,
    linea,
    marca,
    participacion,
    valor,
    unidades_vendidas,
    costo,
    utilidad,
    orden
FROM
    dblink((SELECT cnx FROM remote_cnx),
    'SELECT
        id_bodega_ppal,
        id_linea,
        id_marca,
        linea,
        marca,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        orden
    FROM
        aux_resultado_final_repo
	') AS r(
        id_bodega_ppal INTEGER,
        id_linea INTEGER,
        id_marca INTEGER,
        linea VARCHAR,
        marca VARCHAR,
        participacion FLOAT8,
        valor FLOAT8,
        unidades_vendidas INTEGER,
        costo FLOAT8,
        utilidad FLOAT8,
        orden INTEGER
);


DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;

    
DROP TABLE IF EXISTS aux_suma_resultado_final_repo;
CREATE TEMP TABLE aux_suma_resultado_final_repo AS
select
    '-1'::VARCHAR as id_linea,
    '-1'::VARCHAR as id_marca,
    '-1'::VARCHAR as id_bodega_ppal,
    'TOTAL'::VARCHAR AS linea,
    ''::VARCHAR AS marca,
    SUM(participacion) AS participacion,
    SUM(valor) AS valor,
    SUM(unidades_vendidas) AS unidades_vendidas,
    SUM(costo) AS costo,
    ROUND(CASE WHEN SUM(valor) != 0 THEN ROUND((((SUM(valor) - SUM(costo)) / SUM(valor))*100)::NUMERIC,2) ELSE 0 END::NUMERIC,2) AS utilidad,
    999999999 AS orden
FROM
    aux_reporte_final_remoto;


SELECT
    linea,
    marca,
    participacion,
    valor,
    unidades_vendidas,
    costo,
    utilidad,
    false as ver_detalle,
    id_linea,
    id_marca,
    id_bodega_ppal,
    color
FROM
    (select
        id_linea,
        id_marca,
        id_bodega_ppal,
        linea,
        marca,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        orden,
        0::INTEGER AS color
    FROM
        aux_reporte_final_remoto
    UNION
    select
        id_linea,
        id_marca,
        id_bodega_ppal,
        linea,
        marca,
        participacion,
        valor,
        unidades_vendidas,
        costo,
        utilidad,
        orden,
        -1::INTEGER AS color
    FROM
        aux_suma_resultado_final_repo) AS foo
ORDER BY
    orden;