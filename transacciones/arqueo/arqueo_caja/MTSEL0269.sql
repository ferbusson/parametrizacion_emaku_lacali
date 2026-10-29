-- MTSEL0269 — Consulta valor venta tarjeta regalo para arqueo
--
-- Suma `libro_auxiliar.debe` de la cuenta 281010% (pasivo tarjetas regalo)
-- para los documentos del cajero actual que no estén aún en un arqueo activo.
-- Representa el valor cobrado con tarjetas regalo (redención del pasivo).
--
-- Variante más simple de MTSEL0270 (no requiere `tipo_docs` porque las
-- redenciones de tarjeta regalo pueden ocurrir en cualquier tipo de doc).
--
-- Optimización 2026-10-28: EXCEPT reescrito a CTE + subquery escalar con
-- LIMIT 1 + ventana de 7 días. Compatible con PG 9.5.
--
-- Benchmark dev jbe: 2244 ms → 2 ms (~1000x).
-- En prod: ~32s original esperado al rango de los otros ya optimizados.
--
-- Ver [[project-mtsel0268-optim]] para el análisis del patrón base.

DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT '?'::VARCHAR(70) AS login;

WITH user_docs AS (
    SELECT d.ndocumento
    FROM   documentos      d
    JOIN   info_documento  i  ON i.ndocumento   = d.ndocumento
    JOIN   usuarios        u  ON u.id_usuario   = i.id_usuario
    JOIN   tmp_usuario     tu ON tu.login       = u.login
    WHERE  d.estado
      AND  d.fecha >= CURRENT_DATE - INTERVAL '7 days'
)
SELECT COALESCE(SUM(l.debe), 0) AS valor
FROM   user_docs       ud
JOIN   libro_auxiliar  l  ON l.ndocumento  = ud.ndocumento
JOIN   cuentas         c  ON c.id_cta      = l.id_cta
                         AND c.char_cta ILIKE '281010%'
JOIN   datos_documento dd ON dd.ndocumento = l.ndocumento
WHERE  (
           SELECT 1
           FROM   datos_arqueo a
           JOIN   documentos   da ON da.ndocumento = a.narqueo AND da.estado
           WHERE  a.ndocumento = ud.ndocumento
           LIMIT  1
       ) IS NULL;
