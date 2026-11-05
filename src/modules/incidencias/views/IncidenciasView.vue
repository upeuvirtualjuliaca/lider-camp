<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { cachedFetch, TTL_1H } from '@/lib/localCache'
import {
  incidenciasService,
  codigosService,
  bonusService,
  demeritorService,
  evidenciasService,
  type Incidencia,
  type IncidenciaCodigo,
  type IncidenciaDetalle,
  type BonusEquipo,
  type DemeritoEquipo,
} from '@/modules/incidencias/services/incidencias.service'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import IncidentRow from '../components/IncidentRow.vue'
import IncidentDetail from '../components/IncidentDetail.vue'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const router    = useRouter()

const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()
const momentoActivo    = ref('')
const momentosConProg  = ref<string[]>([])

// ── Estado ────────────────────────────────────────────────────────────────────
const cargando   = ref(true)
const error      = ref('')
const lista      = ref<Incidencia[]>([])
const codigos    = ref<IncidenciaCodigo[]>([])
const equipos    = ref<Equipo[]>([])
const bonusList  = ref<BonusEquipo[]>([])
const demeList   = ref<DemeritoEquipo[]>([])

const filtTab    = ref<'todas' | 'bonus' | 'demerito' | 'pendiente'>('todas')
const filtEquipo = ref('')
const modalOpen  = ref(false)

// ── Detalle inline (web/tablet) ───────────────────────────────────────────────
const incActiva      = ref<IncidenciaDetalle | null>(null)
const cargandoDet    = ref(false)
const evidenciaUrls  = ref<Record<string, string>>({})
const cargandoValid  = ref(false)

// ── Fecha de hoy ──────────────────────────────────────────────────────────────
const hoy = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
})

// ── Puede registrar ───────────────────────────────────────────────────────────
const fechaInicio = computed(() => {
  if (momentos.value.length === 0) return null
  return fechas.value[momentos.value[0] ?? ''] ?? null
})

const labelFechaInicio = computed(() => {
  if (!fechaInicio.value) return ''
  return labelDia(momentos.value[0] ?? '')
})

const puedeRegistrar = computed(() => {
  if (momentos.value.length === 0) return false
  const primerFecha = fechas.value[momentos.value[0] ?? '']
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1] ?? '']
  if (!primerFecha || !ultimaFecha) return false
  return hoy.value >= primerFecha && hoy.value < ultimaFecha
})

const motivoNoRegistrar = computed(() => {
  if (momentos.value.length === 0) return ''
  const primerFecha = fechas.value[momentos.value[0] ?? '']
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1] ?? '']
  if (!primerFecha || !ultimaFecha) return ''
  if (hoy.value < primerFecha) return 'El campamento aún no ha comenzado.'
  if (hoy.value >= ultimaFecha) return 'No se pueden registrar incidencias el último día del campamento.'
  return ''
})

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  if (codigos.value.length > 0 && equipos.value.length > 0 && !navigator.onLine) return
  cargando.value = true
  error.value = ''
  try {
    const [, inc, cod, eq, bon, dem] = await Promise.all([
      cargarCampamento(),
      incidenciasService.getAll({ campamento_id: campStore.selectedId ?? undefined }),
      codigosService.getAll(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      bonusService.getResumen(campStore.selectedId),
      demeritorService.getResumen(campStore.selectedId),
    ])
    if (campStore.selectedId) {
      const campId = campStore.selectedId
      const moms = await cachedFetch<string[]>(`prog_momentos_${campId}`, async () => {
        const { supabase } = await import('@/lib/supabase')
        const { data: progData } = await supabase
          .from('programacion')
          .select('momento')
          .eq('campamento_id', campId)
          .eq('estado', 'programado')
        return [...new Set((progData ?? []).map((r: any) => r.momento as string))]
      }, TTL_1H)
      momentosConProg.value = moms
    }
    momentoActivo.value = detectarMomentoActual()
    lista.value    = inc
    codigos.value  = cod
    equipos.value  = eq
    bonusList.value = bon
    demeList.value  = dem
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar incidencias'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

// ── Computed ──────────────────────────────────────────────────────────────────
const codigoPorCodigo = computed(() => {
  const m = new Map<string, IncidenciaCodigo>()
  codigos.value.forEach(c => m.set(c.codigo, c))
  return m
})

function tipoDe(codigo: string): 'bonus' | 'demerito' {
  return codigoPorCodigo.value.get(codigo)?.tipo === 'bonus' ? 'bonus' : 'demerito'
}

const listaDia = computed(() => {
  if (!momentoActivo.value) return lista.value
  const fecha = fechas.value[momentoActivo.value]
  if (!fecha) return lista.value
  return lista.value.filter(inc => inc.fecha === fecha)
})

const listaFiltrada = computed(() => {
  return listaDia.value.filter(inc => {
    if (filtTab.value === 'bonus'     && tipoDe(inc.codigo) !== 'bonus')     return false
    if (filtTab.value === 'demerito'  && tipoDe(inc.codigo) !== 'demerito')  return false
    if (filtTab.value === 'pendiente' && inc.estado !== 'registrado' && inc.estado !== 'descargo') return false
    if (filtEquipo.value && inc.equipo_id !== filtEquipo.value) return false
    return true
  })
})

// Summary cards (solo validadas, por día activo)
const bonusValidados     = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'bonus'    && i.estado === 'validado'))
const demeritosValidados = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'demerito' && i.estado === 'validado'))
const porValidar         = computed(() => listaDia.value.filter(i => i.estado === 'registrado' || i.estado === 'descargo'))

const bonusPts    = computed(() => bonusList.value.reduce((s, b) => s + (b.bonus_codigo ?? 0), 0))
const demeritoPts = computed(() => demeList.value.reduce((s, d) => s + (d.demeritos_codigo ?? 0), 0))
const bonusTotal  = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'bonus').length)

const cntBonus    = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'bonus').length)
const cntDemerito = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'demerito').length)
const cntPendiente = computed(() => porValidar.value.length)

const bonusCodigos    = computed(() => codigos.value.filter(c => c.tipo === 'bonus'))
const demeritoCodigos = computed(() => codigos.value.filter(c => c.tipo === 'demerito'))

// ── Helpers ───────────────────────────────────────────────────────────────────
function nombreEquipo(id: string) {
  return equipos.value.find(e => e.id === id)?.nombre ?? '—'
}

function labelDiaCorto(m: string) {
  const label = labelDia(m)
  const parts = label.split(' ')
  return parts.length >= 2 ? (parts[0] ?? '').slice(0, 3) + ' ' + (parts[1] ?? '') : label
}

// ── Click en fila ─────────────────────────────────────────────────────────────
async function onRowClick(id: string) {
  if (typeof window !== 'undefined' && window.innerWidth < 768) {
    router.push(`/panel/incidencias/${id}`)
    return
  }
  if (incActiva.value?.id === id) return
  cargandoDet.value   = true
  incActiva.value     = null
  evidenciaUrls.value = {}
  try {
    const det = await incidenciasService.getPorId(id)
    if (!det) return
    incActiva.value = det
    for (const ev of det.evidencias) {
      evidenciaUrls.value[ev.id] = await evidenciasService.getUrl(ev.ruta_archivo)
    }
  } finally {
    cargandoDet.value = false
  }
}

// ── Validar / Rechazar ────────────────────────────────────────────────────────
async function onValidar(motivo: string) {
  if (!incActiva.value) return
  cargandoValid.value = true
  try {
    await incidenciasService.validar(incActiva.value.id, motivo)
    await cargar()
    if (incActiva.value) {
      const det = await incidenciasService.getPorId(incActiva.value.id)
      if (det) incActiva.value = det
    }
  } finally {
    cargandoValid.value = false
  }
}

async function onRechazar(motivo: string) {
  if (!incActiva.value) return
  cargandoValid.value = true
  try {
    await incidenciasService.rechazar(incActiva.value.id, motivo)
    await cargar()
    if (incActiva.value) {
      const det = await incidenciasService.getPorId(incActiva.value.id)
      if (det) incActiva.value = det
    }
  } finally {
    cargandoValid.value = false
  }
}
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden bg-[#F4F6F4]" style="font-family: Inter, system-ui, sans-serif">

    <!-- ═══════════════════ LOADING ═══════════════════ -->
    <div v-if="cargando" class="flex-1 flex flex-col items-center justify-center gap-3 text-[#5B6660]">
      <div class="flex flex-col gap-3 w-full max-w-md px-4">
        <div class="h-10 bg-[#E3E7E4] rounded-xl animate-pulse" />
        <div class="grid grid-cols-3 gap-2">
          <div v-for="n in 3" :key="n" class="h-20 bg-[#E3E7E4] rounded-2xl animate-pulse" />
        </div>
        <div v-for="n in 4" :key="n" class="h-16 bg-[#E3E7E4] rounded-2xl animate-pulse" />
      </div>
    </div>

    <!-- ═══════════════════ ERROR ═══════════════════ -->
    <div v-else-if="error" class="flex-1 flex flex-col items-center justify-center gap-4 p-6">
      <p class="text-[15px] text-[#16201B] text-center">{{ error }}</p>
      <button @click="cargar" class="h-10 px-5 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit]">Reintentar</button>
    </div>

    <!-- ═══════════════════ CONTENT ═══════════════════ -->
    <template v-else>

      <!-- ── TABLET / DESKTOP top bar ─────────────────── -->
      <div class="hidden md:flex items-center gap-3 px-5 py-3 bg-white border-b border-[#E3E7E4] flex-shrink-0 overflow-x-auto">
        <span class="text-[13px] text-[#5B6660] flex-shrink-0">
          Evaluación / <strong class="text-[#16201B]">Incidencias</strong>
        </span>
        <div class="w-px h-5 bg-[#E3E7E4] flex-shrink-0" />

        <!-- Day tabs -->
        <div class="flex gap-1.5 flex-shrink-0">
          <button
            class="flex-shrink-0 h-9 px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit]"
            :class="momentoActivo === '' ? 'bg-[#0E7C59] text-white border-[#0E7C59]' : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
            @click="momentoActivo = ''"
          >Todos</button>
          <button
            v-for="m in momentos"
            :key="m"
            class="flex-shrink-0 h-9 px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit]"
            :class="momentoActivo === m ? 'bg-[#0E7C59] text-white border-[#0E7C59]' : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
            @click="momentoActivo = m"
          >
            {{ labelDiaCorto(m) }}<template v-if="fechas[m] === hoy"> · Hoy</template>
          </button>
        </div>

        <div class="flex-1" />

        <!-- Help button -->
        <button
          class="flex-shrink-0 w-9 h-9 rounded-xl border border-[#DCE1DD] bg-white text-[#5B6660] hover:text-[#0E7C59] hover:border-[#0E7C59] flex items-center justify-center transition-colors"
          title="¿Cómo funciona?"
          @click="modalOpen = true"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        </button>

        <!-- Registrar button -->
        <router-link
          v-if="puedeRegistrar"
          :to="`/panel/incidencias/nueva${momentoActivo && fechas[momentoActivo] ? '?fecha=' + fechas[momentoActivo] : ''}`"
          class="flex-shrink-0 flex items-center gap-1.5 h-9 px-4 rounded-[10px] bg-[#0E7C59] text-white text-[13px] font-semibold hover:bg-[#0B6B4B] transition-colors font-[inherit]"
          style="color: #fff"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
          Registrar incidencia
        </router-link>
        <span
          v-else
          class="flex-shrink-0 flex items-center gap-1.5 h-9 px-4 rounded-[10px] bg-[#F4F6F4] text-[#8A948E] text-[13px] font-semibold cursor-not-allowed border border-[#E3E7E4]"
          :title="motivoNoRegistrar || 'Día cerrado'"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          Registrar incidencia
        </span>
      </div>

      <!-- ── MOBILE header ───────────────────────────── -->
      <div class="md:hidden bg-white border-b border-[#E3E7E4] flex-shrink-0">
        <div class="flex items-center justify-between px-4 py-3 h-[56px]">
          <div class="flex flex-col">
            <span class="text-[17px] font-bold text-[#16201B] leading-tight">Incidencias</span>
            <span class="text-[12px] text-[#5B6660]">Evaluación</span>
          </div>
          <div class="flex items-center gap-2">
            <button
              class="w-9 h-9 rounded-xl border border-[#DCE1DD] bg-white text-[#5B6660] flex items-center justify-center"
              @click="modalOpen = true"
              aria-label="¿Cómo funciona?"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
            </button>
            <router-link
              v-if="puedeRegistrar"
              :to="`/panel/incidencias/nueva${momentoActivo && fechas[momentoActivo] ? '?fecha=' + fechas[momentoActivo] : ''}`"
              class="flex items-center gap-1.5 h-9 px-3.5 rounded-[10px] bg-[#0E7C59] text-white text-[13px] font-semibold font-[inherit]"
              style="color: #fff"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
              Registrar
            </router-link>
          </div>
        </div>
        <div class="flex gap-1.5 overflow-x-auto px-4 pb-3">
          <button
            role="tab"
            class="flex-shrink-0 h-[38px] px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit]"
            :class="momentoActivo === '' ? 'bg-[#0E7C59] text-white border-[#0E7C59]' : 'bg-white text-[#16201B] border-[#DCE1DD]'"
            @click="momentoActivo = ''"
          >Todos</button>
          <button
            v-for="m in momentos"
            :key="m"
            role="tab"
            :aria-selected="momentoActivo === m"
            class="flex-shrink-0 h-[38px] px-3.5 rounded-[10px] text-[13px] font-semibold border transition-colors font-[inherit]"
            :class="momentoActivo === m ? 'bg-[#0E7C59] text-white border-[#0E7C59]' : 'bg-white text-[#16201B] border-[#DCE1DD]'"
            @click="momentoActivo = m"
          >
            {{ labelDiaCorto(m) }}<template v-if="fechas[m] === hoy"> · Hoy</template>
          </button>
        </div>
      </div>

      <!-- ── Aviso bloqueo de registro ───────────────── -->
      <div
        v-if="!cargando && motivoNoRegistrar"
        class="mx-4 mt-3 flex items-start gap-2.5 bg-[#FFF8EA] border border-l-4 border-[#F3DDAE] border-l-[#F59E0B] rounded-xl px-3.5 py-2.5 text-[13px] text-[#7A4F00] leading-relaxed flex-shrink-0"
      >
        <svg class="flex-shrink-0 mt-0.5" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <div class="flex flex-col gap-0.5">
          <span>{{ motivoNoRegistrar }}</span>
          <span v-if="fechaInicio && hoy < fechaInicio" class="text-[11px] text-[#92400E]">
            Inicio: <strong>{{ labelFechaInicio }}</strong> ({{ fechaInicio }})
          </span>
        </div>
      </div>

      <!-- ── Main split layout ───────────────────────── -->
      <div class="flex flex-1 overflow-hidden">

        <!-- LIST COLUMN -->
        <div class="flex flex-col flex-shrink-0 overflow-y-auto w-full md:w-[460px] xl:w-[480px]">

          <!-- Summary cards -->
          <section class="grid grid-cols-3 gap-2 px-4 pt-4 pb-2" aria-label="Resumen">
            <div class="bg-white border border-[#E3E7E4] rounded-[14px] p-[10px]">
              <span class="block text-[11px] text-[#5B6660] mb-0.5">Bonus validados</span>
              <span class="text-[20px] font-bold text-[#0B6B4B] leading-none">+{{ bonusPts }}</span>
              <span class="block text-[11px] text-[#5B6660] mt-0.5">{{ bonusValidados.length }} de {{ bonusTotal }}</span>
            </div>
            <div class="bg-white border border-[#E3E7E4] rounded-[14px] p-[10px]">
              <span class="block text-[11px] text-[#5B6660] mb-0.5">Deméritos validados</span>
              <span class="text-[20px] font-bold text-[#A3261F] leading-none">−{{ demeritoPts }}</span>
              <span class="block text-[11px] text-[#5B6660] mt-0.5">{{ demeritosValidados.length }} validados</span>
            </div>
            <div class="bg-[#FFF8EA] border border-[#F3DDAE] rounded-[14px] p-[10px]">
              <span class="block text-[11px] text-[#7A4F00] mb-0.5">{{ session.esAdmin ? 'Mis pendientes' : 'Por validar' }}</span>
              <span class="text-[20px] font-bold text-[#7A4F00] leading-none">{{ cntPendiente }}</span>
            </div>
          </section>

          <!-- Filter chips + team selector -->
          <div class="px-4 py-2 flex flex-col gap-2">
            <div class="flex gap-1.5 overflow-x-auto">
              <button
                v-for="tab in [
                  { v: 'todas',    label: 'Todas',     cnt: listaDia.length },
                  { v: 'bonus',    label: 'Bonus',     cnt: cntBonus },
                  { v: 'demerito', label: 'Deméritos', cnt: cntDemerito },
                  { v: 'pendiente',label: 'Por validar',cnt: cntPendiente },
                ]"
                :key="tab.v"
                class="flex-shrink-0 h-[34px] px-3 rounded-full text-[13px] border transition-colors font-[inherit]"
                :class="filtTab === tab.v
                  ? 'bg-[#16201B] text-white border-[#16201B] font-semibold'
                  : 'bg-white text-[#16201B] border-[#DCE1DD] font-medium'"
                @click="filtTab = tab.v as any"
              >{{ tab.label }} · {{ tab.cnt }}</button>
            </div>

            <div v-if="equipos.length > 1" class="flex gap-1.5 overflow-x-auto">
              <button
                class="flex-shrink-0 h-[30px] px-3 rounded-full text-[12px] border transition-colors font-[inherit]"
                :class="filtEquipo === '' ? 'bg-[#16201B] text-white border-[#16201B] font-semibold' : 'bg-white text-[#16201B] border-[#DCE1DD] font-medium'"
                @click="filtEquipo = ''"
              >Todos los equipos</button>
              <button
                v-for="eq in equipos"
                :key="eq.id"
                class="flex-shrink-0 h-[30px] px-3 rounded-full text-[12px] border transition-colors font-[inherit]"
                :class="filtEquipo === eq.id ? 'bg-[#16201B] text-white border-[#16201B] font-semibold' : 'bg-white text-[#16201B] border-[#DCE1DD] font-medium'"
                @click="filtEquipo = eq.id"
              >{{ eq.nombre }}</button>
            </div>
          </div>

          <!-- List -->
          <div v-if="listaFiltrada.length" class="mx-4 mb-4 bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
            <ul class="list-none m-0 p-0">
              <IncidentRow
                v-for="inc in listaFiltrada"
                :key="inc.id"
                :inc="inc"
                :tipo="tipoDe(inc.codigo)"
                :equipoNombre="nombreEquipo(inc.equipo_id)"
                :selected="incActiva?.id === inc.id"
                @click="onRowClick(inc.id)"
              />
            </ul>
          </div>

          <!-- Empty state -->
          <div v-else class="flex flex-col items-center gap-2 py-16 px-4 text-center">
            <div class="w-14 h-14 rounded-full bg-white border border-[#E3E7E4] flex items-center justify-center mb-1">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="1.5" stroke-linecap="round" aria-hidden="true"><path d="M20 13V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v7"/><path d="M2 17a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v2z"/></svg>
            </div>
            <p class="text-[15px] font-semibold text-[#5B6660] m-0">No hay incidencias</p>
            <p class="text-[13px] text-[#8A948E] m-0 max-w-[220px] leading-relaxed">
              {{
                filtTab === 'pendiente' ? 'No hay incidencias pendientes de validación.' :
                filtTab !== 'todas'    ? `No hay ${filtTab === 'bonus' ? 'bonus' : 'deméritos'} para este filtro.` :
                'No hay incidencias registradas para este período.'
              }}
            </p>
          </div>
        </div>

        <!-- DETAIL PANEL (tablet / desktop) -->
        <div class="hidden md:flex flex-col flex-1 border-l border-[#E3E7E4] overflow-hidden">
          <div v-if="cargandoDet" class="flex flex-col gap-3 p-5 animate-pulse">
            <div class="h-12 bg-[#E3E7E4] rounded-xl" />
            <div class="grid grid-cols-2 gap-2">
              <div v-for="n in 4" :key="n" class="h-16 bg-[#E3E7E4] rounded-xl" />
            </div>
            <div class="h-24 bg-[#E3E7E4] rounded-xl" />
          </div>
          <div v-else-if="!incActiva" class="flex-1 flex flex-col items-center justify-center gap-3 text-center p-8">
            <div class="w-16 h-16 rounded-full bg-[#F4F6F4] border border-[#E3E7E4] flex items-center justify-center">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="1.5" stroke-linecap="round" aria-hidden="true"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
            </div>
            <p class="text-[15px] font-semibold text-[#5B6660] m-0">Selecciona una incidencia</p>
            <p class="text-[13px] text-[#8A948E] m-0 max-w-[200px] leading-relaxed">Haz clic en una fila de la lista para ver el detalle.</p>
          </div>
          <IncidentDetail
            v-else
            :inc="incActiva"
            :equipoNombre="nombreEquipo(incActiva.equipo_id)"
            :esAdmin="session.esAdmin"
            :evidenciaUrls="evidenciaUrls"
            :cargandoValidacion="cargandoValid"
            @validar="onValidar"
            @rechazar="onRechazar"
            @close="incActiva = null"
          />
        </div>
      </div>
    </template>
  </div>

  <!-- ═══════════════════ MODAL ¿Cómo funciona? ═══════════════════ -->
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div v-if="modalOpen" class="fixed inset-0 z-[200] flex items-end justify-center sm:items-center sm:p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/45 backdrop-blur-sm" @click="modalOpen = false" />

        <!-- Panel -->
        <div class="relative w-full max-w-[440px] bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col overflow-hidden max-h-[90dvh]">

          <!-- Header -->
          <div class="flex items-center justify-between px-5 pt-4 pb-3.5 border-b border-[#F4F6F4] flex-shrink-0">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-[9px] bg-[#E1F3EA] text-[#0B6B4B] flex items-center justify-center">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
              </div>
              <h2 class="text-[16px] font-bold text-[#16201B] m-0">¿Cómo funciona?</h2>
            </div>
            <button
              class="w-8 h-8 rounded-lg bg-transparent hover:bg-[#F4F6F4] text-[#5B6660] flex items-center justify-center transition-colors"
              @click="modalOpen = false"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
          </div>

          <!-- Body -->
          <div class="overflow-y-auto px-5 py-4 flex-1 flex flex-col gap-4">
            <p class="text-[14px] text-[#3A4540] leading-relaxed m-0">
              Las incidencias son eventos que <strong>suman</strong> (bonus) o
              <strong>restan</strong> (deméritos) puntos al equipo.
              Solo cuentan una vez que el admin las <strong>valida</strong>.
            </p>

            <!-- Regla de registro -->
            <div class="flex items-start gap-2 bg-[#E1F3EA] border border-[#0E7C59]/20 rounded-xl px-3.5 py-2.5 text-[13px] text-[#0B6B4B] leading-relaxed">
              <svg class="flex-shrink-0 mt-0.5" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
              <span>Se pueden registrar desde el <strong>primer día</strong> hasta el <strong>penúltimo día</strong> inclusive.</span>
            </div>

            <!-- Pasos -->
            <div class="flex flex-col gap-3">
              <div v-for="(p, i) in [
                { t: 'Evaluador registra', d: 'Documenta el hecho, código, equipo y sube evidencia.' },
                { t: 'Admin valida en bandeja', d: 'Aprueba o rechaza con un motivo. Solo las aprobadas aplican.' },
                { t: 'Impacta el puntaje final', d: 'Solo incidencias validadas afectan el score del equipo.' },
              ]" :key="i" class="flex gap-3 items-start">
                <span
                  class="w-7 h-7 rounded-full flex items-center justify-center text-[13px] font-bold flex-shrink-0 mt-0.5"
                  :class="i === 2 ? 'bg-[#0E7C59] text-white' : 'bg-[#E1F3EA] text-[#0B6B4B]'"
                >{{ i + 1 }}</span>
                <div>
                  <p class="text-[14px] font-semibold text-[#16201B] m-0 mb-0.5">{{ p.t }}</p>
                  <p class="text-[12px] text-[#5B6660] m-0 leading-snug">{{ p.d }}</p>
                </div>
              </div>
            </div>

            <!-- Bonus codes -->
            <div>
              <p class="text-[13px] font-bold text-[#0B6B4B] flex items-center gap-1.5 mb-2 mt-0">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                Bonus
              </p>
              <div class="flex flex-col gap-1.5">
                <div v-for="c in bonusCodigos" :key="c.codigo" class="flex items-start gap-2.5 bg-[#F4F6F4] border border-[#E3E7E4] rounded-xl px-3 py-2">
                  <span class="flex-shrink-0 px-2 py-0.5 rounded-[6px] text-[11px] font-bold bg-[#E1F3EA] text-[#0B6B4B]">{{ c.codigo }}</span>
                  <div class="flex flex-col gap-0.5">
                    <strong class="text-[13px] text-[#16201B]">{{ c.nombre }}</strong>
                    <span class="text-[11px] text-[#5B6660]">
                      {{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                      <template v-if="c.tope_equipo"> · tope {{ c.tope_equipo }} pts</template>
                      <template v-if="c.max_acciones"> · máx. {{ c.max_acciones }} acciones</template>
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Demerito codes -->
            <div>
              <p class="text-[13px] font-bold text-[#A3261F] flex items-center gap-1.5 mb-2 mt-0">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
                Deméritos
              </p>
              <div class="flex flex-col gap-1.5">
                <div v-for="c in demeritoCodigos" :key="c.codigo" class="flex items-start gap-2.5 bg-[#F4F6F4] border border-[#E3E7E4] rounded-xl px-3 py-2">
                  <span class="flex-shrink-0 px-2 py-0.5 rounded-[6px] text-[11px] font-bold bg-[#FDECEC] text-[#A3261F]">{{ c.codigo }}</span>
                  <div class="flex flex-col gap-0.5">
                    <strong class="text-[13px] text-[#16201B]">{{ c.nombre }}</strong>
                    <span class="text-[11px] text-[#5B6660]">
                      {{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                      <template v-if="c.requiere_advertencia"> · requiere advertencia previa</template>
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Estados -->
            <div class="bg-[#F4F6F4] border border-[#E3E7E4] rounded-xl p-3.5">
              <p class="text-[11px] font-bold text-[#8A948E] uppercase tracking-wide m-0 mb-3">Estados</p>
              <div v-for="(est, idx) in [
                { chip: 'Registrada',  cls: 'bg-[#EEF0EE] text-[#4A544F]', desc: 'Esperando revisión del admin' },
                { chip: 'Validada',    cls: 'bg-[#E1F3EA] text-[#0B6B4B]', desc: 'Confirmada — aplica al puntaje' },
                { chip: 'Rechazada',   cls: 'bg-[#FDECEC] text-[#A3261F]', desc: 'No procede — no afecta el puntaje' },
              ]" :key="idx"
              class="flex items-center gap-2.5 py-2 text-[13px] text-[#5B6660]"
              :class="idx > 0 ? 'border-t border-[#EEF1EF]' : ''"
              >
                <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0" :class="est.cls">{{ est.chip }}</span>
                <span>{{ est.desc }}</span>
              </div>
            </div>

            <!-- Nota -->
            <div class="flex items-start gap-2 bg-[#FFF8EA] border border-[#F3DDAE] rounded-xl px-3.5 py-2.5 text-[12px] text-[#7A4F00] leading-relaxed">
              <svg class="flex-shrink-0 mt-0.5" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
              <span>Un solo demérito por episodio. El puntaje mínimo del equipo es 0.</span>
            </div>
          </div>

          <!-- Footer -->
          <div class="px-5 py-4 border-t border-[#F4F6F4] flex-shrink-0">
            <button
              class="w-full h-11 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit] hover:bg-[#0B6B4B] transition-colors"
              @click="modalOpen = false"
            >Entendido</button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
