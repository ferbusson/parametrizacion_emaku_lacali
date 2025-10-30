--borrador
DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
	'?'::DATE AS fechai,
	'?'::DATE AS fechaf,
	TRIM('?'::VARCHAR) AS id_division;

DROP TABLE IF EXISTS aux_ultimo_temporal;
CREATE TEMP TABLE aux_ultimo_temporal AS
SELECT
	MAX(cn.ndocumento) AS ndocumento
FROM
	documentos d,
	causacion_nomina_borrador cn,
	args_nomina an
WHERE
	d.ndocumento = cn.ndocumento AND
	d.estado AND
	d.codigo_tipo = 'VN' AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
GROUP BY
	cn.id_division_nomina;

/*
* AUXILIO DE TRANSPORTE
*/

DROP TABLE IF EXISTS transporte_nomina;
CREATE TEMP TABLE transporte_nomina AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	cn.valor AS aux_transporte
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c	
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina=7 AND -- devengado por valor
	c.id_clasificacion_concepto_causacion = 5 AND -- 5 auxilio transporte
	d.ndocumento=cn.ndocumento;


/* Horas extras diurna ordinaria */
DROP TABLE IF EXISTS hed;
CREATE TEMP TABLE hed AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS thed,
    ce.valor AS vhed
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 2; -- 2 hora extra diurna

/* Horas extras noctura ordinaria */
DROP TABLE IF EXISTS hen;
CREATE TEMP TABLE hen AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS then,
    ce.valor AS vhen
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 27; -- 27 hora extra nocturna

/* Horas extras diurna dominical */
DROP TABLE IF EXISTS heddf;
CREATE TEMP TABLE heddf AS
SELECT 
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS theddf,
    ce.valor AS vheddf
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 4; -- 4  Hora Extra Diurna Dominical y Festivos

/* Horas extras nocturna dominical */
DROP TABLE IF EXISTS hendf;
CREATE TEMP TABLE hendf AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS thendf,
    ce.valor AS vhendf
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 29; -- 29 Hora Extra Nocturna Dominical y Festivos

/* Recargo Noctuhrn Ordinario */
DROP TABLE IF EXISTS hrn;
CREATE TEMP TABLE hrn AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS thrn,
    ce.valor AS vhrn
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 3; -- hora recargo nocturno

/* Recargo Nocturno Dominical */
DROP TABLE IF EXISTS hrndf;
CREATE TEMP TABLE hrndf AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS thrndf,
    ce.valor AS vhrndf
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 30; -- 30 hora recargo nocturno dominical y festivos

/* Dominical o Festivo */
DROP TABLE IF EXISTS hrddf;
CREATE TEMP TABLE hrddf AS
SELECT
    d.ndocumento,
    ce.id_tercero,
    ce.tiempo AS thrddf,
    ce.valor AS vhrddf
FROM
    aux_ultimo_temporal d,
    causacion_extras_nomina_borrador ce,
    concepto_causacion cc
WHERE
    d.ndocumento=ce.ndocumento AND
    cc.id_concepto_causacion = ce.id_concepto_causacion AND
    cc.id_clasificacion_concepto_causacion = 28; -- 28 hora recargo diurno dominical y festivos

/*
* EXTRAS TOTAL
*/

DROP TABLE IF EXISTS extras_nomina;
CREATE TEMP TABLE extras_nomina AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS extras
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 1 AND -- devengado obligatorio
	c.id_clasificacion_concepto_causacion != 1 AND -- 1 salario
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

/*
* OTROS DEVENGADOS
*/
DROP TABLE IF EXISTS otr_devengados;
CREATE TEMP TABLE otr_devengados AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS otr_devengados
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	(
    (c.id_movimiento_nomina IN (5) AND -- comision ventas prueba
	c.id_clasificacion_concepto_causacion NOT IN (5,22,23,56,24)) OR -- exceptuando auxili transporte e incapacidades que tienen su propio apartado mas abajo e incapacidades 24 porque tambien tienen su apartado
    
    (c.id_movimiento_nomina IN (7) AND -- devengado por valor
	c.id_clasificacion_concepto_causacion IN (54,57,55) ) -- 50:Viaticos NS 54: viaticos NS 57:Auxilios (No base salario) Oct 29 2025: se agrega 55: prima (no base salario) para tener en cuenta prima extra legal adm llamado Johana
    ) AND
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

/*
* DEDUCIDOS SALUD Y PENSION
*/

DROP TABLE IF EXISTS ded_sal_pen;
CREATE TEMP TABLE ded_sal_pen AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS sal_pen
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 2 AND -- deducido porcentual
	c.id_clasificacion_concepto_causacion IN (8,9,15) AND --8 salud 9 pensiones obligatorio 15 fondo solidaridad pensional
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

/*
 * RETE FUENTE
*/
 
DROP TABLE IF EXISTS ded_ret_fte;
CREATE TEMP TABLE ded_ret_fte AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS ret_fte
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 6 AND -- deducido porcentual
	c.id_clasificacion_concepto_causacion=14 AND -- 14 retencion en la fuente
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

/*
 * COMISIONES
*/
 
DROP TABLE IF EXISTS comisiones;
CREATE TEMP TABLE comisiones AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS valor
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	--c.id_movimiento_nomina IN (5,7) AND
	c.id_clasificacion_concepto_causacion=50 AND -- 50 comisiones
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

/*
 * BONIFICACIONES NO SALARIALES
*/
 
DROP TABLE IF EXISTS bonificaciones;
CREATE TEMP TABLE bonificaciones AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS valor
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina IN (7) AND
	c.id_clasificacion_concepto_causacion=52 AND -- 52 Bonificacion (No Base Salario)
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;



/*
 * INCAPACIDADES
 */
 
DROP TABLE IF EXISTS ded_inc;
CREATE TEMP TABLE ded_inc AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS incapacidad
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion in (22,23,24,56) AND -- 22 incapacidades generales 23 lic paternidad o maternidad 24 licencia remunerada 56 incapacidades laborales
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;


--PAGOS A TERCEROS
DROP TABLE IF EXISTS pagos_terceros;
CREATE TEMP TABLE pagos_terceros AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS pagos_terceros
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion IN (41) AND -- 41 pagos terceros pre-exequiales montes de los olivos y recordar
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;
	
--DEDUCIDOS AUTORIZADOS 
DROP TABLE IF EXISTS ded_aut;
CREATE TEMP TABLE ded_aut AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS des_autorizado
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion IN (38) AND -- 38 deuda en el momento incluye conceptos: desc autorizados facs credito
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;



-- DEDUCIDOS OTRAS DEDUCCIONES 
DROP TABLE IF EXISTS ded_otros;
CREATE TEMP TABLE ded_otros AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS otros_desc
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (6) AND -- deducido por valor
	c.id_clasificacion_concepto_causacion IN (32,34,35) AND -- 32 afc 34 embargo fiscal 35 plan complementarios
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;
	
DROP TABLE IF EXISTS novedades_planilla;
CREATE TEMP TABLE novedades_planilla AS
SELECT
	d.ndocumento,
	cnn.id_tercero,
	STRING_AGG(DISTINCT nn.sigla::TEXT,',') AS novedad
FROM
	aux_ultimo_temporal d,
	documentos dn,
	info_documento i,
	novedades_nomina nn,
	causacion_novedades_nomina cnn
WHERE
	dn.ndocumento=cnn.ndocumento AND
	dn.estado AND
	nn.id_novedad_nomina=cnn.id_novedad_nomina AND	
	--CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END AND
	d.ndocumento = i.rf_documento AND
	i.ndocumento = cnn.ndocumento
GROUP BY 
	d.ndocumento,
	id_tercero;

-- CESANTIAS PAGADAS
DROP TABLE IF EXISTS cesantias_pagadas;
CREATE TEMP TABLE cesantias_pagadas AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS cesantias_pagadas
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (18) AND -- cesantias en el momento incluye unicamente cesantias pagadas feb 9
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

-- INTERESES SOBRE CESANTIAS PAGADAS
DROP TABLE IF EXISTS intereses_cesantias_pagadas;
CREATE TEMP TABLE intereses_cesantias_pagadas AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS intereses_cesantias_pagadas
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (19) AND -- intereses cesantias en el momento incluye unicamente intereses sobre cesantias pagadas feb 9
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

-- PRIMA DE SERVICIOS PAGADA
DROP TABLE IF EXISTS prima_servicios_pagada;
CREATE TEMP TABLE prima_servicios_pagada AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS prima_servicios_pagada
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (20) AND -- prima en el momento incluye unicamente prima de servicios pagada feb 9
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

-- VACACIONES PAGADAS YO DISFRUTADAS
DROP TABLE IF EXISTS vacaciones_pagadas_disfrutadas;
CREATE TEMP TABLE vacaciones_pagadas_disfrutadas AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS vacaciones_pagadas_disfrutadas
FROM
	aux_ultimo_temporal d,
	causacion_nomina_borrador cn,
	concepto_causacion c
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	--c.id_movimiento_nomina in (7) AND -- devengado por valor Preguntar si son las 7 o las 9 o las dos
	c.id_clasificacion_concepto_causacion IN (26,51) AND -- 26 vacaciones disfrutadas 51 vacaciones pagadas
	d.ndocumento=cn.ndocumento
GROUP BY
	d.ndocumento,
	cn.id_tercero;

-- BASICO Y DATOS GENERALES
DROP TABLE IF EXISTS basico_nomina;
CREATE TEMP TABLE basico_nomina AS
SELECT DISTINCT
	d.ndocumento,
	d.codigo_tipo||'-'||d.numero::BIGINT||' | '||d.fecha AS numero_nomina,
	d.numero::BIGINT AS numero_orden,
	dn.descripcion AS division,
	DATE_PART('month', d.fecha) AS id_mes,
	CASE WHEN DATE_PART('month', d.fecha) = 1 THEN 'ENERO' 
	     WHEN DATE_PART('month', d.fecha) = 2 THEN 'FEBRERO' 
	     WHEN DATE_PART('month', d.fecha) = 3 THEN 'MARZO' 
	     WHEN DATE_PART('month', d.fecha) = 4 THEN 'ABRIL' 
	     WHEN DATE_PART('month', d.fecha) = 5 THEN 'MAYO' 
	     WHEN DATE_PART('month', d.fecha) = 6 THEN 'JUNIO' 
	     WHEN DATE_PART('month', d.fecha) = 7 THEN 'JULIO' 
	     WHEN DATE_PART('month', d.fecha) = 8 THEN 'AGOSTO' 
	     WHEN DATE_PART('month', d.fecha) = 9 THEN 'SEPTIEMBRE' 
	     WHEN DATE_PART('month', d.fecha) = 10 THEN 'OCTUBRE' 
	     WHEN DATE_PART('month', d.fecha) = 11 THEN 'NOVIEMBRE'
	     WHEN DATE_PART('month', d.fecha) = 12 THEN 'DICIEMBRE'   
	     END AS mes,
	DATE_PART('year', d.fecha) AS anio,
	cn.id_tercero,
	COALESCE(g.apellido1,' ')||' '||COALESCE(g.apellido2||' ',' ')||COALESCE(g.nombre1||' ',' ')||COALESCE(g.nombre2,' ') AS nombre,
	g.id_char,
	cn.salario_basico as basico,
	cn.dias,
	cn.valor AS salario
FROM
	general g,
	documentos d,
	causacion_nomina_borrador cn,
	concepto_causacion c,
	division_nomina dn,
	aux_ultimo_temporal a
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	cn.id_division_nomina = dn.id_division_nomina AND
	c.id_movimiento_nomina=1 AND
	c.id_clasificacion_concepto_causacion=1 AND
	d.ndocumento=cn.ndocumento AND
	a.ndocumento = d.ndocumento AND
	g.id=cn.id_tercero;

SELECT
    foo.numero_nomina,    
    foo.periodo,
    foo.division,
    foo.nombre,
    foo.id_char,  
    foo.basico,
    foo.dias,
    foo.novedad,
    foo.salario,
    foo.incapacidades,
    foo.aux_transporte,
    foo.thrn,
	foo.vhrn,
	foo.thrddf,
	foo.vhrddf,
	foo.thrndf,
	foo.vhrndf,   
	foo.thed,
	foo.vhed,
	foo.then,
	foo.vhen,
	foo.theddf,
	foo.vheddf,
	foo.thendf,
	foo.vhendf,
	foo.total_extras, --total calculado del detallado
    foo.extras, --total calculado de tabla original plancha
    foo.comisiones,
    foo.bonificaciones,
    foo.otr_devengados,
    foo.total_devengado,
    foo.sal_pen,
    foo.ret_fte,
    foo.pagos_terceros,
    foo.des_autorizado AS deudas,
    foo.otros_desc,
    foo.total_deducido,
    foo.neto_pago,
    foo.cesantias_pagadas,
    foo.intereses_cesantias_pagadas,
    foo.prima_servicios_pagada,
    foo.vacaciones_pagadas_disfrutadas,
    foo.total_pago_mes
FROM    
	(SELECT
		n.numero_nomina,
		n.numero_orden,
		n.division,
		n.periodo,
		n.id_mes,
		n.anio,
		n.nombre,
		n.id_char,
		n.basico,
		n.dias,
		n.novedad,
		n.salario,
		n.incapacidades,
		n.aux_transporte,
		n.extras,
	 	n.comisiones,
	 	n.bonificaciones,
		n.otr_devengados,
		n.total_devengado,
		n.sal_pen,
		n.ret_fte,
		n.pagos_terceros,
		n.des_autorizado,
		n.otros_desc,
		n.total_deducido,
		n.total_devengado-n.total_deducido AS neto_pago,
		n.cesantias_pagadas,
		n.intereses_cesantias_pagadas,
		n.prima_servicios_pagada,
		n.vacaciones_pagadas_disfrutadas,
		(n.total_devengado-n.total_deducido) + n.cesantias_pagadas+
		n.intereses_cesantias_pagadas + n.prima_servicios_pagada+
		n.vacaciones_pagadas_disfrutadas AS total_pago_mes,

		n.thrn,
		n.vhrn,
		n.thrddf,
		n.vhrddf,
		n.thrndf,
		n.vhrndf,   
		n.thed,
		n.vhed,
		n.then,
		n.vhen,
		n.theddf,
		n.vheddf,
		n.thendf,
		n.vhendf,
		n.vhed+
		n.vhen+
		n.vheddf+
		n.vhendf+
		n.vhrn+
		n.vhrndf+
		n.vhrddf AS total_extras
	FROM
		(SELECT
			bn.numero_nomina,
			bn.numero_orden,
			bn.division,
			bn.mes||' - '||bn.anio AS periodo,
			bn.id_mes,
			bn.anio,
			bn.nombre::VARCHAR AS nombre,
			bn.id_char,
			bn.basico,
			bn.dias,
			COALESCE(nn.novedad::varchar,'-') AS novedad,
			bn.salario,
			COALESCE(atr.aux_transporte,0) AS aux_transporte,
			COALESCE(ex.extras,0) AS extras,
		 	COALESCE(comi.valor,0) AS comisiones,
		 	COALESCE(boni.valor,0) AS bonificaciones,
			COALESCE(od.otr_devengados,0) AS otr_devengados,
			COALESCE(inc.incapacidad,0) AS incapacidades,
			bn.salario+
			COALESCE(atr.aux_transporte,0)+
			COALESCE(ex.extras,0)+
		 	COALESCE(comi.valor,0) +
		 	COALESCE(boni.valor,0) +
			COALESCE(inc.incapacidad,0)+		
			COALESCE(od.otr_devengados,0) AS total_devengado,
			COALESCE(sp.sal_pen,0) AS sal_pen,
			COALESCE(rf.ret_fte,0) AS ret_fte,
			COALESCE(pt.pagos_terceros,0) AS pagos_terceros,
			COALESCE(da.des_autorizado,0) AS des_autorizado,
			COALESCE(dot.otros_desc,0) AS otros_desc,
			COALESCE(sp.sal_pen,0)+
			COALESCE(rf.ret_fte,0)+
			COALESCE(pt.pagos_terceros,0)+
			COALESCE(da.des_autorizado,0)+
			COALESCE(dot.otros_desc,0) AS total_deducido,
			COALESCE(cp.cesantias_pagadas,0) AS cesantias_pagadas,
			COALESCE(icp.intereses_cesantias_pagadas,0) AS intereses_cesantias_pagadas,
			COALESCE(psp.prima_servicios_pagada,0) AS prima_servicios_pagada,
			COALESCE(vpd.vacaciones_pagadas_disfrutadas,0) AS vacaciones_pagadas_disfrutadas,

			COALESCE(hed.thed,'-') AS thed,
			COALESCE(hed.vhed,0.0) AS vhed,
			COALESCE(hen.then,'-') AS then,
			COALESCE(hen.vhen,0.0) AS vhen,
			COALESCE(heddf.theddf,'-') AS theddf,
			COALESCE(heddf.vheddf,0.0) AS vheddf,
			COALESCE(hendf.thendf,'-') AS thendf,
			COALESCE(hendf.vhendf,0.0) AS vhendf,
			COALESCE(hrn.thrn,'-') AS thrn,
			COALESCE(hrn.vhrn,0.0) AS vhrn,
			COALESCE(hrndf.thrndf,'-') AS thrndf,
			COALESCE(hrndf.vhrndf,0.0) AS vhrndf,
			COALESCE(hrddf.thrddf,'-') AS thrddf,
			COALESCE(hrddf.vhrddf,0.0) AS vhrddf
		FROM
			basico_nomina bn
		LEFT OUTER JOIN
			novedades_planilla nn
		ON
			bn.id_tercero=nn.id_tercero AND
			bn.ndocumento=nn.ndocumento
		LEFT OUTER JOIN
			transporte_nomina atr
		ON
			bn.id_tercero=atr.id_tercero AND
			bn.ndocumento=atr.ndocumento
		LEFT OUTER JOIN
			extras_nomina ex
		ON
			bn.id_tercero=ex.id_tercero AND
			bn.ndocumento=ex.ndocumento
		LEFT OUTER JOIN
			ded_inc inc
		ON
			bn.id_tercero=inc.id_tercero AND
			bn.ndocumento=inc.ndocumento
		LEFT OUTER JOIN
			otr_devengados od
		ON
			bn.id_tercero=od.id_tercero AND
			bn.ndocumento=od.ndocumento
		LEFT OUTER JOIN
			ded_sal_pen sp
		ON
			bn.id_tercero=sp.id_tercero AND
			bn.ndocumento=sp.ndocumento
		LEFT OUTER JOIN
			ded_ret_fte rf
		ON
			bn.id_tercero=rf.id_tercero AND
			bn.ndocumento=rf.ndocumento
		LEFT OUTER JOIN
			ded_aut da
		ON
			bn.id_tercero=da.id_tercero AND
			bn.ndocumento=da.ndocumento
		LEFT OUTER JOIN	
			ded_otros dot
		ON
			bn.id_tercero=dot.id_tercero AND
			bn.ndocumento=dot.ndocumento
		LEFT OUTER JOIN	
			comisiones comi
		ON
			bn.id_tercero=comi.id_tercero AND
			bn.ndocumento=comi.ndocumento
		LEFT OUTER JOIN	
			bonificaciones boni
		ON
			bn.id_tercero=boni.id_tercero AND
			bn.ndocumento=boni.ndocumento
		LEFT OUTER JOIN 
			cesantias_pagadas cp
		ON
			bn.id_tercero=cp.id_tercero AND
			bn.ndocumento=cp.ndocumento
		LEFT OUTER JOIN 
			intereses_cesantias_pagadas icp
		ON
			bn.id_tercero=icp.id_tercero AND
			bn.ndocumento=icp.ndocumento
		LEFT OUTER JOIN 
			prima_servicios_pagada psp
		ON
			bn.id_tercero=psp.id_tercero AND
			bn.ndocumento=psp.ndocumento
		LEFT OUTER JOIN
			vacaciones_pagadas_disfrutadas vpd
		ON
			bn.id_tercero=vpd.id_tercero AND
			bn.ndocumento=vpd.ndocumento
		LEFT OUTER JOIN
			pagos_terceros pt
		ON
			bn.id_tercero=pt.id_tercero AND
			bn.ndocumento=pt.ndocumento
		LEFT OUTER JOIN -- Inicia detalle de extras
			hed
		    ON
			bn.id_tercero=hed.id_tercero AND
			bn.ndocumento=hed.ndocumento
		    LEFT OUTER JOIN
			hen
		    ON
			bn.id_tercero=hen.id_tercero AND
			bn.ndocumento=hen.ndocumento
		    LEFT OUTER JOIN
			heddf
		    ON
			bn.id_tercero=heddf.id_tercero AND
			bn.ndocumento=heddf.ndocumento
		    LEFT OUTER JOIN
			hendf
		    ON
			bn.id_tercero=hendf.id_tercero AND
			bn.ndocumento=hendf.ndocumento
		    LEFT OUTER JOIN
			hrn
		    ON
			bn.id_tercero=hrn.id_tercero AND
			bn.ndocumento=hrn.ndocumento
		    LEFT OUTER JOIN
			hrndf
		    ON
			bn.id_tercero=hrndf.id_tercero AND
			bn.ndocumento=hrndf.ndocumento
		    LEFT OUTER JOIN
			hrddf
		    ON
			bn.id_tercero=hrddf.id_tercero AND
			bn.ndocumento=hrddf.ndocumento) AS n) AS foo
ORDER BY
	foo.anio,
	foo.id_mes,
	foo.division,
	foo.numero_orden,
	foo.nombre;