import { supabase } from '@/lib/supabase'
import { enqueue } from '@/lib/offlineQueue'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

// ── Tipos exportados ──────────────────────────────────────────────────────────
export type IncidenciaCodigo   = Tables<'incidencia_codigos'>
export type Incidencia         = Tables<'incidencias'>
export type IncidenciaIntegrante = Tables<'incidencia_integrantes'>
export type IncidenciaEvidencia  = Tables<'incidencia_evidencias'>
export type IncidenciaPendiente  = Tables<'v_incidencias_pendientes'>
export type BonusEquipo          = Tables<'v_bonus_equipo'>
export type DemeritoEquipo       = Tables<'v_demeritos_equipo'>

export interface IncidenciaDetalle extends Incidencia {
  integrantes: IncidenciaIntegrante[]
  evidencias: IncidenciaEvidencia[]
  codigo_info: IncidenciaCodigo | null
}

export interface FiltrosIncidencia {
  tipo?: 'bonus' | 'demerito'
  equipo_id?: string
  campamento_id?: string
  codigo?: string
  estado?: string
  fecha?: string
}

// ── Catálogo de códigos ───────────────────────────────────────────────────────
export const codigosService = {
  async getAll(): Promise<IncidenciaCodigo[]> {
    const { data, error } = await supabase
      .from('incidencia_codigos')
      .select('*')
      .eq('activo', true)
      .order('tipo')
      .order('orden')
    if (error) throw error
    return data ?? []
  },
}

// ── Incidencias ───────────────────────────────────────────────────────────────
export const incidenciasService = {
  async getAll(filtros: FiltrosIncidencia = {}): Promise<Incidencia[]> {
    // Usar alias + hint de FK para evitar ambigüedad (incidencias tiene dos FK a equipos:
    // equipo_id y equipo_apoyado_id)
    const selectStr = filtros.campamento_id
      ? '*, eq_camp:equipos!equipo_id!inner(campamento_id)'
      : '*'

    let q = supabase
      .from('incidencias')
      .select(selectStr)
      .order('fecha', { ascending: false })
      .order('hora', { ascending: false })

    if (filtros.campamento_id) q = (q as any).eq('eq_camp.campamento_id', filtros.campamento_id)
    if (filtros.equipo_id)     q = q.eq('equipo_id', filtros.equipo_id)
    if (filtros.codigo)        q = q.eq('codigo', filtros.codigo)
    if (filtros.estado)        q = q.eq('estado', filtros.estado)
    if (filtros.fecha)         q = q.eq('fecha', filtros.fecha)

    const { data, error } = await q
    if (error) throw error

    // filtro por tipo requiere join a codigos; si viene, filtramos en memoria
    // (el volumen de incidencias es pequeño)
    return (data ?? []) as unknown as Incidencia[]
  },

  async getValidadasPorMomento(
    momento: string,
    campamentoId?: string | null,
  ): Promise<{ equipo_id: string; tipo: string; puntos: number }[]> {
    const selectStr = campamentoId
      ? 'equipo_id, puntos, cod:incidencia_codigos!incidencias_codigo_fkey(tipo), eq_camp:equipos!equipo_id!inner(campamento_id)'
      : 'equipo_id, puntos, cod:incidencia_codigos!incidencias_codigo_fkey(tipo)'
    let q = (supabase as any)
      .from('incidencias')
      .select(selectStr)
      .eq('momento', momento)
      .eq('estado', 'validado')
    if (campamentoId) q = q.eq('eq_camp.campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return ((data ?? []) as any[]).map((r) => ({
      equipo_id: r.equipo_id,
      tipo: r.cod?.tipo ?? '',
      puntos: r.puntos ?? 0,
    }))
  },

  async getPorId(id: string): Promise<IncidenciaDetalle | null> {
    const { data, error } = await supabase
      .from('incidencias')
      .select(`
        *,
        integrantes:incidencia_integrantes(*),
        evidencias:incidencia_evidencias(*),
        codigo_info:incidencia_codigos!incidencias_codigo_fkey(*)
      `)
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    if (!data) return null
    return {
      ...data,
      integrantes: (data as any).integrantes ?? [],
      evidencias: (data as any).evidencias ?? [],
      codigo_info: (data as any).codigo_info ?? null,
    }
  },

  async crear(datos: TablesInsert<'incidencias'>, integrante_ids?: string[]): Promise<Incidencia> {
    if (!navigator.onLine) {
      const tempId = crypto.randomUUID()
      await enqueue({
        table: 'incidencias',
        operation: 'insert',
        payload: { id: tempId, ...datos } as unknown as Record<string, unknown>,
        integrante_ids,
      })
      return {
        id: tempId,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...datos,
      } as unknown as Incidencia
    }
    const { data, error } = await supabase
      .from('incidencias')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, cambios: TablesUpdate<'incidencias'>): Promise<Incidencia> {
    const { data, error } = await supabase
      .from('incidencias')
      .update(cambios)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async validar(id: string, motivo: string): Promise<Incidencia> {
    const { data, error } = await supabase
      .from('incidencias')
      .update({ estado: 'validado', motivo_resolucion: motivo })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async rechazar(id: string, motivo: string): Promise<Incidencia> {
    const { data, error } = await supabase
      .from('incidencias')
      .update({ estado: 'rechazado', motivo_resolucion: motivo })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },
}

// ── Integrantes de incidencia ─────────────────────────────────────────────────
export const incidenciaIntegrantesService = {
  async setPorIncidencia(incidencia_id: string, integrante_ids: string[]): Promise<void> {
    // Borra los actuales y reinserta
    const { error: delErr } = await supabase
      .from('incidencia_integrantes')
      .delete()
      .eq('incidencia_id', incidencia_id)
    if (delErr) throw delErr

    if (!integrante_ids.length) return

    const rows: TablesInsert<'incidencia_integrantes'>[] = integrante_ids.map((iid) => ({
      incidencia_id,
      integrante_id: iid,
    }))
    const { error } = await supabase.from('incidencia_integrantes').insert(rows)
    if (error) throw error
  },
}

// ── Evidencias ────────────────────────────────────────────────────────────────
export const evidenciasService = {
  async subir(
    incidencia_id: string,
    archivo: File,
    subido_por: string,
  ): Promise<IncidenciaEvidencia> {
    const ext = archivo.name.split('.').pop()
    const ruta = `incidencias/${incidencia_id}/${Date.now()}.${ext}`

    const { error: upErr } = await supabase.storage
      .from('evidencias')
      .upload(ruta, archivo)
    if (upErr) throw upErr

    const { data, error } = await supabase
      .from('incidencia_evidencias')
      .insert({
        incidencia_id,
        ruta_archivo: ruta,
        nombre_original: archivo.name,
        tipo_archivo: archivo.type,
        subido_por,
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getUrl(ruta: string): Promise<string> {
    const { data } = await supabase.storage
      .from('evidencias')
      .createSignedUrl(ruta, 3600) // 1 hora
    return data?.signedUrl ?? ''
  },

  async eliminar(id: string, ruta: string): Promise<void> {
    const { error: storErr } = await supabase.storage.from('evidencias').remove([ruta])
    if (storErr) throw storErr
    const { error } = await supabase.from('incidencia_evidencias').delete().eq('id', id)
    if (error) throw error
  },
}

// ── Vistas de resumen ─────────────────────────────────────────────────────────
export const bonusService = {
  async getResumen(campamentoId?: string | null): Promise<BonusEquipo[]> {
    let q = supabase.from('v_bonus_equipo').select('*').order('equipo_nombre')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}

export const demeritorService = {
  async getResumen(campamentoId?: string | null): Promise<DemeritoEquipo[]> {
    let q = supabase.from('v_demeritos_equipo').select('*').order('equipo_nombre')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}

export const pendientesService = {
  async getAll(campamentoId?: string | null): Promise<IncidenciaPendiente[]> {
    let q = supabase.from('v_incidencias_pendientes').select('*').order('created_at')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}
