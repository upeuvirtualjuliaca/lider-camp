-- =================================================================
-- Módulo 3: Criterios y programación
-- Tablas:  criterios, programacion
-- Vistas:  v_resumen_programacion, publico_calendario, publico_criterios
-- =================================================================


-- -----------------------------------------------------------------
-- 1. TABLA criterios
-- -----------------------------------------------------------------
CREATE TABLE public.criterios (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo        text    NOT NULL UNIQUE,
  nombre        text    NOT NULL,
  categoria     text    NOT NULL
                        CHECK (categoria IN (
                          'inscripcion',
                          'armado',
                          'orden_cocina',
                          'ceremonias_participacion',
                          'liderazgo'
                        )),
  tipo_calculo  text    NOT NULL
                        CHECK (tipo_calculo IN (
                          'inscripcion',
                          'rubrica',
                          'asistencia',
                          'liderazgo'
                        )),
  abarca        text,
  no_abarca     text,
  evidencia     text,
  orden         int     NOT NULL DEFAULT 0,
  activo        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.criterios ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_criterios_updated_at
  BEFORE UPDATE ON public.criterios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_criterios_auditoria
  AFTER INSERT OR UPDATE ON public.criterios
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 2. TABLA programacion
-- -----------------------------------------------------------------
CREATE TABLE public.programacion (
  id            uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  criterio_id   uuid         NOT NULL REFERENCES public.criterios(id),
  momento       text         NOT NULL
                             CHECK (momento IN ('J', 'V', 'S', 'D', 'UNICO')),
  puntaje_max   numeric(6,2) NOT NULL DEFAULT 100
                             CHECK (puntaje_max > 0),
  estado        text         NOT NULL DEFAULT 'programado'
                             CHECK (estado IN ('programado', 'no_programado', 'cancelado')),
  motivo        text
                             CHECK (estado <> 'cancelado' OR motivo IS NOT NULL),
  created_at    timestamptz  NOT NULL DEFAULT now(),
  updated_at    timestamptz  NOT NULL DEFAULT now(),

  UNIQUE (criterio_id, momento)
);

ALTER TABLE public.programacion ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_programacion_criterio ON public.programacion (criterio_id);

CREATE TRIGGER tr_programacion_updated_at
  BEFORE UPDATE ON public.programacion
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_programacion_auditoria
  AFTER INSERT OR UPDATE ON public.programacion
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 3. VISTA v_resumen_programacion
--    Filas: por (momento, categoria), subtotales y total general.
--    Incluye máximo esperado 5200 y diferencia.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_resumen_programacion AS
SELECT
  p.momento,
  c.categoria,
  COALESCE(
    SUM(p.puntaje_max) FILTER (WHERE p.estado = 'programado'),
    0
  )::numeric(8,2)                        AS maximo_programado,
  5200::numeric(8,2)                     AS maximo_esperado,
  COALESCE(
    SUM(p.puntaje_max) FILTER (WHERE p.estado = 'programado'),
    0
  ) - 5200                               AS diferencia
FROM public.programacion p
JOIN public.criterios     c ON c.id = p.criterio_id
WHERE c.activo = true
GROUP BY GROUPING SETS (
  (p.momento, c.categoria),   -- detalle por día y categoría
  (p.momento),                -- subtotal por día
  (c.categoria),              -- subtotal por categoría
  ()                          -- total general
);


-- -----------------------------------------------------------------
-- 4. VISTA pública publico_calendario (sin motivo interno)
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_calendario AS
SELECT
  c.codigo,
  c.nombre,
  c.categoria,
  c.orden,
  p.momento,
  p.estado
FROM public.programacion p
JOIN public.criterios     c ON c.id = p.criterio_id
WHERE c.activo = true
ORDER BY c.orden, p.momento;

GRANT SELECT ON public.publico_calendario TO anon;


-- -----------------------------------------------------------------
-- 5. VISTA pública publico_criterios
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_criterios AS
SELECT
  codigo,
  nombre,
  categoria,
  tipo_calculo,
  abarca,
  no_abarca,
  evidencia,
  orden
FROM public.criterios
WHERE activo = true
ORDER BY orden;

GRANT SELECT ON public.publico_criterios TO anon;


-- -----------------------------------------------------------------
-- 6. POLÍTICAS RLS — criterios
--    Admin: SELECT + UPDATE (sin DELETE por integridad histórica)
--    Evaluador: solo SELECT
-- -----------------------------------------------------------------
CREATE POLICY criterios_select_auth ON public.criterios
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY criterios_insert_admin ON public.criterios
  FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY criterios_update_admin ON public.criterios
  FOR UPDATE USING (public.es_admin());


-- -----------------------------------------------------------------
-- 7. POLÍTICAS RLS — programacion
--    Admin: SELECT + INSERT + UPDATE (sin DELETE)
--    Evaluador: solo SELECT
-- -----------------------------------------------------------------
CREATE POLICY programacion_select_auth ON public.programacion
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY programacion_insert_admin ON public.programacion
  FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY programacion_update_admin ON public.programacion
  FOR UPDATE USING (public.es_admin());


-- -----------------------------------------------------------------
-- 8. Revocar acceso anon a tablas base
-- -----------------------------------------------------------------
REVOKE ALL ON public.criterios    FROM anon;
REVOKE ALL ON public.programacion FROM anon;
