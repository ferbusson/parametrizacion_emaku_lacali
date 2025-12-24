DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Existen Líneas pendientes por crear antes de proseguir. Revise las líneas listadas en la tabla "Lineas Nuevas"')
	FROM
		(SELECT DISTINCT
			TRIM(UPPER(linea)) AS descripcion
		FROM
			creacion_productos_masiva
		EXCEPT
		SELECT DISTINCT
			descripcion
		FROM
			linea
		) AS foo) AS foo;


DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Existen Grupos pendientes por crear antes de proseguir. Revise los grupos listados en la tabla "Grupos Nuevos"')
	FROM
		(SELECT DISTINCT
			l.id_linea,
			TRIM(m.grupo) AS grupo
		FROM
			creacion_productos_masiva m,
			linea l
		WHERE
			TRIM(m.linea) = TRIM(l.descripcion)
		EXCEPT
		SELECT DISTINCT
			id_linea,
			TRIM(descripcion) AS grupo
		FROM
			grupo
		) AS foo) AS foo;
	
DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Existen Subgrupos pendientes por crear antes de proseguir. Revise los subgrupos listados en la tabla "Subgrupos Nuevos"')
	FROM
		(SELECT DISTINCT
			l.id_linea,
			g.id_grupo,
			TRIM(UNACCENT(m.subgrupo)) AS subgrupo
		FROM
			creacion_productos_masiva m,
			linea l,
			grupo g
		WHERE
			m.linea = l.descripcion AND
			l.id_linea = g.id_linea AND
			TRIM(m.grupo) = g.descripcion
		EXCEPT
		SELECT
			s.id_linea,
			s.id_grupo,
			UNACCENT(s.descripcion) AS subgrupo
		FROM
			sgrupo s
		) AS foo) AS foo;

DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Existen Marcas pendientes por crear antes de proseguir. Revise las marcas listadas en la tabla "Marcas Nuevas"')
	FROM
		(SELECT DISTINCT
			TRIM(UNACCENT(m.marca)) AS marca
		FROM
			creacion_productos_masiva m,
			grupo_colores g
		WHERE
			g.descripcion = 'LA CALI' AND
			m.marca != ''
		EXCEPT
		SELECT
			UNACCENT(descripcion) AS marca
		FROM
			marcas
		) AS foo) AS foo;


DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Existen Submarcas pendientes por crear antes de proseguir. Revise las submarcas listadas en la tabla "Submarcas Nuevas"')
	FROM
		(SELECT DISTINCT
			TRIM(submarca) AS submarca
		FROM
			creacion_productos_masiva
		WHERE
			submarca IS NOT NULL AND
			submarca != '' AND
			submarca != 'Sin submarca'
		EXCEPT
		SELECT
			descripcion AS submarca
		FROM
			submarcas
		) AS foo) AS foo;

DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('No pueden haber referencias y descripciones repetidas por marca. Revise la tabla "Referencias Repetidas"')
	FROM
		(SELECT
			c.marca,
			c.referencia,
			c.descripcion
		FROM
			creacion_productos_masiva c
		GROUP BY
			c.marca,
			c.referencia,
			c.descripcion
		HAVING
			COUNT(1)>1
		) AS foo) AS foo;

DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('No pueden haber codigos de productos repetidos. Revise la tabla "Códigos Repetidos"')
	FROM
		(SELECT
			c.marca,
			c.referencia,
			c.descripcion
		FROM
			creacion_productos_masiva c
		GROUP BY
			c.marca,
			c.referencia,
			c.descripcion
		HAVING
			COUNT(1)>1
		) AS foo) AS foo;


DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Error, un producto Gravado no puede tener IVA = 0. Revise el valor de la columna IVA del producto Gravado: '||foo.codigo||'-'||foo.descripcion)
	FROM
		(SELECT
			c.codigo,
			c.marca,
			c.referencia,
			c.descripcion
		FROM
			creacion_productos_masiva c
		WHERE
			c.tipo_asiento_generico = 'GRAVADO' AND
			c.iva = 0
		) AS foo) AS foo;

DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Error, la descripción de los productos no puede superar los 100 caracteres : '||foo.codigo||'-'||foo.descripcion)
	FROM
		(SELECT
			c.codigo,
			c.descripcion
		FROM
			creacion_productos_masiva c
		WHERE
			LENGTH(c.descripcion) > 100
		) AS foo) AS foo;


----------------------------------------------------------------------------

DROP TABLE IF EXISTS faltantes;
CREATE TEMP TABLE faltantes AS 
select 
	TRIM(codigo) AS codigo
from 
	creacion_productos_masiva 
except 
select 
	TRIM(ps.codigo) AS codigo
from 
	prod_serv ps, 
	creacion_productos_masiva m 
where 
	TRIM(ps.codigo) = TRIM(m.codigo);

DROP TABLE IF EXISTS productos_para_traslado;
CREATE TABLE productos_para_traslado AS 
SELECT
	codigo
FROM	
	faltantes;

DROP TABLE IF EXISTS ya_existen;
CREATE TEMP TABLE ya_existen AS 
select 
	ps.codigo 
from 
	prod_serv ps, 
	creacion_productos_masiva m 
where 
	ps.codigo = m.codigo;

DROP TABLE IF EXISTS productos_actualizar_masivo;
CREATE TABLE productos_actualizar_masivo AS 
SELECT
	codigo
FROM	
	ya_existen;

-- actualiza linea
UPDATE
	item
SET
	id_linea = l.id_linea
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps,
	linea l
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	TRIM(u.linea) = TRIM(l.descripcion) AND
	item.id_linea != l.id_linea; -- actualiza linea de los productos que vienen con linea diferente en el archivo

-- actualiza grupo
UPDATE
	item
SET
	id_grupo = g.id_grupo
FROM
	ya_existen y,
	creacion_productos_masiva u,
	linea l,
	prod_serv ps,
	grupo g
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	item.id_linea = g.id_linea AND
	TRIM(u.linea) = TRIM(l.descripcion) AND
	l.id_linea = g.id_linea and
	TRIM(u.grupo) = TRIM(g.descripcion) AND
	item.id_grupo != g.id_grupo; -- actualiza grupo de los productos que vienen con grupo diferente en el archivo

-- actualiza sgrupo
UPDATE
	item
SET
	id_sgrupo = sg.id_sgrupo
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps,
	linea l,
	grupo g,
	sgrupo sg
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	item.id_linea = sg.id_linea AND
	item.id_grupo = sg.id_grupo AND
	TRIM(u.linea) = TRIM(l.descripcion) AND
	l.id_linea = g.id_linea and
	TRIM(u.grupo) = TRIM(g.descripcion) AND
	g.id_linea = sg.id_linea and
	g.id_grupo = sg.id_grupo and
	TRIM(u.subgrupo) = TRIM(sg.descripcion) AND
	item.id_sgrupo != sg.id_sgrupo; -- actualiza grupo de los productos que vienen con grupo diferente en el archivo


-- actualiza marcas
UPDATE
	item
SET
	id_marca = m.id_marca
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps,
	marcas m
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	TRIM(u.marca) = TRIM(m.descripcion) AND
	item.id_marca != m.id_marca; -- actualiza marca de los productos que vienen con marca diferente en el archivo

-- actualiza submarcas

UPDATE
	item
SET
	id_submarca = null
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	TRIM(u.submarca) = 'Sin submarca'; -- actualiza submarca de los productos que vienen con marca diferente en el archivo
	
UPDATE
	item
SET
	id_submarca = sm.id_submarca
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps,
	submarcas sm
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	ps.id_item = item.id_item AND
	TRIM(u.submarca) = TRIM(sm.descripcion) AND
	COALESCE(item.id_submarca,-1) != sm.id_submarca; -- actualiza submarca de los productos que vienen con marca diferente en el archivo

-- actualiza ref_proveedor en item Marzo 03 2023 solicitud Fabian, implementa Fer
UPDATE
  item
SET
  ref_proveedor = TRIM(u.referencia)
FROM
  ya_existen y,
  creacion_productos_masiva u,
  prod_serv ps
WHERE
  y.codigo = u.codigo AND
  u.codigo = ps.codigo AND
  ps.id_item = item.id_item AND
  item.ref_proveedor != u.referencia; -- actualiza ref_proveedor de los productos que vienen con referencia diferente en el archivo Marzo 03 2023

-- actualiza nombre en item Julio 09 2023 solicitud Fabian, implementa Fer
UPDATE
  item
SET
  nombre = TRIM(u.descripcion)
FROM
  ya_existen y,
  creacion_productos_masiva u,
  prod_serv ps
WHERE
  y.codigo = u.codigo AND
  u.codigo = ps.codigo AND
  ps.id_item = item.id_item AND
  item.nombre != u.descripcion; -- actualiza nombre (descripcion) de los productos que vienen con nombre diferente en el archivo Julio 09 2023


UPDATE
	pventa
SET
	pventa = u.pventa1
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	pventa.id_prod_serv = ps.id_prod_serv AND
	pventa.id_catalogo = 1;

UPDATE
	pventa
SET
	pventa = u.pventa2
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	pventa.id_prod_serv = ps.id_prod_serv AND
	pventa.id_catalogo = 2;

UPDATE
	pventa
SET
	pventa = u.pventa3
FROM
	ya_existen y,
	creacion_productos_masiva u,
	prod_serv ps
WHERE
	y.codigo = u.codigo AND
	u.codigo = ps.codigo AND
	pventa.id_prod_serv = ps.id_prod_serv AND
	pventa.id_catalogo = 6;

UPDATE
	prod_serv
SET
	--pcosto= u.costo,
	id_asiento_generico = CASE WHEN u.iva = 5 THEN 10 ELSE CASE WHEN u.iva = 19 THEN 5 ELSE CASE WHEN u.tipo_asiento_generico = 'EXENTO' THEN 13 ELSE CASE WHEN u.tipo_asiento_generico = 'EXCLUIDO' THEN 12 ELSE 13 END END END END,
	iva = u.iva
FROM
	ya_existen y,
	creacion_productos_masiva u
WHERE
	y.codigo = u.codigo AND
	u.codigo = prod_serv.codigo;


-- Inicia tratamiento información para insertar nuevos item
-- Se obtiene listado de productos desde tabla de migracion cruzada con linea, grupo, sgrupo, marcas y submarcas
-- 1
DROP TABLE IF EXISTS aux_item;
CREATE TEMP TABLE aux_item AS 
SELECT DISTINCT
	sg.id_linea,
	sg.id_grupo,
	sg.id_sgrupo,
	ma.id_marca,
	sm.id_submarca,
	1 AS id_presentacion,
	TRIM(m.referencia) AS referencia,
	TRIM(m.descripcion) AS descripcion,
	m.costo,
	m.iva
FROM
	linea l,
	grupo g,
	sgrupo sg,
	marcas ma,
	faltantes f,
	creacion_productos_masiva m
LEFT OUTER JOIN
	submarcas sm
 ON
	TRIM(UNACCENT(m.submarca)) = TRIM(UNACCENT(sm.descripcion))	
WHERE
	m.codigo = f.codigo AND
	TRIM(UNACCENT(m.linea)) = TRIM(UNACCENT(l.descripcion)) AND
	l.id_linea = g.id_linea AND
	TRIM(UNACCENT(m.grupo)) = TRIM(UNACCENT(g.descripcion)) AND
	l.id_linea = sg.id_linea AND
	g.id_grupo = sg.id_grupo AND
	TRIM(UNACCENT(m.subgrupo)) = TRIM(UNACCENT(sg.descripcion)) AND
	TRIM(UNACCENT(m.marca)) = TRIM(UNACCENT(ma.descripcion))
ORDER BY
	sg.id_linea,
	sg.id_grupo,
	sg.id_sgrupo,
	ma.id_marca,
	sm.id_submarca,
	TRIM(m.referencia);

-- 2 Busca marcas y referencias repetidas
DROP TABLE IF EXISTS aux_marca_ref_repetidos;
CREATE TEMP TABLE aux_marca_ref_repetidos AS 
SELECT
	id_marca,
	referencia,
	descripcion,
	COUNT(1) AS c
FROM
	aux_item
GROUP BY
	id_marca,
	referencia,
	descripcion
HAVING
	COUNT(1)>1
ORDER BY
	referencia;

-- Lista los productos que No existen
-- 3
DROP TABLE IF EXISTS aux_item_ok;
CREATE TEMP TABLE aux_item_ok AS 
SELECT
	a.id_marca,
	a.referencia,
	TRIM(UNACCENT(a.descripcion)) AS descripcion
FROM
	aux_item a,
	(SELECT DISTINCT
		id_marca,
		referencia,
		descripcion
	FROM
		aux_item
	EXCEPT
	SELECT DISTINCT
		id_marca,
		referencia,
		descripcion
	FROM
		aux_marca_ref_repetidos) AS foo
WHERE
	a.id_marca = foo.id_marca AND
	a.referencia = foo.referencia AND
	a.descripcion = foo.descripcion
EXCEPT
SELECT
	id_marca,
	ref_proveedor,
	TRIM(UNACCENT(nombre)) AS descripcion
FROM
	item;

-- Inserta en item
-- 4
INSERT INTO
	item(
		id_linea,
		id_grupo,
		id_sgrupo,
		id_marca,
		id_submarca,
		id_presentacion,
		ref_proveedor,
		nombre)
SELECT
	a.id_linea,
	a.id_grupo,
	a.id_sgrupo,
	a.id_marca,
	a.id_submarca,
	a.id_presentacion,
	a.referencia,
	a.descripcion
FROM
	aux_item a,
	aux_item_ok o
WHERE
	a.id_marca = o.id_marca AND
	a.referencia = o.referencia AND
	TRIM(UNACCENT(a.descripcion)) = TRIM(UNACCENT(o.descripcion));


-- Inserta en prod_serv
-- 6
DROP TABLE IF EXISTS aux_prod_serv;
CREATE TEMP TABLE aux_prod_serv AS 
SELECT DISTINCT
	TRIM(m.codigo) AS codigo,
	'001' AS id_tipo_prod_serv, -- productos
	TRUE AS estado,
	-- Feb 12 2025: se quita la opción de crear exentos(13) por solicitud de la Cali, todos se van a ir por excluidos (12)
	CASE WHEN m.iva = 5 THEN 10 ELSE CASE WHEN m.iva = 19 THEN 5 ELSE CASE WHEN m.tipo_asiento_generico = 'EXENTO' THEN 12 ELSE CASE WHEN m.tipo_asiento_generico = 'EXCLUIDO' THEN 12 ELSE 12 END END END END AS id_asiento_generico,
	m.iva,
	m.costo,
	i.id_item,
	1 AS id_talla,
	1 AS id_color
FROM
	creacion_productos_masiva m,
	faltantes f,
	item i,
	linea l,
	grupo g,
	sgrupo sg,
	marcas ma
WHERE
	f.codigo = m.codigo AND
	i.id_linea = l.id_linea AND
	i.id_grupo = g.id_grupo AND
	i.id_sgrupo = sg.id_sgrupo AND
	i.id_marca = ma.id_marca AND
	TRIM(UNACCENT(l.descripcion)) = TRIM(UNACCENT(m.linea)) AND
	TRIM(UNACCENT(g.descripcion)) = TRIM(UNACCENT(m.grupo)) AND
	TRIM(UNACCENT(sg.descripcion)) = TRIM(UNACCENT(m.subgrupo)) AND
	TRIM(UNACCENT(ma.descripcion)) = TRIM(UNACCENT(m.marca)) AND
	i.ref_proveedor = TRIM(m.referencia) AND
	TRIM(UNACCENT(i.nombre)) = TRIM(UNACCENT(m.descripcion));

	
DROP TABLE IF EXISTS aux_prod_serv_repetidos;
CREATE TEMP TABLE aux_prod_serv_repetidos AS 
SELECT
	codigo,
	COUNT(1) AS c
FROM
	aux_prod_serv
GROUP BY
	codigo
HAVING
	COUNT(1)>1
ORDER BY
	codigo;

INSERT INTO
	prod_serv(
		codigo,
		id_tipo_prod_serv,
		estado,
		id_asiento_generico,
		iva,
		pcosto,
		id_item,
		id_talla,
		id_color)
SELECT
	a.codigo,
	a.id_tipo_prod_serv,
	a.estado,
	a.id_asiento_generico,
	a.iva,
	--a.costo,
    0 AS costo,
	a.id_item,
	a.id_talla,
	a.id_color
FROM
	aux_prod_serv a,
	(SELECT
		codigo
	FROM
		aux_prod_serv
	EXCEPT
	SELECT
		codigo
	FROM
		prod_serv) AS foo
WHERE
	a.codigo = foo.codigo;

-- pventa1 ok
INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT
	1 AS id_catalogo,
	ps.id_prod_serv,
	CASE WHEN m.pventa1 IS NULL THEN 0 ELSE m.pventa1 END AS pventa1
FROM
	creacion_productos_masiva m,
	prod_serv ps,
	(SELECT
		id_prod_serv
	FROM
		prod_serv
	EXCEPT
	SELECT
		id_prod_serv
	FROM
		pventa 
	WHERE
		id_catalogo = 1) AS foo
WHERE
	TRIM(m.codigo) = ps.codigo AND
	ps.id_prod_serv = foo.id_prod_serv;

-- pventa2 ok
INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT
	2 AS id_catalogo,
	ps.id_prod_serv,
	CASE WHEN m.pventa2 IS NULL THEN 0 ELSE m.pventa2 END AS pventa2
FROM
	creacion_productos_masiva m,
	prod_serv ps,
	(SELECT
		id_prod_serv
	FROM
		prod_serv
	EXCEPT
	SELECT
		id_prod_serv
	FROM
		pventa 
	WHERE
		id_catalogo = 2) AS foo
WHERE
	TRIM(m.codigo) = ps.codigo AND
	ps.id_prod_serv = foo.id_prod_serv;


-- pventa3 mercado libre ok
INSERT INTO
	pventa(
		id_catalogo,
		id_prod_serv,
		pventa)
SELECT
	6 AS id_catalogo,
	ps.id_prod_serv,
	CASE WHEN m.pventa3 IS NULL THEN 0 ELSE m.pventa3 END AS pventa3
FROM
	creacion_productos_masiva m,
	prod_serv ps,
	(SELECT
		id_prod_serv
	FROM
		prod_serv
	EXCEPT
	SELECT
		id_prod_serv
	FROM
		pventa 
	WHERE
		id_catalogo = 6) AS foo
WHERE
	TRIM(m.codigo) = ps.codigo AND
	ps.id_prod_serv = foo.id_prod_serv;

DROP TABLE IF EXISTS aux_traslados;
CREATE TEMP TABLE aux_traslados AS 
SELECT * FROM traslado_masivo_productos() WHERE EXISTS (SELECT codigo FROM productos_para_traslado);

DROP TABLE IF EXISTS aux_traslados;
CREATE TEMP TABLE aux_traslados AS 
SELECT * FROM traslado_masivo_productos_editar() WHERE EXISTS(SELECT codigo FROM productos_actualizar_masivo);