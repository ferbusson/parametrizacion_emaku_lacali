-- CONSULTA VENTAS CON TARJETA CREDITO
DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT '?'::VARCHAR(70) AS login;

DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT
	ds.codigo_tipo
FROM
	documentos_standar dst,
	asignacion_usuario_sucursal au, 
	documentos_sucursales ds,
	tmp_usuario t,
	usuarios u
WHERE
	t.login = u.login AND
	u.id_usuario = au.id AND
	dst.id_documento=ds.id_documento AND
	au.id_administracion_sucursales=ds.id_administracion_sucursales;


SELECT
	COALESCE(SUM(t.valor),0) AS valor
FROM
	tcredito tc,
	tarjetas t,
	datos_documento dd,
	(SELECT
		d.ndocumento
	FROM
		documentos d,
		info_documento i,
		tipo_docs td,
		usuarios u,
		tmp_usuario t
	where
		d.codigo_tipo = td.codigo_tipo and
		d.estado AND
		d.ndocumento=i.ndocumento AND
		i.id_usuario=u.id_usuario AND
		u.login=t.login
	EXCEPT
	SELECT
		a.ndocumento
	FROM
		documentos d,
		datos_arqueo a,
		info_documento i,
		usuarios u,
		tmp_usuario t
	WHERE
		d.ndocumento=a.narqueo AND
		d.estado AND
		A.ndocumento=i.ndocumento AND
		i.id_usuario=u.id_usuario AND
		u.login=t.login) AS foo
WHERE
	foo.ndocumento=t.ndocumento AND
	foo.ndocumento=dd.ndocumento AND
	t.id_tcredito = tc.id_tcredito  AND 
	tc.tipo = 'CR';