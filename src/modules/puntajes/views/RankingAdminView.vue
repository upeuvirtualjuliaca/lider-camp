<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService } from '@/modules/equipos/services/equipos.service'
import { observacionesService, programacionRubricaService, diasService, type DiasEvaluacion } from '@/modules/observaciones/services/observaciones.service'
import { campamentoAdminService } from '@/modules/auditoria/services/auditoria.service'
import { actividadesService, evalRegistrosService } from '@/modules/asistencia/services/asistencia.service'
import { incidenciasService } from '@/modules/incidencias/services/incidencias.service'

const campStore = useCampamentoStore()

// ── Tab activo: 'total' | momento del día ─────────────────────────────────────
const tabActivo = ref<'total' | string>('total')


// ── Datos por día ─────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarDias, labelDia, detectarMomentoActual } = useDiasCampamento()
const momentosConProg = ref<Set<string>>(new Set())
const diasEvaluacion  = ref<DiasEvaluacion[]>([])

interface FilaDia {
  equipo_id: string
  equipo_nombre: string
  equipo_color: string
  posicion: number
  pts_rubrica: number
  pts_actividades: number
  pts_bonus: number
  pts_demeritos: number
  pts_total: number
}
const listaDia       = ref<FilaDia[]>([])
const listaTotal     = ref<FilaDia[]>([])
const campCerrado    = ref(false)

const cargando = ref(true)
const error    = ref('')

// ── Lista activa según tab ────────────────────────────────────────────────────
const listaActiva = computed(() => listaDia.value)

const esDia = computed(() => tabActivo.value !== 'total')

const diaCerrado = computed(() => {
  if (!esDia.value) return false
  return diasEvaluacion.value.find((d) => d.momento === tabActivo.value)?.cerrado ?? false
})

// ── Tabs disponibles ──────────────────────────────────────────────────────────
const tabs = computed(() => [
  { key: 'total', label: 'Total' },
  ...momentos.value
    .filter((m) => momentosConProg.value.has(m))
    .map((m) => ({ key: m, label: labelDia(m) })),
])

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const campId = campStore.selectedId
    await cargarDias()
    const [momentosR, diasData, campEstado] = await Promise.all([
      programacionRubricaService.getMomentosConProgramacion(campId),
      campId ? diasService.getTodos(campId) : Promise.resolve([] as DiasEvaluacion[]),
      campId ? campamentoAdminService.getEstado(campId) : Promise.resolve({ cerrado: false } as any),
    ])
    momentosConProg.value = new Set(momentosR)
    diasEvaluacion.value  = diasData
    campCerrado.value     = campEstado.cerrado ?? false

    // Si campamento cerrado: acumular totales por día; si abierto: limpiar
    if (campCerrado.value) {
      await cargarTotal()
    } else {
      listaTotal.value = []
    }

    // Auto-seleccionar día actual si existe
    const hoy = detectarMomentoActual()
    if (hoy && momentosConProg.value.has(hoy)) tabActivo.value = hoy
    else tabActivo.value = 'total'

    if (esDia.value) await cargarDatosDia(tabActivo.value)
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

async function cargarDatosDia(momento: string) {
  // Solo procesar si el día está cerrado
  const cerrado = diasEvaluacion.value.find((d) => d.momento === momento)?.cerrado ?? false
  if (!cerrado) { listaDia.value = []; return }

  cargando.value = true
  try {
    const campId = campStore.selectedId
    const equipos = await equiposService.getTodos(campId ?? undefined)
    const activos = equipos.filter((e) => e.activo)

    const [puntajesDia, actData, incData] = await Promise.all([
      observacionesService.getPuntajeEquipoDia(momento, campId),
      actividadesService.getPorDia(momento),
      incidenciasService.getValidadasPorMomento(momento, campId),
    ])

    // Puntajes de actividades por equipo
    const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
    const actPts: Record<string, number> = {}
    await Promise.all(
      actFiltradas.map(async (a) => {
        const regs = await evalRegistrosService.getPorActividad(a.id)
        // Promediar entre evaluadores por (criterio, equipo), luego sumar criterios
        const byKey = new Map<string, number[]>()
        for (const r of regs) {
          const key = `${r.criterio_eval_id}|${r.equipo_id}`
          if (!byKey.has(key)) byKey.set(key, [])
          byKey.get(key)!.push(Number(r.puntaje))
        }
        for (const [key, puntajes] of byKey) {
          const equipoId = key.split('|')[1] ?? ''
          if (!equipoId) continue
          const avg = puntajes.reduce((a, b) => a + b, 0) / puntajes.length
          actPts[equipoId] = (actPts[equipoId] ?? 0) + avg
        }
      }),
    )

    // Bonus y deméritos del día (solo para mostrar, no afectan el ranking)
    const bonusPts: Record<string, number>     = {}
    const demeritosPts: Record<string, number> = {}
    for (const inc of incData) {
      if (inc.tipo === 'bonus')    bonusPts[inc.equipo_id]     = (bonusPts[inc.equipo_id]     ?? 0) + inc.puntos
      if (inc.tipo === 'demerito') demeritosPts[inc.equipo_id] = (demeritosPts[inc.equipo_id] ?? 0) + inc.puntos
    }

    // Construir filas — si campamento cerrado: rúbrica + actividades + bonus − deméritos
    //                   si campamento abierto: solo rúbrica
    const filas: FilaDia[] = activos.map((eq) => {
      const rub   = Number(puntajesDia.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
      const act   = actPts[eq.id] ?? 0
      const bon   = bonusPts[eq.id] ?? 0
      const dem   = demeritosPts[eq.id] ?? 0
      const total = campCerrado.value
        ? Math.max(0, rub + act + bon - dem)
        : rub
      return { equipo_id: eq.id, equipo_nombre: eq.nombre, equipo_color: eq.color ?? '#6b7280',
        posicion: 0, pts_rubrica: rub, pts_actividades: act,
        pts_bonus: bon, pts_demeritos: dem, pts_total: total }
    })

    // Ordenar y asignar posición
    filas.sort((a, b) => b.pts_total - a.pts_total)
    filas.forEach((f, i) => { f.posicion = i + 1 })
    listaDia.value = filas
  } finally {
    cargando.value = false
  }
}

async function cargarTotal() {
  const campId = campStore.selectedId
  const equipos = await equiposService.getTodos(campId ?? undefined)
  const activos = equipos.filter((e) => e.activo)

  // Acumular puntos por equipo a través de todos los días cerrados con programación
  const diasCerrados = diasEvaluacion.value.filter(
    (d) => d.cerrado && momentosConProg.value.has(d.momento ?? ''),
  )

  const acum: Record<string, { rub: number; act: number; bon: number; dem: number }> = {}
  for (const eq of activos) acum[eq.id] = { rub: 0, act: 0, bon: 0, dem: 0 }

  await Promise.all(
    diasCerrados.map(async (dia) => {
      const momento = dia.momento ?? ''
      const [puntajesDia, actData, incData] = await Promise.all([
        observacionesService.getPuntajeEquipoDia(momento, campId),
        actividadesService.getPorDia(momento),
        incidenciasService.getValidadasPorMomento(momento, campId),
      ])

      const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
      const actPts: Record<string, number> = {}
      await Promise.all(
        actFiltradas.map(async (a) => {
          const regs = await evalRegistrosService.getPorActividad(a.id)
          for (const r of regs) {
            actPts[r.equipo_id] = (actPts[r.equipo_id] ?? 0) + (r.puntaje ?? 0)
          }
        }),
      )

      for (const eq of activos) {
        const fila = acum[eq.id]
        if (!fila) continue
        fila.rub += Number(puntajesDia.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
        fila.act += actPts[eq.id] ?? 0
        for (const inc of incData.filter((i) => i.equipo_id === eq.id)) {
          if (inc.tipo === 'bonus')    fila.bon += inc.puntos
          if (inc.tipo === 'demerito') fila.dem += inc.puntos
        }
      }
    }),
  )

  const filas: FilaDia[] = activos.map((eq) => {
    const { rub, act, bon, dem } = acum[eq.id] ?? { rub: 0, act: 0, bon: 0, dem: 0 }
    return {
      equipo_id: eq.id,
      equipo_nombre: eq.nombre,
      equipo_color: eq.color ?? '#6b7280',
      posicion: 0,
      pts_rubrica: rub,
      pts_actividades: act,
      pts_bonus: bon,
      pts_demeritos: dem,
      pts_total: Math.max(0, rub + act + bon - dem),
    }
  })
  filas.sort((a, b) => b.pts_total - a.pts_total)
  filas.forEach((f, i) => { f.posicion = i + 1 })
  listaTotal.value = filas
}

async function seleccionarTab(key: string) {
  tabActivo.value = key
  if (key !== 'total') await cargarDatosDia(key)
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

function posClase(pos: number) {
  if (pos === 1) return 'rk-pos--oro'
  if (pos === 2) return 'rk-pos--plata'
  if (pos === 3) return 'rk-pos--bronce'
  return 'rk-pos--part'
}

// ══════════════════════════════════════════════════════════════════════════════
// Display helpers (presentación únicamente — no tocan lógica de negocio)
// ══════════════════════════════════════════════════════════════════════════════
import LockedTotalCard from '../components/LockedTotalCard.vue'
import RankingPodium   from '../components/RankingPodium.vue'
import RankingTable    from '../components/RankingTable.vue'
import RankingRow      from '../components/RankingRow.vue'

function iniciales(nombre: string): string {
  return nombre
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0]?.toUpperCase() ?? '')
    .join('')
}

// ── Active list (day or total) ────────────────────────────────────────────────
const activeList = computed<FilaDia[]>(() =>
  esDia.value ? listaDia.value : listaTotal.value
)

// ── Rows enriched with RANK ties and iniciales ────────────────────────────────
interface RankRow {
  equipo_id: string; equipo_nombre: string; equipo_color: string; iniciales: string
  posicion: number; posLabel: string
  pts_rubrica: number; pts_actividades: number; pts_bonus: number; pts_demeritos: number; pts_total: number
}

const rankRows = computed((): RankRow[] => {
  // El orden y las posiciones vienen del script original (cargarDatosDia /
  // cargarTotal ya ordenan y asignan posicion = i+1 secuencialmente).
  // Solo añadimos iniciales y el marcador "=" cuando dos filas consecutivas
  // tienen el mismo pts_total (empate visual, sin reasignar posición).
  const list = activeList.value
  if (!list.length) return []

  const counts: Record<number, number> = {}
  list.forEach(r => { counts[r.posicion] = (counts[r.posicion] ?? 0) + 1 })

  return list.map(r => ({
    ...r,
    iniciales: iniciales(r.equipo_nombre),
    posLabel: `${r.posicion}°${counts[r.posicion]! > 1 ? ' =' : ''}`,
  }))
})

// ── Empty state: lista realmente vacía (sin equipos cargados) ─────────────────
// Regla original: solo oculta el ranking cuando la lista no tiene equipos,
// nunca porque todos tengan 0 pts (eso sigue siendo un ranking válido).
const isEmpty = computed(() => {
  if (!esDia.value && !campCerrado.value) return false   // bloqueado → no vacío
  const list = esDia.value ? listaDia.value : listaTotal.value
  return list.length === 0
})

// ── Top 3 for podium ─────────────────────────────────────────────────────────
const podiumRows = computed(() => rankRows.value.slice(0, Math.min(3, rankRows.value.length)))

// ── Max total for composition bar scale ──────────────────────────────────────
const maxTotal = computed(() =>
  rankRows.value.reduce((m, r) => Math.max(m, r.pts_rubrica + r.pts_actividades + r.pts_bonus), 0)
)

// ── Días cerrados (for LockedTotalCard) ───────────────────────────────────────
const diasCerradosCount = computed(() =>
  diasEvaluacion.value.filter(d => d.cerrado).length
)

// ── Last closed day label (for "Ver ranking del X" button) ───────────────────
const ultimoDiaMomento = computed<string | null>(() => {
  const ordered = momentos.value.filter(m =>
    momentosConProg.value.has(m) &&
    diasEvaluacion.value.find(d => d.momento === m)?.cerrado
  )
  return ordered.length ? (ordered[ordered.length - 1] ?? null) : null
})

const ultimoDiaLabel = computed(() =>
  ultimoDiaMomento.value ? labelDia(ultimoDiaMomento.value) : ''
)

// ── Period name for table header ─────────────────────────────────────────────
const periodoNombre = computed(() =>
  esDia.value ? labelDia(tabActivo.value) : 'acumulado total'
)

// ── Refresh time ─────────────────────────────────────────────────────────────
const refreshHora = ref<string>('')
function actualizarHora() {
  refreshHora.value = new Date().toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })
}
watch(cargando, (v) => { if (!v) actualizarHora() })
onMounted(actualizarHora)

function handleActualizar() {
  if (esDia.value) cargarDatosDia(tabActivo.value)
  else cargar()
}

// ── Mobile: expandable rows ───────────────────────────────────────────────────
const openRowId = ref<string | null>(null)
function toggleRow(id: string) {
  openRowId.value = openRowId.value === id ? null : id
}
</script>

<template>
  <div class="min-h-full bg-[#F4F6F4]">

    <!-- ══════════════════════════════════════════════════════════════════════
         MOBILE  (< md / 768 px)
         ══════════════════════════════════════════════════════════════════════ -->
    <div class="md:hidden flex flex-col min-h-full">

      <!-- Mobile header + tabs -->
      <header class="bg-white border-b border-[#E3E7E4] px-4 pt-3 pb-0 flex flex-col gap-3">
        <div class="flex items-center justify-between gap-2 h-11">
          <!-- Title block -->
          <div class="flex flex-col">
            <span class="text-[17px] font-bold leading-tight">Ranking interno</span>
            <span class="text-[12px] text-[#5B6660]">No visible para estudiantes</span>
          </div>
          <!-- Refresh -->
          <button
            class="flex items-center gap-1.5 h-9 px-3 rounded-[10px] border border-[#DCE1DD] bg-white text-[12px] text-[#5B6660] font-[inherit] cursor-pointer disabled:opacity-50"
            :disabled="cargando"
            @click="handleActualizar"
          >
            <svg class="w-3.5 h-3.5" :class="{ 'animate-spin': cargando }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
              <path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/>
            </svg>
            {{ refreshHora }}
          </button>
        </div>

        <!-- Tabs -->
        <div class="flex gap-1.5 overflow-x-auto pb-3" style="scrollbar-width: none;">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="flex-shrink-0 h-[38px] px-3.5 rounded-[10px] border text-[13px] font-semibold font-[inherit] cursor-pointer transition-colors"
            :class="tabActivo === tab.key
              ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
              : 'bg-white text-[#16201B] border-[#DCE1DD]'"
            @click="seleccionarTab(tab.key)"
          >{{ tab.label }}</button>
        </div>
      </header>

      <!-- Mobile content -->
      <main class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">

        <!-- Loading skeleton -->
        <template v-if="cargando">
          <!-- Podium skeleton -->
          <div class="grid grid-cols-3 gap-2 items-end animate-pulse">
            <div class="h-24 bg-white rounded-2xl border border-[#E3E7E4]" />
            <div class="h-32 bg-white rounded-2xl border border-[#E3E7E4]" />
            <div class="h-24 bg-white rounded-2xl border border-[#E3E7E4]" />
          </div>
          <!-- List skeleton -->
          <div class="bg-white rounded-2xl border border-[#E3E7E4] overflow-hidden animate-pulse">
            <div v-for="i in 5" :key="i" class="flex items-center gap-3 px-3.5 h-[58px] border-b border-[#EEF1EF] last:border-b-0">
              <div class="w-6 h-4 bg-[#EEF1EF] rounded" />
              <div class="w-9 h-9 bg-[#EEF1EF] rounded-[10px]" />
              <div class="flex-1 h-4 bg-[#EEF1EF] rounded-full" />
              <div class="w-10 h-5 bg-[#EEF1EF] rounded" />
            </div>
          </div>
        </template>

        <!-- Error -->
        <div v-else-if="error" class="rounded-2xl bg-[#FDECEC] border border-[#F5C0C0] px-4 py-3.5 flex items-center gap-3">
          <svg class="w-5 h-5 flex-shrink-0 text-[#C0392B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <path d="m21.73 18-8-14a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 22h16a2 2 0 0 0 1.73-4z"/>
            <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
          <span class="text-[13px] font-medium text-[#C0392B]">{{ error }}</span>
        </div>

        <!-- Total bloqueado -->
        <LockedTotalCard
          v-else-if="!esDia && !campCerrado"
          :diasCerrados="diasCerradosCount"
          :totalDias="4"
          :ultimoDiaLabel="ultimoDiaLabel"
          @verUltimoDia="ultimoDiaMomento && seleccionarTab(ultimoDiaMomento)"
        />

        <!-- Día no cerrado o sin puntajes -->
        <section
          v-else-if="esDia && !diaCerrado || isEmpty"
          class="bg-white border border-dashed border-[#DCE1DD] rounded-2xl p-8 text-center flex flex-col gap-1.5"
        >
          <span class="text-[15px] font-bold">Aún no hay puntajes para este día</span>
          <span class="text-[13px] text-[#5B6660]">El ranking aparecerá cuando se registren las primeras notas.</span>
        </section>

        <!-- Data: podio + lista -->
        <template v-else>
          <!-- Podium -->
          <RankingPodium :rows="podiumRows" />

          <!-- Mobile list -->
          <ul class="list-none m-0 p-0 bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
            <RankingRow
              v-for="row in rankRows"
              :key="row.equipo_id"
              v-bind="row"
              :open="openRowId === row.equipo_id"
              @toggle="toggleRow(row.equipo_id)"
            />
          </ul>
          <p class="m-0 text-[12px] text-[#5B6660] text-center">
            Toca un equipo para ver el detalle. Los empates comparten posición.
          </p>
        </template>

      </main>
    </div>

    <!-- ══════════════════════════════════════════════════════════════════════
         TABLET + DESKTOP  (md+ / 768 px+)
         ══════════════════════════════════════════════════════════════════════ -->
    <div class="hidden md:flex flex-col min-h-full">

      <!-- Desktop/tablet header -->
      <header class="min-h-[64px] px-5 xl:px-7 py-2.5 flex flex-wrap items-center gap-3 border-b border-[#E3E7E4] bg-white box-border">
        <!-- Title -->
        <div class="flex flex-col mr-auto">
          <span class="text-[12px] text-[#5B6660]">Seguimiento</span>
          <div class="flex items-center gap-2.5">
            <span class="text-[18px] font-bold">Ranking interno</span>
            <!-- "No visible" badge -->
            <span class="flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-[6px] bg-[#EEF0EE] text-[#4A544F]">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                <path d="M17.9 17.9A10 10 0 0 1 12 20c-7 0-10-8-10-8a18 18 0 0 1 5.1-5.9M9.9 4.2A9 9 0 0 1 12 4c7 0 10 8 10 8a18 18 0 0 1-2.2 3.2M1 1l22 22"/>
              </svg>
              No visible para estudiantes
            </span>
          </div>
        </div>

        <!-- Tabs -->
        <div role="tablist" aria-label="Periodo" class="flex gap-1.5 flex-wrap">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            role="tab"
            class="h-[38px] px-3.5 rounded-[10px] border text-[13px] font-semibold font-[inherit] cursor-pointer transition-colors"
            :class="tabActivo === tab.key
              ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
              : 'bg-white text-[#16201B] border-[#DCE1DD] hover:border-[#0E7C59] hover:text-[#0E7C59]'"
            :aria-selected="tabActivo === tab.key"
            @click="seleccionarTab(tab.key)"
          >{{ tab.label }}</button>
        </div>

        <!-- Refresh button -->
        <button
          class="h-[38px] px-3 rounded-[10px] border border-[#DCE1DD] bg-white text-[12px] text-[#5B6660] font-[inherit] cursor-pointer flex items-center gap-1.5 hover:bg-[#F4F6F4] transition-colors disabled:opacity-50"
          :disabled="cargando"
          aria-label="Actualizar"
          @click="handleActualizar"
        >
          <svg class="w-3.5 h-3.5" :class="{ 'animate-spin': cargando }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/>
          </svg>
          {{ refreshHora }}
        </button>
      </header>

      <!-- Main content -->
      <main class="flex-1 overflow-y-auto">
        <div class="w-full max-w-[1140px] mx-auto px-5 xl:px-7 py-5 xl:py-6 flex flex-col gap-4 xl:gap-[18px]">

          <!-- Loading skeletons -->
          <template v-if="cargando">
            <!-- Podium skeleton -->
            <div class="grid grid-cols-3 gap-3 xl:gap-4 animate-pulse">
              <div class="h-20 xl:h-28 bg-white rounded-2xl border border-[#E3E7E4]" />
              <div class="h-20 xl:h-36 bg-white rounded-2xl border border-[#E3E7E4]" />
              <div class="h-20 xl:h-28 bg-white rounded-2xl border border-[#E3E7E4]" />
            </div>
            <!-- Table skeleton -->
            <div class="bg-white rounded-2xl border border-[#E3E7E4] overflow-hidden animate-pulse">
              <div class="h-12 bg-[#F4F6F4] border-b border-[#EEF1EF]" />
              <div v-for="i in 5" :key="i" class="flex items-center gap-4 px-5 h-[52px] border-b border-[#EEF1EF] last:border-b-0">
                <div class="w-10 h-4 bg-[#EEF1EF] rounded" />
                <div class="w-9 h-9 bg-[#EEF1EF] rounded-[9px]" />
                <div class="flex-1 h-4 bg-[#EEF1EF] rounded-full" />
                <div class="w-20 h-2.5 bg-[#EEF1EF] rounded-full" />
                <div class="w-12 h-5 bg-[#EEF1EF] rounded" />
              </div>
            </div>
          </template>

          <!-- Error -->
          <div v-else-if="error" class="rounded-2xl bg-[#FDECEC] border border-[#F5C0C0] px-5 py-4 flex items-center gap-3">
            <svg class="w-5 h-5 flex-shrink-0 text-[#C0392B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
              <path d="m21.73 18-8-14a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 22h16a2 2 0 0 0 1.73-4z"/>
              <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
            <span class="text-[14px] font-medium text-[#C0392B]">{{ error }}</span>
          </div>

          <!-- Total bloqueado (campamento aún abierto) -->
          <LockedTotalCard
            v-else-if="!esDia && !campCerrado"
            :diasCerrados="diasCerradosCount"
            :totalDias="4"
            :ultimoDiaLabel="ultimoDiaLabel"
            @verUltimoDia="ultimoDiaMomento && seleccionarTab(ultimoDiaMomento)"
          />

          <!-- Día no cerrado -->
          <section
            v-else-if="esDia && !diaCerrado"
            class="bg-white border border-dashed border-[#DCE1DD] rounded-2xl p-10 text-center flex flex-col gap-1.5"
          >
            <span class="text-[16px] font-bold">Aún no hay puntajes para este día</span>
            <span class="text-[14px] text-[#5B6660]">El ranking aparecerá cuando se registren las primeras notas.</span>
          </section>

          <!-- Sin puntajes (todos 0) -->
          <section
            v-else-if="isEmpty"
            class="bg-white border border-dashed border-[#DCE1DD] rounded-2xl p-10 text-center flex flex-col gap-1.5"
          >
            <span class="text-[16px] font-bold">Aún no hay puntajes para este día</span>
            <span class="text-[14px] text-[#5B6660]">El ranking aparecerá cuando se registren las primeras notas.</span>
          </section>

          <!-- Data: podium + table -->
          <template v-else>
            <RankingPodium :rows="podiumRows" />
            <RankingTable
              :rows="rankRows"
              :maxTotal="maxTotal"
              :periodo="periodoNombre"
            />
          </template>

        </div>
      </main>
    </div>

  </div>
</template>
