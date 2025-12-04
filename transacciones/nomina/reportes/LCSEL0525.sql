SELECT
	codigo,
	nombre
FROM
	reportes
WHERE
	codigo like 'EXNOM%' 
ORDER BY
	CASE WHEN codigo = 'EXNOM12' THEN 'EXNOM062' ELSE codigo END;