import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database'

export type AuditoriaFila       = Tables<'v_auditoria_legible'>
export type SolicitudRevision   = Tables<'solicitudes_revision'>
export type PendientePublicacion = Tables<'v_pendientes_publicacion'>

export interface FiltrosAuditoria {
  tabla?:    string
  accion?:   string
  desde?:    string
  hasta?:    string
}

// ── Auditoría ──────────────────────────────────────────────────────────────────

export const auditoriaService = {
  async getAll(filtros: FiltrosAuditoria = {}): Promise<AuditoriaFila[]> {
    let q = supabase
      .from('v_auditoria_legible')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(500)

    if (filtros.tabla)  q = q.eq('tabla',  filtros.tabla)
    if (filtros.accion) q = q.eq('accion', filtros.accion)
    if (filtros.desde)  q = q.gte('created_at', filtros.desde)
    if (filtros.hasta)  q = q.lte('created_at', filtros.hasta + 'T23:59:59')

    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async historialRegistro(
    tabla: string,
    id: string,
  ): Promise<AuditoriaFila[]> {
    const { data, error } = await supabase.rpc('historial_registro', {
      p_tabla: tabla,
      p_id:    id,
    })
    if (error) throw error
    return (data ?? []) as AuditoriaFila[]
  },
}

// ── Solicitudes de revisión ────────────────────────────────────────────────────

export const solicitudesService = {
  async getMias(campamentoId?: string): Promise<SolicitudRevision[]> {
    let q = supabase
      .from('solicitudes_revision')
      .select('*')
      .order('created_at', { ascending: false })
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async getTodas(campamentoId?: string): Promise<SolicitudRevision[]> {
    let q = supabase
      .from('solicitudes_revision')
      .select('*')
      .order('created_at', { ascending: false })
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async crear(
    payload: { tabla: string; registro_id?: string | null; descripcion: string },
    campamentoId: string,
  ): Promise<SolicitudRevision> {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('No autenticado')

    const { data, error } = await supabase
      .from('solicitudes_revision')
      .insert({ ...payload, solicitante_id: user.id, campamento_id: campamentoId })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async resolver(id: string, decision: 'aprobada' | 'rechazada', respuesta?: string) {
    const { error } = await supabase.rpc('resolver_solicitud', {
      p_id:       id,
      p_decision: decision,
      p_respuesta: respuesta ?? undefined,
    })
    if (error) throw error
  },
}

// ── Pendientes de publicación ──────────────────────────────────────────────────

export const publicacionService = {
  async getPendientes(campamentoId: string): Promise<PendientePublicacion[]> {
    const { data, error } = await supabase
      .from('v_pendientes_publicacion')
      .select('*')
      .eq('campamento_id', campamentoId)
    if (error) throw error
    return data ?? []
  },

  async publicarDia(campamentoId: string, momento: string) {
    const { error } = await supabase
      .from('dias_evaluacion')
      .update({ publicado: true })
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)
    if (error) throw error
  },

  async despublicarDia(campamentoId: string, momento: string) {
    const { error } = await supabase
      .from('dias_evaluacion')
      .update({ publicado: false })
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)
    if (error) throw error
  },
}

// ── Campamento: cierre ─────────────────────────────────────────────────────────

export const campamentoAdminService = {
  async getEstado(campamentoId: string): Promise<{ cerrado: boolean; cerrado_at: string | null; motivo_cierre: string | null }> {
    const { data, error } = await supabase
      .from('campamento')
      .select('cerrado, cerrado_at, motivo_cierre')
      .eq('id', campamentoId)
      .maybeSingle()
    if (error) throw error
    return (data as { cerrado: boolean; cerrado_at: string | null; motivo_cierre: string | null }) ?? { cerrado: false, cerrado_at: null, motivo_cierre: null }
  },

  async cerrar(campamentoId: string, motivo: string, forzar = false) {
    const { error } = await supabase.rpc('cerrar_campamento', {
      p_campamento_id: campamentoId,
      p_motivo: motivo,
      p_forzar: forzar,
    })
    if (error) throw error
  },

  async reabrir(campamentoId: string, motivo: string) {
    const { error } = await supabase.rpc('reabrir_campamento', {
      p_campamento_id: campamentoId,
      p_motivo: motivo,
    })
    if (error) throw error
  },
}
