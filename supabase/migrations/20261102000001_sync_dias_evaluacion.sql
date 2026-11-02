-- =============================================================================
-- Sincronizar dias_evaluacion con dias_campamento
-- Problema: al agregar un nuevo día en dias_campamento, dias_evaluacion
-- no se actualiza automáticamente, por lo que ese día no aparece en
-- v_pendientes_publicacion ni en la vista de Publicación.
-- =============================================================================

-- 1. Insertar filas faltantes en dias_evaluacion para todos los campamentos
--    (cubre el día X-Miércoles y cualquier otro que se haya omitido)
INSERT INTO public.dias_evaluacion (campamento_id, momento)
SELECT dc.campamento_id, dc.codigo
FROM   public.dias_campamento dc
WHERE  NOT EXISTS (
  SELECT 1
  FROM   public.dias_evaluacion de
  WHERE  de.campamento_id = dc.campamento_id
    AND  de.momento       = dc.codigo
)
ON CONFLICT (campamento_id, momento) DO NOTHING;


-- 2. Trigger: cuando se inserta un día en dias_campamento,
--    se crea automáticamente la fila correspondiente en dias_evaluacion.
CREATE OR REPLACE FUNCTION public.sync_dia_evaluacion()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.dias_evaluacion (campamento_id, momento)
  VALUES (NEW.campamento_id, NEW.codigo)
  ON CONFLICT (campamento_id, momento) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_sync_dia_evaluacion ON public.dias_campamento;

CREATE TRIGGER tr_sync_dia_evaluacion
  AFTER INSERT ON public.dias_campamento
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_dia_evaluacion();


-- 3. Trigger: cuando se elimina un día en dias_campamento,
--    se elimina también en dias_evaluacion (solo si no está publicado ni cerrado).
CREATE OR REPLACE FUNCTION public.sync_dia_evaluacion_delete()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.dias_evaluacion
  WHERE campamento_id = OLD.campamento_id
    AND momento       = OLD.codigo
    AND publicado     = false
    AND cerrado       = false;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS tr_sync_dia_evaluacion_delete ON public.dias_campamento;

CREATE TRIGGER tr_sync_dia_evaluacion_delete
  AFTER DELETE ON public.dias_campamento
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_dia_evaluacion_delete();
