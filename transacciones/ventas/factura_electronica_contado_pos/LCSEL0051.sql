SELECT 
	COALESCE(operador,'NA') AS operador,
        COALESCE(voucher,'NA') AS voucher,
        COALESCE(transaction_code,'NA') AS transaction_code        
FROM 
	documentos d
LEFT OUTER JOIN
	(SELECT 
		t.*
	FROM 
		tarjetas t,
		(SELECT
			count(*) as ct, 
			ndocumento
		FROM 
			tarjetas t
		WHERE 
			operador = 'CR' 
		GROUP BY 
			ndocumento) AS foo 
	WHERE 
		t.ndocumento = foo.ndocumento AND
		foo.ct =1 ) AS t
ON
	d.ndocumento = t.ndocumento
WHERE 
	d.codigo_tipo='?' AND 
	d.numero=LPAD('?',10,'0');

