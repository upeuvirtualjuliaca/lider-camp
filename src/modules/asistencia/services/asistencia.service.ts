import { supabase } from '@/lib/supabase'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

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
  async getPorDia(momento: string): Promise<ActividadConProgramacion[]> {
    const { data, error } = await supabase
      .from('actividades')
      .select('*, programacion(*, criterios(*))')
      .eq('programacion.momento', momento)
      .order('hora_inicio', { ascending: true, nullsFirst: true })
    if (error) throw error
    // Filtrar los que realmente pertenecen al momento (el join puede traer nulos)
    return (data ?? []).filter(
      (a) => a.programacion !== null,
    ) as ActividadConProgramacion[]
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

// ── asistenciaService ────────────────────────────────────────────────────────
export const asistenciaService = {
  async getRegistrosPorActividad(actividad_id: string): Promise<RegistroConIntegrante[]> {
    const { data, error } = await supabase
      .from('asistencia_registros')
      .select('*, integrantes(id, nombres, apellidos, equipo_id)')
      .eq('actividad_id', actividad_id)
    if (error) throw error
    return (data ?? []) as RegistroConIntegrante[]
  },

  async upsert(
    datos: TablesInsert<'asistencia_registros'>,
  ): Promise<AsistenciaRegistro> {
    const payload: TablesInsert<'asistencia_registros'> = {
      ...datos,
      // limpiar justificación si no aplica
      motivo_justificacion:
        datos.estado === 'justificado' ? datos.motivo_justificacion ?? null : null,
      documentado: datos.estado === 'justificado' ? (datos.documentado ?? false) : false,
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
    const { data, error } = await supabase
      .from('v_asistencia_equipo_actividad')
      .select('*')
      .eq('actividad_id', actividad_id)
    if (error) throw error
    return data ?? []
  },

  async getResumenPorDia(momento: string): Promise<AsistenciaEquipoDia[]> {
    const { data, error } = await supabase
      .from('v_asistencia_equipo_dia')
      .select('*')
      .eq('momento', momento)
    if (error) throw error
    return data ?? []
  },
}

// ── integrantesAsistenciaService ─────────────────────────────────────────────
export const integrantesAsistenciaService = {
  async getPorEquipo(equipo_id: string) {
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
  },
}
