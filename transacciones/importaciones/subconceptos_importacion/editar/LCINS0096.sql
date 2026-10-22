DROP TABLE IF EXISTS aux_act_conceptos_imp; --?
CREATE TABLE aux_act_conceptos_imp
(
  id_grupo INTEGER,
  descripcion CHARACTER(50),
  naturaleza BOOLEAN,
  id_cta INTEGER,
  id_concepto_importacion INTEGER,
  id_asiento_generico INTEGER,
  id_cta_retencion INTEGER,
  codigo CHARACTER(14),
  id_categoria_costo SMALLINT
);