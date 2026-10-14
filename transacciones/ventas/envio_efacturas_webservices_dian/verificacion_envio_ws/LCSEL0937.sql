SELECT
	codigo_tipo||'-'||numero||' - Fecha: '||fecha||' '||CASE WHEN estado then ' - Habilitada' else ' - Anulada' end||' Usuario: '||u.login||CHR(10)
FROM
	documentos d,
	info_documento id,
	usuarios u
WHERE
	d.ndocumento = id.ndocumento and
	id.id_usuario = u.id_usuario and
	d.numero NOT IN ('0000000000') and
	d.ndocumento IN 
(select
	ndocumento 
FROM
	documentos 
WHERE
	(codigo_tipo IN ('Z1','G1')
	--no pongo M1 porque las devoluciones no tienen error por salto ya que la query actualmente verifica los documentos con 
	--resolucion facturacion, los que no tienen resolucion tienen salto 0 por defecto
	)
EXCEPT
SELECT
	ndocumento
FROM
	envio_webservice);