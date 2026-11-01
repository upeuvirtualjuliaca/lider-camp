import { supabase } from '@/lib/supabase'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

export type Equipo = Tables<'equipos'>
export type Integrante = Tables<'integrantes'>

export interface InscripcionEquipo {
  equipo_id: string
  equipo_nombre: string
  equipo_color: string
  nomina: number
  inscritos_completos: number
  inscritos_parciales: number
  inscritos_tardios: number
  puntaje_inscripcion: number
}

export const equiposService = {
  async getTodos(campamentoId?: string): Promise<Equipo[]> {
    let q = supabase.from('equipos').select('*').order('nombre')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async getPorId(id: string): Promise<Equipo | null> {
    const { data, error } = await supabase
      .from('equipos')
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async crear(equipo: TablesInsert<'equipos'>): Promise<Equipo> {
    const { data, error } = await supabase
      .from('equipos')
      .insert(equipo)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, cambios: TablesUpdate<'equipos'>): Promise<Equipo> {
    const { data, error } = await supabase
      .from('equipos')
      .update(cambios)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getInscripciones(campamentoId?: string): Promise<InscripcionEquipo[]> {
    let q = supabase.from('v_inscripcion_equipo').select('*').order('equipo_nombre')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return (data ?? []) as InscripcionEquipo[]
  },
}

export const integrantesService = {
  async getPorEquipo(equipoId: string): Promise<Integrante[]> {
    const { data, error } = await supabase
      .from('integrantes')
      .select('*')
      .eq('equipo_id', equipoId)
      .order('apellidos')
    if (error) throw error
    return data ?? []
  },

  async crear(integrante: TablesInsert<'integrantes'>): Promise<Integrante> {
    const { data, error } = await supabase
      .from('integrantes')
      .insert(integrante)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async crearMasivo(integrantes: TablesInsert<'integrantes'>[]): Promise<Integrante[]> {
    const { data, error } = await supabase
      .from('integrantes')
      .insert(integrantes)
      .select()
    if (error) throw error
    return data ?? []
  },

  async actualizar(id: string, cambios: TablesUpdate<'integrantes'>): Promise<Integrante> {
    const { data, error } = await supabase
      .from('integrantes')
      .update(cambios)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },
}
