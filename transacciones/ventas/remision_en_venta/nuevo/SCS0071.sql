--SCS0071
-- no necesita fecha, se ejecuta en la Cali
SELECT
    i.orden,
    id.rf_documento,
    CASE WHEN
        i.salida IS NOT NULL AND
        i.salida != 0 AND
        (d.codigo_tipo = '21' OR --REMISION EN VENTA
        d.codigo_tipo like 'G%' OR --FACTURA ELECTRONICA PRINCIPAL
        d.codigo_tipo like 'C%' OR --CAMBIOS PRINCIPAL         
        d.codigo_tipo like 'Z%' OR --FPOS ELECTRONICA PRINCIPAL
        d.codigo_tipo like 'F%' OR --FACTURACION PRINCIPAL FACTURA WEB
        d.codigo_tipo like 'P%' OR--FACTURA CONTINGENCIA POS-E PRINCIPAL
        d.codigo_tipo IN ('TB','TF','TI','TR','TE','TA','TG','TU','TL')
        ) 
    THEN 'TB'
         ELSE CASE WHEN
            i.entrada IS NOT NULL AND
            i.entrada != 0 AND
            (d.codigo_tipo like 'M%' OR --DVENTA ELECTRONICA PRINCIPAL
            d.codigo_tipo like 'L%' OR --DEVOLUCION VENTA PRINCIPAL
            d.codigo_tipo = 'DW' OR --DEVOLUCION VENTA WEB
            d.codigo_tipo like 'C%') --CAMBIOS PRINCIPAL
         THEN 'DV'
         ELSE CASE WHEN 
                i.entrada IS NOT NULL AND
                d.codigo_tipo IN ('EA','IM','RC','AT','SI','IP','AO','AF') THEN 'EA' 
         ELSE CASE WHEN 
                    i.entrada IS NOT NULL AND
                    (d.codigo_tipo IN ('21','TF','TI','TB','TR','TE','TA','TG','TU','TL') OR --traslados
                    --d.codigo_tipo IN ('IJ','AF','AO') OR --ajustes
                    d.codigo_tipo IN ('S1','S3','S4','S5') -- separados
                    ) THEN 'TB'
                ELSE
                    'IJ'
                END
            END
          END 
    END AS codigo_tipo,
    i.pinventario,
    d.estado,
    i.entrada,
    i.valor_ent,
    i.salida,
    i.valor_sal
FROM
    inventarios i,
    documentos d
LEFT OUTER JOIN
    info_documento id
ON
    d.ndocumento=id.ndocumento
WHERE
    i.ndocumento=d.ndocumento AND   
    id_bodega='?' AND
    id_prod_serv='?' 
ORDER BY
    i.fecha,
    i.orden;