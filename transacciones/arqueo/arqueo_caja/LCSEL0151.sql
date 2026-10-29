-- CONSULTA VENTAS CON CHEQUE SODEXO PASS
DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT CAST('?' AS character(13)) AS login;

SELECT
	COALESCE(sum(denominacion*cantidad),0.0) AS valor
FROM
	cheques_sodexobigpass cs,
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
	foo.ndocumento=cs.ndocumento AND
	cs.id_sodexobigpass = 1; 