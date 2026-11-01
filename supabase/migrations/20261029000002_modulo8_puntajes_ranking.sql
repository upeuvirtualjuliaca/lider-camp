-- =================================================================
-- Módulo 8: Puntajes y ranking
-- Sin tablas nuevas — solo vistas que consolidan módulos 1–7.
--
-- Vistas internas (authenticated):
--   v_puntaje_equipo      — desglose completo, todos los días
--
-- Vistas públicas (anon):
--   publico_ranking        — ranking por escala 1-1000 (días publicados)
--   publico_ficha_equipo   — puntaje por criterio × día (días publicados)
-- =================================================================


-- -----------------------------------------------------------------
-- 1. VISTA INTERNA v_puntaje_equipo
--    Fuentes: v_inscripcion_equipo, v_puntaje_rubrica_equipo_dia,
--             v_liderazgo_equipo_dia, v_asistencia_equipo_dia,
--             v_bonus_equipo, v_demeritos_equipo
--    Todos los días (publicados o no) → para uso del admin.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_puntaje_equipo AS
WITH
  rubrica AS (
    SELECT equipo_id,
           COALESCE(SUM(suma_puntaje), 0) AS pts_rubrica
    FROM public.v_puntaje_rubrica_equipo_dia
    GROUP BY equipo_id
  ),
  liderazgo AS (
    SELECT equipo_id,
           COALESCE(SUM(puntos_obtenidos), 0) AS pts_liderazgo
    FROM public.v_liderazgo_equipo_dia
    GROUP BY equipo_id
  ),
  asistencia AS (
    SELECT equipo_id,
           COALESCE(SUM(puntaje_promedio), 0) AS pts_asistencia
    FROM public.v_asistencia_equipo_dia
    GROUP BY equipo_id
  ),
  bonus AS (
    -- bonus_total es el mismo para todas las filas del equipo (window fn)
    SELECT equipo_id,
           COALESCE(MAX(bonus_total), 0) AS pts_bonus
    FROM public.v_bonus_equipo
    GROUP BY equipo_id
  ),
  dem AS (
    -- demeritos_total ídem
    SELECT equipo_id,
           COALESCE(MAX(demeritos_total), 0) AS pts_demeritos
    FROM public.v_demeritos_equipo
    GROUP BY equipo_id
  ),
  base AS (
    SELECT
      e.id                                                AS equipo_id,
      e.nombre                                            AS equipo_nombre,
      e.color                                             AS equipo_color,
      COALESCE(ins.puntaje_inscripcion, 0)                AS pts_inscripcion,
      COALESCE(r.pts_rubrica,   0)                        AS pts_rubrica,
      COALESCE(l.pts_liderazgo, 0)                        AS pts_liderazgo,
      COALESCE(a.pts_asistencia, 0)                       AS pts_asistencia,
      COALESCE(b.pts_bonus, 0)                            AS pts_bonus,
      COALESCE(d.pts_demeritos, 0)                        AS pts_demeritos
    FROM public.equipos e
    LEFT JOIN public.v_inscripcion_equipo ins ON ins.equipo_id = e.id
    LEFT JOIN rubrica   r   ON r.equipo_id = e.id
    LEFT JOIN liderazgo l   ON l.equipo_id = e.id
    LEFT JOIN asistencia a  ON a.equipo_id = e.id
    LEFT JOIN bonus      b  ON b.equipo_id = e.id
    LEFT JOIN dem        d  ON d.equipo_id = e.id
    WHERE e.activo = true
  ),
  calc AS (
    SELECT *,
      pts_inscripcion + pts_rubrica + pts_liderazgo + pts_asistencia AS pts_base,
      GREATEST(0,
        pts_inscripcion + pts_rubrica + pts_liderazgo + pts_asistencia
        + pts_bonus - pts_demeritos
      )::integer                                                      AS pts_bruto
    FROM base
  )
SELECT
  equipo_id,
  equipo_nombre,
  equipo_color,
  pts_inscripcion,
  pts_rubrica,
  pts_liderazgo,
  pts_asistencia,
  pts_base,
  pts_bonus,
  pts_demeritos,
  pts_bruto,
  -- escala 1–1000
  GREATEST(0, LEAST(1000,
    ROUND(pts_bruto::numeric / 5200.0 * 1000)
  ))::integer                                                         AS pts_escala,
  -- medalla provisional (base 5200)
  CASE
    WHEN pts_bruto > 5000 THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END                                                                 AS medalla,
  -- posicion (empate comparte posición)
  RANK() OVER (ORDER BY pts_bruto DESC)::integer                     AS posicion
FROM calc;

REVOKE ALL ON public.v_puntaje_equipo FROM anon;


-- -----------------------------------------------------------------
-- 2. VISTA PÚBLICA publico_ranking
--    Solo rubrica / liderazgo / asistencia de días publicados.
--    Bonus y deméritos son globales (no filtran por día publicado).
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_ranking AS
WITH
  pub AS (
    SELECT momento FROM public.dias_evaluacion WHERE publicado = true
  ),
  rubrica AS (
    SELECT equipo_id,
           COALESCE(SUM(suma_puntaje), 0) AS pts_rubrica
    FROM public.v_puntaje_rubrica_equipo_dia
    WHERE momento IN (SELECT momento FROM pub)
    GROUP BY equipo_id
  ),
  liderazgo AS (
    SELECT equipo_id,
           COALESCE(SUM(puntos_obtenidos), 0) AS pts_liderazgo
    FROM public.v_liderazgo_equipo_dia
    WHERE momento IN (SELECT momento FROM pub)
    GROUP BY equipo_id
  ),
  asistencia AS (
    SELECT v.equipo_id,
           COALESCE(SUM(v.puntaje_promedio), 0) AS pts_asistencia
    FROM public.v_asistencia_equipo_dia v
    WHERE v.momento IN (SELECT momento FROM pub)
    GROUP BY v.equipo_id
  ),
  bonus AS (
    SELECT equipo_id,
           COALESCE(MAX(bonus_total), 0) AS pts_bonus
    FROM public.v_bonus_equipo
    GROUP BY equipo_id
  ),
  dem AS (
    SELECT equipo_id,
           COALESCE(MAX(demeritos_total), 0) AS pts_demeritos
    FROM public.v_demeritos_equipo
    GROUP BY equipo_id
  ),
  calc AS (
    SELECT
      e.id                                                 AS equipo_id,
      e.nombre                                             AS equipo_nombre,
      e.color                                              AS equipo_color,
      COALESCE(ins.puntaje_inscripcion, 0)                 AS pts_inscripcion,
      COALESCE(r.pts_rubrica,   0)                         AS pts_rubrica,
      COALESCE(l.pts_liderazgo, 0)                         AS pts_liderazgo,
      COALESCE(a.pts_asistencia, 0)                        AS pts_asistencia,
      COALESCE(ins.puntaje_inscripcion, 0)
        + COALESCE(r.pts_rubrica,   0)
        + COALESCE(l.pts_liderazgo, 0)
        + COALESCE(a.pts_asistencia, 0)                    AS pts_base,
      COALESCE(b.pts_bonus, 0)                             AS pts_bonus,
      COALESCE(d.pts_demeritos, 0)                         AS pts_demeritos,
      GREATEST(0,
        COALESCE(ins.puntaje_inscripcion, 0)
        + COALESCE(r.pts_rubrica,   0)
        + COALESCE(l.pts_liderazgo, 0)
        + COALESCE(a.pts_asistencia, 0)
        + COALESCE(b.pts_bonus, 0)
        - COALESCE(d.pts_demeritos, 0)
      )::integer                                           AS pts_bruto
    FROM public.equipos e
    LEFT JOIN public.v_inscripcion_equipo ins ON ins.equipo_id = e.id
    LEFT JOIN rubrica   r   ON r.equipo_id = e.id
    LEFT JOIN liderazgo l   ON l.equipo_id = e.id
    LEFT JOIN asistencia a  ON a.equipo_id = e.id
    LEFT JOIN bonus      b  ON b.equipo_id = e.id
    LEFT JOIN dem        d  ON d.equipo_id = e.id
    WHERE e.activo = true
  )
SELECT
  equipo_id,
  equipo_nombre,
  equipo_color,
  pts_inscripcion,
  pts_rubrica,
  pts_liderazgo,
  pts_asistencia,
  pts_base,
  pts_bonus,
  pts_demeritos,
  pts_bruto,
  GREATEST(0, LEAST(1000,
    ROUND(pts_bruto::numeric / 5200.0 * 1000)
  ))::integer                                              AS pts_escala,
  CASE
    WHEN pts_bruto > 5000  THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END                                                      AS medalla,
  RANK() OVER (ORDER BY pts_bruto DESC)::integer           AS posicion
FROM calc;

GRANT SELECT ON public.publico_ranking TO anon;


-- -----------------------------------------------------------------
-- 3. VISTA PÚBLICA publico_ficha_equipo
--    Una fila por (equipo, componente, criterio, momento).
--    Solo días publicados. No expone evaluadores ni comentarios.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_ficha_equipo AS

-- ── Rúbrica: una fila por criterio × día ──────────────────────────
SELECT
  e.id                                                     AS equipo_id,
  e.nombre                                                 AS equipo_nombre,
  e.color                                                  AS equipo_color,
  'rubrica'                                                AS componente,
  c.codigo                                                 AS criterio_codigo,
  c.nombre                                                 AS criterio_nombre,
  p.momento,
  COALESCE(o.puntaje, 0)::integer                         AS puntaje,
  p.puntaje_max::integer                                   AS puntaje_max
FROM public.programacion p
JOIN  public.criterios       c   ON c.id  = p.criterio_id
CROSS JOIN public.equipos    e
LEFT  JOIN public.observaciones o
           ON  o.programacion_id = p.id
           AND o.equipo_id       = e.id
JOIN  public.dias_evaluacion d   ON d.momento = p.momento
WHERE p.estado       = 'programado'
  AND c.tipo_calculo = 'rubrica'
  AND c.activo       = true
  AND e.activo       = true
  AND d.publicado    = true

UNION ALL

-- ── Asistencia: una fila por criterio-asistencia × día ────────────
SELECT
  v.equipo_id,
  v.equipo_nombre,
  e.color                                                  AS equipo_color,
  'asistencia'                                             AS componente,
  c.codigo                                                 AS criterio_codigo,
  c.nombre                                                 AS criterio_nombre,
  v.momento,
  COALESCE(ROUND(v.puntaje_promedio)::integer, 0)         AS puntaje,
  100                                                      AS puntaje_max
FROM public.v_asistencia_equipo_dia v
JOIN  public.criterios c ON c.id  = v.criterio_id
JOIN  public.equipos   e ON e.id  = v.equipo_id
JOIN  public.dias_evaluacion d ON d.momento = v.momento
WHERE d.publicado = true
  AND e.activo    = true

UNION ALL

-- ── Liderazgo: una fila por día ────────────────────────────────────
SELECT
  v.equipo_id,
  v.equipo_nombre,
  v.equipo_color,
  'liderazgo'                                              AS componente,
  'LID'                                                    AS criterio_codigo,
  'Liderazgo de servicio'                                  AS criterio_nombre,
  v.momento,
  COALESCE(ROUND(v.puntos_obtenidos)::integer, 0)         AS puntaje,
  COALESCE(v.puntos_max::integer, 100)                    AS puntaje_max
FROM public.v_liderazgo_equipo_dia v
JOIN public.dias_evaluacion d ON d.momento = v.momento
WHERE d.publicado = true;

GRANT SELECT ON public.publico_ficha_equipo TO anon;


-- -----------------------------------------------------------------
-- Nota: publico_inscripcion se obtiene ya desde publico_ranking
-- (campo pts_inscripcion). No se crea vista extra para inscripción.
-- -----------------------------------------------------------------
