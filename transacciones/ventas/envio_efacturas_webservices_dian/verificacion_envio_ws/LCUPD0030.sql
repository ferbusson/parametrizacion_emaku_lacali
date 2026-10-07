DROP TABLE IF EXISTS aux_params_act;
CREATE TEMP TABLE aux_params_act as
select
	foo.bandera,
	d.ndocumento,
	d.codigo_tipo,
	d.numero
from
	(select '?'::FLOAT8::INTEGER as bandera) AS foo
left join
	documentos d
on
	d.codigo_tipo = '?'
	and d.numero = LPAD('?',10,'0');


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
			select			
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
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	envio_webservice.ndocumento = a.ndocumento;

-- pone el documento en la lista para ser reenviado, con esto tratamos de solucionar el envio de documentos re establecidos
-- desde el formulario amarillo cuando se generan errores de consecutivo de documentos por errores que no son de la DIAN
-- por ejemplo error de partida doble Ago 11 2025 


UPDATE
	libro_auxiliar
SET
	debe = la.debe,
	haber = la.haber
FROM
	libro_auxiliar_documentos_rechazados la,
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	a.ndocumento = la.ndocumento AND
	libro_auxiliar.ndocumento = la.ndocumento AND
	libro_auxiliar.orden = la.orden;

UPDATE
	libro_auxiliar_niifs
SET
	debe = la.debe,
	haber = la.haber
FROM
	libro_auxiliar_documentos_rechazados la,
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	a.ndocumento = la.ndocumento AND
	libro_auxiliar_niifs.ndocumento = la.ndocumento AND
	libro_auxiliar_niifs.orden = la.orden;

UPDATE
	inventarios
SET
	entrada = ia.entrada,
	salida = ia.salida
FROM
	inventarios_documentos_rechazados ia,
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	a.ndocumento = ia.ndocumento AND
	inventarios.ndocumento = ia.ndocumento AND
	inventarios.orden = ia.orden;

INSERT INTO
	cartera
SELECT
	c_aux.*
FROM
	cartera_documentos_rechazados c_aux,
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicia
	a.ndocumento = c_aux.nfactura;

INSERT INTO
	cartera
SELECT
	c_aux.*
FROM
	cartera_documentos_rechazados c_aux,
	aux_params_act a
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicia
	a.ndocumento = c_aux.ncomprobante;


UPDATE
	documentos
SET
	codigo_tipo = r.codigo_tipo,
	numero = r.numero,
	estado = true
FROM
	aux_params_act a,
	registro_documentos_rechazados r
WHERE
	a.bandera = 2 AND -- bandera: numero de boton: debe ser 2 para re-establecer el documento rechazado a su estado inicial
	documentos.ndocumento = a.ndocumento and
	r.ndocumento = a.ndocumento;
	
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
	d.ndocumento IN (select
			ndocumento 
		FROM
			documentos 
		WHERE
			(codigo_tipo like 'Z%' or
			codigo_tipo like 'G%' or
			codigo_tipo like 'M%' or
			codigo_tipo like 'L%') 
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


