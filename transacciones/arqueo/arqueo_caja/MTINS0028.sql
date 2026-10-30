-- MTINS0028 — Inserta auto arqueo (optimizada)
--
-- Cambios vs original (ver MTINS0028.dbplan):
--   1. EXCEPT acotado por ndocumento > último arqueo Q del cajero, con
--      NOT EXISTS como anti-join (no por rama de EXCEPT) y safety-net
--      contra datos_arqueo para idempotencia.
--   2. ANALYZE después de cada CREATE TEMP TABLE (PG 9.5 asume 2040
--      filas sin stats).
--   3. Las 4 sumas (retiros, base_sencilla, devoluciones, documentos
--      efectivo) se consolidan en una sola pasada por `datos_arqueo`
--      del arqueo actual con FILTER + un segundo scan único sobre
--      libro_auxiliar para los movimientos contables.
--   4. INSERTs a libro_auxiliar: UNION → UNION ALL (ramas son
--      mutuamente excluyentes por char_cta y signo de diferencia).
--   5. Outer INSERT a datos_arqueo: eliminada la re-unión redundante a
--      documentos/info_documento después de resolver `foo`.

DROP TABLE IF EXISTS args_arqueo;
CREATE TEMP TABLE args_arqueo AS
SELECT
	d.codigo_tipo,
	f.narqueo,
	u.id_usuario,
	f.id_centrocosto,
	-- último arqueo Q del cajero ANTERIOR al que estamos cerrando;
	-- 0 si es su primer arqueo
	COALESCE((
		SELECT MAX(d2.ndocumento)
		FROM documentos d2
		JOIN info_documento i2 ON i2.ndocumento = d2.ndocumento
		WHERE d2.codigo_tipo LIKE 'Q%'
		  AND d2.estado
		  AND i2.id_usuario = u.id_usuario
		  AND d2.ndocumento < f.narqueo
	), 0::BIGINT) AS last_q_narqueo
FROM
	documentos d,
	usuarios u,
	(SELECT
		'?'::BIGINT AS narqueo,
		'?'::VARCHAR(70) AS login,
		'?'::SMALLINT AS id_centrocosto) AS f
WHERE
	u.login=f.login AND
	d.ndocumento=f.narqueo;
ANALYZE args_arqueo;

DROP TABLE IF EXISTS codigo_tipo_arqueos;
CREATE TEMP TABLE codigo_tipo_arqueos AS
SELECT DISTINCT
	td.codigo_tipo
FROM
	tipo_documento td
WHERE
	codigo_tipo LIKE 'Q%';
ANALYZE codigo_tipo_arqueos;

DROP TABLE IF EXISTS codigo_tipo_documentos_sucursal_usuario;
CREATE TEMP TABLE codigo_tipo_documentos_sucursal_usuario AS
SELECT DISTINCT
	ds.codigo_tipo
FROM
	args_arqueo a,
	documentos_standar dst,
	documentos_sucursales ds,
	administracion_sucursales asu
WHERE
	asu.id_centrocosto = a.id_centrocosto AND
	asu.id_administracion_sucursales = ds.id_administracion_sucursales AND
	ds.id_documento = dst.id_documento;
ANALYZE codigo_tipo_documentos_sucursal_usuario;

-- Documentos pendientes del turno = los del cajero en su sucursal, con
-- ndocumento en la ventana (last_q, narqueo_actual]. NOT EXISTS como
-- safety-net por si el INSERT se re-ejecuta.
/*INSERT INTO
	datos_arqueo(narqueo, ndocumento, valor)*/
SELECT
	a.narqueo,
	d.ndocumento,
	COALESCE(dd.valor, 0) AS valor
FROM
	args_arqueo a
	JOIN info_documento i ON i.id_usuario = a.id_usuario
	JOIN documentos d
		ON d.ndocumento = i.ndocumento
		AND d.ndocumento > a.last_q_narqueo
		AND d.ndocumento <= a.narqueo
		AND d.codigo_tipo != a.codigo_tipo
		AND d.estado
	JOIN codigo_tipo_documentos_sucursal_usuario ctu
		ON ctu.codigo_tipo = d.codigo_tipo
	JOIN datos_documento dd ON dd.ndocumento = d.ndocumento
WHERE
	-- Un documento se considera ya arqueado SÓLO si su fila en
	-- datos_arqueo apunta a un Q activo. Si el Q padre fue anulado
	-- (documentos.estado=false) la fila de datos_arqueo persiste pero
	-- el documento debe volver a entrar a un arqueo nuevo.
	NOT EXISTS (
		SELECT 1
		FROM datos_arqueo da
		JOIN documentos qd ON qd.ndocumento = da.narqueo
		WHERE da.ndocumento = d.ndocumento
		  AND qd.estado
	);

-- =========================================================
-- Contabilización del arqueo
-- =========================================================

-- Una sola pasada por los documentos del arqueo para calcular las 3
-- sumas que dependen de datos_documento (retiros, base_sencilla).
DROP TABLE IF EXISTS sumas_datos_documento;
CREATE TEMP TABLE sumas_datos_documento AS
SELECT
	COALESCE(SUM(dd.valor) FILTER (WHERE dst.nombre = 'RETIRO PARCIAL'), 0)        AS retiros_parciales,
	COALESCE(SUM(dd.valor) FILTER (WHERE dst.nombre = 'ENTREGA BASE SENCILLA'), 0) AS base_sencilla
FROM
	args_arqueo a
	JOIN datos_arqueo da          ON da.narqueo    = a.narqueo
	JOIN documentos d             ON d.ndocumento  = da.ndocumento
	JOIN datos_documento dd       ON dd.ndocumento = d.ndocumento
	JOIN documentos_sucursales ds ON ds.codigo_tipo = d.codigo_tipo
	JOIN documentos_standar dst   ON dst.id_documento = ds.id_documento;
ANALYZE sumas_datos_documento;

-- Sumas que dependen de libro_auxiliar: devoluciones (haber) y
-- documentos efectivo (debe), ambas sobre char_cta='11053501'.
DROP TABLE IF EXISTS sumas_libro;
CREATE TEMP TABLE sumas_libro AS
SELECT
	COALESCE(SUM(l.haber) FILTER (
		WHERE dst.nombre IN ('DEVOLUCION VENTA','DVENTA ELECTRONICA')
	), 0) AS devoluciones_venta,
	COALESCE(SUM(l.debe) FILTER (WHERE l.debe != 0), 0) AS documentos_efectivo_bruto
FROM
	args_arqueo a
	JOIN datos_arqueo da          ON da.narqueo = a.narqueo
	JOIN libro_auxiliar l         ON l.ndocumento = da.ndocumento
	JOIN datos_documento dd       ON dd.ndocumento = da.ndocumento -- excluye no-POS
	JOIN cuentas cu               ON cu.id_cta = l.id_cta AND cu.char_cta = '11053501'
	LEFT JOIN documentos d        ON d.ndocumento = da.ndocumento
	LEFT JOIN documentos_sucursales ds ON ds.codigo_tipo = d.codigo_tipo
	LEFT JOIN documentos_standar dst   ON dst.id_documento = ds.id_documento;
ANALYZE sumas_libro;

DROP TABLE IF EXISTS efectivo_entregado;
CREATE TEMP TABLE efectivo_entregado AS
SELECT
	e."100000"+e."50000"+e."20000"+e."10000"+e."5000"+e."2000"+e."1000"+e.monedas+
	((e."100"+e."50"+e."20"+e."10"+e."5"+e."1"+e.monedasd)*e.trm) AS valor
FROM
	args_arqueo a,
	efectivo e
WHERE
	a.narqueo = e.narqueo;
ANALYZE efectivo_entregado;

DROP TABLE IF EXISTS unificacion_totales;
CREATE TEMP TABLE unificacion_totales AS
SELECT
	COALESCE(sl.documentos_efectivo_bruto - sl.devoluciones_venta - sdd.retiros_parciales, 0.0) AS documentos_en_efectivo,
	COALESCE(sdd.base_sencilla, 0.0)      AS sencilla,
	COALESCE(sdd.retiros_parciales, 0.0)  AS recogida,
	COALESCE((sl.documentos_efectivo_bruto - sl.devoluciones_venta - sdd.retiros_parciales) + sdd.base_sencilla, 0.0) AS total_registrado,
	COALESCE(ee.valor, 0.0)               AS efectivo_entregado,
	COALESCE(ee.valor - ((sl.documentos_efectivo_bruto - sl.devoluciones_venta - sdd.retiros_parciales) + sdd.base_sencilla), 0) AS diferencia
FROM
	sumas_datos_documento sdd,
	sumas_libro sl,
	efectivo_entregado ee;
ANALYZE unificacion_totales;

-- CONTRAPARTIDA ENTREGA BASE SENCILLA
/*INSERT INTO
	libro_auxiliar(id_cta, id_centrocosto, id_tercero, fecha, detalle, ndocumento, debe, haber)*/
SELECT
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'CONTRAPARTIDA ENTREGA BASE SENCILLA' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN s.sencilla > 0 THEN s.sencilla ELSE 0 END AS debe,
	CASE WHEN s.sencilla < 0 THEN -1*s.sencilla ELSE 0 END AS haber
FROM args_arqueo a, cuentas cu, unificacion_totales s
WHERE cu.char_cta = '11051502' AND s.sencilla != 0
UNION ALL
SELECT
	cu.id_cta,
	a.id_centrocosto,
	a.id_usuario,
	CURRENT_TIMESTAMP AS fecha,
	'CONTRAPARTIDA ENTREGA BASE SENCILLA' AS detalle,
	a.narqueo AS ndocumento,
	CASE WHEN s.sencilla < 0 THEN -1*s.sencilla ELSE 0 END AS debe,
	CASE WHEN s.sencilla > 0 THEN s.sencilla ELSE 0 END AS haber
FROM args_arqueo a, cuentas cu, unificacion_totales s
WHERE cu.char_cta = '11051501' AND s.sencilla != 0;

-- TRANSFERENCIA EFECTIVO + sobrantes/faltantes
/*INSERT INTO
	libro_auxiliar(id_cta, id_centrocosto, id_tercero, fecha, detalle, ndocumento, debe, haber)*/
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'TRANSFERENCIA EFECTIVO A TESORERIA', a.narqueo,
	CASE WHEN ut.documentos_en_efectivo < 0 THEN -1*ut.documentos_en_efectivo ELSE 0 END,
	CASE WHEN ut.documentos_en_efectivo > 0 THEN ut.documentos_en_efectivo ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053501'
UNION ALL
-- arqueo cuadrado exacto
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'TRANSFERENCIA EFECTIVO A TESORERIA', a.narqueo,
	CASE WHEN ut.documentos_en_efectivo > 0 THEN ut.documentos_en_efectivo ELSE 0 END,
	CASE WHEN ut.documentos_en_efectivo < 0 THEN -1*ut.documentos_en_efectivo ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia = 0
UNION ALL
-- registro sobrante (ingresos no operacionales)
SELECT
	cu.id_cta, a.id_centrocosto, g.id, CURRENT_TIMESTAMP,
	'REGISTRO SOBRANTE', a.narqueo,
	CASE WHEN ut.diferencia < 0 THEN -1*ut.diferencia ELSE 0.0 END,
	CASE WHEN ut.diferencia > 0 THEN ut.diferencia ELSE 0.0 END
FROM args_arqueo a, cuentas cu, general g, unificacion_totales ut
WHERE g.id_char = '222222222222' AND cu.char_cta = '429553' AND ut.diferencia > 0
UNION ALL
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO SOBRANTE', a.narqueo,
	CASE WHEN (ut.diferencia + ut.documentos_en_efectivo) > 0 THEN ut.diferencia + ut.documentos_en_efectivo ELSE 0 END,
	CASE WHEN (ut.diferencia + ut.documentos_en_efectivo) < 0 THEN -1*(ut.diferencia + ut.documentos_en_efectivo) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia > 0
UNION ALL
-- faltante > 100 pesos
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE SUPERIOR A 100', a.narqueo,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) > 0 THEN ut.documentos_en_efectivo + ut.diferencia ELSE 0 END,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) < 0 THEN -1*(ut.documentos_en_efectivo + ut.diferencia) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia*-1 > 100 AND ut.total_registrado + ut.diferencia != 0
UNION ALL
-- faltante > 100 cuando total_registrado + diferencia = 0 (caso especial)
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE SUPERIOR A 100', a.narqueo,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) > 0 THEN ut.documentos_en_efectivo + ut.diferencia ELSE 0 END,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) < 0 THEN -1*(ut.documentos_en_efectivo + ut.diferencia) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia*-1 > 100 AND ut.total_registrado + ut.diferencia = 0
UNION ALL
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE SUPERIOR A 100', a.narqueo,
	CASE WHEN (ut.diferencia*-1) > 0 THEN ut.diferencia*-1 ELSE 0 END,
	CASE WHEN (ut.diferencia*-1) < 0 THEN -1*(ut.diferencia*-1) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '13653001' AND ut.diferencia*-1 > 100
UNION ALL
-- faltante inferior a 100
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE INFERIOR A 100', a.narqueo,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) > 0 THEN ut.documentos_en_efectivo + ut.diferencia ELSE 0 END,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) < 0 THEN -1*(ut.documentos_en_efectivo + ut.diferencia) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia*-1 > 0 AND ut.diferencia*-1 <= 100
  AND ut.total_registrado + ut.diferencia != 0
UNION ALL
SELECT
	cu.id_cta, a.id_centrocosto, a.id_usuario, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE INFERIOR A 100', a.narqueo,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) > 0 THEN ut.documentos_en_efectivo + ut.diferencia ELSE 0 END,
	CASE WHEN (ut.documentos_en_efectivo + ut.diferencia) < 0 THEN -1*(ut.documentos_en_efectivo + ut.diferencia) ELSE 0 END
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '11053502' AND ut.diferencia*-1 > 0 AND ut.diferencia*-1 <= 100
  AND ut.total_registrado + ut.diferencia = 0
UNION ALL
SELECT
	cu.id_cta, a.id_centrocosto, g.id, CURRENT_TIMESTAMP,
	'REGISTRO FALTANTE INFERIOR A 100', a.narqueo,
	CASE WHEN (ut.diferencia*-1) > 0 THEN ut.diferencia*-1 ELSE 0 END,
	CASE WHEN (ut.diferencia*-1) < 0 THEN -1*(ut.diferencia*-1) ELSE 0 END
FROM args_arqueo a, cuentas cu, general g, unificacion_totales ut
WHERE g.id_char = '222222222222' AND cu.char_cta = '539581'
  AND ut.diferencia*-1 > 0 AND ut.diferencia*-1 <= 100;

-- Faltantes >100 → cartera del cajero
/*INSERT INTO
	cartera(idtercero, nfactura, dcredito, neto_factura, total_factura, movimiento, id_cta)*/
SELECT
	a.id_usuario,
	a.narqueo,
	0::INTEGER,
	ut.diferencia*-1,
	ut.diferencia*-1,
	TRUE,
	cu.id_cta
FROM args_arqueo a, cuentas cu, unificacion_totales ut
WHERE cu.char_cta = '13653001' AND ut.diferencia*-1 > 100;
