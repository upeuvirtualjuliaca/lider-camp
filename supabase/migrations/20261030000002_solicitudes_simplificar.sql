-- =================================================================
-- Simplificar solicitudes_revision: registro_id pasa a nullable
-- para que evaluadores no necesiten conocer el UUID del registro.
-- =================================================================

ALTER TABLE public.solicitudes_revision
  ALTER COLUMN registro_id DROP NOT NULL;
