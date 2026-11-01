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
