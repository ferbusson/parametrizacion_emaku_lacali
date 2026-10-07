--LCSEL1021
select
	trim(codigo) as codigo,
	trim(descripcion) as descripcion
FROM
	campanias_bono_regalo
where
	visible
order by
	descripcion;