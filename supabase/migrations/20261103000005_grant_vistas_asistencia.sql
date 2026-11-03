-- Agrega permisos de lectura a las vistas de asistencia para el rol authenticated.
-- Sin estos grants las queries desde el cliente Supabase fallan silenciosamente.

GRANT SELECT ON public.v_asistencia_equipo_actividad TO authenticated;
GRANT SELECT ON public.v_asistencia_equipo_dia        TO authenticated;
