-- MTSEL0268 — Consulta valor venta tdébito (y demás tipos != 'CR')
--
-- Suma `tarjetas.valor` para los documentos del cajero actual (identificado
-- por `tmp_usuario.login`) que:
--   * tengan `tcredito.tipo <> 'CR'`
--   * pertenezcan a documentos activos
--   * NO estén incluidos en un arqueo activo (datos_arqueo con narqueo activo)
--
-- Versión original (EXCEPT con dos sets grandes) tardaba ~10 s en producción
-- porque construía el set completo "docs del usuario" y "docs cerrados en
-- arqueo" sin empujar el filtro de usuario, forzando seq-scans sobre
-- info_documento (~103k) y datos_arqueo (~80k), y un HashSetOp sobre ~378k
-- filas combinadas.
--
-- Esta reescritura usa tres optimizaciones:
--   1. CTE que aterriza en tarjetas + joins por índices.
--   2. Filtro de ventana de 7 días sobre `d.fecha`. Semánticamente la query
--      alimenta el documento de cierre de arqueo del cajero; si hubo un
--      corte de luz u otro problema técnico puede quedar pendiente de un día
--      para otro, pero 7 días cubre con holgura ese caso real. Esto reduce
--      el universo de ~3M documentos a algunos miles.
--   3. Anti-join como subquery escalar `(SELECT 1 ... LIMIT 1) IS NULL`
--      para forzar nested-loop por `idx_datos_arqueo_ndocumento` en vez de
--      un Hash Anti Join sobre todo datos_arqueo.
--
-- Nota PG 9.5 (producción): se omite la palabra `MATERIALIZED`; en 9.5
-- las CTEs se materializan por defecto, así que el fence se preserva.
-- Nota futura: cuando exista `idx_info_documento_id_usuario`, el planner
-- podrá empujar el filtro del cajero aún más temprano.
--
-- Benchmarks:
--   jbe dev:        2516 ms -> 139 ms  (~18x, sin filtro de fecha)
--   prod sin fecha: 8000 ms -> 2000 ms (~4x)
--   prod con fecha: pendiente de medir (se espera < 100 ms)
--
-- Ver `explain_plans/MTSEL0268/` para los planes before/after.

DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT '?'::VARCHAR(70) AS login;

WITH user_docs AS (
    SELECT t.ndocumento, t.valor
    FROM   tarjetas         t
    JOIN   tcredito         tc ON tc.id_tcredito = t.id_tcredito AND tc.tipo <> 'CR'
    JOIN   documentos       d  ON d.ndocumento   = t.ndocumento
                              AND d.estado
                              AND d.fecha        >= CURRENT_DATE - INTERVAL '7 days'
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
