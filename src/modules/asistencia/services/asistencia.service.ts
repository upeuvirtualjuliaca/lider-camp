import { supabase } from '@/lib/supabase'
import { enqueue } from '@/lib/offlineQueue'
import { cachedFetch, TTL_1H } from '@/lib/localCache'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

export type EvalRegistro = Tables<'actividad_eval_registros'>

// ── Tipos exportados ─────────────────────────────────────────────────────────
export type Actividad = Tables<'actividades'>
export type AsistenciaRegistro = Tables<'asistencia_registros'>
export type AsistenciaEquipoActividad = Tables<'v_asistencia_equipo_actividad'>
export type AsistenciaEquipoDia = Tables<'v_asistencia_equipo_dia'>

// Tipo enriquecido con joins
export type ActividadConProgramacion = Actividad & {
  programacion: {
    id: string
    momento: string
    puntaje_max: number
    estado: string
    criterio_id: string
    criterios: {
      id: string
      codigo: string
      nombre: string
      tipo_calculo: string
      categoria: string
    }
  }
}

export type RegistroConIntegrante = AsistenciaRegistro & {
  integrantes: {
    id: string
    nombres: string
    apellidos: string
    equipo_id: string
  }
}

// ── actividadesService ────────────────────────────────────────────────────────
export const actividadesService = {
  async getConteosPorCampamento(campamentoId: string): Promise<Record<string, number>> {
    return cachedFetch(`actividades_conteos_${campamentoId}`, async () => {
      const { data, error } = await supabase
        .from('actividades')
        .select('programacion!inner(momento, campamento_id)')
        .eq('programacion.campamento_id', campamentoId)
        .neq('estado', 'cancelada')
      if (error) throw error
      const conteo: Record<string, number> = {}
      for (const a of data ?? []) {
        const m = (a.programacion as any)?.momento as string | undefined
        if (m) conteo[m] = (conteo[m] ?? 0) + 1
      }
      return conteo
    }, TTL_1H)
  },

  async getPorDia(momento: string): Promise<ActividadConProgramacion[]> {
    return cachedFetch(`actividades_${momento}`, async () => {
      const { data, error } = await supabase
        .from('actividades')
        .select('*, programacion(*, criterios(*))')
        .eq('programacion.momento', momento)
        .order('hora_inicio', { ascending: true, nullsFirst: true })
      if (error) throw error
      return (data ?? []).filter((a) => a.programacion !== null) as ActividadConProgramacion[]
    }, TTL_1H)
  },

  async crear(datos: TablesInsert<'actividades'>): Promise<Actividad> {
    const { data, error } = await supabase
      .from('actividades')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'actividades'>): Promise<Actividad> {
    const { data, error } = await supabase
      .from('actividades')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async marcarRealizada(id: string): Promise<Actividad> {
    const { data, error } = await supabase
      .from('actividades')
      .update({ estado: 'realizada' })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async cancelar(id: string, motivo: string): Promise<Actividad> {
    const { data, error } = await supabase
      .from('actividades')
      .update({ estado: 'cancelada', motivo_cancelacion: motivo })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },
}

// ── criteriosEvalService ─────────────────────────────────────────────────────
export type CriterioEval = Tables<'actividad_criterios_eval'>

export const criteriosEvalService = {
  async getPorActividad(actividadId: string): Promise<CriterioEval[]> {
    return cachedFetch(`criterios_eval_${actividadId}`, async () => {
      const { data, error } = await supabase
        .from('actividad_criterios_eval')
        .select('*')
        .eq('actividad_id', actividadId)
        .order('orden')
      if (error) throw error
      return data ?? []
    }, TTL_1H)
  },

  async guardar(actividadId: string, criterios: { nombre: string; puntaje_max: number; orden: number }[]): Promise<void> {
    // Reemplaza todos los criterios de la actividad en una transacción implícita
    const { error: delErr } = await supabase
      .from('actividad_criterios_eval')
      .delete()
      .eq('actividad_id', actividadId)
    if (delErr) throw delErr

    if (criterios.length === 0) return

    const { error: insErr } = await supabase
      .from('actividad_criterios_eval')
      .insert(criterios.map((c) => ({ ...c, actividad_id: actividadId })))
    if (insErr) throw insErr
  },
}

// ── asistenciaService ────────────────────────────────────────────────────────
export const asistenciaService = {
  async getRegistrosPorActividad(actividad_id: string): Promise<RegistroConIntegrante[]> {
    return cachedFetch(`asistencia_registros_${actividad_id}`, async () => {
      const { data, error } = await supabase
        .from('asistencia_registros')
        .select('*, integrantes(id, nombres, apellidos, equipo_id)')
        .eq('actividad_id', actividad_id)
      if (error) throw error
      return (data ?? []) as RegistroConIntegrante[]
    }, TTL_1H)
  },

  async upsert(
    datos: TablesInsert<'asistencia_registros'>,
  ): Promise<AsistenciaRegistro> {
    const payload: TablesInsert<'asistencia_registros'> = {
      ...datos,
      motivo_justificacion:
        datos.estado === 'justificado' ? datos.motivo_justificacion ?? null : null,
      documentado: datos.estado === 'justificado' ? (datos.documentado ?? false) : false,
    }

    if (!navigator.onLine) {
      await enqueue({
        table: 'asistencia_registros',
        operation: 'upsert',
        payload: payload as unknown as Record<string, unknown>,
        conflictFields: 'actividad_id,integrante_id',
      })
      return {
        id: crypto.randomUUID(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...payload,
      } as unknown as AsistenciaRegistro
    }

    const { data, error } = await supabase
      .from('asistencia_registros')
      .upsert(payload, { onConflict: 'actividad_id,integrante_id' })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getResumenPorActividad(actividad_id: string): Promise<AsistenciaEquipoActividad[]> {
    return cachedFetch(`asistencia_resumen_act_${actividad_id}`, async () => {
      const { data, error } = await supabase
        .from('v_asistencia_equipo_actividad')
        .select('*')
        .eq('actividad_id', actividad_id)
      if (error) throw error
      return data ?? []
    }, TTL_1H)
  },

  async getResumenPorDia(momento: string): Promise<AsistenciaEquipoDia[]> {
    return cachedFetch(`asistencia_resumen_dia_${momento}`, async () => {
      const { data, error } = await supabase
        .from('v_asistencia_equipo_dia')
        .select('*')
        .eq('momento', momento)
      if (error) throw error
      return data ?? []
    }, TTL_1H)
  },
}

// ── evalRegistrosService ─────────────────────────────────────────────────────
export const evalRegistrosService = {
  async getPorActividad(actividadId: string, evaluador_id?: string): Promise<EvalRegistro[]> {
    const key = `eval_registros_${actividadId}_${evaluador_id ?? 'all'}`
    return cachedFetch(key, async () => {
      let q = supabase
        .from('actividad_eval_registros')
        .select('*')
        .eq('actividad_id', actividadId)
      if (evaluador_id) q = q.eq('evaluador_id', evaluador_id)
      const { data, error } = await q
      if (error) throw error
      return data ?? []
    }, TTL_1H)
  },

  async upsert(datos: TablesInsert<'actividad_eval_registros'>): Promise<EvalRegistro> {
    if (!navigator.onLine) {
      await enqueue({
        table: 'actividad_eval_registros',
        operation: 'upsert',
        payload: datos as unknown as Record<string, unknown>,
        conflictFields: 'criterio_eval_id,equipo_id,evaluador_id',
      })
      return {
        id: crypto.randomUUID(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...datos,
      } as unknown as EvalRegistro
    }
    const { data, error } = await supabase
      .from('actividad_eval_registros')
      .upsert(datos, { onConflict: 'criterio_eval_id,equipo_id,evaluador_id' })
      .select()
      .single()
    if (error) throw error
    return data
  },
}

// ── integrantesAsistenciaService ─────────────────────────────────────────────
export const integrantesAsistenciaService = {
  async getPorEquipo(equipo_id: string) {
    return cachedFetch(`integrantes_${equipo_id}`, async () => {
      const { data, error } = await supabase
        .from('integrantes')
        .select('id, nombres, apellidos, equipo_id, activo, elegible')
        .eq('equipo_id', equipo_id)
        .eq('activo', true)
        .eq('elegible', true)
        .order('apellidos', { ascending: true })
        .order('nombres', { ascending: true })
      if (error) throw error
      return data ?? []
    })
  },
}
