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
    momentoActivo.value      = session.esAdmin ? '' : detectarMomentoActual()
    dias.value               = diasData
    equipos.value            = equiposData.filter((e) => e.activo)
    conteosActividades.value = conteos
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
  const { supabase } = await import('@/lib/supabase')
  const { data, error: err } = await supabase
    .from('dias_evaluacion').select('*')
    .eq('campamento_id', campStore.selectedId).order('momento')
  if (err) throw err
  return data ?? []
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
    const records = await evalRegistrosService.getPorActividad(act.id)

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

// ── CSS helpers ───────────────────────────────────────────────────────────────
function filaClass(fila: FilaIntegrante) {
  if (fila.estado === 'presente')    return 'ast-fila--presente'
  if (fila.estado === 'ausente')     return 'ast-fila--ausente'
  if (fila.estado === 'justificado') return 'ast-fila--justificado'
  return ''
}
</script>

<template>
  <div class="ast">

    <!-- Loading -->
    <div v-if="cargando" class="ast-loading">
      <div class="ast-loading__ring" />
      <p>Cargando…</p>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="ast-error">
      <i class="pi pi-exclamation-circle" />
      <p>{{ error }}</p>
    </div>

    <template v-else>

      <!-- ══════════════════════════════════════════════
           SIN DÍAS DISPONIBLES AÚN — pantalla de espera
      ══════════════════════════════════════════════ -->
      <div v-if="momentosDisponibles.length === 0 && !session.esAdmin" class="ast-espera">

        <!-- Icono animado -->
        <div class="ast-espera__icon-wrap">
          <span class="ast-espera__icon">⛺</span>
        </div>

        <!-- Título -->
        <div class="ast-espera__copy">
          <h2 class="ast-espera__titulo">Las actividades comenzarán pronto</h2>
          <p v-if="proximoMomento" class="ast-espera__sub">
            Próximo día de asistencia
          </p>
          <p v-if="proximoMomento" class="ast-espera__next-day">
            {{ labelDia(proximoMomento) }}
          </p>
        </div>

        <!-- Countdown -->
        <div v-if="proximoMomento" class="ast-espera__countdown">
          <div class="ast-cd-bloque">
            <span class="ast-cd-num">{{ String(countdown.dias).padStart(2,'0') }}</span>
            <span class="ast-cd-label">días</span>
          </div>
          <span class="ast-cd-sep">:</span>
          <div class="ast-cd-bloque">
            <span class="ast-cd-num">{{ String(countdown.horas).padStart(2,'0') }}</span>
            <span class="ast-cd-label">horas</span>
          </div>
          <span class="ast-cd-sep">:</span>
          <div class="ast-cd-bloque">
            <span class="ast-cd-num">{{ String(countdown.minutos).padStart(2,'0') }}</span>
            <span class="ast-cd-label">min</span>
          </div>
          <span class="ast-cd-sep">:</span>
          <div class="ast-cd-bloque ast-cd-seg">
            <span class="ast-cd-num">{{ String(countdown.segundos).padStart(2,'0') }}</span>
            <span class="ast-cd-label">seg</span>
          </div>
        </div>

        <!-- Días programados -->
        <div v-if="momentosFuturos.length" class="ast-espera__dias">
          <p class="ast-espera__dias-label">Días programados</p>
          <div class="ast-espera__dias-row">
            <span
              v-for="m in momentosFuturos"
              :key="m"
              class="ast-espera__dia-pill"
              :class="{ 'ast-espera__dia-pill--next': m === proximoMomento }"
            >
              <i v-if="m === proximoMomento" class="pi pi-clock" style="font-size:0.65rem;" />
              {{ labelDia(m) }}
            </span>
          </div>
        </div>

      </div>

      <template v-else>

      <!-- ══════════════════════════════════════════════
           PASO 1 — Elegir día
      ══════════════════════════════════════════════ -->
      <template v-if="paso === 1">
        <div class="ast-dias-grid">
          <button
            v-for="m in (session.esAdmin
              ? momentos.filter(m => (conteosActividades[m] ?? 0) > 0)
              : momentosDisponibles)"
            :key="m"
            class="ast-dia-card"
            :class="{
              'ast-dia-card--locked':    dias.find((d) => d.momento === m)?.cerrado,
              'ast-dia-card--sin-act':   !conteosActividades[m],
              'ast-dia-card--hoy':       fechas[m] === hoy,
              'ast-dia-card--futuro':    fechas[m] > hoy,
              'ast-dia-card--pasado':    fechas[m] < hoy,
            }"
            @click="seleccionarDia(m)"
          >
            <span class="ast-dia-card__letter">{{ m }}</span>
            <span class="ast-dia-card__label">{{ labelDia(m) }}</span>
            <span class="ast-dia-card__date">{{ fechas[m] ?? '' }}</span>

            <!-- Conteo de actividades -->
            <span v-if="conteosActividades[m]" class="ast-dia-card__acts">
              <i class="pi pi-calendar-check" />
              {{ conteosActividades[m] }} actividad{{ conteosActividades[m] === 1 ? '' : 'es' }}
            </span>
            <span v-else class="ast-dia-card__no-acts">
              <i class="pi pi-exclamation-triangle" /> Sin actividades
            </span>

            <span
              v-if="dias.find((d) => d.momento === m)?.cerrado"
              class="ast-dia-card__lock"
            >
              <i class="pi pi-lock" /> Cerrado
            </span>
            <i v-else class="pi pi-chevron-right ast-dia-card__chevron" />
          </button>
        </div>

        <!-- Hint admin: ningún día seleccionado aún -->
        <div v-if="session.esAdmin && momentoActivo === ''" class="ast-admin-hint">
          <div class="ast-admin-hint__card">
            <div class="ast-admin-hint__icon-wrap">
              <i class="pi pi-calendar-clock ast-admin-hint__icon" />
            </div>
            <h3 class="ast-admin-hint__title">Selecciona un día</h3>
            <p class="ast-admin-hint__text">Elige uno de los días que aparecen arriba para ver y registrar la evaluación.</p>
          </div>
        </div>
      </template>

      <!-- ══════════════════════════════════════════════
           PASO 2 — Elegir actividad
      ══════════════════════════════════════════════ -->
      <template v-else-if="paso === 2">
        <!-- Header con back -->
        <div class="ast-step-header">
          <button class="ast-back" @click="volverPaso(1)">
            <i class="pi pi-arrow-left" />
          </button>
          <div class="ast-step-header__info">
            <h2 class="ast-step-title">{{ labelDia(momentoActivo) }}</h2>
            <span class="ast-step-sub">Elige una actividad</span>
          </div>
          <span v-if="diaCerrado" class="ast-lock-badge">
            <i class="pi pi-lock" /> Solo lectura
          </span>
        </div>

        <div v-if="diaCerrado" class="ast-banner-locked">
          <i class="pi pi-lock" /> Día cerrado — modo solo lectura
        </div>

        <!-- Cargando actividades -->
        <div v-if="cargandoActividades" class="ast-loading-inline">
          <div class="ast-loading__ring ast-loading__ring--sm" />
        </div>

        <!-- Lista de actividades -->
        <div v-else-if="actividadesDia.length" class="ast-act-list">
          <button
            v-for="act in actividadesDia"
            :key="act.id"
            class="ast-act-card"
            :class="{ 'ast-act-card--cancelada': act.estado === 'cancelada' }"
            :disabled="act.estado === 'cancelada'"
            @click="seleccionarActividad(act)"
          >
            <div class="ast-act-card__left">
              <span
                class="ast-estado-dot"
                :class="{
                  'ast-estado-dot--prog':    act.estado === 'programada',
                  'ast-estado-dot--real':    act.estado === 'realizada',
                  'ast-estado-dot--cancel':  act.estado === 'cancelada',
                }"
              />
            </div>
            <div class="ast-act-card__body">
              <div class="ast-act-card__top-row">
                <span class="ast-act-name">{{ act.nombre }}</span>
                <span
                  class="ast-estado-pill"
                  :class="{
                    'ast-estado-pill--prog':   act.estado === 'programada',
                    'ast-estado-pill--real':   act.estado === 'realizada',
                    'ast-estado-pill--cancel': act.estado === 'cancelada',
                  }"
                >{{ act.estado }}</span>
              </div>
              <div class="ast-act-meta">
                <span v-if="act.hora_inicio" class="ast-act-meta__item">
                  <i class="pi pi-clock" /> {{ act.hora_inicio.slice(0, 5) }}
                </span>
                <span v-if="act.lugar" class="ast-act-meta__item">
                  <i class="pi pi-map-marker" /> {{ act.lugar }}
                </span>
                <span v-if="(act.programacion as any)?.criterios?.nombre" class="ast-act-meta__item ast-act-meta__item--crit">
                  {{ (act.programacion as any)?.criterios?.nombre }}
                </span>
              </div>
            </div>
            <i v-if="act.estado !== 'cancelada'" class="pi pi-chevron-right ast-act-card__chevron" />
          </button>
        </div>

        <div v-else class="ast-empty">
          <i class="pi pi-calendar-times" />
          <p>No hay actividades para este día</p>
          <p class="ast-empty__hint">
            Ve a <strong>Actividades</strong> y crea al menos una actividad para
            <strong>{{ labelDia(momentoActivo) }}</strong>.
          </p>
        </div>
      </template>

      <!-- ══════════════════════════════════════════════
           PASO 3 — Evaluación / Asistencia
      ══════════════════════════════════════════════ -->
      <template v-else-if="paso === 3 && actividadSeleccionada">

        <!-- Header -->
        <div class="ast-step-header">
          <button class="ast-back" @click="volverPaso(2)">
            <i class="pi pi-arrow-left" />
          </button>
          <div class="ast-step-header__info">
            <h2 class="ast-step-title">{{ actividadSeleccionada.nombre }}</h2>
            <span class="ast-step-sub">{{ labelDia(momentoActivo) }}</span>
          </div>
        </div>

        <div v-if="diaCerrado" class="ast-banner-locked">
          <i class="pi pi-lock" /> Día cerrado — solo lectura
        </div>

        <!-- ══ CON CRITERIOS: estructura tipo EvaluarView ══ -->
        <template v-if="tieneCriterios">

          <!-- DETALLE: Equipo → sus criterios -->
          <template v-if="tabEval === 'equipos' && equipoEvalActivo">
            <div class="ast-eval-dh">
              <button class="ast-back" @click="equipoEvalActivo = null">
                <i class="pi pi-arrow-left" />
              </button>
              <span class="ast-eval-dot" :style="{ background: equipoEvalActivo.color }" />
              <div class="ast-eval-dh__info">
                <span class="ast-eval-dh__name">{{ equipoEvalActivo.nombre }}</span>
                <span class="ast-eval-dh__sub">
                  {{ progresoEquipoEval(equipoEvalActivo.id).calificados }}/{{ progresoEquipoEval(equipoEvalActivo.id).total }} criterios
                </span>
              </div>
            </div>
            <div class="ast-cc-cards">
              <div
                v-for="fila in (criteriosPorEquipo.get(equipoEvalActivo.id) ?? [])"
                :key="fila.criterio.id"
                class="ast-cc-card"
                :class="{ 'ast-cc-card--done': fila.puntaje !== null }"
              >
                <div class="ast-cc-header">
                  <span class="ast-cc-nombre">{{ fila.criterio.nombre }}</span>
                  <div class="ast-cc-actions">
                    <span class="ast-cc-max">máx {{ fila.criterio.puntaje_max }}</span>
                    <span v-if="fila.estadoGuardado === 'guardando'" class="ast-cc-save ast-cc-save--spin" />
                    <span v-else-if="fila.estadoGuardado === 'guardado'" class="ast-cc-save ast-cc-save--ok"><i class="pi pi-check" /></span>
                    <span v-else-if="fila.estadoGuardado === 'error'"   class="ast-cc-save ast-cc-save--err"><i class="pi pi-times" /></span>
                  </div>
                </div>
                <div class="ast-cc-scores">
                  <button
                    v-for="pts in stepsCriterio(fila.criterio.puntaje_max)"
                    :key="pts"
                    class="ast-cc-btn"
                    :class="[
                      fila.puntaje === pts
                        ? colorCritBtn(pts, Number(fila.criterio.puntaje_max)).active
                        : colorCritBtn(pts, Number(fila.criterio.puntaje_max)).idle,
                      { 'ast-cc-btn--locked': diaCerrado },
                    ]"
                    :disabled="diaCerrado"
                    @click="fila.puntaje = pts; guardarEval(fila.criterio.id, equipoEvalActivo!.id, pts, fila)"
                  >
                    <span class="ast-cc-btn-num">{{ pts }}</span>
                  </button>
                </div>
              </div>
            </div>
          </template>

          <!-- DETALLE: Criterio → todos los equipos -->
          <template v-else-if="tabEval === 'criterios' && criterioEvalActivo">
            <div class="ast-eval-dh">
              <button class="ast-back" @click="criterioEvalActivo = null">
                <i class="pi pi-arrow-left" />
              </button>
              <div class="ast-eval-dh__info">
                <span class="ast-eval-dh__name">{{ criterioEvalActivo.nombre }}</span>
                <span class="ast-eval-dh__sub">máx {{ criterioEvalActivo.puntaje_max }} pts</span>
              </div>
            </div>
            <div class="ast-cc-cards">
              <div
                v-for="fila in (filasPorCriterio.get(criterioEvalActivo.id) ?? [])"
                :key="fila.equipo.id"
                class="ast-cc-card"
                :class="{ 'ast-cc-card--done': fila.puntaje !== null }"
              >
                <div class="ast-cc-header">
                  <span class="ast-eval-dot ast-eval-dot--sm" :style="{ background: fila.equipo.color }" />
                  <span class="ast-cc-nombre">{{ fila.equipo.nombre }}</span>
                  <div class="ast-cc-actions">
                    <span v-if="fila.estadoGuardado === 'guardando'" class="ast-cc-save ast-cc-save--spin" />
                    <span v-else-if="fila.estadoGuardado === 'guardado'" class="ast-cc-save ast-cc-save--ok"><i class="pi pi-check" /></span>
                    <span v-else-if="fila.estadoGuardado === 'error'"   class="ast-cc-save ast-cc-save--err"><i class="pi pi-times" /></span>
                  </div>
                </div>
                <div class="ast-cc-scores">
                  <button
                    v-for="pts in stepsCriterio(criterioEvalActivo.puntaje_max)"
                    :key="pts"
                    class="ast-cc-btn"
                    :class="[
                      fila.puntaje === pts
                        ? colorCritBtn(pts, Number(criterioEvalActivo.puntaje_max)).active
                        : colorCritBtn(pts, Number(criterioEvalActivo.puntaje_max)).idle,
                      { 'ast-cc-btn--locked': diaCerrado },
                    ]"
                    :disabled="diaCerrado"
                    @click="fila.puntaje = pts; guardarEval(criterioEvalActivo!.id, fila.equipo.id, pts, fila)"
                  >
                    <span class="ast-cc-btn-num">{{ pts }}</span>
                  </button>
                </div>
              </div>
            </div>
          </template>

          <!-- LISTA: tabs Por equipo / Por criterio -->
          <template v-else>
            <div class="ast-eval-tabs">
              <button
                class="ast-eval-tab"
                :class="{ 'ast-eval-tab--active': tabEval === 'equipos' }"
                @click="tabEval = 'equipos'"
              >
                <i class="pi pi-users" /><span>Por equipo</span>
              </button>
              <button
                class="ast-eval-tab"
                :class="{ 'ast-eval-tab--active': tabEval === 'criterios' }"
                @click="tabEval = 'criterios'"
              >
                <i class="pi pi-list-check" /><span>Por criterio</span>
              </button>
            </div>

            <!-- Tab: Equipos -->
            <div v-if="tabEval === 'equipos'" class="ast-eval-list">
              <button
                v-for="eq in equipos"
                :key="eq.id"
                class="ast-eval-eq-card"
                @click="equipoEvalActivo = eq"
              >
                <span class="ast-eval-eq-strip" :style="{ background: eq.color }" />
                <div class="ast-eval-eq-body">
                  <div class="ast-eval-eq-top">
                    <span class="ast-eval-eq-name">{{ eq.nombre }}</span>
                    <span
                      class="ast-eval-eq-badge"
                      :class="{ 'ast-eval-eq-badge--done': progresoEquipoEval(eq.id).calificados === progresoEquipoEval(eq.id).total && progresoEquipoEval(eq.id).total > 0 }"
                    >
                      {{ progresoEquipoEval(eq.id).calificados }}/{{ progresoEquipoEval(eq.id).total }}
                    </span>
                  </div>
                  <div class="ast-eval-bar">
                    <div
                      class="ast-eval-bar__fill"
                      :style="{
                        width: pctBarEval(progresoEquipoEval(eq.id).calificados, progresoEquipoEval(eq.id).total) + '%',
                        background: eq.color,
                      }"
                    />
                  </div>
                </div>
                <i class="pi pi-chevron-right ast-eval-chevron" />
              </button>
            </div>

            <!-- Tab: Criterios -->
            <div v-else class="ast-eval-list">
              <button
                v-for="c in criteriosActividad"
                :key="c.id"
                class="ast-eval-crit-row"
                @click="criterioEvalActivo = c"
              >
                <div class="ast-eval-cr-left">
                  <span class="ast-eval-cr-name">{{ c.nombre }}</span>
                  <span class="ast-eval-cr-max">/ {{ c.puntaje_max }} pts</span>
                </div>
                <span
                  class="ast-eval-cr-chip"
                  :class="{ 'ast-eval-cr-chip--done': progresoCriterioEval(c.id).calificados === progresoCriterioEval(c.id).total && progresoCriterioEval(c.id).total > 0 }"
                >
                  {{ progresoCriterioEval(c.id).calificados }}/{{ progresoCriterioEval(c.id).total }}
                </span>
                <i class="pi pi-chevron-right ast-eval-chevron" />
              </button>
            </div>
          </template>

        </template>

        <!-- ══ SIN CRITERIOS: asistencia normal ══ -->
        <template v-else>

          <!-- Selector de equipos -->
          <div class="ast-eq-scroll-wrap">
            <div class="ast-eq-scroll">
              <button
                v-for="eq in equipos"
                :key="eq.id"
                class="ast-eq-chip"
                :class="{ 'ast-eq-chip--active': equipoActivo?.id === eq.id }"
                :style="equipoActivo?.id === eq.id
                  ? { borderColor: eq.color, background: eq.color + '22', color: eq.color }
                  : {}"
                @click="seleccionarEquipo(eq)"
              >
                <span class="ast-eq-dot" :style="{ background: eq.color }" />
                <span>{{ eq.nombre }}</span>
              </button>
            </div>
          </div>

          <!-- Resumen sticky del equipo activo -->
          <div v-if="equipoActivo" class="ast-resumen-bar">
            <div class="ast-resumen-bar__progress">
              <div class="ast-resumen-bar__fill" :style="{ width: pctCompleto() + '%' }" />
            </div>
            <div class="ast-resumen-bar__stats">
              <div class="ast-stat">
                <span class="ast-stat__val ast-stat__val--green">{{ contarPresentes }}</span>
                <span class="ast-stat__lbl">Presentes</span>
              </div>
              <div class="ast-stat">
                <span class="ast-stat__val ast-stat__val--red">{{ contarAusentes }}</span>
                <span class="ast-stat__lbl">Ausentes</span>
              </div>
              <div class="ast-stat">
                <span class="ast-stat__val ast-stat__val--yellow">{{ contarJustificados }}</span>
                <span class="ast-stat__lbl">Just.</span>
              </div>
              <div class="ast-stat">
                <span class="ast-stat__val ast-stat__val--gray">{{ contarSinRegistro }}</span>
                <span class="ast-stat__lbl">Pendiente</span>
              </div>
            </div>
            <div v-if="formulaTexto" class="ast-resumen-bar__formula">
              <i class="pi pi-calculator" /> {{ formulaTexto }}
            </div>
          </div>

          <!-- Toolbar -->
          <div class="ast-toolbar">
            <div class="ast-search-wrap">
              <i class="pi pi-search ast-search-icon" />
              <input
                v-model="busqueda"
                class="ast-search"
                placeholder="Buscar integrante…"
                type="search"
              />
            </div>
            <button
              class="ast-btn-all-present"
              :disabled="diaCerrado || !equipoActivo || contarSinRegistro === 0"
              @click="todosPresentes"
            >
              <i class="pi pi-check-circle" />
              <span>Todos presentes</span>
            </button>
          </div>

          <!-- Cargando registros -->
          <div v-if="cargandoRegistros" class="ast-loading-inline">
            <div class="ast-loading__ring ast-loading__ring--sm" />
            <span>Cargando integrantes…</span>
          </div>

          <!-- Lista de integrantes -->
          <div v-else-if="filasFiltradas.length" class="ast-filas">
            <div
              v-for="fila in filasFiltradas"
              :key="fila.integrante.id"
              class="ast-fila"
              :class="filaClass(fila)"
            >
              <div class="ast-fila__header">
                <div class="ast-fila__nombre-wrap">
                  <span class="ast-fila__nombre">
                    {{ fila.integrante.apellidos }}, {{ fila.integrante.nombres }}
                  </span>
                  <span v-if="fila.estado === 'justificado' && fila.motivo_justificacion" class="ast-fila__motivo">
                    <i class="pi pi-file-edit" /> {{ fila.motivo_justificacion }}
                    <span v-if="fila.documentado" class="ast-fila__doc"><i class="pi pi-paperclip" /> Doc.</span>
                  </span>
                </div>
                <span class="ast-save-indicator">
                  <span v-if="fila.estadoGuardado === 'guardando'" class="ast-save-ring" />
                  <span v-else-if="fila.estadoGuardado === 'guardado'" class="ast-save-ok"><i class="pi pi-check" /></span>
                  <span v-else-if="fila.estadoGuardado === 'error'"   class="ast-save-err"><i class="pi pi-times" /></span>
                </span>
              </div>
              <div class="ast-estado-btns">
                <button
                  v-for="(cfg, key) in ESTADO_CFG"
                  :key="key"
                  class="ast-eb"
                  :class="fila.estado === key ? cfg.active : cfg.idle"
                  :disabled="diaCerrado"
                  @click="marcarEstado(fila, key as EstadoAsistencia)"
                >
                  <i :class="cfg.icon" />
                  <span>{{ cfg.label }}</span>
                </button>
              </div>
            </div>
          </div>

          <div v-else-if="!cargandoRegistros && equipoActivo" class="ast-empty">
            <i class="pi pi-inbox" />
            <p>No hay integrantes en este equipo</p>
          </div>

          <div v-else-if="!equipoActivo" class="ast-empty">
            <i class="pi pi-arrow-up" />
            <p>Selecciona un equipo arriba</p>
          </div>

        </template>

      </template>

      </template><!-- /v-else días disponibles -->
    </template>

    <!-- ══════════════════════════════════════════════
         DIALOG: Justificación
    ══════════════════════════════════════════════ -->
    <Dialog
      v-model:visible="dialogJust"
      header="Justificación"
      modal
      :style="{ width: 'min(26rem, 95vw)' }"
    >
      <p class="ast-dialog-text">
        Motivo para
        <strong>{{ filaJust?.integrante.apellidos }}, {{ filaJust?.integrante.nombres }}</strong>:
      </p>
      <Textarea
        v-model="motivoTemp"
        rows="3"
        class="w-full"
        placeholder="Ej: Enfermedad con certificado médico…"
        autofocus
      />
      <label class="ast-doc-label">
        <span class="ast-doc-checkbox-wrap">
          <input v-model="documentadoTemp" type="checkbox" class="ast-doc-checkbox" />
          <span class="ast-doc-checkbox-custom">
            <i v-if="documentadoTemp" class="pi pi-check" />
          </span>
        </span>
        Justificación documentada
      </label>
      <template #footer>
        <div class="ast-dialog-footer">
          <button class="ast-btn-sec" @click="dialogJust = false">Cancelar</button>
          <button class="ast-btn-pri" @click="confirmarJustificado">
            <i class="pi pi-check" /> Confirmar
          </button>
        </div>
      </template>
    </Dialog>

  </div>
</template>

<style scoped>
/* ═══════════════════════════════════════════════════════════
   BASE
═══════════════════════════════════════════════════════════ */
.ast {
  padding: 0 0 5rem;
  min-height: 100%;
}

/* Loading */
.ast-loading {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 0.75rem; padding: 5rem 1rem;
  color: #94a3b8;
}
.ast-loading__ring {
  width: 36px; height: 36px;
  border: 3px solid #dcfce7; border-top-color: #16a34a;
  border-radius: 50%; animation: spin .7s linear infinite;
}
.ast-loading__ring--sm { width: 24px; height: 24px; }
.ast-loading p { font-size: 0.85rem; }
.ast-loading-inline {
  display: flex; align-items: center; justify-content: center;
  gap: 0.75rem; padding: 2rem; color: #94a3b8; font-size: 0.85rem;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Error */
.ast-error {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.5rem; padding: 3rem 1.5rem; text-align: center; color: #dc2626;
}
.ast-error .pi { font-size: 2rem; }
.ast-error p { font-size: 0.9rem; }

/* Empty */
.ast-empty {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.5rem; padding: 3rem 1rem; color: #94a3b8;
}
.ast-empty .pi { font-size: 2.2rem; opacity: 0.5; }
.ast-empty p { font-size: 0.88rem; }
.ast-empty__hint {
  font-size: 0.8rem !important;
  color: #b45309;
  background: #fef3c7;
  border: 1px solid #fde68a;
  border-radius: 8px;
  padding: 0.5rem 0.875rem;
  margin-top: 0.25rem;
  text-align: center;
  max-width: 280px;
}

/* Back button */
.ast-back {
  flex-shrink: 0; width: 40px; height: 40px; border-radius: 50%;
  border: 1.5px solid #e2e8f0; background: white; color: #374151;
  font-size: 1rem; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.15s; box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.ast-back:hover { border-color: #16a34a; color: #16a34a; background: #f0fdf4; }

/* ═══════════════════════════════════════════════════════════
   PASO 1 — Header + Grid días
═══════════════════════════════════════════════════════════ */
.ast-page-header {
  display: flex; align-items: center; gap: 0.875rem;
  padding: 0.75rem 1rem 1rem;
}
.ast-page-header__icon {
  width: 44px; height: 44px; border-radius: 12px;
  background: #ecfdf5; color: #16a34a;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.15rem; flex-shrink: 0;
}
.ast-page-title { font-size: 1.2rem; font-weight: 800; color: #1e293b; margin: 0; }
.ast-page-sub   { font-size: 0.8rem; color: #94a3b8; margin: 0; }

.ast-dias-grid {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 0.75rem;
  padding: 0 1rem;
}

.ast-dia-card { flex: 0 0 calc(50% - 0.375rem); max-width: 180px; }

@media (min-width: 500px) {
  .ast-dia-card { flex: 0 0 auto; width: 150px; }
}

.ast-dia-card {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 0.2rem;
  padding: 1.25rem 0.75rem;
  border-radius: 16px;
  border: 2px solid #e2e8f0; background: white;
  box-shadow: 0 1px 4px rgba(0,0,0,.07);
  cursor: pointer; transition: all 0.15s;
  text-align: center; min-height: 110px;
  position: relative;
}
.ast-dia-card:hover { border-color: #16a34a; background: #f0fdf4; box-shadow: 0 4px 12px rgba(22,163,74,.12); transform: translateY(-1px); }
.ast-dia-card:active { transform: scale(0.98); }
.ast-dia-card--locked { opacity: 0.65; }

.ast-dia-card__letter {
  font-size: 2rem; font-weight: 900; color: #16a34a; line-height: 1;
}
.ast-dia-card__label {
  font-size: 0.78rem; font-weight: 700; color: #475569;
  text-transform: capitalize;
}
.ast-dia-card__date {
  font-size: 0.7rem; color: #94a3b8;
}
.ast-dia-card__lock {
  display: flex; align-items: center; gap: 0.25rem;
  font-size: 0.65rem; font-weight: 700;
  background: #fef3c7; color: #b45309;
  border-radius: 6px; padding: 0.15rem 0.4rem;
  margin-top: 0.25rem;
}
.ast-dia-card__chevron {
  position: absolute; right: 0.75rem; top: 50%;
  transform: translateY(-50%); color: #cbd5e1; font-size: 0.7rem;
}

.ast-dia-card__acts {
  display: flex; align-items: center; gap: 0.25rem;
  font-size: 0.68rem; font-weight: 700;
  background: #dcfce7; color: #16a34a;
  border-radius: 6px; padding: 0.15rem 0.45rem;
  margin-top: 0.2rem;
}
.ast-dia-card__acts .pi { font-size: 0.65rem; }

.ast-dia-card__no-acts {
  display: flex; align-items: center; gap: 0.25rem;
  font-size: 0.66rem; font-weight: 700;
  background: #fef3c7; color: #b45309;
  border-radius: 6px; padding: 0.15rem 0.45rem;
  margin-top: 0.2rem;
  text-align: center;
}
.ast-dia-card__no-acts .pi { font-size: 0.65rem; }

.ast-dia-card--sin-act {
  border-color: #fde68a;
  background: #fffbeb;
}
.ast-dia-card--sin-act:hover {
  border-color: #f59e0b;
  background: #fef3c7;
  box-shadow: 0 4px 12px rgba(245,158,11,.15);
}

/* Día de hoy — verde intenso */
.ast-dia-card--hoy {
  border-color: #16a34a;
  background: #dcfce7;
  box-shadow: 0 0 0 3px rgba(22,163,74,.18), 0 2px 8px rgba(22,163,74,.15);
}
.ast-dia-card--hoy .ast-dia-card__letter { color: #15803d; }
.ast-dia-card--hoy .ast-dia-card__label  { color: #166534; }
.ast-dia-card--hoy .ast-dia-card__date   { color: #16a34a; }
.ast-dia-card--hoy:hover {
  border-color: #15803d;
  background: #bbf7d0;
  box-shadow: 0 0 0 3px rgba(22,163,74,.25), 0 4px 14px rgba(22,163,74,.2);
}

/* Días futuros — tono apagado */
.ast-dia-card--futuro {
  border-color: #e2e8f0;
  background: #f8fafc;
  opacity: 0.6;
}
.ast-dia-card--futuro .ast-dia-card__letter { color: #94a3b8; }
.ast-dia-card--futuro:hover {
  opacity: 1;
  border-color: #94a3b8;
  background: #f1f5f9;
  box-shadow: 0 4px 12px rgba(0,0,0,.08);
}

/* Días pasados — historial */
.ast-dia-card--pasado {
  border-color: #e2e8f0;
  background: #f8fafc;
}
.ast-dia-card--pasado .ast-dia-card__letter { color: #94a3b8; }
.ast-dia-card--pasado .ast-dia-card__label  { color: #94a3b8; }
.ast-dia-card--pasado .ast-dia-card__date   { color: #cbd5e1; }
.ast-dia-card--pasado::after {
  content: 'Historial';
  position: absolute; top: 0.4rem; right: 0.5rem;
  font-size: 0.55rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; color: #94a3b8;
}
.ast-dia-card--pasado:hover {
  border-color: #cbd5e1;
  background: #f1f5f9;
  box-shadow: 0 4px 12px rgba(0,0,0,.06);
}

/* ── Hint admin sin día seleccionado ── */
.ast-admin-hint {
  display: flex;
  justify-content: center;
  padding: 2rem 1rem;
}
.ast-admin-hint__card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
  border: 1.5px solid #bbf7d0;
  border-radius: 20px;
  padding: 2rem;
  text-align: center;
  max-width: 320px;
  width: 100%;
  box-shadow: 0 4px 16px rgba(22,163,74,0.08);
}
.ast-admin-hint__icon-wrap {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: #dcfce7;
  border: 2px solid #86efac;
  display: flex;
  align-items: center;
  justify-content: center;
}
.ast-admin-hint__icon { font-size: 1.6rem; color: #16a34a; }
.ast-admin-hint__title { font-size: 1rem; font-weight: 700; color: #15803d; margin: 0; }
.ast-admin-hint__text { font-size: 0.85rem; color: #4b5563; margin: 0; line-height: 1.5; }

/* ═══════════════════════════════════════════════════════════
   PASO 2 — Actividades
═══════════════════════════════════════════════════════════ */
.ast-step-header {
  display: flex; align-items: center; gap: 0.75rem;
  padding: 0.5rem 1rem 0.75rem;
}
.ast-step-header__info { flex: 1; min-width: 0; }
.ast-step-title {
  font-size: 1rem; font-weight: 700; color: #1e293b; margin: 0;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.ast-step-sub { font-size: 0.75rem; color: #94a3b8; }

.ast-lock-badge {
  display: flex; align-items: center; gap: 0.3rem;
  font-size: 0.72rem; font-weight: 700;
  background: #fef3c7; color: #b45309; border-radius: 8px;
  padding: 0.25rem 0.6rem; flex-shrink: 0;
}

.ast-banner-locked {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fef3c7; border: 1px solid #fde68a;
  border-radius: 10px; padding: 0.6rem 1rem;
  font-size: 0.82rem; font-weight: 600; color: #92400e;
  margin: 0 1rem 0.75rem;
}

.ast-act-list {
  display: flex; flex-direction: column; gap: 0.5rem; padding: 0 1rem;
}

.ast-act-card {
  display: flex; align-items: stretch; gap: 0;
  border-radius: 14px; border: 1.5px solid #e2e8f0; background: white;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  cursor: pointer; text-align: left; overflow: hidden;
  transition: all 0.15s; width: 100%; min-height: 70px;
}
.ast-act-card:hover:not(:disabled) { border-color: #bbf7d0; background: #fafffe; }
.ast-act-card:active:not(:disabled) { transform: scale(0.99); }
.ast-act-card--cancelada { opacity: 0.5; cursor: not-allowed; }

.ast-act-card__left {
  width: 6px; flex-shrink: 0; display: flex; align-items: stretch;
}
.ast-estado-dot { width: 100%; border-radius: 0; }
.ast-estado-dot--prog   { background: #22c55e; }
.ast-estado-dot--real   { background: #16a34a; }
.ast-estado-dot--cancel { background: #ef4444; }

.ast-act-card__body {
  flex: 1; padding: 0.75rem; display: flex; flex-direction: column; gap: 0.35rem;
}
.ast-act-card__top-row {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 0.5rem;
}
.ast-act-name { font-size: 0.93rem; font-weight: 600; color: #1e293b; flex: 1; }

.ast-estado-pill {
  font-size: 0.68rem; font-weight: 700; border-radius: 6px;
  padding: 0.15rem 0.45rem; white-space: nowrap; flex-shrink: 0;
  text-transform: capitalize;
}
.ast-estado-pill--prog   { background: #dcfce7; color: #16a34a; }
.ast-estado-pill--real   { background: #bbf7d0; color: #166534; }
.ast-estado-pill--cancel { background: #fee2e2; color: #dc2626; }

.ast-act-meta {
  display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center;
}
.ast-act-meta__item {
  display: flex; align-items: center; gap: 0.25rem;
  font-size: 0.78rem; color: #64748b;
}
.ast-act-meta__item--crit {
  background: #f1f5f9; border-radius: 6px; padding: 0.1rem 0.4rem;
  font-size: 0.72rem; font-weight: 600; color: #475569;
}
.ast-act-meta__item .pi { font-size: 0.72rem; }

.ast-act-card__chevron { color: #cbd5e1; font-size: 0.75rem; align-self: center; margin: 0 0.75rem; flex-shrink: 0; }

/* ═══════════════════════════════════════════════════════════
   PASO 3 — Equipos
═══════════════════════════════════════════════════════════ */
.ast-eq-scroll-wrap {
  overflow-x: auto; padding: 0 1rem; scrollbar-width: none;
  margin-bottom: 0.75rem;
}
.ast-eq-scroll-wrap::-webkit-scrollbar { display: none; }
.ast-eq-scroll { display: flex; gap: 0.5rem; width: max-content; }

.ast-eq-chip {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.5rem 0.875rem; border-radius: 999px;
  border: 2px solid #e2e8f0; background: white;
  font-size: 0.82rem; font-weight: 600; color: #475569;
  cursor: pointer; transition: all 0.15s; min-height: 40px;
  white-space: nowrap;
}
.ast-eq-chip:hover { border-color: #16a34a; }
.ast-eq-chip--active { font-weight: 700; }
.ast-eq-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }

/* ── Barra resumen ── */
.ast-resumen-bar {
  margin: 0 1rem 0.75rem;
  background: white; border: 1.5px solid #e2e8f0;
  border-radius: 14px; overflow: hidden;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
}
.ast-resumen-bar__progress {
  height: 4px; background: #f1f5f9;
}
.ast-resumen-bar__fill {
  height: 100%; background: #16a34a;
  border-radius: 0 4px 4px 0; transition: width 0.35s ease;
}
.ast-resumen-bar__stats {
  display: flex; gap: 0; padding: 0.75rem 1rem;
  justify-content: space-around;
}
.ast-stat {
  display: flex; flex-direction: column; align-items: center; gap: 0.1rem;
}
.ast-stat__val {
  font-size: 1.5rem; font-weight: 900; line-height: 1;
}
.ast-stat__val--green  { color: #16a34a; }
.ast-stat__val--red    { color: #ef4444; }
.ast-stat__val--yellow { color: #ca8a04; }
.ast-stat__val--gray   { color: #94a3b8; }
.ast-stat__lbl { font-size: 0.65rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.04em; }

.ast-resumen-bar__formula {
  display: flex; align-items: center; gap: 0.4rem;
  border-top: 1px solid #f1f5f9;
  padding: 0.5rem 1rem;
  font-size: 0.75rem; color: #64748b; font-family: monospace;
}
.ast-resumen-bar__formula .pi { color: #16a34a; font-size: 0.75rem; flex-shrink: 0; }

/* ── Toolbar ── */
.ast-toolbar {
  display: flex; gap: 0.5rem; padding: 0 1rem 0.75rem;
  align-items: center;
}
.ast-search-wrap {
  flex: 1; position: relative; min-width: 0;
}
.ast-search-icon {
  position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%);
  color: #94a3b8; font-size: 0.82rem; pointer-events: none;
}
.ast-search {
  width: 100%; height: 42px;
  padding: 0 0.75rem 0 2.1rem;
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  background: white; font-size: 0.88rem; color: #1e293b;
  outline: none; transition: border-color 0.15s;
}
.ast-search:focus { border-color: #16a34a; }
.ast-search::placeholder { color: #94a3b8; }

.ast-btn-all-present {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0 0.875rem; height: 42px; border-radius: 10px;
  border: 1.5px solid #bbf7d0; background: #f0fdf4;
  color: #16a34a; font-size: 0.82rem; font-weight: 700;
  cursor: pointer; white-space: nowrap; transition: all 0.15s;
  flex-shrink: 0;
}
.ast-btn-all-present:hover:not(:disabled) { background: #dcfce7; }
.ast-btn-all-present:disabled { opacity: 0.4; cursor: not-allowed; }
.ast-btn-all-present .pi { font-size: 0.9rem; }

/* ── Filas de integrantes ── */
.ast-filas {
  display: flex; flex-direction: column; gap: 0.5rem; padding: 0 1rem;
}

.ast-fila {
  background: white; border: 1.5px solid #e2e8f0;
  border-radius: 14px; overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  transition: border-color 0.15s;
}
.ast-fila--presente    { border-color: #86efac; background: #f0fdf4; }
.ast-fila--ausente     { border-color: #fca5a5; background: #fff5f5; }
.ast-fila--justificado { border-color: #fde047; background: #fefce8; }

.ast-fila__header {
  display: flex; align-items: flex-start;
  justify-content: space-between; gap: 0.5rem;
  padding: 0.75rem 0.875rem 0.5rem;
}
.ast-fila__nombre-wrap { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.2rem; }
.ast-fila__nombre {
  font-size: 0.92rem; font-weight: 600; color: #1e293b;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.ast-fila__motivo {
  display: flex; align-items: center; gap: 0.3rem; flex-wrap: wrap;
  font-size: 0.75rem; color: #b45309; font-style: italic;
}
.ast-fila__motivo .pi { font-size: 0.72rem; }
.ast-fila__doc {
  display: inline-flex; align-items: center; gap: 0.2rem;
  font-style: normal; font-weight: 700; color: #166534; font-size: 0.72rem;
}

/* Save indicator */
.ast-save-indicator { flex-shrink: 0; width: 24px; height: 24px; }
.ast-save-ring {
  display: block; width: 22px; height: 22px; border-radius: 50%;
  border: 2.5px solid #dcfce7; border-top-color: #16a34a;
  animation: spin .6s linear infinite;
}
.ast-save-ok, .ast-save-err {
  display: flex; align-items: center; justify-content: center;
  width: 22px; height: 22px; border-radius: 50%; font-size: 0.7rem;
}
.ast-save-ok  { background: #dcfce7; color: #16a34a; }
.ast-save-err { background: #fee2e2; color: #dc2626; }

/* Botones de estado */
.ast-estado-btns {
  display: flex; gap: 0; border-top: 1px solid #f1f5f9;
}
.ast-eb {
  flex: 1; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 0.2rem;
  min-height: 54px; border: none; cursor: pointer;
  font-size: 0.72rem; font-weight: 700; transition: all 0.15s;
  border-right: 1px solid #f1f5f9;
}
.ast-eb:last-child { border-right: none; }
.ast-eb .pi { font-size: 1rem; }
.ast-eb:disabled { opacity: 0.4; cursor: not-allowed; }

/* Idle states */
.ast-eb--presente-idle    { background: #f8fafc; color: #64748b; }
.ast-eb--ausente-idle     { background: #f8fafc; color: #64748b; }
.ast-eb--justificado-idle { background: #f8fafc; color: #64748b; }

/* Hover idle */
.ast-eb--presente-idle:hover:not(:disabled)    { background: #f0fdf4; color: #16a34a; }
.ast-eb--ausente-idle:hover:not(:disabled)     { background: #fff5f5; color: #ef4444; }
.ast-eb--justificado-idle:hover:not(:disabled) { background: #fefce8; color: #ca8a04; }

/* Active states */
.ast-eb--presente-act    { background: #dcfce7; color: #16a34a; }
.ast-eb--ausente-act     { background: #fee2e2; color: #dc2626; }
.ast-eb--justificado-act { background: #fef9c3; color: #b45309; }

/* ═══════════════════════════════════════════════════════════
   DIALOG
═══════════════════════════════════════════════════════════ */
.ast-dialog-text {
  font-size: 0.88rem; color: #64748b; margin: 0 0 0.75rem;
}
.ast-doc-label {
  display: flex; align-items: center; gap: 0.6rem;
  margin-top: 0.875rem; cursor: pointer; font-size: 0.9rem; color: #374151;
}
.ast-doc-checkbox-wrap { position: relative; flex-shrink: 0; }
.ast-doc-checkbox { opacity: 0; position: absolute; width: 20px; height: 20px; cursor: pointer; }
.ast-doc-checkbox-custom {
  width: 20px; height: 20px; border-radius: 5px;
  border: 2px solid #cbd5e1; background: white;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.7rem; color: white; transition: all 0.15s;
}
.ast-doc-checkbox:checked + .ast-doc-checkbox-custom {
  background: #16a34a; border-color: #16a34a;
}
.ast-dialog-footer { display: flex; gap: 0.5rem; justify-content: flex-end; }

.ast-btn-pri {
  display: inline-flex; align-items: center; gap: 0.4rem;
  padding: 0.6rem 1.2rem; border-radius: 8px; border: none;
  background: #16a34a; color: white; font-size: 0.88rem; font-weight: 600;
  cursor: pointer; transition: background 0.15s; min-height: 40px;
}
.ast-btn-pri:hover { background: #15803d; }

.ast-btn-sec {
  display: inline-flex; align-items: center;
  padding: 0.6rem 1rem; border-radius: 8px;
  border: 1.5px solid #e2e8f0; background: white;
  color: #64748b; font-size: 0.88rem; font-weight: 600;
  cursor: pointer; transition: all 0.15s; min-height: 40px;
}
.ast-btn-sec:hover { background: #f8fafc; }

/* ═══════════════════════════════════════════════════════════
   CRITERIOS — TARJETAS (misma estructura que EvaluarView)
═══════════════════════════════════════════════════════════ */
.ast-cc-cards {
  display: flex; flex-direction: column;
  gap: 0.625rem; padding: 0 1rem;
}

.ast-cc-card {
  background: white;
  border: 1.5px solid #e2e8f0;
  border-radius: 14px;
  padding: 0.875rem;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  transition: border-color 0.15s;
}
.ast-cc-card--done {
  border-color: #bbf7d0;
  background: #fafffe;
}

.ast-cc-header {
  display: flex; align-items: center; gap: 0.5rem;
  margin-bottom: 0.625rem;
}
.ast-cc-nombre {
  flex: 1; min-width: 0;
  font-size: 0.9rem; font-weight: 600; color: #1e293b;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.ast-cc-actions {
  display: flex; align-items: center; gap: 0.4rem; flex-shrink: 0;
}
.ast-cc-max {
  font-size: 0.72rem; font-weight: 600;
  background: #f1f5f9; color: #64748b;
  border-radius: 6px; padding: 0.1rem 0.45rem;
}
.ast-cc-save {
  width: 26px; height: 26px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.72rem; flex-shrink: 0;
}
.ast-cc-save--spin {
  border: 2.5px solid #dcfce7; border-top-color: #16a34a;
  animation: spin .7s linear infinite;
}
.ast-cc-save--ok  { background: #dcfce7; color: #16a34a; }
.ast-cc-save--err { background: #fee2e2; color: #dc2626; }

/* ── Botones de puntaje ── */
.ast-cc-scores {
  display: flex; gap: 0.35rem;
}
.ast-cc-btn {
  flex: 1;
  min-height: 52px;
  border-radius: 10px; border: 2px solid transparent;
  cursor: pointer; transition: all 0.15s;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  padding: 0.2rem 0.1rem; line-height: 1.1;
}
.ast-cc-btn--locked { opacity: 0.45; cursor: not-allowed; }
.ast-cc-btn-num {
  font-size: 0.95rem; font-weight: 800; display: block;
}

/* Idle */
.crit-btn--0-idle    { background: #fef2f2; border-color: #fecaca; color: #ef4444; }
.crit-btn--low-idle  { background: #fff7ed; border-color: #fed7aa; color: #f97316; }
.crit-btn--mid-idle  { background: #fefce8; border-color: #fef08a; color: #ca8a04; }
.crit-btn--high-idle { background: #eff6ff; border-color: #bfdbfe; color: #3b82f6; }
.crit-btn--max-idle  { background: #f0fdf4; border-color: #bbf7d0; color: #16a34a; }

/* Active */
.crit-btn--0-act    { background: #ef4444; border-color: #ef4444; color: white; box-shadow: 0 2px 8px #ef444440; transform: scale(1.04); }
.crit-btn--low-act  { background: #f97316; border-color: #f97316; color: white; box-shadow: 0 2px 8px #f9731640; transform: scale(1.04); }
.crit-btn--mid-act  { background: #eab308; border-color: #eab308; color: white; box-shadow: 0 2px 8px #eab30840; transform: scale(1.04); }
.crit-btn--high-act { background: #3b82f6; border-color: #3b82f6; color: white; box-shadow: 0 2px 8px #3b82f640; transform: scale(1.04); }
.crit-btn--max-act  { background: #16a34a; border-color: #16a34a; color: white; box-shadow: 0 2px 8px #16a34a40; transform: scale(1.04); }

/* Hover idle */
.crit-btn--0-idle:hover:not(.ast-cc-btn--locked)    { background: #fee2e2; transform: scale(1.02); }
.crit-btn--low-idle:hover:not(.ast-cc-btn--locked)  { background: #ffedd5; transform: scale(1.02); }
.crit-btn--mid-idle:hover:not(.ast-cc-btn--locked)  { background: #fef9c3; transform: scale(1.02); }
.crit-btn--high-idle:hover:not(.ast-cc-btn--locked) { background: #dbeafe; transform: scale(1.02); }
.crit-btn--max-idle:hover:not(.ast-cc-btn--locked)  { background: #dcfce7; transform: scale(1.02); }

/* ── Separador criterios / asistencia ── */
.ast-section-divider {
  display: flex; align-items: center; gap: 0.75rem;
  padding: 0.75rem 1rem 0.25rem;
  font-size: 0.75rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: 0.05em;
}
.ast-section-divider::before,
.ast-section-divider::after {
  content: ''; flex: 1; height: 1px; background: #e2e8f0;
}

/* ═══════════════════════════════════════════════════════════
   EVAL — TABS Y LISTAS (estructura EvaluarView)
═══════════════════════════════════════════════════════════ */
.ast-eval-tabs {
  display: flex; gap: 0;
  margin: 0 1rem 0.75rem;
  border-radius: 12px; background: #f1f5f9; padding: 3px;
}
.ast-eval-tab {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: 0.4rem;
  padding: 0.55rem 0.5rem; border-radius: 9px; border: none; background: none;
  font-size: 0.85rem; font-weight: 600; color: #64748b;
  cursor: pointer; transition: all 0.15s; min-height: 40px;
}
.ast-eval-tab--active { background: white; color: #16a34a; box-shadow: 0 1px 4px rgba(0,0,0,.1); }
.ast-eval-tab .pi { font-size: 0.82rem; }

.ast-eval-list {
  display: flex; flex-direction: column; gap: 0.5rem; padding: 0 1rem;
}

/* Tarjeta de equipo */
.ast-eval-eq-card {
  display: flex; align-items: center; gap: 0;
  border-radius: 14px; border: 1.5px solid #e2e8f0; background: white;
  box-shadow: 0 1px 4px rgba(0,0,0,.06); overflow: hidden;
  cursor: pointer; transition: all 0.15s; min-height: 64px;
  text-align: left; width: 100%;
}
.ast-eval-eq-card:hover { border-color: #bbf7d0; background: #fafffe; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.ast-eval-eq-card:active { transform: scale(0.99); }
.ast-eval-eq-strip { width: 5px; align-self: stretch; flex-shrink: 0; }
.ast-eval-eq-body { flex: 1; min-width: 0; padding: 0.6rem 0.75rem; display: flex; flex-direction: column; gap: 0.45rem; }
.ast-eval-eq-top { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
.ast-eval-eq-name { font-size: 0.93rem; font-weight: 600; color: #1e293b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ast-eval-eq-badge {
  font-size: 0.75rem; font-weight: 700; padding: 0.15rem 0.55rem;
  border-radius: 999px; background: #f1f5f9; color: #64748b; white-space: nowrap; flex-shrink: 0;
}
.ast-eval-eq-badge--done { background: #dcfce7; color: #16a34a; }
.ast-eval-bar { height: 4px; background: #f1f5f9; border-radius: 4px; overflow: hidden; }
.ast-eval-bar__fill { height: 100%; border-radius: 4px; transition: width 0.35s ease; min-width: 2px; }
.ast-eval-chevron { color: #cbd5e1; font-size: 0.75rem; flex-shrink: 0; margin-right: 0.75rem; }

/* Fila de criterio */
.ast-eval-crit-row {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.75rem 0.875rem; border-radius: 12px;
  border: 1.5px solid #e2e8f0; background: white;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  cursor: pointer; text-align: left; min-height: 56px; width: 100%;
  transition: all 0.15s;
}
.ast-eval-crit-row:hover { border-color: #bbf7d0; background: #fafffe; }
.ast-eval-cr-left { display: flex; align-items: baseline; gap: 0.4rem; flex: 1; min-width: 0; }
.ast-eval-cr-name { font-size: 0.9rem; font-weight: 500; color: #1e293b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ast-eval-cr-max { font-size: 0.75rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.ast-eval-cr-chip {
  font-size: 0.78rem; font-weight: 700; padding: 0.18rem 0.55rem;
  border-radius: 999px; background: #f1f5f9; color: #64748b; white-space: nowrap; flex-shrink: 0;
}
.ast-eval-cr-chip--done { background: #dcfce7; color: #16a34a; }

/* Header detalle (equipo o criterio seleccionado) */
.ast-eval-dh {
  display: flex; align-items: center; gap: 0.75rem;
  padding: 0.5rem 1rem 0.75rem;
}
.ast-eval-dh__info { display: flex; flex-direction: column; gap: 0.1rem; min-width: 0; }
.ast-eval-dh__name { font-size: 1rem; font-weight: 700; color: #1e293b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ast-eval-dh__sub { font-size: 0.75rem; color: #94a3b8; }
.ast-eval-dot {
  width: 16px; height: 16px; border-radius: 50%; flex-shrink: 0;
  border: 2px solid white; box-shadow: 0 0 0 1.5px rgba(0,0,0,.12);
}
.ast-eval-dot--sm { width: 11px; height: 11px; }

/* ═══════════════════════════════════════════════════════════
   TABLET (≥ 640px)
═══════════════════════════════════════════════════════════ */
@media (min-width: 640px) {
  .ast-act-list     { gap: 0.625rem; }
  .ast-filas        { gap: 0.625rem; }
  .ast-act-name     { font-size: 1rem; }
  .ast-fila__nombre { font-size: 0.95rem; }
  .ast-eb           { min-height: 58px; font-size: 0.78rem; }
  .ast-eb .pi       { font-size: 1.1rem; }
}

/* ═══════════════════════════════════════════════════════════
   DESKTOP (≥ 960px)
═══════════════════════════════════════════════════════════ */
@media (min-width: 960px) {
  .ast-act-list { display: grid; grid-template-columns: 1fr 1fr; align-items: start; }
  .ast-filas    { display: grid; grid-template-columns: 1fr 1fr; align-items: start; }
}

/* ══════════════════════════════════════════════════════════
   PANTALLA DE ESPERA — minimalista
══════════════════════════════════════════════════════════ */
/* ════════════════════════════════════════
   Pantalla de espera — evaluador
════════════════════════════════════════ */
.ast-espera {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1.75rem;
  padding: 3rem 1.25rem 4rem;
  min-height: 72vh;
  text-align: center;
}

.ast-espera__icon-wrap {
  width: 88px;
  height: 88px;
  border-radius: 50%;
  background: linear-gradient(135deg, #f0fdf4, #dcfce7);
  border: 2px solid #bbf7d0;
  box-shadow: 0 8px 24px rgba(22,163,74,0.14);
  display: flex;
  align-items: center;
  justify-content: center;
  animation: ast-float 3s ease-in-out infinite;
}
.ast-espera__icon {
  font-size: 2.75rem;
  line-height: 1;
}

.ast-espera__copy {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
}
.ast-espera__titulo {
  font-size: 1.3rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0;
  letter-spacing: -0.02em;
  line-height: 1.25;
}
.ast-espera__sub {
  font-size: 0.8rem;
  color: #94a3b8;
  margin: 0;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  font-weight: 600;
}
.ast-espera__next-day {
  font-size: 1rem;
  font-weight: 700;
  color: #16a34a;
  margin: 0;
}

.ast-espera__countdown {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
  border: 1.5px solid #bbf7d0;
  border-radius: 22px;
  padding: 1.25rem 1.5rem;
  box-shadow: 0 4px 20px rgba(22,163,74,0.1);
}
.ast-cd-bloque {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  min-width: 3rem;
}
.ast-cd-num {
  font-size: 2.4rem;
  font-weight: 800;
  line-height: 1;
  color: #0f172a;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.03em;
}
.ast-cd-seg .ast-cd-num { color: #16a34a; }
.ast-cd-label {
  font-size: 0.58rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: #94a3b8;
}
.ast-cd-sep {
  font-size: 1.75rem;
  font-weight: 300;
  color: #86efac;
  margin-bottom: 1.2rem;
  user-select: none;
  animation: ast-blink 1s step-end infinite;
}

.ast-espera__dias {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
}
.ast-espera__dias-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #cbd5e1;
  margin: 0;
}
.ast-espera__dias-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  justify-content: center;
}
.ast-espera__dia-pill {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.75rem;
  font-weight: 600;
  color: #64748b;
  background: #f8fafc;
  border-radius: 999px;
  padding: 0.35rem 0.9rem;
  border: 1.5px solid #e2e8f0;
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.ast-espera__dia-pill--next {
  color: #15803d;
  background: #dcfce7;
  border-color: #86efac;
  font-weight: 700;
  box-shadow: 0 2px 10px rgba(22,163,74,0.18);
}

@keyframes ast-float {
  0%, 100% { transform: translateY(0); }
  50%       { transform: translateY(-7px); }
}
@keyframes ast-blink {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0; }
}

@media (min-width: 480px) {
  .ast-espera__titulo  { font-size: 1.5rem; }
  .ast-cd-num          { font-size: 2.9rem; }
  .ast-cd-bloque       { min-width: 3.75rem; }
  .ast-espera__icon-wrap { width: 100px; height: 100px; }
  .ast-espera__icon    { font-size: 3.25rem; }
}
@media (min-width: 768px) {
  .ast-espera { max-width: 460px; margin: 0 auto; }
}
</style>
