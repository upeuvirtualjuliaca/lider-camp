-- =================================================================
-- Módulo 6: Liderazgo de servicio y organización
-- Tablas:   liderazgo_indicadores, liderazgo_evaluaciones
-- Vistas:   v_liderazgo_equipo_dia, v_validacion_indicadores,
--           publico_liderazgo_indicadores
-- =================================================================


-- -----------------------------------------------------------------
-- 1. TABLA liderazgo_indicadores
-- -----------------------------------------------------------------
CREATE TABLE public.liderazgo_indicadores (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo      text        NOT NULL UNIQUE,
  nombre      text        NOT NULL,
  descripcion text        NOT NULL,
  evidencia   text        NOT NULL,
  puntaje_max int         NOT NULL DEFAULT 25
                          CHECK (puntaje_max > 0 AND puntaje_max <= 100),
  orden       int         NOT NULL DEFAULT 1,
  activo      boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.liderazgo_indicadores ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_li_updated_at
  BEFORE UPDATE ON public.liderazgo_indicadores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_li_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.liderazgo_indicadores
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- -----------------------------------------------------------------
-- 2. TABLA liderazgo_evaluaciones
-- -----------------------------------------------------------------
CREATE TABLE public.liderazgo_evaluaciones (
  id              uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  equipo_id       uuid         NOT NULL REFERENCES public.equipos(id)               ON DELETE CASCADE,
  programacion_id uuid         NOT NULL REFERENCES public.programacion(id)          ON DELETE CASCADE,
  indicador_id    uuid         NOT NULL REFERENCES public.liderazgo_indicadores(id) ON DELETE CASCADE,
  nivel           int          NOT NULL CHECK (nivel BETWEEN 0 AND 4),
  puntos          numeric(6,2) NOT NULL DEFAULT 0,
  comentario      text,
  evaluador_id    uuid         NOT NULL DEFAULT auth.uid()
                               REFERENCES public.perfiles(id),
  motivo_cambio   text,
  created_at      timestamptz  NOT NULL DEFAULT now(),
  updated_at      timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (equipo_id, programacion_id, indicador_id)
);

ALTER TABLE public.liderazgo_evaluaciones ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_le_updated_at
  BEFORE UPDATE ON public.liderazgo_evaluaciones
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_le_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.liderazgo_evaluaciones
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 3. FUNCIÓN: calcular puntos (BEFORE INSERT/UPDATE)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calcular_puntos_liderazgo()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_pmax int;
BEGIN
  SELECT puntaje_max INTO v_pmax
    FROM public.liderazgo_indicadores WHERE id = NEW.indicador_id;
  NEW.puntos := ROUND((NEW.nivel::numeric * v_pmax / 4), 2);
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_le_calculo
  BEFORE INSERT OR UPDATE ON public.liderazgo_evaluaciones
  FOR EACH ROW EXECUTE FUNCTION public.calcular_puntos_liderazgo();


-- -----------------------------------------------------------------
-- 4. FUNCIÓN: validar evaluación de liderazgo
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_evaluacion_liderazgo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog  record;
  v_dia   record;
BEGIN
  -- Programación: debe existir, estar programada y ser tipo liderazgo
  SELECT p.estado, p.tipo_calculo, p.momento
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = NEW.programacion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Programación no encontrada.';
  END IF;
  IF v_prog.tipo_calculo <> 'liderazgo' THEN
    RAISE EXCEPTION 'La programación no es de tipo liderazgo.';
  END IF;
  IF v_prog.estado <> 'programado' THEN
    RAISE EXCEPTION 'La programación no está en estado "programado" (estado actual: %).', v_prog.estado;
  END IF;

  -- Equipo activo
  IF NOT EXISTS (SELECT 1 FROM public.equipos WHERE id = NEW.equipo_id AND activo = true) THEN
    RAISE EXCEPTION 'El equipo no está activo.';
  END IF;

  -- Indicador activo
  IF NOT EXISTS (SELECT 1 FROM public.liderazgo_indicadores WHERE id = NEW.indicador_id AND activo = true) THEN
    RAISE EXCEPTION 'El indicador de liderazgo no está activo.';
  END IF;

  -- Día cerrado: solo admin puede operar
  SELECT cerrado INTO v_dia
    FROM public.dias_evaluacion WHERE momento = v_prog.momento;

  IF FOUND AND v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'El día % está cerrado. Solo el administrador puede modificar evaluaciones.', v_prog.momento;
  END IF;

  -- En UPDATE: si el nivel cambia, motivo_cambio obligatorio
  IF TG_OP = 'UPDATE' AND NEW.nivel IS DISTINCT FROM OLD.nivel THEN
    IF NEW.motivo_cambio IS NULL OR trim(NEW.motivo_cambio) = '' THEN
      RAISE EXCEPTION 'Debes indicar el motivo del cambio de nivel.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- El trigger de validación debe correr ANTES del de cálculo
-- para rechazar datos inválidos antes de calcular puntos.
-- BEFORE triggers corren en orden de creación por nombre alfabético,
-- pero para garantizarlo usamos nombres que aseguren el orden:
-- tr_le_calculo < tr_le_validar alfabéticamente → validar corre después.
-- Renombramos el de cálculo para que corra antes: tr_le_1calculo
DROP TRIGGER tr_le_calculo ON public.liderazgo_evaluaciones;

CREATE TRIGGER tr_le_1calculo
  BEFORE INSERT OR UPDATE ON public.liderazgo_evaluaciones
  FOR EACH ROW EXECUTE FUNCTION public.calcular_puntos_liderazgo();

CREATE TRIGGER tr_le_2validar
  BEFORE INSERT OR UPDATE ON public.liderazgo_evaluaciones
  FOR EACH ROW EXECUTE FUNCTION public.validar_evaluacion_liderazgo();


-- -----------------------------------------------------------------
-- 5. FUNCIÓN: validar cambios en indicadores
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_indicador_liderazgo()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.puntaje_max IS DISTINCT FROM OLD.puntaje_max THEN
    IF EXISTS (SELECT 1 FROM public.liderazgo_evaluaciones WHERE indicador_id = NEW.id) THEN
      RAISE EXCEPTION
        'No se puede modificar puntaje_max del indicador "%": ya tiene evaluaciones registradas.',
        OLD.nombre;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_li_validar
  BEFORE UPDATE ON public.liderazgo_indicadores
  FOR EACH ROW EXECUTE FUNCTION public.validar_indicador_liderazgo();


-- -----------------------------------------------------------------
-- 6. RLS: liderazgo_indicadores
-- -----------------------------------------------------------------
CREATE POLICY "Admin gestiona liderazgo_indicadores"
  ON public.liderazgo_indicadores FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee liderazgo_indicadores"
  ON public.liderazgo_indicadores FOR SELECT TO authenticated
  USING (true);


-- -----------------------------------------------------------------
-- 7. RLS: liderazgo_evaluaciones
-- -----------------------------------------------------------------
CREATE POLICY "Admin gestiona liderazgo_evaluaciones"
  ON public.liderazgo_evaluaciones FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee liderazgo_evaluaciones"
  ON public.liderazgo_evaluaciones FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Evaluador inserta liderazgo_evaluaciones"
  ON public.liderazgo_evaluaciones FOR INSERT TO authenticated
  WITH CHECK (NOT public.es_admin());

CREATE POLICY "Evaluador actualiza liderazgo_evaluaciones"
  ON public.liderazgo_evaluaciones FOR UPDATE TO authenticated
  USING  (NOT public.es_admin())
  WITH CHECK (NOT public.es_admin());


-- -----------------------------------------------------------------
-- 8. VISTA: v_liderazgo_equipo_dia
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_liderazgo_equipo_dia AS
WITH activos AS (
  SELECT COUNT(*)::int               AS total_indicadores,
         COALESCE(SUM(puntaje_max), 0)::numeric AS puntaje_max_total
    FROM public.liderazgo_indicadores
   WHERE activo = true
),
base AS (
  SELECT e.id   AS equipo_id,
         e.nombre AS equipo_nombre,
         e.color  AS equipo_color,
         p.id   AS programacion_id,
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
       b.equipo_nombre,
       b.equipo_color,
       b.programacion_id,
       b.momento,
       COALESCE(ev.puntos_obtenidos,       0) AS puntos_obtenidos,
       a.puntaje_max_total                    AS puntos_max,
       COALESCE(ev.indicadores_calificados, 0) AS indicadores_calificados,
       a.total_indicadores
  FROM base    b
  CROSS JOIN activos a
  LEFT  JOIN evaluados ev
    ON ev.equipo_id      = b.equipo_id
   AND ev.programacion_id = b.programacion_id;


-- -----------------------------------------------------------------
-- 9. VISTA: v_validacion_indicadores
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_validacion_indicadores AS
SELECT
  COUNT(*)::int                         AS total_activos,
  COALESCE(SUM(puntaje_max), 0)::int    AS puntaje_total_activos,
  COALESCE(SUM(puntaje_max), 0) = 100   AS ok
FROM public.liderazgo_indicadores
WHERE activo = true;


-- -----------------------------------------------------------------
-- 10. VISTA PÚBLICA: publico_liderazgo_indicadores
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_liderazgo_indicadores AS
SELECT codigo, nombre, descripcion, evidencia
  FROM public.liderazgo_indicadores
 WHERE activo = true
 ORDER BY orden;

GRANT SELECT ON public.publico_liderazgo_indicadores TO anon;


-- -----------------------------------------------------------------
-- 11. SEED: indicadores L1-L4 (provisionales)
-- -----------------------------------------------------------------
INSERT INTO public.liderazgo_indicadores
  (codigo, nombre, descripcion, evidencia, puntaje_max, orden)
VALUES
  ('L1', 'Involucramiento',
   'Al menos el 95 % del equipo participa de la actividad de inicio a fin.',
   'Verificar que prácticamente todos los integrantes estén presentes y activos durante toda la actividad.',
   25, 1),
  ('L2', 'Unidad y coordinación',
   'El grupo trabaja unido, con roles distribuidos y coordinados entre sí.',
   'Observar si cada integrante tiene un rol claro y si el equipo actúa de forma cohesionada.',
   25, 2),
  ('L3', 'Ánimo y entusiasmo',
   'Actitud positiva que contagia entusiasmo a otros.',
   'Evaluar expresiones de ánimo, energía y si ese espíritu se transmite a quienes los rodean.',
   25, 3),
  ('L4', 'Servicio en la labor misionera',
   'Cumple la labor asignada con espíritu de servicio, orden y organización.',
   'Revisar si el equipo completa la tarea con actitud de servicio y deja el espacio ordenado.',
   25, 4)
ON CONFLICT (codigo) DO NOTHING;


-- -----------------------------------------------------------------
-- 12. SEED: evaluaciones de prueba
-- -----------------------------------------------------------------
DO $$
DECLARE
  v_prog_j  uuid;  v_prog_v  uuid;
  v_l1 uuid; v_l2 uuid; v_l3 uuid; v_l4 uuid;
  v_alfa uuid; v_beta uuid; v_gamma uuid;
BEGIN
  SELECT id INTO v_l1 FROM public.liderazgo_indicadores WHERE codigo = 'L1';
  SELECT id INTO v_l2 FROM public.liderazgo_indicadores WHERE codigo = 'L2';
  SELECT id INTO v_l3 FROM public.liderazgo_indicadores WHERE codigo = 'L3';
  SELECT id INTO v_l4 FROM public.liderazgo_indicadores WHERE codigo = 'L4';

  SELECT p.id INTO v_prog_j
    FROM public.programacion p JOIN public.criterios c ON c.id = p.criterio_id
   WHERE c.tipo_calculo = 'liderazgo' AND p.momento = 'J' AND p.estado = 'programado'
   LIMIT 1;

  SELECT p.id INTO v_prog_v
    FROM public.programacion p JOIN public.criterios c ON c.id = p.criterio_id
   WHERE c.tipo_calculo = 'liderazgo' AND p.momento = 'V' AND p.estado = 'programado'
   LIMIT 1;

  SELECT id INTO v_alfa  FROM public.equipos WHERE nombre = 'Alfa';
  SELECT id INTO v_beta  FROM public.equipos WHERE nombre = 'Beta';
  SELECT id INTO v_gamma FROM public.equipos WHERE nombre = 'Gamma';

  IF v_prog_j IS NOT NULL AND v_alfa IS NOT NULL THEN
    INSERT INTO public.liderazgo_evaluaciones
      (equipo_id, programacion_id, indicador_id, nivel, comentario)
    VALUES
      (v_alfa, v_prog_j, v_l1, 4, 'Participación total'),
      (v_alfa, v_prog_j, v_l2, 4, 'Muy bien coordinados'),
      (v_alfa, v_prog_j, v_l3, 4, NULL),
      (v_alfa, v_prog_j, v_l4, 3, 'Buen servicio, pequeña desorganización al final')
    ON CONFLICT (equipo_id, programacion_id, indicador_id) DO NOTHING;
  END IF;

  IF v_prog_j IS NOT NULL AND v_beta IS NOT NULL THEN
    INSERT INTO public.liderazgo_evaluaciones
      (equipo_id, programacion_id, indicador_id, nivel, comentario)
    VALUES
      (v_beta, v_prog_j, v_l1, 3, NULL),
      (v_beta, v_prog_j, v_l2, 3, NULL),
      (v_beta, v_prog_j, v_l3, 4, 'Muy entusiastas'),
      (v_beta, v_prog_j, v_l4, 2, 'Faltó más organización')
    ON CONFLICT (equipo_id, programacion_id, indicador_id) DO NOTHING;
  END IF;

  IF v_prog_v IS NOT NULL AND v_alfa IS NOT NULL THEN
    INSERT INTO public.liderazgo_evaluaciones
      (equipo_id, programacion_id, indicador_id, nivel, comentario)
    VALUES
      (v_alfa, v_prog_v, v_l1, 4, NULL),
      (v_alfa, v_prog_v, v_l2, 4, NULL),
      (v_alfa, v_prog_v, v_l3, 3, NULL),
      (v_alfa, v_prog_v, v_l4, 4, NULL)
    ON CONFLICT (equipo_id, programacion_id, indicador_id) DO NOTHING;
  END IF;

  IF v_prog_v IS NOT NULL AND v_beta IS NOT NULL THEN
    INSERT INTO public.liderazgo_evaluaciones
      (equipo_id, programacion_id, indicador_id, nivel, comentario)
    VALUES
      (v_beta, v_prog_v, v_l1, 2, NULL),
      (v_beta, v_prog_v, v_l2, 3, NULL)
    ON CONFLICT (equipo_id, programacion_id, indicador_id) DO NOTHING;
  END IF;

  IF v_prog_j IS NOT NULL AND v_gamma IS NOT NULL THEN
    INSERT INTO public.liderazgo_evaluaciones
      (equipo_id, programacion_id, indicador_id, nivel, comentario)
    VALUES
      (v_gamma, v_prog_j, v_l1, 3, NULL)
    ON CONFLICT (equipo_id, programacion_id, indicador_id) DO NOTHING;
  END IF;
END $$;
