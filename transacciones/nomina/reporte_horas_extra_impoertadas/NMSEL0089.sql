--CURRENT
DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
    '?'::VARCHAR AS fecha,
    '?'::VARCHAR AS division,
    '?'::INTEGER AS tipo; -- 1: con ceros
    
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
    documentos d,
    info_documento id,
    registro_extras_nomina re,
    args_nomina a
WHERE
    d.ndocumento=re.ndocumento AND
    d.ndocumento=id.ndocumento and
    id.rf_documento is null and
    d.estado AND
    EXTRACT(YEAR FROM a.fecha::DATE)=EXTRACT(YEAR FROM d.fecha) AND
    EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM d.fecha);

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
    registro_extras_nomina_rangos re,
    args_nomina a
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
    registro_extras_nomina_rangos re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd2 re,
    args_nomina a
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
        EXTRACT(EPOCH FROM re.tiempo_extra)/60
    ELSE
        CASE WHEN re.hora_inicio_extra::INTERVAL+re.tiempo_extra::interval>'23:59:59'::INTERVAL 
        THEN
            EXTRACT(EPOCH FROM '23:59:59'::TIME-re.hora_inicio_extra::INTERVAL)/60
        ELSE
            EXTRACT(EPOCH FROM re.tiempo_extra)/60
        END
    END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
    registro_extras_nomina_cd2 re,
    args_nomina a
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
    registro_extras_nomina_cd2 re,
    args_nomina a
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
    registro_extras_nomina_cd2 re,
    args_nomina a
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
    registro_extras_nomina_cd2 re,
    args_nomina a
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
    END::INTEGER AS tiempo_extra_minutos_ajustado
FROM
    registro_extras_nomina_cd2 re,
    args_nomina a
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
    registro_extras_nomina_cd2 re,
    args_nomina a
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

-- Dic 26 2023: cambio tiempo_extra_minutos_ajustado por tiempo_extra_minutos segun cambios en la NMSEL0027 para corregir error calculo extras y
-- recargos dominicales y festivos
DROP TABLE IF EXISTS tmp_hnd;
CREATE TEMP TABLE tmp_hnd AS
SELECT
    id_tercero,
    '00:00:00'::INTERVAL+SUM(tiempo_extra_minutos)* INTERVAL '1 MINUTES' tiempo_extra,
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    EXTRACT(MONTH FROM a.fecha::DATE)=EXTRACT(MONTH FROM ((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::INTERVAL)::DATE) and --compara meses de fecha seleccionada arg reporte y mes de la fecha del recargo + el recargo
    ((re.fecha||' '||re.hora_inicio_recargo)::TIMESTAMP+re.tiempo_recargo::interval-interval '1 minute')::DATE!=re.fecha and
    re.hora_inicio_recargo != '00:00:00'
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
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
    registro_extras_nomina_cd re,
    args_nomina a
WHERE
    d.ndocumento=re.ndocumento AND
    d.estado AND
    re.hora_inicio_recargo BETWEEN '19:00:00'::TIME AND '24:00:00' AND
    re.hora_inicio_recargo::interval+re.tiempo_recargo::INTERVAL BETWEEN '19:00:00'::TIME AND '24:00:00';

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
    registro_recargos_nomina_cd2 re,
    args_nomina a
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
    registro_recargos_nomina_cd2 re,
    args_nomina a
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
    registro_recargos_nomina_cd2 re,
    args_nomina a
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
    registro_recargos_nomina_cd2 re,
    args_nomina a
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
    registro_recargos_nomina_cd2 re,
    args_nomina a
WHERE
    (re.fecha IN (SELECT dia FROM festivos_anio) OR
    DATE_PART('dow', re.fecha)=0) AND
    re.hora_inicio_recargo BETWEEN '06:00:00' AND '19:00:00' AND
    re.hora_inicio_recargo::TIME+re.tiempo_recargo::interval BETWEEN '06:00:00' AND '19:00:00';

DROP TABLE IF EXISTS tmp_d;
CREATE TEMP TABLE tmp_d AS
SELECT
    id_tercero,
    '00:00:00'::INTERVAL+SUM(tiempo_recargo_minutos_ajustado)* INTERVAL '1 MINUTES' tiempo_recargo,
    SUM(tiempo_recargo_minutos_ajustado) AS minutos_recargo,
    ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2) AS fraccion,
    ce.porcentaje
FROM
    tmp_dia_ajustado_hd hd,
    categoria_extras_recargos ce
WHERE
    ce.id_categoria_extra_recargo=5
GROUP BY
    ce.porcentaje,
    id_tercero
HAVING
    ROUND((SUM(tiempo_recargo_minutos_ajustado)/60.0)::NUMERIC,2)!=0;
    
    
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


DROP TABLE IF EXISTS aux_calculos_sin_total;
CREATE TEMP TABLE aux_calculos_sin_total AS
SELECT
    f.id_char,
    f.nombre,
    f.salariob,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND((f.salariob/ce.horas)::NUMERIC,0)
    ELSE CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.valor_minimo_hora_extra ELSE ROUND((f.salariob/30/7)::numeric,0) END END AS hbase,
        --ROUND((f.salariob/240)::NUMERIC,0) AS hbase, Enero 28 2023 se comenta y se agrega los case when anteriores
    f.hed::varchar AS hed,
    f.fhed,
    f.phed,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fhed,0)*(1+coalesce(f.phed,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhed,0)*(1+coalesce(f.phed,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhed,0)*(1+coalesce(f.phed,0)/100))::NUMERIC,0) END END
        AS vhed,    
    --ROUND((f.salariob/240*f.fhed*(1+phed/100))::NUMERIC,0) AS vhed, Enero 28 2023 se comenta y se agrega los case when anteriores
    f.hen::varchar AS hen,
    f.fhen,
    f.phen,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas/60)*coalesce(f.fhen,0)*(1+coalesce(f.phen,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhen,0)*(1+coalesce(f.phen,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhen,0)*(1+coalesce(f.phen,0)/100))::NUMERIC,0) END END AS vhen,
    --ROUND((f.salariob/240*f.fhen*(1+phen/100))::NUMERIC,0) AS vhen,Enero 28 2023 se comenta y se agrega los case when anteriores
    f.heddf::varchar,
    f.fheddf,
    f.pheddf,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fheddf,0)*(1+coalesce(f.pheddf,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fheddf,0)*(1+coalesce(f.pheddf,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fheddf,0)*(1+coalesce(f.pheddf,0)/100))::NUMERIC,0) END END AS vheddf,
    --ROUND((f.salariob/240*f.fheddf*(1+pheddf/100))::NUMERIC,0) AS vheddf,
    f.hendf::varchar,
    f.fhendf,
    f.phendf,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fhendf,0)*(1+coalesce(f.phendf,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhendf,0)*(1+coalesce(f.phendf,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhendf,0)*(1+coalesce(f.phendf,0)/100))::NUMERIC,0) END END AS vhendf,
    --ROUND((f.salariob/240*f.fhendf*(1+phendf/100))::NUMERIC,0) AS vhendf,
    f.hrn::varchar,
    f.fhrn,
    f.phrn,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fhrn,0)*(coalesce(f.phrn,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhrn,0)*(coalesce(f.phrn,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhrn,0)*(coalesce(f.phrn,0)/100))::NUMERIC,0) END END AS vhrn,
    --ROUND((f.salariob/240*f.fhrn*(phrn/100))::NUMERIC,0) AS vhrn,
    f.hrndf::varchar,
    f.fhrndf,
    f.phrndf,
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fhrndf,0)*(1+coalesce(f.phrndf,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhrndf,0)*(1+coalesce(f.phrndf,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhrndf,0)*(1+coalesce(f.phrndf,0)/100))::NUMERIC,0) END END AS vhrndf,
    --ROUND((f.salariob/240*f.fhrndf*(1+phrndf/100))::NUMERIC,0) AS vhrndf,
    f.hrddf::varchar,
    f.fhrddf,
    f.phrddf,
    
    CASE WHEN f.id = ce.id THEN -- 1085316050 MARIA CAMILA ALVARADO CASO 150 HORAS
            ROUND(((f.salariob/ce.horas)*coalesce(f.fhrddf,0)*(1+coalesce(f.phrddf,0)/100))::NUMERIC,0)
        ELSE CASE WHEN f.salariob <= (m.minimo/2) THEN 
            ROUND(((CASE WHEN ROUND((f.salariob/15/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/15/7 ELSE f.salariob/15/7 END)*coalesce(f.fhrddf,0)*(1+coalesce(f.phrddf,0)/100))::NUMERIC,0) 
        ELSE 
            ROUND(((CASE WHEN ROUND((f.salariob/30/7)::numeric,0) < m.valor_minimo_hora_extra THEN m.minimo/30/7 ELSE f.salariob/30/7 END)*coalesce(f.fhrddf,0)*(1+coalesce(f.phrddf,0)/100))::NUMERIC,0) END END AS vhrddf
    --ROUND((f.salariob/240*f.fhrddf*(1+phrddf/100))::NUMERIC,0) AS vhrddf
FROM
    salario_minimo AS m,
    (SELECT
        g.id,
        g.id_char,
        LTRIM(COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')) AS nombre,
        tr.salariob,
        COALESCE(hd.tiempo_extra,'00:00:00'::INTERVAL) as hed,
        ROUND((EXTRACT(EPOCH FROM COALESCE(hd.tiempo_extra,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhed,
        COALESCE(hd.porcentaje,0) AS phed,
        COALESCE(hn.tiempo_extra,'00:00:00'::INTERVAL) as hen,
        ROUND((EXTRACT(EPOCH FROM COALESCE(hn.tiempo_extra,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhen,
        COALESCE(hn.porcentaje,0) AS phen,
        COALESCE(hdd.tiempo_extra,'00:00:00'::INTERVAL) as heddf,
        ROUND((EXTRACT(EPOCH FROM COALESCE(hdd.tiempo_extra,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fheddf,
        COALESCE(hdd.porcentaje,0) AS pheddf,
        COALESCE(hnd.tiempo_extra,'00:00:00'::INTERVAL) as hendf,
        ROUND((EXTRACT(EPOCH FROM COALESCE(hnd.tiempo_extra,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhendf,
        COALESCE(hnd.porcentaje,0) AS phendf,
        COALESCE(ro.tiempo_recargo,'00:00:00'::INTERVAL) as hrn,
        ROUND((EXTRACT(EPOCH FROM COALESCE(ro.tiempo_recargo,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhrn,
        COALESCE(ro.porcentaje,0) AS phrn,
        COALESCE(rodf.tiempo_recargo,'00:00:00'::INTERVAL) as hrndf,
        ROUND((EXTRACT(EPOCH FROM COALESCE(rodf.tiempo_recargo,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhrndf,
        COALESCE(rodf.porcentaje,0) AS phrndf,
        COALESCE(d.tiempo_recargo,'00:00:00'::INTERVAL) as hrddf,
        ROUND((EXTRACT(EPOCH FROM COALESCE(d.tiempo_recargo,'00:00:00'::INTERVAL))/60/60)::NUMERIC,5) as fhrddf,
        COALESCE(d.porcentaje,0) AS phrddf
    FROM
        general g,
        args_nomina an,
        (SELECT
            acc.id AS id_tercero,
            SUM(cc.valor) AS salariob
        FROM
            asignacion_concepto_causacion acc,
            datos_division dv,
            args_nomina an,
            concepto_causacion cc
        WHERE
            dv.id_tercero=acc.id AND
            CASE WHEN TRIM(an.division) = '' OR an.division IS NULL THEN TRUE ELSE dv.id_division= an.division::INTEGER END AND
            acc.id_concepto_causacion=cc.id_concepto_causacion AND
            cc.id_movimiento_nomina=1 AND
            cc.id_clasificacion_concepto_causacion in (1,45) -- Sep 15 2025: agrego el 45 que es la clasificacion de apoyos de sostenimiento que usan para practicantes del sena
        GROUP BY
            acc.id) AS tr
    LEFT OUTER JOIN
     -- hora ordinaria diurna
        tmp_hd hd
    ON
        hd.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- hora ordinaria nocturna
        tmp_hn hn
    ON
        hn.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- hora extra dominical o festivo
        tmp_hdd hdd
    ON
        hdd.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- hora extra dominical o festivo nocturno
        tmp_hnd hnd
    ON
        hnd.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- recargo ordinario nocturno
        tmp_ro ro
    ON
        ro.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- recargo nocturno dominical festivo
        tmp_df rodf
    ON
        rodf.id_tercero=tr.id_tercero
    LEFT OUTER JOIN
     -- recargo diurno dominical festivo
        tmp_d d
    ON
        d.id_tercero=tr.id_tercero
    WHERE
        tr.id_tercero=g.id AND
        (COALESCE(hn.tiempo_extra::interval,'00:00:00'::interval)+
        COALESCE(hd.tiempo_extra::interval,'00:00:00'::interval)+
        COALESCE(hnd.tiempo_extra::interval,'00:00:00'::interval)+
        COALESCE(hdd.tiempo_extra::interval,'00:00:00'::interval)+
        COALESCE(ro.tiempo_recargo::interval,'00:00:00'::interval)+
        COALESCE(rodf.tiempo_recargo::interval,'00:00:00'::interval)+
        COALESCE(d.tiempo_recargo::interval,'00:00:00'::interval)>'00:00:00'::interval OR
         an.tipo=1)
    ORDER BY
        g.nombre1||' '||g.nombre2||' '||g.apellido1||' '||g.apellido2) AS f
LEFT OUTER JOIN
    casos_especiales ce
ON
    f.id = ce.id;
   
   
select
	a.id_char,
	a.nombre,
	a.salariob,
	a.hbase,        
	a.hed,
	a.fhed,
	a.phed,
	a.vhed,    
	a.hen,
	a.fhen,
	a.phen,
	a.vhen,    
	a.heddf,
	a.fheddf,
	a.pheddf,    
	a.vheddf,
	a.hendf,
	a.fhendf,
	a.phendf,
	a.vhendf,
	a.hrn,
	a.fhrn,
	a.phrn,
	a.vhrn,
	a.hrndf,
	a.fhrndf,
	a.phrndf,
	a.vhrndf,
	a.hrddf,
	a.fhrddf,
	a.phrddf,
	a.vhrddf,
	a.vhed+a.vhen+a.vheddf+a.vhendf+a.vhrn+a.vhrndf+a.vhrddf as total
from
	aux_calculos_sin_total a
ORDER BY
    nombre;