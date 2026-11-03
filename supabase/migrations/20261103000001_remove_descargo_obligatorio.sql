-- Elimina la restricción que exigía descargo_equipo para poder validar una incidencia.
CREATE OR REPLACE FUNCTION public.fn_validar_incidencia()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cat           record;
  v_equipo        record;
  v_dia_cerrado   boolean;
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

  RETURN NEW;
END;
$$;
