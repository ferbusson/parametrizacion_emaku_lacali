-- LCSEL0152 — Consulta valor venta pagada con cheques BigPass para arqueo
-- Optimización 2026-10-28: EXCEPT -> CTE + subquery escalar con LIMIT 1
-- + ventana de 7 días en d.fecha. Compatible con PG 9.5.
DROP TABLE IF EXISTS tmp_usuario;
CREATE TEMP TABLE tmp_usuario AS
SELECT CAST('?' AS character(13)) AS login;

WITH user_docs AS (
    SELECT cs.ndocumento, cs.denominacion, cs.cantidad
    FROM   cheques_sodexobigpass cs
    JOIN   documentos     d  ON d.ndocumento   = cs.ndocumento
                            AND d.estado
                            AND d.fecha        >= CURRENT_DATE - INTERVAL '7 days'
    JOIN   info_documento i  ON i.ndocumento   = cs.ndocumento
    JOIN   usuarios       u  ON u.id_usuario   = i.id_usuario
    JOIN   tmp_usuario    tu ON tu.login       = u.login
    WHERE  cs.id_sodexobigpass = 2
)
SELECT COALESCE(SUM(ud.denominacion * ud.cantidad), 0.0) AS valor
FROM   user_docs ud
WHERE  (
           SELECT 1
           FROM   datos_arqueo a
           JOIN   documentos   da ON da.ndocumento = a.narqueo AND da.estado
           WHERE  a.ndocumento = ud.ndocumento
           LIMIT  1
       ) IS NULL;
