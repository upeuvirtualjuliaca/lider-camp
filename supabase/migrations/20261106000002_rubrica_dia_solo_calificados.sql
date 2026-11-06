-- =============================================================================
-- Actualiza publico_rubrica_dia para retornar SOLO criterios con observación
-- registrada (INNER JOIN en lugar de LEFT JOIN).
-- Antes devolvía todos los criterios programados con puntaje 0 por defecto.
-- =============================================================================

CREATE OR REPLACE VIEW public.publico_rubrica_dia AS
SELECT
  e.id                        AS equipo_id,
  e.campamento_id,
  c.codigo                    AS criterio_codigo,
  c.nombre                    AS criterio_nombre,
  c.orden,
  p.momento,
  o.puntaje::integer          AS puntaje,
  p.puntaje_max::integer      AS puntaje_max
FROM public.programacion p
JOIN  public.criterios c
      ON  c.id           = p.criterio_id
      AND c.activo       = true
      AND c.tipo_calculo = 'rubrica'
JOIN  public.equipos e
      ON  e.campamento_id = p.campamento_id
      AND e.activo        = true
JOIN  public.observaciones o
      ON  o.programacion_id = p.id
      AND o.equipo_id       = e.id
WHERE p.estado = 'programado';

GRANT SELECT ON public.publico_rubrica_dia TO anon, authenticated;
