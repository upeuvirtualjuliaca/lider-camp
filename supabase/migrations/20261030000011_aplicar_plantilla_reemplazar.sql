-- =================================================================
-- Fix: aplicar_plantilla_a_campamento ahora REEMPLAZA completamente
-- la programación del campamento con los items del payload.
-- Rows de criterios que ya no están en la selección se eliminan.
-- =================================================================

CREATE OR REPLACE FUNCTION public.aplicar_plantilla_a_campamento(
  p_campamento_id uuid,
  p_items         jsonb   -- [{criterio_id, momento, puntaje_max, estado}, ...]
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_item  jsonb;
  v_count int := 0;
BEGIN
  -- Solo admin puede aplicar
  IF (SELECT rol FROM public.perfiles WHERE id = auth.uid()) <> 'admin' THEN
    RAISE EXCEPTION 'Solo administradores pueden aplicar plantillas';
  END IF;

  -- 1. Eliminar filas del campamento cuyos criterios NO están en el nuevo payload
  --    Esto limpia criterios de applies anteriores que ya no forman parte de la selección.
  DELETE FROM public.programacion
  WHERE campamento_id = p_campamento_id
    AND criterio_id NOT IN (
      SELECT (elem->>'criterio_id')::uuid
      FROM jsonb_array_elements(p_items) AS elem
    );

  -- 2. Upsert los items del payload (inserta o actualiza)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.programacion (campamento_id, criterio_id, momento, puntaje_max, estado)
    VALUES (
      p_campamento_id,
      (v_item->>'criterio_id')::uuid,
       v_item->>'momento',
      (v_item->>'puntaje_max')::int,
       v_item->>'estado'
    )
    ON CONFLICT (criterio_id, momento, campamento_id) DO UPDATE SET
      puntaje_max = EXCLUDED.puntaje_max,
      estado      = EXCLUDED.estado,
      updated_at  = now();

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
