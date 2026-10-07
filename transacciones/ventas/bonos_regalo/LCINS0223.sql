--LCINS0223
DELETE FROM
	campanias_bono_regalo
USING
	aux_campaniasbonosregalo a
WHERE
	campanias_bono_regalo.codigo NOT IN 
				(SELECT
					codigo
				FROM
					aux_campaniasbonosregalo);
