-- =================================================================
-- Módulo 7: Incidencias — bonus y deméritos
-- Tablas:   incidencia_codigos, incidencias,
--           incidencia_integrantes, incidencia_evidencias
-- Cambios:  integrantes += expulsado/fecha_expulsion/motivo_expulsion
-- Storage:  bucket "evidencias" (privado)
-- Vistas:   v_bonus_equipo, v_demeritos_equipo,
--           v_incidencias_pendientes, publico_incidencias_resumen
-- Ajuste:   v_asistencia_equipo_actividad excluye expulsados
-- =================================================================


-- -----------------------------------------------------------------
-- 1. CATÁLOGO incidencia_codigos
-- -----------------------------------------------------------------
CREATE TABLE public.incidencia_codigos (
  id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo                  text        NOT NULL UNIQUE,
  tipo                    text        NOT NULL CHECK (tipo IN ('bonus','demerito')),
  nombre                  text        NOT NULL,
  puntos                  int         NOT NULL CHECK (puntos > 0),
  tope_equipo             int         NULL,      -- máx. pts del código por equipo (NULL = sin tope)
  max_acciones            int         NULL,      -- máx. acciones validadas por equipo (NULL = sin límite)
  por_persona             boolean     NOT NULL DEFAULT false,  -- true solo D6: puntos × cant_personas
  requiere_equipo_apoyado boolean     NOT NULL DEFAULT false,  -- true solo B2
  requiere_advertencia    boolean     NOT NULL DEFAULT false,  -- true solo D1
  abarca                  text        NULL,
  excluye                 text        NULL,
  activo                  boolean     NOT NULL DEFAULT true,
  orden                   int         NOT NULL DEFAULT 1,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.incidencia_codigos ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_ic_updated_at
  BEFORE UPDATE ON public.incidencia_codigos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_ic_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.incidencia_codigos
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

-- Solo admin gestiona el catálogo; todos lo leen
CREATE POLICY "Admin gestiona incidencia_codigos"
  ON public.incidencia_codigos FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee incidencia_codigos"
  ON public.incidencia_codigos FOR SELECT TO authenticated
  USING (true);


-- -----------------------------------------------------------------
-- 2. TABLA incidencias
-- -----------------------------------------------------------------
CREATE TABLE public.incidencias (
  id                            uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  equipo_id                     uuid         NOT NULL REFERENCES public.equipos(id)   ON DELETE RESTRICT,
  codigo                        text         NOT NULL REFERENCES public.incidencia_codigos(codigo),
  fecha                         date         NOT NULL,
  hora                          time         NOT NULL,
  momento                       text         NULL,       -- calculado por trigger → dias_campamento.codigo
  hecho                         text         NOT NULL,
  alcance                       text         NOT NULL DEFAULT 'equipo'
                                             CHECK (alcance IN ('equipo','individual')),
  justificacion_grupal          text         NULL,       -- obligatorio si alcance='individual' y no D6
  equipo_apoyado_id             uuid         NULL REFERENCES public.equipos(id) ON DELETE RESTRICT,
  confirmado_por_equipo_apoyado boolean      NOT NULL DEFAULT false,
  advertencia_referencia        text         NULL,       -- obligatorio para D1
  valorado_en_otro_item         text         NULL,       -- referencia para evitar doble descuento
  cantidad_personas             int          NOT NULL DEFAULT 1 CHECK (cantidad_personas >= 1),
  puntos                        numeric(8,2) NOT NULL DEFAULT 0,  -- calculado por trigger; no editable
  estado                        text         NOT NULL DEFAULT 'registrado'
                                             CHECK (estado IN ('registrado','descargo','validado','rechazado')),
  descargo_equipo               text         NULL,
  motivo_resolucion             text         NULL,
  registrado_por                uuid         NOT NULL REFERENCES public.perfiles(id),
  validado_por                  uuid         NULL REFERENCES public.perfiles(id),
  validado_at                   timestamptz  NULL,
  created_at                    timestamptz  NOT NULL DEFAULT now(),
  updated_at                    timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------------------
-- 3. TABLA incidencia_integrantes
-- -----------------------------------------------------------------
CREATE TABLE public.incidencia_integrantes (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  incidencia_id  uuid        NOT NULL REFERENCES public.incidencias(id)    ON DELETE CASCADE,
  integrante_id  uuid        NOT NULL REFERENCES public.integrantes(id)    ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (incidencia_id, integrante_id)
);

ALTER TABLE public.incidencia_integrantes ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_ii_auditoria
  AFTER INSERT OR DELETE ON public.incidencia_integrantes
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 4. TABLA incidencia_evidencias
-- -----------------------------------------------------------------
CREATE TABLE public.incidencia_evidencias (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  incidencia_id    uuid        NOT NULL REFERENCES public.incidencias(id) ON DELETE CASCADE,
  ruta_archivo     text        NOT NULL,  -- Storage path: incidencias/{id}/{uuid}.{ext}
  tipo_archivo     text        NOT NULL,  -- MIME: image/*, application/pdf
  nombre_original  text        NULL,
  subido_por       uuid        NOT NULL REFERENCES public.perfiles(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.incidencia_evidencias ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------------------
-- 5. COLUMNAS EXPULSIÓN en integrantes
-- -----------------------------------------------------------------
ALTER TABLE public.integrantes
  ADD COLUMN IF NOT EXISTS expulsado        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS fecha_expulsion  date    NULL,
  ADD COLUMN IF NOT EXISTS motivo_expulsion text    NULL;


-- -----------------------------------------------------------------
-- 6. STORAGE bucket "evidencias" (privado, 10 MB, solo imágenes/PDF)
-- -----------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'evidencias',
  'evidencias',
  false,
  10485760,
  ARRAY['image/jpeg','image/png','image/webp','image/heic','application/pdf']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Autenticado sube evidencias"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'evidencias');

CREATE POLICY "Autenticado ve evidencias"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'evidencias');

CREATE POLICY "Admin borra evidencias"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'evidencias' AND public.es_admin());


-- -----------------------------------------------------------------
-- 7. FUNCIÓN: calcular momento desde dias_campamento
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_set_momento_incidencia()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  SELECT dc.codigo INTO NEW.momento
    FROM public.dias_campamento dc
   WHERE dc.fecha = NEW.fecha
   LIMIT 1;
  -- Si la fecha no coincide con ningún día del campamento, momento queda NULL
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_inc_1momento
  BEFORE INSERT OR UPDATE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_momento_incidencia();


-- -----------------------------------------------------------------
-- 8. FUNCIÓN: calcular puntos (puntos_catalogo × cantidad_personas)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_calcular_puntos_incidencia()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_puntos_base int;
BEGIN
  SELECT puntos INTO v_puntos_base
    FROM public.incidencia_codigos
   WHERE codigo = NEW.codigo;
  NEW.puntos := ROUND(v_puntos_base::numeric * NEW.cantidad_personas, 2);
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_inc_2puntos
  BEFORE INSERT OR UPDATE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.fn_calcular_puntos_incidencia();


-- -----------------------------------------------------------------
-- 9. FUNCIÓN: validar incidencia (SECURITY DEFINER)
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validar_incidencia()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cat         record;
  v_dia_cerrado boolean;
  v_acciones    int;
  v_integrantes int;
BEGIN
  -- En contexto de migración / service_role (sin auth.uid) omitir validación
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Catálogo
  SELECT * INTO v_cat FROM public.incidencia_codigos WHERE codigo = NEW.codigo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Código de incidencia no encontrado: %', NEW.codigo;
  END IF;
  IF NOT v_cat.activo THEN
    RAISE EXCEPTION 'El código % no está activo.', NEW.codigo;
  END IF;

  -- hecho obligatorio
  IF NEW.hecho IS NULL OR trim(NEW.hecho) = '' THEN
    RAISE EXCEPTION 'El campo "hecho" es obligatorio.';
  END IF;

  -- D6 → alcance siempre individual (forzar silenciosamente)
  IF v_cat.por_persona THEN
    NEW.alcance := 'individual';
  END IF;

  -- alcance=individual (no D6) → justificacion_grupal obligatoria
  IF NEW.alcance = 'individual' AND NOT v_cat.por_persona THEN
    IF NEW.justificacion_grupal IS NULL OR trim(NEW.justificacion_grupal) = '' THEN
      RAISE EXCEPTION
        'Se requiere justificación grupal cuando el alcance es individual y el código no es D6.';
    END IF;
  END IF;

  -- B2 → equipo_apoyado_id obligatorio y distinto
  IF v_cat.requiere_equipo_apoyado THEN
    IF NEW.equipo_apoyado_id IS NULL THEN
      RAISE EXCEPTION 'El código % requiere indicar el equipo apoyado.', NEW.codigo;
    END IF;
    IF NEW.equipo_apoyado_id = NEW.equipo_id THEN
      RAISE EXCEPTION 'El equipo apoyado debe ser distinto del equipo que registra el bonus.';
    END IF;
  END IF;

  -- D1 → advertencia_referencia obligatoria
  IF v_cat.requiere_advertencia THEN
    IF NEW.advertencia_referencia IS NULL OR trim(NEW.advertencia_referencia) = '' THEN
      RAISE EXCEPTION 'El código D1 requiere indicar la advertencia previa.';
    END IF;
  END IF;

  -- Día cerrado → solo admin
  IF NEW.momento IS NOT NULL THEN
    SELECT cerrado INTO v_dia_cerrado
      FROM public.dias_evaluacion
     WHERE momento = NEW.momento;
    IF FOUND AND v_dia_cerrado AND NOT public.es_admin() THEN
      RAISE EXCEPTION
        'El día % está cerrado. Solo el administrador puede registrar incidencias.', NEW.momento;
    END IF;
  END IF;

  -- Solo admin puede cambiar a validado/rechazado
  IF NEW.estado IN ('validado','rechazado') AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede validar o rechazar incidencias.';
  END IF;

  -- Incidencia ya validada: solo admin puede modificarla
  IF TG_OP = 'UPDATE' AND OLD.estado = 'validado' AND NOT public.es_admin() THEN
    RAISE EXCEPTION 'Una incidencia validada no puede ser modificada por un evaluador.';
  END IF;

  -- Validaciones adicionales al cambiar a validado
  IF NEW.estado = 'validado'
     AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.estado <> 'validado'))
  THEN
    -- descargo_equipo obligatorio
    IF NEW.descargo_equipo IS NULL OR trim(NEW.descargo_equipo) = '' THEN
      RAISE EXCEPTION
        'Registra el descargo del equipo (o indica "No presentó descargo") antes de validar.';
    END IF;
    -- motivo_resolucion obligatorio
    IF NEW.motivo_resolucion IS NULL OR trim(NEW.motivo_resolucion) = '' THEN
      RAISE EXCEPTION 'El motivo de resolución es obligatorio al validar.';
    END IF;

    -- Verificar max_acciones
    IF v_cat.max_acciones IS NOT NULL THEN
      SELECT COUNT(*)::int INTO v_acciones
        FROM public.incidencias
       WHERE equipo_id = NEW.equipo_id
         AND codigo    = NEW.codigo
         AND estado    = 'validado'
         AND id       <> NEW.id;
      IF v_acciones >= v_cat.max_acciones THEN
        RAISE EXCEPTION
          'El equipo ya alcanzó el máximo de % acción(es) validada(s) para el código %.',
          v_cat.max_acciones, NEW.codigo;
      END IF;
    END IF;

    -- D6: verificar cantidad_personas = COUNT(incidencia_integrantes)
    IF v_cat.por_persona THEN
      SELECT COUNT(*)::int INTO v_integrantes
        FROM public.incidencia_integrantes
       WHERE incidencia_id = NEW.id;
      IF v_integrantes = 0 THEN
        RAISE EXCEPTION 'D6 requiere al menos un integrante registrado.';
      END IF;
      IF v_integrantes <> NEW.cantidad_personas THEN
        RAISE EXCEPTION
          'La cantidad de personas (%) no coincide con los integrantes registrados (%).',
          NEW.cantidad_personas, v_integrantes;
      END IF;
    END IF;

    -- Marcar quién validó
    NEW.validado_por := auth.uid();
    NEW.validado_at  := now();
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_inc_3validar
  BEFORE INSERT OR UPDATE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.fn_validar_incidencia();

CREATE TRIGGER tr_inc_4updated
  BEFORE UPDATE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER tr_inc_5auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 10. FUNCIÓN: expulsar integrantes al validar D6
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_post_validar_incidencia()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_por_persona boolean;
BEGIN
  -- Solo actuar en el primer cambio a validado
  IF NEW.estado <> 'validado' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.estado = 'validado' THEN RETURN NEW; END IF;

  SELECT por_persona INTO v_por_persona
    FROM public.incidencia_codigos
   WHERE codigo = NEW.codigo;

  IF v_por_persona THEN
    UPDATE public.integrantes
       SET expulsado        = true,
           fecha_expulsion  = NEW.fecha,
           motivo_expulsion = 'D6 — ' || NEW.hecho
     WHERE id IN (
       SELECT integrante_id
         FROM public.incidencia_integrantes
        WHERE incidencia_id = NEW.id
     )
       AND expulsado = false;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_inc_6expulsion
  AFTER INSERT OR UPDATE ON public.incidencias
  FOR EACH ROW EXECUTE FUNCTION public.fn_post_validar_incidencia();


-- -----------------------------------------------------------------
-- 11. RLS: incidencias
-- -----------------------------------------------------------------
CREATE POLICY "Admin gestiona incidencias"
  ON public.incidencias FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee incidencias"
  ON public.incidencias FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Evaluador inserta incidencias"
  ON public.incidencias FOR INSERT TO authenticated
  WITH CHECK (NOT public.es_admin() AND estado = 'registrado');

CREATE POLICY "Evaluador actualiza incidencias abiertas"
  ON public.incidencias FOR UPDATE TO authenticated
  USING  (NOT public.es_admin() AND estado IN ('registrado','descargo'))
  WITH CHECK (NOT public.es_admin() AND estado IN ('registrado','descargo'));


-- -----------------------------------------------------------------
-- 12. RLS: incidencia_integrantes
-- -----------------------------------------------------------------
CREATE POLICY "Admin gestiona incidencia_integrantes"
  ON public.incidencia_integrantes FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee incidencia_integrantes"
  ON public.incidencia_integrantes FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Evaluador agrega integrantes a incidencias abiertas"
  ON public.incidencia_integrantes FOR INSERT TO authenticated
  WITH CHECK (
    NOT public.es_admin() AND
    EXISTS (
      SELECT 1 FROM public.incidencias
       WHERE id = incidencia_id
         AND estado IN ('registrado','descargo')
    )
  );


-- -----------------------------------------------------------------
-- 13. RLS: incidencia_evidencias
-- -----------------------------------------------------------------
CREATE POLICY "Admin gestiona incidencia_evidencias"
  ON public.incidencia_evidencias FOR ALL TO authenticated
  USING  (public.es_admin())
  WITH CHECK (public.es_admin());

CREATE POLICY "Evaluador lee incidencia_evidencias"
  ON public.incidencia_evidencias FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Evaluador sube evidencias a incidencias abiertas"
  ON public.incidencia_evidencias FOR INSERT TO authenticated
  WITH CHECK (
    NOT public.es_admin() AND
    EXISTS (
      SELECT 1 FROM public.incidencias
       WHERE id = incidencia_id
         AND estado IN ('registrado','descargo')
    )
  );


-- -----------------------------------------------------------------
-- 14. VISTA v_bonus_equipo
--     Bonus validados por código (cap tope_equipo) y total (cap 200)
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_bonus_equipo AS
WITH por_codigo AS (
  SELECT
    i.equipo_id,
    e.nombre                                                            AS equipo_nombre,
    e.color                                                             AS equipo_color,
    ic.codigo,
    ic.nombre                                                           AS codigo_nombre,
    ic.puntos                                                           AS puntos_por_accion,
    COUNT(*)::int                                                       AS acciones_validadas,
    LEAST(
      SUM(i.puntos),
      COALESCE(ic.tope_equipo, SUM(i.puntos))
    )                                                                   AS bonus_codigo
  FROM public.incidencias      i
  JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo
  JOIN public.equipos            e  ON e.id      = i.equipo_id
  WHERE i.estado = 'validado' AND ic.tipo = 'bonus'
  GROUP BY i.equipo_id, e.nombre, e.color, ic.codigo, ic.nombre, ic.puntos, ic.tope_equipo
),
totales AS (
  SELECT equipo_id,
         LEAST(SUM(bonus_codigo), 200) AS bonus_total
  FROM por_codigo
  GROUP BY equipo_id
)
SELECT
  pc.equipo_id,
  pc.equipo_nombre,
  pc.equipo_color,
  pc.codigo,
  pc.codigo_nombre,
  pc.puntos_por_accion,
  pc.acciones_validadas,
  pc.bonus_codigo,
  t.bonus_total
FROM por_codigo pc
JOIN totales    t ON t.equipo_id = pc.equipo_id;


-- -----------------------------------------------------------------
-- 15. VISTA v_demeritos_equipo
--     Deméritos validados por código y total por equipo
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_demeritos_equipo AS
SELECT
  i.equipo_id,
  e.nombre                                                              AS equipo_nombre,
  e.color                                                               AS equipo_color,
  ic.codigo,
  ic.nombre                                                             AS codigo_nombre,
  COUNT(*)::int                                                         AS incidencias_validadas,
  SUM(i.puntos)::numeric                                                AS demeritos_codigo,
  SUM(SUM(i.puntos)) OVER (PARTITION BY i.equipo_id)::numeric           AS demeritos_total
FROM public.incidencias      i
JOIN public.incidencia_codigos ic ON ic.codigo = i.codigo
JOIN public.equipos            e  ON e.id      = i.equipo_id
WHERE i.estado = 'validado' AND ic.tipo = 'demerito'
GROUP BY i.equipo_id, e.nombre, e.color, ic.codigo, ic.nombre;


-- -----------------------------------------------------------------
-- 16. VISTA v_incidencias_pendientes (bandeja admin)
--     Incidencias en registrado o descargo, ordenadas por antigüedad
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_incidencias_pendientes AS
SELECT
  i.id,
  i.equipo_id,
  e.nombre                        AS equipo_nombre,
  e.color                         AS equipo_color,
  i.codigo,
  ic.tipo,
  ic.nombre                       AS codigo_nombre,
  i.fecha,
  i.hora,
  i.momento,
  i.hecho,
  i.alcance,
  i.puntos,
  i.estado,
  i.descargo_equipo,
  i.registrado_por,
  p.nombre_completo               AS registrado_por_nombre,
  i.created_at
FROM public.incidencias       i
JOIN public.equipos            e  ON e.id       = i.equipo_id
JOIN public.incidencia_codigos ic ON ic.codigo  = i.codigo
JOIN public.perfiles           p  ON p.id       = i.registrado_por
WHERE i.estado IN ('registrado','descargo');


-- -----------------------------------------------------------------
-- 17. VISTA pública publico_incidencias_resumen (anon)
--     Solo incidencias validadas en días publicados.
--     Sin hecho, evidencias, nombres ni evaluadores.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.publico_incidencias_resumen AS
SELECT
  e.id     AS equipo_id,
  e.nombre AS equipo_nombre,
  e.color  AS equipo_color,
  i.codigo,
  ic.tipo,
  i.puntos,
  i.fecha,
  i.momento
FROM public.incidencias        i
JOIN public.equipos            e  ON e.id       = i.equipo_id
JOIN public.incidencia_codigos ic ON ic.codigo  = i.codigo
LEFT JOIN public.dias_evaluacion de ON de.momento = i.momento
WHERE i.estado = 'validado'
  AND (i.momento IS NULL OR de.publicado = true);

GRANT SELECT ON public.publico_incidencias_resumen TO anon;


-- -----------------------------------------------------------------
-- 18. AJUSTE v_asistencia_equipo_actividad (módulo 5)
--     Excluye integrantes expulsados en actividades de días
--     posteriores a su fecha de expulsión.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_asistencia_equipo_actividad AS
SELECT
  e.id                                                          AS equipo_id,
  e.nombre                                                      AS equipo_nombre,
  a.id                                                          AS actividad_id,
  a.nombre                                                      AS actividad_nombre,
  a.estado                                                      AS actividad_estado,
  p.criterio_id,
  p.momento,
  COUNT(DISTINCT i.id)                                          AS elegibles,
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'justificado' AND ar.documentado = true
    THEN ar.integrante_id END)                                  AS justificados,
  COUNT(DISTINCT i.id)
    - COUNT(DISTINCT CASE
        WHEN ar.estado = 'justificado' AND ar.documentado = true
        THEN ar.integrante_id END)                              AS convocados_elegibles,
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'presente' THEN ar.integrante_id END)      AS presentes,
  COUNT(DISTINCT CASE
    WHEN ar.estado = 'ausente' THEN ar.integrante_id END)       AS ausentes,
  COUNT(DISTINCT i.id) - COUNT(DISTINCT ar.integrante_id)       AS sin_registro,
  CASE
    WHEN (COUNT(DISTINCT i.id)
          - COUNT(DISTINCT CASE
              WHEN ar.estado = 'justificado' AND ar.documentado = true
              THEN ar.integrante_id END)) = 0
    THEN NULL
    ELSE ROUND(
      LEAST(
        100::numeric,
        COUNT(DISTINCT CASE WHEN ar.estado = 'presente' THEN ar.integrante_id END)::numeric
        / (COUNT(DISTINCT i.id)
           - COUNT(DISTINCT CASE
               WHEN ar.estado = 'justificado' AND ar.documentado = true
               THEN ar.integrante_id END))::numeric
        / 0.95
        * 100
      ), 2
    )
  END                                                           AS puntaje,
  (a.estado <> 'realizada')                                    AS provisional
FROM public.actividades a
JOIN public.programacion p  ON p.id  = a.programacion_id
JOIN public.criterios    c  ON c.id  = p.criterio_id
CROSS JOIN public.equipos e
JOIN public.integrantes i
  ON  i.equipo_id = e.id
  AND i.activo    = true
  AND i.elegible  = true
  AND (
    -- Excluir si expulsado Y la actividad ocurre en un día >= fecha_expulsion
    i.expulsado = false
    OR i.fecha_expulsion IS NULL
    OR (
      SELECT dc.fecha
        FROM public.dias_campamento dc
       WHERE dc.codigo = p.momento
       LIMIT 1
    ) < i.fecha_expulsion
  )
LEFT JOIN public.asistencia_registros ar
  ON  ar.actividad_id   = a.id
  AND ar.integrante_id  = i.id
WHERE a.estado <> 'cancelada'
  AND e.activo = true
GROUP BY e.id, e.nombre, a.id, a.nombre, a.estado, p.criterio_id, p.momento;


-- -----------------------------------------------------------------
-- 19. SEED: catálogo completo B1, B2, D1–D6
-- -----------------------------------------------------------------
INSERT INTO public.incidencia_codigos
  (codigo, tipo, nombre, puntos, tope_equipo, max_acciones, por_persona,
   requiere_equipo_apoyado, requiere_advertencia, abarca, excluye, activo, orden)
VALUES
  ('B1', 'bonus', 'Servicio extraordinario',
   25, 50, 2, false, false, false,
   'Acción concreta y visible de servicio que va más allá de lo esperado y que beneficia al campamento o a otros equipos.',
   'Cumplimiento normal de las actividades asignadas al equipo.',
   true, 1),
  ('B2', 'bonus', 'Cooperación entre equipos',
   25, 50, 2, false, true, false,
   'El equipo ayuda activamente a resolver un problema o necesidad concreta de otro equipo, a pedido o de forma espontánea.',
   'Ayuda informal o conversacional; acciones que forman parte de la programación.',
   true, 2),
  ('D1', 'demerito', 'Ruido tras advertencia',
   10, NULL, NULL, false, false, true,
   'El equipo continúa con ruido excesivo después de recibir una advertencia explícita del personal.',
   'Primer aviso sin reincidencia; ruido en horario permitido.',
   true, 3),
  ('D2', 'demerito', 'Uso de recursos de otro equipo',
   20, NULL, NULL, false, false, false,
   'Tomar o usar materiales, utensilios o espacio pertenecientes a otro equipo sin autorización.',
   'Préstamo acordado entre equipos con consentimiento; uso de espacios comunes.',
   true, 4),
  ('D3', 'demerito', 'Burla, insulto o exclusión',
   30, NULL, NULL, false, false, false,
   'Conducta verbal o gestual que afecta la dignidad, integración o bienestar de cualquier persona del campamento.',
   'Broma acordada y bien recibida por todas las partes involucradas.',
   true, 5),
  ('D4', 'demerito', 'Incumplimiento de instrucción de seguridad',
   50, NULL, NULL, false, false, false,
   'Ignorar o desobedecer una instrucción de seguridad emitida por el personal del campamento.',
   'Desconocimiento demostrado de la instrucción; situación de emergencia documentada.',
   true, 6),
  ('D5', 'demerito', 'Alteración de evidencias o puntajes',
   100, NULL, NULL, false, false, false,
   'Modificar, falsificar o destruir registros, fotografías u otro material de evaluación.',
   NULL,
   true, 7),
  ('D6', 'demerito', 'Bebidas prohibidas',
   500, NULL, NULL, true, false, false,
   'Consumo o posesión de alcohol u otras sustancias prohibidas por el reglamento del campamento. 500 pts por persona involucrada.',
   NULL,
   true, 8)
ON CONFLICT (codigo) DO NOTHING;


-- -----------------------------------------------------------------
-- 20. SEED: incidencias de prueba (5 casos en distintos estados)
--     Usa bypass por auth.uid() IS NULL en el trigger de validación.
-- -----------------------------------------------------------------
DO $$
DECLARE
  v_alfa   uuid;  v_beta uuid;  v_gamma uuid;
  v_admin  uuid;  v_eval  uuid;
  v_int1   uuid;  v_int2  uuid;
  v_fecha1 date;  v_fecha2 date;
  v_inc_d6 uuid;
BEGIN
  SELECT id INTO v_alfa  FROM public.equipos WHERE nombre = 'Alfa'  LIMIT 1;
  SELECT id INTO v_beta  FROM public.equipos WHERE nombre = 'Beta'  LIMIT 1;
  SELECT id INTO v_gamma FROM public.equipos WHERE nombre = 'Gamma' LIMIT 1;
  SELECT id INTO v_admin FROM public.perfiles WHERE rol = 'admin'     LIMIT 1;
  SELECT id INTO v_eval  FROM public.perfiles WHERE rol = 'evaluador' LIMIT 1;

  -- Usar las dos primeras fechas del campamento
  SELECT fecha INTO v_fecha1 FROM public.dias_campamento ORDER BY orden LIMIT 1;
  SELECT fecha INTO v_fecha2 FROM public.dias_campamento ORDER BY orden LIMIT 1 OFFSET 1;
  IF v_fecha2 IS NULL THEN v_fecha2 := v_fecha1; END IF;

  -- Integrantes del equipo Alfa para D6
  SELECT id INTO v_int1 FROM public.integrantes
   WHERE equipo_id = v_alfa AND activo = true LIMIT 1;
  SELECT id INTO v_int2 FROM public.integrantes
   WHERE equipo_id = v_alfa AND activo = true AND id <> v_int1 LIMIT 1;

  IF v_admin IS NULL OR v_fecha1 IS NULL THEN
    RAISE NOTICE 'Seed incidencias omitido: falta admin o días del campamento.';
    RETURN;
  END IF;

  -- B1 validado — Alfa, día 1
  IF v_alfa IS NOT NULL THEN
    INSERT INTO public.incidencias
      (equipo_id, codigo, fecha, hora, hecho, alcance, cantidad_personas,
       estado, descargo_equipo, motivo_resolucion, registrado_por, validado_por, validado_at)
    VALUES
      (v_alfa, 'B1', v_fecha1, '08:30',
       'El equipo Alfa organizó voluntariamente el área de desayuno antes de que se les pidiera.',
       'equipo', 1, 'validado',
       'El equipo confirmó la acción. No había nada que descargarse.',
       'Acción verificada por dos evaluadores. Cumple criterio de servicio extraordinario.',
       COALESCE(v_eval, v_admin), v_admin, now())
    ON CONFLICT DO NOTHING;
  END IF;

  -- B2 en descargo — Beta apoyó a Alfa, día 1
  IF v_beta IS NOT NULL AND v_alfa IS NOT NULL THEN
    INSERT INTO public.incidencias
      (equipo_id, codigo, fecha, hora, hecho, alcance,
       equipo_apoyado_id, cantidad_personas, estado, descargo_equipo, registrado_por)
    VALUES
      (v_beta, 'B2', v_fecha1, '10:15',
       'El equipo Beta ayudó al equipo Alfa a reparar su carpa dañada por la lluvia.',
       'equipo', v_alfa, 1, 'descargo',
       'Alfa confirma que Beta los ayudó de forma espontánea.',
       COALESCE(v_eval, v_admin))
    ON CONFLICT DO NOTHING;
  END IF;

  -- D1 validado — Gamma, día 1
  IF v_gamma IS NOT NULL THEN
    INSERT INTO public.incidencias
      (equipo_id, codigo, fecha, hora, hecho, alcance,
       advertencia_referencia, cantidad_personas,
       estado, descargo_equipo, motivo_resolucion, registrado_por, validado_por, validado_at)
    VALUES
      (v_gamma, 'D1', v_fecha1, '23:05',
       'El equipo Gamma continuó con ruido alto 20 minutos después de la advertencia.',
       'equipo',
       'Advertencia verbal a las 22:45 por el evaluador de turno.',
       1, 'validado',
       'El equipo reconoce la advertencia pero argumenta que intentaron bajar el volumen.',
       'Segunda verificación confirmó el ruido. Conducta claramente posterior a la advertencia.',
       COALESCE(v_eval, v_admin), v_admin, now())
    ON CONFLICT DO NOTHING;
  END IF;

  -- D3 rechazado — Beta, día 2
  IF v_beta IS NOT NULL THEN
    INSERT INTO public.incidencias
      (equipo_id, codigo, fecha, hora, hecho, alcance,
       justificacion_grupal, cantidad_personas,
       estado, descargo_equipo, motivo_resolucion, registrado_por, validado_por, validado_at)
    VALUES
      (v_beta, 'D3', v_fecha2, '14:20',
       'Un integrante de Beta realizó comentarios despectivos hacia otro campista.',
       'individual',
       'Se atribuye al equipo porque el comportamiento ocurrió durante una actividad grupal.',
       1, 'rechazado',
       'El equipo presentó testimonios indicando que fue una broma interna acordada.',
       'Se escucharon ambas partes. Testimonios consistentes: broma acordada. Corresponde al ítem excluye del D3.',
       COALESCE(v_eval, v_admin), v_admin, now())
    ON CONFLICT DO NOTHING;
  END IF;

  -- D6 validado — Alfa, 2 personas, 1000 pts, día 2
  -- Insertar primero como 'registrado', luego integrantes, luego validar
  IF v_alfa IS NOT NULL AND v_int1 IS NOT NULL AND v_int2 IS NOT NULL THEN
    INSERT INTO public.incidencias
      (equipo_id, codigo, fecha, hora, hecho, alcance,
       justificacion_grupal, cantidad_personas,
       estado, registrado_por)
    VALUES
      (v_alfa, 'D6', v_fecha2, '23:50',
       'Se encontraron dos integrantes del equipo Alfa con bebidas alcohólicas en la carpa.',
       'individual',
       'El equipo no justificó la presencia de alcohol. Responsabilidad de los individuos involucrados.',
       2, 'registrado',
       COALESCE(v_eval, v_admin))
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_inc_d6;

    IF v_inc_d6 IS NOT NULL THEN
      INSERT INTO public.incidencia_integrantes (incidencia_id, integrante_id)
      VALUES (v_inc_d6, v_int1), (v_inc_d6, v_int2)
      ON CONFLICT DO NOTHING;

      -- Ahora validar: el trigger fn_validar_incidencia omitirá validaciones
      -- porque auth.uid() es NULL en este contexto de migración.
      UPDATE public.incidencias
         SET estado           = 'validado',
             descargo_equipo  = 'El equipo no tuvo nada que descargarse respecto a la conducta individual.',
             motivo_resolucion = 'Evidencia fotográfica y dos testigos. Corresponde D6 por persona. Expulsión inmediata.',
             validado_por     = v_admin,
             validado_at      = now()
       WHERE id = v_inc_d6;
      -- La función fn_post_validar_incidencia (AFTER trigger) marcará a los integrantes
      -- como expulsados automáticamente.
    END IF;
  END IF;
END $$;
