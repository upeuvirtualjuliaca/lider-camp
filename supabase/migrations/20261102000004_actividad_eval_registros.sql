-- =============================================================================
-- Tabla actividad_eval_registros
-- Guarda el puntaje que obtuvo cada equipo en cada criterio de evaluación
-- de una actividad (ej: Equipo Alfa obtuvo 18/20 en Puntualidad).
-- =============================================================================

CREATE TABLE public.actividad_eval_registros (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actividad_id     uuid        NOT NULL REFERENCES public.actividades(id)             ON DELETE CASCADE,
  criterio_eval_id uuid        NOT NULL REFERENCES public.actividad_criterios_eval(id) ON DELETE CASCADE,
  equipo_id        uuid        NOT NULL REFERENCES public.equipos(id)                 ON DELETE CASCADE,
  puntaje          numeric     NOT NULL CHECK (puntaje >= 0),
  comentario       text,
  evaluador_id     uuid        NOT NULL REFERENCES public.perfiles(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (criterio_eval_id, equipo_id)
);

CREATE INDEX idx_eval_reg_actividad  ON public.actividad_eval_registros (actividad_id);
CREATE INDEX idx_eval_reg_equipo     ON public.actividad_eval_registros (equipo_id);

CREATE TRIGGER tr_actividad_eval_registros_updated_at
  BEFORE UPDATE ON public.actividad_eval_registros
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_actividad_eval_registros_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.actividad_eval_registros
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- RLS
ALTER TABLE public.actividad_eval_registros ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticados leen eval registros"
  ON public.actividad_eval_registros FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "autenticados insertan eval registros"
  ON public.actividad_eval_registros FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "autenticados actualizan eval registros"
  ON public.actividad_eval_registros FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "admin elimina eval registros"
  ON public.actividad_eval_registros FOR DELETE
  TO authenticated USING (public.es_admin());

REVOKE ALL ON public.actividad_eval_registros FROM anon;
