-- =============================================================================
-- Vista pública: actividades del campamento (no canceladas)
-- Expone solo: campamento_id, momento, hora_inicio, nombre, lugar
-- Sin datos internos (evaluador_id, descripción, motivo_cancelacion).
-- =============================================================================

CREATE OR REPLACE VIEW public.publico_actividades AS
SELECT
  a.id,
  p.campamento_id,
  p.momento,
  a.hora_inicio,
  a.nombre,
  a.lugar
FROM public.actividades a
JOIN public.programacion p ON p.id = a.programacion_id
WHERE a.estado != 'cancelada';

GRANT SELECT ON public.publico_actividades TO anon, authenticated;
