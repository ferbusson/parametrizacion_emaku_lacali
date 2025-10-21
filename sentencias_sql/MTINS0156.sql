DROP TABLE IF EXISTS aux_general;
CREATE TEMP TABLE aux_general AS
SELECT
    '?'::CHARACTER(15) AS id_char,
    '?'::CHARACTER(1) AS dv,
    '?'::CHARACTER VARYING(60) AS nombre1,
    '?'::CHARACTER VARYING(30) AS nombre2,
    '?'::CHARACTER VARYING(30) AS apellido1,
    '?'::CHARACTER VARYING(30) AS apellido2,
    '?'::CHARACTER(15) AS id_char2;

INSERT INTO general(
    id_char, dv, nombre1, nombre2, apellido1, apellido2
) 
SELECT
    a.id_char,
    a.dv,
    COALESCE(TRIM(a.nombre1),' '),
    COALESCE(TRIM(a.nombre2),' '),
    COALESCE(TRIM(a.apellido1),' '),
    COALESCE(TRIM(a.apellido2),' ')
FROM aux_general a
ON CONFLICT (id_char)  -- Must match the unique constraint/index
DO UPDATE SET
    dv = EXCLUDED.dv,
    nombre1 = EXCLUDED.nombre1,
    nombre2 = EXCLUDED.nombre2,
    apellido1 = EXCLUDED.apellido1,
    apellido2 = EXCLUDED.apellido2;