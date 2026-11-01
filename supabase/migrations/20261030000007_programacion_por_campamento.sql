-- Migration: programacion_por_campamento
-- Adds campamento_id to programacion, updates unique constraint,
-- adds index, RPC for initialization, and recreates affected views.

-- ── 1. Add campamento_id (nullable first) ─────────────────────────────────────
ALTER TABLE public.programacion
  ADD COLUMN IF NOT EXISTS campamento_id uuid REFERENCES public.campamento(id) ON DELETE CASCADE;

-- ── 2. Backfill: assign the active (or oldest) campamento ─────────────────────
UPDATE public.programacion
SET campamento_id = (
  SELECT id FROM public.campamento
  ORDER BY activo DESC, created_at ASC
  LIMIT 1
)
WHERE campamento_id IS NULL;

-- ── 3. Now make it NOT NULL ────────────────────────────────────────────────────
ALTER TABLE public.programacion
  ALTER COLUMN campamento_id SET NOT NULL;

-- ── 4. Drop old unique constraint ─────────────────────────────────────────────
ALTER TABLE public.programacion
  DROP CONSTRAINT IF EXISTS programacion_criterio_id_momento_key;

-- ── 5. New unique constraint scoped to campamento ─────────────────────────────
ALTER TABLE public.programacion
  ADD CONSTRAINT programacion_criterio_momento_campamento_key
    UNIQUE (criterio_id, momento, campamento_id);

-- ── 6. Index for campamento lookups ───────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_programacion_campamento
  ON public.programacion(campamento_id);

-- ── 7. RPC: inicializar_programacion_campamento ───────────────────────────────
CREATE OR REPLACE FUNCTION public.inicializar_programacion_campamento(
  p_campamento_id     uuid,
  p_source_campamento_id uuid DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_source_id   uuid;
  v_inserted    int;
BEGIN
  -- If target already has rows, return 0 (idempotent guard)
  IF EXISTS (
    SELECT 1 FROM public.programacion WHERE campamento_id = p_campamento_id
  ) THEN
    RETURN 0;
  END IF;

  -- Determine source: explicit or the campamento with most programacion rows
  IF p_source_campamento_id IS NOT NULL THEN
    v_source_id := p_source_campamento_id;
  ELSE
    SELECT campamento_id
    INTO v_source_id
    FROM public.programacion
    WHERE campamento_id <> p_campamento_id
    GROUP BY campamento_id
    ORDER BY count(*) DESC
    LIMIT 1;
  END IF;

  -- Nothing to copy
  IF v_source_id IS NULL THEN
    RETURN 0;
  END IF;

  -- Copy rows from source to target
  INSERT INTO public.programacion (
    id,
    criterio_id,
    campamento_id,
    momento,
    puntaje_max,
    estado,
    motivo,
    created_at,
    updated_at
  )
  SELECT
    gen_random_uuid(),
    criterio_id,
    p_campamento_id,
    momento,
    puntaje_max,
    estado,
    motivo,
    now(),
    now()
  FROM public.programacion
  WHERE campamento_id = v_source_id;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

-- Revoke broad access, grant only to authenticated users
REVOKE ALL ON FUNCTION public.inicializar_programacion_campamento(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inicializar_programacion_campamento(uuid, uuid) TO authenticated;

-- ── 8. Recreate v_resumen_programacion ────────────────────────────────────────
DROP VIEW IF EXISTS public.v_resumen_programacion CASCADE;

CREATE VIEW public.v_resumen_programacion
WITH (security_invoker = true)
AS
SELECT
  p.campamento_id,
  p.momento,
  c.categoria,
  count(*)::int                                                        AS total_filas,
  sum(CASE WHEN p.estado = 'programado' THEN p.puntaje_max ELSE 0 END)
    AS maximo_programado,
  sum(CASE WHEN p.estado = 'cancelado'  THEN 1 ELSE 0 END)::int       AS cancelados
FROM public.programacion p
JOIN public.criterios c ON c.id = p.criterio_id
GROUP BY GROUPING SETS (
  (p.campamento_id, p.momento, c.categoria),
  (p.campamento_id, p.momento),
  (p.campamento_id, c.categoria),
  (p.campamento_id)
);

-- ── 9. Recreate publico_calendario ────────────────────────────────────────────
DROP VIEW IF EXISTS public.publico_calendario CASCADE;

CREATE VIEW public.publico_calendario AS
SELECT
  c.id,
  c.codigo,
  c.nombre,
  c.categoria,
  c.tipo_calculo,
  c.orden,
  p.campamento_id,
  p.momento,
  p.puntaje_max,
  p.estado
FROM public.criterios c
JOIN public.programacion p ON p.criterio_id = c.id
WHERE c.activo = true
  AND p.estado IN ('programado', 'cancelado');

GRANT SELECT ON public.publico_calendario TO anon;

-- ── 10. RLS insert policy for programacion ────────────────────────────────────
DROP POLICY IF EXISTS programacion_insert_admin ON public.programacion;

CREATE POLICY programacion_insert_admin
  ON public.programacion
  FOR INSERT
  WITH CHECK (public.es_admin());
