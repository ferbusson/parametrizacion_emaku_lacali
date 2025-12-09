DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::VARCHAR(10) AS numero;

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



DROP TABLE IF EXISTS arqueos_diarios;
CREATE TEMP TABLE arqueos_diarios AS
SELECT
	da.ndocumento
FROM
	documentos d,
	args_arqueo_medios a,
	datos_arqueo da
WHERE
	d.codigo_tipo=a.codigo_tipo AND
	d.numero=LPAD(a.numero,10,'0') AND
	d.ndocumento=da.narqueo;



DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	l.*
FROM
	documentos d,
	libro_auxiliar l,
	arqueos_diarios a,
	tipo_docs t
WHERE
	a.ndocumento=d.ndocumento AND
	d.estado AND
	t.codigo_tipo=d.codigo_tipo AND
	l.ndocumento=d.ndocumento;

DROP TABLE IF EXISTS aux_tarjetas;
CREATE TEMP TABLE aux_tarjetas AS
SELECT
	COUNT(1) AS cant,
	SUM(COALESCE(t.valor,0)) as valor
FROM
	arqueos_diarios a,
	documentos d,
	tarjetas t,
	cuentas c
WHERE
	a.ndocumento = d.ndocumento AND
	d.estado AND
	d.ndocumento = t.ndocumento AND
	c.id_cta = t.id_cta AND
	c.char_cta NOT IN ('28050504'); -- En tarjetas tambien se inserta lo que son tarjetas regalo por eso se descartan porque tienen un campo aparte, ver mas abajo


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
		COALESCE(a.cant,0) AS cant,
		COALESCE(a.valor,0) AS valor
	FROM
		(SELECT
			2::INT as orden,
			'Tarjetas'::VARCHAR(50) as concepto) AS c
		LEFT OUTER JOIN
			aux_tarjetas AS a
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
					c.char_cta LIKE '1305%' -- Se pone LIKE para tener en cuenta todas las facturas incluidas plataformas web Feb 27 2021
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