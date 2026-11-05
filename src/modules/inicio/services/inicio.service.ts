import { supabase } from '@/lib/supabase'
import { cachedFetch, TTL_1H } from '@/lib/localCache'

// ── Tipos ────────────────────────────────────────────────────────────────────
export interface ProgresoHoy {
  registradas: number
  esperadas: number
  porcentaje: number
}

export interface MisNotasHoy {
  total: number
  ultima: { criterio: string; equipo: string; haceMin: number } | null
}

export interface MisIncidencias {
  total: number
  pendientes: number  // en_descargo o sin validar
}

export interface PendienteHoy {
  programacion_id: string
  nombre: string
  categoria: string
  faltantes: number
}

export interface ActividadHoy {
  id: string
  nombre: string
  hora_inicio: string | null
  lugar: string | null
  estado: string
}

export interface DiaCampamentoConEstado {
  codigo: string
  nombre: string
  fecha: string
  orden: number
  cerrado: boolean
  publicado: boolean
  esHoy: boolean
}

// ── Service ──────────────────────────────────────────────────────────────────
export const inicioService = {

  /** Progreso global del día actual (v_progreso_evaluacion). */
  async getProgresoHoy(campamentoId: string, momento: string): Promise<ProgresoHoy> {
    const { data, error } = await supabase
      .from('v_progreso_evaluacion')
      .select('*')
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)
      .single()
    if (error || !data) return { registradas: 0, esperadas: 0, porcentaje: 0 }
    const r = data as { observaciones_registradas: number; observaciones_esperadas: number; porcentaje: number }
    return {
      registradas: r.observaciones_registradas ?? 0,
      esperadas: r.observaciones_esperadas ?? 0,
      porcentaje: Math.round(r.porcentaje ?? 0),
    }
  },

  /** Observaciones + liderazgo registradas hoy por este evaluador. */
  async getMisNotasHoy(campamentoId: string, momento: string, evaluadorId: string): Promise<MisNotasHoy> {
    // Observaciones de rúbrica del evaluador en este día
    const { data: obs } = await supabase
      .from('observaciones')
      .select('updated_at, programacion!inner(momento, campamento_id, criterios(nombre)), equipos(nombre)')
      .eq('evaluador_id', evaluadorId)
      .eq('programacion.campamento_id', campamentoId)
      .eq('programacion.momento', momento)
      .order('updated_at', { ascending: false })

    // Indicadores de liderazgo del evaluador hoy
    const { data: lid } = await (supabase as any)
      .from('liderazgo_registros')
      .select('updated_at')
      .eq('evaluador_id', evaluadorId)
      .eq('campamento_id', campamentoId)
      .eq('momento', momento)

    const totalObs = (obs ?? []).length
    const totalLid = (lid ?? []).length
    const total = totalObs + totalLid

    let ultima: MisNotasHoy['ultima'] = null
    if (obs && obs.length > 0) {
      const last = obs[0] as any
      const criterioNombre = last?.programacion?.criterios?.nombre ?? '—'
      const equipoNombre = last?.equipos?.nombre ?? '—'
      const haceMin = Math.round((Date.now() - new Date(last.updated_at).getTime()) / 60000)
      ultima = { criterio: criterioNombre, equipo: equipoNombre, haceMin }
    }

    return { total, ultima }
  },

  /** Incidencias registradas por este evaluador. */
  async getMisIncidencias(campamentoId: string, evaluadorId: string): Promise<MisIncidencias> {
    const { data } = await supabase
      .from('incidencias')
      .select('validado')
      .eq('campamento_id' as any, campamentoId)
      .eq('evaluador_id' as any, evaluadorId)

    const total = (data ?? []).length
    const pendientes = (data ?? []).filter((i: any) => !i.validado).length
    return { total, pendientes }
  },

  /** Criterios programados hoy con equipos sin nota (máx. 5). */
  async getPendientesHoy(
    campamentoId: string,
    momento: string,
    evaluadorId: string,
  ): Promise<PendienteHoy[]> {
    const key = `pendientes_hoy_${campamentoId}_${momento}_${evaluadorId}`
    return cachedFetch(key, async () => {
      // Programaciones de rúbrica activas para este momento y campamento
      const { data: progs } = await supabase
        .from('programacion')
        .select('id, criterios!inner(nombre, categoria, activo, tipo_calculo)')
        .eq('campamento_id', campamentoId)
        .eq('momento', momento)
        .eq('estado', 'programado')
        .eq('criterios.activo', true)
        .eq('criterios.tipo_calculo', 'rubrica')

      if (!progs || progs.length === 0) return []

      // Total de equipos activos
      const { data: equipos } = await supabase
        .from('equipos')
        .select('id')
        .eq('campamento_id', campamentoId)
        .eq('activo', true)

      const totalEquipos = (equipos ?? []).length
      if (totalEquipos === 0) return []

      // Observaciones ya registradas por este evaluador hoy
      const progIds = progs.map((p: any) => p.id)
      const { data: obs } = await supabase
        .from('observaciones')
        .select('programacion_id')
        .eq('evaluador_id', evaluadorId)
        .in('programacion_id', progIds)

      const conteoObs: Record<string, number> = {}
      for (const o of obs ?? []) {
        conteoObs[o.programacion_id] = (conteoObs[o.programacion_id] ?? 0) + 1
      }

      const pendientes: PendienteHoy[] = []
      for (const p of progs as any[]) {
        const registradas = conteoObs[p.id] ?? 0
        const faltantes = totalEquipos - registradas
        if (faltantes > 0) {
          pendientes.push({
            programacion_id: p.id,
            nombre: p.criterios?.nombre ?? '—',
            categoria: p.criterios?.categoria ?? '—',
            faltantes,
          })
        }
      }

      return pendientes.sort((a, b) => b.faltantes - a.faltantes).slice(0, 5)
    }, 5 * 60 * 1000) // 5 min TTL (datos más frescos que TTL_1H)
  },

  /** Actividades del día ordenadas por hora. */
  async getActividadesHoy(campamentoId: string, momento: string): Promise<ActividadHoy[]> {
    return cachedFetch(`actividades_hoy_${campamentoId}_${momento}`, async () => {
      const { data, error } = await supabase
        .from('actividades')
        .select('id, nombre, hora_inicio, lugar, estado, programacion!inner(momento, campamento_id)')
        .eq('programacion.campamento_id', campamentoId)
        .eq('programacion.momento', momento)
        .order('hora_inicio', { ascending: true, nullsFirst: true })
      if (error) return []
      return (data ?? [])
        .filter((a: any) => a.programacion !== null)
        .map((a: any) => ({
          id: a.id,
          nombre: a.nombre,
          hora_inicio: a.hora_inicio,
          lugar: a.lugar,
          estado: a.estado,
        }))
    }, TTL_1H)
  },

  /** Días del campamento enriquecidos con estado de dias_evaluacion. */
  async getDiasCampamento(campamentoId: string): Promise<DiaCampamentoConEstado[]> {
    return cachedFetch(`dias_camp_estado_${campamentoId}`, async () => {
      const [{ data: dias }, { data: eval_ }] = await Promise.all([
        supabase
          .from('dias_campamento')
          .select('codigo, nombre, fecha, orden')
          .eq('campamento_id', campamentoId)
          .order('orden'),
        supabase
          .from('dias_evaluacion')
          .select('momento, cerrado, publicado')
          .eq('campamento_id', campamentoId),
      ])

      const evalMap: Record<string, { cerrado: boolean; publicado: boolean }> = {}
      for (const e of eval_ ?? []) {
        evalMap[e.momento] = { cerrado: e.cerrado ?? false, publicado: e.publicado ?? false }
      }

      const hoy = new Date()
      const hoyStr = `${hoy.getFullYear()}-${String(hoy.getMonth()+1).padStart(2,'0')}-${String(hoy.getDate()).padStart(2,'0')}`

      return (dias ?? []).map((d: any) => ({
        codigo: d.codigo,
        nombre: d.nombre,
        fecha: d.fecha,
        orden: d.orden,
        cerrado: evalMap[d.codigo]?.cerrado ?? false,
        publicado: evalMap[d.codigo]?.publicado ?? false,
        esHoy: d.fecha === hoyStr,
      }))
    }, TTL_1H)
  },
}
