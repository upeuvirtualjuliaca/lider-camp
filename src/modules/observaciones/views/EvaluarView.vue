<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
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
import NotEvaluatedToday from '../components/NotEvaluatedToday.vue'
import DaySelector     from '../components/DaySelector.vue'
import ModeTabs        from '../components/ModeTabs.vue'
import ScoreButtons    from '../components/ScoreButtons.vue'
import TeamRow         from '../components/TeamRow.vue'
import CriterioRow     from '../components/CriterioRow.vue'

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

const hoy = computed(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}` })

const momentosDisponibles = computed(() =>
  momentos.value.filter(m =>
    momentosConEvaluacion.value.includes(m) && (fechas.value[m] ?? '') <= hoy.value
  )
)

const momentosSelector = computed<string[]>(() =>
  session.esAdmin
    ? momentos.value.filter(m => momentosConEvaluacion.value.includes(m))
    : momentosDisponibles.value
)

const momentosFuturos = computed(() =>
  momentos.value.filter(m => momentosConEvaluacion.value.includes(m) && (fechas.value[m] ?? '') > hoy.value)
)

const proximoMomento = computed(() => momentosFuturos.value[0] ?? null)

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

const SCORE_NIVELES = [
  { descriptor: 'No realiza la acción pese a contar con oportunidad y apoyos.' },
  { descriptor: 'Avance mínimo o depende de ayuda constante.' },
  { descriptor: 'Cumple parcialmente y requiere acompañamiento frecuente.' },
  { descriptor: 'Cumple lo esencial; omisión menor o requiere un recordatorio.' },
  { descriptor: 'Cumple todos los aspectos, con autonomía y dentro del plazo.' },
] as const

function puntajesPara(max: number): number[] {
  return [0, max * 0.25, max * 0.5, max * 0.75, max]
}

function nivelDe(puntaje: number | null | undefined, max: number): number {
  if (puntaje === null || puntaje === undefined) return -1
  return puntajesPara(max).indexOf(puntaje)
}

function labelScore(pts: number): string {
  return String(pts).replace('.', ',')
}

// ── Estado global ─────────────────────────────────────────────────────────────
const session   = useSessionStore()
const campStore = useCampamentoStore()
const route     = useRoute()
const router    = useRouter()
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

const tabActivo = ref<'equipos' | 'criterios'>('equipos')

// ── Presentación ─────────────────────────────────────────────────────────────
const busqueda     = ref('')
const filtroEquipo = ref<'todos' | 'pendientes' | 'completos'>('todos')

const iniciales = computed(() => {
  const n = session.perfil?.nombre_completo ?? ''
  return n.split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
})

function inicialesEquipo(nombre: string): string {
  return nombre.split(' ').filter(Boolean).slice(0, 2).map(w => (w[0] ?? '').toUpperCase()).join('')
}

watch(tabActivo, () => { busqueda.value = '' })

const criteriosProgramados = computed(() =>
  programacionDia.value.filter(p => p.estado === 'programado')
)

const criteriosNoAplican = computed(() =>
  programacionDia.value.filter(p => p.estado !== 'programado')
)

const criteriosFiltrados = computed(() => {
  if (!busqueda.value) return criteriosProgramados.value
  const q = busqueda.value.toLowerCase()
  return criteriosProgramados.value.filter(p => p.criterios.nombre.toLowerCase().includes(q))
})

const criteriosAgrupados = computed(() => {
  const groups: Record<string, ProgramacionConCriterio[]> = {}
  for (const p of criteriosFiltrados.value) {
    const cat = p.criterios.categoria || 'Sin categoría'
    if (!groups[cat]) groups[cat] = []
    groups[cat].push(p)
  }
  return Object.entries(groups).map(([name, items]) => ({ name, items }))
})

const programadosPorCategoria = computed(() => {
  const groups: Record<string, ProgramacionConCriterio[]> = {}
  for (const p of programacionDia.value.filter(p => p.estado === 'programado')) {
    const cat = p.criterios.categoria || 'Sin categoría'
    if (!groups[cat]) groups[cat] = []
    groups[cat].push(p)
  }
  return Object.entries(groups).map(([name, items]) => ({ name, items }))
})

const completosCount = computed(() =>
  equipos.value.filter(e => {
    const p = progresoEquipo(e)
    return p.total > 0 && p.calificados === p.total
  }).length
)

const equiposFiltrados = computed(() => {
  let list = equipos.value
  if (busqueda.value) {
    const q = busqueda.value.toLowerCase()
    list = list.filter(e => e.nombre.toLowerCase().includes(q))
  }
  if (filtroEquipo.value === 'completos') {
    return list.filter(e => {
      const p = progresoEquipo(e)
      return p.total > 0 && p.calificados === p.total
    })
  }
  if (filtroEquipo.value === 'pendientes') {
    list = list.filter(e => {
      const p = progresoEquipo(e)
      return p.calificados < p.total
    })
  }
  return list
})

const pendientesCount = computed(() =>
  equipos.value.filter(e => {
    const p = progresoEquipo(e)
    return p.calificados < p.total
  }).length
)

const equipoIdx = computed(() =>
  equipoSeleccionado.value
    ? equipos.value.findIndex(e => e.id === equipoSeleccionado.value!.id)
    : -1
)

const equipoNext = computed(() =>
  equipoIdx.value >= 0 && equipoIdx.value < equipos.value.length - 1
    ? equipos.value[equipoIdx.value + 1]!
    : null
)

const criterioProgramadoIdx = computed(() =>
  criterioSeleccionado.value
    ? criteriosProgramados.value.findIndex(p => p.id === criterioSeleccionado.value!.id)
    : -1
)

const criterioNext = computed(() =>
  criterioProgramadoIdx.value >= 0 && criterioProgramadoIdx.value < criteriosProgramados.value.length - 1
    ? criteriosProgramados.value[criterioProgramadoIdx.value + 1]!
    : null
)

const liderazgoDoneCount = computed(() => {
  const total = equipos.value.length
  if (!total) return 0
  return liderazgoResumenDia.value.filter(
    r => r.indicadores_calificados === r.total_indicadores && (r.total_indicadores ?? 0) > 0
  ).length
})

// ── URL sync ──────────────────────────────────────────────────────────────────
watch([momentoActivo, tabActivo, equipoSeleccionado, criterioSeleccionado], () => {
  const query: Record<string, string> = {}
  if (momentoActivo.value) query.dia = momentoActivo.value
  if (tabActivo.value !== 'equipos') query.modo = tabActivo.value
  const id = equipoSeleccionado.value?.id ?? criterioSeleccionado.value?.id
  if (id) query.id = id
  router.replace({ query })
}, { flush: 'post' })

// ── Dialog motivo cambio ──────────────────────────────────────────────────────
const dialogMotivo    = ref(false)
const motivoPendiente = ref('')
const callbackMotivo  = ref<((motivo: string) => void) | null>(null)

// ── Dialog info criterio ──────────────────────────────────────────────────────
const dialogInfo  = ref(false)
const criterioInfo = ref<ProgramacionConCriterio | null>(null)

// ── Carga inicial ──────────────────────────────────────────────────────────────
async function cargar() {
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
  modoLiderazgoCriterio.value = false
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
  modoLiderazgoCriterio.value = false
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

async function guardarComentario(
  filasMap: Map<string, FilaEstado>,
  clave: string,
  equipo_id: string,
  programacion_id: string,
) {
  const fila = filasMap.get(clave)
  if (!fila || fila.puntaje === null) return
  await guardarPuntaje(filasMap, clave, fila.puntaje, equipo_id, programacion_id)
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

function pctBar(c: number, t: number) {
  return t === 0 ? 0 : Math.round((c / t) * 100)
}
</script>

<template>
  <div class="bg-[#F4F6F4] text-[#16201B] min-h-screen" style="font-family: Inter, system-ui, sans-serif">

    <!-- ══ CARGANDO ══ -->
    <div v-if="cargando" class="p-4 md:p-6 flex flex-col gap-3 max-w-2xl">
      <div class="h-11 rounded-xl bg-[#E3E7E4] animate-pulse" />
      <div class="h-9 rounded-xl bg-[#E3E7E4] animate-pulse w-48" />
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-2">
        <div v-for="i in 6" :key="i" class="h-36 rounded-2xl bg-[#E3E7E4] animate-pulse" />
      </div>
    </div>

    <!-- ══ ERROR ══ -->
    <div v-else-if="error" class="flex flex-col items-center gap-3 px-4 py-16 text-center">
      <div class="w-12 h-12 rounded-full bg-[#FEE2E2] flex items-center justify-center">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#DC2626" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>
      </div>
      <p class="text-[#16201B] font-semibold text-[15px]">{{ error }}</p>
      <button
        @click="cargar"
        class="h-11 px-6 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold cursor-pointer border-0"
      >Reintentar</button>
    </div>

    <template v-else>

      <!-- ══ PANTALLA DE ESPERA ══ -->
      <NotEvaluatedToday
        v-if="momentosDisponibles.length === 0 && !session.esAdmin"
        :countdown="countdown"
        :proximo-momento="proximoMomento"
        :momentos-futuros="momentosFuturos"
        :label-dia="labelDia"
      />

      <template v-else>

        <!-- ══ TABLET INTERNAL HEADER (768–1279px) ══ -->
        <header class="hidden md:flex xl:hidden sticky top-0 z-10 h-[72px] bg-white border-b border-[#E3E7E4] px-6 items-center gap-5 flex-shrink-0">
          <div class="flex flex-col min-w-[160px]">
            <span class="text-[18px] font-bold">Evaluar</span>
            <span class="text-[12px] text-[#5B6660]">LiderCamp 2026-II</span>
          </div>
          <DaySelector
            :momentos="momentosSelector"
            :activo="momentoActivo"
            :dias="dias"
            :fechas="fechas"
            :hoy="hoy"
            :label-dia="labelDia"
            @select="seleccionarMomento"
          />
          <div class="ml-auto flex items-center gap-3 flex-shrink-0">
            <ModeTabs :activo="tabActivo" @change="tabActivo = $event" />
            <button
              class="w-10 h-10 rounded-full border-0 bg-[#0E7C59] text-white font-bold text-[15px] flex-shrink-0 cursor-pointer"
              :aria-label="`Mi cuenta: ${session.perfil?.nombre_completo}`"
            >{{ iniciales }}</button>
          </div>
        </header>

        <!-- ══ DESKTOP DAY+MODE BAR (≥1280px) ══ -->
        <div class="hidden xl:flex sticky top-16 z-[9] h-[52px] bg-white border-b border-[#E3E7E4] px-8 items-center gap-6">
          <DaySelector
            :momentos="momentosSelector"
            :activo="momentoActivo"
            :dias="dias"
            :fechas="fechas"
            :hoy="hoy"
            :label-dia="labelDia"
            @select="seleccionarMomento"
          />
          <div class="ml-auto flex-shrink-0">
            <ModeTabs :activo="tabActivo" @change="tabActivo = $event" />
          </div>
        </div>

        <!-- ══ MOBILE DAY SELECTOR (<768px) ══ -->
        <div class="md:hidden bg-white border-b border-[#E3E7E4] px-4 py-3">
          <DaySelector
            :momentos="momentosSelector"
            :activo="momentoActivo"
            :dias="dias"
            :fechas="fechas"
            :hoy="hoy"
            :label-dia="labelDia"
            @select="seleccionarMomento"
          />
        </div>

        <!-- ══ ADMIN HINT (ningún día seleccionado) ══ -->
        <div v-if="momentoActivo === ''" class="flex items-center justify-center p-6 md:p-12">
          <div class="flex flex-col items-center gap-3 bg-white border border-[#E3E7E4] rounded-2xl p-8 text-center max-w-xs shadow-sm">
            <div class="w-12 h-12 rounded-full bg-[#E1F3EA] flex items-center justify-center text-[#0E7C59]">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
            </div>
            <h3 class="text-[16px] font-bold m-0">Selecciona un día</h3>
            <p class="text-[14px] text-[#5B6660] m-0 leading-[1.5]">Elige uno de los días de arriba para ver y registrar la evaluación.</p>
          </div>
        </div>

        <!-- ══ TWO-PANEL LAYOUT ══ -->
        <template v-else>

          <!-- Día cerrado banner (mobile) -->
          <div v-if="diaCerrado" class="md:hidden bg-[#FFF1D6] border-b border-[#FDE68A] px-4 py-2 flex items-center gap-2 text-[#7A4F00] text-[13px] font-semibold">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
            Día cerrado — solo lectura
          </div>

          <div class="md:flex md:items-start">

            <!-- ══ LEFT PANEL ══ -->
            <aside
              class="bg-white border-r border-[#E3E7E4] p-4 flex-shrink-0 flex flex-col gap-3 md:w-[340px] md:sticky md:top-[72px] md:h-[calc(100dvh-72px)] md:overflow-y-auto xl:top-[116px] xl:h-[calc(100dvh-116px)]"
              :class="(equipoSeleccionado || criterioSeleccionado || modoLiderazgoCriterio)
                ? 'hidden md:flex md:flex-col'
                : 'flex flex-col'"
            >
              <!-- Mobile: mode tabs -->
              <div class="md:hidden">
                <ModeTabs :activo="tabActivo" @change="tabActivo = $event" />
              </div>

              <!-- Search -->
              <label class="flex items-center gap-2.5 bg-[#F4F6F4] border border-[#DCE1DD] rounded-xl px-3 h-[42px] cursor-text">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
                <span class="sr-only">{{ tabActivo === 'equipos' ? 'Buscar equipo' : 'Buscar criterio' }}</span>
                <input
                  v-model="busqueda"
                  type="search"
                  :placeholder="tabActivo === 'equipos' ? 'Buscar equipo' : 'Buscar criterio'"
                  class="flex-1 bg-transparent border-0 outline-none text-[14px] text-[#16201B] placeholder:text-[#5B6660]"
                />
              </label>

              <!-- LISTA EQUIPOS -->
              <template v-if="tabActivo === 'equipos'">
                <div class="flex gap-1.5">
                  <button
                    @click="filtroEquipo = 'todos'"
                    class="h-8 px-3 rounded-2xl text-[12px] font-semibold transition-colors border-0 cursor-pointer"
                    :class="filtroEquipo === 'todos' ? 'bg-[#16201B] text-white' : 'bg-white text-[#16201B] border border-[#DCE1DD]'"
                  >Todos · {{ equipos.length }}</button>
                  <button
                    @click="filtroEquipo = 'pendientes'"
                    class="h-8 px-3 rounded-2xl text-[12px] font-semibold transition-colors cursor-pointer"
                    :class="filtroEquipo === 'pendientes' ? 'bg-[#16201B] text-white border-0' : 'bg-white text-[#16201B] border border-[#DCE1DD]'"
                  >Pendientes · {{ pendientesCount }}</button>
                  <button
                    @click="filtroEquipo = 'completos'"
                    class="h-8 px-3 rounded-2xl text-[12px] font-semibold transition-colors cursor-pointer"
                    :class="filtroEquipo === 'completos' ? 'bg-[#16201B] text-white border-0' : 'bg-white text-[#16201B] border border-[#DCE1DD]'"
                  >Completos · {{ completosCount }}</button>
                </div>
                <div class="flex flex-col gap-1">
                  <TeamRow
                    v-for="e in equiposFiltrados"
                    :key="e.id"
                    :equipo="e"
                    :progreso="progresoEquipo(e)"
                    :active="equipoSeleccionado?.id === e.id"
                    @click="seleccionarEquipo(e)"
                  />
                  <p v-if="!equiposFiltrados.length" class="text-[14px] text-[#5B6660] text-center py-6 m-0">Sin equipos</p>
                </div>
              </template>

              <!-- LISTA CRITERIOS -->
              <template v-else>
                <div v-for="g in criteriosAgrupados" :key="g.name" class="flex flex-col gap-1">
                  <h3 class="text-[11px] font-bold uppercase tracking-[0.6px] text-[#5B6660] mx-1 mb-1 mt-3 first:mt-0">{{ g.name }}</h3>
                  <CriterioRow
                    v-for="p in g.items"
                    :key="p.id"
                    :nombre="p.criterios.nombre"
                    :done="progresoCriterio(p).calificados"
                    :total="equipos.length"
                    :max="p.puntaje_max"
                    :active="criterioSeleccionado?.id === p.id"
                    @click="seleccionarCriterio(p)"
                  />
                </div>

                <CriterioRow
                  v-if="programacionLiderazgo"
                  nombre="Liderazgo de servicio"
                  :done="liderazgoDoneCount"
                  :total="equipos.length"
                  :active="modoLiderazgoCriterio"
                  :is-liderazgo="true"
                  @click="modoLiderazgoCriterio = true; criterioSeleccionado = null; equipoSeleccionado = null"
                />

                <details v-if="criteriosNoAplican.length" class="mt-1">
                  <summary class="text-[13px] font-semibold text-[#5B6660] cursor-pointer px-1 py-2 select-none flex items-center gap-1.5" style="list-style: none">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
                    No se evalúan hoy · {{ criteriosNoAplican.length }}
                  </summary>
                  <div class="flex flex-col gap-1 mt-1">
                    <div
                      v-for="p in criteriosNoAplican" :key="p.id"
                      class="flex items-center justify-between gap-2 px-3 py-2 rounded-xl bg-[#F4F6F4] text-[#5B6660] text-[13px] opacity-70"
                    >
                      <span>{{ p.criterios.nombre }}</span>
                      <span class="text-[11px] font-semibold">{{ p.estado === 'cancelado' ? 'Cancelado' : 'N/A' }}</span>
                    </div>
                  </div>
                </details>

                <p v-if="!criteriosProgramados.length && !programacionLiderazgo" class="text-[14px] text-[#5B6660] text-center py-6 m-0">Sin criterios para hoy</p>
              </template>
            </aside>

            <!-- ══ RIGHT PANEL ══ -->
            <main
              class="flex-1 min-w-0 md:flex md:flex-col"
              :class="(equipoSeleccionado || criterioSeleccionado || modoLiderazgoCriterio) ? 'flex flex-col' : 'hidden'"
            >
              <!-- Empty state tablet/desktop -->
              <div
                v-if="!equipoSeleccionado && !criterioSeleccionado && !modoLiderazgoCriterio"
                class="hidden md:flex flex-1 items-center justify-center min-h-[60vh]"
              >
                <div class="flex flex-col items-center gap-3 text-[#5B6660] text-center">
                  <div class="w-16 h-16 rounded-2xl bg-[#F4F6F4] flex items-center justify-center">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#DCE1DD" stroke-width="1.5" aria-hidden="true"><path d="M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9"/></svg>
                  </div>
                  <p class="text-[14px] font-medium m-0">Selecciona {{ tabActivo === 'equipos' ? 'un equipo' : 'un criterio' }} para comenzar</p>
                </div>
              </div>

              <!-- ── DETALLE DE EQUIPO ── -->
              <template v-if="equipoSeleccionado">
                <div class="sticky top-0 md:top-[72px] xl:top-[116px] z-[8] bg-[#F4F6F4] border-b border-[#E3E7E4]">
                  <div class="flex items-center gap-3 px-4 py-3 md:px-6">
                    <button
                      class="md:hidden w-10 h-10 rounded-full border border-[#E3E7E4] bg-white flex items-center justify-center text-[#16201B] flex-shrink-0 cursor-pointer"
                      @click="equipoSeleccionado = null"
                      aria-label="Volver"
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
                    </button>
                    <span
                      class="w-12 h-12 rounded-[14px] flex items-center justify-center font-bold text-[16px] text-white flex-shrink-0"
                      :style="{ background: equipoSeleccionado.color }"
                      aria-hidden="true"
                    >{{ inicialesEquipo(equipoSeleccionado.nombre) }}</span>
                    <div class="flex-1 flex flex-col gap-0.5 min-w-0">
                      <span class="text-[26px] font-bold tracking-tight leading-tight">{{ equipoSeleccionado.nombre }}</span>
                      <span class="text-[13px] text-[#5B6660]">{{ labelDia(momentoActivo) }} · {{ progresoEquipo(equipoSeleccionado).calificados }} de {{ progresoEquipo(equipoSeleccionado).total }} criterios</span>
                    </div>
                    <div class="hidden md:flex items-center gap-3 flex-shrink-0">
                      <span class="flex items-center gap-1.5 text-[13px] font-semibold text-[#0B6B4B]">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>
                        Guardado
                      </span>
                      <button
                        v-if="equipoNext"
                        @click="seleccionarEquipo(equipoNext)"
                        class="flex items-center gap-2 h-11 px-4 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold border-0 cursor-pointer"
                      >
                        Siguiente: {{ equipoNext.nombre }}
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                      </button>
                    </div>
                  </div>
                  <div class="h-1.5 bg-[#E3E7E4] overflow-hidden">
                    <div
                      class="h-full bg-[#0E7C59] transition-all duration-500"
                      :style="{ width: pctBar(progresoEquipo(equipoSeleccionado).calificados, progresoEquipo(equipoSeleccionado).total) + '%' }"
                    />
                  </div>
                  <div v-if="diaCerrado" class="hidden md:flex items-center gap-2 bg-[#FFF1D6] border-t border-[#FDE68A] px-6 py-2 text-[#7A4F00] text-[13px] font-semibold">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                    Día cerrado — solo lectura
                  </div>
                </div>

                <div class="p-4 md:p-6 xl:px-7 xl:py-5 flex flex-col gap-6 pb-32 md:pb-8">
                  <div v-for="g in programadosPorCategoria" :key="g.name" class="flex flex-col gap-3">
                    <h2 class="text-[12px] font-bold uppercase tracking-[0.6px] text-[#5B6660] ml-0.5 m-0">{{ g.name }}</h2>
                    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-3">
                      <article
                        v-for="prog in g.items"
                        :key="prog.id"
                        class="bg-white border border-[#E3E7E4] rounded-2xl p-3.5 flex flex-col gap-3 transition-colors"
                        :class="filasEquipo.get(prog.id)?.puntaje !== null ? 'border-[#A7F3D0]' : ''"
                      >
                        <div class="flex items-center gap-2">
                          <span class="flex-1 text-[15px] font-semibold">{{ prog.criterios.nombre }}</span>
                          <span class="text-[11px] font-semibold text-[#5B6660] flex-shrink-0">máx. {{ prog.puntaje_max }}</span>
                          <button
                            class="w-8 h-8 rounded-full border border-[#DCE1DD] bg-white flex items-center justify-center text-[#5B6660] cursor-pointer flex-shrink-0"
                            :aria-label="`Qué se evalúa en ${prog.criterios.nombre}`"
                            @click="abrirInfoCriterio(prog)"
                          >
                            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>
                          </button>
                          <span v-if="filasEquipo.get(prog.id)?.estado === 'guardando'" class="w-6 h-6 rounded-full border-2 border-[#E1F3EA] border-t-[#0E7C59] animate-spin flex-shrink-0" />
                          <span v-else-if="filasEquipo.get(prog.id)?.estado === 'guardado'" class="w-6 h-6 rounded-full bg-[#E1F3EA] text-[#0B6B4B] flex items-center justify-center flex-shrink-0">
                            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>
                          </span>
                          <span v-else-if="filasEquipo.get(prog.id)?.estado === 'error'" class="w-6 h-6 rounded-full bg-[#FEE2E2] text-[#DC2626] flex items-center justify-center text-[11px] flex-shrink-0">✕</span>
                        </div>

                        <ScoreButtons
                          :puntajes="puntajesPara(prog.puntaje_max)"
                          :selected="filasEquipo.get(prog.id)?.puntaje ?? null"
                          :disabled="diaCerrado"
                          @pick="onPuntajeEquipo(prog, $event)"
                        />

                        <p class="text-[12px] leading-[1.4] m-0"
                          :style="{ color: filasEquipo.get(prog.id)?.puntaje !== null ? '#16201B' : '#5B6660' }">
                          {{ filasEquipo.get(prog.id)?.puntaje !== null
                            ? (SCORE_NIVELES[nivelDe(filasEquipo.get(prog.id)?.puntaje, prog.puntaje_max)]?.descriptor ?? '')
                            : 'Toca una nota para calificar' }}
                        </p>

                        <div>
                          <button
                            class="flex items-center gap-1.5 text-[13px] text-[#5B6660] bg-transparent border-0 cursor-pointer p-0 min-h-[36px]"
                            @click="() => { const f = filasEquipo.get(prog.id); if (f) f.comentarioAbierto = !f.comentarioAbierto }"
                          >
                            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>
                            {{ filasEquipo.get(prog.id)?.comentarioAbierto ? 'Cerrar' : 'Comentario' }}
                          </button>
                          <Textarea
                            v-if="filasEquipo.get(prog.id)?.comentarioAbierto"
                            v-model="filasEquipo.get(prog.id)!.comentario"
                            rows="2"
                            class="w-full mt-1.5 text-[14px] rounded-xl"
                            placeholder="Comentario interno…"
                            :disabled="diaCerrado"
                            @blur="guardarComentario(filasEquipo, prog.id, equipoSeleccionado!.id, prog.id)"
                          />
                        </div>
                      </article>
                    </div>
                  </div>

                  <details v-if="criteriosNoAplican.length" class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
                    <summary class="px-4 py-3 font-semibold text-[14px] cursor-pointer flex items-center gap-2" style="list-style: none">
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
                      No se evalúan hoy · {{ criteriosNoAplican.length }}
                    </summary>
                    <div class="px-4 pb-3 flex flex-col gap-0.5">
                      <div
                        v-for="p in criteriosNoAplican" :key="p.id"
                        class="flex items-center justify-between gap-2 py-2 text-[13px] text-[#5B6660] border-t border-[#F4F6F4] first:border-0"
                      >
                        <span>{{ p.criterios.nombre }}</span>
                        <span class="font-semibold text-[11px]">{{ p.estado === 'cancelado' ? 'Cancelado' : 'N/A' }}</span>
                      </div>
                    </div>
                  </details>

                  <LiderazgoCard
                    v-if="programacionLiderazgo"
                    :equipoId="equipoSeleccionado.id"
                    :programacionId="programacionLiderazgo.id"
                    :readonly="diaCerrado"
                  />
                </div>

                <!-- Mobile footer -->
                <div class="md:hidden fixed bottom-20 inset-x-0 z-30 bg-white border-t border-[#E3E7E4] px-4 py-3 flex gap-3">
                  <button
                    v-if="equipoIdx > 0"
                    @click="seleccionarEquipo(equipos[equipoIdx - 1]!)"
                    class="flex-1 h-12 rounded-xl border border-[#DCE1DD] bg-white text-[14px] font-semibold cursor-pointer"
                  >← Anterior</button>
                  <div v-else class="flex-1" />
                  <button
                    v-if="equipoNext"
                    @click="seleccionarEquipo(equipoNext)"
                    class="flex-1 h-12 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold border-0 cursor-pointer"
                  >Siguiente: {{ equipoNext.nombre }}</button>
                </div>
              </template>

              <!-- ── LIDERAZGO POR CRITERIO ── -->
              <template v-else-if="modoLiderazgoCriterio && programacionLiderazgo">
                <div class="sticky top-0 md:top-[72px] xl:top-[116px] z-[8] bg-[#F4F6F4] border-b border-[#E3E7E4] flex items-center gap-3 px-4 py-3 md:px-6">
                  <button
                    class="md:hidden w-10 h-10 rounded-full border border-[#E3E7E4] bg-white flex items-center justify-center flex-shrink-0 cursor-pointer"
                    @click="modoLiderazgoCriterio = false"
                    aria-label="Volver"
                  >
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
                  </button>
                  <div class="w-12 h-12 rounded-[14px] bg-[#E1F3EA] flex items-center justify-center text-[#0E7C59] flex-shrink-0">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
                  </div>
                  <div class="flex-1 flex flex-col gap-0.5 min-w-0">
                    <span class="text-[26px] font-bold tracking-tight">Liderazgo de servicio</span>
                    <span class="text-[13px] text-[#5B6660]">{{ progresoCriterioLiderazgo }} equipos completos · {{ labelDia(momentoActivo) }}</span>
                  </div>
                </div>

                <div class="p-4 md:p-6 xl:px-7 xl:py-5 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-3">
                  <div v-for="equipo in equipos" :key="equipo.id" class="bg-white border border-[#E3E7E4] rounded-2xl p-4">
                    <div class="flex items-center gap-2 mb-3">
                      <span class="w-8 h-8 rounded-[9px] flex items-center justify-center font-bold text-[12px] text-white flex-shrink-0" :style="{ background: equipo.color }" aria-hidden="true">{{ inicialesEquipo(equipo.nombre) }}</span>
                      <span class="flex-1 text-[15px] font-semibold">{{ equipo.nombre }}</span>
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

              <!-- ── DETALLE DE CRITERIO ── -->
              <template v-else-if="criterioSeleccionado">
                <div class="sticky top-0 md:top-[72px] xl:top-[116px] z-[8] bg-[#F4F6F4] border-b border-[#E3E7E4]">
                  <div class="flex items-start gap-3 px-4 py-3 md:px-6">
                    <button
                      class="md:hidden w-10 h-10 rounded-full border border-[#E3E7E4] bg-white flex items-center justify-center flex-shrink-0 mt-0.5 cursor-pointer"
                      @click="criterioSeleccionado = null"
                      aria-label="Volver"
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
                    </button>
                    <div class="flex-1 flex flex-col gap-0.5 min-w-0">
                      <span class="text-[12px] font-bold uppercase tracking-[0.6px] text-[#5B6660]">{{ criterioSeleccionado.criterios.categoria }} · {{ labelDia(momentoActivo) }}</span>
                      <span class="text-[26px] font-bold tracking-tight leading-tight">{{ criterioSeleccionado.criterios.nombre }}</span>
                    </div>
                    <div class="flex items-center gap-3 flex-shrink-0 mt-1">
                      <span class="text-[12px] font-semibold px-2.5 py-1 rounded-lg bg-white border border-[#DCE1DD]">Máx. {{ criterioSeleccionado.puntaje_max }}</span>
                      <button
                        v-if="criterioNext"
                        @click="seleccionarCriterio(criterioNext)"
                        class="hidden md:flex items-center gap-2 h-11 px-4 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold border-0 cursor-pointer"
                      >
                        Siguiente: {{ criterioNext.criterios.nombre }}
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                      </button>
                    </div>
                  </div>

                  <div class="flex items-center gap-3 px-4 md:px-6 pb-3">
                    <span class="text-[13px] text-[#5B6660] flex-shrink-0">{{ progresoCriterio(criterioSeleccionado).calificados }} de {{ equipos.length }} equipos</span>
                    <div class="flex-1 h-1.5 bg-[#E3E7E4] rounded overflow-hidden">
                      <div
                        class="h-full bg-[#0E7C59] rounded transition-all duration-500"
                        :style="{ width: pctBar(progresoCriterio(criterioSeleccionado).calificados, equipos.length) + '%' }"
                      />
                    </div>
                  </div>

                  <div v-if="diaCerrado" class="hidden md:flex items-center gap-2 bg-[#FFF1D6] border-t border-[#FDE68A] px-6 py-2 text-[#7A4F00] text-[13px] font-semibold">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                    Día cerrado — solo lectura
                  </div>
                </div>

                <!-- Abarca / No abarca -->
                <div
                  v-if="criterioSeleccionado.criterios.abarca || criterioSeleccionado.criterios.no_abarca"
                  class="mx-4 md:mx-6 xl:mx-7 mt-4"
                >
                  <div class="bg-white border border-[#E3E7E4] rounded-2xl grid grid-cols-1 md:grid-cols-2 gap-3 p-4 text-[13px] leading-[1.45]">
                    <p v-if="criterioSeleccionado.criterios.abarca" class="m-0"><strong class="text-[#0B6B4B]">Abarca:</strong> {{ criterioSeleccionado.criterios.abarca }}</p>
                    <p v-if="criterioSeleccionado.criterios.no_abarca" class="m-0"><strong class="text-[#7A4F00]">No abarca:</strong> {{ criterioSeleccionado.criterios.no_abarca }}</p>
                  </div>
                </div>

                <!-- Team cards grid -->
                <div class="p-4 md:p-6 xl:px-7 xl:py-5 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-3 pb-32 md:pb-8 xl:pb-8">
                  <article
                    v-for="equipo in equipos"
                    :key="equipo.id"
                    class="bg-white border border-[#E3E7E4] rounded-2xl p-3.5 flex flex-col gap-3 transition-colors"
                    :class="filasCriterio.get(equipo.id)?.puntaje !== null ? 'border-[#A7F3D0]' : ''"
                  >
                    <div class="flex items-center gap-2.5">
                      <span
                        class="w-8 h-8 rounded-[9px] flex items-center justify-center font-bold text-[12px] text-white flex-shrink-0"
                        :style="{ background: equipo.color }"
                        aria-hidden="true"
                      >{{ inicialesEquipo(equipo.nombre) }}</span>
                      <span class="flex-1 text-[15px] font-semibold">{{ equipo.nombre }}</span>
                      <span v-if="filasCriterio.get(equipo.id)?.estado === 'guardando'" class="w-6 h-6 rounded-full border-2 border-[#E1F3EA] border-t-[#0E7C59] animate-spin flex-shrink-0" />
                      <span v-else-if="filasCriterio.get(equipo.id)?.estado === 'guardado'" class="w-6 h-6 rounded-full bg-[#E1F3EA] text-[#0B6B4B] flex items-center justify-center flex-shrink-0">
                        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>
                      </span>
                      <span v-else-if="filasCriterio.get(equipo.id)?.estado === 'error'" class="w-6 h-6 rounded-full bg-[#FEE2E2] text-[#DC2626] flex items-center justify-center text-[11px] flex-shrink-0">✕</span>
                      <span
                        v-else
                        class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0"
                        :class="filasCriterio.get(equipo.id)?.puntaje !== null ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#EEF0EE] text-[#4A544F]'"
                      >{{ filasCriterio.get(equipo.id)?.puntaje !== null ? 'Guardado' : 'Pendiente' }}</span>
                    </div>

                    <ScoreButtons
                      :puntajes="puntajesPara(criterioSeleccionado!.puntaje_max)"
                      :selected="filasCriterio.get(equipo.id)?.puntaje ?? null"
                      :disabled="diaCerrado"
                      @pick="onPuntajeCriterio(equipo, $event)"
                    />

                    <div class="flex items-center justify-between gap-2">
                      <p
                        class="text-[12px] leading-[1.4] m-0 flex-1"
                        :style="{ color: filasCriterio.get(equipo.id)?.puntaje !== null ? '#16201B' : '#5B6660' }"
                      >{{ filasCriterio.get(equipo.id)?.puntaje !== null
                        ? (SCORE_NIVELES[nivelDe(filasCriterio.get(equipo.id)?.puntaje, criterioSeleccionado!.puntaje_max)]?.descriptor ?? '')
                        : 'Toca una nota para calificar' }}</p>
                      <button
                        :aria-label="`Comentario para ${equipo.nombre}`"
                        class="flex-shrink-0 w-9 h-9 rounded-[10px] border border-[#DCE1DD] bg-white flex items-center justify-center cursor-pointer text-[#5B6660]"
                        @click="() => { const f = filasCriterio.get(equipo.id); if (f) f.comentarioAbierto = !f.comentarioAbierto }"
                      >
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>
                      </button>
                    </div>

                    <Textarea
                      v-if="filasCriterio.get(equipo.id)?.comentarioAbierto"
                      v-model="filasCriterio.get(equipo.id)!.comentario"
                      rows="2"
                      class="w-full text-[14px] rounded-xl"
                      placeholder="Comentario interno…"
                      :disabled="diaCerrado"
                      @blur="guardarComentario(filasCriterio, equipo.id, equipo.id, criterioSeleccionado!.id)"
                    />
                  </article>
                </div>

                <!-- Mobile footer -->
                <div class="md:hidden fixed bottom-20 inset-x-0 z-30 bg-white border-t border-[#E3E7E4] px-4 py-3 flex justify-end gap-3">
                  <button
                    v-if="criterioNext"
                    @click="seleccionarCriterio(criterioNext)"
                    class="flex-1 h-12 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold border-0 cursor-pointer"
                  >Siguiente: {{ criterioNext.criterios.nombre }}</button>
                  <div v-else class="flex-1" />
                </div>
              </template>

            </main>
          </div>
        </template>
      </template>
    </template>

    <!-- ══ DIALOG: Motivo de cambio ══ -->
    <Dialog v-model:visible="dialogMotivo" header="Motivo del cambio" modal :style="{ width: 'min(26rem, 95vw)' }">
      <p class="text-[14px] text-[#5B6660] mb-3">Este criterio ya tenía un puntaje. Indica el motivo:</p>
      <Textarea
        v-model="motivoPendiente"
        rows="3"
        class="w-full text-[15px] rounded-xl"
        placeholder="Ej: Corrección tras revisión…"
        autofocus
      />
      <template #footer>
        <div class="flex gap-2 justify-end">
          <button
            class="h-11 px-4 rounded-xl border border-[#E3E7E4] bg-white text-[14px] font-semibold text-[#5B6660] cursor-pointer"
            @click="dialogMotivo = false"
          >Cancelar</button>
          <button
            class="h-11 px-4 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold flex items-center gap-2 cursor-pointer border-0 disabled:opacity-50"
            :disabled="!motivoPendiente.trim()"
            @click="confirmarMotivo"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>
            Confirmar
          </button>
        </div>
      </template>
    </Dialog>

    <!-- ══ DIALOG: Info criterio ══ -->
    <Dialog v-model:visible="dialogInfo" :header="criterioInfo?.criterios.nombre ?? 'Criterio'" modal :style="{ width: 'min(30rem, 95vw)' }">
      <template v-if="criterioInfo">
        <div v-if="criterioInfo.criterios.abarca" class="mb-4">
          <p class="text-[13px] font-bold text-[#374151] flex items-center gap-1.5 mb-1 m-0">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>
            Abarca
          </p>
          <p class="text-[14px] text-[#5B6660] m-0">{{ criterioInfo.criterios.abarca }}</p>
        </div>
        <div v-if="criterioInfo.criterios.no_abarca" class="mb-4">
          <p class="text-[13px] font-bold text-[#374151] flex items-center gap-1.5 mb-1 m-0">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            No abarca
          </p>
          <p class="text-[14px] text-[#5B6660] m-0">{{ criterioInfo.criterios.no_abarca }}</p>
        </div>
        <div v-if="criterioInfo.criterios.evidencia" class="mb-4">
          <p class="text-[13px] font-bold text-[#374151] mb-1 m-0">📷 Evidencia</p>
          <p class="text-[14px] text-[#5B6660] m-0">{{ criterioInfo.criterios.evidencia }}</p>
        </div>
        <div class="mt-3 pt-3 border-t border-[#F4F6F4] flex flex-col gap-2">
          <div v-for="(nivel, idx) in SCORE_NIVELES" :key="idx" class="flex items-center gap-3">
            <span class="text-[12px] font-bold rounded-lg px-2 py-1 bg-[#F4F6F4] text-[#16201B] min-w-[44px] text-center flex-shrink-0">
              {{ labelScore(puntajesPara(criterioInfo.puntaje_max)[idx] ?? 0) }}
            </span>
            <span class="text-[13px] text-[#5B6660]">{{ nivel.descriptor }}</span>
          </div>
        </div>
      </template>
      <template #footer>
        <div class="flex justify-end">
          <button class="h-11 px-4 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold cursor-pointer border-0" @click="dialogInfo = false">Cerrar</button>
        </div>
      </template>
    </Dialog>

  </div>
</template>
