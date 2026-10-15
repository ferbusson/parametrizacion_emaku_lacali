SELECT 
	id_tcredito,
	nombre||' '||tipo
FROM 
	tcredito
WHERE
	visible and
	id_tcredito not in (129,130) -- se excluyen las que se usan para pagos hechos por la cali
ORDER BY
	nombre||' '||tipo;