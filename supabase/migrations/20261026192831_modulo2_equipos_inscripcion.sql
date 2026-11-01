-- =================================================================
-- Módulo 2: Equipos e inscripción
-- Tablas:   campamento, equipos, integrantes
-- Vistas:   v_inscripcion_equipo, publico_equipos
-- =================================================================


-- -----------------------------------------------------------------
-- 1. TABLA campamento (fila única de configuración)
-- -----------------------------------------------------------------
CREATE TABLE public.campamento (
  id                                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  solo_fila                         boolean NOT NULL DEFAULT true UNIQUE
                                            CHECK (solo_fila = true),
  nombre                            text    NOT NULL,
  edicion                           text    NOT NULL,
  fecha_jueves                      date    NOT NULL,
  fecha_viernes                     date    NOT NULL,
  fecha_sabado                      date    NOT NULL,
  fecha_domingo                     date    NOT NULL,
  fecha_limite_inscripcion_completa date    NOT NULL DEFAULT '2026-10-19',
  fecha_limite_inscripcion_parcial  date    NOT NULL DEFAULT '2026-10-21',
  created_at                        timestamptz NOT NULL DEFAULT now(),
  updated_at                        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.campamento ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_campamento_updated_at
  BEFORE UPDATE ON public.campamento
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_campamento_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.campamento
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 2. TABLA equipos
-- -----------------------------------------------------------------
CREATE TABLE public.equipos (
  id                   uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre               text    NOT NULL UNIQUE,
  escuela_profesional  text    NOT NULL,
  color                text    NOT NULL DEFAULT '#3B82F6'
                               CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
  activo               boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.equipos ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_equipos_updated_at
  BEFORE UPDATE ON public.equipos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_equipos_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.equipos
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 3. TABLA integrantes
-- -----------------------------------------------------------------
CREATE TABLE public.integrantes (
  id                    uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  equipo_id             uuid    NOT NULL REFERENCES public.equipos(id) ON DELETE CASCADE,
  nombres               text    NOT NULL,
  apellidos             text    NOT NULL,
  codigo_universitario  text    UNIQUE,
  dni                   text,
  fecha_inscripcion     date    NOT NULL,
  elegible              boolean NOT NULL DEFAULT true,
  activo                boolean NOT NULL DEFAULT true,
  observaciones         text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.integrantes ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_integrantes_equipo ON public.integrantes (equipo_id);

CREATE TRIGGER tr_integrantes_updated_at
  BEFORE UPDATE ON public.integrantes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_integrantes_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.integrantes
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 4. VISTA v_inscripcion_equipo
--    Fórmula: LEAST(100, ROUND((completos×100 + parciales×50) / nomina, 2))
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_inscripcion_equipo AS
SELECT
  e.id                                                          AS equipo_id,
  e.nombre                                                      AS equipo_nombre,
  e.color                                                       AS equipo_color,
  COUNT(i.id) FILTER (WHERE i.activo)                          AS nomina,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_completa
  )                                                             AS inscritos_completos,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_completa
      AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_parcial
  )                                                             AS inscritos_parciales,
  COUNT(i.id) FILTER (
    WHERE i.activo
      AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_parcial
  )                                                             AS inscritos_tardios,
  CASE
    WHEN COUNT(i.id) FILTER (WHERE i.activo) = 0 THEN 0.00
    ELSE LEAST(
      100.00,
      ROUND(
        (
          COUNT(i.id) FILTER (
            WHERE i.activo
              AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_completa
          ) * 100.0
          +
          COUNT(i.id) FILTER (
            WHERE i.activo
              AND i.fecha_inscripcion >  c.fecha_limite_inscripcion_completa
              AND i.fecha_inscripcion <= c.fecha_limite_inscripcion_parcial
          ) * 50.0
        )
        / NULLIF(COUNT(i.id) FILTER (WHERE i.activo), 0),
        2
      )
    )
  END                                                           AS puntaje_inscripcion
FROM       public.equipos     e
CROSS JOIN public.campamento  c
LEFT  JOIN public.integrantes i ON i.equipo_id = e.id
WHERE e.activo = true
GROUP BY
  e.id,
  e.nombre,
  e.color,
  c.fecha_limite_inscripcion_completa,
  c.fecha_limite_inscripcion_parcial;


-- -----------------------------------------------------------------
-- 5. VISTA pública publico_equipos (accesible para anon)
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_equipos AS
SELECT id, nombre, escuela_profesional, color
FROM   public.equipos
WHERE  activo = true;

GRANT SELECT ON public.publico_equipos TO anon;


-- -----------------------------------------------------------------
-- 6. POLÍTICAS RLS — campamento
-- -----------------------------------------------------------------
CREATE POLICY campamento_select_auth ON public.campamento
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY campamento_insert_admin ON public.campamento
  FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY campamento_update_admin ON public.campamento
  FOR UPDATE USING (public.es_admin());


-- -----------------------------------------------------------------
-- 7. POLÍTICAS RLS — equipos
-- -----------------------------------------------------------------
CREATE POLICY equipos_select_auth ON public.equipos
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY equipos_insert_admin ON public.equipos
  FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY equipos_update_admin ON public.equipos
  FOR UPDATE USING (public.es_admin());


-- -----------------------------------------------------------------
-- 8. POLÍTICAS RLS — integrantes
-- -----------------------------------------------------------------
CREATE POLICY integrantes_select_auth ON public.integrantes
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY integrantes_insert_admin ON public.integrantes
  FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY integrantes_update_admin ON public.integrantes
  FOR UPDATE USING (public.es_admin());


-- -----------------------------------------------------------------
-- 9. Revocar acceso anon a tablas base
-- -----------------------------------------------------------------
REVOKE ALL ON public.campamento  FROM anon;
REVOKE ALL ON public.equipos     FROM anon;
REVOKE ALL ON public.integrantes FROM anon;
