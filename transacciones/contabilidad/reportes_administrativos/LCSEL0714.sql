-- LCSEL0714
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
'DROP TABLE IF EXISTS tipo_docs;
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
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal::VARCHAR='''||a.id_bodega_ppal||''' END AND
    ds.nombre IN (''FACTURACION'',
                  ''FMANUAL'',
                  ''FELECTRONICAPOS'',
                  ''FCONTINGENCIAE'',
                  ''FCREDITO'',
                  ''FCONTINGENCIA'',
                  ''CAMBIOS'',
                  ''DEVOLUCION VENTA'',
                  ''DVENTA ELECTRONICA'',
                 ''COMPROBANTES INGRESO'');

-- se excluyen comprobantes de ingreso, se usa para controlar las consignaciones factura multipago
DROP TABLE IF EXISTS tipo_docs_solo_facturacion;
CREATE TEMP TABLE tipo_docs_solo_facturacion AS
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
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal::VARCHAR='''||a.id_bodega_ppal||''' END AND
    ds.nombre IN (''FACTURACION'',
                  ''FMANUAL'',
                  ''FELECTRONICAPOS'',
                  ''FCONTINGENCIAE'',
                  ''FCREDITO'',
                  ''FCONTINGENCIA'',
                  ''CAMBIOS'',
                  ''DEVOLUCION VENTA'',
                  ''DVENTA ELECTRONICA'');

DROP TABLE IF EXISTS tipo_doc_comprobante;
CREATE TEMP TABLE tipo_doc_comprobante AS
SELECT DISTINCT
    ad.id_administracion_sucursales,
    dv.codigo_tipo
FROM
    documentos_standar ds,
    administracion_sucursales ad,
    documentos_sucursales dv
WHERE
    ds.id_documento=dv.id_documento AND
    dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal='''||a.id_bodega_ppal||''' END AND
    ds.nombre IN (''COMPROBANTES INGRESO'',
                 ''CAMBIOS'',
                  ''DEVOLUCION VENTA'',
                  ''DVENTA ELECTRONICA'');

DROP TABLE IF EXISTS tipo_doc_devoluciones;
CREATE TEMP TABLE tipo_doc_devoluciones AS
SELECT DISTINCT
    ad.id_administracion_sucursales,
    dv.codigo_tipo
FROM
    documentos_standar ds,
    administracion_sucursales ad,
    documentos_sucursales dv
WHERE
    ds.id_documento=dv.id_documento AND
    dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal='''||a.id_bodega_ppal||''' END AND
    ds.nombre IN (''DEVOLUCION VENTA'',
                  ''DVENTA ELECTRONICA'');

DROP TABLE IF EXISTS tipo_doc_abonos_cartera;
CREATE TEMP TABLE tipo_doc_abonos_cartera AS
SELECT DISTINCT
    ad.id_administracion_sucursales,
    dv.codigo_tipo
FROM
    documentos_standar ds,
    administracion_sucursales ad,
    documentos_sucursales dv
WHERE
    ds.id_documento=dv.id_documento AND
    dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
    CASE WHEN TRIM('''||a.id_bodega_ppal||''') = '''' THEN TRUE ELSE ad.id_bodega_ppal='''||a.id_bodega_ppal||''' END AND
    ds.nombre IN (''COMPROBANTES INGRESO'');

DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
    t.id_administracion_sucursales,
    t.nom_suc,
    d.codigo_tipo,
    d.fecha::DATE AS fecha,
    d.ndocumento,
    t.suma
from
    tipo_docs t,
    documentos d
WHERE
    d.fecha::date BETWEEN '''||a.fechai||''' AND '''||a.fechaf||''' and
    d.estado AND
    d.codigo_tipo = t.codigo_tipo ; -- Solo documentos de la sucursal seleccionada
    
    
DROP TABLE IF EXISTS aux_facs_credito;
CREATE TEMP TABLE aux_facs_credito AS
SELECT
    l.ndocumento,
    l.fecha::DATE AS fecha,
    SUM(l.debe) AS debe,
    SUM(l.haber) AS haber
FROM
    aux_docs a,
    cuentas c, 
    libro_auxiliar l
WHERE
    a.ndocumento = l.ndocumento AND    
    c.id_cta=l.id_cta AND
    l.debe != 0 AND
    c.char_cta LIKE ''1305%'' -- Se pone like para que tenga en cuenta todas las facturas incluidas plataformas web Feb 27 2021
GROUP BY
    l.ndocumento,
    l.fecha::DATE;


DROP TABLE IF EXISTS aux_abonos_facs_credito;
CREATE TEMP TABLE aux_abonos_facs_credito AS
SELECT
    c.ncomprobante,
    d.fecha::DATE AS fecha_comprobante,
    -1*SUM(COALESCE(c.cargo_comprobante,0)-(COALESCE(c.abono_comprobante,0)+COALESCE(c.dcto_comprobante,0))) AS abono_comprobante
FROM
    aux_docs a,
    tipo_doc_comprobante td,
    documentos d,
    documentos d2,
    cartera c
WHERE
    c.ncomprobante = a.ndocumento AND
    c.nfactura = d2.ndocumento AND
    d2.estado AND
    c.ncomprobante = d.ndocumento AND
    a.fecha::DATE = d.fecha::DATE AND
    --CASE WHEN d.codigo_tipo IN (SELECT codigo_tipo FROM tipo_doc_devoluciones) THEN TRUE ELSE a.fecha::DATE = d2.fecha::DATE END AND
    d.codigo_tipo = td.codigo_tipo AND
    d.estado
GROUP BY
    c.ncomprobante,
    d.fecha;

-- Uso la UNION para tener en cuenta devoluciones que se hagan en efectivo, estas no registran en cartera y es necesario tenerlas en cuenta
DELETE FROM 
    aux_docs AS a
USING 
    (SELECT
        d.ndocumento
    FROM
        aux_docs a,
        documentos d,
        documentos d2,
        tipo_doc_comprobante td,
        cartera c
    WHERE
        a.ndocumento = d.ndocumento AND
        d.codigo_tipo = td.codigo_tipo AND
        a.ndocumento = c.ncomprobante AND
        c.nfactura = d2.ndocumento AND
        d2.estado AND
        d2.fecha::DATE != a.fecha::DATE
    ) AS foo
WHERE
    a.ndocumento = foo.ndocumento;


DROP TABLE IF EXISTS aux_abonos_ci_tarjeta;
CREATE TEMP TABLE aux_abonos_ci_tarjeta AS
SELECT
    a.fecha_comprobante,
    SUM(t.valor) AS valor
FROM
    tarjetas t,
    tcredito tc,
    aux_abonos_facs_credito a,
    cuentas c
WHERE
    t.ndocumento=a.ncomprobante AND
    t.id_tcredito = tc.id_tcredito AND
    tc.tipo NOT IN (''TR'') AND --estas tarjetas se usan para pagos con nequi y demás ...se tratan como consignaciones y tienen apartado propio
    t.id_cta = c.id_cta AND
    c.char_cta NOT IN (''28050504'')  -- no se incluyen tarjetas regalo porque tienen seccion aparte mas abajo
GROUP BY
    a.fecha_comprobante;


DROP TABLE IF EXISTS aux_abonos_ci_consignaciones;
CREATE TEMP TABLE aux_abonos_ci_consignaciones AS
SELECT
    COALESCE(foo.fecha_comprobante,foo2.fecha_comprobante) AS fecha_comprobante,
    COALESCE(foo.valor,0) + COALESCE(foo2.valor,0) AS valor
FROM    
    (SELECT
        a.fecha_comprobante,
        SUM(t.valor) AS valor
    FROM
        tarjetas t,
        tcredito tc,
        aux_abonos_facs_credito a,
        cuentas c
    WHERE
        t.ndocumento=a.ncomprobante AND
        t.id_tcredito = tc.id_tcredito AND
        tc.tipo = ''TR'' AND --estas tarjetas se usan para pagos con nequi y demás ...se tratan como consignaciones
        t.id_cta = c.id_cta AND
        c.char_cta NOT IN (''28050504'')  -- no se incluyen tarjetas regalo porque tienen seccion aparte mas abajo
    GROUP BY
        a.fecha_comprobante) AS foo
FULL OUTER JOIN
    (SELECT
        a.fecha_comprobante,
        SUM(co.valor) AS valor
    FROM
        consignaciones co,
        aux_abonos_facs_credito a
    WHERE
        co.ndocumento=a.ncomprobante
    GROUP BY
        a.fecha_comprobante) AS foo2
ON
    foo.fecha_comprobante = foo2.fecha_comprobante;

    
--Medios de pago de los comprobantes de ingreso
DROP TABLE IF EXISTS aux_medios_pago_ci;
CREATE TEMP TABLE aux_medios_pago_ci AS
SELECT
    foo.fecha_comprobante,
    COALESCE(foo.efectivo,0) AS efectivo,
    COALESCE(cit.valor,0) AS tarjeta,
    COALESCE(foo.tregalo,0) AS tregalo,
    COALESCE(foo.sodexo,0) AS sodexo,
    COALESCE(foo.bigpass,0) AS bigpass,
    COALESCE(cic.valor,0) AS consignaciones
FROM
    (SELECT
        a.fecha_comprobante,
        SUM(CASE WHEN c.char_cta = ''11053501'' THEN a.abono_comprobante ELSE 0 END) AS efectivo,
        SUM(CASE WHEN c.char_cta = ''28050504'' THEN a.abono_comprobante ELSE 0 END) AS tregalo,
        SUM(CASE WHEN c.char_cta = ''11052001'' THEN a.abono_comprobante ELSE 0 END) AS sodexo,
        SUM(CASE WHEN c.char_cta = ''11052501'' THEN a.abono_comprobante ELSE 0 END) AS bigpass
    FROM
        libro_auxiliar l,
        cuentas c,
        aux_abonos_facs_credito a
    WHERE
        a.ncomprobante = l.ndocumento AND
        c.id_cta=l.id_cta AND
        l.debe != 0
    GROUP BY
        a.fecha_comprobante) AS foo
LEFT OUTER JOIN
    aux_abonos_ci_tarjeta cit
ON
    foo.fecha_comprobante = cit.fecha_comprobante
LEFT OUTER JOIN
    aux_abonos_ci_consignaciones cic
ON
    foo.fecha_comprobante = cic.fecha_comprobante;
    
    
--
DROP TABLE IF EXISTS aux_resultado_final_repo;
CREATE TEMP TABLE aux_resultado_final_repo AS
SELECT
    a.fecha,
    COALESCE(efectivo.valor,0)+
    COALESCE(tarjetas.valor,0)+
    COALESCE(consignaciones.valor,0)+
	coalesce(consignacionesfactura.valor,0)+
    COALESCE(tregalo.valor,0)+
    COALESCE(sodexo.valor,0)+
    COALESCE(bigpass.valor,0)+
    COALESCE(anticipos.valor,0)+
    COALESCE(fcredito.valor,0)
    +COALESCE(aci.consignaciones,0)
    +COALESCE(aci.sodexo,0)
    +COALESCE(aci.bigpass,0)
    AS total_facturado,

    COALESCE(efectivo.valor,0) AS efectivo,
    COALESCE(tarjetas.valor,0) AS tarjetas,
    COALESCE(consignaciones.valor,0)+COALESCE(aci.consignaciones,0)+coalesce(consignacionesfactura.valor,0) AS consignaciones,
    COALESCE(tregalo.valor,0) AS bono_regalo,
    COALESCE(sodexo.valor,0)+COALESCE(aci.sodexo,0) AS sodexo,
    COALESCE(bigpass.valor,0)+COALESCE(aci.bigpass,0) AS bigpass,
    COALESCE(anticipos.valor,0) AS anticipos,
    COALESCE(fcredito.valor,0) AS fcredito
FROM    
    (SELECT DISTINCT fecha FROM aux_docs) a
LEFT OUTER JOIN
    (SELECT
        l.fecha::DATE AS fecha,     
        sum(debe)-sum(haber) AS valor
    FROM
        aux_docs a,
        libro_auxiliar l,
        cuentas c
    WHERE
        a.ndocumento = l.ndocumento AND
        c.id_cta=l.id_cta AND
        c.char_cta IN (''11053501'',''530535'') --efectivo, descuentos
    GROUP BY 
        l.fecha::DATE) AS efectivo
ON
    a.fecha = efectivo.fecha
LEFT OUTER JOIN    
    (SELECT
        a.fecha,        
        SUM(CASE WHEN a.suma THEN t.valor ELSE t.valor*-1 END) AS valor
    FROM
        tarjetas t,     
        tcredito tc,
        aux_docs a,
        cuentas c
    WHERE
        t.id_tcredito = tc.id_tcredito AND
        tc.tipo NOT IN (''TR'') AND --estas tarjetas se usan para pagos con nequi y demás ...se tratan como consignaciones y tienes apartado propio
        t.ndocumento=a.ndocumento AND
        t.id_cta = c.id_cta AND
        c.char_cta NOT IN (''28050504'')  -- no se incluyen tarjetas regalo porque tienen seccion aparte mas abajo
    GROUP BY
        a.fecha) AS tarjetas
ON
    a.fecha = tarjetas.fecha
LEFT OUTER JOIN    
    (SELECT
        l.fecha::DATE AS fecha,     
        sum(debe)-sum(haber) AS valor
    FROM
        aux_docs a,
        libro_auxiliar l,
        cuentas c
    WHERE
        a.ndocumento = l.ndocumento AND
        c.id_cta=l.id_cta AND
        c.char_cta =''28050504''
    GROUP BY 
        l.fecha::DATE) AS tregalo
ON
  a.fecha = tregalo.fecha
LEFT OUTER JOIN
    (SELECT
        l.fecha::DATE AS fecha,     
        sum(debe)-sum(haber) AS valor
    FROM
        aux_docs a,
        libro_auxiliar l,
        cuentas c
    WHERE
        a.ndocumento = l.ndocumento AND
        c.id_cta=l.id_cta AND
        c.char_cta =''11052001''
    GROUP BY 
        l.fecha::DATE) AS sodexo
ON
    a.fecha = sodexo.fecha
LEFT OUTER JOIN
    (SELECT
        l.fecha::DATE AS fecha,     
        sum(debe)-sum(haber) AS valor
    FROM
        aux_docs a,
        libro_auxiliar l,
        cuentas c
    WHERE
        a.ndocumento = l.ndocumento AND
        c.id_cta=l.id_cta AND
        c.char_cta =''11052501''
    GROUP BY 
        l.fecha::DATE) AS bigpass
ON
    a.fecha = bigpass.fecha
LEFT OUTER JOIN
    (SELECT
        fcredito.fecha::DATE AS fecha,
        COALESCE(fcredito.valor,0)-COALESCE(abonos.valor,0) AS valor
    FROM
        (SELECT
            a.fecha::DATE AS fecha,     
            sum(a.debe) AS valor
        FROM
            aux_facs_credito a
        GROUP BY
            a.fecha::DATE) AS fcredito
    LEFT OUTER JOIN
        (SELECT
            abonos.fecha_comprobante::DATE AS fecha,        
            sum(abonos.abono_comprobante) AS valor
        FROM
            aux_abonos_facs_credito abonos
        GROUP BY
            abonos.fecha_comprobante::DATE) AS abonos
    ON
        abonos.fecha = fcredito.fecha) AS fcredito
ON
    a.fecha = fcredito.fecha
LEFT OUTER JOIN
    (SELECT
        l.fecha::DATE AS fecha,
        sum(debe)-sum(haber) AS valor
    FROM
        aux_docs a,
        libro_auxiliar l,
        cuentas c
    WHERE
        a.ndocumento = l.ndocumento AND
        c.id_cta=l.id_cta AND
        c.char_cta in (''28050502'')
    GROUP BY 
        l.fecha::DATE) AS anticipos
ON
    a.fecha = anticipos.fecha
LEFT OUTER JOIN
    (
    SELECT
            a.fecha,            
            SUM(CASE WHEN a.suma THEN t.valor ELSE t.valor*-1 END) AS valor
        FROM
            tarjetas t,
            tcredito tc,
            aux_docs a,
            cuentas c
        WHERE
            t.ndocumento=a.ndocumento AND
            t.id_tcredito = tc.id_tcredito AND
            a.codigo_tipo NOT IN (SELECT codigo_tipo FROM tipo_doc_abonos_cartera) AND
            tc.tipo = ''TR'' AND --estas tarjetas se usan para pagos con nequi y demás ...se tratan como consignaciones
            t.id_cta = c.id_cta AND
            c.char_cta NOT IN (''28050504'')  -- no se incluyen tarjetas regalo porque tienen seccion aparte mas abajo
        GROUP BY
            a.fecha 
    ) AS consignaciones
ON
    a.fecha = consignaciones.fecha

LEFT OUTER JOIN
    (SELECT
		a.fecha,
		SUM(co.valor) AS valor
    FROM
        aux_docs a,
		tipo_docs_solo_facturacion sf,
		consignaciones co,
        cuentas c
    WHERE
		a.ndocumento = co.ndocumento AND
		a.codigo_tipo = sf.codigo_tipo and
		a.suma AND
        c.id_cta=co.id_cta AND
        (c.char_cta like (''1110%'') or
		c.char_cta like (''1120%''))
    GROUP BY 
        a.fecha::DATE) AS consignacionesfactura
ON
    a.fecha = consignacionesfactura.fecha


LEFT OUTER JOIN
    aux_medios_pago_ci aci
ON
    a.fecha = aci.fecha_comprobante
ORDER BY
    a.fecha;'))
FROM
    aux_parametros_reporte a;


DROP TABLE IF EXISTS aux_reporte_final_remoto;
CREATE TEMP TABLE aux_reporte_final_remoto AS
SELECT
    fecha,
    total_facturado,
    efectivo,
    tarjetas,
    consignaciones,
    bono_regalo,
    sodexo,
    bigpass,
    anticipos,
    fcredito
FROM
    dblink((SELECT cnx FROM remote_cnx),
    'SELECT
        fecha,
        total_facturado,
        efectivo,
        tarjetas,
        consignaciones,
        bono_regalo,
        sodexo,
        bigpass,
        anticipos,
        fcredito
    FROM
        aux_resultado_final_repo') AS r(
        fecha VARCHAR,
        total_facturado FLOAT8,
        efectivo FLOAT8,
        tarjetas FLOAT8,
        consignaciones FLOAT8,
        bono_regalo FLOAT8,
        sodexo FLOAT8,
        bigpass FLOAT8,
        anticipos FLOAT8,
        fcredito FLOAT8
);

DROP TABLE IF EXISTS cnx_remote;
CREATE TEMP TABLE cnx_remote AS 
SELECT dblink_disconnect(cnx) FROM remote_cnx;


    
DROP TABLE IF EXISTS aux_suma_resultado_final_repo;
CREATE TEMP TABLE aux_suma_resultado_final_repo AS
SELECT
    'TOTAL'::VARCHAR AS fecha,
    SUM(total_facturado) AS total_facturado,
    SUM(efectivo) AS efectivo,
    SUM(tarjetas) AS tarjetas,
    SUM(consignaciones) AS consignaciones,
    SUM(bono_regalo) AS bono_regalo,
    SUM(sodexo) AS sodexo,
    SUM(bigpass) AS bigpass,
    SUM(anticipos) AS anticipos,
    SUM(fcredito) AS fcredito
FROM
    aux_reporte_final_remoto;
    
SELECT
    fecha::VARCHAR AS fecha,
    total_facturado,
    efectivo,
    tarjetas,
    consignaciones,
    bono_regalo,
    sodexo,
    bigpass,
    anticipos,
    fcredito,
    0::INTEGER AS color
FROM
    aux_reporte_final_remoto
UNION
SELECT
    fecha,
    total_facturado,
    efectivo,
    tarjetas,
    consignaciones,
    bono_regalo,
    sodexo,
    bigpass,
    anticipos,
    fcredito,
    -1::INTEGER AS color
FROM
    aux_suma_resultado_final_repo
ORDER BY
    fecha;