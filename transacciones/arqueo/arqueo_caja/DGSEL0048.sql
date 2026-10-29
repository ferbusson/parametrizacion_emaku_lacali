SELECT 
	SUM(foo.efectivo) 
FROM 
	(SELECT
		dd.efectivo-dd.cambio AS efectivo
	FROM
		documentos d, 
		datos_documento dd,
		info_documento i,
		usuarios u,
		(SELECT
			d.ndocumento
		FROM
			documentos d
                WHERE
                         d.estado=true
		EXCEPT
		SELECT
			da.ndocumento
		FROM
			datos_arqueo da,
			documentos d
		WHERE
			d.codigo_tipo='AQ' AND
			da.narqueo=d.ndocumento AND
			d.estado='TRUE') AS foo
	WHERE
		d.ndocumento=dd.ndocumento AND
		d.ndocumento=i.ndocumento AND
		(d.codigo_tipo='FA' OR d.codigo_tipo='FM') AND
		u.id_usuario=i.id_usuario AND
		u.login='?' AND
		dd.efectivo>0 AND
		d.estado=true AND
		d.ndocumento=foo.ndocumento
	ORDER BY
	       d.numero , d.fecha) as foo