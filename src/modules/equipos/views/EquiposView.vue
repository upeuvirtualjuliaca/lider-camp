<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { equiposService, type Equipo, type InscripcionEquipo } from '@/modules/equipos/services/equipos.service'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import EquipoFormDialog from '@/modules/equipos/components/EquipoFormDialog.vue'

const router  = useRouter()
const toast   = useToast()
const session = useSessionStore()
const campStore = useCampamentoStore()

const equipos       = ref<Equipo[]>([])
const inscripciones = ref<Map<string, InscripcionEquipo>>(new Map())
const cargando      = ref(true)
const dialogVisible = ref(false)
const equipoEditando = ref<Equipo | null>(null)
const busqueda = ref('')

const equiposFiltrados = computed(() => {
  const q = busqueda.value.toLowerCase().trim()
  if (!q) return equipos.value
  return equipos.value.filter((e) =>
    e.nombre.toLowerCase().includes(q) ||
    e.escuela_profesional.toLowerCase().includes(q),
  )
})

function insc(id: string): InscripcionEquipo | undefined {
  return inscripciones.value.get(id)
}

async function cargar() {
  cargando.value = true
  try {
    const [eqs, ins] = await Promise.all([
      equiposService.getTodos(campStore.selectedId ?? undefined),
      equiposService.getInscripciones(campStore.selectedId ?? undefined),
    ])
    equipos.value = eqs
    inscripciones.value = new Map(ins.map((i) => [i.equipo_id, i]))
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudieron cargar los equipos.', life: 4000 })
  } finally {
    cargando.value = false
  }
}

function abrirNuevo() { equipoEditando.value = null; dialogVisible.value = true }
function abrirEditar(eq: Equipo) { equipoEditando.value = eq; dialogVisible.value = true }

async function guardar(datos: { nombre: string; escuela_profesional: string; color: string }) {
  try {
    if (equipoEditando.value) {
      await equiposService.actualizar(equipoEditando.value.id, datos)
      toast.add({ severity: 'success', summary: 'Actualizado', detail: 'Equipo actualizado.', life: 3000 })
    } else {
      if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
      await equiposService.crear({ ...datos, campamento_id: campStore.selectedId })
      toast.add({ severity: 'success', summary: 'Creado', detail: 'Equipo creado.', life: 3000 })
    }
    dialogVisible.value = false
    await cargar()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo guardar el equipo.', life: 4000 })
  }
}

async function desactivar(eq: Equipo) {
  try {
    await equiposService.actualizar(eq.id, { activo: !eq.activo })
    toast.add({ severity: 'info', summary: 'Actualizado', detail: `Equipo ${eq.activo ? 'desactivado' : 'activado'}.`, life: 3000 })
    await cargar()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cambiar el estado.', life: 4000 })
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)
</script>

<template>
  <div class="max-w-5xl mx-auto px-3 py-4 sm:px-6">

    <!-- ── Cabecera ── -->
    <div class="flex items-center justify-between mb-5">
      <h2 class="flex items-center gap-2 text-xl font-bold text-gray-800 m-0">
        <i class="pi pi-users text-green-600" />
        Equipos
      </h2>
      <button
        v-if="session.esAdmin"
        class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition"
        @click="abrirNuevo"
      >
        <i class="pi pi-plus text-xs" />
        Nuevo equipo
      </button>
    </div>

    <!-- ── Búsqueda ── -->
    <div class="relative mb-4">
      <i class="pi pi-search absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm pointer-events-none" />
      <input
        v-model="busqueda"
        type="text"
        placeholder="Buscar por nombre o escuela profesional..."
        class="w-full border border-gray-200 rounded-lg pl-9 pr-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px]"
      />
    </div>

    <!-- ── Estado de carga ── -->
    <div v-if="cargando" class="flex items-center justify-center py-12 text-gray-400">
      <i class="pi pi-spin pi-spinner text-2xl mr-2" />
      <span class="text-sm">Cargando equipos...</span>
    </div>

    <template v-else>

      <!-- ════════════════════════════════════════════════════════
           TARJETAS MÓVIL  (visible < md)
           ════════════════════════════════════════════════════════ -->
      <div class="flex flex-col gap-3 md:hidden">

        <div
          v-for="eq in equiposFiltrados"
          :key="eq.id"
          class="bg-white border border-gray-200 rounded-xl shadow-sm cursor-pointer hover:shadow-md transition overflow-hidden"
          :style="{ borderLeftColor: eq.color, borderLeftWidth: '4px' }"
          @click="router.push(`/panel/equipos/${eq.id}`)"
        >
          <div class="p-4 flex flex-col gap-3">

            <!-- Nombre + escuela + badge -->
            <div class="flex items-center gap-2.5">
              <span
                class="shrink-0 rounded-full border border-black/10"
                style="width:16px; height:16px; display:inline-block;"
                :style="{ background: eq.color }"
              />
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-sm text-gray-800 truncate m-0">{{ eq.nombre }}</p>
                <p class="text-xs text-gray-500 truncate m-0">{{ eq.escuela_profesional }}</p>
              </div>
              <span
                class="text-xs font-bold px-2 py-0.5 rounded-full shrink-0"
                :class="eq.activo
                  ? 'bg-green-100 text-green-700'
                  : 'bg-gray-100 text-gray-500'"
              >
                {{ eq.activo ? 'Activo' : 'Inactivo' }}
              </span>
            </div>

            <!-- Stats -->
            <div class="flex gap-1 flex-wrap">
              <div class="flex flex-col items-center flex-1 min-w-[3rem]">
                <span class="text-base font-bold text-gray-700">{{ insc(eq.id)?.nomina ?? '—' }}</span>
                <span class="text-xs text-gray-400">Nómina</span>
              </div>
              <div class="flex flex-col items-center flex-1 min-w-[3rem]">
                <span class="text-base font-bold text-green-600">{{ insc(eq.id)?.inscritos_completos ?? '—' }}</span>
                <span class="text-xs text-gray-400">Completos</span>
              </div>
              <div class="flex flex-col items-center flex-1 min-w-[3rem]">
                <span class="text-base font-bold text-yellow-600">{{ insc(eq.id)?.inscritos_parciales ?? '—' }}</span>
                <span class="text-xs text-gray-400">Parciales</span>
              </div>
              <div class="flex flex-col items-center flex-1 min-w-[3rem]">
                <span class="text-base font-bold text-red-600">{{ insc(eq.id)?.inscritos_tardios ?? '—' }}</span>
                <span class="text-xs text-gray-400">Tardíos</span>
              </div>
              <div class="flex flex-col items-center flex-1 min-w-[3.5rem] border-l border-green-100 pl-1">
                <span class="text-base font-bold text-green-700">
                  {{ Number(insc(eq.id)?.puntaje_inscripcion ?? 0).toFixed(2) }}
                </span>
                <span class="text-xs text-gray-400">pts</span>
              </div>
            </div>

            <!-- Acciones (admin) -->
            <div
              v-if="session.esAdmin"
              class="flex gap-2 justify-end"
              @click.stop
            >
              <button
                class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 hover:text-green-600 transition"
                title="Editar equipo"
                @click="abrirEditar(eq)"
              >
                <i class="pi pi-pencil text-sm" />
              </button>
              <button
                class="w-9 h-9 flex items-center justify-center rounded-lg border transition"
                :class="eq.activo
                  ? 'border-orange-200 text-orange-500 hover:bg-orange-50'
                  : 'border-green-200 text-green-600 hover:bg-green-50'"
                :title="eq.activo ? 'Desactivar equipo' : 'Activar equipo'"
                @click="desactivar(eq)"
              >
                <i :class="eq.activo ? 'pi pi-ban text-sm' : 'pi pi-check text-sm'" />
              </button>
            </div>

          </div>
        </div>

        <!-- Sin resultados -->
        <p
          v-if="equiposFiltrados.length === 0"
          class="text-center text-gray-400 text-sm py-10"
        >
          No se encontraron equipos.
        </p>
      </div>

      <!-- ════════════════════════════════════════════════════════
           TABLA ESCRITORIO  (visible ≥ md)
           ════════════════════════════════════════════════════════ -->
      <div class="hidden md:block bg-white border border-gray-200 rounded-xl shadow-sm overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-green-600 text-white text-left">
              <th class="px-3 py-3 font-semibold w-10"></th>
              <th class="px-3 py-3 font-semibold">Equipo</th>
              <th class="px-3 py-3 font-semibold">Escuela</th>
              <th class="px-3 py-3 font-semibold text-center">Nómina</th>
              <th class="px-3 py-3 font-semibold text-center hidden lg:table-cell">Completos</th>
              <th class="px-3 py-3 font-semibold text-center hidden lg:table-cell">Parciales</th>
              <th class="px-3 py-3 font-semibold text-center hidden lg:table-cell">Tardíos</th>
              <th class="px-3 py-3 font-semibold text-center">Puntaje</th>
              <th class="px-3 py-3 font-semibold text-center">Estado</th>
              <th class="px-3 py-3 font-semibold text-center">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(eq, idx) in equiposFiltrados"
              :key="eq.id"
              class="border-t border-gray-100 hover:bg-green-50/40 transition cursor-pointer"
              :class="idx % 2 === 1 ? 'bg-gray-50/50' : 'bg-white'"
              @click="router.push(`/panel/equipos/${eq.id}`)"
            >
              <!-- Color dot -->
              <td class="px-3 py-3 text-center">
                <span
                  class="inline-block rounded-full border border-black/10"
                  style="width:16px; height:16px;"
                  :style="{ background: eq.color }"
                />
              </td>

              <!-- Nombre -->
              <td class="px-3 py-3 font-semibold text-gray-800">{{ eq.nombre }}</td>

              <!-- Escuela -->
              <td class="px-3 py-3 text-gray-600">{{ eq.escuela_profesional }}</td>

              <!-- Nómina -->
              <td class="px-3 py-3 text-center text-gray-700 font-medium">
                {{ insc(eq.id)?.nomina ?? '—' }}
              </td>

              <!-- Completos -->
              <td class="px-3 py-3 text-center font-semibold text-green-600 hidden lg:table-cell">
                {{ insc(eq.id)?.inscritos_completos ?? '—' }}
              </td>

              <!-- Parciales -->
              <td class="px-3 py-3 text-center font-semibold text-yellow-600 hidden lg:table-cell">
                {{ insc(eq.id)?.inscritos_parciales ?? '—' }}
              </td>

              <!-- Tardíos -->
              <td class="px-3 py-3 text-center font-semibold text-red-600 hidden lg:table-cell">
                {{ insc(eq.id)?.inscritos_tardios ?? '—' }}
              </td>

              <!-- Puntaje -->
              <td class="px-3 py-3 text-center font-bold text-green-700">
                {{ Number(insc(eq.id)?.puntaje_inscripcion ?? 0).toFixed(2) }}
                <span class="text-xs font-normal text-gray-400 ml-0.5">pts</span>
              </td>

              <!-- Estado -->
              <td class="px-3 py-3 text-center">
                <span
                  class="text-xs font-bold px-2 py-0.5 rounded-full"
                  :class="eq.activo
                    ? 'bg-green-100 text-green-700'
                    : 'bg-gray-100 text-gray-500'"
                >
                  {{ eq.activo ? 'Activo' : 'Inactivo' }}
                </span>
              </td>

              <!-- Acciones -->
              <td class="px-3 py-3 text-center" @click.stop>
                <div class="flex items-center justify-center gap-1">
                  <button
                    class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 hover:text-green-600 transition"
                    title="Ver equipo"
                    @click="router.push(`/panel/equipos/${eq.id}`)"
                  >
                    <i class="pi pi-eye text-sm" />
                  </button>
                  <template v-if="session.esAdmin">
                    <button
                      class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 hover:text-green-600 transition"
                      title="Editar equipo"
                      @click="abrirEditar(eq)"
                    >
                      <i class="pi pi-pencil text-sm" />
                    </button>
                    <button
                      class="w-9 h-9 flex items-center justify-center rounded-lg border transition"
                      :class="eq.activo
                        ? 'border-orange-200 text-orange-500 hover:bg-orange-50'
                        : 'border-green-200 text-green-600 hover:bg-green-50'"
                      :title="eq.activo ? 'Desactivar equipo' : 'Activar equipo'"
                      @click="desactivar(eq)"
                    >
                      <i :class="eq.activo ? 'pi pi-ban text-sm' : 'pi pi-check text-sm'" />
                    </button>
                  </template>
                </div>
              </td>
            </tr>

            <!-- Sin resultados -->
            <tr v-if="equiposFiltrados.length === 0">
              <td colspan="10" class="px-3 py-10 text-center text-gray-400 text-sm">
                No se encontraron equipos.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

    </template>

    <EquipoFormDialog
      v-model:visible="dialogVisible"
      :equipo="equipoEditando"
      @guardar="guardar"
    />
  </div>
</template>
