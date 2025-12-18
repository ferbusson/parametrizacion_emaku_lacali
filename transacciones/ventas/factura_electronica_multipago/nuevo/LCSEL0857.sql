-- LCSEL0857 query factura credito
-- Selecciona por prelacion el porcentaje de descuento dentro de cada categoria

-- a11 x submarca
-- a7 x linea y submarca
-- a8 x grupo y submarca
-- a9 x subgrupo y submarca

-- a10 x marca
-- a4 x linea y marca
-- a5 x grupo y marca
-- a6 x subgrupo y marca


DROP TABLE IF EXISTS aux_params_antes_de_validaciones;
CREATE TEMP TABLE aux_params_antes_de_validaciones AS
SELECT
    '?'::CHARACTER(14) AS codigo,
    '?'::INT AS tercero,
    '?'::INTEGER AS id_centrocosto,
    '?'::INTEGER AS id_bodega,
    '?'::VARCHAR AS cuenta_plataforma,
    '1'::INTEGER AS dia_siniva;

DROP TABLE IF EXISTS rev_ter;
CREATE TEMP TABLE rev_ter AS
SELECT
    1
FROM
    (SELECT
        error_text('Para comenzar digite los datos del cliente por favor')
    FROM
        aux_params_antes_de_validaciones a
    WHERE
        a.tercero = -1 or
        a.tercero is null) AS f;
    
DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
    1
FROM
    (SELECT
        error_text(''||foo.mensaje)
    FROM
        (SELECT
            'Seleccione el tipo de factura (Credito, Addi, Sistecredito, Domicilios).'::text as mensaje
        FROM
            aux_params_antes_de_validaciones a
        WHERE
            trim(a.cuenta_plataforma) = '' or
            a.cuenta_plataforma is null
            ) AS foo) AS foo;


DROP TABLE IF EXISTS aux_params;
CREATE TEMP TABLE aux_params AS
SELECT 
    ds.codigo_tipo,
    foo.id_centrocosto,
    foo.codigo,
    foo.tercero,
    foo.id_bodega,
    foo.dia_siniva,
    TRIM(foo.cuenta_plataforma) AS cuenta_plataforma,
    -- Julio 8 2025: se agrega condición por solicitud de Maria E, los clientes con precio mayorista solo
    -- tienen derecho a este beneficio cuando el tipo de factura es CREDITO (130505)
    case when pt.id_catalogo = 2 and TRIM(foo.cuenta_plataforma) != '130505' then 1::integer else pt.id_catalogo end as id_catalogo  
FROM
    administracion_sucursales a,
    documentos_sucursales ds,
    perfil_tercero pt,
    documentos_standar dst,
    aux_params_antes_de_validaciones foo -- 1 facturacion normal, 2 dia sin iva
WHERE
    foo.tercero = pt.id AND
    a.id_centrocosto = foo.id_centrocosto AND
    a.id_administracion_sucursales = ds.id_administracion_sucursales AND
    ds.id_documento = dst.id_documento AND
    dst.nombre = 'FACTURACION';
    


DROP TABLE IF EXISTS aux_subgrupos_dsi;
CREATE TEMP TABLE aux_subgrupos_dsi AS 
SELECT
    sdsi.id_genero_dsi,
    sdsi.id_sgrupo,
    c.tope
FROM
    subgrupos_dsi sdsi,
    categorias_dsi c,
    generos_dsi g
WHERE
    sdsi.id_genero_dsi = g.id_genero_dsi AND
    g.id_categoria_dsi = c.id_categoria_dsi;

DROP TABLE IF EXISTS aux_info_inc;
CREATE TEMP TABLE aux_info_inc AS 
select
    inc
from
    inc
order by 
    id_inc desc
limit 1;

DROP TABLE IF EXISTS item_a;
CREATE TEMP TABLE item_a AS
SELECT
    ps.id_prod_serv,
    --CASE WHEN a.dia_siniva=1 OR sdsi.id_sgrupo IS NULL OR (sdsi.id_sgrupo IS NOT NULL AND ROUND((pv.pventa/(1.0+(ps.iva/100)))::numeric,0) > sdsi.tope) THEN ps.iva ELSE 0 END AS iva, -- porcentahe de iva dia sin iva
    ps.iva,
    ps.iva AS iva_auxiliar, -- porcentaje de iva del producto, se usa para calculos de pventa mas abajo
    ps.id_asiento_generico,
    i.id_linea,
    i.id_grupo,
    i.id_sgrupo,
    i.id_item,
    i.id_marca,
    i.id_presentacion,
    ps.codigo,
    i.ref_proveedor,
    coalesce(i.id_submarca,0) as id_submarca,
    i.nombre,
    a.codigo_tipo,
    a.id_bodega,
    pv.id_catalogo,
    coalesce(tbe.porcentaje,-1) as porcentaje_bp,
    inc.inc 
from
    aux_params a
inner join  
    prod_serv ps
on
    a.codigo = ps.codigo and
    ps.estado
inner join
    pventa pv
on
    ps.id_prod_serv = pv.id_prod_serv AND
    pv.id_catalogo = a.id_catalogo  
inner join
    item i
on
    ps.id_item = i.id_item
LEFT OUTER JOIN 
    aux_subgrupos_dsi sdsi
ON
    i.id_sgrupo = sdsi.id_sgrupo
left outer join 
    enlace_producto_tarifa_bolsa_eco e 
on
    ps.id_prod_serv = e.id_prod_serv
left join   
    tarifas_bolsas_ecologicas tbe
on
    e.id_nivel_impacto = tbe.id_nivel_impacto
left join
    aux_info_inc inc
on
    true;

drop table if exists aux_promociones;
CREATE TEMP TABLE aux_promociones as
select distinct
    d.ndocumento,
    d.codigo_tipo||d.numero AS numero,
    d.fecha,
    r.codigo_tipo,
    r.id_linea,
    r.id_grupo,
    r.id_sgrupo,
    r.id_marca,
    r.id_submarca,
    i.id_item,
    xy.pdescuento,
    xy.narticulos
from
    documentos d,
    xy_promocion xy,
    registro_promociones r
LEFT OUTER JOIN
    items_promocion i
ON
    r.ndocumento = i.ndocumento
where
    d.ndocumento = xy.ndocumento and
    d.ndocumento = r.ndocumento and
    d.estado and
    r.estado AND
    CURRENT_TIMESTAMP BETWEEN r.fechaip AND r.fechafp;

drop table if exists aux_excepciones;
CREATE TEMP TABLE aux_excepciones as
select distinct
    a.ndocumento,
    r.codigo_tipo,
    r.id_linea,
    r.id_grupo,
    r.id_sgrupo,
    r.id_marca,
    r.id_submarca,
    r.id_item
from
    (SELECT DISTINCT ndocumento FROM aux_promociones) AS a,
    registro_promociones_excepciones r
where
    a.ndocumento = r.ndocumento;

drop table if exists union_pe;
CREATE TEMP TABLE union_pe as
select
    p.*,
    string_agg(coalesce(e.codigo_tipo,'-1'),';' ORDER BY coalesce(e.codigo_tipo,'-1')) AS codigo_tipoe,
    string_agg(coalesce(e.id_linea,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_linea,'-1')) AS id_lineae,
    string_agg(coalesce(e.id_grupo,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_grupo,'-1')) AS id_grupoe,
    string_agg(coalesce(e.id_sgrupo,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_sgrupo,'-1')) AS id_sgrupoe,
    string_agg(coalesce(e.id_marca,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_marca,'-1')) AS id_marcae,
    string_agg(coalesce(e.id_submarca,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_submarca,'-1')) AS id_submarcae,
    string_agg(coalesce(e.id_item,'-1')::VARCHAR,';' ORDER BY coalesce(e.id_item,'-1')) AS id_iteme
from
    aux_promociones p
left outer join
    aux_excepciones e
on
    p.ndocumento = e.ndocumento
GROUP BY
    p.ndocumento,
    p.numero,
    p.fecha,
    p.codigo_tipo,
    p.id_linea,
    p.id_grupo,
    p.id_sgrupo,
    p.id_marca,
    p.id_submarca,
    p.id_item,
    p.pdescuento,
    p.narticulos;



DROP TABLE IF EXISTS aux_consulta_con_promociones;
CREATE TEMP TABLE aux_consulta_con_promociones AS 
SELECT
    foo.id_prod_serv,
    foo.descripcion,
    foo.pventa1,
    foo.iva,
    foo.tag,
    CASE WHEN foo.id_prod_serv=28741 THEN 100 ELSE coalesce(i.disponible,0) END AS disponible,
    foo.trm,
    foo.id_marcap,
    foo.id_itemp,
    foo.narticulosa,
    foo.pdescuentoa, --t12
    foo.narticulosm,
    foo.pdescuentom, --u14
    foo.narticulosi,
    foo.pdescuentoi, --v16
    foo.id_marca_pc,
    foo.id_item_pc,
    foo.id_marca_po,
    foo.id_item_po,
    foo.id_marca_pbd,
    foo.id_item_pbd,
    foo.ndocumento,
    foo.id_asiento_generico,
    foo.id_lineap,
    foo.id_grupop,
    foo.id_sgrupop,
    foo.id_submarcap,
    foo.narticulosxyl,
    foo.pdescuentoxyl, --w30
    foo.narticulosxyg,
    foo.pdescuentoxyg, --x32
    foo.narticulosxysg,
    foo.pdescuentoxysg, --y34
    foo.narticulosxysm,
    foo.pdescuentoxysm, --z36
    foo.codigo,
    foo.ref_proveedor,
    1::INTEGER AS contador,
    foo.porcentaje_bp,
    foo.inc
FROM
    (SELECT
        i.id_prod_serv,
        i.codigo,
        i.nombre AS descripcion,
        i.ref_proveedor,
        i.iva,
        current_timestamp AS tag,
        pv1.pventa1,
        pv2.pventa2,
        trm,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_linea,a1.id_linea),a2.id_linea),a3.id_linea),a4.id_linea),a5.id_linea),a6.id_linea),a7.id_linea),a8.id_linea),a9.id_linea),-1) AS id_lineap,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_grupo,a1.id_grupo),a2.id_grupo),a3.id_grupo),a4.id_grupo),a5.id_grupo),a6.id_grupo),a7.id_grupo),a8.id_grupo),a9.id_grupo),-1) AS id_grupop,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_sgrupo,a1.id_sgrupo),a2.id_sgrupo),a3.id_sgrupo),a4.id_sgrupo),a5.id_sgrupo),a6.id_sgrupo),a7.id_sgrupo),a8.id_sgrupo),a9.id_sgrupo),-1) AS id_sgrupop,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_marca,a1.id_marca),a2.id_marca),a3.id_marca),a4.id_marca),a5.id_marca),a6.id_marca),a7.id_marca),a8.id_marca),a9.id_marca),-1) AS id_marcap,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_submarca,a1.id_submarca),a2.id_submarca),a3.id_submarca),a4.id_submarca),a5.id_submarca),a6.id_submarca),a7.id_submarca),a8.id_submarca),a9.id_submarca),-1) AS id_submarcap,
        coalesce(coalesce(coalesce(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(COALESCE(a0.id_item,a1.id_item),a2.id_item),a3.id_item),a4.id_item),a5.id_item),a6.id_item),a7.id_item),a8.id_item),a9.id_item),-1) AS id_itemp,
        coalesce(a.narticulos,0) as narticulosa,
        coalesce(a.pdescuento,0) as pdescuentoa,
        coalesce(a0.narticulos,0) as narticulosxyl,
        coalesce(a0.pdescuento,0) as pdescuentoxyl,
        coalesce(a1.narticulos,0) as narticulosxyg,
        coalesce(a1.pdescuento,0) AS pdescuentoxyg,
        coalesce(a2.narticulos,0) as narticulosxysg,
        coalesce(a2.pdescuento,0) AS pdescuentoxysg,
        coalesce(a4.narticulos,0)+coalesce(a5.narticulos,0)+coalesce(a6.narticulos,0)+coalesce(a10.narticulos,0) as narticulosm,
        --coalesce(a4.pdescuento,0)+coalesce(a5.pdescuento,0)+coalesce(a6.pdescuento,0)+coalesce(a10.pdescuento,0) AS pdescuentom,
        COALESCE(CASE WHEN coalesce(a6.pdescuento,0) > 0 THEN coalesce(a6.pdescuento,0) WHEN coalesce(a5.pdescuento,0) > 0 THEN coalesce(a5.pdescuento,0) WHEN coalesce(a4.pdescuento,0) > 0 THEN coalesce(a4.pdescuento,0) WHEN coalesce(a10.pdescuento,0) > 0 THEN coalesce(a10.pdescuento,0) END,0) AS pdescuentom,
        coalesce(a7.narticulos,0)+coalesce(a8.narticulos,0)+coalesce(a9.narticulos,0)+coalesce(a11.narticulos,0)+COALESCE(a12.narticulos,0) AS narticulosxysm,
        --coalesce(a7.pdescuento,0)+coalesce(a8.pdescuento,0)+coalesce(a9.pdescuento,0)+coalesce(a11.pdescuento,0) AS pdescuentoxysm,
        COALESCE(CASE WHEN coalesce(a12.pdescuento,0) > 0 THEN coalesce(a12.pdescuento,0) WHEN coalesce(a9.pdescuento,0) > 0 THEN coalesce(a9.pdescuento,0) WHEN coalesce(a8.pdescuento,0) > 0 THEN coalesce(a8.pdescuento,0) WHEN coalesce(a7.pdescuento,0) > 0 THEN coalesce(a7.pdescuento,0) WHEN coalesce(a11.pdescuento,0) > 0 THEN coalesce(a11.pdescuento,0) END,0) AS pdescuentoxysm,
        coalesce(a3.narticulos,0) AS narticulosi,
        coalesce(a3.pdescuento,0) AS pdescuentoi,       
        
        COALESCE(COALESCE(pcm.id_marca,pci.id_marca),-1) AS id_marca_pc,
        COALESCE(COALESCE(pcm.id_item,pci.ndocumento),-1) AS id_item_pc,
        COALESCE(COALESCE(pom.id_marca,poi.id_marca),-1) AS id_marca_po,
        COALESCE(COALESCE(pom.id_item,poi.ndocumento),-1) AS id_item_po,
        COALESCE(COALESCE(pbdm.id_marca,pbdi.id_marca),-1) AS id_marca_pbd,
        COALESCE(COALESCE(pbdm.id_item,pbdi.ndocumento),-1) AS id_item_pbd,
        COALESCE(COALESCE(COALESCE(pbda.ndocumento,pbdm.ndocumento),pbdi.ndocumento),0000000000) AS ndocumento,
        i.id_asiento_generico,
        i.porcentaje_bp,
        i.inc
    FROM 
        marcas ma,
        (select pv.id_prod_serv,pv.pventa as pventa1 from pventa pv, item_a i where pv.id_catalogo=i.id_catalogo AND pv.id_prod_serv = i.id_prod_serv) as pv1,
        (select id_prod_serv,pventa as pventa2 from pventa where id_catalogo=2) as pv2,
        (SELECT
            trm
        FROM
            trm t,
            (SELECT 
                max(id_trm) as max
            FROM
                trm) AS f
        WHERE
            f.max=t.id_trm) AS trm,
        item_a i
    LEFT OUTER JOIN
        union_pe a
    on
        (a.codigo_tipo = i.codigo_tipo or -- x almacen
        a.codigo_tipo = '') AND
        a.id_linea is null and 
        a.id_grupo is null and
        a.id_sgrupo is null and
        a.id_marca is null and
        a.id_submarca is null and
        a.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a.id_iteme,';')::INT[]) s(id_iteme))

    LEFT OUTER JOIN
        union_pe as a0
    on
        (a0.codigo_tipo = i.codigo_tipo or
        a0.codigo_tipo = '') and
        a0.id_linea = i.id_linea and -- x linea
        a0.id_grupo is null and
        a0.id_sgrupo is null and
        a0.id_marca is null and
        a0.id_submarca is null and
        a0.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a0.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a0.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a0.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a0.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a0.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a0.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a0.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a1
    on
        (a1.codigo_tipo = i.codigo_tipo or
        a1.codigo_tipo = '') and
        a1.id_grupo = i.id_grupo and -- x grupo
        a1.id_sgrupo is null and
        a1.id_marca is null and
        a1.id_submarca is null and
        a1.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a1.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a1.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a1.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a1.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a1.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a1.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a1.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a2
    on
        (a2.codigo_tipo = i.codigo_tipo or
        a2.codigo_tipo = '') and
        a2.id_sgrupo = i.id_sgrupo and -- x subgrupo
        a2.id_marca is null and
        a2.id_submarca is null and
        a2.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a2.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a2.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a2.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a2.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a2.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a2.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a2.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a3
    on
        (a3.codigo_tipo = i.codigo_tipo or -- x item
        a3.codigo_tipo = '') and
        a3.id_item = i.id_item and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a3.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a3.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a3.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a3.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a3.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a3.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a3.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a4
    on
        (a4.codigo_tipo = i.codigo_tipo or
        a4.codigo_tipo = '') and
        a4.id_linea = i.id_linea and -- x linea y marca
        a4.id_grupo is null and
        a4.id_sgrupo is null and
        a4.id_marca = i.id_marca and
        a4.id_submarca is null and
        a4.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a4.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a4.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a4.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a4.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a4.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a4.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a4.id_iteme,';')::INT[]) s(id_iteme))

    LEFT OUTER JOIN
        union_pe a5
    on
        (a5.codigo_tipo = i.codigo_tipo or
        a5.codigo_tipo = '') and
        a5.id_grupo = i.id_grupo and -- x grupo y marca
        a5.id_sgrupo is null and
        a5.id_marca = i.id_marca and
        a5.id_submarca is null and
        a5.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a5.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a5.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a5.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a5.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a5.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a5.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a5.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a6
    on
        (a6.codigo_tipo = i.codigo_tipo or
        a6.codigo_tipo = '') and
        a6.id_sgrupo = i.id_sgrupo and -- x subgrupo y marca
        a6.id_marca = i.id_marca and
        a6.id_submarca is null and
        a6.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a6.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a6.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a6.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a6.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a6.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a6.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a6.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a7
    on
        (a7.codigo_tipo = i.codigo_tipo or
        a7.codigo_tipo = '') and
        a7.id_linea = i.id_linea and -- x linea y submarca
        a7.id_grupo is null and
        a7.id_sgrupo is null and
        a7.id_marca is null and
        a7.id_submarca = i.id_submarca and
        a7.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a7.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a7.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a7.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a7.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a7.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a7.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a7.id_iteme,';')::INT[]) s(id_iteme))
    
    LEFT OUTER JOIN
        union_pe a8
    on
        (a8.codigo_tipo = i.codigo_tipo or
        a8.codigo_tipo = '') and
        a8.id_grupo = i.id_grupo and -- x grupo y submarca
        a8.id_sgrupo is null and
        a8.id_marca is null and
        a8.id_submarca = i.id_submarca and
        a8.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a8.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a8.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a8.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a8.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a8.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a8.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a8.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a9
    on
        (a9.codigo_tipo = i.codigo_tipo or
        a9.codigo_tipo = '') and
        a9.id_sgrupo = i.id_sgrupo and -- x subgrupo y submarca
        a9.id_marca is null and
        a9.id_submarca = i.id_submarca and
        a9.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a9.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a9.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a9.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a9.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a9.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a9.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a9.id_iteme,';')::INT[]) s(id_iteme))
    
    LEFT OUTER JOIN
        union_pe as a10
    on
        (a10.codigo_tipo = i.codigo_tipo or
        a10.codigo_tipo = '') and
        a10.id_linea is null and
        a10.id_grupo is null and
        a10.id_sgrupo is null and
        a10.id_marca = i.id_marca and -- x marca
        a10.id_submarca is null and
        a10.id_item is null and
        
        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a10.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a10.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a10.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a10.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a10.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a10.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a10.id_iteme,';')::INT[]) s(id_iteme))
        
    LEFT OUTER JOIN
        union_pe a11
    on
        (a11.codigo_tipo = i.codigo_tipo or
        a11.codigo_tipo = '') and
        a11.id_linea is null and
        a11.id_grupo is null and        
        a11.id_sgrupo is null and
        a11.id_marca is null and
        a11.id_submarca = i.id_submarca and -- x submarca
        a11.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a11.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a11.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a11.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a11.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a11.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a11.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a11.id_iteme,';')::INT[]) s(id_iteme))
     
     LEFT OUTER JOIN
        union_pe a12
    on
        (a12.codigo_tipo = i.codigo_tipo or
        a12.codigo_tipo = '') and
        a12.id_linea = i.id_linea and
        a12.id_grupo = i.id_grupo and       
        a12.id_sgrupo = i.id_sgrupo and
        a12.id_marca = i.id_marca and
        a12.id_submarca = i.id_submarca and -- x linea, grupo, sgrupo, marca y submarca
        a12.id_item is null and

        i.codigo_tipo NOT IN (select codigo_tipoe from unnest(string_to_array(a12.codigo_tipoe,';')) s(codigo_tipoe)) AND
        i.id_linea NOT IN (select id_lineae from unnest(string_to_array(a12.id_lineae,';')::INT[]) s(id_lineae)) AND
        i.id_grupo NOT IN (select id_grupoe from unnest(string_to_array(a12.id_grupoe,';')::INT[]) s(id_grupoe)) AND
        i.id_sgrupo NOT IN (select id_sgrupoe from unnest(string_to_array(a12.id_sgrupoe,';')::INT[]) s(id_sgrupoe)) AND
        i.id_marca NOT IN (select id_marcae from unnest(string_to_array(a12.id_marcae,';')::INT[]) s(id_marcae)) AND
        i.id_submarca NOT IN (select id_submarcae from unnest(string_to_array(a12.id_submarcae,';')::INT[]) s(id_submarcae)) AND
        i.id_item NOT IN (select id_iteme from unnest(string_to_array(a12.id_iteme,';')::INT[]) s(id_iteme))

    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            montos_promociones mp,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = mp.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NULL) pcm
    ON
        i.id_marca = pcm.id_marca
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            montos_promociones mp,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = mp.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NOT NULL) pci
    ON
        i.id_marca = pci.id_marca AND
        i.id_item = pci.id_item
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            obsequios_promociones op,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = op.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NULL) pom
    ON
        i.id_marca = pom.id_marca
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            obsequios_promociones op,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = op.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NOT NULL) poi
    ON
        i.id_marca = poi.id_marca AND
        i.id_item = poi.id_item
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            montos_promociones mp,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.codigo_tipo = 'BD' AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = mp.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NULL AND
            i.id_item IS NULL) pbda
    ON
        TRUE
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            montos_promociones mp,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.codigo_tipo = 'BD' AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = mp.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NULL) pbdm
    ON
        i.id_marca = pbdm.id_marca
    LEFT OUTER JOIN
        (SELECT DISTINCT
            d.ndocumento,
            rp.id_marca,
            i.id_item
        FROM
            aux_params ap,
            documentos d,
            montos_promociones mp,
            registro_promociones rp
        LEFT OUTER JOIN
            items_promocion i
        ON
            i.ndocumento = rp.ndocumento
        WHERE
            d.estado AND
            rp.codigo_tipo = ap.codigo_tipo AND
            d.codigo_tipo = 'BD' AND
            d.ndocumento = rp.ndocumento AND
            rp.ndocumento = mp.ndocumento AND
            CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
            rp.id_marca IS NOT NULL AND
            i.id_item IS NOT NULL) pbdi
    ON
        i.id_marca = pbdi.id_marca AND
        i.id_item = pbdi.id_item
    WHERE 
        i.id_marca = ma.id_marca AND
        i.id_prod_serv=pv1.id_prod_serv AND
        i.id_prod_serv=pv2.id_prod_serv
        ) AS foo
LEFT OUTER JOIN
    (SELECT
        inv.id_prod_serv,
        SUM(COALESCE(inv.entrada,0))-SUM(COALESCE(inv.salida,0)) AS disponible
    FROM
        item_a i,
        inventarios inv
    WHERE
        inv.id_prod_serv = i.id_prod_serv and
        inv.id_bodega = i.id_bodega -- Bodega 
    GROUP BY
        inv.id_prod_serv) AS i
ON 
    foo.id_prod_serv = i.id_prod_serv;

DROP TABLE IF EXISTS pventa_ok;
CREATE TEMP TABLE pventa_ok AS 
SELECT
    au.cuenta_plataforma,
    pt.id_regimen,
    ps.id_asiento_generico,
    pv.id_catalogo,
    pv.id_prod_serv,
    CASE WHEN dia_siniva=1 OR sdsi.id_sgrupo IS NULL THEN pventa ELSE CASE WHEN sdsi.id_sgrupo IS NOT NULL AND ROUND(((pv.pventa-(pv.pventa*
    CASE WHEN a.pdescuentoi > 0 THEN a.pdescuentoi WHEN a.pdescuentom > 0 THEN a.pdescuentom 
    WHEN a.pdescuentoxysg > 0 THEN a.pdescuentoxysg WHEN a.pdescuentoxysm > 0 THEN a.pdescuentoxysm 
    WHEN a.pdescuentoxyg > 0 THEN a.pdescuentoxyg WHEN a.pdescuentoxyl > 0 THEN a.pdescuentoxyl ELSE 
    a.pdescuentoa END/100)
    )/(1.0+(ps.iva/100)))::numeric,0) <= sdsi.tope THEN ROUND((pv.pventa/(1.0+(ps.iva/100)))::numeric,0) ELSE pventa END END AS pventa,
    
    CASE WHEN au.dia_siniva=1 OR sdsi.id_sgrupo IS NULL OR (sdsi.id_sgrupo IS NOT NULL AND ROUND(((pv.pventa-(pv.pventa*
    CASE WHEN a.pdescuentoi > 0 THEN a.pdescuentoi WHEN a.pdescuentom > 0 THEN a.pdescuentom 
    WHEN a.pdescuentoxysg > 0 THEN a.pdescuentoxysg WHEN a.pdescuentoxysm > 0 THEN a.pdescuentoxysm 
    WHEN a.pdescuentoxyg > 0 THEN a.pdescuentoxyg WHEN a.pdescuentoxyl > 0 THEN a.pdescuentoxyl ELSE 
    a.pdescuentoa END/100)
    )/(1.0+(ps.iva/100)))::numeric,0) > sdsi.tope) THEN ps.iva ELSE 0 END AS piva -- porcentahe de iva dia sin iva
FROM
    prod_serv ps,
    pventa pv,
    aux_params au,
    perfil_tercero pt,
    aux_consulta_con_promociones a,
    item i
LEFT OUTER JOIN 
    aux_subgrupos_dsi sdsi
ON
    i.id_sgrupo = sdsi.id_sgrupo
WHERE
    au.tercero = pt.id AND
    pv.id_prod_serv=a.id_prod_serv AND
    ps.id_prod_serv = a.id_prod_serv AND
    ps.id_item = i.id_item AND
    pv.id_catalogo = au.id_catalogo;


SELECT
    a.id_prod_serv,
    a.descripcion,
    CASE WHEN pvo.id_regimen='E' THEN ROUND((pvo.pventa/(1+(piva/100)))::numeric,0) ELSE pvo.pventa::NUMERIC END AS pventa,
    CASE WHEN pvo.id_regimen='E' THEN 0 ELSE pvo.piva END AS piva,
    --pvo.pventa,
    --pvo.piva,
    a.tag,
    a.disponible,
    --pvo.pventa,
    --pvo.pventa,
    CASE WHEN pvo.id_regimen='E' THEN ROUND((pvo.pventa/(1+(piva/100)))::numeric,0) ELSE pvo.pventa::NUMERIC END AS pventa,
    CASE WHEN pvo.id_regimen='E' THEN ROUND((pvo.pventa/(1+(piva/100)))::numeric,0) ELSE pvo.pventa::NUMERIC END AS pventa,
    a.trm,
    a.id_marcap,
    a.id_itemp,
    a.narticulosa,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoa ELSE 0 END AS pdescuentoa, --t12
    a.narticulosm,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentom ELSE 0 END AS pdescuentom, --u14
    a.narticulosi,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoi ELSE 0 END AS pdescuentoi, --v16
    a.id_marca_pc,
    a.id_item_pc,
    a.id_marca_po,
    a.id_item_po,
    a.id_marca_pbd,
    a.id_item_pbd,
    a.ndocumento,
    a.id_asiento_generico,
    a.id_lineap,
    a.id_grupop,
    a.id_sgrupop,
    a.id_submarcap,
    a.narticulosxyl,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoxyl ELSE 0 END AS pdescuentoxyl, --w30
    a.narticulosxyg,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoxyg ELSE 0 END AS pdescuentoxyg, --x32
    a.narticulosxysg,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoxysg ELSE 0 END AS pdescuentoxysg, --y34
    a.narticulosxysm,
    CASE WHEN pvo.cuenta_plataforma IN ('130510','130506','130515') THEN a.pdescuentoxysm ELSE 0 END AS pdescuentoxysm, --z36
    a.codigo,
    a.ref_proveedor,
    a.contador,
    pvo.id_regimen,
    pvo.cuenta_plataforma,
    a.porcentaje_bp,
    a.inc
FROM
    aux_consulta_con_promociones a,
    pventa_ok pvo
WHERE
    a.id_prod_serv = pvo.id_prod_serv;
