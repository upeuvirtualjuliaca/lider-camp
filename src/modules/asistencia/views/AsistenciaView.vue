<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import {
  actividadesService,
  asistenciaService,
  integrantesAsistenciaService,
  type ActividadConProgramacion,
  type RegistroConIntegrante,
  type AsistenciaEquipoActividad,
} from '@/modules/asistencia/services/asistencia.service'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import type { Tables } from '@/types/database'

// ── Tipos ────────────────────────────────────────────────────────────────────
type EstadoAsistencia = 'presente' | 'ausente' | 'justificado'
type EstadoGuardado   = 'idle' | 'guardando' | 'guardado' | 'error'

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

const dias       = ref<DiasEvaluacion[]>([])
const equipos    = ref<Equipo[]>([])
const paso       = ref<1 | 2 | 3>(1)
const momentoActivo = ref<string>('')

// Paso 2
const actividadesDia        = ref<ActividadConProgramacion[]>([])
const cargandoActividades   = ref(false)
const actividadSeleccionada = ref<ActividadConProgramacion | null>(null)

// Paso 3
const equipoActivo       = ref<Equipo | null>(null)
const busqueda           = ref('')
const cargandoRegistros  = ref(false)
const filasPorEquipo     = ref<Map<string, FilaIntegrante[]>>(new Map())
const resumenPorEquipo   = ref<Map<string, AsistenciaEquipoActividad>>(new Map())

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
    const [, diasData, equiposData] = await Promise.all([
      cargarCampamento(),
      cargarDias(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])
    momentoActivo.value = detectarMomentoActual()
    dias.value    = diasData
    equipos.value = equiposData.filter((e) => e.activo)
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
  filasPorEquipo.value  = new Map()
  resumenPorEquipo.value = new Map()
  paso.value = 3
  const primero = equipos.value[0]
  if (primero) await seleccionarEquipo(primero)
}

function volverPaso(n: 1 | 2) {
  if (n === 1) {
    paso.value = 1
    actividadesDia.value = []
    actividadSeleccionada.value = null
    filasPorEquipo.value  = new Map()
    resumenPorEquipo.value = new Map()
    equipoActivo.value = null
  } else {
    paso.value = 2
    actividadSeleccionada.value = null
    filasPorEquipo.value  = new Map()
    resumenPorEquipo.value = new Map()
    equipoActivo.value = null
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
           PASO 1 — Elegir día
      ══════════════════════════════════════════════ -->
      <template v-if="paso === 1">
        <div class="ast-page-header">
          <div class="ast-page-header__icon"><i class="pi pi-users" /></div>
          <div>
            <h1 class="ast-page-title">Asistencia</h1>
            <p class="ast-page-sub">Selecciona el día a registrar</p>
          </div>
        </div>

        <div class="ast-dias-grid">
          <button
            v-for="m in momentos"
            :key="m"
            class="ast-dia-card"
            :class="{ 'ast-dia-card--locked': dias.find((d) => d.momento === m)?.cerrado }"
            @click="seleccionarDia(m)"
          >
            <span class="ast-dia-card__letter">{{ m }}</span>
            <span class="ast-dia-card__label">{{ labelDia(m) }}</span>
            <span class="ast-dia-card__date">{{ fechas[m] ?? '' }}</span>
            <span
              v-if="dias.find((d) => d.momento === m)?.cerrado"
              class="ast-dia-card__lock"
            >
              <i class="pi pi-lock" /> Cerrado
            </span>
            <i v-else class="pi pi-chevron-right ast-dia-card__chevron" />
          </button>
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
        </div>
      </template>

      <!-- ══════════════════════════════════════════════
           PASO 3 — Registrar asistencia
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
          <!-- Barra de progreso de registro -->
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
            <!-- Cabecera de la fila -->
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
              <!-- Indicador guardado -->
              <span class="ast-save-indicator">
                <span v-if="fila.estadoGuardado === 'guardando'" class="ast-save-ring" />
                <span v-else-if="fila.estadoGuardado === 'guardado'" class="ast-save-ok"><i class="pi pi-check" /></span>
                <span v-else-if="fila.estadoGuardado === 'error'"   class="ast-save-err"><i class="pi pi-times" /></span>
              </span>
            </div>

            <!-- Botones de estado -->
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
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
  padding: 0 1rem;
}

@media (min-width: 500px) {
  .ast-dias-grid { grid-template-columns: repeat(4, 1fr); }
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
</style>
