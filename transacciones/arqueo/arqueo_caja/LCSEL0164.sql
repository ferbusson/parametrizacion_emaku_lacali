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
	documentos d,
	tipo_arqueo ta
WHERE
	d.codigo_tipo = ta.codigo_tipo AND
	da.narqueo = d.ndocumento and
	d.estado;

DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	COALESCE(da.narqueo,0) AS narqueo,
	d.ndocumento
from
	args_arqueo_medios a,
	tipo_docs t,
	documentos d
LEFT OUTER JOIN
	datos_arqueo_ok as da
on
	d.ndocumento = da.ndocumento
WHERE
	d.estado and
	d.fecha::date = a.fecha and
	d.codigo_tipo = t.codigo_tipo ; -- Solo tipos documento fac, fac credito y cambios

DROP TABLE IF EXISTS aux_docs_ok;
CREATE TEMP TABLE aux_docs_ok AS
select
	da.narqueo as narqueo_informe,
	a.narqueo as narqueo,
	a.ndocumento
from
	aux_docs a
LEFT OUTER JOIN
	datos_arqueo_ok da
ON
	a.narqueo = da.ndocumento;

	
DROP TABLE IF EXISTS arqueo_error;
CREATE TEMP TABLE arqueo_error AS
SELECT
	1
FROM
	(SELECT
		error_text('Existen documentos del usuario: /'||u.login||'/ sin arquear')
	FROM
		documentos d,
		info_documento i,
		usuarios u,
		aux_docs_ok a
	where
		d.ndocumento = a.ndocumento and
		d.ndocumento = i.ndocumento and
		i.id_usuario = u.id_usuario AND
		a.narqueo=0) AS f;
	

DROP TABLE IF EXISTS arqueo_except;
CREATE TEMP TABLE arqueo_except AS
SELECT distinct
	ad.narqueo_informe,
	ad.narqueo,
	ad.ndocumento
FROM
	aux_docs_ok ad
EXCEPT
SELECT DISTINCT
	da.narqueo as narqueo_informe,
	da2.narqueo,
	da2.ndocumento
FROM
	datos_arqueo da,
	datos_arqueo da2,
	documentos d,
	args_arqueo_medios a
WHERE
	d.codigo_tipo=a.codigo_tipo AND
	da.narqueo=d.ndocumento AND
	da.ndocumento = da2.narqueo and
	d.estado;

DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	rf.prefijo,
	d.*
FROM
	documentos d,
	arqueo_except ae,
	resolucion_facturacion rf,
	resolucion_documento rd
WHERE
	rd.ndocumento=d.ndocumento AND
	rd.id_resolucion_facturacion=rf.id_resolucion_facturacion AND	
	d.ndocumento=ae.ndocumento AND
	d.estado;


DROP TABLE IF EXISTS arqueo_error;
CREATE TEMP TABLE arqueo_error AS
SELECT
	1
FROM
	(SELECT
		error_text('No existen arqueos pendientes para generar informe diario en esta fecha'),
		count(1)
	FROM
		aux_medios
	HAVING
		count(1)=0) AS f;
	
DROP TABLE IF EXISTS aux_f;
CREATE TEMP TABLE aux_f AS
SELECT
	a.prefijo fprefijo,
	a.codigo_tipo,
	min(a.numero) AS fdesde,
	max(a.numero) as fhasta,
	count(1) as fdocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'FACTURACION'
GROUP BY
	a.prefijo,
	a.codigo_tipo;

DROP TABLE IF EXISTS aux_g;
CREATE TEMP TABLE aux_g AS
SELECT
	a.prefijo as gprefijo,
	a.codigo_tipo,
	min(a.numero) AS gdesde,
	max(a.numero) as ghasta,
	count(1) as gdocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'FCREDITO'
GROUP BY
	a.prefijo,
	a.codigo_tipo;

DROP TABLE IF EXISTS aux_c;
CREATE TEMP TABLE aux_c AS
SELECT
	a.prefijo AS cprefijo,
	a.codigo_tipo,
	min(a.numero) AS cdesde,
	max(a.numero) as chasta,
	count(1) as cdocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'CAMBIOS'
GROUP BY
	a.prefijo,
	a.codigo_tipo;

DROP TABLE IF EXISTS aux_z;
CREATE TEMP TABLE aux_z AS
SELECT
	a.prefijo AS zprefijo,
	a.codigo_tipo,
	min(a.numero) AS zdesde,
	max(a.numero) as zhasta,
	count(1) as zdocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'FELECTRONICAPOS'
GROUP BY
	a.prefijo,
	a.codigo_tipo;

DROP TABLE IF EXISTS aux_u;
CREATE TEMP TABLE aux_u AS
SELECT
	a.prefijo AS uprefijo,
	a.codigo_tipo,
	min(a.numero) AS udesde,
	max(a.numero) as uhasta,
	count(1) as udocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'FCONTINGENCIA'
GROUP BY
	a.prefijo,
	a.codigo_tipo;

DROP TABLE IF EXISTS aux_p;
CREATE TEMP TABLE aux_p AS
SELECT
	a.prefijo AS pprefijo,
	a.codigo_tipo,
	min(a.numero) AS pdesde,
	max(a.numero) as phasta,
	count(1) as pdocs
FROM
	aux_medios a,
	documentos_standar dst,
	documentos_sucursales ds
WHERE
	dst.id_documento = ds.id_documento and
	ds.codigo_tipo = a.codigo_tipo and
	dst.nombre = 'FCONTINGENCIAE'
GROUP BY
	a.prefijo,
	a.codigo_tipo;


SELECT
	COALESCE(fprefijo||'-'||fdesde::BIGINT,'-') AS fdesde,
	COALESCE(fprefijo||'-'||fhasta::BIGINT,'-') AS fhasta,
	COALESCE(fdocs,0) AS fdocs,
	COALESCE(cprefijo||'-'||cdesde::BIGINT,'-') AS cdesde,
	COALESCE(cprefijo||'-'||chasta::BIGINT,'-') AS chasta,
	COALESCE(cdocs,0) AS cdocs,
	COALESCE(gprefijo||'-'||gdesde::BIGINT,'-') AS gdesde,
	COALESCE(gprefijo||'-'||ghasta::BIGINT,'-') AS ghasta,
	COALESCE(gdocs,0) AS gdocs,
	COALESCE(zprefijo||'-'||zdesde::BIGINT,'-') AS zdesde,
	COALESCE(zprefijo||'-'||zhasta::BIGINT,'-') AS zhasta,
	COALESCE(zdocs,0) AS zdocs,
	COALESCE(uprefijo||'-'||udesde::BIGINT,'-') AS udesde,
	COALESCE(uprefijo||'-'||uhasta::BIGINT,'-') AS uhasta,
	COALESCE(udocs,0) AS udocs,
	COALESCE(pprefijo||'-'||pdesde::BIGINT,'-') AS pdesde,
	COALESCE(pprefijo||'-'||phasta::BIGINT,'-') AS phasta,
	COALESCE(pdocs,0) AS pdocs
FROM
	aux_f
FULL OUTER JOIN
	aux_g
ON
	TRUE
FULL OUTER JOIN
	aux_c
ON 	
	TRUE
FULL OUTER JOIN
	aux_z
ON 	
	TRUE
FULL OUTER JOIN
	aux_u
ON 	
	TRUE
FULL OUTER JOIN
	aux_p
ON 	
	TRUE;