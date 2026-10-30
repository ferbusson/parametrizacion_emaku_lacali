DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
	'?'::VARCHAR AS fecha,
	COALESCE('?'::INTEGER,0) AS division;

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
	 	args_nomina a
    WHERE	 	
        cn.ndocumento=d.ndocumento AND  
        cn.ndocumento=i.ndocumento AND
	 	to_char(cn.fecha, 'MM-YYYY') = to_char(a.fecha::DATE, 'MM-YYYY') AND 	 	
	 
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

--- INICIO CALCULO DE EXTRAS

DROP TABLE IF EXISTS festivos_anio;
CREATE TEMP TABLE festivos_anio AS
SELECT
	dia
FROM
	festivos_colombia f,
	args_nomina a
WHERE
	DATE_PART('year', dia) = DATE_PART('year', a.fecha::DATE);


/** HORA EXTRA ORDINARIA **/

DROP TABLE IF EXISTS aux_ultimo_registro_horas_extra_por_mes;
CREATE TEMP TABLE aux_ultimo_registro_horas_extra_por_mes AS
SELECT
	max(re.ndocumento) as ndocumento
FROM
	documentos d,
	registro_extras_nomina re,
	args_nomina a
WHERE
	d.ndocumento=re.ndocumento and
	d.estado AND
	EXTRACT(YEAR FROM a.fecha::DATE)=EXTRACT(YEAR FROM d.fecha) AND
	EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM d.fecha);


DROP TABLE IF EXISTS registro_extras_nomina_rangos;
CREATE TEMP TABLE registro_extras_nomina_rangos AS
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	re.tiempo_extra,
	re.hora_inicio_recargo,
	re.tiempo_recargo
FROM
	registro_extras_nomina re
where
	re.ndocumento in (select ndocumento from aux_ultimo_registro_horas_extra_por_mes);

/** BASE PARSEADA CON GRUPOS PREPARADOS */

--- SE PASA JORNADA NOCHE A DIA SEGUNDA PARTE EXTRAS
DROP TABLE IF EXISTS registro_extras_nomina_cd;
CREATE TEMP TABLE registro_extras_nomina_cd AS
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	'06:00:00'::TIME AS hora_inicio_extra,
	re.hora_inicio_extra+(re.tiempo_extra::INTERVAL)-('06:00:00'::INTERVAL) AS tiempo_extra,
	'00:00:00'::TIME AS hora_inicio_recargo,
	'00:00:00'::TIME AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_rangos re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra<'06:00:00'::TIME AND
	re.hora_inicio_extra+(re.tiempo_extra::INTERVAL)>'06:00:00'::TIME
UNION ALL
--- SE PASA JORNADA NOCHE A DIA SEGUNDA PARTE RECARGOS
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	'00:00:00'::TIME AS hora_inicio_extra,
	'00:00:00'::TIME AS tiempo_extra,
	'06:00:00'::TIME AS hora_inicio_recargo,
	re.hora_inicio_recargo+(re.tiempo_recargo::INTERVAL)-('06:00:00'::INTERVAL) AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_rangos re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo<'06:00:00'::TIME AND
	re.hora_inicio_recargo+(re.tiempo_recargo::INTERVAL)>'06:00:00'::TIME 
UNION ALL
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	re.tiempo_extra,
	re.hora_inicio_recargo,
	re.tiempo_recargo
FROM
	registro_extras_nomina_rangos re;
	
DROP TABLE IF EXISTS registro_extras_nomina_cd2;
CREATE TEMP TABLE registro_extras_nomina_cd2 AS
--- SE PASA JORNADA NOCHE A DIA PRIMERA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	'06:00:00'::TIME-(re.hora_inicio_extra::INTERVAL) AS tiempo_extra
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra<'06:00:00'::TIME AND
	re.hora_inicio_extra+(re.tiempo_extra::INTERVAL)>'06:00:00'::TIME 
UNION ALL
--- SE PASA JORNADA DIA A NOCHE PRIMERA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	'19:00:00'::TIME-re.hora_inicio_extra::INTERVAL AS tiempo_extra
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra<='19:00:00'::TIME AND
	re.hora_inicio_extra+(re.tiempo_extra::INTERVAL)>'19:00:00'::TIME 
UNION ALL
--- SE PASA JORNADA DIA A NOCHE SEGUNDA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	'19:00:00'::TIME AS hora_inicio_extra,
	re.hora_inicio_extra+re.tiempo_extra::INTERVAL-'19:00:00'::INTERVAL AS tiempo_extra
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra<'19:00:00'::TIME AND
	re.hora_inicio_extra+(re.tiempo_extra::INTERVAL)>'19:00:00'::TIME 
UNION ALL
--- PRIMERA PARTE QUE SE CAMBIAN DE DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	'24:00:00'::TIME-re.hora_inicio_extra::INTERVAL AS tiempo_extra
FROM
	documentos d,
	registro_extras_nomina_cd re,
	args_nomina a
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM ((re.fecha||' '||re.hora_inicio_extra)::TIMESTAMP+re.tiempo_extra::INTERVAL)::DATE) AND
	((re.fecha||' '||re.hora_inicio_extra)::TIMESTAMP+re.tiempo_extra::INTERVAL)::DATE!=re.fecha
UNION ALL
--- SEGUNDAPARTE LOS QUE SE CAMBIAN DE DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	((re.fecha||' '||re.hora_inicio_extra)::TIMESTAMP+re.tiempo_extra::INTERVAL)::DATE AS fecha,
	'00:00:00'::TIME AS hora_inicio_extra,
	re.hora_inicio_extra+re.tiempo_extra::INTERVAL-'24:00:00'::INTERVAL AS tiempo_extra
FROM
	documentos d,
	registro_extras_nomina_cd re,
	args_nomina a
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM ((re.fecha||' '||re.hora_inicio_extra)::TIMESTAMP+re.tiempo_extra::INTERVAL)::DATE) AND
	((re.fecha||' '||re.hora_inicio_extra)::TIMESTAMP+re.tiempo_extra::INTERVAL)::DATE!=re.fecha
UNION ALL
--- ESTAN EN INTERVALO NOCHE AMANECER
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	re.tiempo_extra 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra BETWEEN '00:00:00'::TIME AND '06:00:00' AND
	re.hora_inicio_extra+re.tiempo_extra::INTERVAL BETWEEN '00:00:00'::TIME AND '06:00:00'
UNION ALL
--- ESTAN EN INTERVALO DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	re.tiempo_extra 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra BETWEEN '06:00:00'::TIME AND '19:00:00' AND
	re.hora_inicio_extra+re.tiempo_extra::INTERVAL BETWEEN '06:00:00'::TIME AND '19:00:00'
UNION ALL
--- ESTA EN EL INTERVALO NOCHE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_extra,
	re.tiempo_extra 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_extra BETWEEN '19:00:00'::TIME AND '24:00:00' AND
	re.hora_inicio_extra+re.tiempo_extra::INTERVAL BETWEEN '19:00:00'::TIME AND '24:00:00';

--- TIEMPO AJUSADO DIA
DROP TABLE IF EXISTS tmp_tiempo_ajustado_hd;
CREATE TEMP TABLE tmp_tiempo_ajustado_hd AS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'18:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '18:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_extra)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_extra)/60
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0  AND
	re.hora_inicio_extra BETWEEN '06:00:00' AND '18:59:59';

--- HORA NOCTURNA 

DROP TABLE IF EXISTS tmp_tiempo_ajustado_hn;
CREATE TEMP TABLE tmp_tiempo_ajustado_hn AS
-- HORA NOCTURNA CORTE NOCHE 0 HORAS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'18:59:59'::INTERVAL AND
		re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval<='23:59:59'::INTERVAL
	THEN
		EXTRACT(EPOCH FROM re.hora_inicio_extra+re.tiempo_extra::interval)/60-
		EXTRACT(EPOCH FROM '18:59:59'::TIME)/60 
	ELSE
		CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'23:59:59'::INTERVAL 
		THEN
			EXTRACT(EPOCH FROM '23:59:59'::TIME-re.hora_inicio_extra::INTERVAL)/60
		ELSE
			EXTRACT(EPOCH FROM re.tiempo_extra)/60
		END
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0  AND
	re.hora_inicio_extra BETWEEN '19:00:00' AND '23:59:59'::TIME 
UNION ALL
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval<='23:59:59'::INTERVAL --hora de inicio + tiempo extra <= media noche
	THEN
		EXTRACT(EPOCH FROM re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval-'19:00:00'::TIME)/60
	ELSE
		EXTRACT(EPOCH FROM '23:59:59'::INTERVAL-'19:00:00'::INTERVAL)/60 --hora de inicio + tiempo extra > media noche
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0  AND
	re.hora_inicio_extra < '19:00:00' AND --hora de inicio es antes de las 9pm y
	re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval > '19:00:00' --hora de inicio + tiempo extra superan las 9 pm
UNION ALL
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'05:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '05:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_extra)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_extra)/60
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0  AND
	re.hora_inicio_extra BETWEEN '00:00:00' AND '05:59:59';

DROP TABLE IF EXISTS tmp_hd;
CREATE TEMP TABLE tmp_hd AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_extra_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_extra,
	SUM(tiempo_extra_minutos_ajustado) AS minutos_extras,
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_hd hd,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=1
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2)!=0;
	
DROP TABLE IF EXISTS tmp_hn;
CREATE TEMP TABLE tmp_hn AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_extra_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_extra,
	SUM(tiempo_extra_minutos_ajustado) AS minutos_extras,
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_hn hn,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=2
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2)!=0;


/** HORAS EXTRAS DOMINICAL Y FESTIVO **/


--- TIEMPO AJUSADO DIA
DROP TABLE IF EXISTS tmp_tiempo_ajustado_hdd;
CREATE TEMP TABLE tmp_tiempo_ajustado_hdd AS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'18:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '18:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_extra)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_extra)/60
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0)  AND
	re.hora_inicio_extra BETWEEN '06:00:00' AND '19:00:00';
	
--- HORA NOCTURNA
DROP TABLE IF EXISTS tmp_tiempo_ajustado_hnd;
CREATE TEMP TABLE tmp_tiempo_ajustado_hnd AS
-- HORA NOCTURNA CORTE NOCHE 0 HORAS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'18:59:59'::INTERVAL AND
		re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval<='23:59:59'::INTERVAL
	THEN
		EXTRACT(EPOCH FROM re.hora_inicio_extra+re.tiempo_extra::interval)/60-
		EXTRACT(EPOCH FROM '18:59:59'::TIME)/60 
	ELSE
		CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'23:59:59'::INTERVAL 
		THEN
			EXTRACT(EPOCH FROM '23:59:59'::TIME-re.hora_inicio_extra::INTERVAL)/60
		ELSE
			EXTRACT(EPOCH FROM re.tiempo_extra)/60
		END
	END::INTEGER AS tiempo_extra_minutos_ajustado -- Sep 29 2022: este campo genera error al calcular los minutos extra siempre desde las 9pm, en la cali los minutos mayores a 9pm son considerados en recargos por tanto aqui no el calculo debe comenzar desde la hora de inicio de los extra no desde las 9pm
FROM
	registro_extras_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0)  AND
	re.hora_inicio_extra BETWEEN '19:00:00' AND '24:00:00'::TIME 
UNION ALL
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_extra,
	EXTRACT(EPOCH FROM re.tiempo_extra)/60 AS tiempo_extra_minutos,
	CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'05:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '05:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_extra)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_extra)/60
	END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
	registro_extras_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0)  AND
	re.hora_inicio_extra BETWEEN '00:00:00' AND '06:00:00';

DROP TABLE IF EXISTS tmp_hdd;
CREATE TEMP TABLE tmp_hdd AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_extra_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_extra,
	SUM(tiempo_extra_minutos_ajustado) AS minutos_extras,
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_hdd hd,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=4
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2)!=0;


-- Sep 29 2022: se hace el cambio de tiempo_extra_minutos_ajustado a tiempo_extra_minutos porque el ajustado calcula los minutos extra a partir de las 9pm sin importar que se haya empezado los extra en un tiempo mayor a 9pm
-- para reversar este cambio si es necesario se debe reemplazar tiempo_extra_minutos por tiempo_extra_minutos_ajustado
DROP TABLE IF EXISTS tmp_hnd;
CREATE TEMP TABLE tmp_hnd AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_extra_minutos)* INTERVAL '1 MINUTES' AS tiempo_extra,
	SUM(tiempo_extra_minutos) AS minutos_extras,
	ROUND((SUM(tiempo_extra_minutos)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_hnd hn,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=6
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_extra_minutos_ajustado)/60.0)::NUMERIC,2)!=0;
	
/** RECARGOS NOCTURNOS Y DOMINICALES **/

/** BASE PARSEADA CON GRUPOS PREPARADOS */

DROP TABLE IF EXISTS registro_recargos_nomina_cd2;
CREATE TEMP TABLE registro_recargos_nomina_cd2 AS
--- SE PASA JORNADA NOCHE A DIA PRIMERA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	'06:00:00'::TIME-(re.hora_inicio_recargo::INTERVAL) AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo<'06:00:00'::TIME AND
	re.hora_inicio_recargo::INTERVAL+(re.tiempo_recargo::INTERVAL)>'06:00:00'::INTERVAL 
UNION ALL
--- SE PASA JORNADA DIA A NOCHE PRIMERA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	'19:00:00'::TIME-re.hora_inicio_recargo::INTERVAL AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo<'19:00:00'::TIME AND
	re.hora_inicio_recargo::interval+(re.tiempo_recargo::INTERVAL)>'19:00:00'::interval 
UNION ALL
--- SE PASA JORNADA DIA A NOCHE SEGUNDA PARTE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	'19:00:00'::TIME AS hora_inicio_recargo,
	re.hora_inicio_recargo+re.tiempo_recargo::INTERVAL-'19:00:00'::INTERVAL AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo<'19:00:00'::TIME AND
	re.hora_inicio_recargo::INTERVAL+(re.tiempo_recargo::INTERVAL)>'19:00:00'::INTERVAL 
UNION ALL
--- PRIMERA PARTE QUE SE CAMBIAN DE DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	'24:00:00'::TIME-re.hora_inicio_recargo::INTERVAL AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_cd re,
	args_nomina a
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM ((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE) AND
	((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE!=re.fecha
UNION ALL
--- SEGUNDAPARTE LOS QUE SE CAMBIAN DE DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE AS fecha,
	'00:00:00'::TIME AS hora_inicio_recargo,
	re.hora_inicio_recargo+re.tiempo_recargo::INTERVAL-'24:00:00'::INTERVAL AS tiempo_recargo
FROM
	documentos d,
	registro_extras_nomina_cd re,
	args_nomina a
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM ((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE) AND
	((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE!=re.fecha
UNION ALL
--- ESTAN EN INTERVALO NOCHE AMANECER
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	re.tiempo_recargo 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo BETWEEN '00:00:00'::TIME AND '06:00:00' AND
	re.hora_inicio_recargo+re.tiempo_recargo::INTERVAL BETWEEN '00:00:00'::TIME AND '06:00:00'
UNION ALL
--- ESTAN EN INTERVALO DIA
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	re.tiempo_recargo 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo BETWEEN '06:00:00'::TIME AND '19:00:00' AND
	re.hora_inicio_recargo+re.tiempo_recargo::INTERVAL BETWEEN '06:00:00'::TIME AND '19:00:00'
UNION ALL
--- ESTA EN EL INTERVALO NOCHE
SELECT
	re.ndocumento,
	re.id_tercero,
	re.fecha,
	re.hora_inicio_recargo,
	re.tiempo_recargo 
FROM
	documentos d,
	registro_extras_nomina_cd re
WHERE
	d.ndocumento=re.ndocumento AND
	d.estado AND
	re.hora_inicio_recargo BETWEEN '19:00:00'::TIME AND '24:00:00' AND
	re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::INTERVAL BETWEEN '19:00:00'::TIME AND '24:00:00';

--- TIEMPO RECARGO ORDINARIO
DROP TABLE IF EXISTS tmp_tiempo_ajustado_ro;
CREATE TEMP TABLE tmp_tiempo_ajustado_ro AS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_recargo,
	EXTRACT(EPOCH FROM re.tiempo_recargo)/60 AS tiempo_recargo_minutos,
	CASE WHEN re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::interval>'23:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '23:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_recargo)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_recargo)/60
	END::INTEGER AS tiempo_recargo_minutos_ajustado
FROM
	registro_recargos_nomina_cd2 re
WHERE
	(re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0) AND
	re.hora_inicio_recargo BETWEEN '19:00:00' AND '23:59:59'
UNION ALL
--- HORA NOCTURNA CORTE MAÑANA
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_recargo,
	EXTRACT(EPOCH FROM re.tiempo_recargo)/60 AS tiempo_recargo_minutos,
	CASE WHEN re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::interval>'05:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '05:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_recargo)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_recargo)/60
	END::INTEGER AS tiempo_recargo_minutos_ajustado
FROM
	registro_recargos_nomina_cd2 re
WHERE
	(re.fecha NOT IN (SELECT dia FROM festivos_anio) AND
	DATE_PART('dow', re.fecha)!=0)  AND
	re.hora_inicio_recargo BETWEEN '00:00:00' AND '05:59:59';
	
--- TIEMPO RECARGO DOM O FESTIVO
DROP TABLE IF EXISTS tmp_tiempo_ajustado_df;
CREATE TEMP TABLE tmp_tiempo_ajustado_df AS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_recargo,
	EXTRACT(EPOCH FROM re.tiempo_recargo)/60 AS tiempo_recargo_minutos,
	CASE WHEN re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::interval>'23:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '23:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_recargo)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_recargo)/60
	END::INTEGER AS tiempo_recargo_minutos_ajustado
FROM
	registro_recargos_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0) AND
	re.hora_inicio_recargo BETWEEN '19:00:00' AND '23:59:59'
UNION ALL
--- HORA NOCTURNA CORTE MAÑANA
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_recargo,
	EXTRACT(EPOCH FROM re.tiempo_recargo)/60 AS tiempo_recargo_minutos,
	CASE WHEN re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::interval>'05:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '05:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_recargo)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_recargo)/60
	END::INTEGER AS tiempo_recargo_minutos_ajustado
FROM
	registro_recargos_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0)  AND
	re.hora_inicio_recargo BETWEEN '00:00:00' AND '05:59:59';
	


	
	
DROP TABLE IF EXISTS tmp_ro;
CREATE TEMP TABLE tmp_ro AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_recargo_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_recargo,
	SUM(tiempo_recargo_minutos_ajustado) AS minutos_recargo,
	ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_ro,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=3
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2)!=0;
	
DROP TABLE IF EXISTS tmp_df;
CREATE TEMP TABLE tmp_df AS
SELECT
	id_tercero,
	'00:00:00'::INTERVAL+SUM(tiempo_recargo_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_recargo,
	SUM(tiempo_recargo_minutos_ajustado) AS minutos_recargo,
	ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
	ce.porcentaje
FROM
	tmp_tiempo_ajustado_df,
	categoria_extras_recargos ce
WHERE
	ce.id_categoria_extra_recargo=7
GROUP BY
	ce.porcentaje,
	id_tercero
HAVING
	ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2)!=0;

/** DOMINICALES Y FESTIVOS */



--- TIEMPO AJUSADO DIA
DROP TABLE IF EXISTS tmp_dia_ajustado_hd;
CREATE TEMP TABLE tmp_dia_ajustado_hd AS
SELECT
	re.fecha,
	re.id_tercero,
	re.hora_inicio_recargo,
	EXTRACT(EPOCH FROM re.tiempo_recargo)/60 AS tiempo_recargo_minutos,
	CASE WHEN re.hora_inicio_recargo::INTERVAL+re.tiempo_recargo::interval>'18:59:59'::INTERVAL THEN
		EXTRACT(EPOCH FROM '18:59:59'::TIME)/60 -
		EXTRACT(EPOCH FROM re.hora_inicio_recargo)/60
	ELSE
		EXTRACT(EPOCH FROM re.tiempo_recargo)/60
	END::INTEGER AS tiempo_recargo_minutos_ajustado
FROM
	registro_recargos_nomina_cd2 re
WHERE
	(re.fecha IN (SELECT dia FROM festivos_anio) OR
	DATE_PART('dow', re.fecha)=0) AND
	re.hora_inicio_recargo BETWEEN '06:00:00' AND '19:00:00' AND
	re.hora_inicio_recargo::TIME+re.tiempo_recargo::interval BETWEEN '06:00:00' AND '19:00:00';



DROP TABLE IF EXISTS tmp_tiempo_hdd;
CREATE TEMP TABLE tmp_tiempo_hdd AS
SELECT
	d.id_tercero,
	d.porcentaje,
	sum(d.minutos_extras) as tiempo
FROM
	tmp_hdd d
GROUP BY
	d.id_tercero,
	d.porcentaje;
	
DROP TABLE  IF EXISTS tmp_tiempo_hnd;
CREATE TEMP TABLE tmp_tiempo_hnd AS
SELECT
	d.id_tercero,
	d.porcentaje,
	sum(d.minutos_extras) as tiempo
FROM
	tmp_hnd d
GROUP BY
	d.id_tercero,
	d.porcentaje;
---- FIN CALCULO DE EXTRAS

DROP TABLE IF EXISTS salario_minimo;
CREATE TEMP TABLE salario_minimo AS
SELECT 
	valor AS minimo,
	ROUND((valor/30/7)::numeric,0) AS valor_minimo_hora_extra
FROM
	concepto_causacion 
WHERE
	id_concepto_causacion=1;

DROP TABLE IF EXISTS casos_especiales;
CREATE TEMP TABLE casos_especiales AS
SELECT 
	g.id,
	150 AS horas
FROM
	general g 
WHERE
	g.id_char = '1085316050'
UNION
SELECT 
	g.id,
	180 AS horas
FROM
	general g 
WHERE
	g.id_char = '1085923062';



SELECT
		g.id_char,
		g.nombre1||' '||g.nombre2||' '||g.apellido1||' '||g.apellido2 as nombre,
		sb.salariob,
		0,
		CASE WHEN g.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
			ROUND((sb.salariob/ce.horas)::NUMERIC,0) 			
		ELSE CASE WHEN ROUND((sb.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.valor_minimo_hora_extra ELSE ROUND((sb.salariob/30/7)::numeric,0) END END AS valorbs,
		
		COALESCE(hd.tiempo,0)* INTERVAL '1 MINUTES' AS hd,-- hd
		
		CASE WHEN g.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
			ROUND(((sb.salariob/ce.horas/60)*coalesce(hd.tiempo,0)*(1+coalesce(hd.porcentaje,0)/100))::NUMERIC,0)
		ELSE CASE WHEN sb.salariob <= (m.minimo/2) THEN 
			ROUND(((CASE WHEN ROUND((sb.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7/60 ELSE sb.salariob/15/7/60 END)*coalesce(hd.tiempo,0)*(1+coalesce(hd.porcentaje,0)/100))::NUMERIC,0) 
		ELSE 
			ROUND(((CASE WHEN ROUND((sb.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7/60 ELSE sb.salariob/30/7/60 END)*coalesce(hd.tiempo,0)*(1+coalesce(hd.porcentaje,0)/100))::NUMERIC,0) END END
		AS vheddf,		
		COALESCE(hn.tiempo,0)* INTERVAL '1 MINUTES' AS hn,-- hn		
		CASE WHEN g.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
			ROUND(((sb.salariob/ce.horas/60)*coalesce(hn.tiempo,0)*(1+coalesce(hn.porcentaje,0)/100))::NUMERIC,0)
		ELSE CASE WHEN sb.salariob <= (m.minimo/2) THEN 
			ROUND(((CASE WHEN ROUND((sb.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7/60 ELSE sb.salariob/15/7/60 END)*coalesce(hn.tiempo,0)*(1+coalesce(hn.porcentaje,0)/100))::NUMERIC,0) 
		ELSE 
			ROUND(((CASE WHEN ROUND((sb.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7/60 ELSE sb.salariob/30/7/60 END)*coalesce(hn.tiempo,0)*(1+coalesce(hn.porcentaje,0)/100))::NUMERIC,0) END END AS vheddf,
		0, 		
		en.char_cta_debito,
		COALESCE(ed.char_cta_credito,'-1') as ed_id_cta_credito, -- aqui cambie de id_cta a char_cta
		ed.char_cta_debito,
		COALESCE(en.char_cta_credito,'-1') as en_id_cta_credito, -- aqui cambie de id_cta a char_cta
		ed.porcentaje as edpor,
		en.porcentaje as enpor,
		g.id,
		ed.id_concepto_causacion, 
		en.id_concepto_causacion,
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
		
		(select en.*,COALESCE(c.char_cta,'-1') as char_cta_debito,COALESCE(c2.char_cta,'-1') as char_cta_credito  from concepto_causacion en left outer join cuentas c on en.id_cta_debito=c.id_cta left outer join cuentas c2 on en.id_cta_credito=c2.id_cta)as en,
		(select ed.*,COALESCE(c.char_cta,'-1') as char_cta_debito, COALESCE(c2.char_cta,'-1') as char_cta_credito from concepto_causacion ed left outer join cuentas c on ed.id_cta_debito=c.id_cta left outer join cuentas c2 on ed.id_cta_credito=c2.id_cta)as ed,
		
		asignacion_concepto_causacion acc1,
		asignacion_concepto_causacion acc2,
		general g,
		args_nomina an,
		datos_division dd,
		salario_minimo AS m,
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
			acc.id) AS sb
LEFT OUTER JOIN
	tmp_novedades_nomina cnn
ON
	sb.id=cnn.id_tercero
LEFT OUTER JOIN
	tmp_tiempo_hdd hd
ON
	hd.id_tercero=sb.id
LEFT OUTER JOIN
	tmp_tiempo_hnd hn
ON
	hn.id_tercero=sb.id
LEFT OUTER JOIN
	casos_especiales ce
ON
	ce.id = sb.id
WHERE
		g.id=sb.id AND
		sb.id=acc1.id AND
		sb.id=acc2.id AND
		ed.id_clasificacion_concepto_causacion = 4 AND -- Hora Extra Diurna Dominical y Festivos
		acc1.id_concepto_causacion=ed.id_concepto_causacion AND
		en.id_clasificacion_concepto_causacion = 29 AND -- Hora Extra Nocturna Dominical y Festivos
		acc2.id_concepto_causacion=en.id_concepto_causacion AND
		dd.id_tercero=g.id AND
		dd.id_division=an.division 
GROUP BY
	g.id_char,
	g.nombre1||' '||g.nombre2||' '||g.apellido1||' '||g.apellido2,
	sb.salariob,
	ROUND((sb.salariob/30/7)::numeric,0),
	COALESCE(hd.tiempo,0)* INTERVAL '1 MINUTES',
	ROUND((sb.salariob/30/7/60*COALESCE(hd.tiempo,0)*(1+coalesce(hd.porcentaje,0)/100))::NUMERIC,0),
	COALESCE(hn.tiempo,0)* INTERVAL '1 MINUTES',
	ROUND((sb.salariob/30/7/60*COALESCE(hn.tiempo,0)*(1+coalesce(hn.porcentaje,0)/100))::NUMERIC,0),
	en.char_cta_debito,
	COALESCE(ed.id_cta_credito,-1),
	ed.char_cta_debito,
	COALESCE(en.id_cta_credito,-1),
	COALESCE(ed.char_cta_credito,'-1'),
	COALESCE(en.char_cta_credito,'-1'),
	ed.porcentaje,
	en.porcentaje,
	hd.tiempo,
	hd.porcentaje,
	hn.tiempo,
	hn.porcentaje,
	g.id,
	ed.id_concepto_causacion, 
	en.id_concepto_causacion,
	m.minimo,
	m.valor_minimo_hora_extra,
	ce.id,
	ce.horas
ORDER BY
		g.nombre1||' '||g.nombre2||' '||g.apellido1||' '||g.apellido2;
