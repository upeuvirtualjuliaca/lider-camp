-- =================================================================
-- Módulo 2: Datos iniciales de prueba
-- Campamento + 3 equipos + integrantes (reproduce ejemplo 75 pts)
-- Idempotente: no falla si ya existen los datos
-- =================================================================

DO $$
DECLARE
  v_equipo_alfa uuid;
  v_equipo_beta uuid;
  v_equipo_gamma uuid;
BEGIN

  -- -----------------------------------------------------------------
  -- Configuración del campamento (fila única)
  -- -----------------------------------------------------------------
  INSERT INTO public.campamento (
    nombre, edicion,
    fecha_jueves, fecha_viernes, fecha_sabado, fecha_domingo,
    fecha_limite_inscripcion_completa,
    fecha_limite_inscripcion_parcial
  ) VALUES (
    'LiderCamp', '2026-II',
    '2026-10-22', '2026-10-23', '2026-10-24', '2026-10-25',
    '2026-10-19',
    '2026-10-21'
  )
  ON CONFLICT (solo_fila) DO NOTHING;

  -- -----------------------------------------------------------------
  -- Equipos de ejemplo
  -- -----------------------------------------------------------------
  INSERT INTO public.equipos (nombre, escuela_profesional, color) VALUES
    ('Equipo Alfa',  'Ingeniería de Sistemas', '#3B82F6'),
    ('Equipo Beta',  'Administración',         '#10B981'),
    ('Equipo Gamma', 'Medicina Humana',        '#F59E0B')
  ON CONFLICT (nombre) DO NOTHING;

  SELECT id INTO v_equipo_alfa  FROM public.equipos WHERE nombre = 'Equipo Alfa';
  SELECT id INTO v_equipo_beta  FROM public.equipos WHERE nombre = 'Equipo Beta';
  SELECT id INTO v_equipo_gamma FROM public.equipos WHERE nombre = 'Equipo Gamma';

  -- -----------------------------------------------------------------
  -- Equipo Alfa — reproduce el ejemplo de 75 puntos:
  --   5 inscritos hasta el 19 oct (×100) + 5 del 20-21 oct (×50)
  --   = (500 + 250) / 10 = 75.00 pts
  -- -----------------------------------------------------------------
  INSERT INTO public.integrantes
    (equipo_id, nombres, apellidos, codigo_universitario, fecha_inscripcion)
  SELECT
    v_equipo_alfa,
    'Nombre' || i,
    'Alfa' || i,
    'ALF2026' || LPAD(i::text, 3, '0'),
    '2026-10-18'::date    -- antes del 19 → completo (×100)
  FROM generate_series(1, 5) AS i
  ON CONFLICT (codigo_universitario) DO NOTHING;

  INSERT INTO public.integrantes
    (equipo_id, nombres, apellidos, codigo_universitario, fecha_inscripcion)
  SELECT
    v_equipo_alfa,
    'Nombre' || (i + 5),
    'Alfa' || (i + 5),
    'ALF2026' || LPAD((i + 5)::text, 3, '0'),
    '2026-10-20'::date    -- 20-21 oct → parcial (×50)
  FROM generate_series(1, 5) AS i
  ON CONFLICT (codigo_universitario) DO NOTHING;

  -- -----------------------------------------------------------------
  -- Equipo Beta — todos inscritos a tiempo (puntaje 100)
  -- -----------------------------------------------------------------
  INSERT INTO public.integrantes
    (equipo_id, nombres, apellidos, codigo_universitario, fecha_inscripcion)
  SELECT
    v_equipo_beta,
    'Nombre' || i,
    'Beta' || i,
    'BET2026' || LPAD(i::text, 3, '0'),
    '2026-10-15'::date
  FROM generate_series(1, 8) AS i
  ON CONFLICT (codigo_universitario) DO NOTHING;

  -- -----------------------------------------------------------------
  -- Equipo Gamma — mix: 3 completos, 3 parciales, 2 tardíos
  --   = (3×100 + 3×50) / 8 = 450/8 = 56.25 pts
  -- -----------------------------------------------------------------
  INSERT INTO public.integrantes
    (equipo_id, nombres, apellidos, codigo_universitario, fecha_inscripcion)
  SELECT
    v_equipo_gamma,
    'Nombre' || i,
    'Gamma' || i,
    'GAM2026' || LPAD(i::text, 3, '0'),
    CASE
      WHEN i <= 3 THEN '2026-10-17'::date   -- completo
      WHEN i <= 6 THEN '2026-10-21'::date   -- parcial
      ELSE             '2026-10-23'::date   -- tardío (aporta 0)
    END
  FROM generate_series(1, 8) AS i
  ON CONFLICT (codigo_universitario) DO NOTHING;

  RAISE NOTICE 'Seed Módulo 2 aplicado correctamente.';
END;
$$;
