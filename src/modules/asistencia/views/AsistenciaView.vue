<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import {
  actividadesService,
  asistenciaService,
  criteriosEvalService,
  evalRegistrosService,
  integrantesAsistenciaService,
  type ActividadConProgramacion,
  type RegistroConIntegrante,
  type AsistenciaEquipoActividad,
  type CriterioEval,
} from '@/modules/asistencia/services/asistencia.service'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import type { Tables } from '@/types/database'
import { cachedFetch, TTL_1H } from '@/lib/localCache'
import ModeTabs from '@/modules/observaciones/components/ModeTabs.vue'
import TeamRow from '@/modules/observaciones/components/TeamRow.vue'
import CriterioRow from '@/modules/observaciones/components/CriterioRow.vue'
import ScoreStepper from '@/modules/asistencia/components/ScoreStepper.vue'
import ActivityCard from '@/modules/asistencia/components/ActivityCard.vue'
import ActivityPicker from '@/modules/asistencia/components/ActivityPicker.vue'

// ── Tipos ────────────────────────────────────────────────────────────────────
type EstadoAsistencia = 'presente' | 'ausente' | 'justificado'
type EstadoGuardado   = 'idle' | 'guardando' | 'guardado' | 'error'

interface FilaCriterio {
  criterio: CriterioEval
  puntaje: number | null
  estadoGuardado: EstadoGuardado
}

interface FilaEquipoCriterio {
  equipo: Equipo
  puntaje: number | null
  estadoGuardado: EstadoGuardado
}

interface FilaIntegrante {
  integrante: { id: string; nombres: string; apellidos: string; equipo_id: string }
  estado: EstadoAsistencia | null
  motivo_justificacion: string | null
  documentado: boolean
  estadoGuardado: EstadoGuardado
}

type DiasEvaluacion = Tables<'dias_evaluacion'>

// ── Constantes ────────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

// ── Countdown ─────────────────────────────────────────────────────────────────
const hoy = computed(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}` })

const momentosDisponibles = computed(() =>
  momentos.value.filter((m) => fechas.value[m] && fechas.value[m] <= hoy.value && (conteosActividades.value[m] ?? 0) > 0),
)
const momentosFuturos = computed(() =>
  momentos.value.filter((m) => fechas.value[m] && fechas.value[m] > hoy.value && (conteosActividades.value[m] ?? 0) > 0),
)
const proximoMomento = computed(() => momentosFuturos.value[0] ?? null)
const countdown = ref({ dias: 0, horas: 0, minutos: 0, segundos: 0 })

function calcularCountdown() {
  if (!proximoMomento.value) return
  const fechaProx = fechas.value[proximoMomento.value]
  if (!fechaProx) return
  const target = new Date(fechaProx + 'T00:00:00')
  const diff   = target.getTime() - Date.now()
  if (diff <= 0) { cargar(); return }
  const s = Math.floor(diff / 1000)
  countdown.value = {
    dias:     Math.floor(s / 86400),
    horas:    Math.floor((s % 86400) / 3600),
    minutos:  Math.floor((s % 3600) / 60),
    segundos: s % 60,
  }
}

let cdTimer: ReturnType<typeof setInterval> | null = null
watch(proximoMomento, (val) => {
  if (cdTimer) { clearInterval(cdTimer); cdTimer = null }
  if (val) { calcularCountdown(); cdTimer = setInterval(calcularCountdown, 1000) }
}, { immediate: true })
onUnmounted(() => { if (cdTimer) clearInterval(cdTimer) })

const ESTADO_CFG = {
  presente:    { label: 'Presente',    icon: 'pi pi-check',      active: 'ast-eb--presente-act',    idle: 'ast-eb--presente-idle'    },
  ausente:     { label: 'Ausente',     icon: 'pi pi-times',      active: 'ast-eb--ausente-act',     idle: 'ast-eb--ausente-idle'     },
  justificado: { label: 'Justificado', icon: 'pi pi-file-edit',  active: 'ast-eb--justificado-act', idle: 'ast-eb--justificado-idle' },
} as const

// ── Estado global ─────────────────────────────────────────────────────────────
const session   = useSessionStore()
const campStore = useCampamentoStore()
const cargando  = ref(true)
const error     = ref('')

const dias                = ref<DiasEvaluacion[]>([])
const equipos             = ref<Equipo[]>([])
const paso                = ref<1 | 2 | 3>(1)
const momentoActivo       = ref<string>('')
const conteosActividades  = ref<Record<string, number>>({})

// Paso 2
const actividadesDia        = ref<ActividadConProgramacion[]>([])
const cargandoActividades   = ref(false)
const actividadSeleccionada = ref<ActividadConProgramacion | null>(null)

// Paso 3
const equipoActivo        = ref<Equipo | null>(null)
const busqueda            = ref('')
const cargandoRegistros   = ref(false)
const filasPorEquipo      = ref<Map<string, FilaIntegrante[]>>(new Map())
const resumenPorEquipo    = ref<Map<string, AsistenciaEquipoActividad>>(new Map())
const criteriosActividad  = ref<CriterioEval[]>([])
const criteriosPorEquipo  = ref<Map<string, FilaCriterio[]>>(new Map())
const tabEval             = ref<'equipos' | 'criterios'>('equipos')
const equipoEvalActivo    = ref<Equipo | null>(null)
const criterioEvalActivo  = ref<CriterioEval | null>(null)
const filasPorCriterio    = ref<Map<string, FilaEquipoCriterio[]>>(new Map())

// Dialog justificación
const dialogJust    = ref(false)
const filaJust      = ref<FilaIntegrante | null>(null)
const motivoTemp    = ref('')
const documentadoTemp = ref(false)

// ── Carga inicial ──────────────────────────────────────────────────────────────
async function cargar() {
  // Si ya hay datos en memoria y estamos offline → quedarse donde se está
  const yaHayDatos = equipos.value.length > 0 && Object.keys(conteosActividades.value).length > 0
  if (yaHayDatos && !navigator.onLine) return

  cargando.value = true
  error.value    = ''
  paso.value     = 1
  actividadSeleccionada.value = null
  equipoActivo.value = null
  filasPorEquipo.value  = new Map()
  resumenPorEquipo.value = new Map()
  try {
    const [, diasData, equiposData, conteos] = await Promise.all([
      cargarCampamento(),
      cargarDias(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      campStore.selectedId
        ? actividadesService.getConteosPorCampamento(campStore.selectedId)
        : Promise.resolve({} as Record<string, number>),
    ])
    dias.value               = diasData
    equipos.value            = equiposData.filter((e) => e.activo)
    conteosActividades.value = conteos
    // Auto-select today (or first available day)
    const hoyMomento = detectarMomentoActual()
    const list = session.esAdmin
      ? momentos.value.filter(m => (conteos[m] ?? 0) > 0)
      : momentos.value.filter(m => fechas.value[m] && fechas.value[m] <= hoy.value && (conteos[m] ?? 0) > 0)
    if (hoyMomento && (conteos[hoyMomento] ?? 0) > 0) {
      await seleccionarDia(hoyMomento)
    } else if (list.length) {
      await seleccionarDia(list[list.length - 1]!)
    } else {
      momentoActivo.value = session.esAdmin ? '' : hoyMomento
    }
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargarDias(): Promise<DiasEvaluacion[]> {
  if (!campStore.selectedId) return []
  return cachedFetch(`dias_eval_${campStore.selectedId}`, async () => {
    const { supabase } = await import('@/lib/supabase')
    const { data, error: err } = await supabase
      .from('dias_evaluacion').select('*')
      .eq('campamento_id', campStore.selectedId!).order('momento')
    if (err) throw err
    return data ?? []
  }, TTL_1H)
}

// ── Computed ──────────────────────────────────────────────────────────────────
const diaActual = computed<DiasEvaluacion | undefined>(() =>
  dias.value.find((d) => d.momento === momentoActivo.value),
)
const diaCerrado = computed(() => diaActual.value?.cerrado ?? false)

const filasEquipoActual = computed<FilaIntegrante[]>(() =>
  equipoActivo.value ? (filasPorEquipo.value.get(equipoActivo.value.id) ?? []) : [],
)

const filasFiltradas = computed(() => {
  const q = busqueda.value.toLowerCase().trim()
  if (!q) return filasEquipoActual.value
  return filasEquipoActual.value.filter(
    (f) => f.integrante.nombres.toLowerCase().includes(q) ||
           f.integrante.apellidos.toLowerCase().includes(q),
  )
})

const resumenEquipoActual = computed<AsistenciaEquipoActividad | undefined>(() =>
  equipoActivo.value ? resumenPorEquipo.value.get(equipoActivo.value.id) : undefined,
)

const contarPresentes    = computed(() => filasEquipoActual.value.filter((f) => f.estado === 'presente').length)
const contarAusentes     = computed(() => filasEquipoActual.value.filter((f) => f.estado === 'ausente').length)
const contarJustificados = computed(() => filasEquipoActual.value.filter((f) => f.estado === 'justificado').length)
const contarSinRegistro  = computed(() => filasEquipoActual.value.filter((f) => f.estado === null).length)
const totalIntegrantes   = computed(() => filasEquipoActual.value.length)

const pctPresentes = computed(() => {
  const t = totalIntegrantes.value
  return t ? Math.round((contarPresentes.value / t) * 100) : 0
})

const formulaTexto = computed(() => {
  const r   = resumenEquipoActual.value
  if (!r) return null
  const conv = r.convocados_elegibles ?? 0
  if (conv === 0) return 'Sin convocados — reprogramar'
  const res = Math.min(100, (contarPresentes.value / conv / 0.95) * 100)
  return `${contarPresentes.value} / ${conv} / 0.95 × 100 = ${res.toFixed(1)}`
})

function pctCompleto(): number {
  // % integrantes registrados (cualquier estado) en equipo activo
  const t = totalIntegrantes.value
  if (!t) return 0
  return Math.round(((t - contarSinRegistro.value) / t) * 100)
}

const tieneCriterios = computed(() => criteriosActividad.value.length > 0)

// ── Pasos ─────────────────────────────────────────────────────────────────────
async function seleccionarDia(m: string) {
  momentoActivo.value = m
  actividadSeleccionada.value = null
  filasPorEquipo.value  = new Map()
  resumenPorEquipo.value = new Map()
  paso.value = 2
  cargandoActividades.value = true
  try {
    actividadesDia.value = await actividadesService.getPorDia(m)
    // Auto-open if exactly one non-cancelled activity
    const activas = actividadesDia.value.filter(a => a.estado !== 'cancelada')
    if (activas.length === 1) {
      await seleccionarActividad(activas[0]!)
    }
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar actividades'
  } finally {
    cargandoActividades.value = false
  }
}

async function seleccionarActividad(act: ActividadConProgramacion) {
  if (act.estado === 'cancelada') return
  actividadSeleccionada.value = act
  filasPorEquipo.value     = new Map()
  resumenPorEquipo.value   = new Map()
  criteriosPorEquipo.value = new Map()
  filasPorCriterio.value   = new Map()
  tabEval.value            = 'equipos'
  equipoEvalActivo.value   = null
  criterioEvalActivo.value = null
  paso.value = 3

  criteriosActividad.value = await criteriosEvalService.getPorActividad(act.id)
  if (criteriosActividad.value.length) {
    const records = await evalRegistrosService.getPorActividad(act.id, session.user!.id)

    // criteriosPorEquipo: equipo_id → FilaCriterio[]
    const mapEq = new Map<string, FilaCriterio[]>()
    for (const eq of equipos.value) {
      const recMap = new Map(
        records.filter((r) => r.equipo_id === eq.id).map((r) => [r.criterio_eval_id, Number(r.puntaje)])
      )
      mapEq.set(eq.id, criteriosActividad.value.map((c) => ({
        criterio: c,
        puntaje: recMap.has(c.id) ? recMap.get(c.id)! : null,
        estadoGuardado: 'idle' as EstadoGuardado,
      })))
    }
    criteriosPorEquipo.value = mapEq

    // filasPorCriterio: criterio_id → FilaEquipoCriterio[]
    const mapCrit = new Map<string, FilaEquipoCriterio[]>()
    for (const c of criteriosActividad.value) {
      const recMap = new Map(
        records.filter((r) => r.criterio_eval_id === c.id).map((r) => [r.equipo_id, Number(r.puntaje)])
      )
      mapCrit.set(c.id, equipos.value.map((eq) => ({
        equipo: eq,
        puntaje: recMap.has(eq.id) ? recMap.get(eq.id)! : null,
        estadoGuardado: 'idle' as EstadoGuardado,
      })))
    }
    filasPorCriterio.value = mapCrit
  } else {
    // No criteria — load attendance for first team
    const primero = equipos.value[0]
    if (primero) await seleccionarEquipo(primero)
  }
}

function volverPaso(n: 1 | 2) {
  if (n === 1) {
    paso.value = 1
    actividadesDia.value = []
    actividadSeleccionada.value = null
    filasPorEquipo.value     = new Map()
    resumenPorEquipo.value   = new Map()
    criteriosPorEquipo.value = new Map()
    criteriosActividad.value = []
    filasPorCriterio.value   = new Map()
    tabEval.value            = 'equipos'
    equipoEvalActivo.value   = null
    criterioEvalActivo.value = null
    equipoActivo.value       = null
  } else {
    paso.value = 2
    actividadSeleccionada.value = null
    filasPorEquipo.value     = new Map()
    resumenPorEquipo.value   = new Map()
    criteriosPorEquipo.value = new Map()
    criteriosActividad.value = []
    filasPorCriterio.value   = new Map()
    tabEval.value            = 'equipos'
    equipoEvalActivo.value   = null
    criterioEvalActivo.value = null
    equipoActivo.value       = null
  }
}

async function seleccionarEquipo(equipo: Equipo) {
  equipoActivo.value = equipo
  busqueda.value     = ''
  if (filasPorEquipo.value.has(equipo.id)) return

  cargandoRegistros.value = true
  try {
    const [integrantes, registros, resumen] = await Promise.all([
      integrantesAsistenciaService.getPorEquipo(equipo.id),
      actividadSeleccionada.value
        ? asistenciaService.getRegistrosPorActividad(actividadSeleccionada.value.id)
        : Promise.resolve([] as RegistroConIntegrante[]),
      actividadSeleccionada.value
        ? asistenciaService.getResumenPorActividad(actividadSeleccionada.value.id)
        : Promise.resolve([]),
    ])
    for (const r of resumen) resumenPorEquipo.value.set(r.equipo_id, r)
    const regMap = new Map<string, RegistroConIntegrante>()
    for (const reg of registros) {
      if (reg.integrantes?.equipo_id === equipo.id) regMap.set(reg.integrante_id, reg)
    }
    filasPorEquipo.value.set(equipo.id, integrantes.map((ing) => {
      const reg = regMap.get(ing.id)
      return {
        integrante: ing,
        estado:     reg ? (reg.estado as EstadoAsistencia) : null,
        motivo_justificacion: reg?.motivo_justificacion ?? null,
        documentado:          reg?.documentado ?? false,
        estadoGuardado:       'idle',
      }
    }))
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar integrantes'
  } finally {
    cargandoRegistros.value = false
  }
}

// ── Marcado ───────────────────────────────────────────────────────────────────
async function marcarEstado(fila: FilaIntegrante, nuevoEstado: EstadoAsistencia) {
  if (diaCerrado.value) return
  if (nuevoEstado === 'justificado') {
    filaJust.value      = fila
    motivoTemp.value    = fila.motivo_justificacion ?? ''
    documentadoTemp.value = fila.documentado
    dialogJust.value    = true
    return
  }
  await guardarRegistro(fila, nuevoEstado, null, false)
}

async function confirmarJustificado() {
  if (!filaJust.value) return
  await guardarRegistro(filaJust.value, 'justificado', motivoTemp.value.trim() || null, documentadoTemp.value)
  dialogJust.value = false
  filaJust.value   = null
}

async function guardarRegistro(
  fila: FilaIntegrante,
  nuevoEstado: EstadoAsistencia,
  motivo: string | null,
  documentado: boolean,
) {
  if (!actividadSeleccionada.value) return
  const ant = { estado: fila.estado, motivo: fila.motivo_justificacion, doc: fila.documentado }
  fila.estado = nuevoEstado
  fila.motivo_justificacion = motivo
  fila.documentado   = documentado
  fila.estadoGuardado = 'guardando'
  try {
    await asistenciaService.upsert({
      actividad_id:  actividadSeleccionada.value.id,
      integrante_id: fila.integrante.id,
      estado: nuevoEstado, motivo_justificacion: motivo, documentado,
      evaluador_id: session.user!.id,
    })
    fila.estadoGuardado = 'guardado'
    setTimeout(() => { if (fila.estadoGuardado === 'guardado') fila.estadoGuardado = 'idle' }, 2000)
    if (equipoActivo.value) {
      const resumen = await asistenciaService.getResumenPorActividad(actividadSeleccionada.value.id)
      for (const r of resumen) resumenPorEquipo.value.set(r.equipo_id, r)
    }
  } catch {
    fila.estado = ant.estado; fila.motivo_justificacion = ant.motivo; fila.documentado = ant.doc
    fila.estadoGuardado = 'error'
  }
}

async function todosPresentes() {
  if (diaCerrado.value || !equipoActivo.value) return
  for (const fila of filasEquipoActual.value.filter((f) => f.estado === null)) {
    await guardarRegistro(fila, 'presente', null, false)
  }
}

// ── Evaluación por criterios ──────────────────────────────────────────────────
/** Genera pasos de 5 desde 0 hasta puntaje_max (inclusive). */
function stepsCriterio(puntajeMax: number | string): number[] {
  const max = Number(puntajeMax)
  const steps: number[] = []
  for (let i = 0; i <= max; i += 5) steps.push(i)
  if (steps[steps.length - 1] !== max) steps.push(max)
  return steps
}

/** Devuelve clases CSS idle/active para el botón según su posición relativa al máximo. */
function colorCritBtn(pts: number, max: number): { idle: string; active: string } {
  if (pts === 0)   return { idle: 'crit-btn--0-idle',    active: 'crit-btn--0-act'    }
  if (pts === max) return { idle: 'crit-btn--max-idle',  active: 'crit-btn--max-act'  }
  const pct = pts / max
  if (pct <= 0.33) return { idle: 'crit-btn--low-idle',  active: 'crit-btn--low-act'  }
  if (pct <= 0.66) return { idle: 'crit-btn--mid-idle',  active: 'crit-btn--mid-act'  }
  return              { idle: 'crit-btn--high-idle', active: 'crit-btn--high-act' }
}

async function guardarEval(
  criterioId: string,
  equipoId: string,
  puntaje: number,
  filaRef: { estadoGuardado: EstadoGuardado },
) {
  if (!actividadSeleccionada.value) return
  filaRef.estadoGuardado = 'guardando'
  try {
    await evalRegistrosService.upsert({
      actividad_id:     actividadSeleccionada.value.id,
      criterio_eval_id: criterioId,
      equipo_id:        equipoId,
      puntaje,
      evaluador_id:     session.user!.id,
    })
    filaRef.estadoGuardado = 'guardado'
    setTimeout(() => { if (filaRef.estadoGuardado === 'guardado') filaRef.estadoGuardado = 'idle' }, 2000)
    // Sync criteriosPorEquipo
    const cf = criteriosPorEquipo.value.get(equipoId)?.find((f) => f.criterio.id === criterioId)
    if (cf) cf.puntaje = puntaje
    // Sync filasPorCriterio
    const ef = filasPorCriterio.value.get(criterioId)?.find((f) => f.equipo.id === equipoId)
    if (ef) ef.puntaje = puntaje
  } catch {
    filaRef.estadoGuardado = 'error'
  }
}

function progresoEquipoEval(equipoId: string) {
  const filas = criteriosPorEquipo.value.get(equipoId) ?? []
  return { calificados: filas.filter((f) => f.puntaje !== null).length, total: filas.length }
}

function progresoCriterioEval(criterioId: string) {
  const filas = filasPorCriterio.value.get(criterioId) ?? []
  return { calificados: filas.filter((f) => f.puntaje !== null).length, total: filas.length }
}

function pctBarEval(calificados: number, total: number) {
  return total === 0 ? 0 : Math.round((calificados / total) * 100)
}

// ── Nuevos helpers para rediseño ──────────────────────────────────────────────
const momentoList = computed(() =>
  session.esAdmin
    ? momentos.value.filter(m => (conteosActividades.value[m] ?? 0) > 0)
    : momentosDisponibles.value
)

const totalMaxActividad = computed(() =>
  criteriosActividad.value.reduce((s, c) => s + Number(c.puntaje_max), 0)
)

function subtotalEquipo(equipoId: string): number {
  return (criteriosPorEquipo.value.get(equipoId) ?? []).reduce((s, f) => s + (f.puntaje ?? 0), 0)
}

const notasDoneActual = computed(() => {
  let done = 0
  for (const eq of equipos.value) {
    done += (criteriosPorEquipo.value.get(eq.id) ?? []).filter(f => f.puntaje !== null).length
  }
  return done
})

const notasTotalActual = computed(() =>
  equipos.value.length * criteriosActividad.value.length
)

const equipoIdx = computed(() =>
  equipoEvalActivo.value ? equipos.value.findIndex(e => e.id === equipoEvalActivo.value!.id) : -1
)

function iniciales(nombre: string): string {
  return nombre.split(' ').filter(Boolean).slice(0, 2).map(w => (w[0] ?? '').toUpperCase()).join('')
}

function labelDiaCorto(m: string): string {
  const label = labelDia(m)
  const parts = label.split(' ')
  return parts.length >= 2 ? (parts[0] ?? '').slice(0, 3) + ' ' + (parts[1] ?? '') : label
}

function extraDia(m: string): string {
  const f = fechas.value[m]
  const isHoy = f === hoy.value
  const count = conteosActividades.value[m] ?? 0
  const parts: string[] = []
  if (isHoy) parts.push('Hoy')
  parts.push(count === 1 ? '1 act.' : count > 1 ? `${count} act.` : 'Sin act.')
  return parts.join(' · ')
}

function statusChipCls(calificados: number, total: number): string {
  if (total > 0 && calificados === total) return 'bg-[#E1F3EA] text-[#0B6B4B]'
  if (calificados > 0) return 'bg-[#FFF1D6] text-[#7A4F00]'
  return 'bg-[#EEF0EE] text-[#4A544F]'
}

function statusChipText(calificados: number, total: number): string {
  if (total > 0 && calificados === total) return 'Completo'
  if (calificados > 0) return 'En curso'
  return 'Sin empezar'
}

function statusActConfig(estado: string | null) {
  if (estado === 'realizada') return { text: 'Realizada', cls: 'bg-[#E1F3EA] text-[#0B6B4B]' }
  if (estado === 'cancelada') return { text: 'Cancelada', cls: 'bg-[#FFE4E4] text-[#9B1C1C]' }
  return { text: 'Programada', cls: 'bg-[#EEF0EE] text-[#4A544F]' }
}

function volverAActividades() {
  actividadSeleccionada.value = null
  criteriosPorEquipo.value = new Map()
  criteriosActividad.value = []
  filasPorCriterio.value = new Map()
  tabEval.value = 'equipos'
  equipoEvalActivo.value = null
  criterioEvalActivo.value = null
  equipoActivo.value = null
}

function volverAEquipos() {
  equipoEvalActivo.value = null
  criterioEvalActivo.value = null
}

function navEquipo(dir: 1 | -1) {
  const idx = equipoIdx.value
  if (idx < 0) return
  const next = equipos.value[idx + dir]
  if (next) equipoEvalActivo.value = next
}

// ── CSS helpers ───────────────────────────────────────────────────────────────
function filaClass(fila: FilaIntegrante) {
  if (fila.estado === 'presente')    return 'ast-fila--presente'
  if (fila.estado === 'ausente')     return 'ast-fila--ausente'
  if (fila.estado === 'justificado') return 'ast-fila--justificado'
  return ''
}
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden bg-[#F4F6F4]" style="font-family: Inter, system-ui, sans-serif">

    <!-- Loading -->
    <div v-if="cargando" class="flex-1 flex flex-col items-center justify-center gap-3 text-[#5B6660]">
      <svg class="animate-spin h-6 w-6 text-[#0E7C59]" viewBox="0 0 24 24" fill="none"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/></svg>
      <span class="text-[14px]">Cargando…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="flex-1 flex flex-col items-center justify-center gap-4 p-6">
      <p class="text-[15px] text-[#16201B] text-center">{{ error }}</p>
      <button @click="cargar" class="h-10 px-5 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit]">Reintentar</button>
    </div>

    <!-- Sin dias disponibles -->
    <div v-else-if="momentosDisponibles.length === 0 && !session.esAdmin" class="flex-1 flex flex-col items-center justify-center gap-6 p-8 text-center">
      <div class="text-5xl">⛺</div>
      <div>
        <h2 class="text-[20px] font-bold text-[#16201B] mb-1">Las actividades comenzarán pronto</h2>
        <p v-if="proximoMomento" class="text-[14px] text-[#5B6660]">Próximo día: <strong>{{ labelDia(proximoMomento) }}</strong></p>
      </div>
      <div v-if="proximoMomento" class="flex gap-6">
        <div class="flex flex-col items-center"><span class="text-[28px] font-bold tabular-nums text-[#0E7C59]">{{ String(countdown.dias).padStart(2,'0') }}</span><span class="text-[11px] text-[#5B6660] uppercase">días</span></div>
        <div class="flex flex-col items-center"><span class="text-[28px] font-bold tabular-nums text-[#0E7C59]">{{ String(countdown.horas).padStart(2,'0') }}</span><span class="text-[11px] text-[#5B6660] uppercase">horas</span></div>
        <div class="flex flex-col items-center"><span class="text-[28px] font-bold tabular-nums text-[#0E7C59]">{{ String(countdown.minutos).padStart(2,'0') }}</span><span class="text-[11px] text-[#5B6660] uppercase">min</span></div>
        <div class="flex flex-col items-center"><span class="text-[28px] font-bold tabular-nums text-[#0E7C59]">{{ String(countdown.segundos).padStart(2,'0') }}</span><span class="text-[11px] text-[#5B6660] uppercase">seg</span></div>
      </div>
    </div>

    <!-- Contenido principal -->
    <template v-else>

      <!-- TABLET / DESKTOP top bar (hidden <md) -->
      <div class="hidden md:block bg-white border-b border-[#E3E7E4] flex-shrink-0">
        <div class="flex items-center gap-2 px-4 py-3 overflow-x-auto">
          <button
            v-for="m in momentoList"
            :key="m"
            @click="seleccionarDia(m)"
            class="flex-shrink-0 h-10 px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors whitespace-nowrap font-[inherit]"
            :class="momentoActivo === m
              ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
              : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
          >
            {{ labelDiaCorto(m) }}
            <template v-if="fechas[m] === hoy"> · Hoy</template>
            <template v-if="conteosActividades[m]"> · {{ conteosActividades[m] }} act.</template>
            <span v-if="dias.find(d => d.momento === m)?.cerrado" class="ml-1 opacity-60">🔒</span>
          </button>
        </div>
        <!-- Tablet only: activity picker + mode tabs -->
        <div v-if="momentoActivo" class="xl:hidden flex items-center gap-3 px-4 pb-3">
          <div class="flex-1">
            <ActivityPicker
              :actividades="actividadesDia"
              :selected="actividadSeleccionada"
              :loading="cargandoActividades"
              @select="seleccionarActividad"
            />
          </div>
          <ModeTabs
            v-if="actividadSeleccionada && tieneCriterios"
            :activo="tabEval"
            @change="tabEval = $event"
          />
        </div>
      </div>

      <!-- MOBILE SCREEN 1 header: title + day grid -->
      <div
        class="md:hidden bg-white border-b border-[#E3E7E4] px-4 pt-3 flex flex-col gap-3.5 flex-shrink-0"
        v-show="!actividadSeleccionada"
      >
        <div class="flex items-center justify-between h-11">
          <span class="text-[17px] font-bold text-[#16201B]">Actividades</span>
          <span class="text-[12px] text-[#5B6660]">Evaluación</span>
        </div>
        <div class="grid gap-2 pb-3" :style="{ gridTemplateColumns: `repeat(${Math.min(momentoList.length, 3)}, minmax(0, 1fr))` }">
          <button
            v-for="m in momentoList"
            :key="m"
            @click="seleccionarDia(m)"
            class="h-[52px] rounded-xl border flex flex-col items-center justify-center gap-0.5 transition-colors font-[inherit]"
            :class="momentoActivo === m
              ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
              : 'bg-white text-[#16201B] border-[#DCE1DD]'"
          >
            <span class="text-[13px] font-semibold">{{ labelDiaCorto(m) }}</span>
            <span class="text-[11px]">{{ extraDia(m) }}</span>
          </button>
        </div>
      </div>

      <!-- MOBILE SCREEN 2 header: activity nav -->
      <div
        class="md:hidden bg-white border-b border-[#E3E7E4] px-4 pt-3 flex flex-col gap-3 flex-shrink-0"
        v-show="actividadSeleccionada && !equipoEvalActivo && !criterioEvalActivo"
      >
        <div class="flex items-center gap-2 min-h-[44px]">
          <button @click="volverAActividades" aria-label="Volver a actividades" class="w-11 h-11 -ml-2 rounded-xl flex items-center justify-center flex-shrink-0">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#16201B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg>
          </button>
          <div class="flex-1 min-w-0">
            <div class="text-[11px] font-bold uppercase tracking-[0.6px] text-[#5B6660]">{{ labelDiaCorto(momentoActivo) }} · {{ actividadSeleccionada?.hora_inicio?.slice(0,5) }}</div>
            <div class="text-[17px] font-bold truncate text-[#16201B]">{{ actividadSeleccionada?.nombre }}</div>
          </div>
          <span v-if="actividadSeleccionada" class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0" :class="statusActConfig(actividadSeleccionada.estado).cls">{{ statusActConfig(actividadSeleccionada.estado).text }}</span>
        </div>
        <div class="flex items-center gap-2.5">
          <div class="flex-1 h-1.5 bg-[#E3E7E4] rounded overflow-hidden">
            <div class="h-1.5 bg-[#0E7C59] rounded transition-all" :style="{ width: (notasTotalActual > 0 ? Math.round(notasDoneActual / notasTotalActual * 100) : 0) + '%' }" />
          </div>
          <span class="text-[12px] text-[#5B6660] flex-shrink-0">{{ notasDoneActual }} de {{ notasTotalActual }} notas</span>
        </div>
        <div v-if="tieneCriterios" role="tablist" class="flex gap-6">
          <button role="tab" :aria-selected="tabEval === 'equipos'" @click="tabEval = 'equipos'" class="pb-3 border-0 bg-transparent font-[inherit] text-[14px] cursor-pointer" :class="tabEval === 'equipos' ? 'text-[#0E7C59] font-semibold shadow-[inset_0_-2px_0_#0E7C59]' : 'text-[#5B6660] font-medium'">Por equipo</button>
          <button role="tab" :aria-selected="tabEval === 'criterios'" @click="tabEval = 'criterios'" class="pb-3 border-0 bg-transparent font-[inherit] text-[14px] cursor-pointer" :class="tabEval === 'criterios' ? 'text-[#0E7C59] font-semibold shadow-[inset_0_-2px_0_#0E7C59]' : 'text-[#5B6660] font-medium'">Por criterio</button>
        </div>
      </div>

      <!-- MOBILE SCREEN 3 header: team scoring -->
      <div
        class="md:hidden bg-white border-b border-[#E3E7E4] px-4 pt-3 pb-3.5 flex flex-col gap-3 flex-shrink-0"
        v-show="actividadSeleccionada && (equipoEvalActivo || criterioEvalActivo)"
      >
        <div class="flex items-center gap-2 min-h-[44px]">
          <button @click="volverAEquipos" aria-label="Volver a lista" class="w-11 h-11 -ml-2 rounded-xl flex items-center justify-center flex-shrink-0">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#16201B" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg>
          </button>
          <template v-if="equipoEvalActivo">
            <span class="w-9 h-9 rounded-[10px] flex items-center justify-center font-bold text-[13px] text-white flex-shrink-0" :style="{ background: equipoEvalActivo.color }" aria-hidden="true">{{ iniciales(equipoEvalActivo.nombre) }}</span>
            <div class="flex-1 min-w-0">
              <div class="text-[17px] font-bold truncate">{{ equipoEvalActivo.nombre }}</div>
              <div class="text-[12px] text-[#5B6660] truncate">{{ actividadSeleccionada?.nombre }}</div>
            </div>
            <div class="flex flex-col items-end flex-shrink-0">
              <span class="text-[16px] font-bold">{{ subtotalEquipo(equipoEvalActivo.id) }}<span class="text-[12px] font-medium text-[#5B6660]">/{{ totalMaxActividad }}</span></span>
              <span class="text-[11px] text-[#5B6660]">{{ progresoEquipoEval(equipoEvalActivo.id).calificados }} de {{ progresoEquipoEval(equipoEvalActivo.id).total }}</span>
            </div>
          </template>
          <template v-else-if="criterioEvalActivo">
            <div class="flex-1 min-w-0">
              <div class="text-[17px] font-bold truncate">{{ criterioEvalActivo.nombre }}</div>
              <div class="text-[12px] text-[#5B6660]">máx. {{ criterioEvalActivo.puntaje_max }} pts</div>
            </div>
          </template>
        </div>
        <div class="h-1.5 bg-[#E3E7E4] rounded overflow-hidden">
          <div class="h-1.5 bg-[#0E7C59] rounded transition-all" :style="{ width: (equipoEvalActivo ? pctBarEval(progresoEquipoEval(equipoEvalActivo.id).calificados, progresoEquipoEval(equipoEvalActivo.id).total) : 0) + '%' }" />
        </div>
      </div>

      <!-- MAIN CONTENT AREA -->
      <div class="flex flex-1 overflow-hidden">

        <!-- ACTIVITY LIST panel: xl+ always, mobile only when no activity, tablet hidden -->
        <div
          class="border-r border-[#E3E7E4] bg-white overflow-y-auto flex-col xl:w-[280px] xl:flex-shrink-0"
          :class="!actividadSeleccionada ? 'flex md:hidden xl:flex' : 'hidden xl:flex'"
        >
          <div class="p-4 flex flex-col gap-3">
            <div v-if="momentoActivo" class="hidden xl:block mx-0.5 text-[12px] font-bold uppercase tracking-[0.6px] text-[#5B6660]">
              {{ labelDia(momentoActivo) }}
            </div>
            <template v-if="cargandoActividades">
              <div v-for="i in 3" :key="i" class="bg-[#F4F6F4] rounded-2xl h-20 animate-pulse" />
            </template>
            <template v-else-if="actividadesDia.length">
              <ActivityCard
                v-for="act in actividadesDia"
                :key="act.id"
                :actividad="act"
                :notas-done="actividadSeleccionada?.id === act.id ? notasDoneActual : 0"
                :notas-total="actividadSeleccionada?.id === act.id ? notasTotalActual : 0"
                :active="actividadSeleccionada?.id === act.id"
                @click="act.estado !== 'cancelada' && seleccionarActividad(act)"
              />
            </template>
            <div v-else-if="momentoActivo" class="border border-dashed border-[#DCE1DD] rounded-2xl p-4 text-[13px] text-[#5B6660] text-center">No hay actividades este día</div>
            <div v-else class="border border-dashed border-[#DCE1DD] rounded-2xl p-4 text-[13px] text-[#5B6660] text-center">Selecciona un día</div>
          </div>
        </div>

        <!-- TEAMS / CRITERIA LIST panel: md+ always, mobile when activity selected no detail -->
        <div
          class="border-r border-[#E3E7E4] bg-white overflow-y-auto flex-col md:w-[300px] md:flex-shrink-0"
          :class="actividadSeleccionada && !equipoEvalActivo && !criterioEvalActivo
            ? 'flex'
            : 'hidden md:flex'"
        >
          <template v-if="!actividadSeleccionada && !cargandoActividades">
            <div class="flex-1 flex flex-col items-center justify-center gap-2 p-6 text-center text-[13px] text-[#5B6660]">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#DCE1DD" stroke-width="1.5"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>
              <span>Selecciona una actividad</span>
            </div>
          </template>
          <template v-else-if="cargandoActividades">
            <div class="p-3 flex flex-col gap-2">
              <div v-for="i in 5" :key="i" class="h-14 bg-[#F4F6F4] rounded-xl animate-pulse" />
            </div>
          </template>
          <template v-else-if="actividadSeleccionada">
            <div v-if="tieneCriterios" class="hidden md:flex items-center px-3 pt-3 pb-2">
              <ModeTabs :activo="tabEval" @change="tabEval = $event" />
            </div>
            <div v-if="diaCerrado" class="mx-3 mb-2 mt-1 flex items-center gap-2 px-3 py-2 bg-[#FFF1D6] text-[#7A4F00] rounded-xl text-[12px] font-medium">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              Solo lectura — día cerrado
            </div>
            <template v-if="tieneCriterios">
              <ul v-if="tabEval === 'equipos'" class="list-none m-0 p-3 flex flex-col gap-1">
                <li v-for="eq in equipos" :key="eq.id">
                  <TeamRow
                    :equipo="eq"
                    :progreso="progresoEquipoEval(eq.id)"
                    :active="equipoEvalActivo?.id === eq.id"
                    @click="equipoEvalActivo = eq; criterioEvalActivo = null"
                  />
                </li>
              </ul>
              <ul v-else class="list-none m-0 p-3 flex flex-col gap-1">
                <li v-for="c in criteriosActividad" :key="c.id">
                  <CriterioRow
                    :nombre="c.nombre"
                    :done="progresoCriterioEval(c.id).calificados"
                    :total="progresoCriterioEval(c.id).total"
                    :max="Number(c.puntaje_max)"
                    :active="criterioEvalActivo?.id === c.id"
                    @click="criterioEvalActivo = c; equipoEvalActivo = null"
                  />
                </li>
              </ul>
            </template>
            <template v-else>
              <div class="p-3 flex flex-wrap gap-2">
                <button
                  v-for="eq in equipos"
                  :key="eq.id"
                  @click="seleccionarEquipo(eq)"
                  class="flex items-center gap-1.5 h-9 px-3 rounded-xl text-[13px] font-medium border transition-colors font-[inherit]"
                  :class="equipoActivo?.id === eq.id ? 'border-[#0E7C59] text-[#0E7C59] bg-[#E1F3EA]' : 'border-[#DCE1DD] text-[#16201B] bg-white hover:bg-[#F4F6F4]'"
                >
                  <span class="w-4 h-4 rounded-full flex-shrink-0" :style="{ background: eq.color }" />{{ eq.nombre }}
                </button>
              </div>
            </template>
          </template>
        </div>

        <!-- SCORE / ATTENDANCE panel: md+ always, mobile when detail open -->
        <div
          class="flex-1 overflow-y-auto flex-col md:flex"
          :class="equipoEvalActivo || criterioEvalActivo || (!tieneCriterios && equipoActivo) ? 'flex' : 'hidden'"
        >

          <!-- Placeholder -->
          <div
            v-if="!equipoEvalActivo && !criterioEvalActivo && !equipoActivo"
            class="flex-1 flex flex-col items-center justify-center gap-2 p-8 text-center text-[13px] text-[#5B6660]"
          >
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#DCE1DD" stroke-width="1.5"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            <span>Selecciona un equipo o criterio</span>
          </div>

          <!-- EVAL por equipo -->
          <template v-else-if="tieneCriterios && equipoEvalActivo">
            <div class="hidden md:flex items-center gap-3 px-5 pt-5 pb-4">
              <span class="w-11 h-11 rounded-xl flex items-center justify-center font-bold text-[14px] text-white flex-shrink-0" :style="{ background: equipoEvalActivo.color }">{{ iniciales(equipoEvalActivo.nombre) }}</span>
              <div class="flex-1 min-w-0">
                <div class="text-[22px] font-bold text-[#16201B]">{{ equipoEvalActivo.nombre }}</div>
                <div class="text-[13px] text-[#5B6660]">{{ actividadSeleccionada?.nombre }}</div>
              </div>
              <div class="flex flex-col items-end">
                <span class="text-[20px] font-bold">{{ subtotalEquipo(equipoEvalActivo.id) }}<span class="text-[14px] font-medium text-[#5B6660]">/{{ totalMaxActividad }}</span></span>
                <span class="text-[12px] text-[#5B6660]">{{ progresoEquipoEval(equipoEvalActivo.id).calificados }} de {{ progresoEquipoEval(equipoEvalActivo.id).total }}</span>
              </div>
            </div>
            <div class="p-4 md:px-5 md:pb-5 md:pt-0 grid gap-3" style="grid-template-columns: repeat(auto-fill, minmax(260px, 1fr))">
              <article
                v-for="fila in (criteriosPorEquipo.get(equipoEvalActivo.id) ?? [])"
                :key="fila.criterio.id"
                class="bg-white border border-[#E3E7E4] rounded-2xl p-3.5 flex flex-col gap-3"
              >
                <div class="flex items-center gap-2">
                  <span class="flex-1 text-[15px] font-semibold text-[#16201B]">{{ fila.criterio.nombre }}</span>
                  <span v-if="fila.estadoGuardado === 'guardando'" class="w-4 h-4 border-2 border-[#0E7C59] border-t-transparent rounded-full animate-spin" />
                  <svg v-else-if="fila.estadoGuardado === 'guardado'" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#0E7C59" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
                  <svg v-else-if="fila.estadoGuardado === 'error'" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#EF4444" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px]" :class="fila.puntaje !== null ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#EEF0EE] text-[#4A544F]'">{{ fila.puntaje !== null ? 'Guardado' : 'Pendiente' }}</span>
                </div>
                <ScoreStepper
                  :max="Number(fila.criterio.puntaje_max)"
                  :value="fila.puntaje"
                  :disabled="diaCerrado"
                  @update="(v) => { fila.puntaje = v; guardarEval(fila.criterio.id, equipoEvalActivo!.id, v, fila) }"
                />
              </article>
            </div>
            <!-- Mobile footer nav -->
            <div class="md:hidden mt-auto bg-white border-t border-[#E3E7E4] px-4 py-3 pb-5 flex gap-2.5 flex-shrink-0">
              <button @click="navEquipo(-1)" :disabled="equipoIdx <= 0" class="h-[50px] px-4 rounded-[14px] border border-[#DCE1DD] text-[15px] font-semibold disabled:opacity-40 font-[inherit]">Anterior</button>
              <button v-if="equipoIdx < equipos.length - 1" @click="navEquipo(1)" class="flex-1 h-[50px] rounded-[14px] bg-[#0E7C59] text-white text-[15px] font-semibold flex items-center justify-center gap-2 font-[inherit]">
                Siguiente: {{ equipos[equipoIdx + 1]?.nombre }}
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
              </button>
              <button v-else @click="volverAEquipos" class="flex-1 h-[50px] rounded-[14px] bg-[#0E7C59] text-white text-[15px] font-semibold flex items-center justify-center gap-2 font-[inherit]">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                Finalizar
              </button>
            </div>
          </template>

          <!-- EVAL por criterio -->
          <template v-else-if="tieneCriterios && criterioEvalActivo">
            <div class="hidden md:flex items-center px-5 pt-5 pb-4">
              <div class="flex-1">
                <div class="text-[22px] font-bold text-[#16201B]">{{ criterioEvalActivo.nombre }}</div>
                <div class="text-[13px] text-[#5B6660]">máx. {{ criterioEvalActivo.puntaje_max }} pts · {{ progresoCriterioEval(criterioEvalActivo.id).calificados }}/{{ equipos.length }} equipos</div>
              </div>
            </div>
            <div class="p-4 md:px-5 md:pb-5 md:pt-0 grid gap-3" style="grid-template-columns: repeat(auto-fill, minmax(260px, 1fr))">
              <article
                v-for="fila in (filasPorCriterio.get(criterioEvalActivo.id) ?? [])"
                :key="fila.equipo.id"
                class="bg-white border border-[#E3E7E4] rounded-2xl p-3.5 flex flex-col gap-3"
              >
                <div class="flex items-center gap-2">
                  <span class="w-7 h-7 rounded-lg flex items-center justify-center font-bold text-[11px] text-white flex-shrink-0" :style="{ background: fila.equipo.color }">{{ iniciales(fila.equipo.nombre) }}</span>
                  <span class="flex-1 text-[15px] font-semibold text-[#16201B]">{{ fila.equipo.nombre }}</span>
                  <span v-if="fila.estadoGuardado === 'guardando'" class="w-4 h-4 border-2 border-[#0E7C59] border-t-transparent rounded-full animate-spin" />
                  <svg v-else-if="fila.estadoGuardado === 'guardado'" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#0E7C59" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
                  <svg v-else-if="fila.estadoGuardado === 'error'" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#EF4444" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px]" :class="fila.puntaje !== null ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#EEF0EE] text-[#4A544F]'">{{ fila.puntaje !== null ? 'Guardado' : 'Pendiente' }}</span>
                </div>
                <ScoreStepper
                  :max="Number(criterioEvalActivo.puntaje_max)"
                  :value="fila.puntaje"
                  :disabled="diaCerrado"
                  @update="(v) => { fila.puntaje = v; guardarEval(criterioEvalActivo!.id, fila.equipo.id, v, fila) }"
                />
              </article>
            </div>
          </template>

          <!-- ASISTENCIA (sin criterios) -->
          <template v-else-if="!tieneCriterios">
            <template v-if="equipoActivo">
              <div class="bg-white border-b border-[#E3E7E4] px-4 py-3 flex flex-col gap-2 flex-shrink-0">
                <div class="h-1.5 bg-[#E3E7E4] rounded overflow-hidden"><div class="h-1.5 bg-[#0E7C59] rounded" :style="{ width: pctCompleto() + '%' }" /></div>
                <div class="flex gap-4">
                  <div class="flex flex-col items-center"><span class="text-[16px] font-bold text-[#0E7C59]">{{ contarPresentes }}</span><span class="text-[11px] text-[#5B6660]">Presentes</span></div>
                  <div class="flex flex-col items-center"><span class="text-[16px] font-bold text-[#EF4444]">{{ contarAusentes }}</span><span class="text-[11px] text-[#5B6660]">Ausentes</span></div>
                  <div class="flex flex-col items-center"><span class="text-[16px] font-bold text-[#F59E0B]">{{ contarJustificados }}</span><span class="text-[11px] text-[#5B6660]">Just.</span></div>
                  <div class="flex flex-col items-center"><span class="text-[16px] font-bold text-[#5B6660]">{{ contarSinRegistro }}</span><span class="text-[11px] text-[#5B6660]">Pend.</span></div>
                  <div v-if="formulaTexto" class="flex-1 text-[11px] text-[#5B6660] self-center ml-2">{{ formulaTexto }}</div>
                </div>
              </div>
              <div class="px-4 py-2.5 flex items-center gap-2 border-b border-[#E3E7E4] bg-white flex-shrink-0">
                <div class="flex-1 relative">
                  <svg class="absolute left-3 top-1/2 -translate-y-1/2 text-[#8A948E]" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.3-4.3"/></svg>
                  <input v-model="busqueda" type="search" placeholder="Buscar integrante…" class="w-full h-9 pl-8 pr-3 text-[13px] rounded-xl border border-[#DCE1DD] bg-[#F4F6F4] outline-none focus:border-[#0E7C59]" />
                </div>
                <button @click="todosPresentes" :disabled="diaCerrado || contarSinRegistro === 0" class="h-9 px-3 rounded-xl border border-[#DCE1DD] bg-white text-[13px] font-medium text-[#16201B] flex items-center gap-1.5 disabled:opacity-40 font-[inherit]">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                  Todos presentes
                </button>
              </div>
              <div v-if="cargandoRegistros" class="flex-1 flex items-center justify-center">
                <svg class="animate-spin h-5 w-5 text-[#0E7C59]" viewBox="0 0 24 24" fill="none"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/></svg>
              </div>
              <div v-else-if="filasFiltradas.length" class="flex-1 overflow-y-auto">
                <div
                  v-for="fila in filasFiltradas"
                  :key="fila.integrante.id"
                  class="border-b border-[#EEF1EF] last:border-0 px-4 py-3"
                  :class="{ 'bg-[#F0FBF5]': fila.estado === 'presente', 'bg-[#FEF2F2]': fila.estado === 'ausente', 'bg-[#FFFBEB]': fila.estado === 'justificado' }"
                >
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-[14px] font-semibold text-[#16201B]">{{ fila.integrante.apellidos }}, {{ fila.integrante.nombres }}</span>
                    <span v-if="fila.estadoGuardado === 'guardando'" class="w-4 h-4 border-2 border-[#0E7C59] border-t-transparent rounded-full animate-spin inline-block" />
                    <svg v-else-if="fila.estadoGuardado === 'guardado'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#0E7C59" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
                  </div>
                  <div class="flex gap-2">
                    <button
                      v-for="(cfg, key) in ESTADO_CFG"
                      :key="key"
                      @click="marcarEstado(fila, key as any)"
                      :disabled="diaCerrado"
                      class="flex-1 h-9 rounded-xl border text-[12px] font-medium flex items-center justify-center gap-1 transition-colors disabled:opacity-40 font-[inherit]"
                      :class="fila.estado === key ? 'bg-[#0E7C59] text-white border-[#0E7C59]' : 'bg-white text-[#5B6660] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
                    >{{ cfg.label }}</button>
                  </div>
                </div>
              </div>
              <div v-else class="flex-1 flex flex-col items-center justify-center gap-2 text-[13px] text-[#5B6660]"><p>No hay integrantes</p></div>
            </template>
            <div v-else class="flex-1 flex flex-col items-center justify-center gap-2 text-[13px] text-[#5B6660]">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#DCE1DD" stroke-width="1.5"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
              <span>Selecciona un equipo</span>
            </div>
          </template>

        </div><!-- /score panel -->
      </div><!-- /main content area -->

    </template><!-- /main content -->

    <!-- Dialog Justificacion -->
    <Dialog v-model:visible="dialogJust" header="Justificación" modal :style="{ width: 'min(26rem, 95vw)' }">
      <p class="text-[14px] text-[#16201B] mb-3">Motivo para <strong>{{ filaJust?.integrante.apellidos }}, {{ filaJust?.integrante.nombres }}</strong>:</p>
      <Textarea v-model="motivoTemp" rows="3" class="w-full" placeholder="Ej: Enfermedad con certificado médico…" autofocus />
      <label class="flex items-center gap-2 mt-3 text-[14px] text-[#16201B] cursor-pointer select-none">
        <input v-model="documentadoTemp" type="checkbox" class="w-4 h-4 rounded" />
        Justificación documentada
      </label>
      <template #footer>
        <div class="flex justify-end gap-2">
          <button class="h-10 px-4 rounded-xl border border-[#DCE1DD] text-[14px] font-medium font-[inherit]" @click="dialogJust = false">Cancelar</button>
          <button class="h-10 px-4 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit]" @click="confirmarJustificado">Confirmar</button>
        </div>
      </template>
    </Dialog>

  </div>
</template>
