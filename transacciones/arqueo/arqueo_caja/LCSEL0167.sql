-- LCSEL0167 — Medios de pago del arqueo por almacén (resumen)
--
-- Para los documentos del día que todavía no fueron incluidos en un arqueo
-- activo del codigo_tipo input, resume por medio de pago (efectivo, tarjetas,
-- tarjetas regalo, Sodexo, BigPass, facturas crédito, anticipos, consignaciones)
-- la cantidad de operaciones y el valor total. Usada en el formulario MTR00238.
--
-- Hermana estructural de LCSEL0166 — mismo pipeline (args + tipo_docs +
-- aux_docs + arqueo_except + aux_medios) con una temp table extra
-- `aux_tarjetas` y 8 ramas UNION finales.
--
-- Optimización 2026-10-28 — Phase 1 (tres cambios, semántica idéntica):
--
--   A) `d.fecha::date = a.fecha` -> rango de timestamp en aux_docs.
--
--   B) `ANALYZE <temp_table>` después de cada CREATE TEMP TABLE
--      (ver [[feedback-analyze-temp-tables]]).
--
--   C) `arqueo_except` EXCEPT -> `(SELECT 1 ... LIMIT 1) IS NULL` escalar
--      (patrón de LCSEL0177, dev 7.5x más rápido).
--
-- Las 8 ramas UNION finales quedan intactas (Phase 2 cleanup si fuera
-- necesario).
--
-- Compatible con PG 9.5.

-- Feb 4 2025 se presento problema con factura pagada con consignacion y tarjeta
-- se soluciona haciendo el cruce correcto del id_cta de la tabla consignaciones
-- con el libro_auxiliar

DROP TABLE IF EXISTS args_arqueo_medios;
CREATE TEMP TABLE args_arqueo_medios AS
SELECT
	'?'::VARCHAR(2) AS codigo_tipo,
	'?'::DATE AS fecha;
ANALYZE args_arqueo_medios;

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
ANALYZE tipo_docs;

-- Phase 1 (2026-10-28): fecha::date = a.fecha -> rango timestamp.
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
	d.fecha >= a.fecha::timestamp AND
	d.fecha <  a.fecha::timestamp + INTERVAL '1 day' AND
	d.codigo_tipo = t.codigo_tipo ; -- Solo tipos documento fac, fac credito y cambios
ANALYZE aux_docs;


-- Phase 1 (2026-10-28): EXCEPT -> subquery escalar con LIMIT 1.
DROP TABLE IF EXISTS arqueo_except;
CREATE TEMP TABLE arqueo_except AS
SELECT DISTINCT ad.ndocumento
FROM   aux_docs ad
WHERE  (SELECT 1
          FROM datos_arqueo       da
          JOIN documentos         d  ON d.ndocumento = da.narqueo AND d.estado
          JOIN args_arqueo_medios a  ON a.codigo_tipo = d.codigo_tipo
         WHERE da.ndocumento = ad.ndocumento
         LIMIT 1) IS NULL;
ANALYZE arqueo_except;

DROP TABLE IF EXISTS aux_medios;
CREATE TEMP TABLE aux_medios AS
SELECT
	l.*
FROM
	libro_auxiliar l,
	arqueo_except ae
WHERE
	l.ndocumento=ae.ndocumento;
ANALYZE aux_medios;

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
ANALYZE aux_tarjetas;


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
					c.char_cta IN ('28050503','28050504')
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
			'Cheques Pluxee'::VARCHAR(50) as concepto) AS c
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