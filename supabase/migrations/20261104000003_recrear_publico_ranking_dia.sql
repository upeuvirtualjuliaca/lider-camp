-- =============================================================================
-- Recrea publico_ranking_dia que fue eliminada por CASCADE en la migración
-- 20261104000001 (DROP VIEW v_puntaje_rubrica_equipo_dia CASCADE).
-- actividades_dia usa AVG por evaluador antes de sumar entre criterios.
-- =============================================================================

DROP VIEW IF EXISTS public.publico_ranking_dia;

CREATE VIEW public.publico_ranking_dia
WITH (security_invoker = false)
AS
WITH
actividades_dia AS (
  SELECT
    equipo_id,
    momento,
    SUM(puntaje_promedio)::integer AS pts_actividades
  FROM (
    SELECT
      aer.equipo_id,
      p.momento,
      aer.criterio_eval_id,
      AVG(aer.puntaje) AS puntaje_promedio
    FROM public.actividad_eval_registros aer
    JOIN public.actividades act ON act.id = aer.actividad_id AND act.estado != 'cancelada'
    JOIN public.programacion p  ON p.id   = act.programacion_id
    GROUP BY aer.equipo_id, p.momento, aer.criterio_eval_id
  ) sub
  GROUP BY equipo_id, momento
),
bonus_dia AS (
  SELECT
    i.equipo_id,
    i.momento,
    COALESCE(SUM(i.puntos), 0)::integer AS pts_bonus
  FROM public.incidencias i
  JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo AND ic.tipo = 'bonus'
  WHERE i.estado = 'validado'
  GROUP BY i.equipo_id, i.momento
),
demeritos_dia AS (
  SELECT
    i.equipo_id,
    i.momento,
    COALESCE(SUM(i.puntos), 0)::integer AS pts_demeritos
  FROM public.incidencias i
  JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo AND ic.tipo = 'demerito'
  WHERE i.estado = 'validado'
  GROUP BY i.equipo_id, i.momento
)
SELECT
  r.equipo_id,
  e.campamento_id,
  e.nombre AS equipo_nombre,
  e.color  AS equipo_color,
  r.momento,
  COALESCE(r.suma_puntaje, 0)::integer   AS pts_rubrica,
  COALESCE(ad.pts_actividades, 0)         AS pts_actividades,
  COALESCE(bd.pts_bonus, 0)              AS pts_bonus,
  COALESCE(dd.pts_demeritos, 0)          AS pts_demeritos,
  CASE
    WHEN c.cerrado = true
    THEN GREATEST(0,
           COALESCE(r.suma_puntaje, 0)::integer
           + COALESCE(ad.pts_actividades, 0)
           + COALESCE(bd.pts_bonus, 0)
           - COALESCE(dd.pts_demeritos, 0))
    ELSE COALESCE(r.suma_puntaje, 0)::integer
  END AS pts_total,
  RANK() OVER (
    PARTITION BY e.campamento_id, r.momento
    ORDER BY
      CASE
        WHEN c.cerrado = true
        THEN GREATEST(0,
               COALESCE(r.suma_puntaje, 0)::integer
               + COALESCE(ad.pts_actividades, 0)
               + COALESCE(bd.pts_bonus, 0)
               - COALESCE(dd.pts_demeritos, 0))
        ELSE COALESCE(r.suma_puntaje, 0)::integer
      END DESC
  )::integer AS posicion
FROM public.v_puntaje_rubrica_equipo_dia r
JOIN public.equipos e ON e.id = r.equipo_id
JOIN public.campamento c ON c.id = e.campamento_id
JOIN public.dias_evaluacion d
     ON d.campamento_id = e.campamento_id AND d.momento = r.momento
LEFT JOIN actividades_dia ad ON ad.equipo_id = r.equipo_id AND ad.momento = r.momento
LEFT JOIN bonus_dia       bd ON bd.equipo_id = r.equipo_id AND bd.momento = r.momento
LEFT JOIN demeritos_dia   dd ON dd.equipo_id = r.equipo_id AND dd.momento = r.momento
WHERE d.cerrado = true
  AND e.activo  = true;

GRANT SELECT ON public.publico_ranking_dia TO anon, authenticated;
