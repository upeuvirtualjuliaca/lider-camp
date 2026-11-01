-- Permite al admin eliminar criterios y su programación asociada

CREATE POLICY "admin puede eliminar criterios"
  ON public.criterios FOR DELETE
  TO authenticated
  USING (public.es_admin());

CREATE POLICY "admin puede eliminar programacion"
  ON public.programacion FOR DELETE
  TO authenticated
  USING (public.es_admin());
