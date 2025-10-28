drop table if exists aux_parametro_tercero;
create temp table aux_parametro_tercero as
select 	
	'?'::INTEGER as id_tercero;

SELECT
	CAST(fecha AS date) AS fecha,
	CAST(textcat(text(dcredito), text(' dias')) AS text) AS dcredito,
	CAST(fecha + CAST(textcat(text(dcredito), text(' days')) as interval) AS date) AS vencimiento,
	numero,
	saldo,
	0,
	0,
	0,
	0,
	ndocumento,
	vfactura,
	0,
	char_cta,
	id_cta
FROM
(SELECT
	c.fecha,
	c.numero,
	c.idtercero,
	c.nfactura,
	c.dcredito,
	c.vfactura,
	c.tfactura,
	c.tfactura+COALESCE(co.cargos,0)-COALESCE(co.vcomprobante,0) AS saldo,
	c.char_cta,
	c.id_cta,
	c.ndocumento
FROM
        (SELECT
			d.fecha,
			COALESCE(rf.prefijo,d.codigo_tipo)||'-'||d.numero::BIGINT AS numero,
			c.idtercero,
	        c.nfactura,
	        c.dcredito,
	        SUM(c.neto_factura) AS vfactura,
	        SUM(c.total_factura) AS tfactura,
			ac.char_cta,
			ac.id_cta,
			d.ndocumento
        FROM
			cartera c,
			cuentas ac,
			administracion_sucursales a,
			aux_parametro_tercero apt,
			documentos_sucursales ds,
			documentos d
        LEFT OUTER JOIN
			resolucion_documento rd
		ON
			d.ndocumento = rd.ndocumento
		LEFT OUTER JOIN
			resolucion_facturacion rf
		ON
			rd.id_resolucion_facturacion = rf.id_resolucion_facturacion 
	    WHERE
			d.codigo_tipo = ds.codigo_tipo and			
			ds.id_administracion_sucursales = a.id_administracion_sucursales AND
			ac.id_cta=c.id_cta and
			ac.char_cta not in ('28050502') and -- se excluyen los separados Oct 7 2024
			d.ndocumento=c.nfactura AND
			c.idtercero=apt.id_tercero AND
			d.estado='true' AND
			c.movimiento=true AND
			c.total_factura>0
	    GROUP BY
			d.fecha,
			COALESCE(rf.prefijo,d.codigo_tipo)||'-'||d.numero::BIGINT,
			d.ndocumento,
			c.idtercero,
            c.nfactura,
            c.dcredito,
			ac.id_cta,
			ac.char_cta
		union all --Oct 28 2025: adiciono la union porque se requiere hacer pagos de documentos generados por notas: 1F desde el formulario abono cartera Chat Maria E
		SELECT
			d.fecha,
			d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
			c.idtercero,
		    c.nfactura,
		    c.dcredito,
		    SUM(c.neto_factura) AS vfactura,
		    SUM(c.total_factura) AS tfactura,
			ac.char_cta,
			ac.id_cta,
			d.ndocumento
		FROM
			cartera c,
			cuentas ac,
			aux_parametro_tercero apt,
			documentos d 
		WHERE
			d.codigo_tipo in ('1F') AND			
			ac.id_cta=c.id_cta and
			ac.char_cta not in ('28050502') and -- se excluyen los separados Oct 7 2024
			d.ndocumento=c.nfactura AND
			c.idtercero=apt.id_tercero AND
			d.estado='true' AND
			c.movimiento=true AND
			c.total_factura>0
		GROUP BY
			d.fecha,
			d.codigo_tipo||'-'||d.numero::BIGINT,
			d.ndocumento,
			c.idtercero,
		    c.nfactura,
		    c.dcredito,
			ac.id_cta,
			ac.char_cta) AS c
LEFT OUTER JOIN
        (SELECT
            c.nfactura,
            SUM(c.abono_comprobante)+SUM(c.dcto_comprobante) AS vcomprobante,
			SUM(c.cargo_comprobante) AS cargos
        FROM
            cartera c,
            documentos d
        WHERE
            c.ncomprobante=d.ndocumento AND
            d.estado='true'
        GROUP BY
            c.nfactura) AS co
ON
        co.nfactura=c.nfactura) AS foo
WHERE
	foo.saldo>0 
ORDER BY
	fecha,
	nfactura;


