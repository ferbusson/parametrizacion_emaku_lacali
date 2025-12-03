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
	SUM(vp) AS vp,
	SUM(igemp) AS igemp,
	SUM(igeps) AS igeps
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
		CASE WHEN foo.id_novedad_nomina = 13 THEN dias ELSE 0 END AS VP,
	 	CASE WHEN foo.id_novedad_nomina = 3 THEN dias ELSE 0 END AS IGEMP,
		CASE WHEN foo.id_novedad_nomina = 16 THEN dias ELSE 0 END AS IGEPS		
	FROM
		causacion_novedades_nomina cn,
		aux_validacion_novedades_validas AS foo
	WHERE
		cn.ndocumento=foo.ndocumento AND
	 	cn.fecha = foo.fecha AND
	 	cn.id_novedad_nomina = foo.id_novedad_nomina AND
	 	cn.id_tercero = foo.id_tercero AND
	 	foo.listar
	ORDER BY
		cn.id_tercero) AS c
GROUP BY
	c.ndocumento,
	c.id_tercero;

DROP TABLE IF EXISTS salarios_ok;
CREATE TEMP TABLE salarios_ok AS
SELECT
	ac.id,
	SUBSTRING(c.char_cta,1,2) AS clase
FROM
	asignacion_concepto_causacion ac,
	concepto_causacion cc,
	cuentas c
WHERE
	ac.id_concepto_causacion=cc.id_concepto_causacion AND
	c.id_cta=cc.id_cta_debito AND
	cc.id_movimiento_nomina=1 AND
	cc.id_clasificacion_concepto_causacion=1;

DROP TABLE IF EXISTS asignacion_concepto_causacion_ok;			
CREATE TEMP TABLE asignacion_concepto_causacion_ok AS
SELECT DISTINCT
	id,
	id_concepto_causacion
FROM
	(SELECT
		id,
		id_concepto_causacion
	FROM
		asignacion_concepto_causacion a
	UNION ALL
	-- CONCEPTO DE INCAPACIDAD GENERAL
	SELECT
		tn.id_tercero,
		cc.id_concepto_causacion
	FROM
		tmp_novedades_nomina tn,
		concepto_causacion cc,
	 	asignacion_concepto_causacion ac,
		cuentas c,
		salarios_ok ck
	WHERE
	 	ac.id = tn.id_tercero AND
		ck.id=tn.id_tercero AND
	 	ac.id_concepto_causacion = cc.id_concepto_causacion AND
		ck.clase=SUBSTRING(c.char_cta,1,2) AND
		cc.id_cta_debito=c.id_cta AND
		cc.id_clasificacion_concepto_causacion=22 AND -- CONCEPTOS CAUSACION INCAPACIDAD GENERAL
		igemp!=0
	UNION ALL
	-- CONCEPTO DE INCAPACIDAD GENERAL EPS
	SELECT
		tn.id_tercero,
		cc.id_concepto_causacion
	FROM
		tmp_novedades_nomina tn,
		concepto_causacion cc
	WHERE
		cc.id_concepto_causacion IN (186) AND -- CONCEPTOS CAUSACION INCAPACIDAD GENERAL EPS
		tn.igeps!=0
	UNION ALL
	-- CONCEPTO LICENCIA DE MATERNIDAD
	SELECT
		tn.id_tercero,
		cc.id_concepto_causacion
	FROM
		tmp_novedades_nomina tn,
		concepto_causacion cc
	WHERE
		cc.id_concepto_causacion IN (194) AND -- LICENCIA DE MATERNIDAD
		tn.lm!=0
	-- CONCEPTO LICENCIA DE PATERNIDAD
	UNION ALL
	SELECT
		tn.id_tercero,
		cc.id_concepto_causacion
	FROM
		tmp_novedades_nomina tn,
		concepto_causacion cc
	WHERE
		cc.id_concepto_causacion IN (195) AND -- LICENCIA DE PATERNIDAD
		tn.lp!=0
	UNION ALL
	-- LICENCIA REMUNERADA
	SELECT
		tn.id_tercero,
		cc.id_concepto_causacion
	FROM
		tmp_novedades_nomina tn,
		concepto_causacion cc,
		cuentas c,
		salarios_ok ck
	WHERE
		ck.id=tn.id_tercero AND
		ck.clase=SUBSTRING(c.char_cta,1,2) AND
		cc.id_cta_debito=c.id_cta AND
		cc.id_clasificacion_concepto_causacion=24 AND -- CONCEPTOS CAUSACION LICENCIA REMUNARADA
		lr!=0) AS foo;
	
/*
UNION ALL
-- CONCEPTO DE INCAPACIDAD LABORAL
SELECT
	tn.id_tercero,
	cc.id_concepto_causacion
FROM
	tmp_novedades_nomina tn,
	concepto_causacion cc,
	cuentas c,
	salarios_ok ck
WHERE
	ck.id=tn.id_tercero AND
	ck.clase=SUBSTRING(c.char_cta,1,2) AND
	cc.id_cta_debito=c.id_cta AND
	cc.id_concepto_causacion IN (184,185) AND -- CONCEPTOS CAUSACION INCAPACIDAD LABORAL
	id_novedad_nomina IN (3);
*/

DROP TABLE IF EXISTS salario_minimo;
CREATE TEMP TABLE salario_minimo AS
SELECT 
	valor AS minimo,
	ROUND((valor/30/7.3333)::numeric,0) AS valor_minimo_hora_extra
FROM
	concepto_causacion 
WHERE
	id_concepto_causacion=1;


SELECT
	id_char,
	foo.nombre,
	descripcion,
	0,
    0,
    salariob,
	porcentaje,
	0,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	salariob,
	tipo_concepto,
	0, -- extras o
	0, -- extras d
	0, -- recargos
	0, -- dominicales
	id_tercero_debito,
	id_tercero_credito,
	id_cc,
	id_clasificacion_concepto_causacion,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,56,23,24,26,51) THEN CASE WHEN id_cc=186 THEN COALESCE(igeps,0) ELSE COALESCE(igemp,0) END ELSE 0 END) AS ig,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,23,24,26,51) THEN COALESCE(il,0) ELSE 0 END) AS il,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,56,24,26,51) THEN COALESCE(lm,0) ELSE 0 END) AS lm,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,56,24,26,51) THEN COALESCE(lp,0) ELSE 0 END) AS lp,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,56,23,26,51) THEN COALESCE(lr,0) ELSE 0 END) AS lr,
	SUM(COALESCE(ln,0)) AS ln,
	SUM(COALESCE(sc,0)) AS sc,
	SUM(COALESCE(inc,0) )AS inc,
	SUM(COALESCE(re,0)) AS re,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,56,24,51) THEN COALESCE(vc,0) ELSE 0 END) AS vc,
	SUM(CASE WHEN id_clasificacion_concepto_causacion NOT IN (21,22,56,24,26) THEN COALESCE(vp,0) ELSE 0 END) AS vp,
	0.0 AS devbaseliquidacion,
	genera_base_salarial
FROM
	(SELECT
		id_char,
		foo.nombre,
		descripcion,
		porcentaje,
		COALESCE(c.char_cta,'-1') as id_cta_debito,
		id_cta_credito,
		salariob,
		tipo_concepto,
		id_tercero_debito,
		id_tercero_credito,
		foo.id_cc,
		id_clasificacion_concepto_causacion,
		genera_base_salarial
	FROM
		(SELECT
			g.id_char,
			LTRIM(COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')) AS nombre,
			cc.descripcion,
			cc.porcentaje,
			sb.salariob,
			cc.tipo_concepto,
			cc.id_cta_debito,
			cc.id_cta_credito,
			COALESCE(cc.id_tercero_debito,g.id) AS id_tercero_debito,
			COALESCE(cc.id_tercero_credito,g.id) AS id_tercero_credito,
			cc.id_concepto_causacion as id_cc,
			COALESCE(ccc.id_clasificacion_concepto_causacion,-1) AS id_clasificacion_concepto_causacion,
			cc.genera_base_salarial
		FROM
			general g,
			asignacion_concepto_causacion_ok acc,			
			datos_division dd,
			(SELECT
				acc.id,
				SUM(cc.valor) AS salariob
			FROM
				asignacion_concepto_causacion acc,
				concepto_causacion cc
			WHERE
				acc.id_concepto_causacion=cc.id_concepto_causacion AND
				cc.id_movimiento_nomina=1 AND
			 	cc.id_clasificacion_concepto_causacion in (1,45)
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
			cc.id_movimiento_nomina='5' AND
			g.id=sb.id AND
			dd.id_tercero=g.id AND
			dd.id_division='?' --- DIVISION 
		ORDER BY
			g.id_char,
			cc.descripcion) AS foo
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
    salariob,
	porcentaje,
	id_cta_debito,
	COALESCE(c.char_cta,'-1'),
	salariob,
	tipo_concepto,
	id_tercero_debito,
	id_tercero_credito,
	id_cc,
	id_clasificacion_concepto_causacion,
	genera_base_salarial
ORDER BY
	foo.descripcion,
	foo.nombre;