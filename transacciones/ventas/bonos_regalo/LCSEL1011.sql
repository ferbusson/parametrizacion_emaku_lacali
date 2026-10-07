/*
 * Consulta que llena las opciones del combo Tipo de Tarjeta en la recarga de tarjetas, permite seleccionar la cuenta que
 * le corresponde a cada una al momento de guardar
 * */
select
	char_cta,
	case when cu.char_cta = '28050503' then 'CREDIBANCO' else 'REDEBAN' end as nombre
from
	cuentas cu
where
	cu.char_cta in ('28050503','28050504')
order by
	id_cta DESC;