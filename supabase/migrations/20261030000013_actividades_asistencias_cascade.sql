-- =================================================================
-- Fix: agregar ON DELETE CASCADE a asistencia_registros.actividad_id
-- para completar la cadena de cascada:
--   programacion → actividades → asistencia_registros
-- =================================================================

ALTER TABLE public.asistencia_registros
  DROP CONSTRAINT IF EXISTS asistencia_registros_actividad_id_fkey;

ALTER TABLE public.asistencia_registros
  ADD CONSTRAINT asistencia_registros_actividad_id_fkey
  FOREIGN KEY (actividad_id) REFERENCES public.actividades(id)
  ON DELETE CASCADE;
