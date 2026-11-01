-- =================================================================
-- Multi-campamento (parte 1): equipos por campamento
-- • Elimina restricción de un solo campamento activo
-- • Actualiza activar_campamento para no desactivar otros
-- • Agrega campamento_id a equipos (con backfill)
-- • Recrea vistas con campamento_id + RANK particionado
-- =================================================================


-- -----------------------------------------------------------------
-- 1. Eliminar restricción de singleton activo
--    Ahora pueden coexistir múltiples campamentos activos
-- -----------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_campamento_unico_activo;


-- -----------------------------------------------------------------
-- 2. Actualizar activar_campamento: solo activa el indicado,
--    NO desactiva los demás (multi-activo permitido)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activar_campamento(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede activar un campamento.';
  END IF;
  UPDATE public.campamento SET activo = true WHERE id = p_id;
END;
$$;

-- Nueva función complementaria: desactivar sin afectar otros
CREATE OR REPLACE FUNCTION public.desactivar_campamento(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede desactivar un campamento.';
  END IF;
  UPDATE public.campamento SET activo = false WHERE id = p_id;
END;
$$;

REVOKE ALL  ON FUNCTION public.desactivar_campamento(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.desactivar_campamento(uuid) TO authenticated;


-- -----------------------------------------------------------------
-- 3. Agregar campamento_id a equipos
-- -----------------------------------------------------------------

-- Eliminar vistas dependientes antes de modificar equipos
DROP VIEW IF EXISTS public.publico_ficha_equipo    CASCADE;
DROP VIEW IF EXISTS public.publico_ranking         CASCADE;
DROP VIEW IF EXISTS public.v_puntaje_equipo        CASCADE;
DROP VIEW IF EXISTS public.v_inscripcion_equipo    CASCADE;
DROP VIEW IF EXISTS public.publico_equipos         CASCADE;

-- Agregar columna campamento_id (nullable para hacer backfill primero)
ALTER TABLE public.equipos
  ADD COLUMN IF NOT EXISTS campamento_id uuid REFERENCES public.campamento(id) ON DELETE RESTRICT;

-- Backfill: asignar el campamento activo existente a todos los equipos actuales
-- (Si hay más de uno activo, tomar el creado más recientemente)
UPDATE public.equipos
   SET campamento_id = (
     SELECT id FROM public.campamento
     ORDER BY activo DESC, created_at DESC
     LIMIT 1
   )
 WHERE campamento_id IS NULL;

-- Ahora imponer NOT NULL
ALTER TABLE public.equipos
  ALTER COLUMN campamento_id SET NOT NULL;

-- El nombre ahora es único por campamento, no globalmente
ALTER TABLE public.equipos DROP CONSTRAINT IF EXISTS equipos_nombre_key;
ALTER TABLE public.equipos ADD CONSTRAINT equipos_nombre_campamento_unique
  UNIQUE (campamento_id, nombre);

-- Índice para FK
CREATE INDEX IF NOT EXISTS idx_equipos_campamento
  ON public.equipos (campamento_id);


-- -----------------------------------------------------------------
-- 4. Recrear publico_equipos incluyendo campamento_id
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_equipos AS
SELECT id, campamento_id, nombre, escuela_profesional, color
FROM   public.equipos
WHERE  activo = true;

GRANT SELECT ON public.publico_equipos TO anon;


-- -----------------------------------------------------------------
-- 5. Recrear v_inscripcion_equipo
--    Ahora une equipo con SU campamento (e.campamento_id = c.id)
--    en lugar de campamento global activo = true
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_inscripcion_equipo AS
SELECT
  e.id                                                          AS equipo_id,
  e.campamento_id,
  e.nombre                                                      AS equipo_nombre,
  e.color                                                       AS equipo_color,
  COUNT(i.id) FILTER (WHERE i.activo)                          AS nomina,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_completa
  )                                                             AS inscritos_completos,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_completa
      AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_parcial
  )                                                             AS inscritos_parciales,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion > c.fecha_limite_inscripcion_parcial
  )                                                             AS inscritos_tardios,
  CASE
    WHEN COUNT(i.id) FILTER (WHERE i.activo) = 0 THEN 0.00
    ELSE LEAST(
      100.00,
      ROUND(
        (
          COUNT(i.id) FILTER (
            WHERE i.activo
              AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_completa
          ) * 100.0
          +
          COUNT(i.id) FILTER (
            WHERE i.activo
              AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_completa
              AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_parcial
          ) * 50.0
        )
        / NULLIF(COUNT(i.id) FILTER (WHERE i.activo), 0),
        2
      )
    )
  END                                                           AS puntaje_inscripcion
FROM       public.equipos     e
JOIN       public.campamento  c ON c.id = e.campamento_id   -- ← por equipo, no global
LEFT  JOIN public.integrantes i ON i.equipo_id = e.id
WHERE e.activo = true
GROUP BY
  e.id, e.campamento_id, e.nombre, e.color,
  c.fecha_limite_inscripcion_completa,
  c.fecha_limite_inscripcion_parcial;

REVOKE ALL ON public.v_inscripcion_equipo FROM anon;


-- -----------------------------------------------------------------
-- 6. Recrear v_puntaje_equipo
--    Incluye campamento_id; RANK() particionado por campamento
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
  base AS (
    SELECT
      e.id                                                AS equipo_id,
      e.campamento_id,
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
    LEFT JOIN rubrica    r ON r.equipo_id = e.id
    LEFT JOIN liderazgo  l ON l.equipo_id = e.id
    LEFT JOIN asistencia a ON a.equipo_id = e.id
    LEFT JOIN bonus      b ON b.equipo_id = e.id
    LEFT JOIN dem        d ON d.equipo_id = e.id
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
  campamento_id,
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
  ))::integer                                                         AS pts_escala,
  CASE
    WHEN pts_bruto > 5000  THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END                                                                 AS medalla,
  -- posición dentro de cada campamento
  RANK() OVER (PARTITION BY campamento_id ORDER BY pts_bruto DESC)::integer AS posicion
FROM calc;

REVOKE ALL ON public.v_puntaje_equipo FROM anon;


-- -----------------------------------------------------------------
-- 7. Recrear publico_ranking (versión intermedia)
--    dias_evaluacion todavía no tiene campamento_id (se añade en migración 5).
--    Usa el patrón antiguo para publicado; la versión final se aplica en mig. 5.
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
      e.campamento_id,
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
    LEFT JOIN rubrica   r ON r.equipo_id = e.id
    LEFT JOIN liderazgo l ON l.equipo_id = e.id
    LEFT JOIN asistencia a ON a.equipo_id = e.id
    LEFT JOIN bonus     b ON b.equipo_id = e.id
    LEFT JOIN dem       d ON d.equipo_id = e.id
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
  RANK() OVER (PARTITION BY campamento_id ORDER BY pts_bruto DESC)::integer AS posicion
FROM calc;

GRANT SELECT ON public.publico_ranking TO anon;


-- -----------------------------------------------------------------
-- 8. Recrear publico_ficha_equipo (versión intermedia)
--    dias_evaluacion todavía no tiene campamento_id.
--    La versión final se aplica en migración 5.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_ficha_equipo AS

-- ── Rúbrica ────────────────────────────────────────────────────────
SELECT
  e.id                                                     AS equipo_id,
  e.campamento_id,
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

-- ── Asistencia ─────────────────────────────────────────────────────
SELECT
  v.equipo_id,
  e.campamento_id,
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

-- ── Liderazgo ──────────────────────────────────────────────────────
SELECT
  v.equipo_id,
  e.campamento_id,
  v.equipo_nombre,
  v.equipo_color,
  'liderazgo'                                              AS componente,
  'LID'                                                    AS criterio_codigo,
  'Liderazgo de servicio'                                  AS criterio_nombre,
  v.momento,
  COALESCE(ROUND(v.puntos_obtenidos)::integer, 0)         AS puntaje,
  COALESCE(v.puntos_max::integer, 100)                    AS puntaje_max
FROM public.v_liderazgo_equipo_dia v
JOIN  public.equipos e ON e.id = v.equipo_id
JOIN  public.dias_evaluacion d ON d.momento = v.momento
WHERE d.publicado = true;

GRANT SELECT ON public.publico_ficha_equipo TO anon;
