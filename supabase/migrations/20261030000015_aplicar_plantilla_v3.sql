CREATE OR REPLACE FUNCTION public.aplicar_plantilla_a_campamento(
  p_campamento_id uuid,
  p_items         jsonb   -- [{criterio_id, momento, puntaje_max, estado}, ...]
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF (SELECT rol FROM public.perfiles WHERE id = auth.uid()) <> 'admin' THEN
    RAISE EXCEPTION 'Solo administradores pueden aplicar plantillas';
  END IF;

  -- 1. Eliminar programacion de criterios que ya no están en la selección
  DELETE FROM public.programacion
  WHERE campamento_id = p_campamento_id
    AND criterio_id NOT IN (
      SELECT (elem->>'criterio_id')::uuid
      FROM jsonb_array_elements(p_items) AS elem
    );

  -- 2. Sincronizar campamento_criterios (quitar los que ya no están)
  DELETE FROM public.campamento_criterios
  WHERE campamento_id = p_campamento_id
    AND criterio_id NOT IN (
      SELECT (elem->>'criterio_id')::uuid
      FROM jsonb_array_elements(p_items) AS elem
    );

  -- 3. Insertar los nuevos criterios activos (sin crear programacion)
  INSERT INTO public.campamento_criterios (campamento_id, criterio_id)
  SELECT p_campamento_id, (elem->>'criterio_id')::uuid
  FROM jsonb_array_elements(p_items) AS elem
  ON CONFLICT DO NOTHING;

  SELECT count(*) INTO v_count
  FROM public.campamento_criterios
  WHERE campamento_id = p_campamento_id;

  RETURN v_count;
END;
$$;
