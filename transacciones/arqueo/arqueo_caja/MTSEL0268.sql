-- CONSULTA VENTAS CON TARJETA DEBITO
DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT '?'::VARCHAR(70) AS login;

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
		usuarios u,
		tmp_usuario t
	WHERE
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
	tc.tipo != 'CR';