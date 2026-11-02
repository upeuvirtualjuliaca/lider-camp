-- Corrige el ORDER BY de v_pendientes_publicacion.
-- Antes: CASE hardcodeado (J=1, V=2, S=3, D=4) → no reconocía X ni otros días.
-- Ahora: ordena por dias_campamento.orden (el orden real configurado por el admin).

CREATE OR REPLACE VIEW public.v_pendientes_publicacion
  WITH (security_invoker = true)
AS
WITH dias AS (
  SELECT de.campamento_id, de.momento, de.publicado, de.cerrado,
         COALESCE(dc.orden, 999) AS orden
  FROM   public.dias_evaluacion de
  LEFT JOIN public.dias_campamento dc
         ON dc.campamento_id = de.campamento_id
        AND dc.codigo        = de.momento
),
equipos_por_camp AS (
  SELECT campamento_id, COUNT(*) AS total
  FROM   public.equipos
  WHERE  activo = true
  GROUP BY campamento_id
),
obs_por_dia AS (
  SELECT
    e.campamento_id,
    p.momento,
    COUNT(DISTINCT o.equipo_id) AS equipos_con_rubrica
  FROM public.observaciones o
  JOIN public.programacion  p ON p.id = o.programacion_id
  JOIN public.equipos       e ON e.id = o.equipo_id
  GROUP BY e.campamento_id, p.momento
),
asis_por_dia AS (
  SELECT
    e.campamento_id,
    p.momento,
    COUNT(DISTINCT ar.integrante_id) > 0 AS tiene_asistencia
  FROM public.asistencia_registros ar
  JOIN public.actividades          a  ON a.id  = ar.actividad_id
  JOIN public.programacion         p  ON p.id  = a.programacion_id
  JOIN public.integrantes          i  ON i.id  = ar.integrante_id
  JOIN public.equipos              e  ON e.id  = i.equipo_id
  GROUP BY e.campamento_id, p.momento
),
lid_por_dia AS (
  SELECT
    e.campamento_id,
    p.momento,
    COUNT(DISTINCT le.equipo_id) AS equipos_con_liderazgo
  FROM public.liderazgo_evaluaciones le
  JOIN public.programacion           p ON p.id = le.programacion_id
  JOIN public.equipos                e ON e.id = le.equipo_id
  GROUP BY e.campamento_id, p.momento
)
SELECT
  d.campamento_id,
  d.momento,
  d.publicado,
  d.cerrado,
  COALESCE(ec.total, 0)                 AS equipos_activos,
  COALESCE(o.equipos_con_rubrica,   0)  AS equipos_rubrica,
  COALESCE(l.equipos_con_liderazgo, 0)  AS equipos_liderazgo,
  COALESCE(asis.tiene_asistencia, false) AS tiene_asistencia
FROM dias d
LEFT JOIN equipos_por_camp ec   ON ec.campamento_id = d.campamento_id
LEFT JOIN obs_por_dia      o    ON o.campamento_id  = d.campamento_id AND o.momento = d.momento
LEFT JOIN asis_por_dia     asis ON asis.campamento_id = d.campamento_id AND asis.momento = d.momento
LEFT JOIN lid_por_dia      l    ON l.campamento_id  = d.campamento_id AND l.momento = d.momento
ORDER BY d.campamento_id, d.orden;
