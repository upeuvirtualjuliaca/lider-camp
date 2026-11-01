-- =================================================================
-- Corregir CROSS JOIN en vistas de rúbrica y progreso
-- Para multi-campamento, equipos y programacion deben joinarse
-- por campamento_id, no con producto cartesiano.
-- =================================================================

-- 1. v_puntaje_rubrica_equipo_dia — JOIN por campamento_id, exponer campamento_id
DROP VIEW IF EXISTS public.v_puntaje_rubrica_equipo_dia CASCADE;
-- (CASCADE elimina v_puntaje_equipo que depende de esta vista)

CREATE OR REPLACE VIEW public.v_puntaje_rubrica_equipo_dia AS
SELECT
  e.id                                            AS equipo_id,
  e.nombre                                        AS equipo_nombre,
  e.color                                         AS equipo_color,
  e.campamento_id,
  p.momento,
  COALESCE(SUM(o.puntaje), 0)::integer            AS suma_puntaje,
  SUM(p.puntaje_max)::integer                     AS maximo_posible,
  COUNT(o.id)::integer                            AS criterios_calificados,
  (COUNT(p.id) - COUNT(o.id))::integer            AS criterios_pendientes
FROM public.programacion p
JOIN public.criterios c ON c.id = p.criterio_id
JOIN public.equipos e ON e.campamento_id = p.campamento_id
LEFT JOIN public.observaciones o
       ON o.programacion_id = p.id
      AND o.equipo_id       = e.id
WHERE p.estado       = 'programado'
  AND c.tipo_calculo = 'rubrica'
  AND c.activo       = true
  AND e.activo       = true
GROUP BY e.id, e.nombre, e.color, e.campamento_id, p.momento;

-- 2. v_progreso_evaluacion — agregar campamento_id
DROP VIEW IF EXISTS public.v_progreso_evaluacion CASCADE;

CREATE OR REPLACE VIEW public.v_progreso_evaluacion AS
WITH base AS (
  SELECT
    p.id            AS prog_id,
    p.campamento_id,
    p.momento,
    e.id            AS equipo_id
  FROM public.programacion p
  JOIN public.criterios c ON c.id = p.criterio_id
  JOIN public.equipos e ON e.campamento_id = p.campamento_id
  WHERE p.estado       = 'programado'
    AND c.tipo_calculo = 'rubrica'
    AND c.activo       = true
    AND e.activo       = true
)
SELECT
  b.campamento_id,
  b.momento,
  COUNT(*)                                                     AS observaciones_esperadas,
  COUNT(o.id)                                                  AS observaciones_registradas,
  ROUND(COUNT(o.id)::numeric / NULLIF(COUNT(*), 0) * 100, 1)  AS porcentaje
FROM base b
LEFT JOIN public.observaciones o
       ON o.programacion_id = b.prog_id
      AND o.equipo_id       = b.equipo_id
GROUP BY b.campamento_id, b.momento;

-- 3. Recrear v_puntaje_equipo (fue eliminada por CASCADE del paso 1)
CREATE OR REPLACE VIEW public.v_puntaje_equipo AS
WITH
rubrica AS (
  SELECT equipo_id, COALESCE(SUM(suma_puntaje), 0)::integer AS pts_rubrica
  FROM public.v_puntaje_rubrica_equipo_dia
  GROUP BY equipo_id
),
liderazgo AS (
  SELECT equipo_id, COALESCE(SUM(puntos_obtenidos), 0)::integer AS pts_liderazgo
  FROM public.v_liderazgo_equipo_dia
  GROUP BY equipo_id
),
asistencia AS (
  SELECT equipo_id, COALESCE(SUM(puntaje_promedio), 0)::integer AS pts_asistencia
  FROM public.v_asistencia_equipo_dia
  GROUP BY equipo_id
),
bonus AS (
  SELECT equipo_id, COALESCE(MAX(bonus_total), 0)::integer AS pts_bonus
  FROM public.v_bonus_equipo
  GROUP BY equipo_id
),
demeritos AS (
  SELECT equipo_id, COALESCE(MAX(demeritos_total), 0)::integer AS pts_demeritos
  FROM public.v_demeritos_equipo
  GROUP BY equipo_id
),
numeros AS (
  SELECT
    e.id              AS equipo_id,
    e.campamento_id,
    e.nombre          AS equipo_nombre,
    e.color           AS equipo_color,
    COALESCE(ins.puntaje_inscripcion, 0)::integer  AS pts_inscripcion,
    COALESCE(r.pts_rubrica,    0)                  AS pts_rubrica,
    COALESCE(l.pts_liderazgo,  0)                  AS pts_liderazgo,
    COALESCE(a.pts_asistencia, 0)                  AS pts_asistencia,
    COALESCE(b.pts_bonus,      0)                  AS pts_bonus,
    COALESCE(d.pts_demeritos,  0)                  AS pts_demeritos,
    GREATEST(0,
      COALESCE(ins.puntaje_inscripcion, 0)::integer
      + COALESCE(r.pts_rubrica,    0)
      + COALESCE(l.pts_liderazgo,  0)
      + COALESCE(a.pts_asistencia, 0)
      + COALESCE(b.pts_bonus,      0)
      - COALESCE(d.pts_demeritos,  0)
    )::integer AS pts_bruto
  FROM public.equipos e
  LEFT JOIN public.v_inscripcion_equipo      ins ON ins.equipo_id = e.id
  LEFT JOIN rubrica                            r  ON r.equipo_id   = e.id
  LEFT JOIN liderazgo                          l  ON l.equipo_id   = e.id
  LEFT JOIN asistencia                         a  ON a.equipo_id   = e.id
  LEFT JOIN bonus                              b  ON b.equipo_id   = e.id
  LEFT JOIN demeritos                          d  ON d.equipo_id   = e.id
  WHERE e.activo = true
)
SELECT
  equipo_id,
  campamento_id,
  equipo_nombre,
  equipo_color,
  pts_inscripcion,
  pts_rubrica,
  pts_liderazgo,
  pts_asistencia,
  (pts_inscripcion + pts_rubrica + pts_liderazgo + pts_asistencia)::integer AS pts_base,
  pts_bonus,
  pts_demeritos,
  pts_bruto,
  LEAST(1000, GREATEST(0, ROUND(pts_bruto::numeric / 5200.0 * 1000)))::integer AS pts_escala,
  CASE
    WHEN pts_bruto > 5000 THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END AS medalla,
  RANK() OVER (PARTITION BY campamento_id ORDER BY pts_bruto DESC)::integer AS posicion
FROM numeros;

GRANT SELECT ON public.v_puntaje_equipo TO authenticated;
