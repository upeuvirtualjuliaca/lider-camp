-- =============================================================================
-- Tabla actividad_criterios_eval
-- Almacena los criterios de evaluación de una actividad (ej: Puntualidad 20pts,
-- Asistencia 30pts…). La suma de puntaje_max debe ser igual al puntaje_max de
-- la programación vinculada a la actividad — validación en la app.
-- =============================================================================

CREATE TABLE public.actividad_criterios_eval (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actividad_id uuid        NOT NULL REFERENCES public.actividades(id) ON DELETE CASCADE,
  nombre       text        NOT NULL CHECK (trim(nombre) <> ''),
  puntaje_max  numeric     NOT NULL CHECK (puntaje_max >= 0),
  orden        int         NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_actividad_criterios_eval_actividad
  ON public.actividad_criterios_eval (actividad_id);

CREATE TRIGGER tr_actividad_criterios_eval_updated_at
  BEFORE UPDATE ON public.actividad_criterios_eval
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Auditoría
CREATE TRIGGER tr_actividad_criterios_eval_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.actividad_criterios_eval
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- RLS
ALTER TABLE public.actividad_criterios_eval ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin gestiona criterios eval"
  ON public.actividad_criterios_eval FOR ALL
  TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());

CREATE POLICY "evaluador lee criterios eval"
  ON public.actividad_criterios_eval FOR SELECT
  TO authenticated USING (true);

REVOKE ALL ON public.actividad_criterios_eval FROM anon;
