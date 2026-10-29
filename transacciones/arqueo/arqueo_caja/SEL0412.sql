SELECT 
	TRIM(g.nombre1||' '||g.nombre2||' '||g.apellido1||' '||g.apellido2) as nombre
FROM
	general g,
	usuarios u
WHERE
	u.id_usuario=g.id AND
	u.login='?'