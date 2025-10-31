-- SCSNM0034
DROP TABLE IF EXISTS aux_temporal01;
CREATE TEMP TABLE aux_temporal01 AS
SELECT
	g.id,
	CASE WHEN ccc.id_clasificacion_concepto_causacion in (1,45) THEN SUM(cn.dias) ELSE NULL END AS dias_trabajados,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 1 THEN SUM(cn.valor) ELSE NULL END AS salario_base,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 5 THEN SUM(cn.valor) ELSE NULL END AS auxilio_transporte,
	CASE WHEN ccc.id_clasificacion_concepto_causacion in (20,55) THEN SUM(cn.dias) ELSE NULL END AS dias_prima,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 20 THEN SUM(cn.valor) ELSE NULL END AS valor_prima,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 55 THEN SUM(cn.valor) ELSE NULL END AS valor_primaNS,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 18 THEN SUM(cn.valor) ELSE NULL END AS pago_cesantias,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 18 THEN AVG(cc.porcentaje) ELSE NULL END AS porcentaje_cesantias,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 19 THEN SUM(cn.valor) ELSE NULL END AS intereses_cesantias,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 44 THEN SUM(cn.valor) ELSE NULL END AS dotacion,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 45 THEN SUM(cn.valor) ELSE NULL END AS apoyo_sost,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 46 THEN SUM(cn.valor) ELSE NULL END AS teletrabajo,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 6 THEN SUM(cn.valor) ELSE NULL END AS bonif_retiro,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 47 THEN SUM(cn.valor) ELSE NULL END AS indemnizacion,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 37 THEN SUM(cn.valor) ELSE NULL END AS reintegro,
	CASE WHEN ccc.id_clasificacion_concepto_causacion = 57 THEN SUM(cn.valor) ELSE NULL END AS viaticosManuntencion
FROM	
	documentos d,
	documentos d2,
	info_documento i,
	causacion_nomina cn,
	general g,
	concepto_causacion cc
FULL OUTER JOIN
	clasificacion_conceptos_causacion ccc
ON
	cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion
WHERE	
	d.ndocumento = '?' AND -- ndocumento
	d.estado AND
	d.ndocumento = i.rf_documento AND
	i.ndocumento = d2.ndocumento AND
	d2.estado AND
	i.ndocumento = cn.ndocumento AND
	cn.id_concepto_causacion = cc.id_concepto_causacion AND
	cc.id_movimiento_nomina IN (1,5,7,9) AND
	cn.id_tercero = g.id AND
	g.id_char = '?' -- nitcc tercero
GROUP BY
	g.id,
	ccc.id_clasificacion_concepto_causacion;

SELECT
	SUM(dias_trabajados) AS dias_trabajados,
	SUM(salario_base) AS salario_base,
	SUM(auxilio_transporte) AS auxilio_transporte,
	SUM(dias_prima) AS dias_prima,
	--1::integer as dias_prima, Se puso para envio de nominas Diciembre 2023 pero no recuerdo por que Ene 31 2024
	SUM(valor_prima) AS valor_prima,
	SUM(valor_primaNS) AS valor_primaNS,
	COALESCE((SUM(pago_cesantias)),0) AS pago_cesantias,
	CASE WHEN (SUM(intereses_cesantias)) != 0 THEN COALESCE((SUM(porcentaje_cesantias)),12.00) ELSE 0 END AS porcentaje_cesantias,
	COALESCE((SUM(intereses_cesantias)),0) AS intereses_cesantias,
	SUM(dotacion) AS dotacion,
	SUM(apoyo_sost) AS apoyo_sost,
	SUM(teletrabajo) AS teletrabajo,
	SUM(bonif_retiro) AS bonif_retiro,
	SUM(indemnizacion) AS indemnizacion,
	SUM(reintegro) AS reintegro,
	SUM(viaticosManuntencion) AS viaticosManuntencion
FROM
	aux_temporal01;

