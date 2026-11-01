-- =================================================================
-- Vistas y grants para la página pública /reglas
-- 1. publico_campamento   — campamento activo visible para anon
-- 2. publico_calendario   — recrear con abarca / no_abarca / evidencia
-- 3. incidencia_codigos   — grant SELECT a anon (bonus y deméritos)
-- =================================================================

-- 1. Vista: campamento activo (solo datos no sensibles)
CREATE OR REPLACE VIEW public.publico_campamento AS
SELECT
  id,
  nombre,
  edicion,
  activo
FROM public.campamento
WHERE activo = true;

GRANT SELECT ON public.publico_campamento TO anon, authenticated;


-- 2. Recrear publico_calendario con abarca / no_abarca / evidencia
DROP VIEW IF EXISTS public.publico_calendario CASCADE;

CREATE VIEW public.publico_calendario AS
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


-- 3. Grant SELECT en incidencia_codigos a anon
--    (solo lectura del catálogo público: código, nombre, puntos, tope)
GRANT SELECT ON public.incidencia_codigos TO anon;
