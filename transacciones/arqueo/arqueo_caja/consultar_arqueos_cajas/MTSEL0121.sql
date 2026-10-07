DROP TABLE IF EXISTS args_arqueo_fac;
CREATE TEMP TABLE args_arqueo_fac AS
SELECT
	'?'::BIGINT AS ndocumento;	

DROP TABLE IF EXISTS codigo_tipo_fac;
CREATE TEMP TABLE codigo_tipo_fac AS
SELECT
	dsf.codigo_tipo
FROM
	documentos_standar s,
	documentos_sucursales ds,
	args_arqueo_fac a,
	documentos_standar sf,
	documentos_sucursales dsf,
	documentos d
WHERE
	ds.id_administracion_sucursales=dsf.id_administracion_sucursales AND
	sf.id_documento=dsf.id_documento AND
	sf.nombre='FCREDITO' AND
	s.id_documento=ds.id_documento AND
	ds.codigo_tipo=d.codigo_tipo AND
	d.ndocumento=a.ndocumento ;


DROP TABLE IF EXISTS tmp_docs;
CREATE TEMP TABLE tmp_docs AS
SELECT
	d.*
FROM
	documentos d,
	documentos a,
	datos_arqueo da,
	codigo_tipo_fac cf,
	args_arqueo_fac af
WHERE
	d.estado AND
	d.codigo_tipo=cf.codigo_tipo AND 
	d.ndocumento=da.ndocumento AND
	da.narqueo=a.ndocumento AND
	a.ndocumento=af.ndocumento;

DROP TABLE IF EXISTS aq_datos;
CREATE TEMP TABLE aq_datos AS
SELECT
	l.id_cta,
	l.ndocumento,
	a.fecha,
	a.codigo_tipo||a.numero AS numero,
	l.debe
FROM
	libro_auxiliar l,
	tmp_docs a
WHERE
	a.ndocumento=l.ndocumento;

DROP TABLE IF EXISTS doc_caja;
CREATE TEMP TABLE doc_caja AS
SELECT
	dc.ndocumento,
	dc.fecha,
	dc.numero,
	dc.debe,
	c.char_cta
FROM
	aq_datos dc,
	cuentas c
WHERE
	dc.id_cta=c.id_cta AND
	c.char_cta ~ '110535.';
	

DROP TABLE IF EXISTS doc_otros;
CREATE TEMP TABLE doc_otros AS
SELECT
	dc.ndocumento,
	dc.fecha,
	dc.numero,
	SUM(dc.debe) AS debe
FROM
	aq_datos dc,
	cuentas c
WHERE
	dc.id_cta=c.id_cta AND
	dc.debe!=0 AND
	(c.char_cta like '1110%' or
	c.char_cta like '2805%' or
	c.char_cta like '110540%' or --tarjetas wompi
	c.char_cta like '2380%' or
	c.char_cta like '11052%')
GROUP BY
	dc.fecha,
	dc.numero,
	dc.ndocumento;

DROP TABLE IF EXISTS doc_otros_credito;
CREATE TEMP TABLE doc_otros_credito AS
SELECT
	dc.ndocumento,
	dc.fecha,
	dc.numero,
	SUM(dc.debe) AS debe
FROM
	aq_datos dc,
	cuentas c
WHERE
	dc.id_cta=c.id_cta AND
	dc.debe!=0 AND
	(c.char_cta like '1305%')
GROUP BY
	dc.fecha,
	dc.numero,
	dc.ndocumento;

DROP TABLE IF EXISTS docs_ok;
CREATE TEMP TABLE docs_ok AS
SELECT
	COALESCE(COALESCE(dc.ndocumento,dt.ndocumento),dtc.ndocumento) as ndocumento,
	COALESCE(COALESCE(dc.fecha,dt.fecha),dtc.fecha) as fecha,
	COALESCE(COALESCE(dc.numero,dt.numero),dtc.numero) as numero,
	COALESCE(dc.debe,0) as caja,
	COALESCE(dt.debe, 0) as otros,
	COALESCE(dtc.debe, 0) as otros_credito
FROM
	doc_caja dc
FULL OUTER JOIN
	doc_otros dt
ON
	dc.ndocumento=dt.ndocumento
FULL OUTER JOIN
	doc_otros_credito dtc
ON
	dc.ndocumento=dtc.ndocumento;


SELECT
	ndocumento,
	fecha,
	numero,
	caja,
	otros,
	otros_credito,
	caja+otros+otros_credito as total
FROM
	docs_ok
ORDER BY
	fecha;