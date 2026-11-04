-- =============================================================================
-- Opción B: cada evaluador guarda su propio puntaje.
-- El puntaje final es el PROMEDIO automático de todos los evaluadores.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Cambiar el constraint único de observaciones
--    Antes: (equipo_id, programacion_id)
--    Ahora: (equipo_id, programacion_id, evaluador_id)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.observaciones
  DROP CONSTRAINT IF EXISTS observaciones_equipo_id_programacion_id_key;

ALTER TABLE public.observaciones
  ADD CONSTRAINT observaciones_equipo_prog_eval_key
  UNIQUE (equipo_id, programacion_id, evaluador_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Recrear vistas que dependen de v_puntaje_rubrica_equipo_dia
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.publico_ficha_equipo  CASCADE;
DROP VIEW IF EXISTS public.publico_ranking        CASCADE;
DROP VIEW IF EXISTS public.v_puntaje_equipo       CASCADE;
DROP VIEW IF EXISTS public.v_puntaje_rubrica_equipo_dia CASCADE;

-- v_puntaje_rubrica_equipo_dia con PROMEDIO por evaluador
CREATE OR REPLACE VIEW public.v_puntaje_rubrica_equipo_dia AS
WITH promedios AS (
  SELECT
    programacion_id,
    equipo_id,
    ROUND(AVG(puntaje))::integer AS puntaje_promedio
  FROM public.observaciones
  GROUP BY programacion_id, equipo_id
)
SELECT
  e.campamento_id,
  e.id                                                    AS equipo_id,
  e.nombre                                                AS equipo_nombre,
  e.color                                                 AS equipo_color,
  p.momento,
  COALESCE(SUM(pr.puntaje_promedio), 0)::numeric(10,2)   AS suma_puntaje,
  SUM(p.puntaje_max)::numeric(10,2)                      AS maximo_posible,
  COUNT(pr.puntaje_promedio)::integer                    AS criterios_calificados,
  (COUNT(p.id) - COUNT(pr.puntaje_promedio))::integer    AS criterios_pendientes
FROM public.programacion p
JOIN public.criterios c ON c.id = p.criterio_id
JOIN public.equipos e ON e.campamento_id = p.campamento_id
LEFT JOIN promedios pr
       ON pr.programacion_id = p.id
      AND pr.equipo_id       = e.id
WHERE p.estado       = 'programado'
  AND c.tipo_calculo = 'rubrica'
  AND c.activo       = true
  AND e.activo       = true
GROUP BY e.campamento_id, e.id, e.nombre, e.color, p.momento;

GRANT SELECT ON public.v_puntaje_rubrica_equipo_dia TO authenticated;
REVOKE ALL    ON public.v_puntaje_rubrica_equipo_dia FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Recrear v_puntaje_equipo (sin cambios, solo por CASCADE)
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Recrear publico_ranking (sin cambios, solo por CASCADE)
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Recrear publico_ficha_equipo (sin cambios, solo por CASCADE)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.publico_ficha_equipo AS
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

SELECT
  l.campamento_id,
  l.equipo_id,
  'Liderazgo'                 AS criterio_nombre,
  'liderazgo'                 AS criterio_categoria,
  l.momento,
  l.puntos_obtenidos::integer AS puntaje_obtenido,
  100                         AS maximo_posible,
  'liderazgo'                 AS tipo_fila
FROM public.v_liderazgo_equipo_dia l
JOIN public.dias_evaluacion de ON de.campamento_id = l.campamento_id AND de.momento = l.momento
WHERE de.publicado = true;

GRANT SELECT ON public.publico_ficha_equipo TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Actualizar v_progreso_evaluacion
--    Un slot está "registrado" si al menos un evaluador lo ha calificado.
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.v_progreso_evaluacion CASCADE;

CREATE OR REPLACE VIEW public.v_progreso_evaluacion AS
WITH base AS (
  SELECT
    p.id            AS prog_id,
    p.momento,
    p.campamento_id,
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
  b.momento,
  b.campamento_id,
  COUNT(*)                                                              AS observaciones_esperadas,
  COUNT(DISTINCT (o.programacion_id::text || o.equipo_id::text))       AS observaciones_registradas,
  ROUND(
    COUNT(DISTINCT (o.programacion_id::text || o.equipo_id::text))::numeric
    / NULLIF(COUNT(*), 0) * 100, 1
  )                                                                     AS porcentaje
FROM base b
LEFT JOIN public.observaciones o
       ON o.programacion_id = b.prog_id
      AND o.equipo_id       = b.equipo_id
GROUP BY b.momento, b.campamento_id;

GRANT SELECT ON public.v_progreso_evaluacion TO authenticated;
REVOKE ALL    ON public.v_progreso_evaluacion FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Recrear publico_ranking_dia (caída por CASCADE sobre v_puntaje_rubrica_equipo_dia)
--    actividades_dia usa AVG por (criterio, equipo) antes de sumar entre criterios
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.publico_ranking_dia;

CREATE VIEW public.publico_ranking_dia
WITH (security_invoker = false)
AS
WITH
actividades_dia AS (
  -- Promedio de evaluadores por (criterio, equipo), luego suma de criterios
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
  COALESCE(bd.pts_bonus, 0)               AS pts_bonus,
  COALESCE(dd.pts_demeritos, 0)           AS pts_demeritos,
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
