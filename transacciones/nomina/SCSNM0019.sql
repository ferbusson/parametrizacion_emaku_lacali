-- SCSNM0019 983 mseg
DROP TABLE IF EXISTS args_devengado;
CREATE TEMP TABLE args_devengado AS
SELECT
	doc.ndocumento,
	foo.tercero
FROM 
	(SELECT DISTINCT
		d2.ndocumento
	FROM
		info_documento i,
		documentos d,
		documentos d2
	WHERE
		i.rf_documento = '?' AND
		i.rf_documento = d.ndocumento AND
		d.estado AND
		d2.ndocumento = i.ndocumento AND
		d2.estado) AS doc,
	(SELECT 
		'?'::VARCHAR AS tercero) AS foo;


DROP TABLE IF EXISTS devengados_s;
CREATE TEMP TABLE devengados_s AS
SELECT 
	cc.descripcion,
	cn.valor AS devengados_s
FROM    
	args_devengado ab,
    documentos d,
    causacion_nomina cn,
    general g,
    concepto_causacion cc,
    clasificacion_conceptos_causacion ccc
WHERE   
    cn.valor>0 AND
    d.ndocumento = ab.ndocumento AND -- ndocumento
    d.estado AND
    d.ndocumento = cn.ndocumento AND
    cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion AND
    ccc.id_clasificacion_concepto_causacion = 7 AND -- otros devengados
    cn.id_concepto_causacion = cc.id_concepto_causacion AND
    cn.id_tercero = g.id AND
    g.id_char = ab.tercero; -- nitcc tercero
	
	
DROP TABLE IF EXISTS devengados_ns;
CREATE TEMP TABLE devengados_ns AS
SELECT 
	cc.descripcion,
    cn.valor AS devengados_ns
FROM    
	args_devengado ab,
    documentos d,
    general g,
    causacion_nomina cn,
    concepto_causacion cc,
    clasificacion_conceptos_causacion ccc
WHERE
	cn.valor > 0 AND
    d.ndocumento = ab.ndocumento AND -- ndocumento
    d.estado AND
    d.ndocumento = cn.ndocumento AND
    cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion AND
    ccc.id_clasificacion_concepto_causacion = 58 AND -- Devengados no base salario
    cn.id_concepto_causacion = cc.id_concepto_causacion AND
    cn.id_tercero = g.id AND
    g.id_char = ab.tercero; -- nitcc tercero
	
	
SELECT
	COALESCE(bs.descripcion,bn.descripcion) AS descripcion_concepto,
	COALESCE(bs.devengados_s,0) AS devengadoss_s,
	COALESCE(bn.devengados_ns,0) AS devengados_ns
FROM
	devengados_ns bn
FULL OUTER JOIN
	devengados_s bs
ON
	TRUE