import { createClient } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type { Tables, TablesUpdate } from '@/types/database'

export type Perfil = Tables<'perfiles'>

export interface CrearUsuarioPayload {
  nombre_completo: string
  email:           string
  password:        string
  rol:             'admin' | 'evaluador'
}

export const perfilesService = {
  async getMiPerfil(): Promise<Perfil | null> {
    // Usar getUser() para obtener el ID verificado desde el servidor,
    // y filtrar explícitamente por id para no depender sólo de RLS.
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return null
    const { data, error } = await supabase
      .from('perfiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async getTodos(): Promise<Perfil[]> {
    const { data, error } = await supabase
      .from('perfiles')
      .select('*')
      .order('nombre_completo')
    if (error) throw error
    return data ?? []
  },

  async actualizar(id: string, cambios: TablesUpdate<'perfiles'>): Promise<Perfil> {
    const { data, error } = await supabase
      .from('perfiles')
      .update(cambios)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  /**
   * Crea un usuario usando un cliente temporal (sin sesión) para no
   * desloguear al admin. El trigger tr_crear_perfil crea el perfil
   * automáticamente con rol='evaluador'; si eligió 'admin' lo actualizamos.
   */
  async crearUsuario(payload: CrearUsuarioPayload): Promise<void> {
    // Cliente temporal: sin persistencia de sesión → no afecta al admin
    const tempClient = createClient(
      import.meta.env.VITE_SUPABASE_URL as string,
      import.meta.env.VITE_SUPABASE_ANON_KEY as string,
      { auth: { persistSession: false, autoRefreshToken: false } }
    )

    const { data, error } = await tempClient.auth.signUp({
      email:    payload.email,
      password: payload.password,
      options:  { data: { nombre_completo: payload.nombre_completo } },
    })

    if (error) throw new Error(error.message)
    if (!data.user) throw new Error('No se pudo crear el usuario')

    // Si el rol elegido es admin, actualizamos (el trigger inserta 'evaluador' por defecto)
    if (payload.rol === 'admin') {
      const { error: rolError } = await supabase
        .from('perfiles')
        .update({ rol: 'admin' })
        .eq('id', data.user.id)
      if (rolError) throw new Error('Usuario creado pero no se pudo asignar rol admin: ' + rolError.message)
    }
  },

  /**
   * Envía un email de recuperación de contraseña al usuario.
   * El usuario recibe un link para establecer su nueva contraseña.
   */
  async enviarResetPassword(email: string): Promise<void> {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/login`,
    })
    if (error) throw new Error(error.message)
  },
}
