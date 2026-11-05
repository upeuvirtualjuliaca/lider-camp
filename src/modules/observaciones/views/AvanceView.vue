<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import {
  diasService,
  observacionesService,
  programacionRubricaService,
  type DiasEvaluacion,
  type PuntajeEquipoDia,
  type ProgresoEvaluacion,
} from '@/modules/observaciones/services/observaciones.service'
import {
  evaluacionesService,
  type LiderazgoEquipoDia,
} from '@/modules/liderazgo/services/liderazgo.service'
import {
  actividadesService,
  evalRegistrosService,
  type ActividadConProgramacion,
} from '@/modules/asistencia/services/asistencia.service'
import { incidenciasService } from '@/modules/incidencias/services/incidencias.service'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import ProgressRing   from '@/components/ui/ProgressRing.vue'
import DayStatusCard  from '../components/DayStatusCard.vue'
import ProgressMatrix from '../components/ProgressMatrix.vue'
import CriterionStrip from '../components/CriterionStrip.vue'
import type { MGroupData } from '../components/MatrixGroup.vue'
import type { MTeamData }  from '../components/ProgressMatrix.vue'

// ── Tipos ────────────────────────────────────────────────────────────────────
interface ProgramacionDia {
  id: string
  momento: string
  estado: string
  motivo: string | null
  puntaje_max: number
  criterio_id: string
  criterios: {
    id: string
    codigo: string
    nombre: string
    orden: number
    tipo_calculo: string
    activo: boolean
  }
}

// ── Constantes ────────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

// ── Estado ────────────────────────────────────────────────────────────────────
const session = useSessionStore()
const campStore = useCampamentoStore()
const cargando = ref(true)
const error = ref('')

const dias = ref<DiasEvaluacion[]>([])
const momentoActivo = ref<string>('')
const momentosConProg = ref<Set<string>>(new Set())

const equipos = ref<Equipo[]>([])
const programacionDia = ref<ProgramacionDia[]>([])
const puntajesDia = ref<PuntajeEquipoDia[]>([])
const progreso = ref<ProgresoEvaluacion[]>([])
const liderazgoDia = ref<LiderazgoEquipoDia[]>([])
const actividadesDia = ref<ActividadConProgramacion[]>([])
const actMap = ref<Map<string, number | null>>(new Map())
const bonusMap    = ref<Map<string, number>>(new Map())
const demeritosMap = ref<Map<string, number>>(new Map())
const obsMap = ref<Map<string, number | null>>(new Map())

// Dialogs
const dialogCerrar = ref(false)
const dialogAbrir = ref(false)
const procesandoDia = ref(false)
const errorDialog = ref('')

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const [, diasData, equiposData, momentosRubrica, conteosAct] = await Promise.all([
      cargarCampamento(),
      campStore.selectedId ? diasService.getTodos(campStore.selectedId) : Promise.resolve([]),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      programacionRubricaService.getMomentosConProgramacion(campStore.selectedId),
      campStore.selectedId ? actividadesService.getConteosPorCampamento(campStore.selectedId) : Promise.resolve({} as Record<string, number>),
    ])
    momentosConProg.value = new Set([...momentosRubrica, ...Object.keys(conteosAct)])

    momentoActivo.value = detectarMomentoActual()
    dias.value = diasData
    equipos.value = equiposData.filter((e) => e.activo)

    await cargarDatosDia()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

// ── Helpers ───────────────────────────────────────────────────────────────────
const momentosFiltrados = computed(() =>
  momentos.value.filter((m) => momentosConProg.value.has(m)),
)

const diaActual = computed<DiasEvaluacion | undefined>(() =>
  dias.value.find((d) => d.momento === momentoActivo.value),
)

const diaCerrado = computed(() => diaActual.value?.cerrado ?? false)

const progresoDelDia = computed<ProgresoEvaluacion | undefined>(() =>
  progreso.value.find((p) => p.momento === momentoActivo.value),
)

const porcentaje = computed(() => Math.round(progresoDelDia.value?.porcentaje ?? 0))

// Total del día por equipo: rúbrica + actividades + liderazgo + bonus − deméritos
const totalDiaMap = computed(() => {
  const map = new Map<string, number>()
  for (const eq of equipos.value) {
    const rubrica   = Number(puntajesDia.value.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
    const lid       = Number(liderazgoDia.value.find((l) => l.equipo_id === eq.id)?.puntos_obtenidos ?? 0)
    const bonus     = bonusMap.value.get(eq.id) ?? 0
    const demeritos = demeritosMap.value.get(eq.id) ?? 0

    let actividades = 0
    for (const act of actividadesDia.value) {
      actividades += actMap.value.get(`${act.id}|${eq.id}`) ?? 0
    }

    map.set(eq.id, Math.max(0, rubrica + lid + actividades + bonus - demeritos))
  }
  return map
})

async function cargarDatosDia() {
  try {
    const campId = campStore.selectedId
    const { data: progData, error: errProg } = await supabase_safe(() =>
      programacionRubricaService.getPorDia(momentoActivo.value, campId),
    )
    if (errProg) throw new Error(errProg)
    programacionDia.value = progData as unknown as ProgramacionDia[]

    const [puntajes, progresoData, lidData, actData] = await Promise.all([
      observacionesService.getPuntajeEquipoDia(momentoActivo.value, campId),
      observacionesService.getProgreso(campId),
      evaluacionesService.getResumenDia(momentoActivo.value, campId),
      actividadesService.getPorDia(momentoActivo.value),
    ])

    puntajesDia.value = puntajes
    progreso.value = progresoData
    liderazgoDia.value = lidData
    const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
    const contProg: Record<string, number> = {}
    for (const a of actFiltradas) {
      const pid = a.programacion_id ?? ''
      contProg[pid] = (contProg[pid] ?? 0) + 1
    }
    actividadesDia.value = actFiltradas.map((a) => ({
      ...a,
      _puntaje_individual: Math.round(a.programacion.puntaje_max / (contProg[a.programacion_id ?? ''] ?? 1)),
    })) as any

    const newActMap = new Map<string, number | null>()
    await Promise.all(
      actFiltradas.map(async (a) => {
        try {
          const registros = await evalRegistrosService.getPorActividad(a.id)
          const byKey = new Map<string, number[]>()
          for (const r of registros) {
            const key = `${r.criterio_eval_id}|${r.equipo_id}`
            if (!byKey.has(key)) byKey.set(key, [])
            byKey.get(key)!.push(Number(r.puntaje))
          }
          const totales: Record<string, number> = {}
          for (const [key, puntajes] of byKey) {
            const equipoId = key.split('|')[1] ?? ''
            if (!equipoId) continue
            const avg = puntajes.reduce((a, b) => a + b, 0) / puntajes.length
            totales[equipoId] = (totales[equipoId] ?? 0) + avg
          }
          for (const [equipoId, total] of Object.entries(totales)) {
            newActMap.set(`${a.id}|${equipoId}`, total)
          }
        } catch { /* silencioso */ }
      }),
    )
    actMap.value = newActMap

    const newBonusMap     = new Map<string, number>()
    const newDemeritosMap = new Map<string, number>()
    const incData = await incidenciasService.getValidadasPorMomento(momentoActivo.value, campId)
    for (const inc of incData) {
      if (inc.tipo === 'bonus') {
        newBonusMap.set(inc.equipo_id, (newBonusMap.get(inc.equipo_id) ?? 0) + inc.puntos)
      } else if (inc.tipo === 'demerito') {
        newDemeritosMap.set(inc.equipo_id, (newDemeritosMap.get(inc.equipo_id) ?? 0) + inc.puntos)
      }
    }
    bonusMap.value     = newBonusMap
    demeritosMap.value = newDemeritosMap

    await cargarObservacionesDetalle()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos del día'
  }
}

async function cargarObservacionesDetalle() {
  obsMap.value = new Map()
  const promises = programacionDia.value
    .filter((p) => p.estado === 'programado')
    .map(async (prog) => {
      try {
        const obs = await observacionesService.getPorCriterioYDia(prog.id)
        const byEquipo = new Map<string, number[]>()
        for (const o of obs) {
          if (!byEquipo.has(o.equipo_id)) byEquipo.set(o.equipo_id, [])
          byEquipo.get(o.equipo_id)!.push(o.puntaje)
        }
        for (const [equipo_id, puntajes] of byEquipo) {
          const avg = Math.round(puntajes.reduce((a, b) => a + b, 0) / puntajes.length)
          obsMap.value.set(`${prog.id}|${equipo_id}`, avg)
        }
      } catch {
        // silencioso por criterio
      }
    })
  await Promise.all(promises)
}

async function seleccionarMomento(m: string) {
  momentoActivo.value = m
  await cargarDatosDia()
}

// ── Celda de la matriz ────────────────────────────────────────────────────────
function getCelda(
  prog: ProgramacionDia,
  equipo: Equipo,
): { tipo: 'puntaje' | 'cancelado' | 'na' | 'pendiente'; valor: number | null } {
  if (prog.estado === 'no_programado') return { tipo: 'na', valor: null }
  if (prog.estado === 'cancelado') return { tipo: 'cancelado', valor: null }
  const key = `${prog.id}|${equipo.id}`
  const val = obsMap.value.get(key)
  if (val !== undefined && val !== null) return { tipo: 'puntaje', valor: val }
  return { tipo: 'pendiente', valor: null }
}

// ── Cerrar / Abrir día ────────────────────────────────────────────────────────
async function cerrarDia() {
  procesandoDia.value = true
  errorDialog.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    const updated = await diasService.cerrar(campStore.selectedId, momentoActivo.value, session.user!.id)
    const idx = dias.value.findIndex((d) => d.momento === momentoActivo.value)
    if (idx !== -1) dias.value[idx] = updated
    dialogCerrar.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al cerrar el día'
  } finally {
    procesandoDia.value = false
  }
}

async function abrirDia() {
  procesandoDia.value = true
  errorDialog.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    const updated = await diasService.abrir(campStore.selectedId, momentoActivo.value)
    const idx = dias.value.findIndex((d) => d.momento === momentoActivo.value)
    if (idx !== -1) dias.value[idx] = updated
    dialogAbrir.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al reabrir el día'
  } finally {
    procesandoDia.value = false
  }
}

// ── Celda de liderazgo ────────────────────────────────────────────────────────
function getLidCelda(equipo: Equipo): { clase: string; texto: string } {
  const d = liderazgoDia.value.find((r) => r.equipo_id === equipo.id)
  if (!d) return { clase: 'bg-gray-50 text-gray-400', texto: '—' }
  if ((d.indicadores_calificados ?? 0) === 0) return { clase: 'bg-yellow-50 text-yellow-700', texto: '' }
  const pts = Number(d.puntos_obtenidos)
  const texto = `${pts % 1 === 0 ? pts : pts.toFixed(1)} (${d.indicadores_calificados}/${d.total_indicadores})`
  const clase = d.indicadores_calificados === d.total_indicadores
    ? 'bg-green-100 text-green-800 font-bold'
    : 'bg-yellow-50 text-yellow-700'
  return { clase, texto }
}

// wrapper helper
async function supabase_safe<T>(fn: () => Promise<T>): Promise<{ data: T; error: null } | { data: null; error: string }> {
  try {
    const data = await fn()
    return { data, error: null }
  } catch (e: unknown) {
    return { data: null, error: e instanceof Error ? e.message : 'Error desconocido' }
  }
}

// ── Display helpers (solo presentación) ──────────────────────────────────────
const esAdmin    = computed(() => session.rol === 'admin')
const closedGroups = ref<Set<string>>(new Set())
const mobileTab  = ref<'criterio' | 'equipo'>('criterio')

function toggleGroup(id: string) {
  const s = new Set(closedGroups.value)
  s.has(id) ? s.delete(id) : s.add(id)
  closedGroups.value = s
}

function iniciales(nombre: string): string {
  const words = nombre.trim().split(/\s+/).filter(Boolean)
  if (words.length >= 2) return (words[0]![0]! + words[1]![0]!).toUpperCase()
  return nombre.substring(0, 2).toUpperCase()
}

const pendientesCount = computed(() =>
  Math.max(0,
    (progresoDelDia.value?.observaciones_esperadas ?? 0) -
    (progresoDelDia.value?.observaciones_registradas ?? 0),
  )
)

// Group definitions
const GRUPOS_DEF = [
  { id: 'armado',     nombre: 'Armado del campamento',   keys: ['Carpa', 'Cerco', 'Basurero', 'Tendedero', 'Portada'] },
  { id: 'cocina',     nombre: 'Orden y cocina',          keys: ['Orden', 'Cocina'] },
  { id: 'ceremonias', nombre: 'Ceremonias y conducta',   keys: ['Izamiento', 'Barra', 'Programa', 'Participación', 'Respeta', 'Campamento'] },
]

function getGrupoId(nombre: string): string {
  for (const g of GRUPOS_DEF) {
    if (g.keys.some(k => nombre.startsWith(k) || nombre.includes(k))) return g.id
  }
  return 'otros'
}

interface MCellData  { tipo: 'puntaje'|'pendiente'|'na'|'cancelado'; valor?: string|null }
interface MRowData   { id: string; nombre: string; maxLabel: string; nameColor: string; cells: MCellData[]; av: string; avColor: string }

function buildMRows(progs: ProgramacionDia[]): MRowData[] {
  return progs.map(prog => {
    const cells: MCellData[] = equipos.value.map(eq => {
      const c = getCelda(prog, eq)
      return { tipo: c.tipo, valor: c.tipo === 'puntaje' ? String(c.valor) : null }
    })
    const done = cells.filter(c => c.tipo === 'puntaje').length
    const naAll = prog.estado === 'no_programado'
    return {
      id: prog.id,
      nombre: prog.criterios.nombre,
      maxLabel: naAll ? 'no se evalúa hoy' : `máx. ${prog.puntaje_max}`,
      nameColor: naAll ? '#8A948E' : '#16201B',
      cells,
      av: naAll ? '—' : `${done}/12`,
      avColor: done === 12 ? '#0B6B4B' : '#16201B',
    }
  })
}

const teamColumns = computed((): MTeamData[] => {
  const pctMap = new Map<string, number>()
  for (const eq of equipos.value) {
    let d = 0, t = 0
    for (const prog of programacionDia.value) {
      if (prog.estado === 'programado') {
        t++
        if (obsMap.value.get(`${prog.id}|${eq.id}`) != null) d++
      }
    }
    pctMap.set(eq.id, t ? Math.round(d / t * 100) : 0)
  }
  return equipos.value.map(eq => ({
    id: eq.id,
    nombre: eq.nombre,
    color: (eq as any).color ?? '#0E7C59',
    iniciales: iniciales(eq.nombre),
    pct: pctMap.get(eq.id) ?? 0,
  }))
})

const gruposMatriz = computed((): MGroupData[] => {
  const byId = new Map<string, ProgramacionDia[]>()
  for (const prog of programacionDia.value) {
    const gid = getGrupoId(prog.criterios.nombre)
    if (!byId.has(gid)) byId.set(gid, [])
    byId.get(gid)!.push(prog)
  }

  const defs = [...GRUPOS_DEF, ...(byId.has('otros') ? [{ id: 'otros', nombre: 'Otros criterios', keys: [] as string[] }] : [])]
  const result: MGroupData[] = defs
    .filter(g => byId.has(g.id))
    .map(g => {
      const rows = buildMRows(byId.get(g.id)!)
      let td = 0, tt = 0
      for (const r of rows) for (const c of r.cells) { if (c.tipo !== 'na') { tt++; if (c.tipo === 'puntaje') td++ } }
      return { id: g.id, nombre: g.nombre, rows, summary: `${td} de ${tt}`, pct: tt ? Math.round(td / tt * 100) : 0, open: !closedGroups.value.has(g.id) }
    })

  // Actividades
  if (actividadesDia.value.length) {
    const actRows: MRowData[] = (actividadesDia.value as any[]).map(act => {
      const cells: MCellData[] = equipos.value.map(eq => {
        const v = actMap.value.get(`${act.id}|${eq.id}`)
        return { tipo: v != null ? 'puntaje' as const : 'pendiente' as const, valor: v != null ? String(Math.round(v)) : null }
      })
      const done = cells.filter(c => c.tipo === 'puntaje').length
      return { id: act.id, nombre: act.nombre, maxLabel: `máx. ${act._puntaje_individual ?? act.programacion?.puntaje_max ?? ''}`, nameColor: '#16201B', cells, av: `${done}/12`, avColor: done === 12 ? '#0B6B4B' : '#16201B' }
    })
    const td = actRows.reduce((s, r) => s + r.cells.filter(c => c.tipo === 'puntaje').length, 0)
    const tt = actRows.reduce((s, r) => s + r.cells.filter(c => c.tipo !== 'na').length, 0)
    result.push({ id: 'actividades', nombre: 'Actividades', rows: actRows, summary: `${td} de ${tt}`, pct: tt ? Math.round(td / tt * 100) : 0, open: !closedGroups.value.has('actividades') })
  }

  // Liderazgo
  if (liderazgoDia.value.length) {
    const cells: MCellData[] = equipos.value.map(eq => {
      const c = getLidCelda(eq)
      const isOk = c.texto && c.texto !== '—' && !c.clase.includes('yellow')
      return { tipo: isOk ? 'puntaje' as const : (c.texto === '' ? 'pendiente' as const : 'na' as const), valor: c.texto || null }
    })
    const done = cells.filter(c => c.tipo === 'puntaje').length
    result.push({ id: 'liderazgo', nombre: 'Liderazgo', rows: [{ id: 'lid', nombre: 'Liderazgo', maxLabel: 'máx. 100', nameColor: '#16201B', cells, av: `${done}/12`, avColor: done === 12 ? '#0B6B4B' : '#16201B' }], summary: `${done} de 12`, pct: Math.round(done / 12 * 100), open: !closedGroups.value.has('liderazgo') })
  }

  // Ajustes
  if (bonusMap.value.size || demeritosMap.value.size) {
    const bCells: MCellData[] = equipos.value.map(eq => { const v = bonusMap.value.get(eq.id) ?? 0; return { tipo: v > 0 ? 'puntaje' as const : 'na' as const, valor: v > 0 ? `+${v}` : null } })
    const dCells: MCellData[] = equipos.value.map(eq => { const v = demeritosMap.value.get(eq.id) ?? 0; return { tipo: v > 0 ? 'cancelado' as const : 'na' as const, valor: v > 0 ? `−${v}` : null } })
    result.push({ id: 'ajustes', nombre: 'Ajustes validados', rows: [{ id: 'bonus', nombre: 'Bonus', maxLabel: 'validados', nameColor: '#16201B', cells: bCells, av: '', avColor: '#16201B' }, { id: 'demerito', nombre: 'Deméritos', maxLabel: 'validados', nameColor: '#16201B', cells: dCells, av: '', avColor: '#16201B' }], summary: 'bonus y deméritos', pct: 100, open: !closedGroups.value.has('ajustes') })
  }

  return result
})

const totalRow = computed(() => equipos.value.map(eq => String(totalDiaMap.value.get(eq.id) ?? 0)))

// Mobile stats
const teamStats = computed(() => equipos.value.map(eq => {
  const prog = programacionDia.value.filter(p => p.estado === 'programado')
  const done = prog.filter(p => obsMap.value.get(`${p.id}|${eq.id}`) != null).length
  const pct  = prog.length ? Math.round(done / prog.length * 100) : 0
  return { ...eq, iniciales: iniciales(eq.nombre), color: (eq as any).color ?? '#0E7C59', pct, pts: totalDiaMap.value.get(eq.id) ?? 0, done, total: prog.length }
}))

const mobileGrupos = computed(() =>
  gruposMatriz.value.map(g => ({
    ...g,
    rows: g.rows.map(r => ({
      ...r,
      dots: r.cells.map(c =>
        c.tipo === 'puntaje'   ? '#0E7C59' :
        c.tipo === 'pendiente' ? '#F3C969' :
        c.tipo === 'cancelado' ? '#F4A6A6' : '#E3E7E4',
      ),
    })),
  })),
)

const noCriterios = computed(() => !programacionDia.value.length && !liderazgoDia.value.length && !actividadesDia.value.length)
</script>

<template>
  <div
    class="flex flex-col flex-1 min-h-0 overflow-hidden"
    style="font-family: Inter, system-ui, sans-serif; background: #F4F6F4; color: #16201B"
  >

    <!-- ═══════════════ LOADING SKELETON ═══════════════ -->
    <div v-if="cargando" class="flex-1 overflow-y-auto p-6 flex flex-col gap-4">
      <!-- Header skeleton -->
      <div class="bg-white border border-[#E3E7E4] rounded-2xl h-16 animate-pulse" />
      <!-- Summary skeleton -->
      <div class="flex gap-3">
        <div class="flex-[2] bg-white border border-[#E3E7E4] rounded-2xl h-24 animate-pulse" />
        <div class="flex-1 bg-white border border-[#E3E7E4] rounded-2xl h-24 animate-pulse" />
      </div>
      <!-- Matrix skeleton -->
      <div class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
        <div class="h-12 border-b border-[#EEF1EF] animate-pulse bg-[#F4F6F4]" />
        <div v-for="i in 6" :key="i" class="h-11 border-b border-[#EEF1EF] animate-pulse" :class="i % 2 === 0 ? 'bg-[#FAFBFA]' : 'bg-white'" />
      </div>
    </div>

    <!-- ═══════════════ ERROR ═══════════════ -->
    <div v-else-if="error" class="flex-1 flex items-center justify-center p-8 text-center">
      <div class="flex flex-col items-center gap-3">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#A3261F" stroke-width="1.5" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></svg>
        <p class="text-[14px] text-[#A3261F]">{{ error }}</p>
        <button class="h-9 px-4 rounded-xl bg-[#0E7C59] text-white text-[13px] font-semibold font-[inherit]" @click="cargar">Reintentar</button>
      </div>
    </div>

    <template v-else>

      <!-- ══════════════════════════════════
           MOBILE: < md
      ══════════════════════════════════ -->
      <div class="md:hidden flex flex-col flex-1 overflow-hidden">

        <!-- Mobile header -->
        <header class="bg-white border-b border-[#E3E7E4] flex-shrink-0">
          <!-- Title row -->
          <div class="flex items-center justify-between px-4 h-14">
            <div class="flex flex-col">
              <span class="text-[17px] font-bold text-[#16201B] leading-tight">Avance</span>
              <span class="text-[12px] text-[#5B6660]">Seguimiento</span>
            </div>
          </div>
          <!-- Day selector -->
          <div
            role="tablist"
            aria-label="Día"
            class="flex gap-1.5 overflow-x-auto px-4 pb-3 scrollbar-none"
          >
            <button
              v-for="m in momentosFiltrados"
              :key="m"
              role="tab"
              :aria-selected="momentoActivo === m"
              class="flex-shrink-0 h-[38px] px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit]"
              :class="momentoActivo === m
                ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
                : 'bg-white text-[#16201B] border-[#DCE1DD]'"
              @click="seleccionarMomento(m)"
            >
              {{ labelDia(m) }}
              <svg v-if="dias.find(d => d.momento === m)?.cerrado" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" class="inline ml-1" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
            </button>
          </div>
          <!-- View tabs -->
          <div role="tablist" aria-label="Vista" class="flex gap-6 px-4">
            <button
              role="tab"
              :aria-selected="mobileTab === 'criterio'"
              class="pb-3 text-[14px] border-b-2 font-[inherit] transition-colors"
              :class="mobileTab === 'criterio'
                ? 'text-[#0E7C59] font-semibold border-[#0E7C59]'
                : 'text-[#5B6660] font-medium border-transparent'"
              @click="mobileTab = 'criterio'"
            >Por criterio</button>
            <button
              role="tab"
              :aria-selected="mobileTab === 'equipo'"
              class="pb-3 text-[14px] border-b-2 font-[inherit] transition-colors"
              :class="mobileTab === 'equipo'
                ? 'text-[#0E7C59] font-semibold border-[#0E7C59]'
                : 'text-[#5B6660] font-medium border-transparent'"
              @click="mobileTab = 'equipo'"
            >Por equipo</button>
          </div>
        </header>

        <!-- Mobile content -->
        <main class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">

          <!-- Summary card -->
          <section class="bg-white border border-[#E3E7E4] rounded-2xl px-4 py-3.5 flex items-center gap-3">
            <ProgressRing :percent="porcentaje" :size="56" :thickness="8" />
            <div class="flex-1 flex flex-col gap-0.5">
              <span class="text-[16px] font-bold">
                {{ progresoDelDia?.observaciones_registradas ?? 0 }}
                <span class="text-[14px] font-normal text-[#5B6660]">de {{ progresoDelDia?.observaciones_esperadas ?? 0 }}</span>
              </span>
              <span class="text-[12px] text-[#5B6660]">observaciones registradas</span>
              <span v-if="pendientesCount > 0" class="text-[12px] font-semibold text-[#7A4F00]">{{ pendientesCount }} pendientes</span>
            </div>
            <span
              class="self-start flex items-center gap-1 text-[11px] font-semibold px-2 py-1 rounded-[10px]"
              :class="diaCerrado ? 'bg-[#EEF1EF] text-[#5B6660]' : 'bg-[#E1F3EA] text-[#0B6B4B]'"
            >
              <svg v-if="diaCerrado" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
              <span v-else class="w-[6px] h-[6px] rounded-full bg-[#0E7C59]" aria-hidden="true" />
              {{ diaCerrado ? 'Cerrado' : 'Abierto' }}
            </span>
          </section>

          <!-- Sin criterios -->
          <div v-if="noCriterios" class="bg-white border border-[#E3E7E4] rounded-2xl px-5 py-10 text-center">
            <p class="text-[14px] text-[#5B6660]">No hay criterios programados para este día.</p>
          </div>

          <!-- Por criterio -->
          <template v-else-if="mobileTab === 'criterio'">
            <section v-for="g in mobileGrupos" :key="g.id" class="flex flex-col gap-2">
              <div class="flex items-baseline justify-between px-1">
                <h2 class="m-0 text-[12px] font-bold uppercase tracking-[0.6px] text-[#5B6660]">{{ g.nombre }}</h2>
                <span class="text-[12px] text-[#5B6660]">{{ g.summary }}</span>
              </div>
              <ul class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden list-none m-0 p-0">
                <CriterionStrip
                  v-for="row in g.rows"
                  :key="row.id"
                  :nombre="row.nombre"
                  :nameColor="row.nameColor"
                  :dots="(row as any).dots"
                  :av="row.av"
                  :avColor="row.avColor"
                />
              </ul>
            </section>
            <p class="text-[12px] text-[#5B6660] text-center mt-1 mb-3">
              <span class="inline-flex items-center gap-1 mr-3"><span class="w-3 h-2 rounded-sm bg-[#0E7C59] inline-block" /> Calificado</span>
              <span class="inline-flex items-center gap-1 mr-3"><span class="w-3 h-2 rounded-sm bg-[#F3C969] inline-block" /> Pendiente</span>
              <span class="inline-flex items-center gap-1"><span class="w-3 h-2 rounded-sm bg-[#E3E7E4] inline-block" /> No hoy</span>
            </p>
          </template>

          <!-- Por equipo -->
          <template v-else>
            <ul class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden list-none m-0 p-0">
              <li v-for="eq in teamStats" :key="eq.id" class="border-b border-[#EEF1EF] last:border-b-0">
                <div class="flex items-center gap-3 px-4 min-h-[62px] py-3">
                  <span
                    class="w-[38px] h-[38px] rounded-[11px] flex items-center justify-center font-bold text-[13px] text-white flex-shrink-0"
                    :style="{ background: eq.color }"
                  >{{ eq.iniciales }}</span>
                  <div class="flex-1 min-w-0 flex flex-col gap-0.5">
                    <span class="text-[15px] font-semibold text-[#16201B] truncate">{{ eq.nombre }}</span>
                    <span class="text-[12px] text-[#5B6660]">{{ eq.done }}/{{ eq.total }} calificados · {{ eq.pts }} pts</span>
                  </div>
                  <ProgressRing :percent="eq.pct" :size="38" :thickness="6" />
                </div>
              </li>
            </ul>
          </template>

        </main>

        <!-- Mobile footer: solo admin -->
        <footer v-if="esAdmin" class="bg-white border-t border-[#E3E7E4] px-4 py-3 flex-shrink-0">
          <button
            v-if="!diaCerrado"
            class="w-full h-[50px] rounded-[14px] border border-[#16201B] bg-white text-[15px] font-semibold text-[#16201B] flex items-center justify-center gap-2 font-[inherit]"
            @click="dialogCerrar = true"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
            Cerrar día
          </button>
          <button
            v-else
            class="w-full h-[50px] rounded-[14px] border border-[#DCE1DD] bg-white text-[15px] font-semibold text-[#16201B] flex items-center justify-center gap-2 font-[inherit]"
            @click="dialogAbrir = true"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="14" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>
            Reabrir día
          </button>
        </footer>
      </div>

      <!-- ══════════════════════════════════
           TABLET + DESKTOP: ≥ md
      ══════════════════════════════════ -->
      <div class="hidden md:flex flex-col flex-1 overflow-hidden">

        <!-- Header -->
        <header class="bg-white border-b border-[#E3E7E4] px-6 py-3 flex flex-wrap items-center gap-3 flex-shrink-0">
          <div class="flex flex-col mr-auto">
            <span class="text-[12px] text-[#5B6660]">Seguimiento</span>
            <span class="text-[18px] font-bold text-[#16201B]">Avance de evaluación</span>
          </div>
          <!-- Day tabs -->
          <div role="tablist" aria-label="Día" class="flex gap-1.5 flex-wrap">
            <button
              v-for="m in momentosFiltrados"
              :key="m"
              role="tab"
              :aria-selected="momentoActivo === m"
              class="h-[38px] px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit] flex items-center gap-1.5"
              :class="momentoActivo === m
                ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
                : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
              @click="seleccionarMomento(m)"
            >
              {{ labelDia(m) }}
              <svg v-if="dias.find(d => d.momento === m)?.cerrado" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
            </button>
          </div>
        </header>

        <!-- Content area -->
        <div class="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">

          <!-- Summary row -->
          <section aria-label="Resumen" class="flex flex-wrap gap-3">
            <!-- Progress card -->
            <div class="flex-[2_1_320px] bg-white border border-[#E3E7E4] rounded-2xl px-5 py-4 flex items-center gap-4">
              <ProgressRing :percent="porcentaje" :size="64" :thickness="9" />
              <div class="flex flex-col gap-1">
                <span class="text-[13px] text-[#5B6660]">Observaciones registradas · {{ labelDia(momentoActivo) }}</span>
                <span class="text-[22px] font-bold leading-tight">
                  {{ progresoDelDia?.observaciones_registradas ?? 0 }}
                  <span class="text-[14px] font-medium text-[#5B6660]">de {{ progresoDelDia?.observaciones_esperadas ?? 0 }}</span>
                </span>
                <span v-if="pendientesCount > 0" class="text-[12px] font-semibold text-[#7A4F00]">{{ pendientesCount }} pendientes</span>
              </div>
            </div>
            <!-- Day status card -->
            <div class="flex-[1_1_280px] bg-white border border-[#E3E7E4] rounded-2xl px-5 py-4">
              <DayStatusCard
                :cerrado="diaCerrado"
                :esAdmin="esAdmin"
                :pendientes="pendientesCount"
                @cerrar="dialogCerrar = true"
                @reabrir="dialogAbrir = true"
              />
            </div>
          </section>

          <!-- Matrix section -->
          <section aria-label="Matriz de avance" class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
            <!-- Matrix header + legend -->
            <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3.5 border-b border-[#EEF1EF]">
              <h2 class="m-0 text-[15px] font-bold text-[#16201B]">Criterios × equipos</h2>
              <div class="flex flex-wrap gap-4 text-[12px] text-[#5B6660]">
                <span class="flex items-center gap-1.5">
                  <span class="w-[22px] h-[16px] rounded-[4px] bg-[#E1F3EA] text-[10px] font-bold text-[#0B6B4B] flex items-center justify-center">25</span>
                  Calificado
                </span>
                <span class="flex items-center gap-1.5">
                  <span class="w-[22px] h-[16px] rounded-[4px] bg-[#FFF1D6] flex items-center justify-center">
                    <span class="w-[6px] h-[6px] rounded-full bg-[#B07800]" />
                  </span>
                  Pendiente
                </span>
                <span class="flex items-center gap-1.5">
                  <span class="w-[22px] h-[16px] rounded-[4px] bg-[#F4F6F4] text-[10px] text-[#8A948E] flex items-center justify-center">—</span>
                  No se evalúa hoy
                </span>
                <span class="flex items-center gap-1.5">
                  <span class="w-[22px] h-[16px] rounded-[4px] bg-[#FDECEC] text-[10px] text-[#A3261F] font-semibold flex items-center justify-center">×</span>
                  Cancelado
                </span>
              </div>
            </div>

            <!-- Sin criterios -->
            <div v-if="noCriterios" class="px-5 py-10 text-center">
              <p class="text-[14px] text-[#5B6660] m-0">No hay criterios programados para este día.</p>
            </div>

            <!-- Matrix table: compact on tablet (md < xl), full on xl -->
            <ProgressMatrix
              v-else
              :equipos="teamColumns"
              :grupos="gruposMatriz"
              :totalRow="totalRow"
              :compact="false"
              @toggleGroup="toggleGroup"
            />
          </section>

        </div>
      </div>

    </template>

    <!-- ═══════════════ MODAL CERRAR DÍA ═══════════════ -->
    <Teleport to="body">
      <div v-if="dialogCerrar" class="fixed inset-0 z-[200] flex items-end justify-center sm:items-center bg-black/45 backdrop-blur-sm" @click.self="dialogCerrar = false">
        <div class="w-full max-w-[360px] bg-white rounded-[20px_20px_0_0] sm:rounded-2xl px-6 pt-5 pb-8 sm:py-6 flex flex-col items-center gap-3 shadow-xl">
          <div class="w-9 h-1 rounded-full bg-[#E3E7E4] mb-1 sm:hidden" />
          <div class="w-13 h-13 rounded-full bg-[#EEF1EF] flex items-center justify-center">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#16201B" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
          </div>
          <h3 class="m-0 text-[16px] font-bold text-[#16201B]">¿Cerrar el día?</h3>
          <p class="m-0 text-[14px] text-[#5B6660] text-center">{{ labelDia(momentoActivo) }}</p>
          <p class="m-0 text-[13px] text-[#5B6660] text-center leading-snug">
            Los evaluadores ya no podrán registrar observaciones.
            <template v-if="pendientesCount > 0">
              <strong class="text-[#7A4F00]">Quedan {{ pendientesCount }} observaciones pendientes.</strong>
            </template>
          </p>
          <div v-if="errorDialog" class="w-full text-[13px] text-[#A3261F] bg-[#FDECEC] rounded-xl px-3 py-2.5">{{ errorDialog }}</div>
          <div class="flex gap-2.5 w-full mt-1">
            <button class="flex-1 h-11 rounded-xl border border-[#DCE1DD] bg-white text-[14px] font-semibold text-[#16201B] font-[inherit]" :disabled="procesandoDia" @click="dialogCerrar = false">Cancelar</button>
            <button class="flex-1 h-11 rounded-xl border border-[#16201B] bg-white text-[14px] font-semibold text-[#16201B] font-[inherit] flex items-center justify-center gap-2 disabled:opacity-50" :disabled="procesandoDia" @click="cerrarDia">
              <svg v-if="!procesandoDia" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
              <svg v-else class="animate-spin" width="15" height="15" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="#16201B" stroke-width="3" stroke-opacity=".25"/><path d="M12 2a10 10 0 0 1 10 10" stroke="#16201B" stroke-width="3" stroke-linecap="round"/></svg>
              {{ procesandoDia ? 'Cerrando…' : 'Cerrar día' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ═══════════════ MODAL REABRIR DÍA ═══════════════ -->
    <Teleport to="body">
      <div v-if="dialogAbrir" class="fixed inset-0 z-[200] flex items-end justify-center sm:items-center bg-black/45 backdrop-blur-sm" @click.self="dialogAbrir = false">
        <div class="w-full max-w-[360px] bg-white rounded-[20px_20px_0_0] sm:rounded-2xl px-6 pt-5 pb-8 sm:py-6 flex flex-col items-center gap-3 shadow-xl">
          <div class="w-9 h-1 rounded-full bg-[#E3E7E4] mb-1 sm:hidden" />
          <div class="w-13 h-13 rounded-full bg-[#E1F3EA] flex items-center justify-center">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0B6B4B" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="14" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>
          </div>
          <h3 class="m-0 text-[16px] font-bold text-[#16201B]">¿Reabrir el día?</h3>
          <p class="m-0 text-[14px] text-[#5B6660] text-center">{{ labelDia(momentoActivo) }}</p>
          <p class="m-0 text-[13px] text-[#5B6660] text-center">Los evaluadores podrán volver a registrar observaciones.</p>
          <div v-if="errorDialog" class="w-full text-[13px] text-[#A3261F] bg-[#FDECEC] rounded-xl px-3 py-2.5">{{ errorDialog }}</div>
          <div class="flex gap-2.5 w-full mt-1">
            <button class="flex-1 h-11 rounded-xl border border-[#DCE1DD] bg-white text-[14px] font-semibold text-[#16201B] font-[inherit]" :disabled="procesandoDia" @click="dialogAbrir = false">Cancelar</button>
            <button class="flex-1 h-11 rounded-xl bg-[#0E7C59] text-[14px] font-semibold text-white font-[inherit] flex items-center justify-center gap-2 disabled:opacity-50" :disabled="procesandoDia" @click="abrirDia">
              <svg v-if="!procesandoDia" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="14" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>
              <svg v-else class="animate-spin" width="15" height="15" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="#fff" stroke-width="3" stroke-opacity=".25"/><path d="M12 2a10 10 0 0 1 10 10" stroke="#fff" stroke-width="3" stroke-linecap="round"/></svg>
              {{ procesandoDia ? 'Reabriendo…' : 'Reabrir día' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>
