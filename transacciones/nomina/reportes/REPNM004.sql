DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
	'?'::DATE AS fechai,
	'?'::DATE AS fechaf,
	TRIM('?'::VARCHAR) AS id_division;

/*
* AUXILIO DE TRANSPORTE
*/

DROP TABLE IF EXISTS transporte_nomina;
CREATE TEMP TABLE transporte_nomina AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	sum(cn.valor) AS aux_transporte
FROM
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina=7 AND -- devengado por valor
	c.id_clasificacion_concepto_causacion = 5 AND -- 5 auxilio transporte
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE end
group by
		d.ndocumento,
		cn.id_tercero;

/*
* EXTRAS
*/

DROP TABLE IF EXISTS extras_nomina;
CREATE TEMP TABLE extras_nomina AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS extras
FROM
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 1 AND -- devengado obligatorio
	c.id_clasificacion_concepto_causacion not in (1,45) AND -- 1 salario 45 apoyo de sostenimiento Oct 30 2024
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	(
    (c.id_movimiento_nomina IN (5) AND -- comision ventas prueba
	c.id_clasificacion_concepto_causacion NOT IN (5,22,23,56,24)) OR -- exceptuando auxili transporte e incapacidades que tienen su propio apartado mas abajo e incapacidades 24 porque tambien tienen su apartado
    
    (c.id_movimiento_nomina IN (7) AND -- devengado por valor
	c.id_clasificacion_concepto_causacion IN (54,57) ) -- 50:Viaticos NS 54: viaticos NS 57:Auxilios (No base salario)
    ) AND
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 2 AND -- deducido porcentual
	c.id_clasificacion_concepto_causacion IN (8,9,15) AND --8 salud 9 pensiones obligatorio 15 fondo solidaridad pensional
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina = 6 AND -- deducido porcentual
	c.id_clasificacion_concepto_causacion=14 AND -- 14 retencion en la fuente
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion=50 AND -- 50 comisiones
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina IN (7) AND
	c.id_clasificacion_concepto_causacion=52 AND -- 52 Bonificacion (No Base Salario)
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion in (22,23,24,56) AND -- 22 incapacidades generales 23 lic paternidad o maternidad 24 licencia remunerada 56 incapacidades laborales
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion IN (41) AND -- 41 pagos terceros pre-exequiales montes de los olivos y recordar
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_clasificacion_concepto_causacion IN (38) AND -- 38 deuda en el momento incluye conceptos: desc autorizados facs credito
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (6) AND -- deducido por valor
	c.id_clasificacion_concepto_causacion IN (32,34,35,42) AND -- 32 afc 34 embargo fiscal 35 plan complementarios 42 anticipos
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
GROUP BY
	d.ndocumento,
	cn.id_tercero;
	
DROP TABLE IF EXISTS nominas_del_periodo;
CREATE TEMP TABLE nominas_del_periodo AS
select distinct 
	d.ndocumento,
	d.fecha,
	cn.id_tercero
FROM
	documentos d,
	args_nomina an,
	causacion_nomina cn
WHERE
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' and
	d.ndocumento = cn.ndocumento AND
	d.estado;


DROP TABLE IF EXISTS novedades_del_periodo;
CREATE TEMP TABLE novedades_del_periodo AS
select
	cnn.fecha,
	cnn.id_tercero,
	nn.sigla as novedad
FROM
	(select distinct id_tercero from nominas_del_periodo) np,
	documentos dn,
	args_nomina an,
	novedades_nomina nn,
	causacion_novedades_nomina cnn
WHERE
	dn.ndocumento=cnn.ndocumento AND
	dn.estado and
	nn.id_novedad_nomina=cnn.id_novedad_nomina AND
	dn.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	np.id_tercero = cnn.id_tercero;

DROP TABLE IF EXISTS novedades_planilla;
CREATE TEMP TABLE novedades_planilla as
select -- 3 agrupamos por documento y tercero las novedades ya filtradas y asignadas
	foo.ndocumento,
	foo.id_tercero,
	STRING_AGG(DISTINCT foo.novedad::TEXT,',') AS novedad
from
	(select -- 2 tomamos la primera nomina que haya afectado la novedad
		min(foo.ndocumento) as ndocumento,
		foo.id_tercero,
		foo.novedad
	from	
		(select -- 1 buscamos las novedades menores o iguales a una causacion nomina
			nm.ndocumento,
			nn.id_tercero,
			nn.novedad
		from 
			nominas_del_periodo nm,
			novedades_del_periodo nn
		where 
			nm.id_tercero = nn.id_tercero and
			nn.fecha <= nm.fecha::date) as foo
	group by 
		foo.id_tercero,
		foo.novedad) as foo
group by
	foo.ndocumento,
	foo.id_tercero;

-- CESANTIAS PAGADAS
DROP TABLE IF EXISTS cesantias_pagadas;
CREATE TEMP TABLE cesantias_pagadas AS
SELECT 
	d.ndocumento,
	cn.id_tercero,
	SUM(cn.valor) AS cesantias_pagadas
FROM
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (18) AND -- cesantias en el momento incluye unicamente cesantias pagadas feb 9
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (19) AND -- intereses cesantias en el momento incluye unicamente intereses sobre cesantias pagadas feb 9
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina in (7) AND -- devengado por valor: 
	c.id_clasificacion_concepto_causacion IN (20) AND -- prima en el momento incluye unicamente prima de servicios pagada feb 9
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
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
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	--c.id_movimiento_nomina in (7) AND -- devengado por valor Preguntar si son las 7 o las 9 o las dos
	c.id_clasificacion_concepto_causacion IN (26,51) AND -- 26 vacaciones disfrutadas 51 vacaciones pagadas
	d.ndocumento=cn.ndocumento AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END
GROUP BY
	d.ndocumento,
	cn.id_tercero;

-- BASICO Y DATOS GENERALES
-- Octubre 30 2024: agrego esta tabla para poder capturar los días trabajados por aprendices sena en el caso en el que su practica
-- termina a mitad de mes y luego son contratados, los días trabajados se guardan como apoyo de sostenimiento, esta tabla se usa en la siguiente
-- con left join, en las nóminas de apoyo de sostenimiento también se guarda por defecto el salario basico con dias = 30 lo cual confundia el reporte
-- poniendo 30 en vez del número de días efectivamente trabajados
DROP TABLE IF EXISTS basico_nomina_apoyos_sostenimiento;
CREATE TEMP TABLE basico_nomina_apoyos_sostenimiento AS
SELECT DISTINCT
	d.ndocumento,
	d.codigo_tipo||'-'||d.numero::BIGINT AS numero_nomina,
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
	--c.valor AS basico, Feb 19 2024: cambio esta linea por la siguiente para dejar los datos consistentes con la nomina, el 
	-- concepto cambia cada año
	cn.salario_basico as basico,
	cn.dias,
	cn.valor AS salario
FROM
	general g,
	documentos d,
	causacion_nomina cn,
	concepto_causacion c,
	division_nomina dn,
	args_nomina an
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	cn.id_division_nomina = dn.id_division_nomina AND
	c.id_movimiento_nomina=1 AND
	c.id_clasificacion_concepto_causacion=45 and -- apoyo sostenimiento
	d.ndocumento=cn.ndocumento AND
	g.id=cn.id_tercero AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END;



DROP TABLE IF EXISTS basico_nomina;
CREATE TEMP TABLE basico_nomina AS
SELECT DISTINCT
	d.ndocumento,
	d.codigo_tipo||'-'||d.numero::BIGINT AS numero_nomina,
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
	--c.valor AS basico, Feb 19 2024: cambio esta linea por la siguiente para dejar los datos consistentes con la nomina, el 
	-- concepto cambia cada año
	cn.salario_basico as basico,
	coalesce(bs.dias,cn.dias) as dias,
	coalesce(bs.salario,cn.valor) AS salario
FROM
	general g,
	documentos d,	
	concepto_causacion c,
	division_nomina dn,
	args_nomina an,
	causacion_nomina cn
left join
	basico_nomina_apoyos_sostenimiento bs
on
	cn.ndocumento = bs.ndocumento and
	cn.id_tercero = bs.id_tercero
WHERE
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	cn.id_division_nomina = dn.id_division_nomina AND
	c.id_movimiento_nomina=1 AND
	c.id_clasificacion_concepto_causacion=1 AND
	d.ndocumento=cn.ndocumento AND
	g.id=cn.id_tercero AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END;




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
    foo.extras,
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
		n.vacaciones_pagadas_disfrutadas AS total_pago_mes
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
			COALESCE(vpd.vacaciones_pagadas_disfrutadas,0) AS vacaciones_pagadas_disfrutadas
		FROM
			basico_nomina bn
		LEFT OUTER JOIN
			novedades_planilla nn
		ON
			bn.id_tercero=nn.id_tercero AND -- descomentado marzo 30 2023
			bn.ndocumento=nn.ndocumento -- descomentado marzo 30 2023
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
			bn.ndocumento=pt.ndocumento) AS n) AS foo
ORDER BY
	foo.anio,
	foo.id_mes,
	foo.division,
	foo.numero_orden,
	foo.nombre;