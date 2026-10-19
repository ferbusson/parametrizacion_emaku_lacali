DROP TABLE IF EXISTS aux_params;
CREATE TEMP TABLE aux_params AS
SELECT 
	'?'::BIGINT AS ndocumento,
	'?'::VARCHAR(12) AS char_cta,
	'?'::FLOAT8 AS valor,
	'?'::SMALLINT AS id_tcredito,
	'?'::FLOAT8 AS comision,
	'?'::VARCHAR AS voucher,
	'?'::CHARACTER(2) AS operador,
	'?'::CHARACTER(10) AS transaction_code,
        '?'::VARCHAR(8) AS rrn,
        '?'::FLOAT8 AS retefuente,
        '?'::FLOAT8 AS reteiva,
        '?'::VARCHAR(10) AS auth,
        '?'::VARCHAR(5) AS four_numbers;

INSERT INTO
	tarjetas(
		ndocumento,
		id_tcredito,
		id_cta,
		valor,
		comision,
		voucher,
		operador,
		transaction_code,
                rrn,
                retefuente,
                reteiva,
                auth,
                four_numbers)
SELECT	
	a.ndocumento,
	a.id_tcredito,
	c.id_cta,	
        a.valor,
	a.comision,
	a.voucher,
	a.operador,
	a.transaction_code,
        a.rrn,
        a.retefuente,
        a.reteiva,
        a.auth,
        a.four_numbers
FROM
	aux_params a,
	cuentas c
WHERE
	a.char_cta = c.char_cta AND
	a.id_tcredito IS NOT NULL;
