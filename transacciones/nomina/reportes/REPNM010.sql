-- reporte pago cuenta 
DROP TABLE IF EXISTS args_nomina;
CREATE TEMP TABLE args_nomina AS
SELECT
	'?'::DATE AS fechai,
	'?'::DATE AS fechaf,
	TRIM('?'::VARCHAR) AS id_division;

-- Sep 27 2023: se usa para no listar aquellos empleados que hayan sido retirados
DROP TABLE IF EXISTS aux_empleados_retirados_suspendidos;
CREATE TEMP TABLE aux_empleados_retirados_suspendidos AS
select distinct
	cnn.id_tercero
from
	causacion_novedades_nomina cnn,
	(select 
		cnn.id_tercero,
		MAX(cnn.ndocumento) as ndocumento
	from
		documentos d,
		causacion_novedades_nomina cnn
	where
		cnn.ndocumento = d.ndocumento and
		d.estado	
	group by
		cnn.id_tercero) as foo
where
	--cnn.id_tercero = (select id from general where id_char = '1085931317') and
	cnn.ndocumento = foo.ndocumento and
	cnn.id_tercero = foo.id_tercero and
	cnn.id_novedad_nomina IN (11); -- 11 retiro;


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
	c.id_clasificacion_concepto_causacion != 1 AND -- 1 salario
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
	c.id_clasificacion_concepto_causacion IN (54,57,55) ) -- 50:Viaticos NS 54: viaticos NS 57:Auxilios (No base salario) Oct 29 2025: se agrega 55: prima (no base salario) para tener en cuenta prima extra legal adm llamado Johana
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
	--c.id_movimiento_nomina IN (5,7) AND
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

/*
* BASICO Y DATOS GENERALES
*/

DROP TABLE IF EXISTS basico_nomina;
CREATE TEMP TABLE basico_nomina AS
SELECT DISTINCT
	d.ndocumento,
	d.numero,
	cn.id_tercero,
	COALESCE(g.apellido1,' ')||' '||COALESCE(g.apellido2||' ',' ')||COALESCE(g.nombre1||' ',' ')||COALESCE(g.nombre2,' ') AS nombre,
	g.id_char,
	cn.salario_basico as basico,
	cn.dias,
	cn.valor AS salario
FROM
	general g,
	documentos d,
	causacion_nomina cn,
	--aux_empleados_retirados_suspendidos a, Feb 19 2025
	concepto_causacion c,
	args_nomina an
WHERE
	--cn.id_tercero != a.id_tercero and
	--cn.id_tercero not in (select id_tercero from aux_empleados_retirados_suspendidos) and Feb 19 2025
	cn.id_concepto_causacion=c.id_concepto_causacion AND
	c.id_movimiento_nomina=1 AND
	c.id_clasificacion_concepto_causacion=1 AND
	d.ndocumento=cn.ndocumento AND
	g.id=cn.id_tercero AND
	d.fecha::DATE BETWEEN an.fechai AND an.fechaf AND
	d.codigo_tipo = 'NM' AND
	d.estado AND
	CASE WHEN an.id_division IS NOT NULL AND an.id_division != '' THEN an.id_division = cn.id_division_nomina::VARCHAR ELSE TRUE END;
	
DROP TABLE IF EXISTS info_cuenta_bancaria;
CREATE TEMP TABLE info_cuenta_bancaria AS 
SELECT DISTINCT ON(c.id)
	c.id,
	b.nombre AS banco,
	t.descripcion AS tipo,
	c.cuenta
FROM
	cuentas_bancarias c,
	tipo_cuenta_bancaria t,
	bancos b
WHERE	
	b.banco=c.banco AND
	c.tipo=t.tipo
ORDER BY
	c.id DESC,
	c.id_cuenta_bancaria DESC;
	
SELECT
	n.nombre,
	n.id_char,
	COALESCE(c.banco,'SIN DEFINIR') AS entidad,
	COALESCE(c.tipo,'N/A') AS tipo,
	COALESCE(c.cuenta,'N/A') AS cuenta,
	n.total_devengado-n.total_deducido AS neto_pago
FROM
	(SELECT
	 	bn.id_tercero,
		bn.nombre,
		bn.id_char,
		bn.basico,
		bn.dias,
		bn.salario,
		COALESCE(atr.aux_transporte,0) AS aux_transporte,
		COALESCE(ex.extras,0) AS extras,
		COALESCE(od.otr_devengados,0) AS otr_devengados,
		bn.salario+
		COALESCE(atr.aux_transporte,0)+
		COALESCE(ex.extras,0)+
	 	COALESCE(comi.valor,0) +
	 	COALESCE(boni.valor,0) +
		COALESCE(inc.incapacidad,0)+		
		COALESCE(od.otr_devengados,0) AS total_devengado,
		COALESCE(sp.sal_pen,0) AS sal_pen,
		COALESCE(rf.ret_fte,0) AS ret_fte,
		COALESCE(da.des_autorizado,0) AS des_autorizado,
		COALESCE(dot.otros_desc,0) AS otros_desc,
		COALESCE(sp.sal_pen,0)+
		COALESCE(rf.ret_fte,0)+
		COALESCE(pt.pagos_terceros,0)+
		COALESCE(da.des_autorizado,0)+
		COALESCE(dot.otros_desc,0) AS total_deducido

	FROM
		basico_nomina bn
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
		/*LEFT OUTER JOIN 
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
			bn.ndocumento=vpd.ndocumento*/
		LEFT OUTER JOIN
			pagos_terceros pt
		ON
			bn.id_tercero=pt.id_tercero AND
			bn.ndocumento=pt.ndocumento
) AS n
LEFT OUTER JOIN
	info_cuenta_bancaria c
ON
	n.id_tercero=c.id
ORDER BY
	n.nombre;