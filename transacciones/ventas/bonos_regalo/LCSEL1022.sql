--LCSEL1022
select
	cu.nombre as franquicia,
	abr.codigo_campania,
	abr.codigo_bono_regalo,
	abr.telefono,
	abr.email
from
	documentos d
join
	activacion_bonos_regalo abr 
on
	d.ndocumento = abr.ndocumento
join
	cuentas cu
on
	abr.franquicia = cu.char_cta 
where
	d.codigo_tipo = '?'
	and d.numero = lpad('?',10,'0');