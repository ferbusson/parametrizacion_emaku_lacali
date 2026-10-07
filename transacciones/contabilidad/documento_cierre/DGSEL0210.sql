DROP TABLE IF EXISTS sdo_cierre_cta;
CREATE TEMP TABLE sdo_cierre_cta AS
SELECT
	l.id_cta,
	l.id_tercero,
	l.id_prod_serv,
	ROUND(SUM(haber)::numeric,2)-ROUND(SUM(debe)::numeric,2) AS saldo
FROM
	libro_auxiliar l,
	cuentas c
WHERE
	c.id_cta=l.id_cta AND
	c.char_cta LIKE '4%' AND
	CAST(l.fecha AS date)<=CAST('?' AS date)
GROUP BY
	l.id_cta,
	l.id_tercero,
	l.id_prod_serv;

DROP TABLE IF EXISTS cierre_saldos;
CREATE TEMP TABLE cierre_saldos AS
SELECT
	c.char_cta,
	c.id_cta,
	l.id_tercero,
	l.id_prod_serv,
	c.nombre,
	CASE WHEN (p.naturaleza AND l.saldo>0) OR (p.naturaleza=false AND l.saldo<0) THEN ABS(l.saldo) ELSE 0 END AS sdo_debe,
	CASE WHEN (p.naturaleza=false AND l.saldo>0) OR (p.naturaleza AND l.saldo<0) THEN ABS(l.saldo) ELSE 0 END AS sdo_haber
FROM
	cuentas c,
	perfil_cta p,
	sdo_cierre_cta AS l
WHERE
	l.id_cta=c.id_cta AND
	p.id_cta=l.id_cta AND
	l.saldo!=0;

SELECT
	c.char_cta,
	c.nombre,
	c.id_char,
	p.codigo,
	c.sdo_debe,
	c.sdo_haber,
	0,
	c.id_cta,
	c.id_tercero,
	c.id_prod_serv
FROM	
	(SELECT
		c.char_cta,
		c.nombre,
		g.id_char,
		c.sdo_debe,
		c.sdo_haber,
		c.id_cta,
		c.id_tercero,
		c.id_prod_serv
	FROM
		cierre_saldos c
	LEFT OUTER JOIN
		general g
	ON
		g.id=c.id_tercero) AS c
LEFT OUTER JOIN
	prod_serv p
ON
	p.id_prod_serv=c.id_prod_serv
ORDER BY
	char_cta,
	id_char,
	codigo