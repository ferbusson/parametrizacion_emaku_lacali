SELECT
	foo3.tercero,
	'NIT: '||foo3.id_char||'-'||foo3.dv AS nit,
	foo3.razon_social,
	foo3.ciudad,
	'Dir: '||foo3.direccion AS direccion,
	'Tel: '||foo3.telefono AS telefono,
	e.descripcion AS establecimiento
FROM
	(SELECT
		foo2.id,
		foo2.id_char,
		foo2.dv,
		foo2.tercero,
		foo2.razon_social,
		foo2.direccion,
		foo2.ciudad,
		t.numero AS telefono
	FROM
		(SELECT
			foo1.*,
			m.nombre AS ciudad,
			m.direccion
		FROM
			(SELECT
				foo.id,
				foo.id_char,
				foo.tercero,
				foo.dv,
				foo.razon_social,
				MAX(id_direccion) AS id_direccion
			FROM
				(SELECT
					id,
					id_char,
					dv,
					COALESCE(nombre1,'')||' '||COALESCE(nombre2,'')||' '||COALESCE(apellido1,'')||' '||COALESCE(apellido2,'') AS tercero,
					COALESCE(razon_social,'') AS razon_social
				FROM
					general 
				WHERE
					id = '1') as foo
			LEFT OUTER JOIN
				direcciones d
			ON
				d.id = foo.id
			GROUP BY
				foo.id,
				foo.id_char,
				foo.dv,
				foo.tercero,
				foo.razon_social) AS foo1
		LEFT OUTER JOIN
			(SELECT
				d.id_direccion,
				d.direccion,
				m.nombre
			FROM
				direcciones d,
				municipios m
			WHERE
				d.id_dep = m.id_dep AND
				d.municipio = m.municipio) AS m
		ON
			m.id_direccion = foo1.id_direccion) AS foo2
	LEFT OUTER JOIN
		telefonos t
	ON
		t.id = foo2.id) AS foo3
LEFT OUTER JOIN
	establecimiento e
ON
	e.id = foo3.id;