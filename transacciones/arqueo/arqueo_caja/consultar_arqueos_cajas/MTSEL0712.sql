DROP TABLE IF EXISTS tmp_args;
CREATE TEMP TABLE tmp_args AS
select
	da.narqueo,
	da.ndocumento
from
	documentos d,
	datos_arqueo da,
	documentos d2
where
	d.ndocumento = da.narqueo and
	d.estado and
	da.ndocumento = d2.ndocumento and
	d2.estado and
	d.fecha::DATE between '?' and '?';

DROP TABLE IF EXISTS aux_cuentas_consulta;
CREATE TEMP TABLE aux_cuentas_consulta as
select
	cu.id_cta,
	cu.char_cta
from
	cuentas cu
where
	(cu.char_cta like '110535%' OR
	cu.char_cta like '1105150%')  and -- Incluye entrega sencilla
	cu.char_cta not in ('11053502') or --Descarta J1 recogidas
	(cu.char_cta like '1110%' OR
	cu.char_cta='281010');

DROP TABLE IF EXISTS aux_libro_auxiliar_consulta;
CREATE TEMP TABLE aux_libro_auxiliar_consulta AS
SELECT
	t.narqueo,
	cu.char_cta,
	sum(coalesce(l.debe,0)) as debe,
	sum(coalesce(l.haber,0)) as haber
FROM
	libro_auxiliar l,
	aux_cuentas_consulta cu,
	tmp_args t
WHERE
	t.ndocumento=l.ndocumento and
	cu.id_cta = l.id_cta
GROUP BY
	t.narqueo,
	cu.char_cta;


-- Obtiene total pagos hechos en efectivo de los documentos de cada arqueo
DROP TABLE IF EXISTS tarqueo_efectivo;
CREATE TEMP TABLE tarqueo_efectivo AS
SELECT
	l.narqueo,
	COALESCE(sum(debe),0) AS total
FROM
	aux_libro_auxiliar_consulta l
WHERE
	(l.char_cta like '110535%' OR
	l.char_cta like '1105150%')  AND -- Incluye entrega sencilla
	l.char_cta != '11053502'
GROUP BY
	l.narqueo
ORDER BY
	l.narqueo;

-- Obtiene total pagos hechos en tarjetas de los documentos de cada arqueo
DROP TABLE IF EXISTS tarqueo_tarjetas;
CREATE TEMP TABLE tarqueo_tarjetas AS
SELECT
	l.narqueo,
	COALESCE(sum(debe),0) AS total
FROM
	aux_libro_auxiliar_consulta l
WHERE
	(l.char_cta like '1110%' OR
	l.char_cta='281010')
GROUP BY
	l.narqueo
ORDER BY
	l.narqueo;

DROP TABLE IF EXISTS tarqueo_egresos;
CREATE TEMP TABLE tarqueo_egresos AS
SELECT
	l.narqueo,
	COALESCE(sum(haber),0) AS total
FROM
	aux_libro_auxiliar_consulta l
WHERE
	l.char_cta like '110535%'
GROUP BY
	l.narqueo
ORDER BY
	l.narqueo;


DROP TABLE IF EXISTS tarqueo_recaudo;
CREATE TEMP TABLE tarqueo_recaudo AS
SELECT
	d.ndocumento AS narqueo,
	d.codigo_tipo||'-'||d.numero::bigint AS numero,
	d.fecha,
	g.nombre1||' '||g.apellido1 AS cajero,
	coalesce("100000",0)+coalesce("50000",0)+coalesce("20000",0)+coalesce("10000",0)+coalesce("5000",0)+coalesce("2000",0)+coalesce("1000",0)+coalesce(monedas,0) AS pesos,
	coalesce("100",0)+coalesce("50",0)+coalesce("20",0)+coalesce("10",0)+coalesce("5",0)+coalesce("1",0)+coalesce(monedasd,0) AS dolares,
	e.trm,
	coalesce(tcredito,0) as tcredito,
	coalesce(tdebito,0) as tdebito,
	coalesce(tregalo,0) as tregalo,
	COALESCE(tsodexo,0) AS tsodexo,
	COALESCE(tbigpass,0) AS tbigpass,
	asu.nombre,
	d.codigo_tipo
FROM
	documentos d,
	documentos_sucursales ds,
	administracion_sucursales asu,
	efectivo e,
	info_documento i,
	general g	
WHERE
	d.ndocumento in (select distinct t.narqueo from tmp_args t) and
	d.codigo_tipo = ds.codigo_tipo AND
	d.estado AND
	ds.id_administracion_sucursales = asu.id_administracion_sucursales AND
	i.ndocumento=d.ndocumento AND
	d.ndocumento=e.narqueo AND
	g.id=i.id_usuario;
	
DROP TABLE IF EXISTS tmp_mvaq;
CREATE TEMP TABLE tmp_mvaq AS
SELECT
	r.nombre,
	r.fecha,
	r.numero,
	r.cajero,
	COALESCE(e.total,0)-COALESCE(te.total,0) AS total_efectivo,
	COALESCE(t.total,0) AS total_tarjetas,
	COALESCE(te.total,0) AS total_egresos,
	--pesos+(dolares*trm)+tcredito+tdebito+tregalo AS recaudo,
	COALESCE(pesos,0)+(COALESCE(dolares,0)*r.trm) AS recaudo,
	--ROUND(((e.total-te.total)-(pesos+(dolares*trm)+tcredito+tdebito+tregalo))::NUMERIC,2) AS diferencia,
	ROUND(((COALESCE(e.total,0)-COALESCE(te.total,0))-(COALESCE(pesos,0)+(COALESCE(dolares,0)*r.trm)))::NUMERIC,2) AS diferencia,
	r.narqueo,
	r.codigo_tipo,
	r.tsodexo,
	r.tbigpass
FROM	
	tarqueo_recaudo r
LEFT OUTER JOIN
	tarqueo_efectivo e
ON
	r.narqueo = e.narqueo
LEFT OUTER JOIN
	tarqueo_tarjetas t
ON
	r.narqueo = t.narqueo
LEFT OUTER JOIN
	tarqueo_egresos te
ON
	r.narqueo = te.narqueo;


SELECT
	q.nombre,
	q.fecha,
	numero,
	cajero,
	total_tarjetas,
	total_efectivo,
	recaudo,
	diferencia,
	CASE WHEN diferencia < 0 THEN 'Sobró' ELSE CASE WHEN diferencia > 0 THEN 'Faltó' ELSE 'Perfect!!!' END END AS estado,
	gtotal,
	'MTR00202' AS perfil,
	narqueo,
	COALESCE(total_tarjetas,0)+COALESCE(total_efectivo,0)+COALESCE(tsodexo,0)+COALESCE(tbigpass,0)-COALESCE(total_egresos,0) as total
FROM
	tmp_mvaq AS q,
	(SELECT
		fecha,
		sum(total_efectivo+total_tarjetas+tsodexo+tbigpass-total_egresos) AS gtotal
	FROM
		tmp_mvaq
	GROUP BY
		fecha) AS f
WHERE
	f.fecha=q.fecha
ORDER BY
	codigo_tipo,
	numero;