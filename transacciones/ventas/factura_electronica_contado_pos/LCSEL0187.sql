SELECT
	CASE WHEN r.host IS NOT NULL THEN u.login||' Caja: '||COALESCE(r.host,'') ELSE u.login END AS cajero
FROM
	documentos d,	
	usuarios u,
	info_documento i,
	registro_modificacion rm
LEFT OUTER JOIN
	equipos_registrados r
ON
	rm.ip=r.ip
WHERE	
	d.ndocumento=rm.ndocumento AND
	rm.id_tipo_modificacion = 0 AND
	i.ndocumento=d.ndocumento AND
	i.id_usuario=u.id_usuario AND
	d.codigo_tipo='?' AND
	d.numero=LPAD('?',10,'0');