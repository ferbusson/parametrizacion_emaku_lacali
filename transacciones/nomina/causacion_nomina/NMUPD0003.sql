DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
	'?'::bigint AS ndocumento,
	'?'::varchar AS cc;
	
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
	(SELECT DISTINCT
		cn.ndocumento,
		cn.id_tercero,
		CASE WHEN id_novedad_nomina in (3,16) THEN dias ELSE 0 END AS IG,
		CASE WHEN id_novedad_nomina = 4 THEN dias ELSE 0 END AS IL,
		CASE WHEN id_novedad_nomina = 5 THEN dias ELSE 0 END AS LM,
		CASE WHEN id_novedad_nomina = 6 THEN dias ELSE 0 END AS LP,
		CASE WHEN id_novedad_nomina = 7 THEN dias ELSE 0 END AS LR,
		CASE WHEN id_novedad_nomina = 8 THEN dias ELSE 0 END AS LN,
		CASE WHEN id_novedad_nomina = 9 THEN dias ELSE 0 END AS SC,
		CASE WHEN id_novedad_nomina = 10 THEN extract('day' from fecha) ELSE 0 END AS INC,
		CASE WHEN id_novedad_nomina = 11 THEN extract('day' from fecha) ELSE 0 END AS RE,
		CASE WHEN id_novedad_nomina = 12 THEN dias ELSE 0 END AS VC,
		CASE WHEN id_novedad_nomina = 13 THEN dias ELSE 0 END AS VP
	FROM
		causacion_novedades_nomina cn,
		(SELECT
			cn.ndocumento
		FROM
			causacion_novedades_nomina cn,
			documentos d,
			info_documento i
		WHERE
			i.rf_documento IS NULL AND
			i.ndocumento=d.ndocumento AND
			d.ndocumento=cn.ndocumento AND
			d.estado) AS foo
	WHERE
		cn.ndocumento=foo.ndocumento) AS c
GROUP BY
	c.ndocumento,
	c.id_tercero;


UPDATE 
	info_documento
SET
	rf_documento=f.ndocumento_nomina
FROM
	(SELECT DISTINCT
		cn.ndocumento AS ndocumento_nomina,
		tc.ndocumento
	FROM
		args_nomina an,
        documentos d,
        documentos d2,
		causacion_nomina cn,
		tmp_novedades_nomina tc
	WHERE
        cn.ndocumento=d.ndocumento AND
		cn.ndocumento=an.ndocumento AND
		cn.id_tercero=tc.id_tercero AND
        tc.ndocumento = d2.ndocumento and
        d2.estado and
		EXTRACT(YEAR FROM d.fecha) = EXTRACT(YEAR FROM d2.fecha) AND
		EXTRACT(MONTH FROM d.fecha) = EXTRACT(MONTH FROM d2.fecha)) AS f
WHERE
	info_documento.ndocumento=f.ndocumento;

/*
	actualiza rf_documento de documentos de registro_extras_nomina con ndocumento 
	de la nomina que se esta causando
*/
UPDATE
	info_documento
SET
	rf_documento = foo.ndocumento_nomina
FROM
	(SELECT DISTINCT
		d.ndocumento AS ndocumento_nomina,
		r.ndocumento AS ndocumento_extras
	FROM
		args_nomina a,
		documentos d,
		documentos d2,
		registro_extras_nomina r,
	 	causacion_nomina cn
	WHERE
		r.ndocumento = d2.ndocumento and
		d2.estado and
		a.ndocumento = d.ndocumento AND
	 	d.ndocumento = cn.ndocumento AND
	 	cn.id_tercero = r.id_tercero AND
		EXTRACT(YEAR FROM d.fecha) = EXTRACT(YEAR FROM d2.fecha) AND
		EXTRACT(MONTH FROM d.fecha) = EXTRACT(MONTH FROM d2.fecha)) AS foo
WHERE
	info_documento.ndocumento = foo.ndocumento_extras;