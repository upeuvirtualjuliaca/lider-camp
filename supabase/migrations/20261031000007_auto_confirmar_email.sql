-- Trigger que confirma automáticamente el email al crear un usuario.
-- El admin crea todos los usuarios; no hay registro público,
-- por lo que no se necesita confirmación por correo.
-- Función en public (no en auth) para evitar error de permisos de esquema.

CREATE OR REPLACE FUNCTION public.auto_confirmar_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = NEW.id
    AND email_confirmed_at IS NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_auto_confirmar_email ON auth.users;

CREATE TRIGGER tr_auto_confirmar_email
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirmar_email();
