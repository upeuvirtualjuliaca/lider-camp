-- =================================================================
-- Módulo 3 (extensión): Plantillas de criterios
-- Tablas:    plantillas_criterios, plantilla_items
-- Función:   aplicar_plantilla_a_campamento
-- =================================================================

-- -----------------------------------------------------------------
-- 1. TABLA plantillas_criterios (cabecera de cada plantilla)
-- -----------------------------------------------------------------
CREATE TABLE public.plantillas_criterios (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      text        NOT NULL,
  descripcion text,
  activo      boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_plantillas_criterios_updated_at
  BEFORE UPDATE ON public.plantillas_criterios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.plantillas_criterios ENABLE ROW LEVEL SECURITY;

-- Lectura: cualquier autenticado
CREATE POLICY "plantillas_select"
  ON public.plantillas_criterios FOR SELECT TO authenticated USING (true);

-- Escritura: solo admin
CREATE POLICY "plantillas_insert"
  ON public.plantillas_criterios FOR INSERT TO authenticated
  WITH CHECK ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY "plantillas_update"
  ON public.plantillas_criterios FOR UPDATE TO authenticated
  USING ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY "plantillas_delete"
  ON public.plantillas_criterios FOR DELETE TO authenticated
  USING ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

-- -----------------------------------------------------------------
-- 2. TABLA plantilla_items (criterios + días de una plantilla)
-- -----------------------------------------------------------------
CREATE TABLE public.plantilla_items (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  plantilla_id uuid        NOT NULL REFERENCES public.plantillas_criterios(id) ON DELETE CASCADE,
  criterio_id  uuid        NOT NULL REFERENCES public.criterios(id) ON DELETE CASCADE,
  momento      text        NOT NULL CHECK (momento IN ('J','V','S','D','UNICO')),
  puntaje_max  int         NOT NULL DEFAULT 100 CHECK (puntaje_max >= 0),
  estado       text        NOT NULL DEFAULT 'programado'
                           CHECK (estado IN ('programado','no_programado','cancelado')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(plantilla_id, criterio_id, momento)
);

ALTER TABLE public.plantilla_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plantilla_items_select"
  ON public.plantilla_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "plantilla_items_insert"
  ON public.plantilla_items FOR INSERT TO authenticated
  WITH CHECK ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY "plantilla_items_update"
  ON public.plantilla_items FOR UPDATE TO authenticated
  USING ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY "plantilla_items_delete"
  ON public.plantilla_items FOR DELETE TO authenticated
  USING ((SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'admin');

-- -----------------------------------------------------------------
-- 3. FUNCIÓN aplicar_plantilla_a_campamento
--    Recibe los items (posiblemente modificados en memoria) como JSONB
--    y los upsertea en la tabla programacion para el campamento dado.
--    Devuelve el número de filas procesadas.
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aplicar_plantilla_a_campamento(
  p_campamento_id uuid,
  p_items         jsonb   -- [{criterio_id, momento, puntaje_max, estado}, ...]
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_item  jsonb;
  v_count int := 0;
BEGIN
  -- Solo admin puede aplicar
  IF (SELECT rol FROM public.perfiles WHERE id = auth.uid()) <> 'admin' THEN
    RAISE EXCEPTION 'Solo administradores pueden aplicar plantillas';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.programacion (campamento_id, criterio_id, momento, puntaje_max, estado)
    VALUES (
      p_campamento_id,
      (v_item->>'criterio_id')::uuid,
       v_item->>'momento',
      (v_item->>'puntaje_max')::int,
       v_item->>'estado'
    )
    ON CONFLICT (criterio_id, momento, campamento_id) DO UPDATE SET
      puntaje_max = EXCLUDED.puntaje_max,
      estado      = EXCLUDED.estado,
      updated_at  = now();

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
