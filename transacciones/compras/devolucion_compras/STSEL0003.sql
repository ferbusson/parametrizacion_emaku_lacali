SELECT 
    cu.char_cta
FROM 
    clase_cxp cxp,
    cuentas cu,
	cuentas cu2
WHERE 
    cu2.char_cta = '?' AND
	cu2.id_cta = cxp.id_cta_cxp AND
    cxp.id_cta_cxp = cu.id_cta;