--LCSEL1023
SELECT
	tc.nombre,
	ta.valor,
	ta.voucher,
	ta.rrn,
	ta.auth,
	ta.four_numbers,
	ta.comision,
	ta.retefuente,
	ta.reteiva,
	tc.id_tcredito,
	cb.char_cta as cta_banco,
	cc.char_cta as cta_gasto,
	crf.char_cta as cta_rtfuente,
	cri.char_cta as cta_rtiva,
	ta.operador,
	ta.transaction_code,
	tc.comision
FROM
	cuentas cb,
	cuentas cc,
	cuentas crf,
	cuentas cri,
	tarjetas ta,
	tcredito tc,
	documentos d
WHERE
	cb.id_cta=tc.id_banco AND
	cc.id_cta=tc.id_cta_comision AND
	crf.id_cta=tc.id_cta_rfuente AND
	cri.id_cta=tc.id_cta_rtiva AND
	ta.id_tcredito=tc.id_tcredito AND
	ta.ndocumento=d.ndocumento AND
	d.codigo_tipo='?' AND
	d.numero=lpad('?',10,'0') and
	cb.char_cta = '28050503';