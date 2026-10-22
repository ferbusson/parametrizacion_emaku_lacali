DROP TABLE IF EXISTS aux_params_importacion;
CREATE TEMP TABLE aux_params_importacion AS
SELECT
	'?'::INTEGER AS id_grupo,
	'?'::CHARACTER(50) AS descripcion,
	'?'::BOOLEAN AS naturaleza,
	'?'::INTEGER AS id_cta,
	'?'::INTEGER AS id_concepto_importacion,
	'?'::INTEGER AS id_asiento_generico,
	'?'::INTEGER AS id_cta_retencion,
    '?'::VARCHAR(14) AS codigo,
    '?'::SMALLINT AS id_categoria_costo;
	
UPDATE
	conceptos_importacion
SET
	id_cta = a.id_cta,
	naturaleza = a.naturaleza,
	id_asiento_generico = a.id_asiento_generico,
	id_cta_retencion = a.id_cta_retencion,
    id_categoria_costo = CASE WHEN a.id_categoria_costo = 0 THEN NULL ELSE a.id_categoria_costo END
FROM
	aux_params_importacion a
WHERE
	conceptos_importacion.id_concepto_importacion = a.id_concepto_importacion;
    
UPDATE
    item
SET
    nombre = a.descripcion
FROM
    aux_params_importacion a,
    conceptos_importacion ci,
    prod_serv ps
WHERE
    a.id_concepto_importacion = ci.id_concepto_importacion AND
    ci.id_prod_serv = ps.id_prod_serv AND
    item.id_item = ps.id_item;
    
UPDATE
    prod_serv AS ps
SET
    codigo = a.codigo,
    id_asiento_generico = ci.id_asiento_generico,
    iva = ag.tarifa
FROM
    conceptos_importacion ci,
    aux_params_importacion a,
    asientos_genericos ag
WHERE
    ci.id_concepto_importacion = a.id_concepto_importacion AND
    ps.id_prod_serv = ci.id_prod_serv AND
    ci.id_asiento_generico = ag.id_asiento_generico;

INSERT INTO
	aux_act_conceptos_imp(
	id_grupo,
	descripcion,
	naturaleza,
	id_cta,
	id_concepto_importacion,
	id_asiento_generico,
	id_cta_retencion)
SELECT
	id_grupo,
	descripcion,
	naturaleza,
	id_cta,
	id_concepto_importacion,
	id_asiento_generico,
	id_cta_retencion
FROM
	aux_params_importacion;