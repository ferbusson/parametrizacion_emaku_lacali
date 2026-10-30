INSERT INTO --?
	items_pendientes_traslado(id_item, operacion)
SELECT
	CURRVAL('item_id_item_seq') AS id_item,
	'C'::CHARACTER(1) AS operacion;