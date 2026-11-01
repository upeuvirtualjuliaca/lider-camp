-- =================================================================
-- Corregir acceso anon a vistas públicas
--
-- Problema: las vistas usan SECURITY INVOKER (default) por lo que
-- el rol anon debe pasar el RLS de las tablas subyacentes, donde
-- no tiene ninguna política definida.
--
-- Solución: recrear todas las vistas públicas con SECURITY DEFINER
-- para que ejecuten con los permisos del propietario (postgres) y
-- no requieran políticas RLS para anon en tablas internas.
-- =================================================================

-- 1. publico_campamento
CREATE OR REPLACE VIEW public.publico_campamento
WITH (security_invoker = false)
AS
SELECT id, nombre, edicion, activo
FROM public.campamento
WHERE activo = true;

GRANT SELECT ON public.publico_campamento TO anon, authenticated;

-- 2. publico_calendario (incluye abarca / no_abarca / evidencia)
CREATE OR REPLACE VIEW public.publico_calendario
WITH (security_invoker = false)
AS
SELECT
  c.id,
  c.codigo,
  c.nombre,
  c.categoria,
  c.tipo_calculo,
  c.abarca,
  c.no_abarca,
  c.evidencia,
  c.orden,
  p.campamento_id,
  p.momento,
  p.puntaje_max,
  p.estado
FROM public.criterios c
JOIN public.programacion p ON p.criterio_id = c.id
WHERE c.activo = true
  AND p.estado IN ('programado', 'cancelado');

GRANT SELECT ON public.publico_calendario TO anon, authenticated;

-- 3. publico_criterios (vista simple de criterios activos)
DROP VIEW IF EXISTS public.publico_criterios;
CREATE VIEW public.publico_criterios
WITH (security_invoker = false)
AS
SELECT id, codigo, nombre, categoria, tipo_calculo, abarca, no_abarca, evidencia, orden
FROM public.criterios
WHERE activo = true;

GRANT SELECT ON public.publico_criterios TO anon, authenticated;

-- 4. publico_liderazgo_indicadores
CREATE OR REPLACE VIEW public.publico_liderazgo_indicadores
WITH (security_invoker = false)
AS
SELECT codigo, nombre, descripcion, evidencia
FROM public.liderazgo_indicadores
WHERE activo = true
ORDER BY orden;

GRANT SELECT ON public.publico_liderazgo_indicadores TO anon, authenticated;

-- 5. incidencia_codigos — grant directo (la tabla es catálogo público)
GRANT SELECT ON public.incidencia_codigos TO anon;

-- Política RLS para que anon pueda leer incidencia_codigos
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'incidencia_codigos'
      AND policyname = 'anon lee incidencia_codigos'
  ) THEN
    EXECUTE 'CREATE POLICY "anon lee incidencia_codigos"
      ON public.incidencia_codigos FOR SELECT TO anon
      USING (activo = true)';
  END IF;
END$$;
