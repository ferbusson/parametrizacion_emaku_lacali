--LCSEL1013

select
	d.ndocumento,
    'EXCEL '||d.numero::bigint||' - '||d.fecha
FROM
    documentos d
WHERE
    d.codigo_tipo = '83'
    AND d.estado = true
order BY
    d.numero::bigint desc
limit 10;