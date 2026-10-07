--LCSEL1020
SELECT
	descripcion,
	codigo,
	visible,
	id
FROM
	campanias_bono_regalo
 UNION ALL
 SELECT
    NULL AS descripcion,
    NULL AS codigo,
    false AS visible,
    0 as id
 FROM
    generate_series(0,10)
ORDER BY
	descripcion NULLS LAST;	