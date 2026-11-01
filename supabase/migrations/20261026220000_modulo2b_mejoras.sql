-- =================================================================
-- Módulo 2b: Mejoras — limpiar seed generado, equipos reales,
--            corrección de vista v_inscripcion_equipo
-- =================================================================


-- -----------------------------------------------------------------
-- 1. Limpiar integrantes generados por generate_series en seed inicial
--    (solo afecta datos de prueba; al correr de nuevo el seed
--     se insertan los nombrados)
-- -----------------------------------------------------------------
DELETE FROM public.integrantes;


-- -----------------------------------------------------------------
-- 2. Actualizar escuelas de los 3 equipos del seed inicial
-- -----------------------------------------------------------------
UPDATE public.equipos SET escuela_profesional = 'Ingeniería de Sistemas'    WHERE nombre = 'Alfa';
UPDATE public.equipos SET escuela_profesional = 'Administración de Empresas' WHERE nombre = 'Beta';
UPDATE public.equipos SET escuela_profesional = 'Enfermería'                 WHERE nombre = 'Gamma';


-- -----------------------------------------------------------------
-- 3. Agregar 3 equipos nuevos (idempotente)
-- -----------------------------------------------------------------
INSERT INTO public.equipos (nombre, escuela_profesional, color) VALUES
  ('Delta',   'Medicina Humana',         '#EF4444'),
  ('Épsilon', 'Contabilidad y Finanzas', '#8B5CF6'),
  ('Zeta',    'Psicología',              '#EC4899')
ON CONFLICT (nombre) DO NOTHING;


-- -----------------------------------------------------------------
-- 4. Reemplazar v_inscripcion_equipo
--    Reglas confirmadas:
--      · activo = false NO cuenta en nómina ni en puntaje
--      · equipo sin integrantes activos → puntaje = 0.00 (sin error)
--      · JOIN explícito en campamento (requiere la fila única del seed)
-- -----------------------------------------------------------------
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
      AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_parcial
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
JOIN       public.campamento  c ON c.solo_fila = true
LEFT  JOIN public.integrantes i ON i.equipo_id = e.id
WHERE e.activo = true
GROUP BY
  e.id,
  e.nombre,
  e.color,
  c.fecha_limite_inscripcion_completa,
  c.fecha_limite_inscripcion_parcial;
