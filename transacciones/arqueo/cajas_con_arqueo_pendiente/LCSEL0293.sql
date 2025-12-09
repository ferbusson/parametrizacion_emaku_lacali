DROP TABLE IF EXISTS aux_params;
CREATE TEMP TABLE aux_params AS
SELECT
	'?'::DATE AS fecha_corte;

DROP TABLE IF EXISTS aux_ult_arqueo;
CREATE TEMP TABLE aux_ult_arqueo AS
SELECT
	i.id_usuario,
	MAX(d.ndocumento) AS ndocumento
FROM
	documentos d,
	info_documento i,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.nombre IN ('ARQUEO') AND
	dst.id_documento = ds.id_documento AND	
	ds.codigo_tipo = d.codigo_tipo AND
	d.ndocumento = i.ndocumento AND
	d.estado
GROUP BY
	i.id_usuario;

DROP TABLE IF EXISTS aux_documentos;
CREATE TEMP TABLE aux_documentos AS
SELECT
	d.ndocumento
FROM
	documentos d,
	documentos_standar dst,
	documentos_sucursales ds,
	aux_params a
WHERE
	dst.nombre IN ('FACTURACION','RECARGA TARJETAS','FCREDITO','SEPARADOS','ABONOS SEPARADOS','COMPROBANTES INGRESO','CAMBIOS','DEVOLUCION VENTA','DVENTA ELECTRONICA','REEMPLAZO PAGOS PARCIALES','ENTREGA BASE SENCILLA','RETIRO PARCIAL','FCONTINGENCIA') AND
	dst.id_documento = ds.id_documento AND	
	ds.codigo_tipo = d.codigo_tipo AND
	d.estado AND
	d.fecha::DATE <= a.fecha_corte
EXCEPT
SELECT
	da.ndocumento
FROM
	datos_arqueo da,
	documentos d
WHERE
	da.narqueo = d.ndocumento AND
	d.estado;


SELECT
	u.login,
	COALESCE(foo.numero,'--') AS num_ult_arqueo,
	foo.fecha AS fecha_ult_arqueo,
	COUNT(1) AS cont,	
	COALESCE(er.host,'Equipo No registrado: '||rm.ip) AS caja,
	SUM(valor) AS valor_venta
FROM
	usuarios u,
	aux_documentos a,
	info_documento i,
	datos_documento dd,
	registro_modificacion rm
LEFT OUTER JOIN
	equipos_registrados er
ON
	rm.ip = er.ip
LEFT OUTER JOIN
	(SELECT
		au.id_usuario,
		d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
		d.fecha::DATE AS fecha
	FROM
		aux_ult_arqueo au,
		documentos d
	WHERE
		au.ndocumento = d.ndocumento) AS foo
ON
	foo.id_usuario = rm.id_usuario
WHERE
	a.ndocumento = i.ndocumento AND
	dd.ndocumento = i.ndocumento AND
	a.ndocumento = rm.ndocumento AND
	i.id_usuario = u.id_usuario AND
	i.id_usuario = rm.id_usuario
GROUP BY
	u.login,
	COALESCE(er.host,'Equipo No registrado: '||rm.ip),
	foo.numero,
	foo.fecha	
ORDER BY
	u.login;