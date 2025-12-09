DROP TABLE IF EXISTS aux_parametro;
create temp table aux_parametro as
select
	'?'::VARCHAR AS fechai,
	'?'::VARCHAR AS fechaf,
	'?'::VARCHAR(1) as bandera;

select
	sucursal,
	linea,
	grupo,
	subgrupo,
	marca,
	submarca,
	por_item,
	pdescuento,
	numero,
	fechaip,
	fechafp,	
	fecha as fecha_creacion,
	perfil,
	ndocumento,
	id_administracion_sucursales
from
	(SELECT DISTINCT
		CASE WHEN rp.codigo_tipo = '' THEN 'TODAS' ELSE UPPER(TRIM(REPLACE(td.descripcion,'Facturacion ',''))) END AS sucursal,
		l.descripcion as linea,
		g.descripcion as grupo,
		s.descripcion as subgrupo,
		m.descripcion AS marca,
		sm.descripcion as submarca,
		CASE WHEN i.ndocumento IS NOT NULL THEN 'SI' ELSE 'NO' END AS por_item,
		xy.pdescuento,
		d.numero,
		xy.created_at AS fecha,
		rp.fechaip,
		rp.fechafp,	
		'PRTR00015' AS perfil,
		d.ndocumento,
		CASE WHEN rp.codigo_tipo = '' THEN 0 WHEN rp.codigo_tipo = 'FA' THEN 1 WHEN rp.codigo_tipo = 'F2' THEN 3 WHEN rp.codigo_tipo = 'F3' THEN 4 WHEN rp.codigo_tipo = 'F4' THEN 5 WHEN rp.codigo_tipo = 'F5' THEN 6 END AS id_administracion_sucursales
	FROM
		aux_parametro a,
		documentos d,
		xy_promocion xy,		
		registro_promociones rp
	LEFT OUTER JOIN
		linea l
	ON
		rp.id_linea = l.id_linea
	LEFT OUTER JOIN
		grupo g
	ON
		rp.id_grupo = g.id_grupo
	LEFT OUTER JOIN
		sgrupo s
	ON
		rp.id_sgrupo = s.id_sgrupo
	LEFT OUTER JOIN
		marcas m
	ON
		rp.id_marca = m.id_marca
	LEFT OUTER JOIN
		submarcas sm
	ON
		rp.id_submarca = sm.id_submarca
	LEFT OUTER JOIN
		items_promocion i
	ON
		rp.ndocumento = i.ndocumento
	left outer join
		registro_promociones_excepciones rpe
	on
		rp.ndocumento = rpe.ndocumento and
		rpe.codigo_tipo is not null
	LEFT OUTER JOIN
		tipo_documento td
	ON
		td.codigo_tipo = rp.codigo_tipo
	WHERE
		xy.ndocumento = d.ndocumento AND
		d.codigo_tipo = 'XY' AND
		d.estado AND
		d.ndocumento = rp.ndocumento AND
		-- ((a.bandera::INT = 1 and
-- 		rp.estado AND
-- 		CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp) OR
-- 		(a.bandera::INT = 0 AND 
-- 		(rp.estado = FALSE OR
-- 		CURRENT_TIMESTAMP NOT BETWEEN rp.fechaip AND rp.fechafp)))

		((a.bandera::INT = 1 and
		rp.estado AND
		CURRENT_TIMESTAMP BETWEEN rp.fechaip AND rp.fechafp AND
		CASE WHEN TRIM(a.fechaf) = '' THEN FALSE ELSE xy.created_at::DATE BETWEEN a.fechai::DATE AND a.fechaf::DATE END) OR
		(a.bandera::INT = 0 AND 
		((rp.estado = FALSE OR
		CURRENT_TIMESTAMP NOT BETWEEN rp.fechaip AND rp.fechafp) AND
		CASE WHEN TRIM(a.fechaf) = '' THEN FALSE ELSE xy.created_at::DATE BETWEEN a.fechai::DATE AND a.fechaf::DATE END)))
		) as foo
order by
	sucursal,
	numero;