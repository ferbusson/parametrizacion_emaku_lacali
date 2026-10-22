DROP TABLE IF EXISTS aux_parametros_query;
CREATE TEMP TABLE aux_parametros_query AS
SELECT 
	'?'::VARCHAR AS id_char,
	'?'::VARCHAR AS id_centrocosto,
	'?'::VARCHAR AS id_grupo;

DROP TABLE IF EXISTS error_msg_proveedor;
CREATE TEMP TABLE error_msg_proveedor AS
SELECT 
	1
FROM
	(SELECT
		error_text('Antes de iniciar, seleccione el tercero por favor')
	FROM
		aux_parametros_query
	WHERE
		TRIM(id_char) = '') AS foo;

--

DROP TABLE IF EXISTS aux_cuentas_retencion;
CREATE TEMP TABLE aux_cuentas_retencion AS
SELECT
	ci.id_concepto_importacion,
	ci.id_cta_retencion,
	pc.base,
	pc.porcentaje,
	cr.id_regimen,
	cu.char_cta AS char_cta_retencion
FROM
	conceptos_importacion ci,
	aux_parametros_query a,
	general g,
	perfil_tercero pt,
	cuentas_regimen cr,
	perfil_cta pc,
	cuentas cu
WHERE
	g.id_char = a.id_char AND
	g.id = pt.id AND
	cr.id_regimen=pt.id_regimen AND
	cr.codigo_tipo='GI' AND
	cr.id_cta=pc.id_cta AND
	ci.id_cta_retencion = pc.id_cta AND
	ci.id_cta_retencion = cu.id_cta AND
	ci.id_grupo::VARCHAR = a.id_grupo;
--

SELECT
	TRIM(ps.codigo) AS codigo,
	i.nombre,
	0.0 AS valor_pesos,
	0.0 AS valor_usd,
	ps.iva,
	0.0 AS valor_iva,
	0.0 AS subtotal,
	COALESCE(acr.base,0.0) AS base,
	COALESCE(acr.porcentaje,0.0) porcentaje,
	0.0 AS total_retencion,
	a.id_centrocosto,
	g.id AS id_tercero,
	ci.id_cta,
	COALESCE(acr.char_cta_retencion,'23652502') AS char_cta_retencion,
	ci.id_grupo,
	ps.id_prod_serv,
	1 AS cantidad,
	0 AS pdescuento,
	0 AS descuento,
	ci.id_concepto_importacion,
	COALESCE(acr.id_cta_retencion,-1) AS id_cta_retencion
FROM	
	general g,
	aux_parametros_query a,
	cuentas cu,
	prod_serv ps,
    item i,
	conceptos_importacion ci
LEFT OUTER JOIN
	aux_cuentas_retencion acr
ON
	ci.id_concepto_importacion = acr.id_concepto_importacion
WHERE
	ci.id_grupo::VARCHAR = a.id_grupo AND
	a.id_char = g.id_char AND
	ci.naturaleza AND
	ci.id_cta = cu.id_cta AND
	ci.id_prod_serv = ps.id_prod_serv AND
    ps.id_item = i.id_item 
ORDER BY
	ci.id_concepto_importacion;