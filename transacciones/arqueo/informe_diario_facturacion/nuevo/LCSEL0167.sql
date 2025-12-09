-- Feb 4 2025 se presento problema con factura pagada con consignacion y tarjeta
-- se soluciona haciendo el cruce correcto del id_cta de la tabla consignaciones 
-- con el libro_auxiliar

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::DATE AS fecha;

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

DROP TABLE IF EXISTS aux_docs;
CREATE TEMP TABLE aux_docs AS
select
	d.ndocumento
from
	args_arqueo_medios a,
	tipo_docs t,
	documentos d
WHERE
	--d.ndocumento = 1644518 and
	d.fecha::date = a.fecha and
	d.codigo_tipo = t.codigo_tipo ; -- Solo tipos documento fac, fac credito y cambios


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

DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	l.*
FROM
	libro_auxiliar l,	
	arqueo_except ae
WHERE
	l.ndocumento=ae.ndocumento;

DROP TABLE IF EXISTS aux_tarjetas;
CREATE TEMP TABLE aux_tarjetas AS
SELECT
	t.ndocumento,
	SUM(t.valor) AS valor
FROM
	tarjetas t,	
	arqueo_except ae,
	cuentas c
WHERE
	t.ndocumento=ae.ndocumento AND
	t.id_cta = c.id_cta AND
	c.char_cta NOT IN ('28050504')	-- no se incluyen tarjetas regalo porque tienen seccion aparte mas abajo
GROUP BY
	t.ndocumento;


SELECT
	concepto,
	cant,
	valor
FROM
	(SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			1::INT as orden,
			'Efectivo'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta ='11053501'
				GROUP BY 
					ndocumento)AS d) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			2::INT as orden,
			'Tarjetas'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					t.ndocumento,
					t.valor
				FROM
					aux_tarjetas t) AS d) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			3::INT as orden,
			'Tarjetas Regalo'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta ='28050504'
				GROUP BY 
					ndocumento
				HAVING 
					sum(debe)!=0)AS d) AS f
	ON
		true
	UNION
	SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			4::INT as orden,
			'Cheques Sodexo Pass'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta ='11052001'
				GROUP BY 
					ndocumento)AS d) AS f
	ON
		true
	UNION
		SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			5::INT as orden,
			'Cheques Big Pass'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta ='11052501'
				GROUP BY 
					ndocumento)AS d) AS f
	ON
		true
	UNION
		SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			6::INT as orden,
			'Facturas Credito'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta LIKE '1305%' -- Se pone like para que tenga en cuenta todas las facturas incluidas plataformas web Feb 27 2021
					--c.char_cta in ('130505','130506')
				GROUP BY 
					ndocumento)AS d) AS f
	ON
		true
		UNION
		SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			7::INT as orden,
			'Anticipos Facturados'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					ndocumento,
					sum(debe) AS valor
				FROM
					aux_medios a,
					cuentas c
				WHERE
					c.id_cta=a.id_cta AND
					c.char_cta in ('28050502')
				GROUP BY 
					ndocumento)AS d) AS f
	ON
		true
	UNION
		SELECT
		orden,
		concepto,
		COALESCE(cant,0) AS cant,
		COALESCE(valor,0) AS valor
	FROM
		(SELECT
			8::INT as orden,
			'Consignaciones'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			(SELECT
				count(1) AS cant, 
				SUM(valor) AS valor
			FROM
				(SELECT
					a.ndocumento,
					sum(con.valor) AS valor
				FROM
					(select distinct ndocumento from aux_medios) a,
					consignaciones con,
					cuentas c
				WHERE
					a.ndocumento = con.ndocumento and
					c.id_cta=con.id_cta and
					/*con.id_cta=a.id_cta and Junio 28 2025: quito el cruce aux_medios por cuenta valor y documento
					con.valor = a.debe and*/
					(c.char_cta like ('1110%') or
					c.char_cta like ('110540%') or
					c.char_cta like ('1120%'))
				GROUP BY 
					a.ndocumento)AS d) AS f
	ON
		true) AS f
ORDER BY
	orden;