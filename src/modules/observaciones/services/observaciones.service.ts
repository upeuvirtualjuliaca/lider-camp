import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database'

// ── Tipos exportados ────────────────────────────────────────────────────────
export type DiasEvaluacion = Tables<'dias_evaluacion'>
export type Observacion = Tables<'observaciones'>
export type PuntajeEquipoDia = Tables<'v_puntaje_rubrica_equipo_dia'>
export type ProgresoEvaluacion = Tables<'v_progreso_evaluacion'>

// Tipos enriquecidos (join)
export interface ObservacionConDetalle extends Omit<Observacion, 'programacion_id'> {
  programacion: {
    id: string
    momento: string
    puntaje_max: number
    estado: string
    motivo: string | null
    criterios: {
      id: string
      codigo: string
      nombre: string
      categoria: string
      tipo_calculo: string
      abarca: string | null
      no_abarca: string | null
      evidencia: string | null
      orden: number
      activo: boolean
    }
  }
}

export interface ObservacionConEquipo extends Observacion {
  equipos: {
    id: string
    nombre: string
    color: string
    activo: boolean
    escuela_profesional: string
  }
}

export interface ProgramacionConCriterio {
  id: string
  momento: string
  puntaje_max: number
  estado: string
  motivo: string | null
  criterio_id: string
  criterios: {
    id: string
    codigo: string
    nombre: string
    categoria: string
    tipo_calculo: string
    abarca: string | null
    no_abarca: string | null
    evidencia: string | null
    orden: number
    activo: boolean
  }
}

export interface UpsertObservacion {
  equipo_id: string
  programacion_id: string
  puntaje: number
  comentario?: string | null
  evaluador_id: string
  motivo_cambio?: string | null
}

// ── diasService ─────────────────────────────────────────────────────────────
export const diasService = {
  async getTodos(campamentoId: string): Promise<DiasEvaluacion[]> {
    const { data, error } = await supabase
      .from('dias_evaluacion')
      .select('*')
      .eq('campamento_id', campamentoId)
      .order('momento')
    if (error) throw error
    return data ?? []
  },

  async cerrar(campamentoId: string, momento: string, cerrado_por_id: string): Promise<DiasEvaluacion> {
    const { data, error } = await supabase
      .from('dias_evaluacion')
      .update({
        cerrado: true,
        cerrado_at: new Date().toISOString(),
        cerrado_por: cerrado_por_id,
      })
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async abrir(campamentoId: string, momento: string): Promise<DiasEvaluacion> {
    const { data, error } = await supabase
      .from('dias_evaluacion')
      .update({
        cerrado: false,
        cerrado_at: null,
        cerrado_por: null,
      })
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)
      .select()
      .single()
    if (error) throw error
    return data
  },
}

// ── observacionesService ────────────────────────────────────────────────────
export const observacionesService = {
  async getPorEquipoYDia(
    equipo_id: string,
    momento: string,
  ): Promise<ObservacionConDetalle[]> {
    const { data, error } = await supabase
      .from('observaciones')
      .select('*, programacion(*, criterios(*))')
      .eq('equipo_id', equipo_id)
      .eq('programacion.momento', momento)
    if (error) throw error
    // Filtrar nulls (filas donde el join no coincide con momento)
    return (data ?? []).filter(
      (o) => o.programacion !== null,
    ) as unknown as ObservacionConDetalle[]
  },

  async getPorCriterioYDia(programacion_id: string): Promise<ObservacionConEquipo[]> {
    const { data, error } = await supabase
      .from('observaciones')
      .select('*, equipos(*)')
      .eq('programacion_id', programacion_id)
    if (error) throw error
    return (data ?? []) as unknown as ObservacionConEquipo[]
  },

  async upsert(datos: UpsertObservacion): Promise<Observacion> {
    const { data, error } = await supabase
      .from('observaciones')
      .upsert(datos, { onConflict: 'equipo_id,programacion_id' })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getPuntajeEquipoDia(momento: string, campamentoId?: string | null): Promise<PuntajeEquipoDia[]> {
    let q = supabase.from('v_puntaje_rubrica_equipo_dia').select('*').eq('momento', momento)
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },

  async getProgreso(campamentoId?: string | null): Promise<ProgresoEvaluacion[]> {
    let q = supabase.from('v_progreso_evaluacion').select('*')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return data ?? []
  },
}

// ── programacionRubricaService ───────────────────────────────────────────────
export const programacionRubricaService = {
  async getMomentosConProgramacion(campamentoId?: string | null): Promise<string[]> {
    let q = supabase
      .from('programacion')
      .select('momento, criterios!inner(tipo_calculo, activo)')
      .eq('criterios.tipo_calculo', 'rubrica')
      .eq('criterios.activo', true)
      .eq('estado', 'programado')
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error
    return [...new Set((data ?? []).map((r: any) => r.momento as string))]
  },

  async getPorDia(momento: string, campamentoId?: string | null): Promise<ProgramacionConCriterio[]> {
    // 1. Filas de programacion para este momento
    let q = supabase
      .from('programacion')
      .select('*, criterios(*)')
      .eq('momento', momento)
      .order('orden', { referencedTable: 'criterios' })
    if (campamentoId) q = q.eq('campamento_id', campamentoId)
    const { data, error } = await q
    if (error) throw error

    // Filtrar rubrica (case-insensitive) y activos
    const progs = ((data ?? []).filter(
      (p) => p.criterios !== null &&
             (p.criterios as any).tipo_calculo?.toLowerCase() === 'rubrica' &&
             (p.criterios as any).activo === true,
    )) as unknown as ProgramacionConCriterio[]

    // 2. Si hay campamentoId, completar con criterios rubrica sin fila en programacion
    if (campamentoId) {
      const { data: ccData } = await supabase
        .from('campamento_criterios')
        .select('criterio_id, criterios(*)')
        .eq('campamento_id', campamentoId)

      const progCriterioIds = new Set(progs.map((p) => p.criterio_id))

      for (const cc of (ccData ?? []) as any[]) {
        const c = cc.criterios
        if (!c || c.tipo_calculo?.toLowerCase() !== 'rubrica' || !c.activo) continue
        if (progCriterioIds.has(cc.criterio_id)) continue
        // Criterio rubrica del campamento sin programacion para este momento → no_programado
        progs.push({
          id: `noprog_${cc.criterio_id}`,
          momento,
          puntaje_max: 0,
          estado: 'no_programado',
          motivo: null,
          criterio_id: cc.criterio_id,
          criterios: c,
        } as unknown as ProgramacionConCriterio)
      }

      progs.sort((a, b) => (a.criterios.orden ?? 0) - (b.criterios.orden ?? 0))
    }

    return progs
  },
}
