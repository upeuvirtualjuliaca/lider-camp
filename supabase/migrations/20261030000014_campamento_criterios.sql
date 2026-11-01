-- Tabla que registra qué criterios están activos para un campamento
-- SIN días ni puntajes — eso va en programacion
CREATE TABLE IF NOT EXISTS public.campamento_criterios (
  campamento_id uuid NOT NULL REFERENCES public.campamento(id) ON DELETE CASCADE,
  criterio_id   uuid NOT NULL REFERENCES public.criterios(id)   ON DELETE CASCADE,
  PRIMARY KEY (campamento_id, criterio_id)
);

ALTER TABLE public.campamento_criterios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "todos pueden leer campamento_criterios"
  ON public.campamento_criterios FOR SELECT USING (true);

CREATE POLICY "admin puede gestionar campamento_criterios"
  ON public.campamento_criterios
  FOR ALL
  USING (public.es_admin())
  WITH CHECK (public.es_admin());
