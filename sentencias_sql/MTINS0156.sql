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

UPDATE
    general
SET 
    id_char=a.id_char,
    dv=a.dv,
    nombre1=COALESCE(TRIM(a.nombre1),' '),
    nombre2=COALESCE(TRIM(a.nombre2),' '),
    apellido1=COALESCE(TRIM(a.apellido1),' '),
    apellido2=COALESCE(TRIM(a.apellido2),' ')
FROM
    aux_general a
WHERE
    general.id_char=a.id_char;

INSERT INTO 
    general(
        id_char,
        dv,
        nombre1,
        nombre2,
        apellido1,
        apellido2) 
SELECT
    a.id_char,
    a.dv,
    COALESCE(TRIM(a.nombre1),' ') AS nombre1,
    COALESCE(TRIM(a.nombre2),' ') AS nombre2,
    COALESCE(TRIM(a.apellido1),' ') AS apellido1,
    COALESCE(TRIM(a.apellido2),' ') AS apellido2
FROM
    aux_general a,
    (SELECT
        TRIM(id_char) AS id_char
    FROM
        aux_general
    EXCEPT
    SELECT
        TRIM(id_char) AS id_char
    FROM
        general) AS foo
WHERE
    foo.id_char = a.id_char;