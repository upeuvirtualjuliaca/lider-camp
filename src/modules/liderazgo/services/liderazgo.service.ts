import { supabase } from '@/lib/supabase'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

export type LiderazgoIndicador        = Tables<'liderazgo_indicadores'>
export type LiderazgoEvaluacion       = Tables<'liderazgo_evaluaciones'>
export type LiderazgoEquipoDia        = Tables<'v_liderazgo_equipo_dia'>
export type ValidacionIndicadores     = Tables<'v_validacion_indicadores'>
export type PublicoLiderazgoIndicador = Tables<'publico_liderazgo_indicadores'>

// Programacion row with criterio joined
export interface ProgramacionLiderazgo {
  id: string
  momento: string
  estado: string
  puntaje_max: number
  criterio_id: string
}

// ── Indicadores ──────────────────────────────────────────────────────────────

export const indicadoresService = {
  async getAll(): Promise<LiderazgoIndicador[]> {
    const { data, error } = await supabase
      .from('liderazgo_indicadores')
      .select('*')
      .order('orden')
    if (error) throw error
    return data ?? []
  },

  async upsert(datos: TablesInsert<'liderazgo_indicadores'>): Promise<LiderazgoIndicador> {
    const { data, error } = await supabase
      .from('liderazgo_indicadores')
      .upsert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'liderazgo_indicadores'>): Promise<LiderazgoIndicador> {
    const { data, error } = await supabase
      .from('liderazgo_indicadores')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },
}

// ── Validación ───────────────────────────────────────────────────────────────

export const validacionService = {
  async get(): Promise<ValidacionIndicadores | null> {
    const { data, error } = await supabase
      .from('v_validacion_indicadores')
      .select('*')
      .maybeSingle()
    if (error) throw error
    return data
  },
}

// ── Programación de liderazgo ────────────────────────────────────────────────

export const programacionLiderazgoService = {
  async getPorDia(momento: string, campamentoId?: string | null): Promise<ProgramacionLiderazgo | null> {
    let q = supabase
      .from('programacion')
      .select('id, momento, estado, puntaje_max, criterio_id, criterios!inner(tipo_calculo)')
      .eq('momento', momento)
      .eq('criterios.tipo_calculo', 'liderazgo')
      .eq('estado', 'programado')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q.maybeSingle()
    if (error) throw error
    if (!data) return null
    return {
      id: data.id,
      momento: data.momento,
      estado: data.estado,
      puntaje_max: data.puntaje_max,
      criterio_id: data.criterio_id,
    }
  },
}

// ── Evaluaciones ─────────────────────────────────────────────────────────────

export const evaluacionesService = {
  async getPorEquipoDia(
    equipo_id: string,
    programacion_id: string,
  ): Promise<LiderazgoEvaluacion[]> {
    const { data, error } = await supabase
      .from('liderazgo_evaluaciones')
      .select('*')
      .eq('equipo_id', equipo_id)
      .eq('programacion_id', programacion_id)
    if (error) throw error
    return data ?? []
  },

  async upsert(datos: TablesInsert<'liderazgo_evaluaciones'> & { motivo_cambio?: string | null }): Promise<LiderazgoEvaluacion> {
    const { data, error } = await supabase
      .from('liderazgo_evaluaciones')
      .upsert(datos, { onConflict: 'equipo_id,programacion_id,indicador_id' })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getResumenDia(momento: string, campamentoId?: string | null): Promise<LiderazgoEquipoDia[]> {
    let q = supabase
      .from('v_liderazgo_equipo_dia')
      .select('*')
      .eq('momento', momento)
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}

// ── Vista pública (anon) ─────────────────────────────────────────────────────

export const publicoLiderazgoService = {
  async getIndicadores(): Promise<PublicoLiderazgoIndicador[]> {
    const { data, error } = await supabase
      .from('publico_liderazgo_indicadores')
      .select('*')
    if (error) throw error
    return data ?? []
  },
}
