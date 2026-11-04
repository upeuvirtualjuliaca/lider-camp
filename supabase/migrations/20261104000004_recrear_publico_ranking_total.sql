-- Recrea publico_ranking_total eliminada por CASCADE en 20261104000001.

DROP VIEW IF EXISTS public.publico_ranking_total;

CREATE VIEW public.publico_ranking_total
WITH (security_invoker = false)
AS
SELECT pe.*
FROM public.v_puntaje_equipo pe
JOIN public.campamento c ON c.id = pe.campamento_id AND c.cerrado = true;

GRANT SELECT ON public.publico_ranking_total TO anon, authenticated;
