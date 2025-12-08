--LCSEL1014

with aux_parametros_query as (
select
	'?'::varchar as id_movimiento,
	'?'::varchar as id_concepto_causacion,
	'?'::bigint as ndocumento
)

select
	g.id_char,
	trim(upper(coalesce(g.apellido1,'')||' '||coalesce(g.apellido2,'')||' '||coalesce(g.nombre1,'')||' '||coalesce(g.nombre2,'')||' '||coalesce(g.razon_social,''))) as nombre,
	ideev.valor,
	g.id,
	a.id_concepto_causacion,
	0 as bandera,
	row_number() over (order by ideev.id_tercero) as tagdata
from
	importacion_desde_excel_empleados_valor ideev 
inner join
	aux_parametros_query a
on 	
	ideev.ndocumento = a.ndocumento
inner join
	"general" g 
on
	ideev.id_tercero = g.id
where
	ideev.ndocumento = a.ndocumento
order by
	nombre;


