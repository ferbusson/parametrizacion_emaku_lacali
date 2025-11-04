-- LCUPD0030 Unico
DROP TABLE IF EXISTS aux_params_act;
CREATE TEMP TABLE aux_params_act AS
SELECT
	'?'::FLOAT8::INTEGER AS bandera,
	'?'::CHARACTER(2) AS codigo_tipo,
	LPAD('?',10,'0') AS numero;


-- bandera = 1: desbloquear facturacion electronica actualizando documentos a EE
UPDATE
	envio_webservice 
SET
	id_codigo_retorno_dian = 'EE'
FROM
	aux_params_act a
WHERE
	envio_webservice.id_codigo_retorno_dian NOT IN ('00','EE') AND
	a.bandera = 1; -- bandera: numero de boton: debe ser 1 para desbloquear

/* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

-- bandera = 2: re-establece documentos ED a su original (factura, devolucion electronica)

-- Valida que no se re-establezca un documento que haya presentado error pero que ya se haya generado de forma normal o se haya re-establecido antes
SELECT
	1
FROM
	(SELECT
		error_text('El documento: '||a.codigo_tipo||'-'||a.numero::BIGINT||' ya se generó o ya fue re-establecido a su original') AS message
	FROM
		aux_params_act a,
		(SELECT
			count(1) AS c
		FROM
			(SELECT 
				r.codigo_tipo,
				r.numero 
			FROM 
				registro_documentos_rechazados r
			EXCEPT
			SELECT
				d.codigo_tipo,
				d.numero
			FROM
				documentos d
				) AS foo) AS foo
	WHERE
		foo.c = 0 AND -- si el except no arroja resultados (0) significa que todos los documentos rechazados ya se generaron
		a.bandera = 2) AS foo;
		
--

UPDATE
	envio_webservice
SET
	id_codigo_retorno_dian = 'EE'
FROM
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	envio_webservice.ndocumento = d.ndocumento;

UPDATE
	libro_auxiliar
SET
	debe = la.debe,
	haber = la.haber
FROM
	libro_auxiliar_documentos_rechazados la,
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	d.ndocumento = la.ndocumento AND
	libro_auxiliar.ndocumento = la.ndocumento AND
	libro_auxiliar.orden = la.orden;

UPDATE
	libro_auxiliar_niifs
SET
	debe = la.debe,
	haber = la.haber
FROM
	libro_auxiliar_documentos_rechazados la,
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	d.ndocumento = la.ndocumento AND
	libro_auxiliar_niifs.ndocumento = la.ndocumento AND
	libro_auxiliar_niifs.orden = la.orden;

UPDATE
	inventarios
SET
	entrada = ia.entrada,
	salida = ia.salida
FROM
	inventarios_documentos_rechazados ia,
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	d.ndocumento = ia.ndocumento AND
	inventarios.ndocumento = ia.ndocumento AND
	inventarios.orden = ia.orden;

INSERT INTO
	cartera
SELECT
	c_aux.*
FROM
	cartera_documentos_rechazados c_aux,
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicia
	d.ndocumento = c_aux.nfactura;

INSERT INTO
	cartera
SELECT
	c_aux.*
FROM
	cartera_documentos_rechazados c_aux,
	aux_params_act a,
	documentos d
WHERE
	d.codigo_tipo = a.codigo_tipo AND
	d.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicia
	d.ndocumento = c_aux.ncomprobante;

UPDATE
	documentos
SET
	codigo_tipo = r.codigo_tipo,
	numero = r.numero,
	estado = TRUE
FROM
	aux_params_act a,
	registro_documentos_rechazados r
WHERE
	documentos.codigo_tipo = a.codigo_tipo AND
	documentos.numero = a.numero AND
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	documentos.ndocumento = r.ndocumento;
	
/* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

-- bandera = 3: arregla problema de salto de consecutivo

DROP TABLE IF EXISTS aux_docs_arreglar;
CREATE TEMP TABLE aux_docs_arreglar AS
SELECT
	d.codigo_tipo,
	d.numero,
	d.fecha,
	d.estado
FROM
	aux_params_act a,
	documentos d
WHERE
	a.bandera = 3 AND
	d.numero NOT IN ('0000000000') and
	d.ndocumento IN 
		(select
			ndocumento 
		FROM
			documentos 
		WHERE
			codigo_tipo in ('G4','Z4') -- esta query funciona en Unico
		EXCEPT
		SELECT
			ndocumento
		FROM
			envio_webservice);


--
insert into 
	envio_webservice (
		ndocumento,
		fecha,
		respuestaws,
		consecutivo_envio,
		id_codigo_retorno_dian) 
select 
	d.ndocumento,
	d.fecha,
	'<xml />',
	nextval('envio_webservice_consecutivo_envio_seq'),
	'EE' 
from 
	documentos d,
	aux_docs_arreglar a
where 
	d.codigo_tipo = a.codigo_tipo AND 
	d.numero = a.numero;


