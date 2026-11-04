-- Vista pública de ranking por día (solo días cerrados) basada únicamente en Rúbrica.
-- Usada por la vista pública de ranking (/ranking) para mostrar tabs por día.

CREATE OR REPLACE VIEW public.publico_ranking_dia
WITH (security_invoker = false)
AS
SELECT
  r.equipo_id,
  e.campamento_id,
  e.nombre  AS equipo_nombre,
  e.color   AS equipo_color,
  r.momento,
  COALESCE(r.suma_puntaje, 0)::integer AS pts_rubrica,
  RANK() OVER (
    PARTITION BY e.campamento_id, r.momento
    ORDER BY COALESCE(r.suma_puntaje, 0) DESC
  )::integer AS posicion
FROM public.v_puntaje_rubrica_equipo_dia r
JOIN public.equipos e ON e.id = r.equipo_id
JOIN public.dias_evaluacion d
     ON d.campamento_id = e.campamento_id AND d.momento = r.momento
WHERE d.cerrado = true
  AND e.activo  = true;

GRANT SELECT ON public.publico_ranking_dia TO anon, authenticated;
