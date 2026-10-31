-- SCSNM0012 983 mseg
DROP TABLE IF EXISTS datos_hv;
CREATE TEMP TABLE datos_hv AS
SELECT DISTINCT
	d2.*
FROM
	info_documento i,
	documentos d,
	documentos d2
WHERE
	i.rf_documento = '?' AND -- ndocumento de NE asociada a las nominas de los terceros de la division que está siendo enviada
	i.rf_documento = d.ndocumento AND
	d.estado AND
	d2.ndocumento = i.ndocumento AND
	d2.estado;

/*
 * Enero 7 2026: comento toda esta seccion para dar paso a la nueva, en esta el nitcc tercero era una interrogacion
 * Con el nuevo modelo hago suma de valores de dias y valores para tener un solo registro, en el viejo solo asumia uno si existian novedades o registros por valor en fechas diferentes
 * para el registro de vacaciones
SELECT 
    nov.dias AS cantidad,
    cn.valor AS pago
FROM    
	documentos d2,
    causacion_nomina cn,
    registro_conceptos_nomina_valor r,
    general g,
	causacion_novedades_nomina nov,
    concepto_causacion cc,
    clasificacion_conceptos_causacion ccc,
	datos_hv h
WHERE
	to_char(nov.fecha, 'MM-YYYY') = to_char(h.fecha, 'MM-YYYY') AND --cambio hecho Feb 06 de 2024
	nov.ndocumento = d2.ndocumento AND
    h.ndocumento = cn.ndocumento AND
	nov.id_tercero = cn.id_tercero AND
	nov.id_novedad_nomina =13 AND
    d2.estado AND
    cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion AND
    ccc.id_clasificacion_concepto_causacion in (21,51) AND -- vacaciones, vacaciones_pagadas Se adiciona 21 Ene 02 2024
    cn.id_concepto_causacion = cc.id_concepto_causacion and
    cc.id_movimiento_nomina != 4 and -- se adiciona este filtro para descartar los conceptos por provision de vacaciones Ene 02 2024
    cn.id_tercero = g.id AND
    g.id_char = '1004191347'; -- nitcc tercero
  */


drop table if exists aux_causacion_novedades_nomina_vacas;
create temp table aux_causacion_novedades_nomina_vacas as
select
	to_char(cnn.fecha, 'MM-YYYY') as periodo,
	cnn.id_tercero,
	sum(cnn.dias) as dias
from
	causacion_novedades_nomina cnn
inner join
	documentos d
on
	cnn.ndocumento = d.ndocumento 
inner join
	info_documento id
on
	cnn.ndocumento = id.ndocumento 
	and id.rf_documento is null
inner join
	(select fecha from datos_hv limit 1) h
on
	to_char(cnn.fecha, 'MM-YYYY') = to_char(h.fecha, 'MM-YYYY')
where
	cnn.id_novedad_nomina = 13
	and d.estado 
	and cnn.id_tercero = (select id from general where id_char = '?') -- id_char del empleado
group by
	to_char(cnn.fecha, 'MM-YYYY'),
	cnn.id_tercero;

drop table if exists aux_registro_conceptos_nomina_x_valor_vacas;
create temp table aux_registro_conceptos_nomina_x_valor_vacas as
select
	to_char(d.fecha, 'MM-YYYY') as periodo,
	rcnv.id_tercero,
	sum(rcnv.valor) as valor
from
	registro_conceptos_nomina_valor rcnv 
inner join
	documentos d
on
	rcnv.ndocumento = d.ndocumento 
inner join
	concepto_causacion cc 
on 
	rcnv.id_concepto_causacion = cc.id_concepto_causacion 
inner join
	clasificacion_conceptos_causacion ccc 
on
	cc.id_clasificacion_concepto_causacion = ccc.id_clasificacion_concepto_causacion 
where
	to_char(d.fecha, 'MM-YYYY') = (select to_char(fecha, 'MM-YYYY') from datos_hv limit 1)
	and d.estado
	and ccc.id_clasificacion_concepto_causacion in (21,51)
	and cc.id_movimiento_nomina != 4 -- se adiciona este filtro para descartar los conceptos por provision de vacaciones Ene 02 2024
group by
	to_char(d.fecha, 'MM-YYYY'),
	rcnv.id_tercero;

select
	a.dias as cantidad,
	b.valor as pago
from
	aux_causacion_novedades_nomina_vacas a
inner join 
	aux_registro_conceptos_nomina_x_valor_vacas b
on
	a.periodo = b.periodo 
	and a.id_tercero = b.id_tercero;

