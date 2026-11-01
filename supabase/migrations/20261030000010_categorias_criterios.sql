-- =================================================================
-- Módulo 3 — extensión: tabla de categorías dinámicas
-- Elimina el CHECK hardcodeado en criterios.categoria
-- Crea la tabla categorias_criterios y FK opcional
-- =================================================================

-- 1. Quitar el CHECK constraint hardcodeado en criterios.categoria
ALTER TABLE public.criterios
  DROP CONSTRAINT IF EXISTS criterios_categoria_check;

-- 2. Tabla de categorías
CREATE TABLE IF NOT EXISTS public.categorias_criterios (
  clave   text    PRIMARY KEY,            -- slug corto, ej: 'armado'
  nombre  text    NOT NULL,               -- label visible, ej: 'Armado de campamento'
  color   text    NOT NULL DEFAULT 'slate', -- nombre Tailwind base, ej: 'indigo', 'emerald'
  orden   int     NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 3. Trigger de updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at_categorias()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_categorias_criterios_updated_at
  BEFORE UPDATE ON public.categorias_criterios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_categorias();

-- 5. RLS
ALTER TABLE public.categorias_criterios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "todos pueden leer categorias"
  ON public.categorias_criterios FOR SELECT
  USING (true);

CREATE POLICY "admin puede insertar categorias"
  ON public.categorias_criterios FOR INSERT
  WITH CHECK (public.es_admin());

CREATE POLICY "admin puede actualizar categorias"
  ON public.categorias_criterios FOR UPDATE
  USING (public.es_admin());

CREATE POLICY "admin puede eliminar categorias"
  ON public.categorias_criterios FOR DELETE
  USING (public.es_admin());

-- 6. Seed de las 5 categorías que ya existen en los datos
INSERT INTO public.categorias_criterios (clave, nombre, color, orden) VALUES
  ('inscripcion',               'Inscripción',               'violet',  1),
  ('armado',                    'Armado de campamento',      'amber',   2),
  ('orden_cocina',              'Orden y cocina',            'emerald', 3),
  ('ceremonias_participacion',  'Ceremonias y participación','sky',     4),
  ('liderazgo',                 'Liderazgo',                 'rose',    5)
ON CONFLICT (clave) DO NOTHING;

-- 7. Agregar FK (después del seed para no violar la constraint)
ALTER TABLE public.criterios
  ADD CONSTRAINT criterios_categoria_fk
  FOREIGN KEY (categoria) REFERENCES public.categorias_criterios(clave)
  ON UPDATE CASCADE;
