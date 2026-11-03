-- Corrige fn_calcular_puntos_incidencia para que solo sobreescriba puntos
-- cuando el código es por_persona (D6). Para bonus y otros deméritos, el
-- evaluador puede elegir los puntos libremente desde el formulario.
CREATE OR REPLACE FUNCTION public.fn_calcular_puntos_incidencia()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_cat record;
BEGIN
  SELECT * INTO v_cat
    FROM public.incidencia_codigos
   WHERE codigo = NEW.codigo;

  -- Solo D6 (por_persona=true) recalcula: puntos_catalogo × cantidad_personas
  IF FOUND AND v_cat.por_persona THEN
    NEW.puntos := ROUND(v_cat.puntos::numeric * NEW.cantidad_personas, 2);
  END IF;

  RETURN NEW;
END;
$$;
