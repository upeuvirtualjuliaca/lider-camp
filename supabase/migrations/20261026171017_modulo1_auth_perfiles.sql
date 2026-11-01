-- =================================================================
-- Módulo 1: Base y autenticación
-- Tablas:    perfiles, auditoria
-- Funciones: set_updated_at, es_admin, obtener_rol,
--            proteger_campos_perfil, crear_perfil_nuevo_usuario,
--            registrar_auditoria
-- =================================================================


-- -----------------------------------------------------------------
-- 1. FUNCIÓN set_updated_at — reutilizable en todos los módulos
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


-- -----------------------------------------------------------------
-- 2. TABLA perfiles
-- -----------------------------------------------------------------
CREATE TABLE public.perfiles (
  id              uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre_completo text        NOT NULL,
  email           text        NOT NULL,
  rol             text        NOT NULL DEFAULT 'evaluador'
                              CHECK (rol IN ('admin', 'evaluador')),
  activo          boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tr_perfiles_updated_at
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------
-- 3. FUNCIÓN es_admin — SECURITY DEFINER evita recursión en RLS
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.es_admin()
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  STABLE
  SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE id     = auth.uid()
      AND rol    = 'admin'
      AND activo = true
  );
END;
$$;


-- -----------------------------------------------------------------
-- 4. FUNCIÓN obtener_rol — devuelve NULL si inactivo o sin sesión
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.obtener_rol()
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  STABLE
  SET search_path = ''
AS $$
DECLARE
  v_rol text;
BEGIN
  SELECT rol INTO v_rol
  FROM public.perfiles
  WHERE id     = auth.uid()
    AND activo = true;
  RETURN v_rol;
END;
$$;


-- -----------------------------------------------------------------
-- 5. FUNCIÓN proteger_campos_perfil
--    Un no-admin solo puede editar nombre_completo.
--    Se permite todo cuando auth.uid() IS NULL
--    (dashboard / SQL Editor / service_role).
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proteger_campos_perfil()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
BEGIN
  -- Sin sesión JWT: dashboard, SQL Editor, service_role → permitir todo
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Admin: puede cambiar cualquier campo
  IF public.es_admin() THEN
    RETURN NEW;
  END IF;

  -- No-admin: bloquear cambios en rol, activo y email
  IF NEW.rol IS DISTINCT FROM OLD.rol THEN
    RAISE EXCEPTION 'No tienes permiso para cambiar el rol.';
  END IF;

  IF NEW.activo IS DISTINCT FROM OLD.activo THEN
    RAISE EXCEPTION 'No tienes permiso para cambiar el estado activo.';
  END IF;

  IF NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'No tienes permiso para cambiar el email.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_perfiles_proteger_campos
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.proteger_campos_perfil();


-- -----------------------------------------------------------------
-- 6. FUNCIÓN crear_perfil_nuevo_usuario
--    Se dispara al crear un usuario en auth.users.
--    Toma nombre_completo de raw_user_meta_data o usa el email.
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_perfil_nuevo_usuario()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.perfiles (id, nombre_completo, email, rol)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'nombre_completo'), ''),
      NEW.email
    ),
    NEW.email,
    'evaluador'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_crear_perfil
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.crear_perfil_nuevo_usuario();


-- -----------------------------------------------------------------
-- 7. TABLA auditoria
-- -----------------------------------------------------------------
CREATE TABLE public.auditoria (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tabla            text        NOT NULL,
  registro_id      uuid        NOT NULL,
  accion           text        NOT NULL CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE')),
  datos_anteriores jsonb,
  datos_nuevos     jsonb,
  usuario_id       uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_auditoria_tabla_registro ON public.auditoria (tabla, registro_id);
CREATE INDEX idx_auditoria_created_at     ON public.auditoria (created_at);


-- -----------------------------------------------------------------
-- 8. FUNCIÓN registrar_auditoria — reutilizable en todos los módulos
-- -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_auditoria()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
DECLARE
  v_registro_id uuid;
  v_anteriores  jsonb;
  v_nuevos      jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_registro_id := NEW.id;
    v_anteriores  := NULL;
    v_nuevos      := to_jsonb(NEW);
  ELSIF TG_OP = 'UPDATE' THEN
    v_registro_id := NEW.id;
    v_anteriores  := to_jsonb(OLD);
    v_nuevos      := to_jsonb(NEW);
  ELSIF TG_OP = 'DELETE' THEN
    v_registro_id := OLD.id;
    v_anteriores  := to_jsonb(OLD);
    v_nuevos      := NULL;
  END IF;

  INSERT INTO public.auditoria (
    tabla, registro_id, accion, datos_anteriores, datos_nuevos, usuario_id
  ) VALUES (
    TG_TABLE_NAME,
    v_registro_id,
    TG_OP,
    v_anteriores,
    v_nuevos,
    auth.uid()
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tr_perfiles_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();


-- -----------------------------------------------------------------
-- 9. POLÍTICAS RLS — perfiles
-- -----------------------------------------------------------------

-- Usuario ve su propio perfil (solo si activo)
CREATE POLICY perfiles_select_propio ON public.perfiles
  FOR SELECT
  USING (auth.uid() = id AND activo = true);

-- Admin ve todos los perfiles
CREATE POLICY perfiles_select_admin ON public.perfiles
  FOR SELECT
  USING (public.es_admin());

-- Usuario edita su propio perfil (solo si activo; trigger protege campos)
CREATE POLICY perfiles_update_propio ON public.perfiles
  FOR UPDATE
  USING (auth.uid() = id AND activo = true);

-- Admin edita cualquier perfil
CREATE POLICY perfiles_update_admin ON public.perfiles
  FOR UPDATE
  USING (public.es_admin());


-- -----------------------------------------------------------------
-- 10. POLÍTICAS RLS — auditoria
-- -----------------------------------------------------------------

-- Solo admin puede leer auditoría
CREATE POLICY auditoria_select_admin ON public.auditoria
  FOR SELECT
  USING (public.es_admin());


-- -----------------------------------------------------------------
-- 11. SEGURIDAD: revocar todo acceso a anon en ambas tablas
-- -----------------------------------------------------------------
REVOKE ALL ON public.perfiles  FROM anon;
REVOKE ALL ON public.auditoria FROM anon;
