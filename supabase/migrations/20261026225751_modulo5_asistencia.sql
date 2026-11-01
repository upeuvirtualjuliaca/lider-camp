-- =============================================================================
-- Módulo 5: Asistencia y participación
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. TABLA actividades
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.actividades (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  programacion_id      uuid        NOT NULL REFERENCES public.programacion(id),
  nombre               text        NOT NULL,
  descripcion          text,
  hora_inicio          time,
  lugar                text,
  estado               text        NOT NULL DEFAULT 'programada'
                                   CHECK (estado IN ('programada','realizada','cancelada')),
  motivo_cancelacion   text,
  evaluador_id         uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES public.perfiles(id),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_actividad_cancelacion
    CHECK (estado <> 'cancelada' OR motivo_cancelacion IS NOT NULL)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TABLA asistencia_registros
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.asistencia_registros (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actividad_id         uuid        NOT NULL REFERENCES public.actividades(id),
  integrante_id        uuid        NOT NULL REFERENCES public.integrantes(id),
  estado               text        NOT NULL
                                   CHECK (estado IN ('presente','ausente','justificado')),
  motivo_justificacion text,
  documentado          boolean     NOT NULL DEFAULT false,
  evaluador_id         uuid        NOT NULL DEFAULT auth.uid()
                                   REFERENCES public.perfiles(id),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (actividad_id, integrante_id),
  CONSTRAINT ck_justificado_motivo
    CHECK (estado <> 'justificado' OR motivo_justificacion IS NOT NULL)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. TRIGGERS: updated_at
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_updated_at_actividades
  BEFORE UPDATE ON public.actividades
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_updated_at_asistencia_registros
  BEFORE UPDATE ON public.asistencia_registros
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TRIGGERS: auditoría (reutiliza registrar_auditoria() — ambas tablas son uuid PK)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_auditoria_actividades
  AFTER INSERT OR UPDATE OR DELETE ON public.actividades
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

CREATE TRIGGER trg_auditoria_asistencia_registros
  AFTER INSERT OR UPDATE OR DELETE ON public.asistencia_registros
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. TRIGGER: validación de asistencia_registros
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validar_asistencia_registro()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_integrante record;
  v_actividad  record;
  v_prog       record;
  v_dia        record;
BEGIN
  -- 1. Integrante debe ser activo y elegible
  SELECT i.activo, i.elegible, i.nombres, i.apellidos
    INTO v_integrante
    FROM public.integrantes i
   WHERE i.id = NEW.integrante_id;

  IF NOT v_integrante.activo THEN
    RAISE EXCEPTION 'El integrante % % está inactivo.',
      v_integrante.nombres, v_integrante.apellidos;
  END IF;

  IF NOT v_integrante.elegible THEN
    RAISE EXCEPTION 'El integrante % % no es elegible para este campamento.',
      v_integrante.nombres, v_integrante.apellidos;
  END IF;

  -- 2. Actividad no puede estar cancelada
  SELECT a.estado, a.programacion_id
    INTO v_actividad
    FROM public.actividades a
   WHERE a.id = NEW.actividad_id;

  IF v_actividad.estado = 'cancelada' THEN
    RAISE EXCEPTION 'No se puede registrar asistencia en una actividad cancelada.';
  END IF;

  -- 3. Si el día está cerrado, solo admin puede escribir
  SELECT p.momento
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = v_actividad.programacion_id;

  SELECT d.cerrado
    INTO v_dia
    FROM public.dias_evaluacion d
   WHERE d.momento = v_prog.momento;

  IF v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'El día % está cerrado. Solo el administrador puede modificar registros.',
      v_prog.momento;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_asistencia_registro
  BEFORE INSERT OR UPDATE ON public.asistencia_registros
  FOR EACH ROW EXECUTE FUNCTION public.validar_asistencia_registro();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. TRIGGER: validación de actividades (programacion debe ser tipo asistencia)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validar_actividad()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog     record;
  v_criterio record;
BEGIN
  SELECT p.estado, p.criterio_id
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = NEW.programacion_id;

  IF v_prog.estado <> 'programado' THEN
    RAISE EXCEPTION 'La programación seleccionada no está en estado programado.';
  END IF;

  SELECT c.tipo_calculo, c.nombre, c.activo
    INTO v_criterio
    FROM public.criterios c
   WHERE c.id = v_prog.criterio_id;

  IF v_criterio.tipo_calculo <> 'asistencia' THEN
    RAISE EXCEPTION 'Solo se pueden crear actividades para criterios de tipo asistencia (criterio: %).', v_criterio.nombre;
  END IF;

  IF NOT v_criterio.activo THEN
    RAISE EXCEPTION 'El criterio "%" está inactivo.', v_criterio.nombre;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_actividad
  BEFORE INSERT OR UPDATE ON public.actividades
  FOR EACH ROW EXECUTE FUNCTION public.validar_actividad();

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. VISTA v_asistencia_equipo_actividad
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_asistencia_equipo_actividad AS
SELECT
  e.id                                                          AS equipo_id,
  e.nombre                                                      AS equipo_nombre,
  a.id                                                          AS actividad_id,
  a.nombre                                                      AS actividad_nombre,
  a.estado                                                      AS actividad_estado,
  p.criterio_id,
  p.momento,
  -- elegibles: integrantes activos y elegibles del equipo
  COUNT(DISTINCT i.id)                                          AS elegibles,
  -- justificados documentados (exentos del denominador)
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'justificado' AND ar.documentado = true
    THEN ar.integrante_id END)                                  AS justificados,
  -- convocados_elegibles = elegibles - justificados documentados
  COUNT(DISTINCT i.id)
    - COUNT(DISTINCT CASE
        WHEN ar.estado = 'justificado' AND ar.documentado = true
        THEN ar.integrante_id END)                              AS convocados_elegibles,
  -- presentes
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'presente' THEN ar.integrante_id END)      AS presentes,
  -- ausentes registrados explícitamente
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'ausente' THEN ar.integrante_id END)       AS ausentes,
  -- sin registro aún
  COUNT(DISTINCT i.id) - COUNT(DISTINCT ar.integrante_id)       AS sin_registro,
  -- puntaje: NULL si convocados_elegibles = 0
  CASE
    WHEN (COUNT(DISTINCT i.id)
          - COUNT(DISTINCT CASE
              WHEN ar.estado = 'justificado' AND ar.documentado = true
              THEN ar.integrante_id END)) = 0
    THEN NULL
    ELSE ROUND(
      LEAST(
        100::numeric,
        COUNT(DISTINCT CASE WHEN ar.estado = 'presente' THEN ar.integrante_id END)::numeric
        / (COUNT(DISTINCT i.id)
           - COUNT(DISTINCT CASE
               WHEN ar.estado = 'justificado' AND ar.documentado = true
               THEN ar.integrante_id END))::numeric
        / 0.95
        * 100
      ), 2
    )
  END                                                           AS puntaje,
  -- provisional si la actividad aún no se marcó como realizada
  (a.estado <> 'realizada')                                    AS provisional
FROM public.actividades a
JOIN public.programacion p  ON p.id  = a.programacion_id
JOIN public.criterios c     ON c.id  = p.criterio_id
CROSS JOIN public.equipos e
JOIN public.integrantes i
  ON i.equipo_id = e.id
  AND i.activo   = true
  AND i.elegible = true
LEFT JOIN public.asistencia_registros ar
  ON ar.actividad_id   = a.id
  AND ar.integrante_id = i.id
WHERE a.estado <> 'cancelada'
  AND e.activo = true
GROUP BY e.id, e.nombre, a.id, a.nombre, a.estado, p.criterio_id, p.momento;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. VISTA v_asistencia_equipo_dia
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_asistencia_equipo_dia AS
SELECT
  v.equipo_id,
  v.equipo_nombre,
  v.criterio_id,
  v.momento,
  COUNT(*)::integer                                             AS num_actividades,
  COUNT(v.puntaje)::integer                                    AS actividades_con_puntaje,
  ROUND(AVG(v.puntaje), 2)                                     AS puntaje_promedio,
  BOOL_OR(v.puntaje IS NULL)                                   AS reprogramar,
  BOOL_OR(v.provisional)                                       AS provisional
FROM public.v_asistencia_equipo_actividad v
GROUP BY v.equipo_id, v.equipo_nombre, v.criterio_id, v.momento;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RLS — actividades
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.actividades ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticados pueden ver actividades"
  ON public.actividades FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "admin puede insertar actividades"
  ON public.actividades FOR INSERT
  TO authenticated WITH CHECK (public.es_admin());

CREATE POLICY "admin puede actualizar actividades"
  ON public.actividades FOR UPDATE
  TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());

CREATE POLICY "admin puede eliminar actividades"
  ON public.actividades FOR DELETE
  TO authenticated USING (public.es_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. RLS — asistencia_registros
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.asistencia_registros ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticados pueden ver asistencia"
  ON public.asistencia_registros FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "autenticados pueden insertar asistencia"
  ON public.asistencia_registros FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "autenticados pueden actualizar asistencia"
  ON public.asistencia_registros FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "admin puede eliminar asistencia"
  ON public.asistencia_registros FOR DELETE
  TO authenticated USING (public.es_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. Bloquear acceso anon
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON public.actividades                    FROM anon;
REVOKE ALL ON public.asistencia_registros           FROM anon;
REVOKE ALL ON public.v_asistencia_equipo_actividad  FROM anon;
REVOKE ALL ON public.v_asistencia_equipo_dia        FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. SEED — actividades y registros de asistencia
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  -- programacion ids
  v_prog_est_j uuid;  -- EST momento J
  v_prog_est_v uuid;  -- EST momento V
  v_prog_eve_v uuid;  -- EVE momento V

  -- actividad ids
  v_act_est_j uuid;
  v_act_est_v uuid;
  v_act_eve_v uuid;

  -- equipo ids
  v_alfa    uuid;
  v_beta    uuid;
  v_gamma   uuid;

  -- evaluador
  v_eval uuid;

  -- integrantes de Alfa (para el caso 17/18 = 99.42)
  v_ints_alfa uuid[];
  v_int_id    uuid;
  v_idx       int;
BEGIN
  -- Evaluador
  SELECT id INTO v_eval FROM public.perfiles LIMIT 1;
  IF v_eval IS NULL THEN
    RAISE NOTICE 'Seed asistencia omitido: sin perfiles.';
    RETURN;
  END IF;

  -- Equipos
  SELECT id INTO v_alfa  FROM public.equipos WHERE nombre = 'Alfa';
  SELECT id INTO v_beta  FROM public.equipos WHERE nombre = 'Beta';
  SELECT id INTO v_gamma FROM public.equipos WHERE nombre = 'Gamma';
  IF v_alfa IS NULL THEN
    RAISE NOTICE 'Seed asistencia omitido: sin equipos.';
    RETURN;
  END IF;

  -- Programaciones asistencia
  SELECT p.id INTO v_prog_est_j
    FROM public.programacion p JOIN public.criterios c ON c.id = p.criterio_id
   WHERE c.codigo = 'EST' AND p.momento = 'J' AND p.estado = 'programado';

  SELECT p.id INTO v_prog_est_v
    FROM public.programacion p JOIN public.criterios c ON c.id = p.criterio_id
   WHERE c.codigo = 'EST' AND p.momento = 'V' AND p.estado = 'programado';

  SELECT p.id INTO v_prog_eve_v
    FROM public.programacion p JOIN public.criterios c ON c.id = p.criterio_id
   WHERE c.codigo = 'EVE' AND p.momento = 'V' AND p.estado = 'programado';

  IF v_prog_est_j IS NULL THEN
    RAISE NOTICE 'Seed asistencia omitido: programaciones no encontradas.';
    RETURN;
  END IF;

  -- ── Crear actividades ────────────────────────────────────────────────────
  INSERT INTO public.actividades
    (id, programacion_id, nombre, hora_inicio, lugar, estado, evaluador_id)
  VALUES
    (gen_random_uuid(), v_prog_est_j,
     'Programa estelar — Jueves',   '20:00', 'Auditorio principal', 'realizada', v_eval),
    (gen_random_uuid(), v_prog_est_v,
     'Programa estelar — Viernes',  '20:00', 'Auditorio principal', 'realizada', v_eval),
    (gen_random_uuid(), v_prog_eve_v,
     'Actividad deportiva — Viernes','09:00', 'Campo deportivo',    'realizada', v_eval)
  ON CONFLICT DO NOTHING;

  -- Obtener ids de las actividades recién insertadas
  SELECT id INTO v_act_est_j
    FROM public.actividades
   WHERE programacion_id = v_prog_est_j AND nombre = 'Programa estelar — Jueves';

  SELECT id INTO v_act_est_v
    FROM public.actividades
   WHERE programacion_id = v_prog_est_v AND nombre = 'Programa estelar — Viernes';

  SELECT id INTO v_act_eve_v
    FROM public.actividades
   WHERE programacion_id = v_prog_eve_v AND nombre = 'Actividad deportiva — Viernes';

  -- ── Alfa: EST Jueves — 17 presentes de 18 elegibles → 99.42 ─────────────
  -- Los primeros 17 integrantes elegibles = presente; el último = ausente
  SELECT ARRAY(
    SELECT id FROM public.integrantes
     WHERE equipo_id = v_alfa AND activo = true AND elegible = true
     ORDER BY apellidos, nombres
     LIMIT 18
  ) INTO v_ints_alfa;

  FOREACH v_int_id IN ARRAY v_ints_alfa LOOP
    v_idx := array_position(v_ints_alfa, v_int_id);
    INSERT INTO public.asistencia_registros
      (actividad_id, integrante_id, estado, evaluador_id)
    VALUES (
      v_act_est_j,
      v_int_id,
      CASE WHEN v_idx <= 17 THEN 'presente' ELSE 'ausente' END,
      v_eval
    )
    ON CONFLICT (actividad_id, integrante_id) DO NOTHING;
  END LOOP;

  -- ── Alfa: EST Viernes — todos presentes → 100 ────────────────────────────
  INSERT INTO public.asistencia_registros (actividad_id, integrante_id, estado, evaluador_id)
  SELECT v_act_est_v, i.id, 'presente', v_eval
    FROM public.integrantes i
   WHERE i.equipo_id = v_alfa AND i.activo = true AND i.elegible = true
  ON CONFLICT (actividad_id, integrante_id) DO NOTHING;

  -- ── Beta: EST Jueves — todos presentes → 100 ─────────────────────────────
  INSERT INTO public.asistencia_registros (actividad_id, integrante_id, estado, evaluador_id)
  SELECT v_act_est_j, i.id, 'presente', v_eval
    FROM public.integrantes i
   WHERE i.equipo_id = v_beta AND i.activo = true AND i.elegible = true
  ON CONFLICT (actividad_id, integrante_id) DO NOTHING;

  -- ── Beta: EVE Viernes — 1 justificado documentado + resto presentes ──────
  -- El primer integrante es justificado (documentado=true); los demás, presentes
  -- Esto verifica que justificado documentado sí descuenta del denominador
  INSERT INTO public.asistencia_registros
    (actividad_id, integrante_id, estado, motivo_justificacion, documentado, evaluador_id)
  SELECT
    v_act_eve_v,
    i.id,
    CASE WHEN rn = 1 THEN 'justificado' ELSE 'presente' END,
    CASE WHEN rn = 1 THEN 'Cita médica documentada con certificado' ELSE NULL END,
    CASE WHEN rn = 1 THEN true ELSE false END,
    v_eval
  FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY apellidos, nombres) AS rn
      FROM public.integrantes
     WHERE equipo_id = v_beta AND activo = true AND elegible = true
  ) i
  ON CONFLICT (actividad_id, integrante_id) DO NOTHING;

  -- ── Gamma: EST Jueves — 1 justificado NO documentado + 14 presentes ──────
  -- Verifica que justificado sin documentar NO descuenta del denominador
  INSERT INTO public.asistencia_registros
    (actividad_id, integrante_id, estado, motivo_justificacion, documentado, evaluador_id)
  SELECT
    v_act_est_j,
    i.id,
    CASE WHEN rn = 1 THEN 'justificado' ELSE 'presente' END,
    CASE WHEN rn = 1 THEN 'Dice que estuvo enfermo (sin documentar)' ELSE NULL END,
    false,
    v_eval
  FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY apellidos, nombres) AS rn
      FROM public.integrantes
     WHERE equipo_id = v_gamma AND activo = true AND elegible = true
     LIMIT 15
  ) i
  ON CONFLICT (actividad_id, integrante_id) DO NOTHING;

  RAISE NOTICE 'Seed asistencia completado.';
END;
$$;
