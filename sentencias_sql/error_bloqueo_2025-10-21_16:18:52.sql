2025-10-21 16:18:52.254 -05 [2865286] emaku@lacali ERROR:  canceling statement due to user request
2025-10-21 16:18:52.254 -05 [2865286] emaku@lacali CONTEXT:  while locking tuple (1343,39) in relation "general"
2025-10-21 16:18:52.254 -05 [2865286] emaku@lacali STATEMENT:  DROP TABLE IF EXISTS aux_general;
        CREATE TEMP TABLE aux_general AS
        SELECT
            '1085290352'::CHARACTER(15) AS id_char,
            NULL::CHARACTER(1) AS dv,
            'JOHANA'::CHARACTER VARYING(60) AS nombre1,
            'CAROLINA'::CHARACTER VARYING(30) AS nombre2,
            'ORTIZ'::CHARACTER VARYING(30) AS apellido1,
            'RUEDA'::CHARACTER VARYING(30) AS apellido2,
            '1085290352'::CHARACTER(15) AS id_char2;
        
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
2025-10-21 16:18:52.257 -05 [2865286] emaku@lacali ERROR:  current transaction is aborted, commands ignored until end of transaction block



--Solution:

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