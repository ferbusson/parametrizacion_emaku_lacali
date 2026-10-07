SELECT 
	to_char(e.fecha,'YYYY/MM/DD hh:mm:ss') as fecha
FROM
        documentos doc,
        envio_webservice e
WHERE
	doc.ndocumento = e.ndocumento AND
        doc.codigo_tipo='?' AND
        doc.numero=LPAD('?',10,'0');