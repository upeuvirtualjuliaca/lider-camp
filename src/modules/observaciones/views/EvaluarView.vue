<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
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

// ── Tipos ────────────────────────────────────────────────────────────────────
type EstadoGuardado = 'idle' | 'guardando' | 'guardado' | 'error'

interface FilaEstado {
  estado: EstadoGuardado
  puntaje: number | null
  comentario: string
  comentarioAbierto: boolean
}

// ── Constantes ────────────────────────────────────────────────────────────────
const PUNTAJES = [0, 25, 50, 75, 100]

const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

const DESCRIPTORES_RUBRICA: Record<number, string> = {
  0:   'No cumple / No presente',
  25:  'Deficiente — incumplimiento grave',
  50:  'Regular — cumplimiento parcial',
  75:  'Bueno — cumple lo esencial',
  100: 'Excelente — cumplimiento total',
}

const SCORE_COLOR: Record<number, { idle: string; active: string; label: string }> = {
  0:   { idle: 'score-btn--0-idle',   active: 'score-btn--0-act',   label: 'Nulo' },
  25:  { idle: 'score-btn--25-idle',  active: 'score-btn--25-act',  label: 'Def.' },
  50:  { idle: 'score-btn--50-idle',  active: 'score-btn--50-act',  label: 'Reg.' },
  75:  { idle: 'score-btn--75-idle',  active: 'score-btn--75-act',  label: 'Bien' },
  100: { idle: 'score-btn--100-idle', active: 'score-btn--100-act', label: '¡Ok!' },
}

// ── Estado global ─────────────────────────────────────────────────────────────
const session   = useSessionStore()
const campStore = useCampamentoStore()
const cargando  = ref(true)
const error     = ref('')

const dias             = ref<DiasEvaluacion[]>([])
const momentoActivo    = ref<string>('')
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
  cargando.value = true
  error.value    = ''
  equipoSeleccionado.value  = null
  criterioSeleccionado.value = null
  modoLiderazgoCriterio.value = false
  obsByEquipo.value   = new Map()
  obsByCriterio.value = new Map()
  try {
    const [, diasData, equiposData] = await Promise.all([
      cargarCampamento(),
      campStore.selectedId ? diasService.getTodos(campStore.selectedId) : Promise.resolve([]),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])
    momentoActivo.value = detectarMomentoActual()
    dias.value    = diasData
    equipos.value = equiposData.filter((e) => e.activo)
    await cargarProgramacionDia()
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
    observacionesService.getPorEquipoYDia(equipo.id, momentoActivo.value),
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
    observacionesService.getPorCriterioYDia(prog.id),
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

      <!-- ── Selector de días ──────────────────────────────────────── -->
      <div class="ev-days-wrap">
        <div class="ev-days">
          <button
            v-for="m in momentos"
            :key="m"
            class="ev-day"
            :class="{
              'ev-day--active':  momentoActivo === m,
              'ev-day--locked':  dias.find((d) => d.momento === m)?.cerrado,
            }"
            @click="seleccionarMomento(m)"
          >
            <span class="ev-day__label">{{ labelDia(m) }}</span>
            <span
              v-if="dias.find((d) => d.momento === m)?.cerrado"
              class="ev-day__lock"
            >
              <i class="pi pi-lock" />
            </span>
          </button>
        </div>
      </div>

      <!-- Banner día cerrado -->
      <div v-if="diaCerrado" class="ev-banner-locked">
        <i class="pi pi-lock" />
        <span>Día cerrado — solo lectura</span>
      </div>

      <!-- ══════════════════════════════════════════
           VISTA: Detalle por equipo
      ══════════════════════════════════════════ -->
      <template v-if="equipoSeleccionado">
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
                  v-for="pts in PUNTAJES"
                  :key="pts"
                  class="ev-score-btn"
                  :class="[
                    filasEquipo.get(prog.id)?.puntaje === pts
                      ? SCORE_COLOR[pts]!.active
                      : SCORE_COLOR[pts]!.idle,
                    { 'ev-score-btn--locked': diaCerrado },
                  ]"
                  :disabled="diaCerrado"
                  @click="onPuntajeEquipo(prog, pts)"
                >
                  <span class="ev-score-num">{{ pts }}</span>
                  <span
                    v-if="filasEquipo.get(prog.id)?.puntaje === pts"
                    class="ev-score-label"
                  >{{ SCORE_COLOR[pts]!.label }}</span>
                </button>
              </div>

              <!-- Descriptor -->
              <div
                v-if="filasEquipo.get(prog.id)?.puntaje !== null && filasEquipo.get(prog.id)?.puntaje !== undefined"
                class="ev-descriptor"
              >
                <i class="pi pi-info-circle" />
                {{ DESCRIPTORES_RUBRICA[filasEquipo.get(prog.id)!.puntaje!] }}
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
      <template v-else-if="modoLiderazgoCriterio && programacionLiderazgo">
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
      <template v-else-if="criterioSeleccionado">
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
                v-for="pts in PUNTAJES"
                :key="pts"
                class="ev-score-btn"
                :class="[
                  filasCriterio.get(equipo.id)?.puntaje === pts
                    ? SCORE_COLOR[pts]!.active
                    : SCORE_COLOR[pts]!.idle,
                  { 'ev-score-btn--locked': diaCerrado },
                ]"
                :disabled="diaCerrado"
                @click="onPuntajeCriterio(equipo, pts)"
              >
                <span class="ev-score-num">{{ pts }}</span>
                <span v-if="filasCriterio.get(equipo.id)?.puntaje === pts" class="ev-score-label">
                  {{ SCORE_COLOR[pts]!.label }}
                </span>
              </button>
            </div>

            <div
              v-if="filasCriterio.get(equipo.id)?.puntaje !== null && filasCriterio.get(equipo.id)?.puntaje !== undefined"
              class="ev-descriptor"
            >
              <i class="pi pi-info-circle" />
              {{ DESCRIPTORES_RUBRICA[filasCriterio.get(equipo.id)!.puntaje!] }}
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
      <template v-else>

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
            v-for="pts in PUNTAJES"
            :key="pts"
            class="ev-rubrica-row"
          >
            <span class="ev-rubrica-pts" :class="SCORE_COLOR[pts]!.active">{{ pts }}</span>
            <span class="ev-rubrica-desc">{{ DESCRIPTORES_RUBRICA[pts] }}</span>
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
  width: 40px; height: 40px;
  border: 3px solid #dcfce7;
  border-top-color: #16a34a;
  border-radius: 50%;
  animation: spin 0.75s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.ev-loading p { font-size: 0.85rem; }

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

/* ── Banner cerrado ── */
.ev-banner-locked {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: #fef3c7;
  border: 1px solid #fde68a;
  border-radius: 10px;
  padding: 0.6rem 1rem;
  font-size: 0.82rem;
  font-weight: 600;
  color: #92400e;
  margin: 0 1rem 0.75rem;
}

/* ═══════════════════════════════════════════════════════════
   SELECTOR DE DÍAS
═══════════════════════════════════════════════════════════ */
.ev-days-wrap {
  overflow-x: auto;
  padding: 0.75rem 1rem;
  scrollbar-width: none;
}
.ev-days-wrap::-webkit-scrollbar { display: none; }

.ev-days {
  display: flex;
  gap: 0.5rem;
  width: max-content;
}

.ev-day {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.55rem 1.2rem;
  border-radius: 999px;
  border: 2px solid #e2e8f0;
  background: white;
  font-size: 0.88rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
  min-height: 42px;
}
.ev-day:hover { border-color: #16a34a; color: #15803d; }
.ev-day--active {
  border-color: #16a34a;
  background: #f0fdf4;
  color: #15803d;
  box-shadow: 0 0 0 3px #bbf7d060;
}
.ev-day--locked { opacity: 0.65; }
.ev-day__label { font-weight: 700; }
.ev-day__lock { font-size: 0.7rem; color: #b45309; }

/* ═══════════════════════════════════════════════════════════
   HEADER DETALLE (volver atrás)
═══════════════════════════════════════════════════════════ */
.ev-detail-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1rem 0.75rem;
}

.ev-back {
  flex-shrink: 0;
  width: 40px; height: 40px;
  border-radius: 50%;
  border: 1.5px solid #e2e8f0;
  background: white;
  color: #374151;
  font-size: 1rem;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.15s;
  box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.ev-back:hover { border-color: #16a34a; color: #16a34a; background: #f0fdf4; }

.ev-dot {
  width: 16px; height: 16px;
  border-radius: 50%;
  flex-shrink: 0;
  border: 2px solid white;
  box-shadow: 0 0 0 1.5px rgba(0,0,0,.12);
}
.ev-dot--sm { width: 11px; height: 11px; }

.ev-lid-icon {
  width: 36px; height: 36px;
  border-radius: 10px;
  background: #ecfdf5;
  color: #16a34a;
  display: flex; align-items: center; justify-content: center;
  font-size: 1rem;
  flex-shrink: 0;
}

.ev-detail-header__info {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}
.ev-detail-header__name {
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ev-detail-header__sub {
  font-size: 0.75rem;
  color: #94a3b8;
}

/* ═══════════════════════════════════════════════════════════
   CARDS DE CRITERIOS (vista detalle)
═══════════════════════════════════════════════════════════ */
.ev-cards {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  padding: 0 1rem;
}

.ev-criterio-card {
  background: white;
  border: 1.5px solid #e2e8f0;
  border-radius: 14px;
  padding: 0.875rem;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  transition: border-color 0.15s;
}
.ev-criterio-card--done {
  border-color: #bbf7d0;
  background: #fafffe;
}
.ev-criterio-card--inactive { opacity: 0.55; }

/* Cabecera de la card */
.ev-cc-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.625rem;
}
.ev-cc-meta {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex: 1;
  min-width: 0;
}
.ev-cc-name {
  font-size: 0.9rem;
  font-weight: 600;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ev-cc-actions {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

/* Badge categoría */
.ev-cat-badge {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  background: #f1f5f9;
  color: #64748b;
  border-radius: 6px;
  padding: 0.1rem 0.45rem;
  white-space: nowrap;
  flex-shrink: 0;
}
.ev-cat-badge--lid {
  background: #ecfdf5;
  color: #16a34a;
}

/* Botón info */
.ev-info-btn {
  width: 30px; height: 30px;
  border-radius: 50%;
  border: 1.5px solid #e2e8f0;
  background: #f8fafc;
  color: #94a3b8;
  font-size: 0.85rem;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.12s;
}
.ev-info-btn:hover { border-color: #16a34a; color: #16a34a; background: #f0fdf4; }

/* Indicador guardado */
.ev-save-dot {
  width: 26px; height: 26px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.72rem;
  flex-shrink: 0;
}
.ev-save-dot--saving {
  border: 2.5px solid #dcfce7;
  border-top-color: #16a34a;
  animation: spin 0.7s linear infinite;
}
.ev-save-dot--ok { background: #dcfce7; color: #16a34a; }
.ev-save-dot--err { background: #fee2e2; color: #dc2626; }

/* Mensajes inactivo */
.ev-inactive-msg {
  font-size: 0.82rem;
  color: #94a3b8;
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0;
}
.ev-inactive-msg--cancel { color: #dc2626; }
.ev-inactive-motivo { font-style: italic; }

/* ═══════════════════════════════════════════════════════════
   BOTONES DE PUNTAJE
═══════════════════════════════════════════════════════════ */
.ev-scores {
  display: flex;
  gap: 0.35rem;
  margin-bottom: 0.5rem;
}

.ev-score-btn {
  flex: 1;
  min-height: 52px;
  border-radius: 10px;
  border: 2px solid transparent;
  cursor: pointer;
  transition: all 0.15s;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.1rem;
  padding: 0.2rem 0.15rem;
  line-height: 1.1;
}
.ev-score-btn--locked { opacity: 0.45; cursor: not-allowed; }

.ev-score-num {
  font-size: 0.95rem;
  font-weight: 800;
  display: block;
}
.ev-score-label {
  font-size: 0.6rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  display: block;
}

/* Colores idle */
.score-btn--0-idle   { background: #fef2f2; border-color: #fecaca; color: #ef4444; }
.score-btn--25-idle  { background: #fff7ed; border-color: #fed7aa; color: #f97316; }
.score-btn--50-idle  { background: #fefce8; border-color: #fef08a; color: #ca8a04; }
.score-btn--75-idle  { background: #eff6ff; border-color: #bfdbfe; color: #3b82f6; }
.score-btn--100-idle { background: #f0fdf4; border-color: #bbf7d0; color: #16a34a; }

/* Colores activos */
.score-btn--0-act   { background: #ef4444; border-color: #ef4444; color: white; box-shadow: 0 2px 8px #ef444440; transform: scale(1.04); }
.score-btn--25-act  { background: #f97316; border-color: #f97316; color: white; box-shadow: 0 2px 8px #f9731640; transform: scale(1.04); }
.score-btn--50-act  { background: #eab308; border-color: #eab308; color: white; box-shadow: 0 2px 8px #eab30840; transform: scale(1.04); }
.score-btn--75-act  { background: #3b82f6; border-color: #3b82f6; color: white; box-shadow: 0 2px 8px #3b82f640; transform: scale(1.04); }
.score-btn--100-act { background: #16a34a; border-color: #16a34a; color: white; box-shadow: 0 2px 8px #16a34a40; transform: scale(1.04); }

/* Hover en idle */
.score-btn--0-idle:hover:not(.ev-score-btn--locked)   { background: #fee2e2; transform: scale(1.02); }
.score-btn--25-idle:hover:not(.ev-score-btn--locked)  { background: #ffedd5; transform: scale(1.02); }
.score-btn--50-idle:hover:not(.ev-score-btn--locked)  { background: #fef9c3; transform: scale(1.02); }
.score-btn--75-idle:hover:not(.ev-score-btn--locked)  { background: #dbeafe; transform: scale(1.02); }
.score-btn--100-idle:hover:not(.ev-score-btn--locked) { background: #dcfce7; transform: scale(1.02); }

/* Descriptor */
.ev-descriptor {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.78rem;
  color: #16a34a;
  font-weight: 500;
  font-style: italic;
  margin-bottom: 0.35rem;
  padding: 0 0.1rem;
}
.ev-descriptor .pi { flex-shrink: 0; font-size: 0.72rem; }

/* ── Comentario ── */
.ev-comment-wrap { margin-top: 0.25rem; }

.ev-comment-toggle {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.8rem;
  color: #94a3b8;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.3rem 0;
  min-height: 36px;
  transition: color 0.12s;
}
.ev-comment-toggle:hover { color: #16a34a; }

.ev-comment-input {
  width: 100%;
  margin-top: 0.35rem;
  font-size: 0.9rem;
  border-radius: 8px;
  border: 1.5px solid #e2e8f0;
}

/* Liderazgo card wrapper */
.ev-liderazgo-card { margin: 0.75rem 1rem 0; }

/* ═══════════════════════════════════════════════════════════
   TABS PERSONALIZADOS
═══════════════════════════════════════════════════════════ */
.ev-tabs {
  display: flex;
  gap: 0;
  margin: 0 1rem 0.75rem;
  border-radius: 12px;
  background: #f1f5f9;
  padding: 3px;
}
.ev-tab {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.55rem 0.5rem;
  border-radius: 9px;
  border: none;
  background: none;
  font-size: 0.85rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
  min-height: 40px;
}
.ev-tab--active {
  background: white;
  color: #16a34a;
  box-shadow: 0 1px 4px rgba(0,0,0,.1);
}
.ev-tab .pi { font-size: 0.82rem; }

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
  border-radius: 14px;
  border: 1.5px solid #e2e8f0;
  background: white;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  overflow: hidden;
  cursor: pointer;
  transition: all 0.15s;
  min-height: 64px;
  text-align: left;
  width: 100%;
}
.ev-equipo-card:hover { border-color: #bbf7d0; background: #fafffe; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.ev-equipo-card:active { transform: scale(0.99); }

.ev-ec-strip {
  width: 5px;
  align-self: stretch;
  flex-shrink: 0;
}

.ev-ec-body {
  flex: 1;
  min-width: 0;
  padding: 0.6rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.ev-ec-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.ev-ec-name {
  font-size: 0.93rem;
  font-weight: 600;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ev-ec-badge {
  font-size: 0.75rem;
  font-weight: 700;
  padding: 0.15rem 0.55rem;
  border-radius: 999px;
  background: #f1f5f9;
  color: #64748b;
  white-space: nowrap;
  flex-shrink: 0;
}
.ev-ec-badge--done { background: #dcfce7; color: #16a34a; }

.ev-progress-bar {
  height: 4px;
  background: #f1f5f9;
  border-radius: 4px;
  overflow: hidden;
}
.ev-progress-fill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.35s ease;
  min-width: 2px;
}

.ev-ec-chevron {
  color: #cbd5e1;
  font-size: 0.75rem;
  flex-shrink: 0;
  margin-right: 0.75rem;
}

/* ═══════════════════════════════════════════════════════════
   LISTA DE CRITERIOS (tab Por criterio)
═══════════════════════════════════════════════════════════ */
.ev-criterio-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 0.875rem;
  border-radius: 12px;
  border: 1.5px solid #e2e8f0;
  background: white;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  cursor: pointer;
  text-align: left;
  min-height: 56px;
  width: 100%;
  transition: all 0.15s;
}
.ev-criterio-row:hover:not(:disabled) { border-color: #bbf7d0; background: #fafffe; }
.ev-criterio-row--inactive { opacity: 0.55; cursor: default; }
.ev-criterio-row--lid { border-color: #d1fae5; background: #f0fdf4; }

.ev-cr-left {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex: 1;
  min-width: 0;
}

.ev-cr-name {
  font-size: 0.9rem;
  font-weight: 500;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ev-cr-chip {
  font-size: 0.78rem;
  font-weight: 700;
  padding: 0.18rem 0.55rem;
  border-radius: 999px;
  background: #f1f5f9;
  color: #64748b;
  white-space: nowrap;
  flex-shrink: 0;
}
.ev-cr-chip--lid { background: #dcfce7; color: #16a34a; }

.ev-status-badge {
  font-size: 0.72rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  white-space: nowrap;
  flex-shrink: 0;
}
.ev-status-badge--cancel { background: #fee2e2; color: #dc2626; }
.ev-status-badge--na     { background: #f1f5f9; color: #94a3b8; }

/* Empty state */
.ev-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2.5rem 1rem;
  color: #94a3b8;
  font-size: 0.88rem;
}

/* ═══════════════════════════════════════════════════════════
   DIALOGS
═══════════════════════════════════════════════════════════ */
.ev-dialog-text {
  font-size: 0.88rem;
  color: #64748b;
  margin: 0 0 0.75rem;
}
.ev-dialog-textarea {
  width: 100%;
  font-size: 0.9rem;
  border-radius: 8px;
}
.ev-dialog-footer {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
}

.ev-btn-primary {
  display: inline-flex; align-items: center; gap: 0.4rem;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  border: none;
  background: #16a34a;
  color: white;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  min-height: 40px;
}
.ev-btn-primary:hover:not(:disabled) { background: #15803d; }
.ev-btn-primary:disabled { opacity: 0.45; cursor: not-allowed; }

.ev-btn-secondary {
  display: inline-flex; align-items: center;
  padding: 0.6rem 1rem;
  border-radius: 8px;
  border: 1.5px solid #e2e8f0;
  background: white;
  color: #64748b;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s;
  min-height: 40px;
}
.ev-btn-secondary:hover { background: #f8fafc; border-color: #cbd5e1; }

/* Rúbrica en dialog info */
.ev-info-block {
  margin-bottom: 0.875rem;
}
.ev-info-label {
  font-size: 0.8rem;
  font-weight: 700;
  color: #374151;
  display: flex;
  align-items: center;
  gap: 0.35rem;
  margin: 0 0 0.25rem;
}
.ev-info-label .pi { font-size: 0.78rem; }
.ev-info-text {
  font-size: 0.85rem;
  color: #64748b;
  margin: 0;
  padding-left: 0.1rem;
}

.ev-rubrica-grid {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid #f1f5f9;
}
.ev-rubrica-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.ev-rubrica-pts {
  font-size: 0.82rem;
  font-weight: 800;
  border-radius: 8px;
  padding: 0.25rem 0.55rem;
  min-width: 42px;
  text-align: center;
  flex-shrink: 0;
}
.ev-rubrica-desc {
  font-size: 0.82rem;
  color: #475569;
}

/* ═══════════════════════════════════════════════════════════
   TABLET (≥ 600px)
═══════════════════════════════════════════════════════════ */
@media (min-width: 600px) {
  .ev-cards { gap: 0.75rem; }

  .ev-scores {
    gap: 0.5rem;
  }
  .ev-score-btn {
    min-height: 56px;
    border-radius: 12px;
  }
  .ev-score-num { font-size: 1.05rem; }
  .ev-score-label { font-size: 0.65rem; }

  .ev-equipo-card { min-height: 70px; }
  .ev-ec-name     { font-size: 1rem; }
}

/* ═══════════════════════════════════════════════════════════
   DESKTOP (≥ 960px): grid 2 columnas para criterios
═══════════════════════════════════════════════════════════ */
@media (min-width: 960px) {
  .ev-cards {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
  }
  .ev-liderazgo-card {
    grid-column: 1 / -1;
  }
  .ev-list {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
  }
}
</style>
