-- SCSNM0033
DROP TABLE IF EXISTS fecha_ingreso;
CREATE TEMP TABLE fecha_ingreso AS
	SELECT 
		id_tercero,
		MIN(fecha) as fecha_ingreso
	FROM
		causacion_novedades_nomina 
	WHERE
		id_novedad_nomina=10
	
	GROUP BY 
		id_tercero;
	
DROP TABLE IF EXISTS aux_nm_valor_ok;
CREATE TEMP TABLE aux_nm_valor_ok AS
SELECT
	foo1.ndocumento,
	foo1.id_tercero,
	foo1.valor_ok_haber - COALESCE(foo2.valor_ok_debe,0) - COALESCE(valor_ok_debe_aprendices_sena,0) AS valor_ok
FROM
	(SELECT
		d.ndocumento,
		l.id_tercero,
		SUM(l.haber) AS valor_ok_haber
	FROM
		libro_auxiliar l,
		documentos d,
		cuentas c
	WHERE
		d.ndocumento = l.ndocumento and
		--c.nombre not in ('VACACIONES CONSOLIDADAS') AND
		l.id_cta = c.id_cta AND
		(c.char_cta ILIKE '25%' OR
	 	c.char_cta ILIKE '2335%') AND
		d.estado AND
		d.codigo_tipo = 'NM'
	GROUP BY
		d.ndocumento,
		l.id_tercero) AS foo1
LEFT OUTER JOIN		
	(SELECT
		d.ndocumento,
		l.id_tercero,
		SUM(l.debe) AS valor_ok_debe
	FROM
		libro_auxiliar l,
		documentos d,
		cuentas c
	WHERE
		d.ndocumento = l.ndocumento AND
		l.id_cta = c.id_cta AND
		c.char_cta like '25%' and -- Oct 31 2025: cambio condicion de 250505 a ilike 25%
		d.estado AND
		d.codigo_tipo = 'NM'
	GROUP BY
		d.ndocumento,
		l.id_tercero) AS foo2
ON
	foo1.id_tercero = foo2.id_tercero AND
	foo1.ndocumento = foo2.ndocumento
LEFT OUTER JOIN		-- Julio 06 2023: se agrega este join para tener en cuenta registro de deducidos (debe) en la 23359508 para el caso de Sena Etapa Productiva, ya que estos no registran en la 250505 Fer
	(SELECT distinct
		d.ndocumento,
		l.id_tercero,
		SUM(l.debe) AS valor_ok_debe_aprendices_sena
	FROM
		libro_auxiliar l,
		documentos d,
		cuentas c
	WHERE
		d.ndocumento = l.ndocumento AND
	 	l.id_tercero IN (SELECT id_tercero FROM datos_division WHERE id_division IN (9,10,15,23)) AND
		l.id_cta = c.id_cta AND
		c.char_cta ILIKE '23359508%' AND
		d.estado AND
		l.debe != 0 and
		d.codigo_tipo = 'NM'
	GROUP BY
		d.ndocumento,
		l.id_tercero) AS foo3
ON
	foo1.id_tercero = foo3.id_tercero AND
	foo1.ndocumento = foo3.ndocumento;
		
		
SELECT DISTINCT
	g.id,
	trim(g.id_char) as id_char,
	'NE' AS prefijo, --prefijo consecutivo envío
	r.consecutivo,
	r.mes AS periodo, -- Si es el mes 
	0.0 AS devengado, -- preguntar
	0.0 AS deducido, -- preguntar
	COALESCE(ie.id_tipo_trabajador_ne,'01') AS tipo_trabajador, -- preguntar
	COALESCE(ie.id_subtipo_trabajador_ne,'00') AS subtipo_trabajador, -- preguntar
	c.id_clase_tercero AS tipo_documento, -- preguntar
	g.apellido1,
	CASE WHEN g.apellido2 IS NULL OR g.apellido2 = '' THEN ' ' ELSE g.apellido2 END AS apellido2,
	g.nombre1,
	CASE WHEN g.nombre2 IS NULL OR g.nombre2 = '' THEN ' ' ELSE g.nombre2 END AS nombre2,
	dir.id_pais,
	TRIM(dir.id_dep) AS id_dep,
	dir.municipio,
	dir.direccion,
	cc.valor AS salario_base, -- confirmar
	COALESCE(tc.id_tipo_contrato_ne,1) AS tipo_contrato, -- confirmar
	COALESCE(TRIM(ic.codigo),'47') AS metodo_pago, -- FORMA DE PAGO -- por defecto 47 -Transferencia D bito Bancaria
	CASE WHEN TRIM(ic.codigo) ='47' THEN COALESCE(ba.nombre,'SIN REGISTRAR') ELSE 'SIN REGISTRAR' END AS banco,
	CASE WHEN TRIM(ic.codigo) ='47' THEN COALESCE(CASE WHEN cb.tipo = 'A' THEN 'AHORROS' WHEN cb.tipo = 'C' THEN 'CORRIENTE' END,'SIN REGISTRAR') ELSE 'SIN REGISTRAR' END AS tipo_cuenta,
	CASE WHEN TRIM(ic.codigo) ='47' THEN COALESCE(cb.cuenta,'SIN REGISTRAR') ELSE 'SIN REGISTRAR' END AS numero_cuenta,
	'NOTA NOMINA ELECTRONICA' AS notas,
	r.anio::character(4)||'-'||r.mes::character(2)||'-01' AS fecha_inicio_periodo,
	d.fecha::DATE AS fecha_fin_periodo,
	fi.fecha_ingreso AS fecha_inicio_contrato,
	CASE WHEN d.fecha::date - fi.fecha_ingreso::date = 0 THEN 1 ELSE d.fecha::date - fi.fecha_ingreso::date END AS tiempo_laborado, --Nota: cambio para soportar casos en los que el ingreso y el egreso es el mismo dia Enero 30 2023
	an.valor_ok AS total_nomina
FROM
	documentos d,
	registro_nomina_electronica r,
	concepto_causacion cc,
	documentos d2,
	division_nomina dn,
	info_documento i,
	clase_tercero c,
	fecha_ingreso fi,
	aux_nm_valor_ok an,
	(SELECT DISTINCT ON (id)
		id,
		id_direccion,
		id_pais,
		id_dep,
		municipio,
		direccion
	FROM
		direcciones
	ORDER BY
		id,
		id_direccion DESC) AS dir,
	causacion_nomina cn
LEFT OUTER JOIN 
	(SELECT 
		ic.ndocumento, 
		fp.codigo
	FROM 
		info_causacion_nomina ic,
		formas_pago_nomina fp
	WHERE
		ic.id_forma_pago_nomina = fp.id_forma_pago_nomina) ic
ON 
	ic.ndocumento = cn. ndocumento,
	general g
LEFT OUTER JOIN
	info_empleado ie
ON
	g.id = ie.id
LEFT OUTER JOIN
	(SELECT DISTINCT ON(c.id)
        c.*
    FROM
        cuentas_bancarias c  
    ORDER BY
        c.id DESC,
        c.id_cuenta_bancaria DESC) cb
ON
	g.id = cb.id
LEFT OUTER JOIN
	bancos ba
ON
	cb.banco = ba.banco
LEFT OUTER JOIN
	tipo_contrato_empleado tc
ON
	ie.id_tipo_contrato_empleado=tc.id_tipo_contrato_empleado
WHERE
	cn.ndocumento = d2.ndocumento AND
	r.mes = EXTRACT('month' FROM d2.fecha) AND
	r.anio = EXTRACT('year' FROM d2.fecha) AND
	r.ndocumento = i.rf_documento AND
	i.ndocumento = cn.ndocumento AND	
	cn.id_concepto_causacion = cc.id_concepto_causacion AND
	r.id_division_nomina = dn.id_division_nomina and -- Ene 31 2024: adicione division nomina para tratar los casos del sena como se debe
	(cc.id_clasificacion_concepto_causacion = 45 and dn.descripcion ilike '%sena%' or -- Ene 31 2024: si es del sena toma el apoyo sostenimiento
	cc.id_clasificacion_concepto_causacion = 1 and dn.descripcion not ilike '%sena%') and --Ene 31 2024: si no se va por el salario normal
	--cc.id_clasificacion_concepto_causacion in (1,45) AND -- salarios apoyo sostenimiento para casos sena
	r.id_tercero = cn.id_tercero AND
	r.id_tercero = g.id AND
	g.id_clase_tercero = c.id_clase_tercero AND
	g.id = dir.id AND
	an.id_tercero = g.id AND
	an.ndocumento = i.ndocumento AND
	d.ndocumento = i.ndocumento AND
	fi.id_tercero = g.id AND
	r.ndocumento = '?'
ORDER BY
	trim(g.id_char);