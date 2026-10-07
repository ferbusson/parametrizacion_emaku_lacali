SELECT 
    cu.char_cta
FROM 
    datos_documento dd,
    clase_cxp cxp,
    cuentas cu
WHERE 
    dd.ndocumento = '?' AND
    dd.id_clase_cxp = cxp.id_clase_cxp AND
    cxp.id_cta_cxp = cu.id_cta;