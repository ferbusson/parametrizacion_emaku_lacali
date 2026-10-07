SELECT  --?
	descripcion,
	direccion,
	ndepto||' '||id_dep as departamento,
	mnombre||' '||municipio as municipio,
	foo.id_direccion,
	count(tercero_def.id_direccion) as links
FROM 
	(SELECT 
		direcciones.id_direccion,
		direcciones.descripcion,
		direcciones.direccion,
		pais.nombre as npais,
		pais.id_pais,
		departamentos.nombre as ndepto,
		departamentos.id_dep,
		municipios.nombre as mnombre,
		municipios.municipio 
	FROM 
		general g,
		direcciones,
		pais,
		departamentos,
		municipios 
	WHERE 
		g.id_char = '?' AND
		g.id = direcciones.id AND
		direcciones.municipio=municipios.municipio AND 
		direcciones.id_dep=municipios.id_dep AND 
		direcciones.id_pais=municipios.id_pais AND 
		direcciones.id_dep = departamentos.id_dep AND 
		direcciones.id_pais=departamentos.id_pais AND 
		direcciones.id_pais = pais.id_pais) as foo 
LEFT OUTER JOIN 
	tercero_def 
ON 
	foo.id_direccion=tercero_def.id_direccion 
group by 
	foo.id_direccion,
	descripcion,
	direccion,
	npais,
	id_pais,
	ndepto,
	id_dep,
	mnombre,
	municipio
ORDER BY
	foo.id_direccion desc;