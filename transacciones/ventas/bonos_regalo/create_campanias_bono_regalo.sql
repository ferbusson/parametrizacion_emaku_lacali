-- public.campanias_bono_regalo definition

-- Drop table

-- DROP TABLE public.campanias_bono_regalo;

CREATE TABLE public.campanias_bono_regalo (
	id serial4 NOT NULL,
	descripcion varchar(50) NULL,
	codigo varchar(20) NULL,
	visible bool DEFAULT true NULL,
	CONSTRAINT unique_codigo UNIQUE (codigo)
);


-- public.activacion_bonos_regalo definition

-- Drop table

-- DROP TABLE public.activacion_bonos_regalo;

CREATE TABLE public.activacion_bonos_regalo (
	ndocumento int8 NULL,
	id_bono serial4 NOT NULL,
	franquicia varchar(50) NULL,
	codigo_campania varchar(12) NULL,
	codigo_bono_regalo varchar(20) NULL,
	telefono varchar(10) NULL,
	email varchar(41) NULL,
	CONSTRAINT activacion_bonos_regalo_codigo_campania_fkey FOREIGN KEY (codigo_campania) REFERENCES public.campanias_bono_regalo(codigo),
	CONSTRAINT activacion_bonos_regalo_ndocumento_fkey FOREIGN KEY (ndocumento) REFERENCES public.documentos(ndocumento)
);
