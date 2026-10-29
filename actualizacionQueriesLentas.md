Grupo A — Formulario DGTR00082 "Nuevo arqueo modificado"

  ┌─────┬───────────┬─────────┬─────────────────────────────────────────────────────────────────────────────────────┬────────────────────┐
  │  #  │   Code    │ ms orig │                                Script de despliegue                                 │ Confirmado en prod │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 1   │ MTSEL0267 │ 74 548  │ queries/caja/MTSEL0267_update_sentencia_sql.sql                                     │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 2   │ MTSEL0270 │ 68 251  │ queries/caja/MTSEL0270_update_sentencia_sql.sql                                     │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 3   │ MTSEL0268 │ 33 698  │ queries/caja/MTSEL0268_update_sentencia_sql.sql                                     │ ✅ 8 s → 0.5 s     │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 4   │ LCSEL0152 │ 32 666  │ queries/caja/LCSEL0151_LCSEL0152_update_sentencia_sql.sql (uno solo para 151 + 152) │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 5   │ MTSEL0269 │ 31 966  │ queries/caja/MTSEL0269_update_sentencia_sql.sql                                     │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 6   │ LCSEL0151 │ 31 743  │ (incluido en el script de 152 arriba)                                               │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────────────────────────────────────────┼────────────────────┤
  │ 9   │ DGSEL0048 │ 13 906  │ queries/caja/DGSEL0048_update_sentencia_sql.sql                                     │ ⏳ pendiente       │
  └─────┴───────────┴─────────┴─────────────────────────────────────────────────────────────────────────────────────┴────────────────────┘

  Grupo B — Formulario MTR00238 "Nuevo informe diario de facturación por almacén"

  ┌─────┬───────────┬─────────┬─────────────────────────────────────────────────┬────────────────────┐
  │  #  │   Code    │ ms orig │              Script de despliegue               │ Confirmado en prod │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────┼────────────────────┤
  │ 7   │ LCSEL0164 │ 16 367  │ queries/caja/LCSEL0164_update_sentencia_sql.sql │ ✅ 16 s → 6 s      │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────┼────────────────────┤
  │ 8   │ LCSEL0177 │ 15 915  │ queries/caja/LCSEL0177_update_sentencia_sql.sql │ ✅ 6 s → 2 s       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────┼────────────────────┤
  │ 10  │ LCSEL0166 │ 12 186  │ queries/caja/LCSEL0166_update_sentencia_sql.sql │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────┼────────────────────┤
  │ 12  │ LCSEL0167 │ 11 452  │ queries/caja/LCSEL0167_update_sentencia_sql.sql │ ⏳ pendiente       │
  ├─────┼───────────┼─────────┼─────────────────────────────────────────────────┼────────────────────┤
  │ 13  │ LCSEL0168 │ 10 021  │ queries/caja/LCSEL0168_update_sentencia_sql.sql │ ⏳ pendiente       │
  └─────┴───────────┴─────────┴─────────────────────────────────────────────────┴────────────────────┘

  Totales

  - 12 sentencias optimizadas (7 grupo A + 5 grupo B).
  - 11 scripts de despliegue (porque LCSEL0151 y LCSEL0152 van en uno solo).
  - Confirmadas en prod: 3 (MTSEL0268, LCSEL0164, LCSEL0177).
  - Pendientes de confirmar: 9.

  Proceso para cada script

  1. Correrlo con rol que tenga UPDATE sobre sentencia_sql (emaku_query_lab sólo tiene SELECT).
  2. Revisar el SELECT final que muestra el nuevo LEFT(sentencia, 200) para confirmar el contenido.
  3. Cambiar ROLLBACK; por COMMIT; para persistir.
  4. Medir en prod corriendo la sentencia desde el formulario correspondiente.
