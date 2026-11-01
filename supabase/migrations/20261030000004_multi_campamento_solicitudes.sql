-- =================================================================
-- Multi-campamento (parte 2): campamento_id en solicitudes_revision
-- =================================================================


-- -----------------------------------------------------------------
-- 1. Agregar campamento_id (nullable para hacer backfill)
-- -----------------------------------------------------------------
ALTER TABLE public.solicitudes_revision
  ADD COLUMN IF NOT EXISTS campamento_id uuid REFERENCES public.campamento(id) ON DELETE CASCADE;

-- Backfill: asignar el campamento activo más reciente a las solicitudes existentes
UPDATE public.solicitudes_revision
   SET campamento_id = (
     SELECT id FROM public.campamento
     ORDER BY activo DESC, created_at DESC
     LIMIT 1
   )
 WHERE campamento_id IS NULL;

-- Imponer NOT NULL
ALTER TABLE public.solicitudes_revision
  ALTER COLUMN campamento_id SET NOT NULL;


-- -----------------------------------------------------------------
-- 2. Índice para filtrar por campamento
-- -----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_sr_campamento
  ON public.solicitudes_revision (campamento_id);
