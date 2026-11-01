<script setup lang="ts">
import { ref, computed, onMounted, watch, defineComponent, h } from 'vue'
import {
  criteriosService,
  programacionService,
  categoriasService,
  campamentoCriteriosService,
  type Criterio,
  type Programacion,
  type ResumenProgramacion,
  type CategoriaCriterio,
} from '@/modules/criterios/services/criterios.service'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { useCampamentoStore } from '@/stores/campamento'

// ── Sub-componente para el contenido de cada celda ─────
const CeldaContenido = defineComponent({
  name: 'CeldaContenido',
  props: {
    prog: { type: Object as () => Programacion | undefined, default: undefined },
  },
  setup(props) {
    return () => {
      const p = props.prog
      if (!p) return h('span', { class: 'text-gray-400 text-xs' }, '—')
      if (p.estado === 'programado')
        return h('span', { class: 'bg-green-100 text-green-700 text-xs font-bold px-2 py-0.5 rounded-full' }, `${p.puntaje_max} pts`)
      if (p.estado === 'cancelado')
        return h('span', { class: 'bg-red-100 text-red-600 text-xs font-bold px-2 py-0.5 rounded-full' }, 'Cancelado')
      return h('span', { class: 'text-gray-400 text-xs' }, 'N/P')
    }
  },
})

// ── Estado ─────────────────────────────────────────────
const criterios    = ref<Criterio[]>([])
const programacion = ref<Programacion[]>([])
const resumen      = ref<ResumenProgramacion[]>([])
const categorias   = ref<CategoriaCriterio[]>([])
const cargando     = ref(true)
const error        = ref('')

// Dialog editar celda
const dialogVisible  = ref(false)
const celdaEditando  = ref<Programacion | null>(null)
const celdaCriterio  = ref<Criterio | null>(null)
const celdaMomento   = ref<string>('')
const formEstado     = ref<string>('programado')
const formPuntaje    = ref<number>(100)
const formMotivo     = ref<string>('')
const guardando      = ref(false)
const errorDialog    = ref('')

// ── Constantes ──────────────────────────────────────────
const MOMENTO_UNICO = 'UNICO'

const { momentos, cargar: cargarCampamento, labelDia } = useDiasCampamento()

function labelCategoria(clave: string): string {
  return categorias.value.find((c) => c.clave === clave)?.nombre ?? clave
}

const OPCIONES_ESTADO = [
  { label: 'Programado', value: 'programado' },
  { label: 'Cancelado', value: 'cancelado' },
]

const PUNTAJE_META = 5200

// Mobile tab state
const momentoMobileTab = ref('')

const campStore = useCampamentoStore()

// ── Carga ───────────────────────────────────────────────
async function cargar() {
  // Sin campamento seleccionado → limpiar y no cargar nada
  if (!campStore.selectedId) {
    criterios.value    = []
    programacion.value = []
    resumen.value      = []
    categorias.value   = []
    cargando.value     = false
    return
  }

  cargando.value = true
  error.value    = ''
  const campId   = campStore.selectedId   // capturar antes del await

  try {
    const [p, r, , cat, criterioIds] = await Promise.all([
      programacionService.getTodos(campId),
      programacionService.getResumen(campId),
      cargarCampamento(),
      categoriasService.getTodas(),
      campamentoCriteriosService.getCriterioIds(campId),
    ])

    // Si el campamento cambió mientras cargaba, descartar resultado obsoleto
    if (campStore.selectedId !== campId) return

    programacion.value = p
    resumen.value      = r
    categorias.value   = cat

    // Cargar criterios desde campamento_criterios (no desde programacion)
    if (criterioIds.length) {
      const todos = await criteriosService.getTodos()
      criterios.value = todos.filter((c) => criterioIds.includes(c.id))
    } else {
      criterios.value = []
    }

    momentoMobileTab.value = momentos.value[0] ?? MOMENTO_UNICO
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

const sinCampamento = computed(() => !cargando.value && !campStore.selectedId)
const sinCriterios  = computed(
  () => !cargando.value && !error.value && criterios.value.length === 0 && !!campStore.selectedId,
)

// ── Helpers ─────────────────────────────────────────────

/** Devuelve el registro de programación para un criterio y momento dado */
function getProg(criterioId: string, momento: string): Programacion | undefined {
  return programacion.value.find(
    (p) => p.criterio_id === criterioId && p.momento === momento,
  )
}

/** Subtotal programado de una categoría (solo filas con momento=valor y categoria=valor) */
function subtotalCategoria(categoria: string): number {
  return resumen.value
    .filter((r) => r.categoria === categoria && r.momento !== null)
    .reduce((acc, r) => acc + (r.maximo_programado ?? 0), 0)
}

/** Total general (fila con categoria=null y momento=null) */
const totalGeneral = computed(() => {
  const fila = resumen.value.find((r) => r.categoria === null && r.momento === null)
  return fila?.maximo_programado ?? 0
})

const diferencia = computed(() => totalGeneral.value - PUNTAJE_META)

/** Criterios agrupados por categoría — todos los criterios de campamento_criterios */
const grupos = computed(() => {
  const mapa: Record<string, Criterio[]> = criterios.value.reduce(
    (acc, c) => {
      if (!acc[c.categoria]) acc[c.categoria] = []
      ;(acc[c.categoria] as Criterio[]).push(c)
      return acc
    },
    {} as Record<string, Criterio[]>,
  )
  const orden = categorias.value.length
    ? categorias.value.map((c) => c.clave)
    : ['inscripcion', 'armado', 'orden_cocina', 'ceremonias_participacion', 'liderazgo']
  const extra = Object.keys(mapa).filter((k) => !orden.includes(k))
  return [...orden, ...extra].filter((cat) => mapa[cat]?.length).map((cat) => ({
    categoria: cat,
    items: mapa[cat] ?? [],
  }))
})

// ── Editar / agregar celda ──────────────────────────────
function abrirCelda(criterioId: string, momento: string) {
  const prog = getProg(criterioId, momento)
  celdaEditando.value  = prog ?? null
  celdaCriterio.value  = criterios.value.find((c) => c.id === criterioId) ?? null
  celdaMomento.value   = momento
  formEstado.value     = prog?.estado ?? 'programado'
  formPuntaje.value    = prog?.puntaje_max ?? 100
  formMotivo.value     = prog?.motivo ?? ''
  errorDialog.value    = ''
  dialogVisible.value  = true
}

async function guardar() {
  if (formEstado.value === 'cancelado' && !formMotivo.value.trim()) {
    errorDialog.value = 'Debes indicar el motivo de la cancelación.'
    return
  }
  guardando.value = true
  errorDialog.value = ''
  try {
    const campId = campStore.selectedId!
    if (celdaEditando.value) {
      // Actualizar fila existente
      const actualizado = await programacionService.actualizar(celdaEditando.value.id, {
        estado: formEstado.value,
        puntaje_max: formPuntaje.value,
        motivo: formMotivo.value || null,
      })
      const idx = programacion.value.findIndex((p) => p.id === actualizado.id)
      if (idx !== -1) programacion.value[idx] = actualizado
    } else {
      // Crear nueva fila para este criterio × día
      const nueva = await programacionService.crear({
        campamento_id: campId,
        criterio_id:   celdaCriterio.value!.id,
        momento:       celdaMomento.value,
        puntaje_max:   formPuntaje.value,
        estado:        formEstado.value,
        motivo:        formMotivo.value || null,
      })
      programacion.value.push(nueva)
    }
    resumen.value = await programacionService.getResumen(campId)
    dialogVisible.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

/** Suma de puntajes programados de un criterio (todos sus días) */
function totalCriterio(criterioId: string): number {
  return programacion.value
    .filter((p) => p.criterio_id === criterioId && p.estado === 'programado')
    .reduce((sum, p) => sum + Number(p.puntaje_max ?? 0), 0)
}

/** Etiqueta corta para chip de día en mobile: "Jue", "Vie", "1×" */
function labelDiaCorto(mom: string): string {
  if (mom === MOMENTO_UNICO) return '1×'
  return labelDia(mom).split(' ')[0] ?? mom
}

async function quitarDia() {
  if (!celdaEditando.value) return
  guardando.value = true
  errorDialog.value = ''
  try {
    await programacionService.eliminar(celdaEditando.value.id)
    programacion.value = programacion.value.filter((p) => p.id !== celdaEditando.value!.id)
    resumen.value = await programacionService.getResumen(campStore.selectedId!)
    dialogVisible.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al quitar día'
  } finally {
    guardando.value = false
  }
}

</script>

<template>
  <div class="max-w-5xl mx-auto px-3 py-4 sm:px-6">
    <!-- Header -->
    <h1 class="flex items-center gap-2 text-xl font-bold text-gray-800 mb-4">
      <i class="pi pi-calendar text-green-600" />
      Programación de evaluación
    </h1>

    <!-- Cargando -->
    <div v-if="cargando" class="flex justify-center py-12">
      <svg class="animate-spin h-8 w-8 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
      </svg>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
      {{ error }}
    </div>

    <!-- Sin campamento seleccionado -->
    <div v-else-if="sinCampamento" class="flex flex-col items-center justify-center py-16 text-center gap-3">
      <i class="pi pi-building text-4xl text-gray-300" />
      <p class="text-base font-semibold text-gray-500 m-0">Selecciona un campamento</p>
      <p class="text-sm text-gray-400 m-0">Elige un campamento en el menú lateral para ver su programación.</p>
    </div>

    <template v-else>
      <!-- Banner: campamento sin programación configurada -->
      <div
        v-if="sinCriterios"
        class="bg-blue-50 border border-blue-200 text-blue-800 rounded-2xl px-5 py-4 mb-4 flex items-start gap-3"
      >
        <i class="pi pi-info-circle text-xl mt-0.5 shrink-0" />
        <div>
          <p class="text-sm font-bold m-0 mb-1">Sin criterios aplicados</p>
          <p class="text-sm m-0">
            Este campamento aún no tiene programación. Ve a
            <strong>Criterios de evaluación</strong>, elige una plantilla en
            <em>Criterio General</em>, personalízala en <em>Criterios para este campamento</em>
            y pulsa <strong>Aplicar a este campamento</strong>.
          </p>
        </div>
      </div>

      <!-- Advertencia diferencia de 5200 -->
      <div
        v-if="diferencia !== 0"
        class="bg-amber-50 border border-amber-200 text-amber-800 rounded-xl px-4 py-3 text-sm mb-4"
      >
        El total programado es <strong>{{ totalGeneral }} pts</strong>.
        Diferencia respecto a 5200:
        <strong>{{ diferencia > 0 ? '+' : '' }}{{ diferencia }} pts</strong>.
      </div>

      <!-- ── DESKTOP: tabla (hidden on mobile) ── -->
      <div class="hidden md:block overflow-x-auto rounded-xl border border-gray-200 shadow-sm mb-4">
        <table class="w-full border-collapse text-sm bg-white">
          <thead>
            <tr class="bg-green-50">
              <th class="text-left text-xs font-bold text-gray-500 uppercase px-3 py-2 border border-gray-200 min-w-[200px]">
                Criterio
              </th>
              <th
                v-for="mom in momentos"
                :key="mom"
                class="text-center text-xs font-bold text-gray-500 uppercase px-3 py-2 border border-gray-200 min-w-[80px]"
              >
                {{ labelDia(mom) }}
              </th>
              <th class="text-center text-xs font-bold text-gray-500 uppercase px-3 py-2 border border-gray-200 min-w-[80px]">
                {{ labelDia('UNICO') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="grupo in grupos" :key="grupo.categoria">
              <!-- Cabecera de categoría -->
              <tr>
                <td :colspan="momentos.length + 2" class="bg-green-50 text-green-700 font-bold text-xs px-3 py-2 border border-gray-200">
                  {{ labelCategoria(grupo.categoria) }}
                </td>
              </tr>

              <!-- Filas de criterios -->
              <tr
                v-for="criterio in grupo.items"
                :key="criterio.id"
                class="hover:bg-gray-50 transition"
              >
                <td class="px-3 py-2 border border-gray-200 text-xs align-middle">
                  <span class="bg-gray-200 text-gray-700 text-xs font-bold px-1.5 py-0.5 rounded-full mr-1">
                    {{ criterio.codigo }}
                  </span>
                  {{ criterio.nombre }}
                </td>

                <!-- Columnas de días: todas clickeables -->
                <td
                  v-for="mom in momentos"
                  :key="mom"
                  class="border border-gray-200 text-center align-middle p-0"
                >
                  <button
                    class="w-full min-h-[44px] flex items-center justify-center transition"
                    :class="getProg(criterio.id, mom)
                      ? 'hover:bg-green-50'
                      : 'hover:bg-blue-50'"
                    @click="abrirCelda(criterio.id, mom)"
                  >
                    <CeldaContenido v-if="getProg(criterio.id, mom)" :prog="getProg(criterio.id, mom)" />
                    <span v-else class="text-blue-300 text-lg leading-none">+</span>
                  </button>
                </td>

                <!-- Columna ÚNICO -->
                <td class="border border-gray-200 text-center align-middle p-0">
                  <button
                    class="w-full min-h-[44px] flex items-center justify-center transition"
                    :class="getProg(criterio.id, MOMENTO_UNICO)
                      ? 'hover:bg-green-50'
                      : 'hover:bg-blue-50'"
                    @click="abrirCelda(criterio.id, MOMENTO_UNICO)"
                  >
                    <CeldaContenido v-if="getProg(criterio.id, MOMENTO_UNICO)" :prog="getProg(criterio.id, MOMENTO_UNICO)" />
                    <span v-else class="text-blue-300 text-lg leading-none">+</span>
                  </button>
                </td>
              </tr>

              <!-- Subtotal de categoría -->
              <tr>
                <td :colspan="momentos.length + 2" class="bg-gray-50 text-right text-xs text-gray-500 px-3 py-1.5 border border-gray-200">
                  Subtotal {{ labelCategoria(grupo.categoria) }}:
                  <strong>{{ subtotalCategoria(grupo.categoria) }} pts</strong>
                </td>
              </tr>
            </template>

            <!-- Total general -->
            <tr>
              <td :colspan="momentos.length + 2" class="bg-green-100 text-green-800 font-bold text-right px-3 py-2 border border-gray-200">
                Total general: <strong>{{ totalGeneral }} pts</strong>
                <span
                  v-if="diferencia !== 0"
                  :class="diferencia > 0 ? 'text-orange-600 text-sm ml-2' : 'text-red-600 text-sm ml-2'"
                >
                  ({{ diferencia > 0 ? '+' : '' }}{{ diferencia }} vs 5200)
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- ── MOBILE / TABLET: cards por criterio ── -->
      <div class="md:hidden">

        <!-- Resumen total -->
        <div v-if="criterios.length" class="flex items-center justify-between mb-4 px-1">
          <span class="text-xs text-gray-500 font-medium">{{ criterios.length }} criterios</span>
          <span
            class="text-sm font-bold px-3 py-1 rounded-full"
            :class="diferencia === 0 ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'"
          >
            {{ totalGeneral }} pts
            <span v-if="diferencia !== 0" class="font-normal text-xs">
              ({{ diferencia > 0 ? '+' : '' }}{{ diferencia }} vs 5200)
            </span>
          </span>
        </div>

        <!-- Grupos por categoría -->
        <div class="flex flex-col gap-5">
          <div v-for="grupo in grupos" :key="grupo.categoria">

            <!-- Cabecera de categoría -->
            <div class="flex items-center justify-between mb-2 px-1">
              <h3 class="text-xs font-bold text-green-700 uppercase tracking-wide m-0">
                {{ labelCategoria(grupo.categoria) }}
              </h3>
              <span class="text-xs text-gray-400 font-semibold">{{ subtotalCategoria(grupo.categoria) }} pts</span>
            </div>

            <!-- Cards de criterios -->
            <div class="flex flex-col gap-2">
              <div
                v-for="criterio in grupo.items"
                :key="criterio.id"
                class="bg-white rounded-2xl border shadow-sm overflow-hidden"
                :class="totalCriterio(criterio.id) > 0 ? 'border-green-100' : 'border-gray-200'"
              >
                <!-- Encabezado del criterio -->
                <div class="flex items-center gap-2 px-3 pt-3 pb-2">
                  <span class="bg-gray-100 text-gray-600 text-xs font-bold px-2 py-0.5 rounded-full shrink-0">
                    {{ criterio.codigo }}
                  </span>
                  <span class="text-sm font-semibold text-gray-800 flex-1 min-w-0">
                    {{ criterio.nombre }}
                  </span>
                  <span
                    class="shrink-0 text-xs font-bold px-2 py-0.5 rounded-full"
                    :class="totalCriterio(criterio.id) > 0
                      ? 'bg-green-100 text-green-700'
                      : 'bg-gray-100 text-gray-400'"
                  >
                    {{ totalCriterio(criterio.id) > 0 ? totalCriterio(criterio.id) + ' pts' : 'Sin días' }}
                  </span>
                </div>

                <!-- Chips de días -->
                <div class="flex gap-1.5 px-3 pb-3 flex-wrap">
                  <button
                    v-for="mom in [...momentos, MOMENTO_UNICO]"
                    :key="mom"
                    class="flex flex-col items-center gap-0.5 px-2.5 py-2 rounded-xl border-2 min-w-[52px] min-h-[52px] justify-center transition active:scale-95"
                    :class="getProg(criterio.id, mom)?.estado === 'programado'
                      ? 'border-green-400 bg-green-50'
                      : getProg(criterio.id, mom)?.estado === 'cancelado'
                      ? 'border-red-300 bg-red-50'
                      : 'border-dashed border-gray-200 bg-gray-50 hover:border-blue-300 hover:bg-blue-50'"
                    @click="abrirCelda(criterio.id, mom)"
                  >
                    <span
                      class="text-xs font-bold"
                      :class="getProg(criterio.id, mom)?.estado === 'programado'
                        ? 'text-green-600'
                        : getProg(criterio.id, mom)?.estado === 'cancelado'
                        ? 'text-red-400'
                        : 'text-gray-400'"
                    >
                      {{ labelDiaCorto(mom) }}
                    </span>
                    <span
                      v-if="getProg(criterio.id, mom)?.estado === 'programado'"
                      class="text-xs font-bold text-green-700 leading-none"
                    >
                      {{ getProg(criterio.id, mom)?.puntaje_max }}
                    </span>
                    <span
                      v-else-if="getProg(criterio.id, mom)?.estado === 'cancelado'"
                      class="text-xs text-red-400 leading-none"
                    >✕</span>
                    <span v-else class="text-blue-300 text-base leading-none">+</span>
                  </button>
                </div>
              </div>
            </div>

          </div>
        </div>

        <p v-if="!criterios.length && !sinCriterios" class="text-sm text-gray-500 text-center py-8">
          Sin criterios configurados.
        </p>
      </div>
    </template>

    <!-- Modal editar celda (bottom-sheet) -->
    <Teleport to="body">
      <div
        v-if="dialogVisible"
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      >
        <!-- Backdrop -->
        <div
          class="absolute inset-0 bg-black/40"
          @click="dialogVisible = false"
        />

        <!-- Sheet -->
        <div class="relative bg-white w-full sm:max-w-lg sm:rounded-xl rounded-t-2xl shadow-xl p-5 z-10">
          <!-- Título con contexto -->
          <div class="mb-4">
            <h2 class="text-base font-bold text-gray-800">
              {{ celdaEditando ? 'Editar día' : 'Habilitar día' }}
            </h2>
            <div v-if="celdaCriterio" class="flex items-center gap-2 mt-1">
              <span class="bg-gray-200 text-gray-700 text-xs font-bold px-1.5 py-0.5 rounded-full">
                {{ celdaCriterio.codigo }}
              </span>
              <span class="text-sm text-gray-600 font-medium">{{ celdaCriterio.nombre }}</span>
              <span class="ml-auto bg-green-100 text-green-700 text-xs font-bold px-2 py-0.5 rounded-full">
                {{ labelDia(celdaMomento) }}
              </span>
            </div>
          </div>

          <!-- Error dialog -->
          <div v-if="errorDialog" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm mb-4">
            {{ errorDialog }}
          </div>

          <div class="flex flex-col gap-4">
            <!-- Estado -->
            <div class="flex flex-col gap-1">
              <label class="text-sm font-semibold text-gray-700">Estado</label>
              <div class="grid grid-cols-3 gap-2">
                <button
                  v-for="op in OPCIONES_ESTADO"
                  :key="op.value"
                  class="min-h-[44px] rounded-lg border text-sm font-semibold transition"
                  :class="formEstado === op.value
                    ? op.value === 'programado'   ? 'bg-green-600 text-white border-green-600'
                    : op.value === 'cancelado'    ? 'bg-red-500 text-white border-red-500'
                    :                               'bg-gray-400 text-white border-gray-400'
                    : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
                  @click="formEstado = op.value; if (op.value === 'cancelado') formPuntaje = 0"
                >
                  {{ op.label }}
                </button>
              </div>
            </div>

            <!-- Puntaje máximo -->
            <div class="flex flex-col gap-1">
              <label class="text-sm font-semibold text-gray-700">
                Puntaje máximo
                <span v-if="formEstado === 'cancelado'" class="text-xs text-gray-400 font-normal ml-1">(no aplica)</span>
              </label>
              <div class="flex items-center gap-2">
                <input
                  v-model.number="formPuntaje"
                  type="number"
                  min="0"
                  max="9999"
                  :disabled="formEstado === 'cancelado'"
                  class="flex-1 min-h-[44px] border border-gray-300 rounded-lg px-3 py-2 text-sm font-bold text-center focus:outline-none focus:ring-2 focus:ring-green-500 disabled:bg-gray-100 disabled:text-gray-400"
                />
                <span class="text-sm text-gray-500 shrink-0">pts</span>
              </div>
              <!-- Atajos de puntaje -->
              <div v-if="formEstado === 'programado'" class="flex gap-1 flex-wrap mt-1">
                <button
                  v-for="v in [25, 50, 75, 100, 150, 200]"
                  :key="v"
                  class="px-2 py-1 text-xs rounded-lg border transition"
                  :class="formPuntaje === v
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-600 border-gray-200 hover:border-green-400'"
                  @click="formPuntaje = v"
                >
                  {{ v }}
                </button>
              </div>
            </div>

            <!-- Motivo -->
            <div class="flex flex-col gap-1">
              <label class="text-sm font-semibold text-gray-700">
                Motivo
                <span v-if="formEstado !== 'cancelado'" class="text-xs text-gray-400 font-normal ml-1">(opcional)</span>
                <span v-else class="text-xs text-red-500 font-normal ml-1">* obligatorio al cancelar</span>
              </label>
              <textarea
                v-model="formMotivo"
                rows="2"
                placeholder="Cancelado por lluvia, ajuste especial, etc."
                class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500 resize-none"
                :class="formEstado === 'cancelado' && !formMotivo.trim() ? 'border-red-400' : 'border-gray-300'"
              />
            </div>
          </div>

          <!-- Footer -->
          <div class="flex items-center gap-2 mt-5">
            <!-- Quitar día (solo si ya existe la fila) -->
            <button
              v-if="celdaEditando"
              :disabled="guardando"
              class="px-3 py-2 min-h-[44px] rounded-lg border border-red-200 text-sm font-semibold text-red-600 bg-white hover:bg-red-50 transition disabled:opacity-50 flex items-center gap-1.5"
              @click="quitarDia"
            >
              <i class="pi pi-trash text-xs" />
              Quitar día
            </button>
            <div class="flex-1" />
            <button
              :disabled="guardando"
              class="px-4 py-2 min-h-[44px] rounded-lg border border-gray-300 text-sm font-semibold text-gray-700 bg-white hover:bg-gray-50 transition disabled:opacity-50"
              @click="dialogVisible = false"
            >
              Cancelar
            </button>
            <button
              :disabled="guardando"
              class="px-4 py-2 min-h-[44px] rounded-lg bg-green-600 text-white text-sm font-semibold hover:bg-green-700 transition disabled:opacity-50 flex items-center gap-2"
              @click="guardar"
            >
              <svg v-if="guardando" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
              </svg>
              <i v-else class="pi pi-check" />
              {{ celdaEditando ? 'Guardar' : 'Habilitar' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

