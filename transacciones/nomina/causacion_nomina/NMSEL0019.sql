DROP TABLE IF EXISTS fecha_aux;
CREATE TEMP TABLE fecha_aux AS
SELECT 
	'?'::DATE AS fecha_nom;

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
        info_documento i,
	 	fecha_aux f
    WHERE
        cn.ndocumento=d.ndocumento AND  
        cn.ndocumento=i.ndocumento AND	 	
	 	to_char(cn.fecha, 'MM-YYYY') = to_char(f.fecha_nom, 'MM-YYYY') AND 
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
	 	foo.listar
	) AS c
GROUP BY
	c.ndocumento,
	c.id_tercero;

DROP TABLE IF EXISTS asignacion_conceptos_causacion_ok;
CREATE TEMP TABLE asignacion_conceptos_causacion_ok AS
SELECT
	acc.id,
	acc.id_concepto_causacion,
	cc.valor
FROM	
	asignacion_concepto_causacion acc,
	concepto_causacion cc
WHERE
	cc.id_concepto_causacion=acc.id_concepto_causacion AND
	cc.id_movimiento_nomina='7' AND
	cc.valor!=0
UNION ALL
SELECT
	rn.id_tercero,
	rn.id_concepto_causacion,
	SUM(rn.valor) AS valor
FROM	
	registro_conceptos_nomina_valor rn,
	documentos d,
	concepto_causacion cc,
	info_documento i,
	fecha_aux f
WHERE
	to_char(d.fecha, 'MM-YYYY') = to_char(f.fecha_nom, 'MM-YYYY') AND 
	i.ndocumento=d.ndocumento AND
	i.rf_documento IS NULL AND
	d.ndocumento=rn.ndocumento AND
	d.estado AND
	rn.valor!=0 AND
	cc.id_concepto_causacion=rn.id_concepto_causacion AND
	cc.id_movimiento_nomina='7'
GROUP BY
	rn.id_tercero,
	rn.id_concepto_causacion;
	

	
SELECT
	id_char,
	foo.nombre,
	descripcion,
	0,
	0,
	valor,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	id_tercero_debito,
	id_tercero_credito,
	id_cc,
	valor,
	id_clasificacion_concepto_causacion,
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
	SUM(COALESCE(vp,0)) AS vp,
	0.0 AS devbaseliquidacion,
	genera_base_salarial
FROM
	(SELECT
		id_char,
		foo.nombre,
		descripcion,
		valor,
		COALESCE(c.char_cta,'-1') as id_cta_debito,
		id_cta_credito,
		id_tercero_debito,
		id_tercero_credito,
		id_cc,
		id_clasificacion_concepto_causacion,
		genera_base_salarial
	FROM
		(SELECT
			g.id_char,
			LTRIM(COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')) AS nombre,
			cc.descripcion,
			acc.valor,
			cc.id_cta_debito,
			cc.id_cta_credito,
			COALESCE(cc.id_tercero_debito,g.id) AS id_tercero_debito,
			COALESCE(cc.id_tercero_credito,g.id) AS id_tercero_credito,
			cc.id_concepto_causacion as id_cc,
			COALESCE(ccc.id_clasificacion_concepto_causacion,-1) AS id_clasificacion_concepto_causacion,
			cc.genera_base_salarial
		FROM
			general g,
			asignacion_conceptos_causacion_ok acc,
			datos_division dd,
			(SELECT
				acc.id,
				SUM(cc.valor) AS salariob
			FROM
				asignacion_concepto_causacion acc,
				concepto_causacion cc
			WHERE
				acc.id_concepto_causacion=cc.id_concepto_causacion AND
				cc.id_movimiento_nomina=1 
			GROUP BY
				acc.id) AS sb,
			concepto_causacion cc
		LEFT OUTER JOIN
			clasificacion_conceptos_causacion ccc
		ON
			cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion
		WHERE
			g.id=acc.id AND
			acc.id_concepto_causacion=cc.id_concepto_causacion AND
			g.id=sb.id AND
			cc.tipo_concepto=false AND
			dd.id_tercero=g.id AND
			dd.id_division='?' 
		ORDER BY
			g.id_char,
			cc.descripcion) as foo
	LEFT OUTER JOIN
			cuentas c
		ON
			foo.id_cta_debito=c.id_cta) AS foo
LEFT OUTER JOIN
	cuentas c
ON
	foo.id_cta_credito=c.id_cta
LEFT OUTER JOIN
	tmp_novedades_nomina cnn
ON
	foo.id_tercero_credito=cnn.id_tercero 
GROUP BY
	id_char,
	foo.nombre,
	descripcion,
	valor,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	id_tercero_debito,
	id_tercero_credito,
	id_cc,
	valor,
	id_clasificacion_concepto_causacion,
	genera_base_salarial
ORDER BY
	foo.descripcion,
	foo.nombre;