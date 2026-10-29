-- MTSEL0267 — Consulta valor venta tarjeta crédito para arqueo
--
-- Suma `tarjetas.valor` para los documentos del cajero actual con
-- `tcredito.tipo = 'CR'` (crédito) que no estén aún en un arqueo activo.
--
-- Gemela de MTSEL0268 (débito) — misma estructura, filtro invertido.
-- En producción esta era la más lenta del grupo A (~74.5s) y causaba un
-- halt nocturno en el cierre de arqueo (formulario DGTR00082).
--
-- Ver [[project-mtsel0268-optim]] para el análisis del patrón.

DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT '?'::VARCHAR(70) AS login;

DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT
	ds.codigo_tipo
FROM
	documentos_standar dst,
	asignacion_usuario_sucursal au, 
	documentos_sucursales ds,
	tmp_usuario t,
	usuarios u
WHERE
	t.login = u.login AND
	u.id_usuario = au.id AND
	dst.id_documento=ds.id_documento AND
	au.id_administracion_sucursales=ds.id_administracion_sucursales;

WITH user_docs AS (
    SELECT t.ndocumento, t.valor
    FROM   tarjetas         t
    JOIN   tcredito         tc ON tc.id_tcredito = t.id_tcredito AND tc.tipo = 'CR'    
    JOIN   documentos       d  ON d.ndocumento   = t.ndocumento
                              AND d.estado
                              AND d.fecha        >= CURRENT_DATE - INTERVAL '7 days'
    join tipo_docs td on td.codigo_tipo = d.codigo_tipo
    JOIN   info_documento   i  ON i.ndocumento   = t.ndocumento
    JOIN   usuarios         u  ON u.id_usuario   = i.id_usuario
    JOIN   tmp_usuario      tu ON tu.login       = u.login
    JOIN   datos_documento  dd ON dd.ndocumento  = t.ndocumento
)
SELECT COALESCE(SUM(ud.valor), 0) AS valor
FROM   user_docs ud
WHERE  (
           SELECT 1
           FROM   datos_arqueo a
           JOIN   documentos   da ON da.ndocumento = a.narqueo AND da.estado
           WHERE  a.ndocumento = ud.ndocumento
           LIMIT  1
       ) IS NULL;
