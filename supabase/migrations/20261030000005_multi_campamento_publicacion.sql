-- =================================================================
-- Multi-campamento (parte 3): dias_evaluacion por campamento
-- • Cambia PK de dias_evaluacion: momento text → (campamento_id, momento)
-- • Actualiza v_pendientes_publicacion con campamento_id
-- • cerrar_campamento / reabrir_campamento aceptan p_campamento_id
-- • fn_campamento_cerrado_check con overload que acepta campamento_id
-- • Triggers de validación usan campamento del equipo
-- =================================================================


-- =================================================================
-- 1. REESTRUCTURAR dias_evaluacion
-- =================================================================

-- 1a. Quitar vistas/funciones que dependen de dias_evaluacion
DROP VIEW IF EXISTS public.v_pendientes_publicacion CASCADE;

-- 1b. Agregar campamento_id (nullable para hacer backfill)
ALTER TABLE public.dias_evaluacion
  ADD COLUMN IF NOT EXISTS campamento_id uuid REFERENCES public.campamento(id) ON DELETE CASCADE;

-- 1c. Backfill: asignar el campamento activo (o el más reciente) a las 4 filas existentes
UPDATE public.dias_evaluacion
   SET campamento_id = (
     SELECT id FROM public.campamento
     ORDER BY activo DESC, created_at DESC
     LIMIT 1
   )
 WHERE campamento_id IS NULL;

-- 1d. Quitar PK simple (momento)
ALTER TABLE public.dias_evaluacion
  DROP CONSTRAINT IF EXISTS dias_evaluacion_pkey;

-- 1e. Imponer NOT NULL en campamento_id y crear PK compuesta
ALTER TABLE public.dias_evaluacion
  ALTER COLUMN campamento_id SET NOT NULL;

ALTER TABLE public.dias_evaluacion
  ADD CONSTRAINT dias_evaluacion_pkey PRIMARY KEY (campamento_id, momento);

-- 1f. Índice para búsquedas por campamento
CREATE INDEX IF NOT EXISTS idx_dias_evaluacion_campamento
  ON public.dias_evaluacion (campamento_id);

-- 1g. Seed: para cada campamento existente asegurar que tenga 4 días
--     (los códigos válidos vienen de dias_campamento.codigo)
INSERT INTO public.dias_evaluacion (campamento_id, momento)
SELECT DISTINCT dc.campamento_id, dc.codigo
FROM   public.dias_campamento dc
ON CONFLICT (campamento_id, momento) DO NOTHING;


-- =================================================================
-- 2. RECREAR v_pendientes_publicacion con campamento_id
--    El frontend filtra: .eq('campamento_id', id)
-- =================================================================
CREATE OR REPLACE VIEW public.v_pendientes_publicacion
  WITH (security_invoker = true)
AS
WITH dias AS (
  SELECT campamento_id, momento, publicado, cerrado
  FROM public.dias_evaluacion
),
equipos_por_camp AS (
  SELECT campamento_id, COUNT(*) AS total
  FROM public.equipos
  WHERE activo = true
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
  COALESCE(ec.total, 0)                                   AS equipos_activos,
  COALESCE(o.equipos_con_rubrica,   0)                    AS equipos_rubrica,
  COALESCE(l.equipos_con_liderazgo, 0)                    AS equipos_liderazgo,
  COALESCE(asis.tiene_asistencia,   false)                AS tiene_asistencia
FROM dias d
LEFT JOIN equipos_por_camp ec   ON ec.campamento_id = d.campamento_id
LEFT JOIN obs_por_dia      o    ON o.campamento_id  = d.campamento_id AND o.momento  = d.momento
LEFT JOIN asis_por_dia     asis ON asis.campamento_id = d.campamento_id AND asis.momento = d.momento
LEFT JOIN lid_por_dia      l    ON l.campamento_id  = d.campamento_id AND l.momento  = d.momento
ORDER BY
  d.campamento_id,
  CASE d.momento WHEN 'J' THEN 1 WHEN 'V' THEN 2 WHEN 'S' THEN 3 WHEN 'D' THEN 4 ELSE 5 END;


-- =================================================================
-- 3. fn_campamento_cerrado_check con campamento_id explícito
-- =================================================================

-- Versión sin parámetros: chequea todos los campamentos activos
-- (compatibilidad: si alguno está cerrado y el usuario no es admin → bloquea)
-- Se mantiene para llamadas legacy, pero los triggers la irán reemplazando.
CREATE OR REPLACE FUNCTION public.fn_campamento_cerrado_check()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_cerrado boolean;
BEGIN
  -- Con multi-campamento, la versión sin parámetros no puede saber
  -- cuál campamento aplica → no bloquea (usar la versión con parámetro)
  -- Solo bloquea si TODOS los campamentos están cerrados (caso extremo).
  SELECT bool_and(cerrado) INTO v_cerrado FROM public.campamento WHERE activo = true;
  IF COALESCE(v_cerrado, false) AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'Todos los campamentos activos están cerrados.';
  END IF;
END;
$$;

-- Versión con campamento_id explícito (usada por los triggers actualizados)
CREATE OR REPLACE FUNCTION public.fn_campamento_cerrado_check(p_campamento_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_cerrado boolean;
BEGIN
  SELECT cerrado INTO v_cerrado
    FROM public.campamento
   WHERE id = p_campamento_id;
  IF COALESCE(v_cerrado, false) AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'El campamento está cerrado. No se pueden registrar ni modificar datos.';
  END IF;
END;
$$;

REVOKE ALL  ON FUNCTION public.fn_campamento_cerrado_check(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_campamento_cerrado_check(uuid) TO authenticated;


-- =================================================================
-- 4. cerrar_campamento y reabrir_campamento con p_campamento_id
-- =================================================================
CREATE OR REPLACE FUNCTION public.cerrar_campamento(
  p_campamento_id uuid,
  p_motivo        text,
  p_forzar        boolean DEFAULT false
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_pendientes int;
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede cerrar el campamento.';
  END IF;
  IF NOT p_forzar THEN
    SELECT COUNT(*) INTO v_pendientes
      FROM public.incidencias i
      JOIN public.equipos     e ON e.id = i.equipo_id
     WHERE i.estado = 'registrado'
       AND e.campamento_id = p_campamento_id;
    IF v_pendientes > 0 THEN
      RAISE EXCEPTION
        'Hay % incidencia(s) sin resolver. Usa p_forzar=true para cerrar igualmente.', v_pendientes;
    END IF;
  END IF;
  UPDATE public.campamento
     SET cerrado       = true,
         cerrado_at    = now(),
         cerrado_por   = auth.uid(),
         motivo_cierre = p_motivo
   WHERE id = p_campamento_id;
END;
$$;

REVOKE ALL  ON FUNCTION public.cerrar_campamento(uuid, text, boolean) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cerrar_campamento(uuid, text, boolean) TO authenticated;

-- Mantener firma antigua (sin campamento_id) redirigiendo al activo para no romper clientes viejos
-- Se puede eliminar en un ciclo futuro.
CREATE OR REPLACE FUNCTION public.cerrar_campamento(p_motivo text, p_forzar boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.campamento WHERE activo = true ORDER BY created_at DESC LIMIT 1;
  IF v_id IS NULL THEN RAISE EXCEPTION 'No hay campamento activo.'; END IF;
  PERFORM public.cerrar_campamento(v_id, p_motivo, p_forzar);
END;
$$;


CREATE OR REPLACE FUNCTION public.reabrir_campamento(p_campamento_id uuid, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede reabrir el campamento.';
  END IF;
  UPDATE public.campamento
     SET cerrado       = false,
         cerrado_at    = NULL,
         cerrado_por   = NULL,
         motivo_cierre = p_motivo
   WHERE id = p_campamento_id;
END;
$$;

REVOKE ALL  ON FUNCTION public.reabrir_campamento(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.reabrir_campamento(uuid, text) TO authenticated;

-- Firma antigua de compatibilidad
CREATE OR REPLACE FUNCTION public.reabrir_campamento(p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.campamento WHERE activo = true ORDER BY created_at DESC LIMIT 1;
  IF v_id IS NULL THEN RAISE EXCEPTION 'No hay campamento activo.'; END IF;
  PERFORM public.reabrir_campamento(v_id, p_motivo);
END;
$$;


-- =================================================================
-- 5. Actualizar triggers de validación para usar campamento del equipo
-- =================================================================

-- 5a. validar_observacion
CREATE OR REPLACE FUNCTION public.validar_observacion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog        record;
  v_criterio    record;
  v_equipo      record;
  v_dia         record;
BEGIN
  -- Obtener programación
  SELECT p.estado, p.momento, p.criterio_id
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = NEW.programacion_id;

  -- 1. Programación debe estar en estado 'programado'
  IF v_prog.estado <> 'programado' THEN
    RAISE EXCEPTION
      'La programación seleccionada no está en estado programado (estado actual: %).', v_prog.estado;
  END IF;

  -- 2. Criterio debe ser tipo rúbrica y activo
  SELECT c.tipo_calculo, c.activo, c.nombre
    INTO v_criterio
    FROM public.criterios c
   WHERE c.id = v_prog.criterio_id;

  IF v_criterio.tipo_calculo <> 'rubrica' THEN
    RAISE EXCEPTION
      'Solo se pueden registrar observaciones para criterios de tipo rúbrica (criterio: %).', v_criterio.nombre;
  END IF;

  IF NOT v_criterio.activo THEN
    RAISE EXCEPTION 'El criterio "%" está inactivo.', v_criterio.nombre;
  END IF;

  -- 3. Equipo debe estar activo; obtener campamento_id
  SELECT e.activo, e.nombre, e.campamento_id
    INTO v_equipo
    FROM public.equipos e
   WHERE e.id = NEW.equipo_id;

  IF NOT v_equipo.activo THEN
    RAISE EXCEPTION 'El equipo "%" está inactivo.', v_equipo.nombre;
  END IF;

  -- 4. Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check(v_equipo.campamento_id);

  -- 5. Si el día (del campamento del equipo) está cerrado, solo admin puede escribir
  SELECT d.cerrado
    INTO v_dia
    FROM public.dias_evaluacion d
   WHERE d.campamento_id = v_equipo.campamento_id
     AND d.momento       = v_prog.momento;

  IF v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION
      'El día % está cerrado. Solo el administrador puede modificar observaciones.', v_prog.momento;
  END IF;

  -- 6. En UPDATE, motivo obligatorio si cambia el puntaje
  IF TG_OP = 'UPDATE' AND NEW.puntaje <> OLD.puntaje THEN
    IF NEW.motivo_cambio IS NULL OR trim(NEW.motivo_cambio) = '' THEN
      RAISE EXCEPTION 'Debes indicar el motivo del cambio de puntaje.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


-- 5b. validar_asistencia_registro
CREATE OR REPLACE FUNCTION public.validar_asistencia_registro()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_integrante record;
  v_actividad  record;
  v_prog       record;
  v_equipo     record;
  v_dia        record;
BEGIN
  -- 1. Integrante debe ser activo y elegible
  SELECT i.activo, i.elegible, i.nombres, i.apellidos, i.equipo_id
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

  -- 3. Obtener campamento_id del equipo del integrante
  SELECT e.campamento_id
    INTO v_equipo
    FROM public.equipos e
   WHERE e.id = v_integrante.equipo_id;

  -- 4. Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check(v_equipo.campamento_id);

  -- 5. Si el día está cerrado, solo admin puede escribir
  SELECT p.momento
    INTO v_prog
    FROM public.programacion p
   WHERE p.id = v_actividad.programacion_id;

  SELECT d.cerrado
    INTO v_dia
    FROM public.dias_evaluacion d
   WHERE d.campamento_id = v_equipo.campamento_id
     AND d.momento       = v_prog.momento;

  IF v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION
      'El día % está cerrado. Solo el administrador puede modificar registros.', v_prog.momento;
  END IF;

  RETURN NEW;
END;
$$;


-- 5c. validar_evaluacion_liderazgo
CREATE OR REPLACE FUNCTION public.validar_evaluacion_liderazgo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog   record;
  v_equipo record;
  v_dia    record;
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
    RAISE EXCEPTION
      'La programación no está en estado "programado" (estado actual: %).', v_prog.estado;
  END IF;

  -- Equipo activo + campamento_id
  SELECT e.campamento_id
    INTO v_equipo
    FROM public.equipos e
   WHERE e.id = NEW.equipo_id AND e.activo = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El equipo no está activo.';
  END IF;

  -- Indicador activo
  IF NOT EXISTS (
    SELECT 1 FROM public.liderazgo_indicadores WHERE id = NEW.indicador_id AND activo = true
  ) THEN
    RAISE EXCEPTION 'El indicador de liderazgo no está activo.';
  END IF;

  -- Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check(v_equipo.campamento_id);

  -- Día cerrado: solo admin puede operar
  SELECT d.cerrado INTO v_dia
    FROM public.dias_evaluacion d
   WHERE d.campamento_id = v_equipo.campamento_id
     AND d.momento       = v_prog.momento;

  IF FOUND AND v_dia.cerrado AND NOT public.es_admin() THEN
    RAISE EXCEPTION
      'El día % está cerrado. Solo el administrador puede modificar evaluaciones.', v_prog.momento;
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


-- 5d. fn_validar_incidencia
CREATE OR REPLACE FUNCTION public.fn_validar_incidencia()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cat           record;
  v_equipo        record;
  v_dia_cerrado   boolean;
  v_acciones      int;
  v_integrantes   int;
BEGIN
  -- En contexto de migración / service_role (sin auth.uid) omitir validación
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Catálogo
  SELECT * INTO v_cat FROM public.incidencia_codigos WHERE codigo = NEW.codigo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Código de incidencia no encontrado: %', NEW.codigo;
  END IF;
  IF NOT v_cat.activo THEN
    RAISE EXCEPTION 'El código % no está activo.', NEW.codigo;
  END IF;

  -- hecho obligatorio
  IF NEW.hecho IS NULL OR trim(NEW.hecho) = '' THEN
    RAISE EXCEPTION 'El campo "hecho" es obligatorio.';
  END IF;

  -- D6 → alcance siempre individual
  IF v_cat.por_persona THEN
    NEW.alcance := 'individual';
  END IF;

  -- alcance=individual (no D6) → justificacion_grupal obligatoria
  IF NEW.alcance = 'individual' AND NOT v_cat.por_persona THEN
    IF NEW.justificacion_grupal IS NULL OR trim(NEW.justificacion_grupal) = '' THEN
      RAISE EXCEPTION
        'Se requiere justificación grupal cuando el alcance es individual y el código no es D6.';
    END IF;
  END IF;

  -- B2 → equipo_apoyado_id obligatorio y distinto
  IF v_cat.requiere_equipo_apoyado THEN
    IF NEW.equipo_apoyado_id IS NULL THEN
      RAISE EXCEPTION 'El código % requiere indicar el equipo apoyado.', NEW.codigo;
    END IF;
    IF NEW.equipo_apoyado_id = NEW.equipo_id THEN
      RAISE EXCEPTION 'El equipo apoyado debe ser distinto del equipo que registra el bonus.';
    END IF;
  END IF;

  -- D1 → advertencia_referencia obligatoria
  IF v_cat.requiere_advertencia THEN
    IF NEW.advertencia_referencia IS NULL OR trim(NEW.advertencia_referencia) = '' THEN
      RAISE EXCEPTION 'El código D1 requiere indicar la advertencia previa.';
    END IF;
  END IF;

  -- Obtener campamento del equipo
  SELECT e.campamento_id
    INTO v_equipo
    FROM public.equipos e
   WHERE e.id = NEW.equipo_id;

  IF FOUND THEN
    -- Campamento cerrado
    PERFORM public.fn_campamento_cerrado_check(v_equipo.campamento_id);

    -- Día cerrado → solo admin
    IF NEW.momento IS NOT NULL THEN
      SELECT cerrado INTO v_dia_cerrado
        FROM public.dias_evaluacion
       WHERE campamento_id = v_equipo.campamento_id
         AND momento       = NEW.momento;
      IF FOUND AND v_dia_cerrado AND NOT public.es_admin() THEN
        RAISE EXCEPTION
          'El día % está cerrado. Solo el administrador puede registrar incidencias.', NEW.momento;
      END IF;
    END IF;
  END IF;

  -- Solo admin puede cambiar a validado/rechazado
  IF NEW.estado IN ('validado','rechazado') AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede validar o rechazar incidencias.';
  END IF;

  -- Incidencia ya validada: solo admin puede modificarla
  IF TG_OP = 'UPDATE' AND OLD.estado = 'validado' AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'Una incidencia validada no puede ser modificada por un evaluador.';
  END IF;

  -- Validaciones adicionales al cambiar a validado
  IF NEW.estado = 'validado'
     AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.estado <> 'validado'))
  THEN
    IF NEW.descargo_equipo IS NULL OR trim(NEW.descargo_equipo) = '' THEN
      RAISE EXCEPTION
        'Al validar una incidencia se requiere registrar el descargo del equipo.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
