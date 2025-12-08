/*
 Parametros necesarios:
	1 id_bodega
	2 fechai
	3 fechaf
	4 id_char
	5 id_marca
	6 id_linea
*/

-- Step 1: Create a temp table to store the input parameters
DROP TABLE IF EXISTS aux_reporte_libro_aux;
CREATE TEMP TABLE aux_reporte_libro_aux AS
SELECT 
	'?'::varchar as id_bodega,
	'?'::timestamp AS fechai,
	'?'::timestamp AS fechaf,
	'?'::VARCHAR AS id_char,
	'?'::VARCHAR AS id_marca,
	'?'::varchar AS id_linea;

-- Step 2: Validation - check if date range exceeds 180 days (6 months)
DROP TABLE IF EXISTS error_msg;
CREATE TEMP TABLE error_msg AS
SELECT 
	1
FROM
	(SELECT
		error_text('Rango demasiado extenso: '||foo.dias||' días detectados. Reduzca el período a 365 días máximo o agregue filtros adicionales.')
		
	FROM
		(SELECT
			fechaf::date - fechai::date as dias
		FROM
			aux_reporte_libro_aux
		WHERE
		 	fechaf::date - fechai::date > 365
		 	and (id_char = '' or id_char is null)
		 	and (id_marca = '' or id_marca is null)
		 	and (id_linea = '' or id_linea is null)
		) AS foo
	) AS foo;

-- Step 3: Execute the main query only if validation passed (error_msg is empty)
SELECT
	nombre_bodega,
	plataforma,
	nit_proveedor,
	proveedor,
	marca,
	submarca,
	linea,
	grupo,
	subgrupo,
	codigo_producto,
	descripcion_producto,
	referencia,
	tipo_impuesto,
	unidades_vendidas,
	costo_unidad,
	pcosto_ult_compra,
	pventa,
	porcentaje_descuento,
	pventa_antes_iva,
	valor_total_venta,
	porcentaje_utilidad,    
	porcentaje_utilidad_ult_compra
FROM
	informe_ventas_pos_x_proveedor_marca_on_servers(
		(SELECT id_bodega FROM aux_reporte_libro_aux),
		(SELECT fechai FROM aux_reporte_libro_aux),
		(SELECT fechaf FROM aux_reporte_libro_aux),
		(SELECT id_char FROM aux_reporte_libro_aux),
		(SELECT id_marca FROM aux_reporte_libro_aux),
		(SELECT id_linea FROM aux_reporte_libro_aux)
	);