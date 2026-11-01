-- =================================================================
-- Agregar campamento_id a vistas de resumen para permitir filtrado
-- Vistas afectadas:
--   v_liderazgo_equipo_dia, v_bonus_equipo, v_demeritos_equipo,
--   v_incidencias_pendientes
-- =================================================================


-- -----------------------------------------------------------------
-- 1. v_liderazgo_equipo_dia — agregar campamento_id de equipos
-- -----------------------------------------------------------------
DROP VIEW IF EXISTS public.v_liderazgo_equipo_dia CASCADE;
CREATE VIEW public.v_liderazgo_equipo_dia AS
WITH activos AS (
  SELECT COUNT(*)::int               AS total_indicadores,
         COALESCE(SUM(puntaje_max), 0)::numeric AS puntaje_max_total
    FROM public.liderazgo_indicadores
   WHERE activo = true
),
base AS (
  SELECT e.id            AS equipo_id,
         e.campamento_id,
         e.nombre        AS equipo_nombre,
         e.color         AS equipo_color,
         p.id            AS programacion_id,
         p.momento
    FROM public.equipos      e
    CROSS JOIN public.programacion p
    JOIN  public.criterios   c ON c.id = p.criterio_id
   WHERE e.activo = true
     AND c.tipo_calculo = 'liderazgo'
     AND p.estado = 'programado'
),
evaluados AS (
  SELECT le.equipo_id,
         le.programacion_id,
         COUNT(*)::int  AS indicadores_calificados,
         SUM(le.puntos) AS puntos_obtenidos
    FROM public.liderazgo_evaluaciones le
    JOIN public.liderazgo_indicadores  li ON li.id = le.indicador_id
   WHERE li.activo = true
   GROUP BY le.equipo_id, le.programacion_id
)
SELECT b.equipo_id,
       b.campamento_id,
       b.equipo_nombre,
       b.equipo_color,
       b.programacion_id,
       b.momento,
       a.total_indicadores,
       a.puntaje_max_total                                           AS puntos_max,
       COALESCE(ev.indicadores_calificados, 0)                       AS indicadores_calificados,
       COALESCE(ev.puntos_obtenidos,        0)                       AS puntos_obtenidos,
       CASE
         WHEN a.total_indicadores = 0 THEN false
         ELSE COALESCE(ev.indicadores_calificados, 0) >= a.total_indicadores
       END                                                           AS completo
  FROM base           b
  JOIN activos        a  ON true
  LEFT JOIN evaluados ev ON ev.equipo_id       = b.equipo_id
                        AND ev.programacion_id = b.programacion_id;

REVOKE ALL ON public.v_liderazgo_equipo_dia FROM anon;


-- -----------------------------------------------------------------
-- 2. v_bonus_equipo — agregar campamento_id
-- -----------------------------------------------------------------
DROP VIEW IF EXISTS public.v_bonus_equipo CASCADE;
CREATE VIEW public.v_bonus_equipo AS
WITH por_codigo AS (
  SELECT
    i.equipo_id,
    e.campamento_id,
    e.nombre                                                            AS equipo_nombre,
    e.color                                                             AS equipo_color,
    ic.codigo,
    ic.nombre                                                           AS codigo_nombre,
    ic.puntos                                                           AS puntos_por_accion,
    COUNT(*)::int                                                       AS acciones_validadas,
    LEAST(
      SUM(i.puntos),
      COALESCE(ic.tope_equipo, SUM(i.puntos))
    )                                                                   AS bonus_codigo
  FROM public.incidencias      i
  JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo
  JOIN public.equipos            e  ON e.id      = i.equipo_id
  WHERE i.estado = 'validado' AND ic.tipo = 'bonus'
  GROUP BY i.equipo_id, e.campamento_id, e.nombre, e.color,
           ic.codigo, ic.nombre, ic.puntos, ic.tope_equipo
),
totales AS (
  SELECT equipo_id,
         LEAST(SUM(bonus_codigo), 200) AS bonus_total
  FROM por_codigo
  GROUP BY equipo_id
)
SELECT
  pc.equipo_id,
  pc.campamento_id,
  pc.equipo_nombre,
  pc.equipo_color,
  pc.codigo,
  pc.codigo_nombre,
  pc.puntos_por_accion,
  pc.acciones_validadas,
  pc.bonus_codigo,
  t.bonus_total
FROM por_codigo pc
JOIN totales    t ON t.equipo_id = pc.equipo_id;

REVOKE ALL ON public.v_bonus_equipo FROM anon;


-- -----------------------------------------------------------------
-- 3. v_demeritos_equipo — agregar campamento_id
-- -----------------------------------------------------------------
DROP VIEW IF EXISTS public.v_demeritos_equipo CASCADE;
CREATE VIEW public.v_demeritos_equipo AS
SELECT
  i.equipo_id,
  e.campamento_id,
  e.nombre                                                              AS equipo_nombre,
  e.color                                                               AS equipo_color,
  ic.codigo,
  ic.nombre                                                             AS codigo_nombre,
  COUNT(*)::int                                                         AS incidencias_validadas,
  SUM(i.puntos)::numeric                                                AS demeritos_codigo,
  SUM(SUM(i.puntos)) OVER (PARTITION BY i.equipo_id)::numeric           AS demeritos_total
FROM public.incidencias      i
JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo
JOIN public.equipos            e  ON e.id      = i.equipo_id
WHERE i.estado = 'validado' AND ic.tipo = 'demerito'
GROUP BY i.equipo_id, e.campamento_id, e.nombre, e.color, ic.codigo, ic.nombre;

REVOKE ALL ON public.v_demeritos_equipo FROM anon;


-- -----------------------------------------------------------------
-- 4. v_incidencias_pendientes — agregar campamento_id
-- -----------------------------------------------------------------
DROP VIEW IF EXISTS public.v_incidencias_pendientes CASCADE;
CREATE VIEW public.v_incidencias_pendientes AS
SELECT
  i.id,
  i.equipo_id,
  e.campamento_id,
  e.nombre                        AS equipo_nombre,
  e.color                         AS equipo_color,
  i.codigo,
  ic.tipo,
  ic.nombre                       AS codigo_nombre,
  i.fecha,
  i.hora,
  i.momento,
  i.hecho,
  i.alcance,
  i.puntos,
  i.estado,
  i.descargo_equipo,
  i.registrado_por,
  p.nombre_completo               AS registrado_por_nombre,
  i.created_at
FROM public.incidencias       i
JOIN public.equipos            e  ON e.id       = i.equipo_id
JOIN public.incidencia_codigos ic ON ic.codigo  = i.codigo
JOIN public.perfiles           p  ON p.id       = i.registrado_por
WHERE i.estado IN ('registrado','descargo');

REVOKE ALL ON public.v_incidencias_pendientes FROM anon;
