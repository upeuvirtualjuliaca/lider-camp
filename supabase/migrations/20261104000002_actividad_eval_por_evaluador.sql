-- =============================================================================
-- Opción B para actividades: cada evaluador guarda su propio puntaje.
-- El puntaje final es el PROMEDIO automático de todos los evaluadores
-- por cada (criterio, equipo), luego se suma entre criterios.
-- =============================================================================

ALTER TABLE public.actividad_eval_registros
  DROP CONSTRAINT IF EXISTS actividad_eval_registros_criterio_eval_id_equipo_id_key;

ALTER TABLE public.actividad_eval_registros
  ADD CONSTRAINT actividad_eval_registros_criterio_equipo_eval_key
  UNIQUE (criterio_eval_id, equipo_id, evaluador_id);
