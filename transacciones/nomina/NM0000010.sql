DROP TABLE IF EXISTS aux_validacion_novedades_validas;
CREATE TEMP TABLE aux_validacion_novedades_validas AS 
SELECT DISTINCT
	foo.ndocumento,
	foo.fecha,
	foo.mes,
	foo.id_novedad_nomina,
	foo.id_tercero,
	CASE WHEN cn.id_tercero IS NOT NULL THEN FALSE ELSE TRUE END AS listar
FROM
	(SELECT -- todas las novedades del mes anio y sus referencias a causacion_nomina
		cn.ndocumento, -- ndocumento novedad nomina
		cn.fecha,
	 	extract('month' from cn.fecha) AS mes,
		cn.id_novedad_nomina,
		cn.id_tercero,
		i.rf_documento AS ndocumento_causacion_nomina
	FROM
		causacion_novedades_nomina cn,
		documentos d,
		info_documento i
	WHERE
		cn.ndocumento=d.ndocumento AND	
		cn.ndocumento=i.ndocumento AND
	 	to_char(cn.fecha, 'MM-YYYY') = to_char('?'::DATE, 'MM-YYYY') AND 
		d.estado) AS foo
LEFT OUTER JOIN
	causacion_nomina cn
ON
	foo.ndocumento_causacion_nomina = cn.ndocumento AND
	foo.id_tercero = cn.id_tercero;

DROP TABLE IF EXISTS tmp_novedades_nomina;
CREATE TEMP TABLE tmp_novedades_nomina AS 
SELECT
	c.ndocumento,
	c.id_tercero,
	SUM(ig) AS ig,
	SUM(il) AS il,
	SUM(lm) AS lm,
	SUM(lp) AS lp,
	sum(lr) AS lr,
	sum(ln) AS ln,
	SUM(sc) AS sc,
	SUM(inc) AS inc,
	SUM(re) AS re,
	SUM(vc) AS vc,
	SUM(vp) AS vp
FROM
	(SELECT
		cn.ndocumento,
		cn.id_tercero,
		CASE WHEN foo.id_novedad_nomina in (3,16) THEN dias ELSE 0 END AS IG,
		CASE WHEN foo.id_novedad_nomina = 4 THEN dias ELSE 0 END AS IL,
		CASE WHEN foo.id_novedad_nomina = 5 THEN dias ELSE 0 END AS LM,
		CASE WHEN foo.id_novedad_nomina = 6 THEN dias ELSE 0 END AS LP,
		CASE WHEN foo.id_novedad_nomina = 7 THEN dias ELSE 0 END AS LR,
		CASE WHEN foo.id_novedad_nomina = 8 THEN dias ELSE 0 END AS LN,
		CASE WHEN foo.id_novedad_nomina = 9 THEN dias ELSE 0 END AS SC,
		CASE WHEN foo.id_novedad_nomina = 10 THEN extract('day' from foo.fecha) ELSE 0 END AS INC,
		CASE WHEN foo.id_novedad_nomina = 11 AND foo.mes = 2 AND (extract('day' from foo.fecha) = 28 OR extract('day' from foo.fecha) = 29) THEN 30
	 	ELSE CASE WHEN foo.id_novedad_nomina = 11 AND extract('day' from foo.fecha) = 31 THEN 30 
	 	ELSE CASE WHEN foo.id_novedad_nomina = 11 THEN extract('day' from foo.fecha) 
	 	ELSE 0
		END END END AS RE,
		CASE WHEN foo.id_novedad_nomina = 12 THEN dias ELSE 0 END AS VC,
		CASE WHEN foo.id_novedad_nomina = 13 THEN dias ELSE 0 END AS VP
	FROM
		causacion_novedades_nomina cn,
		aux_validacion_novedades_validas AS foo
	WHERE
		cn.ndocumento=foo.ndocumento AND
		cn.fecha = foo.fecha AND
		cn.id_novedad_nomina = foo.id_novedad_nomina AND
		cn.id_tercero = foo.id_tercero AND
		foo.listar) AS c
GROUP BY
	c.ndocumento,
	c.id_tercero;
	
--

SELECT
	id_char,
	foo.nombre,
	foo.descripcion,
	foo.valor,
        0,
        0,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	id_tercero_debito,
	id_tercero_credito,
	id_cc,
	SUM(COALESCE(ig,0)) AS ig,
	SUM(COALESCE(il,0)) AS il,
	SUM(COALESCE(lm,0)) AS lm,
	SUM(COALESCE(lp,0)) AS lp,
	SUM(COALESCE(lr,0)) AS lr,
	SUM(COALESCE(ln,0)) AS ln,
	SUM(COALESCE(sc,0)) AS sc,
	SUM(COALESCE(inc,0)) AS inc,
	SUM(COALESCE(re,0)) AS re,
	SUM(COALESCE(vc,0)) AS vc,
	SUM(COALESCE(vp,0)) AS vp
FROM
	(SELECT
		id_char,
		foo.nombre,
		foo.descripcion,
		foo.valor,
		COALESCE(c.char_cta,'-1') as id_cta_debito,
		id_cta_credito,
		foo.id_tercero_debito,
		foo.id_tercero_credito,
		foo.id_concepto_causacion as id_cc,
		COALESCE(ig,0) AS ig,
		COALESCE(il,0) AS il,
		COALESCE(lm,0) AS lm,
		COALESCE(lp,0) AS lp,
		COALESCE(lr,0) AS lr,
		COALESCE(ln,0) AS ln,
		COALESCE(sc,0) AS sc,
		COALESCE(inc,0) AS inc,
		COALESCE(re,0) AS re,
		COALESCE(vc,0) AS vc,
		COALESCE(vp,0) AS vp
	FROM
		(SELECT
			g.id_char,
			LTRIM(COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')) AS nombre,
			cc.descripcion,
			cc.valor,
			COALESCE(cc.id_cta_debito,'-1') as id_cta_debito,
			COALESCE(cc.id_cta_credito,'-1') as id_cta_credito,		
			COALESCE(cc.id_tercero_debito,g.id) AS id_tercero_debito,
			COALESCE(cc.id_tercero_credito,g.id) AS id_tercero_credito,
			cc.id_concepto_causacion
		 
		FROM
			general g,
			asignacion_concepto_causacion acc,
			concepto_causacion cc,
			datos_division dd
		WHERE
			g.id=acc.id AND
			acc.id_concepto_causacion=cc.id_concepto_causacion AND
			cc.id_movimiento_nomina=1 AND
			dd.id_tercero=g.id AND
			dd.id_division='?' AND --- DIVISION 
			cc.id_clasificacion_concepto_causacion in (1,45)
		ORDER BY
			g.id_char,
			cc.descripcion) as foo
	LEFT OUTER JOIN
			cuentas c
		ON
			foo.id_cta_debito=c.id_cta
	LEFT OUTER JOIN
			tmp_novedades_nomina cnn
		ON
			foo.id_tercero_credito=cnn.id_tercero
	LEFT OUTER JOIN
		documentos d
	ON
		cnn.ndocumento = d.ndocumento AND
		d.estado) AS foo
LEFT OUTER JOIN
	cuentas c
ON
	foo.id_cta_credito=c.id_cta
GROUP BY
	id_char,
	foo.nombre,
	foo.descripcion,
	foo.valor,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	id_tercero_debito,
	id_tercero_credito,
	id_cc
ORDER BY
	foo.nombre;