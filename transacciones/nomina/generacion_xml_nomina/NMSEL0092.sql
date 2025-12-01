DROP TABLE IF EXISTS aux_parametros_ne;
CREATE TEMP TABLE aux_parametros_ne AS
SELECT
	'?'::INTEGER AS id_division_nomina,
	'?'::INTEGER AS mes;	

UPDATE
    info_documento
SET
    rf_documento = foo.ndocumento_nm
FROM
    (SELECT DISTINCT
        foo.ndocumento AS ndocumento_nm,
        id.ndocumento AS ndocumento_nn,
        id.rf_documento AS apuntando_a,
        d.codigo_tipo||'-'||d.numero::BIGINT AS documento_nn
    FROM
        causacion_novedades_nomina cnn,    
        documentos d,
        info_documento id,
        (SELECT
            MAX(d.codigo_tipo||'-'||d.numero::BIGINT) AS nomina,
            MAX(d.fecha::DATE) AS fecha,
            MAX(EXTRACT('year' FROM d.fecha::DATE)) AS anio,
            MAX(EXTRACT('month' FROM d.fecha::DATE)) AS mes,
            MAX(d.ndocumento) AS ndocumento,
            cn.id_tercero
        FROM
            documentos d,
            causacion_nomina cn,
            aux_parametros_ne a
        WHERE
            d.ndocumento = cn.ndocumento AND
            d.codigo_tipo = 'NM' AND
            d.estado AND
            EXTRACT('year' FROM d.fecha::DATE) = EXTRACT('year' FROM CURRENT_DATE) AND
            EXTRACT('month' FROM d.fecha::DATE) = a.mes AND
            cn.id_division_nomina = a.id_division_nomina
		GROUP BY
			cn.id_tercero) AS foo
    WHERE
        cnn.id_tercero = foo.id_tercero AND
        cnn.ndocumento = id.ndocumento AND
        cnn.ndocumento = d.ndocumento AND
        EXTRACT('year' FROM cnn.fecha::DATE) = foo.anio AND
        EXTRACT('month' FROM cnn.fecha::DATE) = foo.mes
    ORDER BY
        foo.ndocumento) AS foo
WHERE
    info_documento.ndocumento = foo.ndocumento_nn;
    
--

DROP TABLE IF EXISTS aux_terceros_ya_enviados;
CREATE TEMP TABLE aux_terceros_ya_enviados AS
SELECT
	r.id_tercero
FROM
	aux_parametros_ne a,
	registro_nomina_electronica r,
	general g,
	documentos d,
	envio_webservice e
WHERE
	r.anio = extract ('year' from current_date) AND 
	a.mes = r.mes AND
	a.id_division_nomina = r.id_division_nomina AND
	r.ndocumento = d.ndocumento AND
	d.estado AND
	r.id_tercero = g.id AND
	r.ndocumento = e.ndocumento AND
	e.id_char = g.id_char AND
	e.id_codigo_retorno_dian = '00';
	
--

SELECT
	'NA' AS relleno,
	TRUE AS seleccion,
	g.id_char,
	TRIM(COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')) AS nombre,
	g.id AS id_tercero
FROM
	aux_parametros_ne a,
	general g,
	asignacion_concepto_causacion acc,
	concepto_causacion cc,
	datos_division dd
WHERE
	g.id=acc.id AND
	acc.id_concepto_causacion=cc.id_concepto_causacion AND
	cc.id_movimiento_nomina=1 AND
	dd.id_tercero=g.id AND
	dd.id_division=a.id_division_nomina AND
	dd.id_tercero NOT IN (SELECT id_tercero FROM aux_terceros_ya_enviados) AND
	cc.id_clasificacion_concepto_causacion in (1,45)
ORDER BY
	nombre;