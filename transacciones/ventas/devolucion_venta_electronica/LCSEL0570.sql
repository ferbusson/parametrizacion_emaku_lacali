--LCSEL0570 dev en venta

with aux_parametros_query as (
select
	d.ndocumento
from
	documentos d
where
    d.codigo_tipo='?' AND    
    d.numero=LPAD('?',10,'0')
) 
, aux_prefijos_devoluciones as (
select
	ds2.codigo_tipo
from
	documentos_standar ds 
inner join
	documentos_sucursales ds2 
on
	ds.id_documento = ds2.id_documento 
where
	ds.nombre = 'DVENTA ELECTRONICA'
)
,aux_devs_asociadas_a_factura as (
select
	a.ndocumento as ndocumento_factura,
	d.*,
	dp.id_bodega,
	dp.id_prod_serv,
	dp.cant
from
	aux_parametros_query a
inner join
	info_documento id
on
	a.ndocumento = id.rf_documento
inner join
	documentos d
on
	id.ndocumento = d.ndocumento 
inner join
	aux_prefijos_devoluciones apr
on
	apr.codigo_tipo = d.codigo_tipo 
inner join 
	datos_prod dp
on
	d.ndocumento = dp.ndocumento 
where
	d.estado
)
, aux_cruce_con_devoluiciones as (
select
	dp.ndocumento,
	dp.id_bodega,
	dp.id_prod_serv,
	dp.cant,
	dp.pventa,
	dp.iva,
	dp.descuento1,
	coalesce(dp.porcentajebp,-1) as porcentajebp,
    coalesce(dp.inc,-1) as inc,
	coalesce(adev.cant,0) as ya_devuelto,
	dp.cant - coalesce(adev.cant,0) as saldo
from
	aux_parametros_query a
inner join
	datos_prod dp
on
	a.ndocumento = dp.ndocumento
left join
	aux_devs_asociadas_a_factura adev
on
	a.ndocumento = adev.ndocumento_factura
	and dp.id_prod_serv = adev.id_prod_serv 
)

SELECT 
    ps.codigo,
    substring(it.nombre,0,40) as nombre,
    a.saldo AS disponible, -- En la dev el disponible no es representativo
    a.saldo,
    a.pventa,
    a.iva,
    a.descuento1,
    0.00 as sub_tot,
    0.00 as v_dcto,
    0.00 as neto,
    0.00 as v_iva,
    0.00 as gtotal,
    a.id_prod_serv,
    CURRENT_TIMESTAMP AS tag,
    COALESCE(dd.trm,'0.0') AS trm,
    0.0 as totalus,
    ps.id_asiento_generico,
    0.0 as basecinco,
    0.0 as ivacinco,
    0.0 as basediezynueve,
    0.0 as ivadiezynueve,
    0.0 as baseexentos,
    0.0 as ivaextos,
    0.0 as baseexcluidos,
    0.0 as ivaexcluidos,
    0.0 AS verde,
    0.0 AS subtotalsinbolsa,
    0.0 AS vlrunitarioimp,
    ps.codigo,
    it.ref_proveedor,
    a.porcentajebp,
    a.inc,
    1 as contadorlineas
FROM 
	aux_cruce_con_devoluiciones a,
    datos_documento dd,
    prod_serv ps,
     item it,
    marcas mar
WHERE 
    a.ndocumento = dd.ndocumento AND
    ps.id_prod_serv=a.id_prod_serv AND
    it.id_item=ps.id_item AND
    it.id_marca=mar.id_marca and 
	a.saldo != 0;