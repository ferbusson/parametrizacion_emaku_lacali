-- public.campanias_bono_regalo definition

-- Drop table

-- DROP TABLE public.campanias_bono_regalo;

CREATE TABLE public.campanias_bono_regalo (
	id serial NOT NULL,
	descripcion varchar(50) NULL,
	codigo varchar(20) NULL,
	visible bool DEFAULT true NULL
);

alter table campanias_bono_regalo add constraint unique_codigo unique(codigo);


-- public.activacion_bonos_regalo definition

-- Drop table

-- DROP TABLE public.activacion_bonos_regalo;

CREATE TABLE public.activacion_bonos_regalo (
	ndocumento bigint references documentos(ndocumento),
	id_bono serial4 NOT NULL,
	franquicia varchar(50) NULL,
	codigo_campania varchar(12) NULL,
	codigo_bono_regalo varchar(20) NULL,
	telefono varchar(10) NULL,
	email varchar(41) NULL,
	CONSTRAINT activacion_bonos_regalo_codigo_campania_fkey FOREIGN KEY (codigo_campania) REFERENCES public.campanias_bono_regalo(codigo)
);