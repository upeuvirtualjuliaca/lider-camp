-- =============================================================================
-- Módulo 4: Observaciones diarias (rúbricas)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. TABLA dias_evaluacion
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.dias_evaluacion (
  momento       text        PRIMARY KEY CHECK (momento IN ('J','V','S','D')),
  cerrado       boolean     NOT NULL DEFAULT false,
  cerrado_at    timestamptz,
  cerrado_por   uuid        REFERENCES public.perfiles(id),
  publicado     boolean     NOT NULL DEFAULT false,
  publicado_at  timestamptz,
  publicado_por uuid        REFERENCES public.perfiles(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_cerrado_campos
    CHECK (cerrado = false OR (cerrado_at IS NOT NULL AND cerrado_por IS NOT NULL))
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TABLA observaciones
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.observaciones (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  equipo_id       uuid        NOT NULL REFERENCES public.equipos(id),
  programacion_id uuid        NOT NULL REFERENCES public.programacion(id),
  puntaje         integer     NOT NULL CHECK (puntaje IN (0, 25, 50, 75, 100)),
  comentario      text,
  evaluador_id    uuid        NOT NULL DEFAULT auth.uid() REFERENCES public.perfiles(id),
  motivo_cambio   text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (equipo_id, programacion_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. FUNCIÓN y TRIGGER: updated_at
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_updated_at_dias_evaluacion
  BEFORE UPDATE ON public.dias_evaluacion
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_updated_at_observaciones
  BEFORE UPDATE ON public.observaciones
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FUNCIÓN y TRIGGER: auditoría
-- ─────────────────────────────────────────────────────────────────────────────
-- Función de auditoría para tablas con PK uuid llamada "id"
CREATE OR REPLACE FUNCTION public.registrar_auditoria()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.auditoria (accion, tabla, registro_id, datos_anteriores, datos_nuevos, usuario_id)
  VALUES (
    TG_OP,
    TG_TABLE_NAME,
    CASE TG_OP WHEN 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE TG_OP WHEN 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE TG_OP WHEN 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
    auth.uid()
  );
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_auditoria_observaciones
  AFTER INSERT OR UPDATE OR DELETE ON public.observaciones
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- dias_evaluacion no guarda puntajes → no requiere trigger de auditoría
-- (los cambios de cierre/apertura quedan en cerrado_por + cerrado_at)

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. FUNCIÓN y TRIGGER: validación de observaciones
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validar_observacion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog     record;
  v_criterio record;
  v_equipo   record;
  v_dia      record;
BEGIN
  -- Obtener programación
  SELECT p.estado, p.momento, p.criterio_id
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = NEW.programacion_id;

  -- 1. Programación debe estar en estado 'programado'
  IF v_prog.estado <> 'programado' THEN
    RAISE EXCEPTION 'La programación seleccionada no está en estado programado (estado actual: %).', v_prog.estado;
  END IF;

  -- 2. Criterio debe ser tipo rúbrica y activo
  SELECT c.tipo_calculo, c.activo, c.nombre
    INTO v_criterio
    FROM public.criterios c
   WHERE c.id = v_prog.criterio_id;

  IF v_criterio.tipo_calculo <> 'rubrica' THEN
    RAISE EXCEPTION 'Solo se pueden registrar observaciones para criterios de tipo rúbrica (criterio: %).', v_criterio.nombre;
  END IF;

  IF NOT v_criterio.activo THEN
    RAISE EXCEPTION 'El criterio "%" está inactivo.', v_criterio.nombre;
  END IF;

  -- 3. Equipo debe estar activo
  SELECT e.activo, e.nombre
    INTO v_equipo
    FROM public.equipos e
   WHERE e.id = NEW.equipo_id;

  IF NOT v_equipo.activo THEN
    RAISE EXCEPTION 'El equipo "%" está inactivo.', v_equipo.nombre;
  END IF;

  -- 4. Si el día está cerrado, solo admin puede escribir
  SELECT d.cerrado
    INTO v_dia
    FROM public.dias_evaluacion d
   WHERE d.momento = v_prog.momento;

  IF v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'El día % está cerrado. Solo el administrador puede modificar observaciones.', v_prog.momento;
  END IF;

  -- 5. En UPDATE, motivo obligatorio si cambia el puntaje
  IF TG_OP = 'UPDATE' AND NEW.puntaje <> OLD.puntaje THEN
    IF NEW.motivo_cambio IS NULL OR trim(NEW.motivo_cambio) = '' THEN
      RAISE EXCEPTION 'Debes indicar el motivo del cambio de puntaje.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_observacion
  BEFORE INSERT OR UPDATE ON public.observaciones
  FOR EACH ROW EXECUTE FUNCTION public.validar_observacion();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. VISTA v_puntaje_rubrica_equipo_dia
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_puntaje_rubrica_equipo_dia AS
SELECT
  e.id                                            AS equipo_id,
  e.nombre                                        AS equipo_nombre,
  e.color                                         AS equipo_color,
  p.momento,
  COALESCE(SUM(o.puntaje), 0)::integer            AS suma_puntaje,
  SUM(p.puntaje_max)::integer                     AS maximo_posible,
  COUNT(o.id)::integer                            AS criterios_calificados,
  (COUNT(p.id) - COUNT(o.id))::integer            AS criterios_pendientes
FROM public.programacion p
JOIN public.criterios c ON c.id = p.criterio_id
CROSS JOIN public.equipos e
LEFT JOIN public.observaciones o
       ON o.programacion_id = p.id
      AND o.equipo_id       = e.id
WHERE p.estado       = 'programado'
  AND c.tipo_calculo = 'rubrica'
  AND c.activo       = true
  AND e.activo       = true
GROUP BY e.id, e.nombre, e.color, p.momento;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. VISTA v_progreso_evaluacion
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_progreso_evaluacion AS
WITH base AS (
  SELECT
    p.id      AS prog_id,
    p.momento,
    e.id      AS equipo_id
  FROM public.programacion p
  JOIN public.criterios c ON c.id = p.criterio_id
  CROSS JOIN public.equipos e
  WHERE p.estado       = 'programado'
    AND c.tipo_calculo = 'rubrica'
    AND c.activo       = true
    AND e.activo       = true
)
SELECT
  b.momento,
  COUNT(*)                                                     AS observaciones_esperadas,
  COUNT(o.id)                                                  AS observaciones_registradas,
  ROUND(COUNT(o.id)::numeric / NULLIF(COUNT(*), 0) * 100, 1)  AS porcentaje
FROM base b
LEFT JOIN public.observaciones o
       ON o.programacion_id = b.prog_id
      AND o.equipo_id       = b.equipo_id
GROUP BY b.momento;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RLS — dias_evaluacion
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.dias_evaluacion ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticados pueden ver dias"
  ON public.dias_evaluacion FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "admin puede insertar dias"
  ON public.dias_evaluacion FOR INSERT
  TO authenticated WITH CHECK (public.es_admin());

CREATE POLICY "admin puede actualizar dias"
  ON public.dias_evaluacion FOR UPDATE
  TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. RLS — observaciones
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.observaciones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "autenticados pueden ver observaciones"
  ON public.observaciones FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "autenticados pueden insertar observaciones"
  ON public.observaciones FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "autenticados pueden actualizar observaciones"
  ON public.observaciones FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "admin puede eliminar observaciones"
  ON public.observaciones FOR DELETE
  TO authenticated USING (public.es_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. Bloquear acceso anon
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON public.dias_evaluacion              FROM anon;
REVOKE ALL ON public.observaciones                FROM anon;
REVOKE ALL ON public.v_puntaje_rubrica_equipo_dia FROM anon;
REVOKE ALL ON public.v_progreso_evaluacion        FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. SEED — 4 filas de dias_evaluacion
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.dias_evaluacion (momento) VALUES
  ('J'), ('V'), ('S'), ('D')
ON CONFLICT (momento) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. SEED — observaciones aleatorias para J y V (algunas pendientes)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_alfa    uuid; v_beta  uuid; v_gamma   uuid;
  v_delta   uuid; v_epsilon uuid;

  v_car_j uuid; v_cer_j uuid; v_bas_j uuid; v_ten_j uuid;
  v_oli_j uuid; v_ole_j uuid; v_coo_j uuid; v_col_j uuid;
  v_com_j uuid; v_bam_j uuid; v_ban_j uuid;

  v_car_v uuid; v_cer_v uuid; v_bas_v uuid; v_ten_v uuid;
  v_por_v uuid; v_oli_v uuid; v_ole_v uuid; v_coo_v uuid;
  v_col_v uuid; v_com_v uuid; v_iza_v uuid; v_bam_v uuid;
  v_ban_v uuid;

  v_eval uuid;
BEGIN
  SELECT id INTO v_alfa    FROM public.equipos WHERE nombre = 'Alfa';
  SELECT id INTO v_beta    FROM public.equipos WHERE nombre = 'Beta';
  SELECT id INTO v_gamma   FROM public.equipos WHERE nombre = 'Gamma';
  SELECT id INTO v_delta   FROM public.equipos WHERE nombre = 'Delta';
  SELECT id INTO v_epsilon FROM public.equipos WHERE nombre = 'Épsilon';
  SELECT id INTO v_eval    FROM public.perfiles LIMIT 1;

  IF v_alfa IS NULL OR v_eval IS NULL THEN
    RAISE NOTICE 'Seed observaciones omitido: faltan equipos o perfiles.';
    RETURN;
  END IF;

  -- Programación J
  SELECT p.id INTO v_car_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='CAR' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_cer_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='CER' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_bas_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAS' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_ten_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='TEN' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_oli_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='OLI' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_ole_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='OLE' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_coo_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COO' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_col_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COL' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_com_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COM' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_bam_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAM' AND p.momento='J' AND p.estado='programado';
  SELECT p.id INTO v_ban_j FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAN' AND p.momento='J' AND p.estado='programado';

  -- Programación V
  SELECT p.id INTO v_car_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='CAR' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_cer_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='CER' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_bas_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAS' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_ten_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='TEN' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_por_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='POR' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_oli_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='OLI' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_ole_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='OLE' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_coo_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COO' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_col_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COL' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_com_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='COM' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_iza_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='IZA' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_bam_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAM' AND p.momento='V' AND p.estado='programado';
  SELECT p.id INTO v_ban_v FROM public.programacion p JOIN public.criterios c ON c.id=p.criterio_id WHERE c.codigo='BAN' AND p.momento='V' AND p.estado='programado';

  -- J — Alfa (completo: 11/11)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_alfa, v_car_j, 100, v_eval), (v_alfa, v_cer_j, 100, v_eval),
    (v_alfa, v_bas_j,  75, v_eval), (v_alfa, v_ten_j, 100, v_eval),
    (v_alfa, v_oli_j,  75, v_eval), (v_alfa, v_ole_j, 100, v_eval),
    (v_alfa, v_coo_j,  75, v_eval), (v_alfa, v_col_j, 100, v_eval),
    (v_alfa, v_com_j,  75, v_eval), (v_alfa, v_bam_j, 100, v_eval),
    (v_alfa, v_ban_j,  75, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- J — Beta (completo: 11/11)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_beta, v_car_j,  75, v_eval), (v_beta, v_cer_j, 100, v_eval),
    (v_beta, v_bas_j, 100, v_eval), (v_beta, v_ten_j,  75, v_eval),
    (v_beta, v_oli_j, 100, v_eval), (v_beta, v_ole_j,  75, v_eval),
    (v_beta, v_coo_j, 100, v_eval), (v_beta, v_col_j,  75, v_eval),
    (v_beta, v_com_j, 100, v_eval), (v_beta, v_bam_j,  50, v_eval),
    (v_beta, v_ban_j,  75, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- J — Gamma (parcial: 9/11, falta bam y ban)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_gamma, v_car_j,  50, v_eval), (v_gamma, v_cer_j,  75, v_eval),
    (v_gamma, v_bas_j,  50, v_eval), (v_gamma, v_ten_j,  75, v_eval),
    (v_gamma, v_oli_j,  50, v_eval), (v_gamma, v_ole_j,  75, v_eval),
    (v_gamma, v_coo_j,  50, v_eval), (v_gamma, v_col_j,  75, v_eval),
    (v_gamma, v_com_j,  50, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- J — Delta (parcial: 6/11)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_delta, v_car_j,  75, v_eval), (v_delta, v_cer_j,  75, v_eval),
    (v_delta, v_bas_j,  75, v_eval), (v_delta, v_ten_j,  50, v_eval),
    (v_delta, v_oli_j,  75, v_eval), (v_delta, v_ole_j,  50, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- J — Épsilon: sin calificar (0/11)

  -- V — Alfa (completo: 13/13)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_alfa, v_car_v, 100, v_eval), (v_alfa, v_cer_v, 100, v_eval),
    (v_alfa, v_bas_v,  75, v_eval), (v_alfa, v_ten_v, 100, v_eval),
    (v_alfa, v_por_v, 100, v_eval), (v_alfa, v_oli_v, 100, v_eval),
    (v_alfa, v_ole_v,  75, v_eval), (v_alfa, v_coo_v, 100, v_eval),
    (v_alfa, v_col_v,  75, v_eval), (v_alfa, v_com_v, 100, v_eval),
    (v_alfa, v_iza_v, 100, v_eval), (v_alfa, v_bam_v, 100, v_eval),
    (v_alfa, v_ban_v,  75, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- V — Beta (completo: 13/13)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_beta, v_car_v,  75, v_eval), (v_beta, v_cer_v, 100, v_eval),
    (v_beta, v_bas_v, 100, v_eval), (v_beta, v_ten_v,  75, v_eval),
    (v_beta, v_por_v,  75, v_eval), (v_beta, v_oli_v,  75, v_eval),
    (v_beta, v_ole_v, 100, v_eval), (v_beta, v_coo_v,  75, v_eval),
    (v_beta, v_col_v, 100, v_eval), (v_beta, v_com_v,  75, v_eval),
    (v_beta, v_iza_v,  75, v_eval), (v_beta, v_bam_v,  75, v_eval),
    (v_beta, v_ban_v, 100, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- V — Gamma (parcial: 8/13)
  INSERT INTO public.observaciones (equipo_id, programacion_id, puntaje, evaluador_id) VALUES
    (v_gamma, v_car_v,  50, v_eval), (v_gamma, v_cer_v,  75, v_eval),
    (v_gamma, v_bas_v,  75, v_eval), (v_gamma, v_ten_v,  50, v_eval),
    (v_gamma, v_por_v,  50, v_eval), (v_gamma, v_oli_v,  75, v_eval),
    (v_gamma, v_ole_v,  50, v_eval), (v_gamma, v_coo_v,  75, v_eval)
  ON CONFLICT (equipo_id, programacion_id) DO NOTHING;

  -- V — Delta y Épsilon: sin calificar

  RAISE NOTICE 'Seed observaciones completado.';
END;
$$;
