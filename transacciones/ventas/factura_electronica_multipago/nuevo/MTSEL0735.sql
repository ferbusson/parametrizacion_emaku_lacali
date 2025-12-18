SELECT 
	i.id,
	i.sigla 
FROM 
	info_empleado i,
	empleados_sucursal e,
	administracion_sucursales a
WHERE
	a.id_bodega_ppal = '?' AND
	a.id_administracion_sucursales = e.id_administracion_sucursales AND
	i.estado='ACT' AND
	i.id = e.id
	--i.id_cargo_empleado = 'VEN'
ORDER BY
	case when sigla = 'VEN PRUEBA' then null else sigla end nulls first;