DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::DATE AS fecha;

DROP TABLE IF EXISTS tipo_arqueo;
CREATE TEMP TABLE tipo_arqueo AS
SELECT
	dv.codigo_tipo
FROM
	documentos_standar ds,
	administracion_sucursales ad,
	documentos_sucursales du,
	documentos_sucursales dv,
	args_arqueo_medios a
WHERE
	ds.id_documento=dv.id_documento AND
	dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
	ad.id_administracion_sucursales=du.id_administracion_sucursales AND
	du.codigo_tipo=a.codigo_tipo AND
	ds.nombre IN ('ARQUEO');

DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT
	dv.codigo_tipo
FROM
	documentos_standar ds,
	administracion_sucursales ad,
	documentos_sucursales du,
	documentos_sucursales dv,
	args_arqueo_medios a
WHERE
	ds.id_documento=dv.id_documento AND
	dv.id_administracion_sucursales=ad.id_administracion_sucursales AND
	ad.id_administracion_sucursales=du.id_administracion_sucursales AND
	du.codigo_tipo=a.codigo_tipo AND
	ds.nombre IN ('FACTURACION','FCREDITO','CAMBIOS','FELECTRONICAPOS','FCONTINGENCIA','FCONTINGENCIAE');

DROP TABLE IF EXISTS datos_arqueo_ok;
CREATE TEMP TABLE datos_arqueo_ok AS
select
	da.narqueo,
	da.ndocumento
FROM
	datos_arqueo da,
	documentos d
WHERE
	da.narqueo = d.ndocumento and
	d.estado;

DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	COALESCE(da.narqueo,0) AS narqueo,
	da.ndocumento
from
	args_arqueo_medios a,
	tipo_arqueo t,
	tipo_docs td,
	datos_arqueo_ok da,
	documentos d, -- documento arqueo
	documentos d2 -- documentos del arqueo
WHERE
	d.estado and
	d.fecha::date = a.fecha and
	d.codigo_tipo = t.codigo_tipo AND
	d.ndocumento = da.narqueo AND
	da.ndocumento = d2.ndocumento AND
	d2.codigo_tipo = td.codigo_tipo; -- Solo tipos documento fac, fac credito y cambios



DROP TABLE IF EXISTS arqueo_except;
CREATE TEMP TABLE arqueo_except AS
SELECT distinct
	ad.ndocumento
FROM
	aux_docs ad
EXCEPT
SELECT DISTINCT
	da.ndocumento
FROM
	datos_arqueo da,
	documentos d,
	args_arqueo_medios a
WHERE
	d.codigo_tipo=a.codigo_tipo AND
	da.narqueo=d.ndocumento AND
	d.estado;


SELECT DISTINCT
	d.fecha,
	d.codigo_tipo||'-'||d.numero::int AS numero,
	u.login,
	nombre1||' '||apellido1 as usuario,
	da.narqueo
FROM
	usuarios u,
	info_documento i,
	general g,
	documentos d,
	tipo_arqueo ta,
	arqueo_except foo,
	datos_arqueo da
WHERE
	da.ndocumento = foo.ndocumento AND
	da.narqueo = i.ndocumento AND
	i.id_usuario = u.id_usuario AND
	g.id = u.id_usuario AND
	d.ndocumento = da.narqueo AND
	d.codigo_tipo = ta.codigo_tipo
ORDER BY
	d.fecha,
	numero;