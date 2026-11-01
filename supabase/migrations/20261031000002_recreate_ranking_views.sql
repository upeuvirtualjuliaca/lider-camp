-- =================================================================
-- Recrear vistas de puntaje y ranking
-- (fueron eliminadas por CASCADE en migración 006)
-- =================================================================

-- 1. v_puntaje_equipo — vista interna, usuarios autenticados
DROP VIEW IF EXISTS public.v_puntaje_equipo CASCADE;

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

-- 2. publico_ranking — solo días publicados, acceso anon
DROP VIEW IF EXISTS public.publico_ranking CASCADE;

CREATE OR REPLACE VIEW public.publico_ranking AS
WITH dias_pub AS (
  SELECT DISTINCT campamento_id
  FROM public.dias_evaluacion
  WHERE publicado = true
),
rubrica_pub AS (
  SELECT r.equipo_id, COALESCE(SUM(r.suma_puntaje), 0)::integer AS pts_rubrica
  FROM public.v_puntaje_rubrica_equipo_dia r
  JOIN public.equipos e ON e.id = r.equipo_id
  JOIN public.dias_evaluacion de ON de.campamento_id = e.campamento_id AND de.momento = r.momento
  WHERE de.publicado = true
  GROUP BY r.equipo_id
),
liderazgo_pub AS (
  SELECT l.equipo_id, COALESCE(SUM(l.puntos_obtenidos), 0)::integer AS pts_liderazgo
  FROM public.v_liderazgo_equipo_dia l
  JOIN public.dias_evaluacion de ON de.campamento_id = l.campamento_id AND de.momento = l.momento
  WHERE de.publicado = true
  GROUP BY l.equipo_id
),
asistencia_pub AS (
  SELECT a.equipo_id, COALESCE(SUM(a.puntaje_promedio), 0)::integer AS pts_asistencia
  FROM public.v_asistencia_equipo_dia a
  JOIN public.equipos e ON e.id = a.equipo_id
  JOIN public.dias_evaluacion de ON de.campamento_id = e.campamento_id AND de.momento = a.momento
  WHERE de.publicado = true
  GROUP BY a.equipo_id
),
bonus_pub AS (
  SELECT equipo_id, COALESCE(MAX(bonus_total), 0)::integer AS pts_bonus
  FROM public.v_bonus_equipo
  GROUP BY equipo_id
),
demeritos_pub AS (
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
  INNER JOIN dias_pub dp ON dp.campamento_id = e.campamento_id
  LEFT JOIN public.v_inscripcion_equipo       ins ON ins.equipo_id = e.id
  LEFT JOIN rubrica_pub                         r  ON r.equipo_id   = e.id
  LEFT JOIN liderazgo_pub                       l  ON l.equipo_id   = e.id
  LEFT JOIN asistencia_pub                      a  ON a.equipo_id   = e.id
  LEFT JOIN bonus_pub                           b  ON b.equipo_id   = e.id
  LEFT JOIN demeritos_pub                       d  ON d.equipo_id   = e.id
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

GRANT SELECT ON public.publico_ranking TO anon, authenticated;

-- 3. publico_ficha_equipo — desglose por momento (rubrica + asistencia + liderazgo), solo publicados
DROP VIEW IF EXISTS public.publico_ficha_equipo CASCADE;

CREATE OR REPLACE VIEW public.publico_ficha_equipo AS
-- Rúbrica: totales por momento (la vista base no expone criterio_id individual)
SELECT
  e.campamento_id,
  r.equipo_id,
  'Rúbrica total'   AS criterio_nombre,
  'rubrica'         AS criterio_categoria,
  r.momento,
  r.suma_puntaje    AS puntaje_obtenido,
  r.maximo_posible,
  'rubrica'         AS tipo_fila
FROM public.v_puntaje_rubrica_equipo_dia r
JOIN public.equipos e ON e.id = r.equipo_id
JOIN public.dias_evaluacion de ON de.campamento_id = e.campamento_id AND de.momento = r.momento
WHERE de.publicado = true AND e.activo = true

UNION ALL

-- Asistencia: por criterio + momento
SELECT
  e.campamento_id,
  a.equipo_id,
  c.nombre                    AS criterio_nombre,
  c.categoria                 AS criterio_categoria,
  a.momento,
  a.puntaje_promedio::integer AS puntaje_obtenido,
  100                         AS maximo_posible,
  'asistencia'                AS tipo_fila
FROM public.v_asistencia_equipo_dia a
JOIN public.equipos e ON e.id = a.equipo_id
JOIN public.criterios c ON c.id = a.criterio_id
JOIN public.dias_evaluacion de ON de.campamento_id = e.campamento_id AND de.momento = a.momento
WHERE de.publicado = true AND e.activo = true

UNION ALL

-- Liderazgo: por momento
SELECT
  l.campamento_id,
  l.equipo_id,
  'Liderazgo'              AS criterio_nombre,
  'liderazgo'              AS criterio_categoria,
  l.momento,
  l.puntos_obtenidos::integer AS puntaje_obtenido,
  100                      AS maximo_posible,
  'liderazgo'              AS tipo_fila
FROM public.v_liderazgo_equipo_dia l
JOIN public.dias_evaluacion de ON de.campamento_id = l.campamento_id AND de.momento = l.momento
WHERE de.publicado = true;

GRANT SELECT ON public.publico_ficha_equipo TO anon, authenticated;
