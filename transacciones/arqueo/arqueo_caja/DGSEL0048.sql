-- DGSEL0048 — Consulta datos_documento (efectivo pendiente de arqueo)
--
-- Suma `efectivo - cambio` de las facturas FA/FM del cajero actual
-- (login en u.login) que todavía no estén incluidas en un arqueo activo
-- de tipo AQ.
--
-- Usada por 5 formularios (DGTR00082/83/84 "arqueo modificado",
-- MTR00057 "Editar arqueo", MTR00061 "Ver estado de cajas"), todos en
-- el flujo de arqueo.
--
-- Diferencias con el patrón de MTSEL0268:
--   * El login se interpola directamente (`u.login = 'interrogacion'`), no vía tmp_usuario.
--   * El EXCEPT original NO filtra por usuario (toma "todos los docs no
--     arqueados"), el filtro de usuario se aplica al nivel exterior. En el
--     rewrite el orden se invierte sin cambiar la semántica: filtramos
--     primero por usuario+tipo+fecha (set pequeño) y luego anti-join.
--   * La anti-check incluye `da.codigo_tipo = 'AQ'` sobre el documento
--     padre del arqueo (preservado del original).
--
-- Optimización 2026-10-28: EXCEPT reescrito a CTE + subquery escalar con
-- LIMIT 1 + ventana de 7 días. Compatible con PG 9.5.
--
-- Benchmark dev jbe: 799 ms → 0.3 ms (dev no tiene FA/FM; ambos planes
-- cortocircuitan, el original igual construye el HashSetOp sobre 99k filas).
--
-- Ver [[project-mtsel0268-optim]] para el análisis del patrón.

WITH user_docs AS (
    SELECT d.ndocumento,
           dd.efectivo,
           dd.cambio
    FROM   documentos      d
    JOIN   datos_documento dd ON dd.ndocumento = d.ndocumento
    JOIN   info_documento  i  ON i.ndocumento  = d.ndocumento
    JOIN   usuarios        u  ON u.id_usuario  = i.id_usuario
    WHERE  u.login       = '?'
      AND  d.estado      = true
      AND  d.codigo_tipo IN ('FA','FM')
      AND  d.fecha      >= CURRENT_DATE - INTERVAL '7 days'
      AND  dd.efectivo   > 0
)
SELECT coalesce(SUM(ud.efectivo - ud.cambio),0) AS valor
FROM   user_docs ud
WHERE  (
           SELECT 1
           FROM   datos_arqueo a
           JOIN   documentos   da ON da.ndocumento = a.narqueo
                                 AND da.estado
                                 AND da.codigo_tipo = 'AQ'
           WHERE  a.ndocumento = ud.ndocumento
           LIMIT  1
       ) IS NULL;
