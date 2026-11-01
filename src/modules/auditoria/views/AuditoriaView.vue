<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  auditoriaService,
  type AuditoriaFila,
  type FiltrosAuditoria,
} from '@/modules/auditoria/services/auditoria.service'

const lista    = ref<AuditoriaFila[]>([])
const cargando = ref(true)
const error    = ref('')
const mostrarAyuda = ref(false)
const mostrarFiltros = ref(false)

const filtros = ref<FiltrosAuditoria>({
  tabla:  '',
  accion: '',
  desde:  '',
  hasta:  '',
})

const TABLAS = [
  'observaciones', 'asistencia_registros', 'liderazgo_evaluaciones',
  'incidencias', 'equipos', 'integrantes', 'programacion',
  'actividades', 'campamento', 'solicitudes_revision',
]

const TABLA_LABELS: Record<string, string> = {
  observaciones:           'Observaciones',
  asistencia_registros:    'Asistencia',
  liderazgo_evaluaciones:  'Liderazgo',
  incidencias:             'Incidencias',
  equipos:                 'Equipos',
  integrantes:             'Integrantes',
  programacion:            'Programación',
  actividades:             'Actividades',
  campamento:              'Campamento',
  solicitudes_revision:    'Revisiones',
}

onMounted(() => cargar())

async function cargar() {
  cargando.value = true
  error.value    = ''
  try {
    lista.value = await auditoriaService.getAll({
      tabla:  filtros.value.tabla  || undefined,
      accion: filtros.value.accion || undefined,
      desde:  filtros.value.desde  || undefined,
      hasta:  filtros.value.hasta  || undefined,
    })
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

function limpiarFiltros() {
  filtros.value = { tabla: '', accion: '', desde: '', hasta: '' }
  cargar()
}

function accionColor(accion: string | null) {
  if (accion === 'INSERT') return 'bg-green-100 text-green-700'
  if (accion === 'UPDATE') return 'bg-yellow-100 text-yellow-800'
  if (accion === 'DELETE') return 'bg-red-100 text-red-700'
  return 'bg-gray-100 text-gray-600'
}

function accionLabel(accion: string | null) {
  if (accion === 'INSERT') return 'Creación'
  if (accion === 'UPDATE') return 'Edición'
  if (accion === 'DELETE') return 'Eliminación'
  return accion ?? '—'
}

function formatFecha(ts: string | null) {
  if (!ts) return '—'
  return new Date(ts).toLocaleString('es-PE', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function getFilaCambios(row: any): Array<{ k: string; antes: unknown; despues: unknown }> {
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
  const c = row.cambios
  if (!c || typeof c !== 'object' || Array.isArray(c)) return []
  return Object.keys(c as object).map((k) => ({
    k,
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    antes:   (c as any)[k]?.antes   ?? '—',
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    despues: (c as any)[k]?.despues ?? '—',
  }))
}

const hayFiltrosActivos = () =>
  !!(filtros.value.tabla || filtros.value.accion || filtros.value.desde || filtros.value.hasta)
</script>

<template>
  <div class="max-w-5xl mx-auto px-3 py-4 sm:px-6">

    <!-- Encabezado -->
    <div class="flex items-center justify-between mb-4 gap-2">
      <div class="flex items-center gap-2">
        <i class="pi pi-history text-green-700 text-xl" />
        <h1 class="text-lg font-extrabold text-gray-800">Historial de auditoría</h1>
      </div>
      <div class="flex gap-2">
        <!-- Filtros toggle (mobile) -->
        <button
          class="flex items-center gap-1.5 px-3 py-2 rounded-lg border text-sm font-semibold min-h-[44px] transition"
          :class="mostrarFiltros || hayFiltrosActivos()
            ? 'bg-green-50 border-green-300 text-green-700'
            : 'bg-white border-gray-200 text-gray-600'"
          @click="mostrarFiltros = !mostrarFiltros"
        >
          <i class="pi pi-filter text-sm" />
          <span class="hidden sm:inline">Filtros</span>
          <span v-if="hayFiltrosActivos()" class="w-2 h-2 rounded-full bg-green-500 sm:hidden" />
        </button>
        <!-- Ayuda -->
        <button
          class="w-10 h-10 rounded-full bg-green-50 border border-green-200 text-green-700 font-bold text-base flex items-center justify-center hover:bg-green-100 transition"
          title="¿Cómo funciona la auditoría?"
          @click="mostrarAyuda = true"
        >?</button>
      </div>
    </div>

    <!-- Panel de filtros -->
    <div v-if="mostrarFiltros" class="bg-white border border-gray-200 rounded-xl p-4 mb-4 shadow-sm">
      <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Filtrar registros</p>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Módulo</label>
          <select
            v-model="filtros.tabla"
            class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm bg-white focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px]"
          >
            <option value="">Todos los módulos</option>
            <option v-for="t in TABLAS" :key="t" :value="t">{{ TABLA_LABELS[t] ?? t }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Tipo de acción</label>
          <select
            v-model="filtros.accion"
            class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm bg-white focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px]"
          >
            <option value="">Todas las acciones</option>
            <option value="INSERT">Creación</option>
            <option value="UPDATE">Edición</option>
            <option value="DELETE">Eliminación</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Desde</label>
          <input
            v-model="filtros.desde"
            type="date"
            class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm bg-white focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px]"
          />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Hasta</label>
          <input
            v-model="filtros.hasta"
            type="date"
            class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm bg-white focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px]"
          />
        </div>
      </div>
      <div class="flex gap-2 mt-4">
        <button
          class="flex-1 sm:flex-none flex items-center justify-center gap-2 px-5 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm font-semibold min-h-[44px] disabled:opacity-50 transition"
          :disabled="cargando"
          @click="cargar"
        >
          <i class="pi pi-search text-sm" />
          Buscar
        </button>
        <button
          v-if="hayFiltrosActivos()"
          class="flex items-center gap-1.5 px-4 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-500 hover:bg-gray-50 min-h-[44px] transition"
          @click="limpiarFiltros"
        >
          <i class="pi pi-times text-xs" />
          Limpiar
        </button>
      </div>
    </div>

    <!-- Estado de carga -->
    <div v-if="cargando" class="flex items-center justify-center py-16 gap-3 text-gray-400">
      <i class="pi pi-spin pi-spinner text-2xl text-green-500" />
      <span class="text-sm">Cargando registros…</span>
    </div>

    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-xl p-4 text-red-700 text-sm">
      <i class="pi pi-exclamation-triangle mr-2" />{{ error }}
    </div>

    <template v-else>
      <!-- Conteo -->
      <p class="text-xs text-gray-400 mb-3">
        {{ lista.length }} registro(s) encontrados
        <span v-if="hayFiltrosActivos()" class="text-green-600 font-medium"> · filtros activos</span>
      </p>

      <!-- Sin resultados -->
      <div v-if="!lista.length" class="flex flex-col items-center justify-center py-16 text-gray-400 gap-2">
        <i class="pi pi-inbox text-4xl" />
        <p class="text-sm">No se encontraron registros.</p>
        <button v-if="hayFiltrosActivos()" class="text-green-600 text-sm font-medium mt-1 underline" @click="limpiarFiltros">
          Quitar filtros
        </button>
      </div>

      <!-- Cards (mobile) / Tabla (desktop) -->
      <template v-else>
        <!-- Móvil: tarjetas -->
        <div class="flex flex-col gap-3 md:hidden">
          <div
            v-for="row in lista"
            :key="row.id ?? ''"
            class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm"
          >
            <!-- Header de la card -->
            <div class="flex items-start justify-between gap-2 mb-3">
              <div>
                <span
                  class="inline-block text-xs font-bold px-2 py-0.5 rounded-full mr-2"
                  :class="accionColor(row.accion)"
                >{{ accionLabel(row.accion) }}</span>
                <span class="font-semibold text-sm text-gray-800">
                  {{ TABLA_LABELS[row.tabla ?? ''] ?? row.tabla ?? '—' }}
                </span>
              </div>
              <span class="text-xs text-gray-400 whitespace-nowrap mt-0.5">{{ formatFecha(row.created_at) }}</span>
            </div>

            <!-- Meta -->
            <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 mb-3">
              <span v-if="row.evaluador_nombre">
                <i class="pi pi-user mr-1" />{{ row.evaluador_nombre }}
              </span>
              <span v-if="row.registro_id" class="font-mono text-gray-400">
                ID: {{ (row.registro_id ?? '').slice(0, 8) }}…
              </span>
            </div>

            <!-- Cambios -->
            <div v-if="getFilaCambios(row).length" class="bg-gray-50 rounded-lg p-3 space-y-1.5">
              <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Cambios</p>
              <div
                v-for="item in getFilaCambios(row)"
                :key="item.k"
                class="flex flex-wrap items-center gap-1.5 text-xs"
              >
                <span class="bg-green-100 text-green-700 font-bold px-1.5 py-0.5 rounded">{{ item.k }}</span>
                <span class="text-red-500 line-through">{{ item.antes }}</span>
                <i class="pi pi-arrow-right text-gray-300 text-[10px]" />
                <span class="text-green-600 font-medium">{{ item.despues }}</span>
              </div>
            </div>
            <div v-else class="text-xs text-gray-300 italic">Sin cambios registrados</div>
          </div>
        </div>

        <!-- Desktop: tabla -->
        <div class="hidden md:block overflow-x-auto rounded-xl border border-gray-200 shadow-sm">
          <table class="w-full border-collapse text-sm bg-white">
            <thead>
              <tr class="bg-green-50 text-left">
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200 whitespace-nowrap">Fecha</th>
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200">Módulo</th>
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200">Acción</th>
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200">Registro</th>
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200">Evaluador</th>
                <th class="px-3 py-3 font-bold text-xs text-gray-500 uppercase tracking-wide border-b border-gray-200 min-w-[240px]">Cambios</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in lista"
                :key="row.id ?? ''"
                class="border-b border-gray-100 hover:bg-gray-50 transition last:border-0"
              >
                <td class="px-3 py-3 text-xs text-gray-400 whitespace-nowrap">{{ formatFecha(row.created_at) }}</td>
                <td class="px-3 py-3 font-semibold text-gray-700 text-xs">
                  {{ TABLA_LABELS[row.tabla ?? ''] ?? row.tabla ?? '—' }}
                </td>
                <td class="px-3 py-3">
                  <span
                    class="inline-block text-xs font-bold px-2 py-0.5 rounded-full"
                    :class="accionColor(row.accion)"
                  >{{ accionLabel(row.accion) }}</span>
                </td>
                <td class="px-3 py-3 font-mono text-xs text-gray-400">
                  {{ row.registro_id ? (row.registro_id ?? '').slice(0, 8) + '…' : '—' }}
                </td>
                <td class="px-3 py-3 text-xs text-gray-600">{{ row.evaluador_nombre ?? '—' }}</td>
                <td class="px-3 py-3">
                  <template v-if="getFilaCambios(row).length">
                    <div
                      v-for="item in getFilaCambios(row)"
                      :key="item.k"
                      class="flex flex-wrap items-center gap-1.5 mb-1 text-xs last:mb-0"
                    >
                      <span class="bg-green-100 text-green-700 font-bold px-1.5 py-0.5 rounded">{{ item.k }}</span>
                      <span class="text-red-500 line-through">{{ item.antes }}</span>
                      <i class="pi pi-arrow-right text-gray-300 text-[10px]" />
                      <span class="text-green-600 font-medium">{{ item.despues }}</span>
                    </div>
                  </template>
                  <span v-else class="text-gray-300 text-xs">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>

    <!-- Modal de ayuda -->
    <Teleport to="body">
      <div
        v-if="mostrarAyuda"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="mostrarAyuda = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[80vh] overflow-y-auto">
          <!-- Handle (mobile) -->
          <div class="flex justify-center pt-3 sm:hidden">
            <div class="w-10 h-1 rounded-full bg-gray-200" />
          </div>
          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-history text-green-600 text-sm" />
              </div>
              <h2 class="font-bold text-gray-800">Auditoría — ¿cómo funciona?</h2>
            </div>
            <button
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-400"
              @click="mostrarAyuda = false"
            >
              <i class="pi pi-times text-sm" />
            </button>
          </div>
          <!-- Contenido -->
          <div class="px-5 py-4 space-y-4 text-sm text-gray-700">
            <div>
              <p class="font-semibold text-gray-800 mb-1">
                <i class="pi pi-eye mr-1.5 text-green-600" />¿Qué es el historial de auditoría?
              </p>
              <p class="text-gray-600 text-xs leading-relaxed">
                Registra automáticamente cada vez que alguien crea, edita o elimina datos en el sistema.
                Sirve para detectar errores, cambios no autorizados o alteraciones de puntajes (demérito D5).
              </p>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-1">
                <i class="pi pi-filter mr-1.5 text-green-600" />Cómo usar los filtros
              </p>
              <ul class="text-xs text-gray-600 space-y-1 list-disc list-inside leading-relaxed">
                <li><strong>Módulo:</strong> filtra por área del sistema (observaciones, incidencias, etc.).</li>
                <li><strong>Tipo de acción:</strong> Creación, Edición o Eliminación.</li>
                <li><strong>Desde / Hasta:</strong> acota el rango de fechas.</li>
                <li>Se muestran hasta 500 registros ordenados del más reciente al más antiguo.</li>
              </ul>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-1">
                <i class="pi pi-list mr-1.5 text-green-600" />Columna de cambios
              </p>
              <p class="text-xs text-gray-600 leading-relaxed">
                En las ediciones se muestra qué campo cambió:
                el valor <span class="text-red-500 line-through">anterior</span> tachado en rojo
                y el <span class="text-green-600 font-medium">nuevo</span> en verde.
              </p>
            </div>
          </div>
          <div class="px-5 pb-5">
            <button
              class="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm transition"
              @click="mostrarAyuda = false"
            >Entendido</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
