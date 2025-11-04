with aux_documento_consultar as(
	select
		d.ndocumento
	from
		documentos d
	where
		d.codigo_tipo = '?' AND
		d.numero = LPAD( '?',10,'0')
	)
select
	case when cu.char_cta = '28050503' then 'CREDIBANCO' else 'REDEBAN' end as nombre
from
	libro_auxiliar la
inner join
	aux_documento_consultar a
on
	la.ndocumento = a.ndocumento
inner join
	cuentas cu
on
	la.id_cta = cu.id_cta and
	cu.char_cta in ('28050503','28050504')
limit 1;