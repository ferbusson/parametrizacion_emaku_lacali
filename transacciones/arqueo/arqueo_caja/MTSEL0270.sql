-- MTSEL0270 — Consulta valor venta facturación crédito para arqueo
--
-- Suma `libro_auxiliar.debe` de la cuenta 1305% (clientes por cobrar) para
-- los documentos del cajero actual con `codigo_tipo` tipo FCREDITO que no
-- estén aún en un arqueo activo.
--
-- Diferencias con el patrón de MTSEL0268 (tdébito):
--   * Usa `libro_auxiliar` en vez de `tarjetas` como tabla de instrumentos.
--   * El filtro de tipo de pago se hace vía temp table `tipo_docs`
--     (codigo_tipo de documentos FCREDITO asignados a la sucursal del cajero).
--   * El valor a sumar es `l.debe` filtrado por cuenta `char_cta ILIKE '1305%'`.
--
-- Optimización 2026-10-28: EXCEPT reescrito a CTE + subquery escalar con
-- LIMIT 1 + ventana de 7 días. Compatible con PG 9.5.
--
-- Benchmark dev jbe: 2706 ms → 17 ms (~160x).
-- Esta era la 2ª sentencia más lenta del log (~68s en prod).
--
-- Ver [[project-mtsel0268-optim]] para el análisis del patrón base.

DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT CAST('?' AS character(13)) AS login;

DROP TABLE IF EXISTS tipo_docs;
CREATE TEMP TABLE tipo_docs AS
SELECT ds.codigo_tipo
FROM   documentos_standar          dst,
       asignacion_usuario_sucursal au,
       documentos_sucursales       ds,
       tmp_usuario                 t,
       usuarios                    u
WHERE  t.login = u.login
  AND  u.id_usuario = au.id
  AND  dst.id_documento = ds.id_documento
  AND  au.id_administracion_sucursales = ds.id_administracion_sucursales
  AND  dst.nombre IN ('FCREDITO');

WITH user_docs AS (
    SELECT DISTINCT d.ndocumento
    FROM   documentos      d
    JOIN   info_documento  i  ON i.ndocumento   = d.ndocumento
    JOIN   usuarios        u  ON u.id_usuario   = i.id_usuario
    JOIN   tmp_usuario     tu ON tu.login       = u.login
    JOIN   tipo_docs       td ON td.codigo_tipo = d.codigo_tipo
    WHERE  d.estado
      AND  d.fecha >= CURRENT_DATE - INTERVAL '7 days'
)
SELECT COALESCE(SUM(l.debe), 0) AS valor
FROM   user_docs       ud
JOIN   libro_auxiliar  l  ON l.ndocumento  = ud.ndocumento
JOIN   cuentas         c  ON c.id_cta      = l.id_cta
                         AND c.char_cta ILIKE '1305%'
JOIN   datos_documento dd ON dd.ndocumento = l.ndocumento
WHERE  (
           SELECT 1
           FROM   datos_arqueo a
           JOIN   documentos   da ON da.ndocumento = a.narqueo AND da.estado
           WHERE  a.ndocumento = ud.ndocumento
           LIMIT  1
       ) IS NULL;
