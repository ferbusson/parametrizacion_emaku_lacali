SELECT
	t.nombre,
	t.tipo,
	t.id_tcredito,
	t.comision,
        c.char_cta,
        cg.char_cta AS cuenta_gasto,
        cf.char_cta AS cuenta_retefuente,
        ci.char_cta AS cuenta_reteiva,
        t.id_banco,
        g.id_char,
        t.prte_fuente,
        t.prte_iva
FROM
	cuentas c,
	general g,
	tcredito t
LEFT OUTER JOIN
	cuentas cg
ON
	t.id_cta_comision = cg.id_cta
LEFT OUTER JOIN
	cuentas cf
ON
	t.id_cta_rfuente = cf.id_cta
LEFT OUTER JOIN
	cuentas ci
ON
	t.id_cta_rtiva = ci.id_cta
WHERE
	t.id_banco = c.id_cta AND
	g.id = t.id_tercero_banco
ORDER BY
	id_tcredito;