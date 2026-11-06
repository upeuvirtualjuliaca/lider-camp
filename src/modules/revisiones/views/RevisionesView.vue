<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import {
  incidenciasService,
  codigosService,
  evidenciasService,
  type Incidencia,
  type IncidenciaDetalle,
  type IncidenciaCodigo,
} from '@/modules/incidencias/services/incidencias.service'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import { useCampamentoStore } from '@/stores/campamento'
import { useRevisionesStore } from '../store'
import ReviewPanel  from '../components/ReviewPanel.vue'
import RejectDialog from '../components/RejectDialog.vue'

const campStore = useCampamentoStore()
const revStore  = useRevisionesStore()

// ── Data ──────────────────────────────────────────────────────────────────────
const lista    = ref<Incidencia[]>([])
const codigos  = ref<IncidenciaCodigo[]>([])
const equipos  = ref<Equipo[]>([])
const cargando = ref(true)
const error    = ref('')

// ── Tabs & filters ────────────────────────────────────────────────────────────
const tab          = ref<'pend' | 'val' | 'rec' | 'all'>('pend')
const filtroEquipo = ref('')
const filtroTipo   = ref<'' | 'bonus' | 'demerito'>('')
const filtroFecha  = ref('')

// ── Selection & detail ────────────────────────────────────────────────────────
const selectedId  = ref<string | null>(null)
const detalle     = ref<IncidenciaDetalle | null>(null)
const detCargando = ref(false)
const detError    = ref('')
const detUrls     = ref<Record<string, string>>({})

// ── Review state ─────────────────────────────────────────────────────────────
const comentarioAdmin = ref('')
const accionando      = ref(false)
const accionError     = ref('')

// ── Reject dialog ─────────────────────────────────────────────────────────────
const rejectOpen = ref(false)

// ── Load ──────────────────────────────────────────────────────────────────────
onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargar() {
  cargando.value = true
  error.value    = ''
  try {
    const [inc, cod, eq] = await Promise.all([
      incidenciasService.getAll({ campamento_id: campStore.selectedId ?? undefined }),
      codigosService.getAll(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])
    lista.value   = inc
    codigos.value = cod
    equipos.value = eq
    revStore.cntPendiente = inc.filter(
      (i) => i.estado === 'registrado' || i.estado === 'descargo',
    ).length
    // drop stale selection
    if (selectedId.value && !inc.find((i) => i.id === selectedId.value)) {
      selectedId.value = null
      detalle.value    = null
    }
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const tipoPorCodigo = computed(() => {
  const m = new Map<string, 'bonus' | 'demerito'>()
  codigos.value.forEach((c) => m.set(c.codigo, c.tipo as 'bonus' | 'demerito'))
  return m
})

function tipoDe(codigo: string): 'bonus' | 'demerito' {
  return tipoPorCodigo.value.get(codigo) ?? 'demerito'
}

function nombreEquipo(id: string): string {
  return equipos.value.find((e) => e.id === id)?.nombre ?? '—'
}

function fmt(fecha: string, hora: string | null): string {
  const DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
  const d = new Date(fecha + 'T12:00:00')
  return `${DIAS[d.getDay()]} ${d.getDate()}${hora ? ' · ' + hora.slice(0, 5) : ''}`
}

// ── Counts ────────────────────────────────────────────────────────────────────
const cntPend = computed(() =>
  lista.value.filter((i) => i.estado === 'registrado' || i.estado === 'descargo').length)
const cntVal  = computed(() => lista.value.filter((i) => i.estado === 'validado').length)
const cntRec  = computed(() => lista.value.filter((i) => i.estado === 'rechazado').length)

// ── Filtered list ─────────────────────────────────────────────────────────────
const listaFiltrada = computed(() => {
  let list = lista.value
  if (tab.value === 'pend') list = list.filter((i) => i.estado === 'registrado' || i.estado === 'descargo')
  else if (tab.value === 'val') list = list.filter((i) => i.estado === 'validado')
  else if (tab.value === 'rec') list = list.filter((i) => i.estado === 'rechazado')
  if (filtroEquipo.value) list = list.filter((i) => i.equipo_id === filtroEquipo.value)
  if (filtroTipo.value)   list = list.filter((i) => tipoDe(i.codigo) === filtroTipo.value)
  if (filtroFecha.value)  list = list.filter((i) => i.fecha === filtroFecha.value)
  return list
})

// ── Unique filter options ─────────────────────────────────────────────────────
const fechasUnicas = computed(() => {
  const set = new Set<string>()
  lista.value.forEach((i) => { if (i.fecha) set.add(i.fecha) })
  return [...set].sort().reverse()
})

const equiposEnLista = computed(() => {
  const set = new Set<string>()
  lista.value.forEach((i) => set.add(i.equipo_id))
  return equipos.value.filter((e) => set.has(e.id))
})

// ── Estado config ─────────────────────────────────────────────────────────────
const ESTADO_CFG: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Registrada',  cls: 'bg-[#EEF0EE] text-[#4A544F]' },
  descargo:   { label: 'En descargo', cls: 'bg-[#FFF1D6] text-[#7A4F00]' },
  validado:   { label: 'Validada',    cls: 'bg-[#E1F3EA] text-[#0B6B4B]' },
  rechazado:  { label: 'Rechazada',   cls: 'bg-[#FDECEC] text-[#A3261F]' },
}
function estadoCfg(e: string) { return ESTADO_CFG[e] ?? { label: e, cls: 'bg-[#EEF0EE] text-[#4A544F]' } }

// ── Selection ─────────────────────────────────────────────────────────────────
async function seleccionar(id: string) {
  if (selectedId.value === id) return
  selectedId.value      = id
  detalle.value         = null
  detUrls.value         = {}
  detError.value        = ''
  comentarioAdmin.value = ''
  accionError.value     = ''
  rejectOpen.value  = false

  detCargando.value = true
  try {
    const d = await incidenciasService.getPorId(id)
    if (!d) { detError.value = 'No encontrado'; return }
    detalle.value = d
    for (const ev of d.evidencias) {
      detUrls.value[ev.id] = await evidenciasService.getUrl(ev.ruta_archivo)
    }
  } catch (e: any) {
    detError.value = e.message ?? 'Error al cargar detalle'
  } finally {
    detCargando.value = false
  }
}

// ── Pending position ──────────────────────────────────────────────────────────
const pendList = computed(() =>
  lista.value.filter((i) => i.estado === 'registrado' || i.estado === 'descargo'))

const pendPos = computed(() => {
  if (!selectedId.value) return null
  const idx = pendList.value.findIndex((i) => i.id === selectedId.value)
  return idx >= 0 ? { pos: idx + 1, total: pendList.value.length } : null
})

function irSiguientePendiente() {
  if (!selectedId.value) return
  const idx = pendList.value.findIndex((i) => i.id === selectedId.value)
  if (idx >= 0 && idx + 1 < pendList.value.length) {
    seleccionar(pendList.value[idx + 1]!.id)
  } else {
    selectedId.value = null
    detalle.value    = null
  }
}

// ── Actions ───────────────────────────────────────────────────────────────────
function updateLista(actualizado: Incidencia) {
  const idx = lista.value.findIndex((i) => i.id === actualizado.id)
  if (idx >= 0) lista.value[idx] = actualizado
  if (detalle.value?.id === actualizado.id) {
    detalle.value = { ...detalle.value, ...actualizado }
  }
}

async function validar() {
  if (!detalle.value) return
  accionando.value  = true
  accionError.value = ''
  try {
    const motivo = comentarioAdmin.value.trim() || null
    const actualizado = await incidenciasService.validar(detalle.value.id, motivo)
    updateLista(actualizado)
    revStore.cntPendiente = Math.max(0, revStore.cntPendiente - 1)
    irSiguientePendiente()
  } catch (e: any) {
    accionError.value = e.message ?? 'Error al validar'
  } finally {
    accionando.value = false
  }
}

async function confirmarRechazo(motivo: string) {
  if (!detalle.value) return
  accionando.value  = true
  accionError.value = ''
  try {
    const actualizado = await incidenciasService.rechazar(detalle.value.id, motivo)
    updateLista(actualizado)
    revStore.cntPendiente = Math.max(0, revStore.cntPendiente - 1)
    rejectOpen.value = false
    irSiguientePendiente()
  } catch (e: any) {
    accionError.value = e.message ?? 'Error al rechazar'
  } finally {
    accionando.value = false
  }
}

async function reabrir() {
  if (!detalle.value) return
  accionando.value  = true
  accionError.value = ''
  try {
    const actualizado = await incidenciasService.actualizar(detalle.value.id, {
      estado: 'registrado',
      motivo_resolucion: null,
    })
    updateLista(actualizado)
    revStore.cntPendiente += 1
    comentarioAdmin.value = ''
  } catch (e: any) {
    accionError.value = e.message ?? 'Error al reabrir'
  } finally {
    accionando.value = false
  }
}

// ── Tab state: for pending, also show if selected is pending ──────────────────
const selectedEstado = computed(() => detalle.value?.estado ?? lista.value.find(i => i.id === selectedId.value)?.estado ?? null)
const selectedIsPending = computed(() => selectedEstado.value === 'registrado' || selectedEstado.value === 'descargo')
</script>

<template>
  <!-- Root: on tablet/desktop becomes fixed-height flex split layout -->
  <div class="bg-[#F4F6F4] flex flex-col md:flex-row md:h-dvh xl:h-[calc(100dvh-64px)] md:overflow-hidden">

    <!-- ═══════════════ LIST COLUMN ═══════════════ -->
    <div
      class="flex flex-col bg-white md:w-[420px] md:flex-shrink-0 xl:flex-1 xl:w-auto md:border-r md:border-[#E3E7E4] md:overflow-hidden"
      :class="selectedId ? 'hidden md:flex' : 'flex'"
    >
      <!-- List header (title + tabs + filters) -->
      <div class="flex-shrink-0 border-b border-[#E3E7E4]">
        <!-- Title row (tablet/desktop) -->
        <div class="hidden md:flex items-center justify-between px-5 pt-4 pb-3">
          <div>
            <p class="text-[12px] text-[#5B6660] mb-0.5">Administración</p>
            <h1 class="text-[20px] font-bold m-0">Revisiones</h1>
          </div>
          <button
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-[#E3E7E4] bg-white text-[#5B6660] hover:bg-[#F4F6F4] transition-colors disabled:opacity-50"
            :disabled="cargando"
            @click="cargar"
            aria-label="Actualizar"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true" :class="cargando ? 'animate-spin' : ''"><path d="M1 4v6h6"/><path d="M23 20v-6h-6"/><path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"/></svg>
          </button>
        </div>

        <!-- Tabs: underline on mobile, pill segments on tablet/desktop -->
        <div
          class="flex gap-[18px] overflow-x-auto px-4 md:gap-1 md:bg-[#EEF1EF] md:rounded-xl md:mx-4 xl:mx-5 md:p-1 md:overflow-visible md:px-0 md:my-3"
        >
          <button
            v-for="t in [
              { key: 'pend', label: 'Pendientes', cnt: cntPend  },
              { key: 'val',  label: 'Validadas',  cnt: cntVal   },
              { key: 'rec',  label: 'Rechazadas', cnt: cntRec   },
              { key: 'all',  label: 'Todas',      cnt: lista.length },
            ]"
            :key="t.key"
            class="flex-shrink-0 flex items-center gap-1.5 text-[14px] transition-colors border-0"
            :class="[
              tab === t.key
                ? 'text-[#0E7C59] font-semibold pb-3 border-b-2 border-[#0E7C59] md:pb-0 md:border-b-0 md:bg-white md:shadow-sm md:text-[#16201B] md:rounded-lg md:px-3.5 md:py-[7px]'
                : 'text-[#5B6660] pb-3 border-b-2 border-transparent md:pb-0 md:border-b-0 md:bg-transparent md:px-3.5 md:py-[7px] md:rounded-lg hover:md:bg-white/50',
            ]"
            @click="tab = t.key as any"
          >
            {{ t.label }}
            <span
              class="text-[11px] font-bold px-[6px] py-0.5 rounded-lg leading-none"
              :class="t.key === 'pend' && t.cnt > 0
                ? 'bg-[#0E7C59] text-white'
                : 'bg-[#E3E7E4] text-[#3A4540]'"
            >{{ t.cnt }}</span>
          </button>
        </div>

        <!-- Filters row -->
        <div class="flex gap-2 px-4 xl:px-5 pb-3 overflow-x-auto">
          <select
            v-model="filtroFecha"
            class="text-[13px] h-8 px-2.5 rounded-lg border border-[#DCE1DD] bg-white text-[#16201B] outline-none focus:border-[#0E7C59]"
          >
            <option value="">Día</option>
            <option v-for="f in fechasUnicas" :key="f" :value="f">{{ f }}</option>
          </select>
          <select
            v-model="filtroEquipo"
            class="text-[13px] h-8 px-2.5 rounded-lg border border-[#DCE1DD] bg-white text-[#16201B] outline-none focus:border-[#0E7C59] flex-1 min-w-0 max-w-[160px]"
          >
            <option value="">Equipo</option>
            <option v-for="eq in equiposEnLista" :key="eq.id" :value="eq.id">{{ eq.nombre }}</option>
          </select>
          <select
            v-model="filtroTipo"
            class="text-[13px] h-8 px-2.5 rounded-lg border border-[#DCE1DD] bg-white text-[#16201B] outline-none focus:border-[#0E7C59]"
          >
            <option value="">Tipo</option>
            <option value="bonus">Bonus</option>
            <option value="demerito">Demérito</option>
          </select>
        </div>
      </div>

      <!-- List body -->
      <div class="flex-1 overflow-y-auto">
        <!-- Loading skeleton -->
        <template v-if="cargando">
          <div v-for="n in 4" :key="n" class="flex items-start gap-3 px-4 py-3.5 border-b border-[#EEF1EF]">
            <div class="w-10 h-10 rounded-[10px] bg-[#EEF1EF] animate-pulse flex-shrink-0" />
            <div class="flex-1 flex flex-col gap-2">
              <div class="h-4 w-3/4 bg-[#EEF1EF] rounded animate-pulse" />
              <div class="h-3 w-full bg-[#EEF1EF] rounded animate-pulse" />
              <div class="h-3 w-1/2 bg-[#EEF1EF] rounded animate-pulse" />
            </div>
          </div>
        </template>

        <!-- Error -->
        <div v-else-if="error" class="flex flex-col items-center justify-center py-16 gap-2 text-center px-4">
          <span class="text-[14px] text-[#A3261F]">{{ error }}</span>
          <button class="text-[13px] text-[#0E7C59] underline" @click="cargar">Reintentar</button>
        </div>

        <!-- Empty state -->
        <div v-else-if="listaFiltrada.length === 0" class="flex flex-col items-center justify-center py-16 gap-2 text-center px-4">
          <span
            class="w-[52px] h-[52px] rounded-full bg-[#E1F3EA] flex items-center justify-center"
            aria-hidden="true"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#0E7C59" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10"/></svg>
          </span>
          <span class="text-[16px] font-bold">Todo al día</span>
          <span class="text-[13px] text-[#5B6660]">
            {{ tab === 'pend' ? 'No hay incidencias esperando revisión.' : 'No hay registros en este estado.' }}
          </span>
        </div>

        <!-- Rows -->
        <ul v-else class="list-none m-0 p-0">
          <li v-for="inc in listaFiltrada" :key="inc.id" class="border-b border-[#EEF1EF] last:border-0">
            <button
              class="w-full flex items-start gap-3 px-4 py-3.5 text-left transition-colors"
              :class="selectedId === inc.id ? 'bg-[#E1F3EA]' : 'hover:bg-[#F4F6F4]'"
              @click="seleccionar(inc.id)"
            >
              <!-- Code badge -->
              <span
                class="flex-shrink-0 w-10 h-10 rounded-[10px] flex items-center justify-center text-[13px] font-bold"
                :class="tipoDe(inc.codigo) === 'bonus' ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#FDECEC] text-[#A3261F]'"
              >{{ inc.codigo }}</span>

              <!-- Content -->
              <span class="flex-1 min-w-0 flex flex-col gap-1">
                <span class="flex justify-between items-start gap-2">
                  <span class="text-[14px] font-semibold truncate">{{ nombreEquipo(inc.equipo_id) }}</span>
                  <span
                    class="text-[14px] font-bold flex-shrink-0"
                    :class="inc.estado === 'rechazado'
                      ? 'text-[#8A948E] line-through'
                      : tipoDe(inc.codigo) === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'"
                  >{{ tipoDe(inc.codigo) === 'bonus' ? '+' : '−' }}{{ inc.puntos }}</span>
                </span>
                <span class="text-[13px] text-[#3A4540] truncate">{{ inc.hecho }}</span>
                <span class="flex items-center gap-2 flex-wrap">
                  <span
                    class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px]"
                    :class="estadoCfg(inc.estado).cls"
                  >{{ estadoCfg(inc.estado).label }}</span>
                  <span class="text-[12px] text-[#5B6660]">{{ fmt(inc.fecha, inc.hora) }}</span>
                </span>
              </span>

              <!-- Chevron (mobile only) -->
              <svg class="md:hidden mt-3 flex-shrink-0 text-[#8A948E]" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
            </button>
          </li>
        </ul>
      </div>
    </div>
    <!-- /LIST COLUMN -->

    <!-- ═══════════════ DETAIL PANEL (tablet + desktop) ═══════════════ -->
    <div class="hidden md:flex flex-col flex-1 min-w-0 overflow-hidden bg-[#F4F6F4]">
      <ReviewPanel
        :detalle="detalle"
        :cargando="detCargando"
        :error="detError"
        :det-urls="detUrls"
        :comentario-admin="comentarioAdmin"
        :accionando="accionando"
        :accion-error="accionError"
        :pend-pos="pendPos"
        :tipo-de="tipoDe"
        :nombre-equipo="nombreEquipo"
        @update:comentario-admin="comentarioAdmin = $event"
        @validar="validar"
        @abrir-rechazo="rejectOpen = true"
        @reabrir="reabrir"
        class="flex-1 overflow-y-auto flex flex-col"
      />
    </div>

  </div>
  <!-- /split container -->

  <!-- ═══════════════ MOBILE DETAIL OVERLAY ═══════════════ -->
  <Transition
    enter-active-class="transition-transform duration-300 ease-out"
    enter-from-class="translate-x-full"
    leave-active-class="transition-transform duration-250 ease-in"
    leave-to-class="translate-x-full"
  >
    <div
      v-if="selectedId"
      class="md:hidden fixed inset-0 z-50 bg-[#F4F6F4] flex flex-col"
    >
      <!-- Mobile detail header -->
      <header class="bg-white border-b border-[#E3E7E4] px-4 py-3 flex items-center gap-2 min-h-[68px] flex-shrink-0">
        <button
          class="w-11 h-11 flex items-center justify-center rounded-xl -ml-2 text-[#16201B]"
          aria-label="Volver"
          @click="selectedId = null; detalle = null"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 6l-6 6 6 6"/></svg>
        </button>
        <div class="flex-1 flex flex-col">
          <span class="text-[17px] font-bold">Revisar incidencia</span>
          <span v-if="pendPos" class="text-[12px] text-[#5B6660]">{{ pendPos.pos }} de {{ pendPos.total }} pendientes</span>
        </div>
        <span
          v-if="selectedEstado"
          class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px]"
          :class="estadoCfg(selectedEstado).cls"
        >{{ estadoCfg(selectedEstado).label }}</span>
      </header>

      <!-- Scrollable detail content (reuses ReviewPanel but without its footer bar) -->
      <ReviewPanel
        :detalle="detalle"
        :cargando="detCargando"
        :error="detError"
        :det-urls="detUrls"
        :comentario-admin="comentarioAdmin"
        :accionando="accionando"
        :accion-error="accionError"
        :pend-pos="pendPos"
        :tipo-de="tipoDe"
        :nombre-equipo="nombreEquipo"
        @update:comentario-admin="comentarioAdmin = $event"
        @validar="validar"
        @abrir-rechazo="rejectOpen = true"
        @reabrir="reabrir"
        class="flex-1 overflow-y-auto flex flex-col"
      />

      <!-- Mobile fixed footer (pending only) -->
      <footer
        v-if="selectedIsPending && detalle"
        class="bg-white border-t border-[#E3E7E4] px-4 pb-[22px] pt-3 flex flex-col gap-2 flex-shrink-0"
      >
        <div class="flex gap-2.5">
          <button
            class="flex-1 h-[50px] rounded-[14px] border border-[#DCE1DD] bg-white text-[15px] font-semibold text-[#A3261F] hover:bg-[#FDECEC] transition-colors disabled:opacity-50"
            :disabled="accionando"
            @click="rejectOpen = true"
          >Rechazar</button>
          <button
            class="flex-[2] h-[50px] rounded-[14px] border-0 bg-[#0E7C59] text-[15px] font-semibold text-white transition-colors disabled:opacity-50"
            :disabled="accionando"
            @click="validar"
          >Validar</button>
        </div>
      </footer>
    </div>
  </Transition>

  <!-- ═══════════════ REJECT DIALOG ═══════════════ -->
  <RejectDialog
    :open="rejectOpen"
    :accionando="accionando"
    @confirm="confirmarRechazo"
    @cancel="rejectOpen = false"
  />
</template>
