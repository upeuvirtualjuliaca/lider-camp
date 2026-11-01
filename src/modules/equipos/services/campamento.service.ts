import { supabase } from '@/lib/supabase'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

export type Campamento    = Tables<'campamento'>
export type DiaCampamento = Tables<'dias_campamento'>

// ── Campamento ─────────────────────────────────────────────────────────────────

export const campamentoService = {
  /** Retorna el campamento activo (legacy — preferir store.campamento). */
  async get(): Promise<Campamento | null> {
    const { data, error } = await supabase
      .from('campamento')
      .select('*')
      .eq('activo', true)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async getById(id: string): Promise<Campamento | null> {
    const { data, error } = await supabase
      .from('campamento')
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    return data
  },

  /** Lista todos los campamentos, activo primero. */
  async getAll(): Promise<Campamento[]> {
    const { data, error } = await supabase
      .from('campamento')
      .select('*')
      .order('activo', { ascending: false })
      .order('created_at', { ascending: false })
    if (error) throw error
    return data ?? []
  },

  async crear(datos: TablesInsert<'campamento'>): Promise<Campamento> {
    const { data, error } = await supabase
      .from('campamento')
      .insert({ ...datos, activo: false })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'campamento'>): Promise<Campamento> {
    const { data, error } = await supabase
      .from('campamento')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(id: string): Promise<void> {
    const { error } = await supabase.from('campamento').delete().eq('id', id)
    if (error) throw error
  },

  async setActivo(id: string): Promise<void> {
    const { error } = await supabase.rpc('activar_campamento', { p_id: id })
    if (error) throw error
  },

  async setInactivo(id: string): Promise<void> {
    const { error } = await supabase.rpc('desactivar_campamento', { p_id: id })
    if (error) throw error
  },
}

// ── Días del campamento ────────────────────────────────────────────────────────

export const diasCampamentoService = {
  async getPorCampamento(campamentoId: string): Promise<DiaCampamento[]> {
    const { data, error } = await supabase
      .from('dias_campamento')
      .select('*')
      .eq('campamento_id', campamentoId)
      .order('orden')
    if (error) throw error
    return data ?? []
  },

  async crear(datos: TablesInsert<'dias_campamento'>): Promise<DiaCampamento> {
    const { data, error } = await supabase
      .from('dias_campamento')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'dias_campamento'>): Promise<DiaCampamento> {
    const { data, error } = await supabase
      .from('dias_campamento')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(id: string): Promise<void> {
    const { error } = await supabase.from('dias_campamento').delete().eq('id', id)
    if (error) throw error
  },
}
