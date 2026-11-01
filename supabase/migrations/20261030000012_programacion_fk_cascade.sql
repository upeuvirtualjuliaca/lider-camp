-- =================================================================
-- Fix: agregar ON DELETE CASCADE a las FKs que apuntan a programacion
-- para permitir que aplicar_plantilla_a_campamento elimine filas
-- sin violar restricciones de integridad referencial.
-- Tablas afectadas: observaciones, actividades (asistencia)
-- liderazgo_evaluaciones ya tenía ON DELETE CASCADE.
-- =================================================================

-- 1. observaciones.programacion_id
ALTER TABLE public.observaciones
  DROP CONSTRAINT IF EXISTS observaciones_programacion_id_fkey;

ALTER TABLE public.observaciones
  ADD CONSTRAINT observaciones_programacion_id_fkey
  FOREIGN KEY (programacion_id) REFERENCES public.programacion(id)
  ON DELETE CASCADE;

-- 2. actividades.programacion_id (módulo asistencia)
ALTER TABLE public.actividades
  DROP CONSTRAINT IF EXISTS actividades_programacion_id_fkey;

ALTER TABLE public.actividades
  ADD CONSTRAINT actividades_programacion_id_fkey
  FOREIGN KEY (programacion_id) REFERENCES public.programacion(id)
  ON DELETE CASCADE;
