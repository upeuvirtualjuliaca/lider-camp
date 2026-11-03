-- =============================================================================
-- Permite crear actividades para cualquier tipo de criterio activo.
-- Se elimina la restricción que solo aceptaba 'asistencia'.
-- =============================================================================

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

  IF NOT v_criterio.activo THEN
    RAISE EXCEPTION 'El criterio "%" está inactivo.', v_criterio.nombre;
  END IF;

  RETURN NEW;
END;
$$;
