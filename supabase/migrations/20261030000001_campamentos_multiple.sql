-- =================================================================
-- Múltiples campamentos: quitar singleton solo_fila, agregar activo
-- Actualiza también las vistas que dependen de solo_fila
-- =================================================================

-- 1. Eliminar las vistas dependientes de solo_fila (CASCADE)
DROP VIEW IF EXISTS public.publico_ranking       CASCADE;
DROP VIEW IF EXISTS public.v_puntaje_equipo      CASCADE;
DROP VIEW IF EXISTS public.v_inscripcion_equipo  CASCADE;

-- 2. Quitar columna solo_fila (ya sin dependencias)
ALTER TABLE public.campamento DROP CONSTRAINT IF EXISTS campamento_solo_fila_key;
ALTER TABLE public.campamento DROP COLUMN  IF EXISTS solo_fila;

-- 3. Columna activo — solo un campamento activo a la vez
ALTER TABLE public.campamento
  ADD COLUMN IF NOT EXISTS activo boolean NOT NULL DEFAULT false;

-- Marcar el campamento existente como activo
UPDATE public.campamento SET activo = true WHERE activo = false;

-- Índice parcial único
CREATE UNIQUE INDEX IF NOT EXISTS idx_campamento_unico_activo
  ON public.campamento (activo) WHERE activo = true;

-- 4. Política adicional: permite insertar nuevos campamentos (admin)
CREATE POLICY campamento_delete_admin ON public.campamento
  FOR DELETE TO authenticated USING (public.es_admin());


-- =================================================================
-- 5. Recrear v_inscripcion_equipo — usa activo = true
-- =================================================================
CREATE OR REPLACE VIEW public.v_inscripcion_equipo AS
SELECT
  e.id                                                          AS equipo_id,
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
JOIN       public.campamento  c ON c.activo = true   -- ← cambiado de solo_fila = true
LEFT  JOIN public.integrantes i ON i.equipo_id = e.id
WHERE e.activo = true
GROUP BY
  e.id, e.nombre, e.color,
  c.fecha_limite_inscripcion_completa,
  c.fecha_limite_inscripcion_parcial;

REVOKE ALL ON public.v_inscripcion_equipo FROM anon;


-- =================================================================
-- 6. Recrear v_puntaje_equipo (sin cambios en lógica)
-- =================================================================
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
  equipo_id, equipo_nombre, equipo_color,
  pts_inscripcion, pts_rubrica, pts_liderazgo, pts_asistencia,
  pts_base, pts_bonus, pts_demeritos, pts_bruto,
  GREATEST(0, LEAST(1000,
    ROUND(pts_bruto::numeric / 5200.0 * 1000)
  ))::integer                                                         AS pts_escala,
  CASE
    WHEN pts_bruto > 5000  THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END                                                                 AS medalla,
  RANK() OVER (ORDER BY pts_bruto DESC)::integer                     AS posicion
FROM calc;

REVOKE ALL ON public.v_puntaje_equipo FROM anon;


-- =================================================================
-- 7. Recrear publico_ranking (sin cambios en lógica)
-- =================================================================
CREATE OR REPLACE VIEW public.publico_ranking AS
WITH
  pub AS (SELECT momento FROM public.dias_evaluacion WHERE publicado = true),
  rubrica AS (
    SELECT equipo_id, COALESCE(SUM(suma_puntaje), 0) AS pts_rubrica
    FROM public.v_puntaje_rubrica_equipo_dia
    WHERE momento IN (SELECT momento FROM pub)
    GROUP BY equipo_id
  ),
  liderazgo AS (
    SELECT equipo_id, COALESCE(SUM(puntos_obtenidos), 0) AS pts_liderazgo
    FROM public.v_liderazgo_equipo_dia
    WHERE momento IN (SELECT momento FROM pub)
    GROUP BY equipo_id
  ),
  asistencia AS (
    SELECT v.equipo_id, COALESCE(SUM(v.puntaje_promedio), 0) AS pts_asistencia
    FROM public.v_asistencia_equipo_dia v
    WHERE v.momento IN (SELECT momento FROM pub)
    GROUP BY v.equipo_id
  ),
  bonus AS (
    SELECT equipo_id, COALESCE(MAX(bonus_total), 0) AS pts_bonus
    FROM public.v_bonus_equipo GROUP BY equipo_id
  ),
  dem AS (
    SELECT equipo_id, COALESCE(MAX(demeritos_total), 0) AS pts_demeritos
    FROM public.v_demeritos_equipo GROUP BY equipo_id
  ),
  calc AS (
    SELECT
      e.id    AS equipo_id, e.nombre AS equipo_nombre, e.color AS equipo_color,
      COALESCE(ins.puntaje_inscripcion, 0)               AS pts_inscripcion,
      COALESCE(r.pts_rubrica,   0)                        AS pts_rubrica,
      COALESCE(l.pts_liderazgo, 0)                        AS pts_liderazgo,
      COALESCE(a.pts_asistencia, 0)                       AS pts_asistencia,
      COALESCE(ins.puntaje_inscripcion, 0)
        + COALESCE(r.pts_rubrica,   0)
        + COALESCE(l.pts_liderazgo, 0)
        + COALESCE(a.pts_asistencia, 0)                   AS pts_base,
      COALESCE(b.pts_bonus, 0)                            AS pts_bonus,
      COALESCE(d.pts_demeritos, 0)                        AS pts_demeritos,
      GREATEST(0,
        COALESCE(ins.puntaje_inscripcion, 0)
        + COALESCE(r.pts_rubrica, 0) + COALESCE(l.pts_liderazgo, 0)
        + COALESCE(a.pts_asistencia, 0)
        + COALESCE(b.pts_bonus, 0)   - COALESCE(d.pts_demeritos, 0)
      )::integer                                          AS pts_bruto
    FROM public.equipos e
    LEFT JOIN public.v_inscripcion_equipo ins ON ins.equipo_id = e.id
    LEFT JOIN rubrica    r ON r.equipo_id = e.id
    LEFT JOIN liderazgo  l ON l.equipo_id = e.id
    LEFT JOIN asistencia a ON a.equipo_id = e.id
    LEFT JOIN bonus      b ON b.equipo_id = e.id
    LEFT JOIN dem        d ON d.equipo_id = e.id
    WHERE e.activo = true
  )
SELECT
  equipo_id, equipo_nombre, equipo_color,
  pts_inscripcion, pts_rubrica, pts_liderazgo, pts_asistencia,
  pts_base, pts_bonus, pts_demeritos, pts_bruto,
  GREATEST(0, LEAST(1000,
    ROUND(pts_bruto::numeric / 5200.0 * 1000)
  ))::integer                                             AS pts_escala,
  CASE
    WHEN pts_bruto > 5000  THEN 'oro'
    WHEN pts_bruto >= 4000 THEN 'plata'
    WHEN pts_bruto >= 3000 THEN 'bronce'
    ELSE 'participacion'
  END                                                     AS medalla,
  RANK() OVER (ORDER BY pts_bruto DESC)::integer          AS posicion
FROM calc;

GRANT SELECT ON public.publico_ranking TO anon;


-- =================================================================
-- 8. RPC activar_campamento
-- =================================================================
CREATE OR REPLACE FUNCTION public.activar_campamento(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede cambiar el campamento activo.';
  END IF;
  UPDATE public.campamento SET activo = false WHERE activo = true;
  UPDATE public.campamento SET activo = true  WHERE id = p_id;
END;
$$;
REVOKE ALL  ON FUNCTION public.activar_campamento(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.activar_campamento(uuid) TO authenticated;


-- =================================================================
-- 9. Actualizar funciones que usan campamento
-- =================================================================
CREATE OR REPLACE FUNCTION public.fn_campamento_cerrado_check()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_cerrado boolean;
BEGIN
  SELECT cerrado INTO v_cerrado FROM public.campamento WHERE activo = true LIMIT 1;
  IF COALESCE(v_cerrado, false) AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'El campamento está cerrado. No se pueden registrar ni modificar datos.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.cerrar_campamento(p_motivo text, p_forzar boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_pendientes int;
BEGIN
  IF NOT public.es_admin() THEN RAISE EXCEPTION 'Solo el administrador puede cerrar el campamento.'; END IF;
  IF NOT p_forzar THEN
    SELECT COUNT(*) INTO v_pendientes FROM public.incidencias WHERE estado = 'registrado';
    IF v_pendientes > 0 THEN
      RAISE EXCEPTION 'Hay % incidencia(s) sin resolver. Usa p_forzar=true para cerrar igualmente.', v_pendientes;
    END IF;
  END IF;
  UPDATE public.campamento
     SET cerrado = true, cerrado_at = now(), cerrado_por = auth.uid(), motivo_cierre = p_motivo
   WHERE activo = true;
END;
$$;

CREATE OR REPLACE FUNCTION public.reabrir_campamento(p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN RAISE EXCEPTION 'Solo el administrador puede reabrir el campamento.'; END IF;
  UPDATE public.campamento
     SET cerrado = false, cerrado_at = NULL, cerrado_por = NULL, motivo_cierre = p_motivo
   WHERE activo = true;
END;
$$;
