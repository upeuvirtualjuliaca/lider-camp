-- =================================================================
-- Módulo 9: Auditoría, solicitudes de revisión, cierre y reportes
-- =================================================================
-- A. Índices adicionales en auditoria + fn_diff_jsonb + v_auditoria_legible
-- B. solicitudes_revision + v_pendientes_publicacion
-- C. Cierre de campamento (campamento.cerrado + fn_campamento_cerrado_check +
--    actualización de los 4 triggers de validación)
-- D. Funciones RPC: cerrar_campamento, reabrir_campamento
-- =================================================================


-- -----------------------------------------------------------------
-- A1. Índices adicionales en auditoria
-- -----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario
  ON public.auditoria (usuario_id);

CREATE INDEX IF NOT EXISTS idx_auditoria_accion
  ON public.auditoria (accion);


-- -----------------------------------------------------------------
-- A2. Función auxiliar: diff entre dos JSONB (solo claves que cambiaron)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_diff_jsonb(antes jsonb, despues jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT
    jsonb_object_agg(
      k,
      jsonb_build_object('antes', antes -> k, 'despues', despues -> k)
    )
  FROM (
    SELECT DISTINCT key AS k
    FROM (
      SELECT jsonb_object_keys(COALESCE(antes,  '{}')) AS key
      UNION
      SELECT jsonb_object_keys(COALESCE(despues, '{}')) AS key
    ) keys
    WHERE COALESCE(antes,  '{}') -> key IS DISTINCT FROM
          COALESCE(despues, '{}') -> key
  ) changed_keys
$$;


-- -----------------------------------------------------------------
-- A3. Vista v_auditoria_legible (solo admin — security_invoker)
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_auditoria_legible
  WITH (security_invoker = true)
AS
SELECT
  a.id,
  a.created_at,
  a.tabla,
  a.registro_id,
  a.accion,
  a.datos_anteriores,
  a.datos_nuevos,
  CASE
    WHEN a.accion = 'UPDATE' THEN
      public.fn_diff_jsonb(a.datos_anteriores, a.datos_nuevos)
    ELSE NULL
  END                                              AS cambios,
  a.usuario_id,
  p.nombre_completo                                AS evaluador_nombre,
  p.rol                                            AS evaluador_rol
FROM public.auditoria a
LEFT JOIN public.perfiles p ON p.id = a.usuario_id;

-- Admin solo puede leer la vista (RLS en auditoria ya bloquea a evaluadores)
CREATE POLICY "Admin lee auditoria"
  ON public.auditoria FOR SELECT TO authenticated
  USING (public.es_admin());

-- Evaluador no puede SELECT (política no existe → denegado por defecto con RLS)
-- La vista heredará el context del llamante (security_invoker) → evaluador ve nada


-- -----------------------------------------------------------------
-- A4. Función RPC: historial de un registro
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.historial_registro(p_tabla text, p_id uuid)
RETURNS TABLE (
  id               uuid,
  created_at       timestamptz,
  accion           text,
  datos_anteriores jsonb,
  datos_nuevos     jsonb,
  cambios          jsonb,
  evaluador_nombre text,
  evaluador_rol    text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    a.id,
    a.created_at,
    a.accion,
    a.datos_anteriores,
    a.datos_nuevos,
    CASE
      WHEN a.accion = 'UPDATE' THEN
        public.fn_diff_jsonb(a.datos_anteriores, a.datos_nuevos)
      ELSE NULL
    END,
    p.nombre_completo,
    p.rol
  FROM public.auditoria a
  LEFT JOIN public.perfiles p ON p.id = a.usuario_id
  WHERE a.tabla = p_tabla AND a.registro_id = p_id
  ORDER BY a.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.historial_registro(text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.historial_registro(text, uuid) TO authenticated;


-- -----------------------------------------------------------------
-- B1. Tabla solicitudes_revision
-- -----------------------------------------------------------------
CREATE TABLE public.solicitudes_revision (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tabla            text        NOT NULL,    -- tabla afectada
  registro_id      uuid        NOT NULL,    -- PK del registro en cuestión
  descripcion      text        NOT NULL,    -- motivo de la solicitud
  solicitante_id   uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  estado           text        NOT NULL DEFAULT 'pendiente'
                                CHECK (estado IN ('pendiente','aprobada','rechazada')),
  respuesta        text,                    -- comentario del admin al resolver
  resuelto_por     uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  resuelto_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.solicitudes_revision ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_sr_updated_at
  BEFORE UPDATE ON public.solicitudes_revision
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_sr_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.solicitudes_revision
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- Evaluadores crean y ven sus propias solicitudes; admin ve todo
CREATE POLICY "Evaluador crea solicitud"
  ON public.solicitudes_revision FOR INSERT TO authenticated
  WITH CHECK (solicitante_id = auth.uid());

CREATE POLICY "Evaluador ve sus solicitudes"
  ON public.solicitudes_revision FOR SELECT TO authenticated
  USING (solicitante_id = auth.uid() OR public.es_admin());

CREATE POLICY "Admin actualiza solicitudes"
  ON public.solicitudes_revision FOR UPDATE TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Admin elimina solicitudes"
  ON public.solicitudes_revision FOR DELETE TO authenticated
  USING (public.es_admin());

-- Índices
CREATE INDEX idx_sr_estado         ON public.solicitudes_revision (estado);
CREATE INDEX idx_sr_solicitante    ON public.solicitudes_revision (solicitante_id);
CREATE INDEX idx_sr_tabla_registro ON public.solicitudes_revision (tabla, registro_id);


-- -----------------------------------------------------------------
-- B2. Función para resolver una solicitud (admin) — actualiza estado
--     y opcionalmente devuelve el registro auditado
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolver_solicitud(
  p_id       uuid,
  p_decision text,   -- 'aprobada' | 'rechazada'
  p_respuesta text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede resolver solicitudes.';
  END IF;

  IF p_decision NOT IN ('aprobada','rechazada') THEN
    RAISE EXCEPTION 'Decisión inválida: %. Use "aprobada" o "rechazada".', p_decision;
  END IF;

  UPDATE public.solicitudes_revision
     SET estado       = p_decision,
         respuesta    = p_respuesta,
         resuelto_por = auth.uid(),
         resuelto_at  = now()
   WHERE id = p_id AND estado = 'pendiente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada o ya resuelta.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_solicitud(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.resolver_solicitud(uuid, text, text) TO authenticated;


-- -----------------------------------------------------------------
-- B3. Vista v_pendientes_publicacion
--     Días activos con indicadores de completitud (solo admin la usa)
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_pendientes_publicacion
  WITH (security_invoker = true)
AS
WITH dias AS (
  SELECT momento, publicado, cerrado FROM public.dias_evaluacion
),
equipos_activos AS (
  SELECT COUNT(*) AS total FROM public.equipos WHERE activo = true
),
obs_por_dia AS (
  SELECT
    p.momento,
    COUNT(DISTINCT o.equipo_id)                              AS equipos_con_rubrica
  FROM public.observaciones o
  JOIN public.programacion  p ON p.id = o.programacion_id
  GROUP BY p.momento
),
asis_por_dia AS (
  SELECT
    p.momento,
    COUNT(DISTINCT ar.integrante_id) > 0                     AS tiene_asistencia
  FROM public.asistencia_registros ar
  JOIN public.actividades          a  ON a.id  = ar.actividad_id
  JOIN public.programacion         p  ON p.id  = a.programacion_id
  GROUP BY p.momento
),
lid_por_dia AS (
  SELECT
    p.momento,
    COUNT(DISTINCT le.equipo_id)                             AS equipos_con_liderazgo
  FROM public.liderazgo_evaluaciones le
  JOIN public.programacion           p ON p.id = le.programacion_id
  GROUP BY p.momento
)
SELECT
  d.momento,
  d.publicado,
  d.cerrado,
  ea.total                                                    AS equipos_activos,
  COALESCE(o.equipos_con_rubrica,  0)                         AS equipos_rubrica,
  COALESCE(l.equipos_con_liderazgo,0)                         AS equipos_liderazgo,
  COALESCE(asis.tiene_asistencia,  false)                     AS tiene_asistencia
FROM dias d
CROSS JOIN equipos_activos ea
LEFT JOIN obs_por_dia  o    ON o.momento    = d.momento
LEFT JOIN asis_por_dia asis ON asis.momento = d.momento
LEFT JOIN lid_por_dia  l    ON l.momento    = d.momento
ORDER BY
  CASE d.momento WHEN 'J' THEN 1 WHEN 'V' THEN 2 WHEN 'S' THEN 3 WHEN 'D' THEN 4 ELSE 5 END;


-- -----------------------------------------------------------------
-- C1. Columnas de cierre en campamento
-- -----------------------------------------------------------------
ALTER TABLE public.campamento
  ADD COLUMN IF NOT EXISTS cerrado       boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cerrado_at    timestamptz,
  ADD COLUMN IF NOT EXISTS cerrado_por   uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS motivo_cierre text;


-- -----------------------------------------------------------------
-- C2. Función fn_campamento_cerrado_check()
--     SECURITY DEFINER: llaman los triggers de validación.
--     Bloquea a evaluadores cuando cerrado=true; admin puede seguir.
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campamento_cerrado_check()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cerrado boolean;
BEGIN
  SELECT cerrado INTO v_cerrado FROM public.campamento LIMIT 1;
  IF COALESCE(v_cerrado, false) AND NOT public.es_admin() THEN
    RAISE EXCEPTION
      'El campamento está cerrado. No se pueden registrar ni modificar datos.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_campamento_cerrado_check() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_campamento_cerrado_check() TO authenticated;


-- -----------------------------------------------------------------
-- C3. Actualizar validar_observacion — añadir chequeo de cierre
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_observacion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog     record;
  v_criterio record;
  v_equipo   record;
  v_dia      record;
BEGIN
  -- Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check();

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
    RAISE EXCEPTION
      'El día % está cerrado. Solo el administrador puede modificar observaciones.', v_prog.momento;
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


-- -----------------------------------------------------------------
-- C4. Actualizar validar_asistencia_registro — añadir chequeo de cierre
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_asistencia_registro()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_integrante record;
  v_actividad  record;
  v_prog       record;
  v_dia        record;
BEGIN
  -- Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check();

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
    RAISE EXCEPTION
      'El día % está cerrado. Solo el administrador puede modificar registros.', v_prog.momento;
  END IF;

  RETURN NEW;
END;
$$;


-- -----------------------------------------------------------------
-- C5. Actualizar validar_evaluacion_liderazgo — añadir chequeo de cierre
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validar_evaluacion_liderazgo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prog  record;
  v_dia   record;
BEGIN
  -- Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check();

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

  -- Equipo activo
  IF NOT EXISTS (SELECT 1 FROM public.equipos WHERE id = NEW.equipo_id AND activo = true) THEN
    RAISE EXCEPTION 'El equipo no está activo.';
  END IF;

  -- Indicador activo
  IF NOT EXISTS (
    SELECT 1 FROM public.liderazgo_indicadores WHERE id = NEW.indicador_id AND activo = true
  ) THEN
    RAISE EXCEPTION 'El indicador de liderazgo no está activo.';
  END IF;

  -- Día cerrado: solo admin puede operar
  SELECT cerrado INTO v_dia
    FROM public.dias_evaluacion WHERE momento = v_prog.momento;

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


-- -----------------------------------------------------------------
-- C6. Actualizar fn_validar_incidencia — añadir chequeo de cierre
--     (DESPUÉS del bypass de auth.uid() IS NULL)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validar_incidencia()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cat         record;
  v_dia_cerrado boolean;
  v_acciones    int;
  v_integrantes int;
BEGIN
  -- En contexto de migración / service_role (sin auth.uid) omitir validación
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Campamento cerrado
  PERFORM public.fn_campamento_cerrado_check();

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

  -- D6 → alcance siempre individual (forzar silenciosamente)
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

  -- Día cerrado → solo admin
  IF NEW.momento IS NOT NULL THEN
    SELECT cerrado INTO v_dia_cerrado
      FROM public.dias_evaluacion
     WHERE momento = NEW.momento;
    IF FOUND AND v_dia_cerrado AND NOT public.es_admin() THEN
      RAISE EXCEPTION
        'El día % está cerrado. Solo el administrador puede registrar incidencias.', NEW.momento;
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
    -- descargo_equipo obligatorio
    IF NEW.descargo_equipo IS NULL OR trim(NEW.descargo_equipo) = '' THEN
      RAISE EXCEPTION
        'Registra el descargo del equipo (o indica "No presentó descargo") antes de validar.';
    END IF;
    -- motivo_resolucion obligatorio
    IF NEW.motivo_resolucion IS NULL OR trim(NEW.motivo_resolucion) = '' THEN
      RAISE EXCEPTION 'El motivo de resolución es obligatorio al validar.';
    END IF;

    -- Verificar max_acciones
    IF v_cat.max_acciones IS NOT NULL THEN
      SELECT COUNT(*)::int INTO v_acciones
        FROM public.incidencias
       WHERE equipo_id = NEW.equipo_id
         AND codigo    = NEW.codigo
         AND estado    = 'validado'
         AND id       <> NEW.id;
      IF v_acciones >= v_cat.max_acciones THEN
        RAISE EXCEPTION
          'El equipo ya alcanzó el máximo de % acción(es) validada(s) para el código %.',
          v_cat.max_acciones, NEW.codigo;
      END IF;
    END IF;

    -- D6: verificar cantidad_personas = COUNT(incidencia_integrantes)
    IF v_cat.por_persona THEN
      SELECT COUNT(*)::int INTO v_integrantes
        FROM public.incidencia_integrantes
       WHERE incidencia_id = NEW.id;
      IF v_integrantes = 0 THEN
        RAISE EXCEPTION 'D6 requiere al menos un integrante registrado.';
      END IF;
      IF v_integrantes <> NEW.cantidad_personas THEN
        RAISE EXCEPTION
          'La cantidad de personas (%) no coincide con los integrantes registrados (%).',
          NEW.cantidad_personas, v_integrantes;
      END IF;
    END IF;

    -- Marcar quién validó
    NEW.validado_por := auth.uid();
    NEW.validado_at  := now();
  END IF;

  RETURN NEW;
END;
$$;


-- -----------------------------------------------------------------
-- D1. Función RPC: cerrar_campamento
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cerrar_campamento(
  p_motivo  text,
  p_forzar  boolean DEFAULT false
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_pendientes int;
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede cerrar el campamento.';
  END IF;

  -- Verificar incidencias pendientes (a menos que p_forzar=true)
  IF NOT p_forzar THEN
    SELECT COUNT(*) INTO v_pendientes
      FROM public.incidencias
     WHERE estado = 'registrado';

    IF v_pendientes > 0 THEN
      RAISE EXCEPTION
        'Hay % incidencia(s) sin resolver. Resuélvelas o usa p_forzar=true para cerrar igualmente.',
        v_pendientes;
    END IF;
  END IF;

  UPDATE public.campamento
     SET cerrado       = true,
         cerrado_at    = now(),
         cerrado_por   = auth.uid(),
         motivo_cierre = p_motivo;
END;
$$;

REVOKE ALL ON FUNCTION public.cerrar_campamento(text, boolean) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cerrar_campamento(text, boolean) TO authenticated;


-- -----------------------------------------------------------------
-- D2. Función RPC: reabrir_campamento
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reabrir_campamento(p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede reabrir el campamento.';
  END IF;

  UPDATE public.campamento
     SET cerrado       = false,
         cerrado_at    = NULL,
         cerrado_por   = NULL,
         motivo_cierre = p_motivo;   -- guardar como "motivo de reapertura" para auditoría
END;
$$;

REVOKE ALL ON FUNCTION public.reabrir_campamento(text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.reabrir_campamento(text) TO authenticated;


-- -----------------------------------------------------------------
-- Seed: 2 solicitudes de revisión de prueba (idempotente)
-- (Solo se insertan si ya existe al menos un evaluador en perfiles)
-- -----------------------------------------------------------------
DO $$
DECLARE
  v_eval_id  uuid;
  v_obs_id   uuid;
BEGIN
  -- Tomar el primer evaluador disponible
  SELECT id INTO v_eval_id FROM public.perfiles WHERE rol = 'evaluador' LIMIT 1;
  IF v_eval_id IS NULL THEN RETURN; END IF;

  -- Tomar la primera observación disponible
  SELECT id INTO v_obs_id FROM public.observaciones LIMIT 1;
  IF v_obs_id IS NULL THEN RETURN; END IF;

  INSERT INTO public.solicitudes_revision
    (tabla, registro_id, descripcion, solicitante_id, estado)
  VALUES
    ('observaciones', v_obs_id,
     'El puntaje registrado no coincide con lo observado en campo. Solicito revisión.',
     v_eval_id, 'pendiente'),
    ('observaciones', v_obs_id,
     'Posible error en criterio "Basurero" del día J — el equipo sí cumplió.',
     v_eval_id, 'pendiente')
  ON CONFLICT DO NOTHING;
END;
$$;
