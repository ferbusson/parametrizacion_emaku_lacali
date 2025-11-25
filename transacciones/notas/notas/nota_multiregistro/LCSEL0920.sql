drop table if exists aux_libro_auxiliar_consulta;
create temp table aux_libro_auxiliar_consulta as
SELECT
	l.orden,
	l.id_centrocosto,
	l.id_scentrocosto,
	c.char_cta,
	c.nombre,
	l.id_cta,
	l.id_tercero,
	l.ndocumento,
	l.ndocumento_enlace,
	l.id_prod_serv,
	l.debe,
	l.haber,
	d.codigo_tipo,
	COALESCE(rd.valor_base,0) AS base,
	l.detalle,
	pc.terceros,
	pc.centro ,
	pc.scentro,
	pc.vinculada,
	pc.edocumento,
	pc.retencion,
	l.id_vinculo_movimiento
from
	libro_auxiliar l
inner join
	documentos d
on
	l.ndocumento = d.ndocumento
inner join
	cuentas c
on
	l.id_cta = c.id_cta
inner join
	perfil_cta pc
on
	c.id_cta = pc.id_cta	
LEFT OUTER JOIN
 	retenciones_documento rd
ON
 	l.ndocumento = rd.ndocumento AND
 	l.id_cta = rd.id_cta AND
 	case when d.codigo_tipo not in ('IC','G1','AT','EA','DC','ED','GI','DO','DQ','RC','M1','CJ') then l.id_tercero = rd.id_tercero else true end and -- las devs en compra no guardan el id_tercero Feb 17 2025
 	abs(l.haber-l.debe) = rd.valor_retencion
WHERE
	d.codigo_tipo='?' AND
	d.numero=LPAD('?',10,'0');

--

SELECT
	foo.char_cta,
	foo.detalle,
	foo.debe,
	foo.haber,
	foo.base,
	foo.id_char,
	numero,
	foo.centrocosto,
	foo.scentrocosto,
	v.codigo AS vinculo,
	foo.nombre,
	foo.terceros,
	foo.centro,
	foo.scentro,
	foo.vinculada,
	foo.edocumento,
	foo.retencion,
	id_tercero,
	foo.id_prod_serv AS id_producto,
	foo.id_cta,
	NEXTVAL('orden_seq'),
	nombret,
	foo.nfactura,
	nombretimp,
	detalleimp,
	numdocimp
FROM	
	(SELECT
		foo.char_cta,
		foo.detalle,
		foo.debe,
		foo.haber,
		foo.base,
		foo.id_char,
		numero,
		foo.codigo AS centrocosto,
		s.codigo AS scentrocosto,	
		foo.nombre,
		foo.terceros,
		foo.id_prod_serv,
		foo.centro,
		foo.scentro,
		COALESCE(foo.id_tercero,0) AS id_tercero,
		foo.id_cta,
		foo.vinculada,
		foo.edocumento,
		foo.retencion,
		foo.id_vinculo_movimiento,
		foo.orden,
		nombret,
	 	foo.nfactura,
	 	nombretimp,
	 	detalleimp,
	 	numdocimp
	FROM
		(SELECT
			foo.char_cta,
			foo.debe,
			foo.haber,
			foo.base,
			foo.id_char,
			coalesce(doc.numero,doc2.numero) as numero,
			--doc.numero,
			foo.codigo,
			foo.id_scentrocosto,
			foo.id_centrocosto,
			foo.id_prod_serv,
			foo.nombre,
			foo.terceros,
			foo.detalle,
			foo.centro,
			foo.scentro,
			foo.id_tercero,
			foo.id_cta,
			foo.vinculada,
			foo.edocumento,
			foo.retencion,
			foo.id_vinculo_movimiento,
			foo.orden,
			nombret,
		 	coalesce(doc.nfactura,doc2.nfactura) as nfactura,
			--doc.nfactura,
		 	SUBSTRING(foo.id_char||'-'||nombret,1,30) AS nombretimp,
		 	SUBSTRING(foo.detalle,1,41) AS detalleimp,
		 	coalesce(doc.numero_exdocumento,doc2.numero_exdocumento) as numdocimp
		 	--doc.numero_exdocumento as numdocimp
		FROM
			(select
				foo.codigo_tipo,
				foo.orden,
				foo.char_cta,
				foo.nombre,
				g.id_char,
				foo.id_cta,
				foo.id_tercero,
				foo.ndocumento,
				foo.ndocumento_enlace,
				foo.id_prod_serv,
				foo.debe,
				foo.haber,
				foo.base,
				foo.terceros,
				foo.id_centrocosto,
				foo.detalle,
				foo.codigo,
				foo.id_scentrocosto,
				foo.scentro,
				foo.centro,
				foo.vinculada,
				foo.edocumento,
				foo.retencion,
				foo.id_vinculo_movimiento,
				TRIM(COALESCE(g.nombre1,'')||' '||COALESCE(g.nombre2,'')||' '||COALESCE(g.apellido1,'')||' '||COALESCE(g.apellido2,'')||' '||COALESCE(g.razon_social,'')) AS nombret
			FROM
				(select
					foo.codigo_tipo,
					foo.orden,
					foo.char_cta,
					foo.nombre,
					foo.id_cta,
					foo.id_tercero,
					foo.ndocumento,
					foo.ndocumento_enlace,
					foo.id_prod_serv,
					foo.debe,
					foo.haber,
					foo.base,
					foo.terceros,
					foo.id_centrocosto,
					foo.detalle,					
					CASE WHEN foo.centro and foo.codigo_tipo IN ('EA','DC') THEN 'CCB1' ELSE c.codigo END AS codigo,
					foo.id_scentrocosto,
					foo.scentro,
					foo.centro,
					foo.vinculada,
					foo.edocumento,
					foo.retencion,
					foo.id_vinculo_movimiento
				FROM
					aux_libro_auxiliar_consulta AS foo
				LEFT OUTER JOIN
					centrocosto c
				ON
					foo.id_centrocosto=c.id_centrocosto) AS foo
			LEFT OUTER JOIN
				general g
			ON
				foo.id_tercero=g.id) AS foo
		LEFT OUTER JOIN
			(SELECT
				d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
				substring(case when id.ex_documento is null or id.ex_documento = '' then d.codigo_tipo||'-'||d.numero::bigint else d.codigo_tipo||'-'||d.numero::bigint||'/'||COALESCE(id.ex_documento,'') end,1,22) as numero_exdocumento,
				c.id_cta,
				c.idtercero,
				c.nfactura,
				c.ncomprobante,
				SUM(c.abono_comprobante) AS abono_comprobante,
				SUM(c.cargo_comprobante) AS cargo_comprobante
			 FROM
				documentos d,
				info_documento id,
				(select distinct a.id_tercero from aux_libro_auxiliar_consulta a) as a,
				cartera c
			 where
			 	c.idtercero = a.id_tercero and
			 	d.estado AND
				c.nfactura=d.ndocumento and
				d.ndocumento = id.ndocumento
			GROUP BY
				d.codigo_tipo||'-'||d.numero::BIGINT,
				id.ex_documento,
				c.id_cta,
				c.idtercero,
				c.nfactura,
				c.ncomprobante) AS doc
		ON
			doc.id_cta=foo.id_cta AND
			doc.nfactura=foo.ndocumento_enlace AND
			doc.ncomprobante=foo.ndocumento AND
			doc.idtercero=foo.id_tercero
		LEFT OUTER JOIN
			(select --este bloque se encarga de listar los documentos relacionados con el que se consulta en la nota, se agrega para completar la info cuando se llama a una dev en compra DC-2885 Feb 17 2025
				d.codigo_tipo||'-'||d.numero::BIGINT AS numero,
				substring(case when id.ex_documento is null or id.ex_documento = '' then d.codigo_tipo||'-'||d.numero::bigint else d.codigo_tipo||'-'||d.numero::bigint||'/'||COALESCE(id.ex_documento,'') end,1,22) as numero_exdocumento,
				c.id_cta,
				c.idtercero,
				c.nfactura,
				c.ncomprobante,
				SUM(c.abono_comprobante) AS abono_comprobante,
				SUM(c.cargo_comprobante) AS cargo_comprobante
			 FROM
				documentos d,
				info_documento id,
				(select distinct a.id_tercero from aux_libro_auxiliar_consulta a) as a,
				cartera c
			 where
			 	c.idtercero = a.id_tercero and
			 	d.estado AND
				c.nfactura=d.ndocumento and
				d.ndocumento = id.ndocumento
			GROUP by
				d.codigo_tipo||'-'||d.numero::BIGINT,
				id.ex_documento,
				c.id_cta,
				c.idtercero,
				c.nfactura,
				c.ncomprobante) AS doc2
		ON
			doc2.id_cta=foo.id_cta AND
			doc2.ncomprobante=foo.ndocumento and
			-- 25 Nov 2025: este bloque hace que si quieren editar una DC se muestre la entrada almacen a la que pertenece por medio del registro en cartera que estos dos documentos 
			-- comparten, se hace asi porque la dev en compra no enlaza a la EA en libro_auxiliar por medio de ndocumento_enlace, pero se evita que otros documentos hagan ese mismo 
			-- join porque se duplican los registros por eso el false en el else, si existe ndocumento_enlace no hay problema
			case when foo.ndocumento_enlace is not null then doc2.nfactura=foo.ndocumento_enlace when foo.ndocumento_enlace is null and foo.codigo_tipo = 'DC' then true else false end AND
			doc2.idtercero=foo.id_tercero
			) AS foo
	LEFT OUTER JOIN
		scentrocosto s
	ON
		s.id_scentrocosto = foo.id_scentrocosto
	ORDER BY
		orden) AS foo
LEFT OUTER JOIN
	vinculo_movimientos v
ON
	v.id_vinculo_movimiento = foo.id_vinculo_movimiento
ORDER BY
	foo.orden;