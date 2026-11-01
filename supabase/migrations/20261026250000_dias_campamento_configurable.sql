-- =================================================================
-- Días del campamento configurables
-- Reemplaza las 4 columnas fijas (fecha_jueves/viernes/sabado/domingo)
-- por una tabla flexible dias_campamento.
-- =================================================================


-- -----------------------------------------------------------------
-- 1. TABLA dias_campamento
-- -----------------------------------------------------------------
CREATE TABLE public.dias_campamento (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  campamento_id uuid        NOT NULL REFERENCES public.campamento(id) ON DELETE CASCADE,
  codigo        text        NOT NULL,   -- código corto: 'J', 'X', 'L', etc.
  nombre        text        NOT NULL,   -- nombre completo: 'Jueves', 'Miércoles'
  fecha         date        NOT NULL,
  orden         int         NOT NULL DEFAULT 1,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campamento_id, codigo),
  UNIQUE (campamento_id, fecha)
);

ALTER TABLE public.dias_campamento ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_dias_campamento_updated_at
  BEFORE UPDATE ON public.dias_campamento
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Admin gestiona, cualquier autenticado puede leer
CREATE POLICY "Admin gestiona dias_campamento"
  ON public.dias_campamento FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee dias_campamento"
  ON public.dias_campamento FOR SELECT TO authenticated
  USING (true);


-- -----------------------------------------------------------------
-- 2. Migrar datos existentes de campamento → dias_campamento
-- -----------------------------------------------------------------
DO $$
DECLARE
  v_id uuid;
  v_j  date;
  v_v  date;
  v_s  date;
  v_d  date;
BEGIN
  SELECT id, fecha_jueves, fecha_viernes, fecha_sabado, fecha_domingo
    INTO v_id, v_j, v_v, v_s, v_d
    FROM public.campamento WHERE solo_fila = true;

  IF v_id IS NOT NULL THEN
    INSERT INTO public.dias_campamento (campamento_id, codigo, nombre, fecha, orden) VALUES
      (v_id, 'J', 'Jueves',  v_j, 1),
      (v_id, 'V', 'Viernes', v_v, 2),
      (v_id, 'S', 'Sábado',  v_s, 3),
      (v_id, 'D', 'Domingo', v_d, 4)
    ON CONFLICT (campamento_id, codigo) DO NOTHING;
  END IF;
END $$;


-- -----------------------------------------------------------------
-- 3. Eliminar columnas fijas de campamento
-- -----------------------------------------------------------------
ALTER TABLE public.campamento
  DROP COLUMN IF EXISTS fecha_jueves,
  DROP COLUMN IF EXISTS fecha_viernes,
  DROP COLUMN IF EXISTS fecha_sabado,
  DROP COLUMN IF EXISTS fecha_domingo;


-- -----------------------------------------------------------------
-- 4. Quitar CHECKs hardcodeados de momento
--    (validación ahora es responsabilidad del trigger/UI)
-- -----------------------------------------------------------------
ALTER TABLE public.programacion    DROP CONSTRAINT IF EXISTS programacion_momento_check;
ALTER TABLE public.dias_evaluacion DROP CONSTRAINT IF EXISTS dias_evaluacion_momento_check;
