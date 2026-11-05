<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import {
  diasService,
  observacionesService,
  programacionRubricaService,
  type DiasEvaluacion,
  type ObservacionConDetalle,
  type ObservacionConEquipo,
  type ProgramacionConCriterio,
  type PuntajeEquipoDia,
} from '@/modules/observaciones/services/observaciones.service'
import {
  programacionLiderazgoService,
  evaluacionesService,
  type ProgramacionLiderazgo,
  type LiderazgoEquipoDia,
} from '@/modules/liderazgo/services/liderazgo.service'
import LiderazgoCard from '@/modules/liderazgo/components/LiderazgoCard.vue'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import OnlineIndicator from '@/components/ui/OnlineIndicator.vue'

// ── Tipos ────────────────────────────────────────────────────────────────────
type EstadoGuardado = 'idle' | 'guardando' | 'guardado' | 'error'

interface FilaEstado {
  estado: EstadoGuardado
  puntaje: number | null
  comentario: string
  comentarioAbierto: boolean
}

// ── Constantes ────────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

// Solo mostrar días cuya fecha ya llegó (≤ hoy)
const hoy = computed(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}` })

// Días con programación ya disponibles (fecha ≤ hoy)
const momentosDisponibles = computed(() =>
  momentos.value.filter(m =>
    momentosConEvaluacion.value.includes(m) && (fechas.value[m] ?? '') <= hoy.value
  )
)

// Días que se muestran en el selector:
// - Admin: todos los días con criterios (puede navegar aunque aún no lleguen)
// - Evaluador: solo días ya llegados
const momentosSelector = computed<string[]>(() =>
  session.esAdmin
    ? momentos.value.filter(m => momentosConEvaluacion.value.includes(m))
    : momentosDisponibles.value
)

// Días con programación aún por llegar (fecha > hoy)
const momentosFuturos = computed(() =>
  momentos.value.filter(m => momentosConEvaluacion.value.includes(m) && (fechas.value[m] ?? '') > hoy.value)
)

// Próximo día a evaluar
const proximoMomento = computed(() => momentosFuturos.value[0] ?? null)

// Countdown al próximo día
const countdown = ref({ dias: 0, horas: 0, minutos: 0, segundos: 0 })

function calcularCountdown() {
  if (!proximoMomento.value) return
  const fechaProx = fechas.value[proximoMomento.value]
  if (!fechaProx) return
  const target  = new Date(fechaProx + 'T00:00:00')
  const diff    = target.getTime() - Date.now()
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

// Los 5 niveles de rúbrica (0 % → 100 % del puntaje_max del criterio)
const SCORE_NIVELES = [
  { idle: 'score-btn--0-idle',   active: 'score-btn--0-act',   label: 'Nulo',  descriptor: 'No cumple / No presente'         },
  { idle: 'score-btn--25-idle',  active: 'score-btn--25-act',  label: 'Def.',  descriptor: 'Deficiente — incumplimiento grave' },
  { idle: 'score-btn--50-idle',  active: 'score-btn--50-act',  label: 'Reg.',  descriptor: 'Regular — cumplimiento parcial'   },
  { idle: 'score-btn--75-idle',  active: 'score-btn--75-act',  label: 'Bien',  descriptor: 'Bueno — cumple lo esencial'       },
  { idle: 'score-btn--100-idle', active: 'score-btn--100-act', label: '¡Ok!',  descriptor: 'Excelente — cumplimiento total'   },
] as const

/** Devuelve los 5 valores de puntaje para un criterio dado su puntaje_max */
function puntajesPara(max: number): number[] {
  return [0, max * 0.25, max * 0.5, max * 0.75, max]
}

/** Índice de nivel (0-4) de un puntaje respecto al puntaje_max. -1 si no coincide. */
function nivelDe(puntaje: number | null | undefined, max: number): number {
  if (puntaje === null || puntaje === undefined) return -1
  return puntajesPara(max).indexOf(puntaje)
}

// ── Estado global ─────────────────────────────────────────────────────────────
const session   = useSessionStore()
const campStore = useCampamentoStore()
const cargando  = ref(true)
const error     = ref('')

const dias                    = ref<DiasEvaluacion[]>([])
const momentoActivo           = ref<string>('')
const momentosConEvaluacion   = ref<string[]>([])
const equipos          = ref<Equipo[]>([])
const programacionDia  = ref<ProgramacionConCriterio[]>([])
const puntajesDia      = ref<PuntajeEquipoDia[]>([])

const programacionLiderazgo  = ref<ProgramacionLiderazgo | null>(null)
const liderazgoResumenDia    = ref<LiderazgoEquipoDia[]>([])
const modoLiderazgoCriterio  = ref(false)

const equipoSeleccionado  = ref<Equipo | null>(null)
const criterioSeleccionado = ref<ProgramacionConCriterio | null>(null)

const obsByEquipo   = ref<Map<string, ObservacionConDetalle>>(new Map())
const obsByCriterio = ref<Map<string, ObservacionConEquipo>>(new Map())

const filasEquipo   = ref<Map<string, FilaEstado>>(new Map())
const filasCriterio = ref<Map<string, FilaEstado>>(new Map())

// Tab activo (lista): 'equipos' | 'criterios'
const tabActivo = ref<'equipos' | 'criterios'>('equipos')

// ── Dialog motivo cambio ──────────────────────────────────────────────────────
const dialogMotivo    = ref(false)
const motivoPendiente = ref('')
const callbackMotivo  = ref<((motivo: string) => void) | null>(null)

// ── Dialog info criterio ──────────────────────────────────────────────────────
const dialogInfo  = ref(false)
const criterioInfo = ref<ProgramacionConCriterio | null>(null)

// ── Carga inicial ──────────────────────────────────────────────────────────────
async function cargar() {
  // Si ya hay datos en memoria y estamos offline → quedarse donde se está,
  // solo actualizar en silencio cuando vuelva la red.
  const yaHayDatos = momentosConEvaluacion.value.length > 0 && equipos.value.length > 0
  if (yaHayDatos && !navigator.onLine) return

  cargando.value = true
  error.value    = ''
  equipoSeleccionado.value  = null
  criterioSeleccionado.value = null
  modoLiderazgoCriterio.value = false
  obsByEquipo.value   = new Map()
  obsByCriterio.value = new Map()
  try {
    const [, diasData, equiposData, momentosData] = await Promise.all([
      cargarCampamento(),
      campStore.selectedId ? diasService.getTodos(campStore.selectedId) : Promise.resolve([]),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      programacionRubricaService.getMomentosConProgramacion(campStore.selectedId),
    ])
    momentosConEvaluacion.value = momentosData
    dias.value    = diasData
    equipos.value = equiposData.filter((e) => e.activo)
    const hoyVal    = hoy.value
    const hoyMomento = momentosData.find(m => fechas.value[m] === hoyVal)
    if (hoyMomento) {
      momentoActivo.value = hoyMomento
    } else {
      const pasados = momentosData.filter(m => fechas.value[m] && fechas.value[m] < hoyVal)
      momentoActivo.value = pasados[pasados.length - 1] ?? ''
    }
    if (momentoActivo.value) await cargarProgramacionDia()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

// ── Helpers ───────────────────────────────────────────────────────────────────
const diaActual = computed<DiasEvaluacion | undefined>(() =>
  dias.value.find((d) => d.momento === momentoActivo.value),
)
const diaCerrado = computed(() => diaActual.value?.cerrado ?? false)

// ── Cambio de día ─────────────────────────────────────────────────────────────
async function seleccionarMomento(m: string) {
  momentoActivo.value        = m
  equipoSeleccionado.value   = null
  criterioSeleccionado.value = null
  modoLiderazgoCriterio.value = false
  obsByEquipo.value   = new Map()
  obsByCriterio.value = new Map()
  filasEquipo.value   = new Map()
  filasCriterio.value = new Map()
  await cargarProgramacionDia()
}

async function cargarProgramacionDia() {
  const campId = campStore.selectedId
  const { data, error: err } = await supabase_safe(() =>
    programacionRubricaService.getPorDia(momentoActivo.value, campId),
  )
  if (err || !data) { error.value = err ?? 'Error al cargar programación'; return }
  programacionDia.value = data

  const [ptsResult, lidProgResult, lidResumenResult] = await Promise.all([
    supabase_safe(() => observacionesService.getPuntajeEquipoDia(momentoActivo.value, campId)),
    supabase_safe(() => programacionLiderazgoService.getPorDia(momentoActivo.value, campId)),
    supabase_safe(() => evaluacionesService.getResumenDia(momentoActivo.value, campId)),
  ])
  if (ptsResult.data)       puntajesDia.value        = ptsResult.data
  programacionLiderazgo.value = lidProgResult.data
  liderazgoResumenDia.value   = lidResumenResult.data ?? []
}

async function supabase_safe<T>(fn: () => Promise<T>): Promise<{ data: T; error: null } | { data: null; error: string }> {
  try   { return { data: await fn(), error: null } }
  catch (e: unknown) { return { data: null, error: e instanceof Error ? e.message : 'Error desconocido' } }
}

// ── Vista por equipo ──────────────────────────────────────────────────────────
async function seleccionarEquipo(equipo: Equipo) {
  equipoSeleccionado.value  = equipo
  criterioSeleccionado.value = null
  obsByEquipo.value  = new Map()
  filasEquipo.value  = new Map()

  const { data } = await supabase_safe(() =>
    observacionesService.getPorEquipoYDia(equipo.id, momentoActivo.value, session.user!.id),
  )
  if (!data) return
  for (const obs of data) obsByEquipo.value.set(obs.programacion.id, obs)
  for (const prog of programacionDia.value) {
    const obs = obsByEquipo.value.get(prog.id)
    filasEquipo.value.set(prog.id, {
      estado: 'idle',
      puntaje: obs?.puntaje ?? null,
      comentario: obs?.comentario ?? '',
      comentarioAbierto: false,
    })
  }
}

// ── Vista por criterio ────────────────────────────────────────────────────────
async function seleccionarCriterio(prog: ProgramacionConCriterio) {
  criterioSeleccionado.value = prog
  equipoSeleccionado.value   = null
  obsByCriterio.value  = new Map()
  filasCriterio.value  = new Map()

  const { data } = await supabase_safe(() =>
    observacionesService.getPorCriterioYDia(prog.id, session.user!.id),
  )
  if (!data) return
  for (const obs of data) obsByCriterio.value.set(obs.equipo_id, obs)
  for (const equipo of equipos.value) {
    const obs = obsByCriterio.value.get(equipo.id)
    filasCriterio.value.set(equipo.id, {
      estado: 'idle',
      puntaje: obs?.puntaje ?? null,
      comentario: obs?.comentario ?? '',
      comentarioAbierto: false,
    })
  }
}

// ── Guardado de puntaje ───────────────────────────────────────────────────────
async function guardarPuntaje(
  filasMap: Map<string, FilaEstado>,
  clave: string,
  nuevoPuntaje: number,
  equipo_id: string,
  programacion_id: string,
  motivo?: string,
) {
  const fila = filasMap.get(clave)
  if (!fila) return
  const anterior = fila.puntaje
  fila.puntaje = nuevoPuntaje
  fila.estado  = 'guardando'
  try {
    await observacionesService.upsert({
      equipo_id, programacion_id,
      puntaje: nuevoPuntaje,
      comentario: fila.comentario || null,
      evaluador_id: session.user!.id,
      motivo_cambio: motivo ?? null,
    })
    fila.estado = 'guardado'
    setTimeout(() => { if (fila.estado === 'guardado') fila.estado = 'idle' }, 2000)
  } catch {
    fila.puntaje = anterior
    fila.estado  = 'error'
  }
}

async function onPuntajeEquipo(prog: ProgramacionConCriterio, pts: number) {
  if (diaCerrado.value || !equipoSeleccionado.value) return
  const fila = filasEquipo.value.get(prog.id)
  if (!fila) return
  if (fila.puntaje !== null && fila.puntaje !== pts) {
    motivoPendiente.value = ''
    dialogMotivo.value    = true
    callbackMotivo.value  = (m) => guardarPuntaje(filasEquipo.value, prog.id, pts, equipoSeleccionado.value!.id, prog.id, m)
  } else {
    guardarPuntaje(filasEquipo.value, prog.id, pts, equipoSeleccionado.value!.id, prog.id)
  }
}

async function onPuntajeCriterio(equipo: Equipo, pts: number) {
  if (diaCerrado.value || !criterioSeleccionado.value) return
  const fila = filasCriterio.value.get(equipo.id)
  if (!fila) return
  if (fila.puntaje !== null && fila.puntaje !== pts) {
    motivoPendiente.value = ''
    dialogMotivo.value    = true
    callbackMotivo.value  = (m) => guardarPuntaje(filasCriterio.value, equipo.id, pts, equipo.id, criterioSeleccionado.value!.id, m)
  } else {
    guardarPuntaje(filasCriterio.value, equipo.id, pts, equipo.id, criterioSeleccionado.value!.id)
  }
}

function confirmarMotivo() {
  callbackMotivo.value?.(motivoPendiente.value)
  callbackMotivo.value = null
  dialogMotivo.value   = false
}

// ── Progreso ──────────────────────────────────────────────────────────────────
function progresoEquipo(equipo: Equipo): { calificados: number; total: number } {
  if (equipoSeleccionado.value?.id === equipo.id) {
    let c = 0, t = 0
    for (const [, f] of filasEquipo.value) { t++; if (f.puntaje !== null) c++ }
    return { calificados: c, total: t }
  }
  const dato = puntajesDia.value.find((p) => p.equipo_id === equipo.id)
  if (dato) return { calificados: dato.criterios_calificados ?? 0, total: (dato.criterios_calificados ?? 0) + (dato.criterios_pendientes ?? 0) }
  return { calificados: 0, total: programacionDia.value.filter((p) => p.estado === 'programado').length }
}

function progresoCriterio(prog: ProgramacionConCriterio): { calificados: number; total: number } {
  if (criterioSeleccionado.value?.id === prog.id) {
    let c = 0
    for (const [, f] of filasCriterio.value) if (f.puntaje !== null) c++
    return { calificados: c, total: equipos.value.length }
  }
  return { calificados: 0, total: equipos.value.length }
}

const progresoCriterioLiderazgo = computed(() => {
  const total    = equipos.value.length
  if (!total) return '0/0'
  const completos = liderazgoResumenDia.value.filter(
    (r) => r.indicadores_calificados === r.total_indicadores && (r.total_indicadores ?? 0) > 0,
  ).length
  return `${completos}/${total}`
})

function abrirInfoCriterio(prog: ProgramacionConCriterio) {
  criterioInfo.value = prog
  dialogInfo.value   = true
}

// ── Helpers CSS ───────────────────────────────────────────────────────────────
function pctBar(c: number, t: number) {
  return t === 0 ? 0 : Math.round((c / t) * 100)
}
</script>

<template>
  <div class="ev">

    <!-- ══════════════════════════════════════════
         CARGANDO
    ══════════════════════════════════════════ -->
    <div v-if="cargando" class="ev-loading">
      <div class="ev-loading__ring" />
      <p>Cargando evaluación…</p>
    </div>

    <!-- ══════════════════════════════════════════
         ERROR
    ══════════════════════════════════════════ -->
    <div v-else-if="error" class="ev-error">
      <i class="pi pi-exclamation-circle ev-error__icon" />
      <p>{{ error }}</p>
    </div>

    <template v-else>

      <!-- ══════════════════════════════════════════
           SIN DÍAS DISPONIBLES AÚN — pantalla de espera
      ══════════════════════════════════════════ -->
      <div v-if="momentosDisponibles.length === 0 && !session.esAdmin" class="ev-espera">

        <!-- Icono animado -->
        <div class="ev-espera__icon-wrap">
          <span class="ev-espera__icon">⛺</span>
        </div>

        <!-- Título -->
        <div class="ev-espera__copy">
          <h2 class="ev-espera__titulo">La evaluación comenzará pronto</h2>
          <p v-if="proximoMomento" class="ev-espera__sub">
            Próximo día de evaluación
          </p>
          <p v-if="proximoMomento" class="ev-espera__next-day">
            {{ labelDia(proximoMomento) }}
          </p>
        </div>

        <!-- Countdown -->
        <div v-if="proximoMomento" class="ev-espera__countdown">
          <div class="ev-cd-bloque">
            <span class="ev-cd-num">{{ String(countdown.dias).padStart(2,'0') }}</span>
            <span class="ev-cd-label">días</span>
          </div>
          <span class="ev-cd-sep">:</span>
          <div class="ev-cd-bloque">
            <span class="ev-cd-num">{{ String(countdown.horas).padStart(2,'0') }}</span>
            <span class="ev-cd-label">horas</span>
          </div>
          <span class="ev-cd-sep">:</span>
          <div class="ev-cd-bloque">
            <span class="ev-cd-num">{{ String(countdown.minutos).padStart(2,'0') }}</span>
            <span class="ev-cd-label">min</span>
          </div>
          <span class="ev-cd-sep">:</span>
          <div class="ev-cd-bloque ev-cd-seg">
            <span class="ev-cd-num">{{ String(countdown.segundos).padStart(2,'0') }}</span>
            <span class="ev-cd-label">seg</span>
          </div>
        </div>

        <!-- Días futuros -->
        <div v-if="momentosFuturos.length" class="ev-espera__dias">
          <p class="ev-espera__dias-label">Días programados</p>
          <div class="ev-espera__dias-row">
            <span
              v-for="m in momentosFuturos"
              :key="m"
              class="ev-espera__dia-pill"
              :class="{ 'ev-espera__dia-pill--next': m === proximoMomento }"
            >
              <i v-if="m === proximoMomento" class="pi pi-clock" style="font-size:0.65rem;" />
              {{ labelDia(m) }}
            </span>
          </div>
        </div>

      </div>

      <!-- ── Selector de días ──────────────────────────────────────── -->
      <div v-else class="ev-days-wrap">
        <div class="ev-days-header">
          <span class="ev-days-title">Día a evaluar</span>
        </div>
        <div class="ev-days">
          <button
            v-for="m in momentosSelector"
            :key="m"
            class="ev-day"
            :class="{
              'ev-day--active':  momentoActivo === m,
              'ev-day--locked':  dias.find((d) => d.momento === m)?.cerrado,
            }"
            @click="seleccionarMomento(m)"
          >
            <span class="ev-day__label">{{ labelDia(m) }}</span>
            <span v-if="fechas[m] === hoy" class="ev-day__hoy">Hoy</span>
            <span
              v-if="dias.find((d) => d.momento === m)?.cerrado"
              class="ev-day__lock"
            >
              <i class="pi pi-lock" />
            </span>
          </button>
        </div>
      </div>

      <!-- Hint admin: ningún día seleccionado -->
      <div v-if="session.esAdmin && momentoActivo === ''" class="ev-admin-hint">
        <div class="ev-admin-hint__card">
          <div class="ev-admin-hint__icon-wrap">
            <i class="pi pi-calendar-clock ev-admin-hint__icon" />
          </div>
          <h3 class="ev-admin-hint__title">Selecciona un día</h3>
          <p class="ev-admin-hint__text">Elige uno de los días que aparecen arriba para ver y registrar la evaluación.</p>
        </div>
      </div>

      <!-- Banner día cerrado -->
      <div v-if="momentoActivo !== '' && diaCerrado" class="ev-banner-locked">
        <i class="pi pi-lock" />
        <span>Día cerrado — solo lectura</span>
      </div>

      <!-- ══════════════════════════════════════════
           VISTA: Detalle por equipo
      ══════════════════════════════════════════ -->
      <template v-if="momentoActivo !== '' && equipoSeleccionado">
        <!-- Header equipo -->
        <div class="ev-detail-header">
          <button class="ev-back" @click="equipoSeleccionado = null">
            <i class="pi pi-arrow-left" />
          </button>
          <span class="ev-dot" :style="{ background: equipoSeleccionado.color }" />
          <div class="ev-detail-header__info">
            <span class="ev-detail-header__name">{{ equipoSeleccionado.nombre }}</span>
            <span class="ev-detail-header__sub">
              {{ progresoEquipo(equipoSeleccionado).calificados }}/{{ progresoEquipo(equipoSeleccionado).total }} criterios
            </span>
          </div>
        </div>

        <!-- Barra de progreso del equipo -->
        <div class="ev-detail-prog">
          <div class="ev-detail-prog__fill" :style="{
            width: pctBar(progresoEquipo(equipoSeleccionado).calificados, progresoEquipo(equipoSeleccionado).total) + '%',
            background: equipoSeleccionado.color,
          }" />
        </div>

        <div class="ev-cards">
          <div
            v-for="prog in programacionDia"
            :key="prog.id"
            class="ev-criterio-card"
            :class="{
              'ev-criterio-card--done':     filasEquipo.get(prog.id)?.puntaje !== null,
              'ev-criterio-card--inactive': prog.estado !== 'programado',
            }"
          >
            <!-- Cabecera criterio -->
            <div class="ev-cc-header">
              <div class="ev-cc-meta">
                <span class="ev-cat-badge">{{ prog.criterios.categoria }}</span>
                <span class="ev-cc-name">{{ prog.criterios.nombre }}</span>
              </div>
              <div class="ev-cc-actions">
                <!-- Estado guardado -->
                <span v-if="filasEquipo.get(prog.id)?.estado === 'guardando'" class="ev-save-dot ev-save-dot--saving" />
                <span v-else-if="filasEquipo.get(prog.id)?.estado === 'guardado'" class="ev-save-dot ev-save-dot--ok">
                  <i class="pi pi-check" />
                </span>
                <span v-else-if="filasEquipo.get(prog.id)?.estado === 'error'" class="ev-save-dot ev-save-dot--err">
                  <i class="pi pi-times" />
                </span>
                <button class="ev-info-btn" @click="abrirInfoCriterio(prog)">
                  <i class="pi pi-info-circle" />
                </button>
              </div>
            </div>

            <!-- No aplica / Cancelado -->
            <div v-if="prog.estado === 'no_programado'" class="ev-inactive-msg">
              <i class="pi pi-minus-circle" /> No aplica este día
            </div>
            <div v-else-if="prog.estado === 'cancelado'" class="ev-inactive-msg ev-inactive-msg--cancel">
              <i class="pi pi-ban" /> Cancelado
              <span v-if="prog.motivo" class="ev-inactive-motivo"> — {{ prog.motivo }}</span>
            </div>

            <!-- Botones de puntaje -->
            <template v-else>
              <div class="ev-scores">
                <button
                  v-for="(pts, idx) in puntajesPara(prog.puntaje_max)"
                  :key="pts"
                  class="ev-score-btn"
                  :class="[
                    filasEquipo.get(prog.id)?.puntaje === pts
                      ? SCORE_NIVELES[idx]!.active
                      : SCORE_NIVELES[idx]!.idle,
                    { 'ev-score-btn--locked': diaCerrado },
                  ]"
                  :disabled="diaCerrado"
                  @click="onPuntajeEquipo(prog, pts)"
                >
                  <span class="ev-score-num">{{ pts }}</span>
                  <span
                    v-if="filasEquipo.get(prog.id)?.puntaje === pts"
                    class="ev-score-label"
                  >{{ SCORE_NIVELES[idx]!.label }}</span>
                </button>
              </div>

              <!-- Descriptor -->
              <div
                v-if="filasEquipo.get(prog.id)?.puntaje !== null && filasEquipo.get(prog.id)?.puntaje !== undefined"
                class="ev-descriptor"
              >
                <i class="pi pi-info-circle" />
                {{ SCORE_NIVELES[nivelDe(filasEquipo.get(prog.id)?.puntaje, prog.puntaje_max)]?.descriptor }}
              </div>

              <!-- Comentario -->
              <div class="ev-comment-wrap">
                <button
                  class="ev-comment-toggle"
                  @click="() => { const f = filasEquipo.get(prog.id); if (f) f.comentarioAbierto = !f.comentarioAbierto }"
                >
                  <i :class="filasEquipo.get(prog.id)?.comentarioAbierto ? 'pi pi-chevron-up' : 'pi pi-comment'" />
                  <span>{{ filasEquipo.get(prog.id)?.comentarioAbierto ? 'Cerrar' : 'Comentario' }}</span>
                </button>
                <Textarea
                  v-if="filasEquipo.get(prog.id)?.comentarioAbierto"
                  v-model="filasEquipo.get(prog.id)!.comentario"
                  rows="2"
                  class="ev-comment-input"
                  placeholder="Comentario interno…"
                  :disabled="diaCerrado"
                />
              </div>
            </template>
          </div>
        </div>

        <!-- Liderazgo del día -->
        <LiderazgoCard
          v-if="programacionLiderazgo"
          :equipoId="equipoSeleccionado.id"
          :programacionId="programacionLiderazgo.id"
          :readonly="diaCerrado"
          class="ev-liderazgo-card"
        />
      </template>

      <!-- ══════════════════════════════════════════
           VISTA: Liderazgo por criterio (todos los equipos)
      ══════════════════════════════════════════ -->
      <template v-else-if="momentoActivo !== '' && modoLiderazgoCriterio && programacionLiderazgo">
        <div class="ev-detail-header">
          <button class="ev-back" @click="modoLiderazgoCriterio = false">
            <i class="pi pi-arrow-left" />
          </button>
          <div class="ev-lid-icon">
            <i class="pi pi-bolt" />
          </div>
          <div class="ev-detail-header__info">
            <span class="ev-detail-header__name">Liderazgo de servicio</span>
            <span class="ev-detail-header__sub">{{ progresoCriterioLiderazgo }} equipos completos</span>
          </div>
        </div>

        <div class="ev-cards">
          <div v-for="equipo in equipos" :key="equipo.id" class="ev-criterio-card">
            <div class="ev-cc-header">
              <span class="ev-dot ev-dot--sm" :style="{ background: equipo.color }" />
              <span class="ev-cc-name">{{ equipo.nombre }}</span>
            </div>
            <LiderazgoCard
              :equipoId="equipo.id"
              :programacionId="programacionLiderazgo.id"
              :readonly="diaCerrado"
              compact
            />
          </div>
        </div>
      </template>

      <!-- ══════════════════════════════════════════
           VISTA: Detalle por criterio (todos los equipos)
      ══════════════════════════════════════════ -->
      <template v-else-if="momentoActivo !== '' && criterioSeleccionado">
        <div class="ev-detail-header">
          <button class="ev-back" @click="criterioSeleccionado = null">
            <i class="pi pi-arrow-left" />
          </button>
          <div class="ev-detail-header__info">
            <span class="ev-cat-badge">{{ criterioSeleccionado.criterios.categoria }}</span>
            <span class="ev-detail-header__name">{{ criterioSeleccionado.criterios.nombre }}</span>
          </div>
        </div>

        <div class="ev-cards">
          <div v-for="equipo in equipos" :key="equipo.id" class="ev-criterio-card"
               :class="{ 'ev-criterio-card--done': filasCriterio.get(equipo.id)?.puntaje !== null }">
            <div class="ev-cc-header">
              <span class="ev-dot ev-dot--sm" :style="{ background: equipo.color }" />
              <span class="ev-cc-name">{{ equipo.nombre }}</span>
              <div class="ev-cc-actions">
                <span v-if="filasCriterio.get(equipo.id)?.estado === 'guardando'" class="ev-save-dot ev-save-dot--saving" />
                <span v-else-if="filasCriterio.get(equipo.id)?.estado === 'guardado'" class="ev-save-dot ev-save-dot--ok"><i class="pi pi-check" /></span>
                <span v-else-if="filasCriterio.get(equipo.id)?.estado === 'error'" class="ev-save-dot ev-save-dot--err"><i class="pi pi-times" /></span>
              </div>
            </div>

            <div class="ev-scores">
              <button
                v-for="(pts, idx) in puntajesPara(criterioSeleccionado!.puntaje_max)"
                :key="pts"
                class="ev-score-btn"
                :class="[
                  filasCriterio.get(equipo.id)?.puntaje === pts
                    ? SCORE_NIVELES[idx]!.active
                    : SCORE_NIVELES[idx]!.idle,
                  { 'ev-score-btn--locked': diaCerrado },
                ]"
                :disabled="diaCerrado"
                @click="onPuntajeCriterio(equipo, pts)"
              >
                <span class="ev-score-num">{{ pts }}</span>
                <span v-if="filasCriterio.get(equipo.id)?.puntaje === pts" class="ev-score-label">
                  {{ SCORE_NIVELES[idx]!.label }}
                </span>
              </button>
            </div>

            <div
              v-if="filasCriterio.get(equipo.id)?.puntaje !== null && filasCriterio.get(equipo.id)?.puntaje !== undefined"
              class="ev-descriptor"
            >
              <i class="pi pi-info-circle" />
              {{ SCORE_NIVELES[nivelDe(filasCriterio.get(equipo.id)?.puntaje, criterioSeleccionado!.puntaje_max)]?.descriptor }}
            </div>

            <div class="ev-comment-wrap">
              <button
                class="ev-comment-toggle"
                @click="() => { const f = filasCriterio.get(equipo.id); if (f) f.comentarioAbierto = !f.comentarioAbierto }"
              >
                <i :class="filasCriterio.get(equipo.id)?.comentarioAbierto ? 'pi pi-chevron-up' : 'pi pi-comment'" />
                <span>{{ filasCriterio.get(equipo.id)?.comentarioAbierto ? 'Cerrar' : 'Comentario' }}</span>
              </button>
              <Textarea
                v-if="filasCriterio.get(equipo.id)?.comentarioAbierto"
                v-model="filasCriterio.get(equipo.id)!.comentario"
                rows="2"
                class="ev-comment-input"
                placeholder="Comentario interno…"
                :disabled="diaCerrado"
              />
            </div>
          </div>
        </div>
      </template>

      <!-- ══════════════════════════════════════════
           VISTA: Lista principal (tabs)
      ══════════════════════════════════════════ -->
      <template v-else-if="momentoActivo !== ''">

        <!-- Contexto del día activo -->
        <div class="ev-ctx-bar">
          <span class="ev-ctx-day">{{ labelDia(momentoActivo) }}</span>
          <span v-if="diaCerrado" class="ev-ctx-locked"><i class="pi pi-lock" /> Solo lectura</span>
        </div>

        <!-- Tabs custom -->
        <div class="ev-tabs">
          <button
            class="ev-tab"
            :class="{ 'ev-tab--active': tabActivo === 'equipos' }"
            @click="tabActivo = 'equipos'"
          >
            <i class="pi pi-users" />
            <span>Por equipo</span>
          </button>
          <button
            class="ev-tab"
            :class="{ 'ev-tab--active': tabActivo === 'criterios' }"
            @click="tabActivo = 'criterios'"
          >
            <i class="pi pi-list-check" />
            <span>Por criterio</span>
          </button>
        </div>

        <!-- Tab: Equipos -->
        <div v-if="tabActivo === 'equipos'" class="ev-list">
          <button
            v-for="equipo in equipos"
            :key="equipo.id"
            class="ev-equipo-card"
            @click="seleccionarEquipo(equipo)"
          >
            <!-- Color strip + nombre -->
            <span class="ev-ec-strip" :style="{ background: equipo.color }" />
            <div class="ev-ec-body">
              <div class="ev-ec-top">
                <span class="ev-ec-name">{{ equipo.nombre }}</span>
                <span
                  class="ev-ec-badge"
                  :class="{
                    'ev-ec-badge--done': progresoEquipo(equipo).calificados === progresoEquipo(equipo).total && progresoEquipo(equipo).total > 0,
                  }"
                >
                  {{ progresoEquipo(equipo).calificados }}/{{ progresoEquipo(equipo).total }}
                </span>
              </div>
              <!-- Barra de progreso -->
              <div class="ev-progress-bar">
                <div
                  class="ev-progress-fill"
                  :style="{
                    width: pctBar(progresoEquipo(equipo).calificados, progresoEquipo(equipo).total) + '%',
                    background: equipo.color,
                  }"
                />
              </div>
            </div>
            <i class="pi pi-chevron-right ev-ec-chevron" />
          </button>
          <p v-if="!equipos.length" class="ev-empty">
            <i class="pi pi-inbox" /> Sin equipos activos
          </p>
        </div>

        <!-- Tab: Criterios -->
        <div v-else class="ev-list">
          <button
            v-for="prog in programacionDia"
            :key="prog.id"
            class="ev-criterio-row"
            :class="{ 'ev-criterio-row--inactive': prog.estado !== 'programado' }"
            :disabled="prog.estado !== 'programado'"
            @click="prog.estado === 'programado' && seleccionarCriterio(prog)"
          >
            <div class="ev-cr-left">
              <span class="ev-cat-badge">{{ prog.criterios.categoria }}</span>
              <span class="ev-cr-name">{{ prog.criterios.nombre }}</span>
            </div>
            <span v-if="prog.estado === 'cancelado'" class="ev-status-badge ev-status-badge--cancel">
              Cancelado
            </span>
            <span v-else-if="prog.estado === 'no_programado'" class="ev-status-badge ev-status-badge--na">
              N/A
            </span>
            <span v-else class="ev-cr-chip">
              {{ progresoCriterio(prog).calificados }}/{{ progresoCriterio(prog).total }}
            </span>
            <i v-if="prog.estado === 'programado'" class="pi pi-chevron-right ev-ec-chevron" />
          </button>

          <p v-if="!programacionDia.length && !programacionLiderazgo" class="ev-empty">
            <i class="pi pi-calendar-times" /> Sin criterios de rúbrica para este día
          </p>

          <!-- Fila Liderazgo -->
          <button
            v-if="programacionLiderazgo"
            class="ev-criterio-row ev-criterio-row--lid"
            @click="modoLiderazgoCriterio = true"
          >
            <div class="ev-cr-left">
              <span class="ev-cat-badge ev-cat-badge--lid"><i class="pi pi-bolt" /></span>
              <span class="ev-cr-name">Liderazgo de servicio</span>
            </div>
            <span class="ev-cr-chip ev-cr-chip--lid">{{ progresoCriterioLiderazgo }}</span>
            <i class="pi pi-chevron-right ev-ec-chevron" />
          </button>
        </div>
      </template>

    </template><!-- /v-else (not loading, not error) -->

    <!-- ══════════════════════════════════════════
         DIALOG: Motivo de cambio
    ══════════════════════════════════════════ -->
    <Dialog
      v-model:visible="dialogMotivo"
      header="Motivo del cambio"
      modal
      :style="{ width: 'min(26rem, 95vw)' }"
    >
      <p class="ev-dialog-text">Este criterio ya tenía un puntaje. Indica el motivo:</p>
      <Textarea
        v-model="motivoPendiente"
        rows="3"
        class="ev-dialog-textarea"
        placeholder="Ej: Corrección tras revisión…"
        autofocus
      />
      <template #footer>
        <div class="ev-dialog-footer">
          <button class="ev-btn-secondary" @click="dialogMotivo = false">Cancelar</button>
          <button
            class="ev-btn-primary"
            :disabled="!motivoPendiente.trim()"
            @click="confirmarMotivo"
          >
            <i class="pi pi-check" /> Confirmar
          </button>
        </div>
      </template>
    </Dialog>

    <!-- ══════════════════════════════════════════
         DIALOG: Info criterio
    ══════════════════════════════════════════ -->
    <Dialog
      v-model:visible="dialogInfo"
      :header="criterioInfo?.criterios.nombre ?? 'Criterio'"
      modal
      :style="{ width: 'min(30rem, 95vw)' }"
    >
      <template v-if="criterioInfo">
        <div v-if="criterioInfo.criterios.abarca" class="ev-info-block">
          <p class="ev-info-label"><i class="pi pi-check-circle" /> Abarca</p>
          <p class="ev-info-text">{{ criterioInfo.criterios.abarca }}</p>
        </div>
        <div v-if="criterioInfo.criterios.no_abarca" class="ev-info-block">
          <p class="ev-info-label"><i class="pi pi-times-circle" /> No abarca</p>
          <p class="ev-info-text">{{ criterioInfo.criterios.no_abarca }}</p>
        </div>
        <div v-if="criterioInfo.criterios.evidencia" class="ev-info-block">
          <p class="ev-info-label"><i class="pi pi-camera" /> Evidencia</p>
          <p class="ev-info-text">{{ criterioInfo.criterios.evidencia }}</p>
        </div>
        <div class="ev-rubrica-grid">
          <div
            v-for="(nivel, idx) in SCORE_NIVELES"
            :key="idx"
            class="ev-rubrica-row"
          >
            <span class="ev-rubrica-pts" :class="nivel.active">{{ nivel.label }}</span>
            <span class="ev-rubrica-desc">{{ nivel.descriptor }}</span>
          </div>
        </div>
      </template>
      <template #footer>
        <button class="ev-btn-primary" @click="dialogInfo = false">Cerrar</button>
      </template>
    </Dialog>

  </div>
</template>

<style scoped>
/* ═══════════════════════════════════════════════════════════
   BASE
═══════════════════════════════════════════════════════════ */
.ev {
  padding: 0 0 5rem;
  min-height: 100%;
  font-size: 16px;
}

/* ── Loading ── */
.ev-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 5rem 1rem;
  color: #94a3b8;
}
.ev-loading__ring {
  width: 42px; height: 42px;
  border: 3px solid #d1fae5;
  border-top-color: #059669;
  border-radius: 50%;
  animation: spin 0.75s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.ev-loading p { font-size: 0.88rem; }

/* ── Error ── */
.ev-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1.5rem;
  text-align: center;
  color: #dc2626;
}
.ev-error__icon { font-size: 2rem; }
.ev-error p { font-size: 0.9rem; }

/* ── Hint admin sin día seleccionado ── */
.ev-admin-hint {
  display: flex;
  justify-content: center;
  padding: 2rem 1rem;
}
.ev-admin-hint__card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
  border: 1.5px solid #a7f3d0;
  border-radius: 20px;
  padding: 2rem;
  text-align: center;
  max-width: 320px;
  width: 100%;
  box-shadow: 0 4px 16px rgba(5,150,105,0.08);
}
.ev-admin-hint__icon-wrap {
  width: 56px; height: 56px;
  border-radius: 50%;
  background: #d1fae5;
  border: 2px solid #6ee7b7;
  display: flex; align-items: center; justify-content: center;
}
.ev-admin-hint__icon { font-size: 1.6rem; color: #059669; }
.ev-admin-hint__title { font-size: 1rem; font-weight: 700; color: #047857; margin: 0; }
.ev-admin-hint__text  { font-size: 0.85rem; color: #4b5563; margin: 0; line-height: 1.5; }

/* ── Banner día cerrado (global, entre vistas) ── */
.ev-banner-locked {
  display: none; /* Sustituido por ev-ctx-locked dentro del ctx-bar */
}

/* ═══════════════════════════════════════════════════════════
   SELECTOR DE DÍAS
═══════════════════════════════════════════════════════════ */
.ev-days-wrap {
  background: white;
  border-bottom: 1.5px solid #f0f4f8;
}

/* Cabecera: label + indicador online */
.ev-days-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.875rem 1rem 0.4rem;
}
.ev-days-title {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: #94a3b8;
}

/* Strip horizontal con scroll nativo */
.ev-days {
  display: flex;
  gap: 0.55rem;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  padding: 0.4rem 1rem 1rem;
}
.ev-days::-webkit-scrollbar { display: none; }

.ev-day {
  scroll-snap-align: start;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  padding: 0.75rem 1.25rem;
  border-radius: 18px;
  border: 2px solid #e8edf2;
  background: #fafbfc;
  cursor: pointer;
  transition: all 0.2s cubic-bezier(.4,0,.2,1);
  min-height: 68px;
  min-width: 86px;
  -webkit-tap-highlight-color: transparent;
  box-shadow: 0 1px 3px rgba(0,0,0,.06);
  user-select: none;
}
.ev-day:active { transform: scale(0.94); }
.ev-day:hover {
  border-color: #6ee7b7;
  background: #ecfdf5;
  box-shadow: 0 3px 10px rgba(5,150,105,.13);
}
.ev-day--active {
  border-color: #059669;
  background: linear-gradient(150deg, #10b981 0%, #047857 100%);
  color: white;
  box-shadow: 0 6px 20px rgba(5,150,105,.4);
  transform: translateY(-2px);
}
.ev-day--active .ev-day__label { color: white; }
.ev-day--active .ev-day__hoy   { background: rgba(255,255,255,.22); color: rgba(255,255,255,.95); border-color: transparent; }
.ev-day--locked                { opacity: 0.48; }

.ev-day__label {
  font-size: 0.9rem;
  font-weight: 800;
  letter-spacing: 0.01em;
  line-height: 1.2;
  color: #334155;
}
.ev-day__lock { font-size: 0.72rem; color: #b45309; }
.ev-day__hoy {
  font-size: 0.58rem;
  font-weight: 800;
  text-transform: uppercase;
  background: #d1fae5;
  color: #059669;
  border: 1px solid #6ee7b7;
  padding: 0.08rem 0.45rem;
  border-radius: 20px;
  letter-spacing: .06em;
  white-space: nowrap;
}

/* ══════════════════════════════════════════════════════════
   PANTALLA DE ESPERA
══════════════════════════════════════════════════════════ */
.ev-espera {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1.75rem;
  padding: 3rem 1.25rem 4rem;
  min-height: 72vh;
  text-align: center;
}
.ev-espera__icon-wrap {
  width: 88px; height: 88px;
  border-radius: 50%;
  background: linear-gradient(135deg, #ecfdf5, #d1fae5);
  border: 2px solid #a7f3d0;
  box-shadow: 0 8px 24px rgba(5,150,105,0.14);
  display: flex; align-items: center; justify-content: center;
  animation: ev-float 3s ease-in-out infinite;
}
.ev-espera__icon { font-size: 2.75rem; line-height: 1; }
.ev-espera__copy { display: flex; flex-direction: column; align-items: center; gap: 0.4rem; }
.ev-espera__titulo {
  font-size: 1.3rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0;
  letter-spacing: -0.02em;
  line-height: 1.25;
}
.ev-espera__sub {
  font-size: 0.8rem; color: #94a3b8; margin: 0;
  text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600;
}
.ev-espera__next-day { font-size: 1rem; font-weight: 700; color: #059669; margin: 0; }
.ev-espera__countdown {
  display: flex; align-items: center; gap: 0.4rem;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
  border: 1.5px solid #a7f3d0;
  border-radius: 22px;
  padding: 1.25rem 1.5rem;
  box-shadow: 0 4px 20px rgba(5,150,105,0.1);
}
.ev-cd-bloque { display: flex; flex-direction: column; align-items: center; gap: 0.25rem; min-width: 3rem; }
.ev-cd-num { font-size: 2.4rem; font-weight: 800; line-height: 1; color: #0f172a; font-variant-numeric: tabular-nums; letter-spacing: -0.03em; }
.ev-cd-seg .ev-cd-num { color: #059669; }
.ev-cd-label { font-size: 0.58rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; color: #94a3b8; }
.ev-cd-sep { font-size: 1.75rem; font-weight: 300; color: #6ee7b7; margin-bottom: 1.2rem; user-select: none; animation: ev-blink 1s step-end infinite; }
.ev-espera__dias { display: flex; flex-direction: column; align-items: center; gap: 0.6rem; }
.ev-espera__dias-label { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: #cbd5e1; margin: 0; }
.ev-espera__dias-row { display: flex; flex-wrap: wrap; gap: 0.45rem; justify-content: center; }
.ev-espera__dia-pill {
  display: flex; align-items: center; gap: 0.3rem;
  font-size: 0.75rem; font-weight: 600; color: #64748b;
  background: #f8fafc; border-radius: 999px;
  padding: 0.35rem 0.9rem; border: 1.5px solid #e2e8f0;
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.ev-espera__dia-pill--next {
  color: #047857; background: #d1fae5; border-color: #6ee7b7;
  font-weight: 700; box-shadow: 0 2px 10px rgba(5,150,105,0.18);
}
@keyframes ev-float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-7px); } }
@keyframes ev-blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
@media (min-width: 480px) {
  .ev-espera__titulo   { font-size: 1.5rem; }
  .ev-cd-num           { font-size: 2.9rem; }
  .ev-cd-bloque        { min-width: 3.75rem; }
  .ev-espera__icon-wrap { width: 100px; height: 100px; }
  .ev-espera__icon     { font-size: 3.25rem; }
}
@media (min-width: 768px) {
  .ev-espera { max-width: 460px; margin: 0 auto; }
}

/* ═══════════════════════════════════════════════════════════
   CONTEXTO: día activo + estado (sobre los tabs)
═══════════════════════════════════════════════════════════ */
.ev-ctx-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1rem 0.25rem;
  gap: 0.5rem;
}
.ev-ctx-day {
  font-size: 1.25rem;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -0.025em;
  line-height: 1;
}
.ev-ctx-locked {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.72rem;
  font-weight: 700;
  color: #92400e;
  background: #fef3c7;
  border: 1px solid #fde68a;
  padding: 0.3rem 0.65rem;
  border-radius: 999px;
  flex-shrink: 0;
}
.ev-ctx-locked .pi { font-size: 0.65rem; }

/* ═══════════════════════════════════════════════════════════
   TABS PERSONALIZADOS
═══════════════════════════════════════════════════════════ */
.ev-tabs {
  display: flex;
  gap: 0;
  margin: 0.625rem 1rem 0.875rem;
  border-radius: 14px;
  background: #f1f5f9;
  padding: 4px;
  box-shadow: inset 0 1px 3px rgba(0,0,0,.08);
}
.ev-tab {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  padding: 0.7rem 0.5rem;
  border-radius: 10px;
  border: none;
  background: none;
  font-size: 0.9rem;
  font-weight: 700;
  color: #94a3b8;
  cursor: pointer;
  transition: all 0.18s cubic-bezier(.4,0,.2,1);
  min-height: 46px;
  -webkit-tap-highlight-color: transparent;
  letter-spacing: 0.01em;
  user-select: none;
}
.ev-tab--active {
  background: white;
  color: #047857;
  box-shadow: 0 2px 8px rgba(0,0,0,.12);
}
.ev-tab .pi { font-size: 0.95rem; }

/* ═══════════════════════════════════════════════════════════
   HEADER DETALLE (volver atrás)
═══════════════════════════════════════════════════════════ */
.ev-detail-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  border-bottom: 1px solid #f0f4f8;
}
.ev-back {
  flex-shrink: 0;
  width: 44px; height: 44px;
  border-radius: 50%;
  border: 1.5px solid #e2e8f0;
  background: white;
  color: #374151;
  font-size: 1rem;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.15s;
  box-shadow: 0 1px 4px rgba(0,0,0,.08);
  -webkit-tap-highlight-color: transparent;
}
.ev-back:hover  { border-color: #059669; color: #059669; background: #ecfdf5; }
.ev-back:active { transform: scale(0.9); }
.ev-dot {
  width: 18px; height: 18px; border-radius: 50%; flex-shrink: 0;
  border: 2.5px solid white; box-shadow: 0 0 0 1.5px rgba(0,0,0,.14);
}
.ev-dot--sm { width: 12px; height: 12px; }
.ev-lid-icon {
  width: 42px; height: 42px; border-radius: 13px;
  background: #d1fae5; color: #059669;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; flex-shrink: 0;
}
.ev-detail-header__info { display: flex; flex-direction: column; gap: 0.15rem; min-width: 0; flex: 1; }
.ev-detail-header__name {
  font-size: 1.08rem; font-weight: 800; color: #0f172a;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; letter-spacing: -0.015em;
}
.ev-detail-header__sub { font-size: 0.75rem; color: #94a3b8; font-weight: 500; }

/* Barra de progreso del equipo (bajo el header de detalle) */
.ev-detail-prog {
  height: 4px;
  background: #f1f5f9;
  margin-bottom: 0.375rem;
}
.ev-detail-prog__fill {
  height: 100%;
  transition: width 0.45s cubic-bezier(.4,0,.2,1);
  opacity: 0.75;
  min-width: 3px;
}

/* ═══════════════════════════════════════════════════════════
   CARDS DE CRITERIOS (vista detalle)
═══════════════════════════════════════════════════════════ */
.ev-cards {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  padding: 0.5rem 1rem 0;
}
.ev-criterio-card {
  background: white;
  border: 1.5px solid #e8edf2;
  border-radius: 18px;
  padding: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,.055);
  transition: border-color 0.2s, box-shadow 0.2s;
}
.ev-criterio-card--done {
  border-color: #6ee7b7;
  background: linear-gradient(170deg, #fafffe 60%, #ecfdf5 100%);
  box-shadow: 0 2px 10px rgba(5,150,105,.09);
}
.ev-criterio-card--inactive { opacity: 0.5; }

.ev-cc-header { display: flex; align-items: flex-start; gap: 0.5rem; margin-bottom: 0.75rem; }
.ev-cc-meta   { display: flex; align-items: flex-start; gap: 0.4rem; flex: 1; min-width: 0; flex-direction: column; }
.ev-cc-name {
  font-size: 0.98rem;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.35;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.ev-cc-actions { display: flex; align-items: center; gap: 0.4rem; flex-shrink: 0; }

/* Badge categoría */
.ev-cat-badge {
  font-size: 0.65rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  background: #f1f5f9;
  color: #64748b;
  border-radius: 7px;
  padding: 0.12rem 0.5rem;
  white-space: nowrap;
  flex-shrink: 0;
  align-self: flex-start;
}
.ev-cat-badge--lid { background: #d1fae5; color: #059669; }

/* Botón info */
.ev-info-btn {
  width: 32px; height: 32px; border-radius: 50%;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  color: #94a3b8; font-size: 0.88rem; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.12s;
  -webkit-tap-highlight-color: transparent;
}
.ev-info-btn:hover { border-color: #059669; color: #059669; background: #ecfdf5; }

/* Indicador guardado */
.ev-save-dot {
  width: 28px; height: 28px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.72rem; flex-shrink: 0;
}
.ev-save-dot--saving { border: 2.5px solid #d1fae5; border-top-color: #059669; animation: spin 0.7s linear infinite; }
.ev-save-dot--ok  { background: #d1fae5; color: #059669; }
.ev-save-dot--err { background: #fee2e2; color: #dc2626; }

/* Mensajes inactivo */
.ev-inactive-msg {
  font-size: 0.84rem; color: #94a3b8;
  display: flex; align-items: center; gap: 0.35rem; padding: 0.25rem 0;
}
.ev-inactive-msg--cancel { color: #dc2626; }
.ev-inactive-motivo { font-style: italic; }

/* ═══════════════════════════════════════════════════════════
   BOTONES DE PUNTAJE  —  el elemento más importante de la app
═══════════════════════════════════════════════════════════ */
.ev-scores {
  display: flex;
  gap: 0.3rem;
  margin-bottom: 0.5rem;
}

.ev-score-btn {
  flex: 1;
  min-height: 60px;
  border-radius: 13px;
  border: 2px solid transparent;
  cursor: pointer;
  transition: all 0.16s cubic-bezier(.4,0,.2,1);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.12rem;
  padding: 0.3rem 0.1rem;
  line-height: 1;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
}
.ev-score-btn:active:not(.ev-score-btn--locked) { transform: scale(0.93); }
.ev-score-btn--locked { opacity: 0.38; cursor: not-allowed; }

.ev-score-num   { font-size: 1.05rem; font-weight: 800; display: block; letter-spacing: -0.02em; }
.ev-score-label { font-size: 0.58rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; display: block; }

/* Colores idle */
.score-btn--0-idle   { background: #fff1f2; border-color: #fecdd3; color: #e11d48; }
.score-btn--25-idle  { background: #fff7ed; border-color: #fed7aa; color: #ea580c; }
.score-btn--50-idle  { background: #fefce8; border-color: #fef08a; color: #ca8a04; }
.score-btn--75-idle  { background: #eff6ff; border-color: #bfdbfe; color: #2563eb; }
.score-btn--100-idle { background: #ecfdf5; border-color: #a7f3d0; color: #059669; }

/* Colores activos */
.score-btn--0-act   { background: #e11d48; border-color: #e11d48; color: white; box-shadow: 0 4px 14px rgba(225,29,72,.35);  transform: scale(1.05); }
.score-btn--25-act  { background: #ea580c; border-color: #ea580c; color: white; box-shadow: 0 4px 14px rgba(234,88,12,.35);  transform: scale(1.05); }
.score-btn--50-act  { background: #d97706; border-color: #d97706; color: white; box-shadow: 0 4px 14px rgba(217,119,6,.35);  transform: scale(1.05); }
.score-btn--75-act  { background: #2563eb; border-color: #2563eb; color: white; box-shadow: 0 4px 14px rgba(37,99,235,.35);  transform: scale(1.05); }
.score-btn--100-act { background: #059669; border-color: #059669; color: white; box-shadow: 0 4px 14px rgba(5,150,105,.38); transform: scale(1.05); }

/* Hover idle */
.score-btn--0-idle:hover:not(.ev-score-btn--locked)   { background: #ffe4e6; transform: scale(1.02); }
.score-btn--25-idle:hover:not(.ev-score-btn--locked)  { background: #ffedd5; transform: scale(1.02); }
.score-btn--50-idle:hover:not(.ev-score-btn--locked)  { background: #fef9c3; transform: scale(1.02); }
.score-btn--75-idle:hover:not(.ev-score-btn--locked)  { background: #dbeafe; transform: scale(1.02); }
.score-btn--100-idle:hover:not(.ev-score-btn--locked) { background: #d1fae5; transform: scale(1.02); }

/* Descriptor */
.ev-descriptor {
  display: flex; align-items: center; gap: 0.35rem;
  font-size: 0.8rem; color: #059669; font-weight: 600; font-style: italic;
  margin-bottom: 0.4rem; padding: 0 0.1rem;
}
.ev-descriptor .pi { flex-shrink: 0; font-size: 0.72rem; }

/* Comentario */
.ev-comment-wrap { margin-top: 0.3rem; }
.ev-comment-toggle {
  display: flex; align-items: center; gap: 0.4rem;
  font-size: 0.82rem; color: #94a3b8;
  background: none; border: none; cursor: pointer;
  padding: 0.3rem 0; min-height: 38px;
  transition: color 0.12s;
  -webkit-tap-highlight-color: transparent;
}
.ev-comment-toggle:hover { color: #059669; }
.ev-comment-input {
  width: 100%; margin-top: 0.35rem;
  font-size: 1rem; border-radius: 10px; border: 1.5px solid #e2e8f0;
}

/* Liderazgo */
.ev-liderazgo-card { margin: 0.75rem 1rem 0; }

/* ═══════════════════════════════════════════════════════════
   LISTA DE EQUIPOS
═══════════════════════════════════════════════════════════ */
.ev-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0 1rem;
}

.ev-equipo-card {
  display: flex;
  align-items: center;
  gap: 0;
  border-radius: 18px;
  border: 1.5px solid #e8edf2;
  background: white;
  box-shadow: 0 2px 8px rgba(0,0,0,.06);
  overflow: hidden;
  cursor: pointer;
  transition: all 0.18s cubic-bezier(.4,0,.2,1);
  min-height: 72px;
  text-align: left;
  width: 100%;
  -webkit-tap-highlight-color: transparent;
}
.ev-equipo-card:hover  { border-color: #6ee7b7; box-shadow: 0 4px 16px rgba(5,150,105,.12); }
.ev-equipo-card:active { transform: scale(0.985); }

.ev-ec-strip { width: 7px; align-self: stretch; flex-shrink: 0; }
.ev-ec-body  { flex: 1; min-width: 0; padding: 0.75rem 0.875rem; display: flex; flex-direction: column; gap: 0.5rem; }
.ev-ec-top   { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
.ev-ec-name  {
  font-size: 1.02rem; font-weight: 700; color: #0f172a;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; letter-spacing: -0.01em;
}
.ev-ec-badge {
  font-size: 0.75rem; font-weight: 800;
  padding: 0.22rem 0.65rem;
  border-radius: 999px;
  background: #f1f5f9; color: #64748b;
  white-space: nowrap; flex-shrink: 0;
}
.ev-ec-badge--done { background: #d1fae5; color: #047857; }
.ev-progress-bar { height: 5px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.ev-progress-fill { height: 100%; border-radius: 999px; transition: width 0.4s ease; min-width: 3px; opacity: 0.82; }
.ev-ec-chevron { color: #d1d5db; font-size: 0.82rem; flex-shrink: 0; margin-right: 1rem; }

/* ═══════════════════════════════════════════════════════════
   LISTA DE CRITERIOS (tab Por criterio)
═══════════════════════════════════════════════════════════ */
.ev-criterio-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.9rem 1rem;
  border-radius: 15px;
  border: 1.5px solid #e8edf2;
  background: white;
  box-shadow: 0 1px 5px rgba(0,0,0,.055);
  cursor: pointer;
  text-align: left;
  min-height: 62px;
  width: 100%;
  transition: all 0.16s;
  -webkit-tap-highlight-color: transparent;
}
.ev-criterio-row:hover:not(:disabled)  { border-color: #6ee7b7; box-shadow: 0 3px 10px rgba(5,150,105,.1); }
.ev-criterio-row:active:not(:disabled) { transform: scale(0.99); }
.ev-criterio-row--inactive { opacity: 0.48; cursor: default; }
.ev-criterio-row--lid {
  border-color: #a7f3d0;
  background: linear-gradient(to right, #ecfdf5 0%, white 60%);
}

.ev-cr-left { display: flex; align-items: center; gap: 0.45rem; flex: 1; min-width: 0; }
.ev-cr-name {
  font-size: 0.95rem; font-weight: 600; color: #0f172a;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  line-height: 1.35;
}

.ev-cr-chip {
  font-size: 0.78rem; font-weight: 800;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  background: #f1f5f9; color: #64748b;
  white-space: nowrap; flex-shrink: 0;
}
.ev-cr-chip--lid { background: #d1fae5; color: #059669; }

.ev-status-badge {
  font-size: 0.72rem; font-weight: 700;
  padding: 0.18rem 0.55rem;
  border-radius: 999px;
  white-space: nowrap; flex-shrink: 0;
}
.ev-status-badge--cancel { background: #fee2e2; color: #dc2626; }
.ev-status-badge--na     { background: #f1f5f9; color: #94a3b8; }

/* Empty state */
.ev-empty {
  display: flex; align-items: center; justify-content: center;
  gap: 0.5rem; padding: 2.5rem 1rem;
  color: #94a3b8; font-size: 0.88rem;
}

/* ═══════════════════════════════════════════════════════════
   DIALOGS
═══════════════════════════════════════════════════════════ */
.ev-dialog-text { font-size: 0.88rem; color: #64748b; margin: 0 0 0.75rem; }
.ev-dialog-textarea { width: 100%; font-size: 1rem; border-radius: 10px; }
.ev-dialog-footer { display: flex; gap: 0.5rem; justify-content: flex-end; }

.ev-btn-primary {
  display: inline-flex; align-items: center; gap: 0.4rem;
  padding: 0.65rem 1.25rem; border-radius: 10px; border: none;
  background: #059669; color: white;
  font-size: 0.9rem; font-weight: 700; cursor: pointer;
  transition: background 0.15s; min-height: 44px;
}
.ev-btn-primary:hover:not(:disabled) { background: #047857; }
.ev-btn-primary:disabled { opacity: 0.45; cursor: not-allowed; }
.ev-btn-secondary {
  display: inline-flex; align-items: center;
  padding: 0.65rem 1rem; border-radius: 10px;
  border: 1.5px solid #e2e8f0; background: white; color: #64748b;
  font-size: 0.9rem; font-weight: 600; cursor: pointer;
  transition: all 0.15s; min-height: 44px;
}
.ev-btn-secondary:hover { background: #f8fafc; border-color: #cbd5e1; }

/* Rúbrica en dialog info */
.ev-info-block { margin-bottom: 0.875rem; }
.ev-info-label {
  font-size: 0.8rem; font-weight: 700; color: #374151;
  display: flex; align-items: center; gap: 0.35rem; margin: 0 0 0.25rem;
}
.ev-info-label .pi { font-size: 0.78rem; }
.ev-info-text { font-size: 0.85rem; color: #64748b; margin: 0; padding-left: 0.1rem; }
.ev-rubrica-grid { display: flex; flex-direction: column; gap: 0.4rem; margin-top: 0.75rem; padding-top: 0.75rem; border-top: 1px solid #f1f5f9; }
.ev-rubrica-row  { display: flex; align-items: center; gap: 0.75rem; }
.ev-rubrica-pts  { font-size: 0.82rem; font-weight: 800; border-radius: 8px; padding: 0.25rem 0.55rem; min-width: 42px; text-align: center; flex-shrink: 0; }
.ev-rubrica-desc { font-size: 0.82rem; color: #475569; }

/* ═══════════════════════════════════════════════════════════
   MUY PEQUEÑO (< 360px)
═══════════════════════════════════════════════════════════ */
@media (max-width: 359px) {
  .ev-score-num  { font-size: 0.9rem; }
  .ev-score-btn  { min-height: 52px; }
  .ev-day        { min-width: 72px; padding: 0.65rem 0.875rem; }
  .ev-day__label { font-size: 0.82rem; }
}

/* ═══════════════════════════════════════════════════════════
   TABLET (≥ 600px)
═══════════════════════════════════════════════════════════ */
@media (min-width: 600px) {
  .ev-cards        { padding: 0.5rem 1.25rem 0; gap: 0.875rem; }
  .ev-list         { padding: 0 1.25rem; gap: 0.625rem; }
  .ev-tabs         { margin: 0.625rem 1.25rem 0.875rem; }
  .ev-ctx-bar      { padding: 1.125rem 1.25rem 0.25rem; }
  .ev-detail-header { padding: 1rem 1.25rem; }
  .ev-equipo-card  { min-height: 76px; }
  .ev-ec-name      { font-size: 1.05rem; }
  .ev-score-btn    { min-height: 64px; border-radius: 15px; }
  .ev-score-num    { font-size: 1.12rem; }
  .ev-score-label  { font-size: 0.63rem; }
  .ev-criterio-row { min-height: 66px; padding: 1rem 1.125rem; }
  .ev-day          { min-width: 96px; padding: 0.875rem 1.4rem; min-height: 72px; }
}

/* ═══════════════════════════════════════════════════════════
   DESKTOP (≥ 960px): grid 2 columnas
═══════════════════════════════════════════════════════════ */
@media (min-width: 960px) {
  .ev-cards {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
    padding: 0.5rem 1.5rem 0;
  }
  .ev-liderazgo-card { grid-column: 1 / -1; }
  .ev-list {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
    padding: 0 1.5rem;
  }
  .ev-tabs    { margin: 0.625rem 1.5rem 0.875rem; }
  .ev-ctx-bar { padding: 1.25rem 1.5rem 0.25rem; }
  .ev-day     { min-width: 110px; min-height: 76px; }
}
</style>

