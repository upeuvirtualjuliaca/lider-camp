-- Fix: permitir puntaje_max = 0 para días cancelados
-- El constraint anterior (puntaje_max > 0) impedía guardar estado='cancelado'

ALTER TABLE public.programacion
  DROP CONSTRAINT IF EXISTS programacion_puntaje_max_check;

ALTER TABLE public.programacion
  ADD CONSTRAINT programacion_puntaje_max_check
  CHECK (puntaje_max >= 0);
