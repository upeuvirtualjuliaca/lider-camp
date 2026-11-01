import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { perfilesService, type Perfil } from './services/perfiles.service'

export const useSessionStore = defineStore('session', () => {
  const user = ref<User | null>(null)
  const perfil = ref<Perfil | null>(null)
  const cargando = ref(true)

  const rol = computed(() => perfil.value?.rol ?? null)
  const esAdmin = computed(() => rol.value === 'admin')
  const estaActivo = computed(() => perfil.value?.activo === true)

  // Promise que se resuelve una sola vez cuando inicializar() termina.
  // El guard de rutas la awaita para no redirigir antes de conocer la sesión.
  let _resolveIniciado!: () => void
  const _iniciado = new Promise<void>((resolve) => {
    _resolveIniciado = resolve
  })
  function esperarInicializacion() {
    return _iniciado
  }

  async function cargarPerfil() {
    if (!user.value) {
      perfil.value = null
      return
    }
    try {
      perfil.value = await perfilesService.getMiPerfil()
    } catch {
      perfil.value = null
    }
  }

  let listenerRegistrado = false

  async function inicializar() {
    cargando.value = true
    const { data } = await supabase.auth.getSession()
    user.value = data.session?.user ?? null
    await cargarPerfil()
    cargando.value = false
    _resolveIniciado()   // ← desbloquea el guard de rutas

    if (!listenerRegistrado) {
      listenerRegistrado = true
      supabase.auth.onAuthStateChange(async (_event, session) => {
        user.value = session?.user ?? null
        await cargarPerfil()
      })
    }
  }

  async function login(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    user.value = data.user
    await cargarPerfil()

    if (!perfil.value) {
      // El perfil no existe en la tabla (cuenta sin perfil en la BD)
      await supabase.auth.signOut()
      user.value = null
      throw new Error('No se encontró un perfil para esta cuenta. Contacta al administrador.')
    }

    if (!perfil.value.activo) {
      // El perfil existe pero está desactivado
      await supabase.auth.signOut()
      user.value = null
      perfil.value = null
      throw new Error('Tu cuenta está desactivada. Contacta al administrador.')
    }
  }

  async function logout() {
    await supabase.auth.signOut()
    user.value = null
    perfil.value = null
  }

  return { user, perfil, cargando, rol, esAdmin, estaActivo, inicializar, esperarInicializacion, login, logout }
})
