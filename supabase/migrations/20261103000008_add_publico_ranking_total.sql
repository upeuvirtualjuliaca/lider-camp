-- Vista pública del ranking total final.
-- Solo visible cuando el campamento está cerrado (campamento.cerrado = true).
-- Incluye todos los componentes: rúbrica, actividades, bonus y deméritos.

CREATE OR REPLACE VIEW public.publico_ranking_total
WITH (security_invoker = false)
AS
SELECT pe.*
FROM public.v_puntaje_equipo pe
JOIN public.campamento c ON c.id = pe.campamento_id AND c.cerrado = true;

GRANT SELECT ON public.publico_ranking_total TO anon, authenticated;
