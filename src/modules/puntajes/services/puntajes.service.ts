import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database'

export type PuntajeEquipo    = Tables<'v_puntaje_equipo'>
export type PublicoRanking   = Tables<'publico_ranking'>
export type PublicoFichaFila = Tables<'publico_ficha_equipo'>

// ── Admin (autenticado) ───────────────────────────────────────────────────────
export const rankingAdminService = {
  async getAll(campamentoId?: string): Promise<PuntajeEquipo[]> {
    let q = supabase.from('v_puntaje_equipo').select('*').order('posicion')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}

// ── Público (anon) ────────────────────────────────────────────────────────────
export const rankingPublicoService = {
  async getAll(campamentoId?: string): Promise<PublicoRanking[]> {
    let q = supabase.from('publico_ranking').select('*').order('posicion')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async getPorId(equipoId: string): Promise<PublicoRanking | null> {
    const { data, error } = await supabase
      .from('publico_ranking')
      .select('*')
      .eq('equipo_id', equipoId)
      .maybeSingle()
    if (error) throw error
    return data
  },
}

// Tipo manual porque la vista es nueva y no está en database.ts generado
export interface PublicoRankingDia {
  equipo_id: string
  campamento_id: string
  equipo_nombre: string
  equipo_color: string | null
  momento: string
  pts_rubrica: number
  pts_actividades: number
  pts_bonus: number
  pts_demeritos: number
  pts_total: number
  posicion: number
}

export const rankingDiarioPublicoService = {
  async getAll(campamentoId?: string): Promise<PublicoRankingDia[]> {
    let q = (supabase as any)
      .from('publico_ranking_dia')
      .select('*')
      .order('momento')
      .order('posicion')
    if (campamentoId) q = (q as any).eq('campamento_id', campamentoId)
    const { data, error } = await (q as any)
    if (error) throw error
    return (data ?? []) as PublicoRankingDia[]
  },
}

// Ranking total final — solo cuando campamento.cerrado = true
export interface PublicoRankingTotal {
  equipo_id: string
  campamento_id: string
  equipo_nombre: string
  equipo_color: string | null
  pts_rubrica: number
  pts_actividades: number
  pts_bonus: number
  pts_demeritos: number
  pts_bruto: number
  pts_escala: number
  medalla: string | null
  posicion: number
}

export const rankingTotalPublicoService = {
  async getAll(campamentoId?: string): Promise<PublicoRankingTotal[]> {
    let q = (supabase as any)
      .from('publico_ranking_total')
      .select('equipo_id,campamento_id,equipo_nombre,equipo_color,pts_rubrica,pts_actividades,pts_bonus,pts_demeritos,pts_bruto,pts_escala,medalla,posicion')
      .order('posicion')
    if (campamentoId) q = (q as any).eq('campamento_id', campamentoId)
    const { data, error } = await (q as any)
    if (error) throw error
    return (data ?? []) as PublicoRankingTotal[]
  },
}

export const fichaPublicaService = {
  async getPorEquipo(equipoId: string): Promise<PublicoFichaFila[]> {
    const { data, error } = await supabase
      .from('publico_ficha_equipo')
      .select('*')
      .eq('equipo_id', equipoId)
      .order('momento')
      .order('tipo_fila')
      .order('criterio_nombre')
    if (error) throw error
    return data ?? []
  },
}
