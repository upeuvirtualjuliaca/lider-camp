<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useToast } from 'primevue/usetoast'
import {
  campamentoService,
  diasCampamentoService,
  type Campamento,
  type DiaCampamento,
} from '@/modules/equipos/services/campamento.service'

const toast = useToast()

// ── Estado general ─────────────────────────────────────────────────────────────
const cargando    = ref(true)
const campamentos = ref<Campamento[]>([])

// Vista: 'lista' | 'detalle'
const vista     = ref<'lista' | 'detalle'>('lista')
const campSelec = ref<Campamento | null>(null)
const dias      = ref<DiaCampamento[]>([])
const cargandoDias = ref(false)

// ── Formulario campamento ──────────────────────────────────────────────────────
const guardando = ref(false)
const modoNuevo = ref(false)

const form = ref({
  nombre:  '',
  edicion: '',
  fecha_limite_inscripcion_completa: '',
  fecha_limite_inscripcion_parcial:  '',
})

const errForm = ref('')

function validarForm(): string {
  if (!form.value.nombre.trim())  return 'El nombre es obligatorio.'
  if (!form.value.edicion.trim()) return 'La edición es obligatoria.'
  if (!form.value.fecha_limite_inscripcion_completa) return 'La fecha límite completa es obligatoria.'
  if (!form.value.fecha_limite_inscripcion_parcial)  return 'La fecha límite parcial es obligatoria.'
  if (form.value.fecha_limite_inscripcion_completa > form.value.fecha_limite_inscripcion_parcial)
    return 'La fecha límite completa no puede ser posterior a la parcial.'
  return ''
}

// ── Formulario día ─────────────────────────────────────────────────────────────
const diaEditar       = ref<DiaCampamento | null>(null)
const panelDiaVisible = ref(false)
const guardandoDia    = ref(false)
const formDia = ref({ fecha: '', codigo: '', nombre: '' })
const errDia  = ref('')

// ── Confirmaciones ─────────────────────────────────────────────────────────────
const confirmElimCamp = ref<Campamento | null>(null)
const confirmElimDia  = ref<DiaCampamento | null>(null)

// ── Helpers ────────────────────────────────────────────────────────────────────
const DIAS_SEMANA: Record<number, { codigo: string; nombre: string }> = {
  0: { codigo: 'D', nombre: 'Domingo' },
  1: { codigo: 'L', nombre: 'Lunes' },
  2: { codigo: 'M', nombre: 'Martes' },
  3: { codigo: 'X', nombre: 'Miércoles' },
  4: { codigo: 'J', nombre: 'Jueves' },
  5: { codigo: 'V', nombre: 'Viernes' },
  6: { codigo: 'S', nombre: 'Sábado' },
}

function onFechaDiaChange() {
  if (!formDia.value.fecha) return
  const d = new Date(formDia.value.fecha + 'T12:00:00')
  const s = DIAS_SEMANA[d.getDay()]
  if (s) { formDia.value.codigo = s.codigo; formDia.value.nombre = s.nombre }
}

function formatFecha(iso: string): string {
  if (!iso) return '—'
  return new Date(iso + 'T12:00:00').toLocaleDateString('es', {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
  })
}

function formatFechaCorta(iso: string): string {
  if (!iso) return '—'
  return new Date(iso + 'T12:00:00').toLocaleDateString('es', {
    day: 'numeric', month: 'short', year: 'numeric',
  })
}

const ordenSiguiente = computed(() =>
  dias.value.length ? Math.max(...dias.value.map((d) => d.orden)) + 1 : 1,
)

// ── Carga ──────────────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  try {
    campamentos.value = await campamentoService.getAll()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cargar.', life: 4000 })
  } finally {
    cargando.value = false
  }
}

async function cargarDias(id: string) {
  cargandoDias.value = true
  try {
    dias.value = await diasCampamentoService.getPorCampamento(id)
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudieron cargar los días.', life: 4000 })
  } finally {
    cargandoDias.value = false
  }
}

// ── Navegación master-detail ───────────────────────────────────────────────────
function abrirDetalle(camp: Campamento) {
  campSelec.value = camp
  form.value = {
    nombre:  camp.nombre,
    edicion: camp.edicion,
    fecha_limite_inscripcion_completa: camp.fecha_limite_inscripcion_completa ?? '',
    fecha_limite_inscripcion_parcial:  camp.fecha_limite_inscripcion_parcial  ?? '',
  }
  modoNuevo.value = false
  errForm.value   = ''
  panelDiaVisible.value = false
  vista.value     = 'detalle'
  cargarDias(camp.id)
}

function abrirNuevo() {
  campSelec.value = null
  form.value      = { nombre: '', edicion: '', fecha_limite_inscripcion_completa: '', fecha_limite_inscripcion_parcial: '' }
  modoNuevo.value = true
  errForm.value   = ''
  dias.value      = []
  panelDiaVisible.value = false
  vista.value     = 'detalle'
}

function volverLista() {
  vista.value     = 'lista'
  campSelec.value = null
  cargar()
}

// ── CRUD campamento ────────────────────────────────────────────────────────────
async function guardarCampamento() {
  errForm.value = validarForm()
  if (errForm.value) return

  guardando.value = true
  try {
    if (modoNuevo.value) {
      const nuevo = await campamentoService.crear({
        nombre:  form.value.nombre.trim(),
        edicion: form.value.edicion.trim(),
        fecha_limite_inscripcion_completa: form.value.fecha_limite_inscripcion_completa,
        fecha_limite_inscripcion_parcial:  form.value.fecha_limite_inscripcion_parcial,
      })
      campSelec.value = nuevo
      modoNuevo.value = false
      toast.add({ severity: 'success', summary: 'Creado', detail: 'Campamento creado correctamente.', life: 3000 })
    } else {
      const updated = await campamentoService.actualizar(campSelec.value!.id, {
        nombre:  form.value.nombre.trim(),
        edicion: form.value.edicion.trim(),
        fecha_limite_inscripcion_completa: form.value.fecha_limite_inscripcion_completa,
        fecha_limite_inscripcion_parcial:  form.value.fecha_limite_inscripcion_parcial,
      })
      campSelec.value = updated
      toast.add({ severity: 'success', summary: 'Guardado', detail: 'Cambios guardados.', life: 3000 })
    }
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message ?? 'No se pudo guardar.', life: 4000 })
  } finally {
    guardando.value = false
  }
}

async function activarCampamento(camp: Campamento) {
  try {
    await campamentoService.setActivo(camp.id)
    await cargar()
    if (campSelec.value?.id === camp.id) {
      campSelec.value = { ...campSelec.value, activo: true }
    }
    toast.add({ severity: 'success', summary: 'Activo', detail: `"${camp.nombre}" es ahora el campamento activo.`, life: 3000 })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message ?? 'No se pudo activar.', life: 4000 })
  }
}

async function eliminarCampamento() {
  if (!confirmElimCamp.value) return
  try {
    await campamentoService.eliminar(confirmElimCamp.value.id)
    confirmElimCamp.value = null
    volverLista()
    toast.add({ severity: 'success', summary: 'Eliminado', detail: 'Campamento eliminado.', life: 3000 })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message ?? 'No se pudo eliminar.', life: 4000 })
    confirmElimCamp.value = null
  }
}

// ── CRUD días ──────────────────────────────────────────────────────────────────
function abrirNuevoDia() {
  if (!campSelec.value) return
  diaEditar.value = null
  formDia.value   = { fecha: '', codigo: '', nombre: '' }
  errDia.value    = ''
  panelDiaVisible.value = true
}

function abrirEditarDia(dia: DiaCampamento) {
  diaEditar.value = dia
  formDia.value   = { fecha: dia.fecha, codigo: dia.codigo, nombre: dia.nombre }
  errDia.value    = ''
  panelDiaVisible.value = true
}

function cerrarPanelDia() {
  panelDiaVisible.value = false
  diaEditar.value = null
}

async function guardarDia() {
  if (!formDia.value.fecha || !formDia.value.codigo.trim() || !formDia.value.nombre.trim()) {
    errDia.value = 'Completa todos los campos.'
    return
  }
  guardandoDia.value = true
  errDia.value = ''
  try {
    const payload = {
      campamento_id: campSelec.value!.id,
      fecha:  formDia.value.fecha,
      codigo: formDia.value.codigo.trim().toUpperCase(),
      nombre: formDia.value.nombre.trim(),
      orden:  diaEditar.value ? diaEditar.value.orden : ordenSiguiente.value,
    }
    if (diaEditar.value) {
      const upd = await diasCampamentoService.actualizar(diaEditar.value.id, payload)
      const idx = dias.value.findIndex((d) => d.id === diaEditar.value!.id)
      if (idx !== -1) dias.value[idx] = upd
    } else {
      dias.value.push(await diasCampamentoService.crear(payload))
    }
    cerrarPanelDia()
    toast.add({ severity: 'success', summary: 'Listo', detail: diaEditar.value ? 'Día actualizado.' : 'Día agregado.', life: 3000 })
  } catch (e: any) {
    errDia.value = e.message ?? 'No se pudo guardar el día.'
  } finally {
    guardandoDia.value = false
  }
}

async function eliminarDia() {
  if (!confirmElimDia.value) return
  try {
    await diasCampamentoService.eliminar(confirmElimDia.value.id)
    dias.value = dias.value.filter((d) => d.id !== confirmElimDia.value!.id)
    confirmElimDia.value = null
    toast.add({ severity: 'success', summary: 'Eliminado', detail: 'Día eliminado.', life: 3000 })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message ?? 'No se pudo eliminar.', life: 4000 })
    confirmElimDia.value = null
  }
}

onMounted(cargar)
</script>

<template>
  <div class="max-w-2xl mx-auto px-3 py-4 sm:px-6 pb-12">

    <!-- ═══════════════ VISTA: LISTA ═══════════════ -->
    <template v-if="vista === 'lista'">

      <div class="flex items-center justify-between mb-5 gap-2">
        <div class="flex items-center gap-2">
          <i class="pi pi-building text-green-700 text-xl" />
          <h1 class="text-lg font-extrabold text-gray-800">Campamentos</h1>
        </div>
        <button
          class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition"
          @click="abrirNuevo"
        >
          <i class="pi pi-plus text-sm" /> Nuevo
        </button>
      </div>

      <!-- Cargando -->
      <div v-if="cargando" class="flex items-center justify-center py-16 gap-3 text-gray-400">
        <i class="pi pi-spin pi-spinner text-2xl text-green-500" />
        <span class="text-sm">Cargando…</span>
      </div>

      <!-- Vacío -->
      <div v-else-if="!campamentos.length" class="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
        <i class="pi pi-calendar-plus text-5xl text-gray-200" />
        <p class="text-sm">No hay campamentos configurados.</p>
        <button
          class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition"
          @click="abrirNuevo"
        >
          Crear el primero
        </button>
      </div>

      <!-- Lista -->
      <div v-else class="flex flex-col gap-3">
        <div
          v-for="c in campamentos"
          :key="c.id"
          class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm cursor-pointer hover:shadow-md hover:border-green-200 transition flex items-start gap-3"
          @click="abrirDetalle(c)"
        >
          <!-- Icono -->
          <div class="w-11 h-11 rounded-xl bg-green-50 flex items-center justify-center flex-shrink-0">
            <i class="pi pi-building text-green-600 text-lg" />
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-gray-800">{{ c.nombre }}</span>
              <span
                v-if="c.activo"
                class="text-xs font-bold px-2 py-0.5 rounded-full bg-green-100 text-green-700"
              >Activo</span>
            </div>
            <p class="text-sm text-gray-500 mt-0.5">{{ c.edicion }}</p>
            <div class="flex flex-wrap gap-x-4 gap-y-0.5 mt-1.5 text-xs text-gray-400">
              <span><i class="pi pi-calendar mr-1" />Completa: {{ formatFechaCorta(c.fecha_limite_inscripcion_completa) }}</span>
              <span><i class="pi pi-calendar mr-1" />Parcial: {{ formatFechaCorta(c.fecha_limite_inscripcion_parcial) }}</span>
            </div>
          </div>

          <i class="pi pi-chevron-right text-gray-300 mt-1 flex-shrink-0" />
        </div>
      </div>
    </template>

    <!-- ═══════════════ VISTA: DETALLE ═══════════════ -->
    <template v-else>

      <!-- Encabezado -->
      <div class="flex items-center gap-3 mb-5">
        <button
          class="w-10 h-10 flex items-center justify-center rounded-xl border border-gray-200 bg-white hover:bg-gray-50 text-gray-500 transition flex-shrink-0"
          @click="volverLista"
        >
          <i class="pi pi-arrow-left text-sm" />
        </button>
        <div class="flex-1 min-w-0">
          <h1 class="text-lg font-extrabold text-gray-800 truncate">
            {{ modoNuevo ? 'Nuevo campamento' : (campSelec?.nombre ?? '') }}
          </h1>
          <p v-if="campSelec?.edicion" class="text-xs text-gray-400">{{ campSelec.edicion }}</p>
        </div>
        <span
          v-if="campSelec?.activo"
          class="text-xs font-bold px-2.5 py-1 rounded-full bg-green-100 text-green-700 flex-shrink-0"
        >Activo</span>
      </div>

      <!-- ── Datos básicos ── -->
      <div class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm mb-3">
        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-4">Información básica</p>

        <div class="flex flex-col gap-3">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Nombre <span class="text-red-400">*</span>
            </label>
            <input
              v-model="form.nombre"
              class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
              placeholder="LiderCamp"
            />
          </div>
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Edición <span class="text-red-400">*</span>
            </label>
            <input
              v-model="form.edicion"
              class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
              placeholder="2026-II"
            />
          </div>
        </div>

        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider mt-5 mb-3">Límites de inscripción</p>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Inscripción completa hasta
              <span class="text-xs font-normal text-gray-400 ml-1">(100 pts)</span>
            </label>
            <input
              v-model="form.fecha_limite_inscripcion_completa"
              type="date"
              class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
            />
          </div>
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Inscripción parcial hasta
              <span class="text-xs font-normal text-gray-400 ml-1">(50 pts)</span>
            </label>
            <input
              v-model="form.fecha_limite_inscripcion_parcial"
              type="date"
              class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
            />
          </div>
        </div>

        <!-- Error -->
        <div v-if="errForm" class="flex items-center gap-2 mt-3 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5 text-red-700 text-sm">
          <i class="pi pi-exclamation-circle flex-shrink-0" />{{ errForm }}
        </div>

        <button
          class="w-full mt-4 flex items-center justify-center gap-2 py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[48px] disabled:opacity-50 transition"
          :disabled="guardando"
          @click="guardarCampamento"
        >
          <i :class="guardando ? 'pi pi-spin pi-spinner' : 'pi pi-save'" />
          {{ guardando ? 'Guardando…' : (modoNuevo ? 'Crear campamento' : 'Guardar cambios') }}
        </button>
      </div>

      <!-- ── Acciones del campamento (solo si ya existe y no está activo) ── -->
      <div v-if="campSelec && !campSelec.activo" class="bg-white border border-gray-200 rounded-xl shadow-sm mb-3 overflow-hidden">
        <!-- Activar -->
        <div class="flex items-center justify-between gap-3 px-4 py-3.5 border-b border-gray-100">
          <div>
            <p class="text-sm font-semibold text-gray-800">Activar este campamento</p>
            <p class="text-xs text-gray-400 mt-0.5">Lo establece como campamento en curso para todos los módulos.</p>
          </div>
          <button
            class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] flex-shrink-0 transition"
            @click="activarCampamento(campSelec)"
          >
            <i class="pi pi-check-circle text-sm" /> Activar
          </button>
        </div>

        <!-- Eliminar -->
        <div class="flex items-center justify-between gap-3 px-4 py-3.5">
          <div>
            <p class="text-sm font-semibold text-red-600">Eliminar campamento</p>
            <p class="text-xs text-gray-400 mt-0.5">Solo campamentos inactivos pueden eliminarse.</p>
          </div>
          <button
            class="flex items-center gap-1.5 px-4 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-xl font-semibold text-sm min-h-[44px] flex-shrink-0 transition"
            @click="confirmElimCamp = campSelec"
          >
            <i class="pi pi-trash text-sm" /> Eliminar
          </button>
        </div>
      </div>

      <!-- ── Días del campamento ── -->
      <div v-if="campSelec && !modoNuevo" class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm mb-3">
        <div class="flex items-center justify-between mb-4">
          <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Días del campamento</p>
          <button
            class="flex items-center gap-1.5 px-3 py-2 bg-green-50 hover:bg-green-100 border border-green-200 text-green-700 rounded-lg font-semibold text-xs min-h-[36px] transition"
            @click="abrirNuevoDia"
          >
            <i class="pi pi-plus text-xs" /> Agregar día
          </button>
        </div>

        <div v-if="cargandoDias" class="flex items-center justify-center py-6 gap-2 text-gray-400 text-sm">
          <i class="pi pi-spin pi-spinner text-green-500" /> Cargando días…
        </div>

        <p v-else-if="!dias.length && !panelDiaVisible" class="text-center text-xs text-gray-400 py-4">
          Sin días configurados. Agrega el primer día.
        </p>

        <div v-else class="flex flex-col gap-2">
          <div
            v-for="dia in dias"
            :key="dia.id"
            class="flex items-center gap-3 bg-gray-50 border border-gray-100 rounded-xl px-3 py-2.5"
          >
            <!-- Badge código -->
            <div class="w-10 h-10 rounded-xl bg-green-600 text-white flex items-center justify-center font-extrabold text-sm flex-shrink-0">
              {{ dia.codigo }}
            </div>
            <!-- Info -->
            <div class="flex-1 min-w-0">
              <p class="font-bold text-sm text-gray-800">{{ dia.nombre }}</p>
              <p class="text-xs text-gray-400">{{ formatFecha(dia.fecha) }}</p>
            </div>
            <!-- Acciones -->
            <div class="flex gap-1.5 flex-shrink-0">
              <button
                class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-200 bg-white hover:bg-gray-100 text-gray-500 transition"
                title="Editar"
                @click.stop="abrirEditarDia(dia)"
              >
                <i class="pi pi-pencil text-xs" />
              </button>
              <button
                class="w-9 h-9 flex items-center justify-center rounded-lg border border-red-100 bg-white hover:bg-red-50 text-red-400 transition"
                title="Eliminar"
                @click.stop="confirmElimDia = dia"
              >
                <i class="pi pi-trash text-xs" />
              </button>
            </div>
          </div>
        </div>

        <!-- Formulario de día (inline) -->
        <div v-if="panelDiaVisible" class="mt-3 border border-green-200 bg-green-50 rounded-xl p-4">
          <p class="text-xs font-bold text-green-700 uppercase tracking-wider mb-3">
            {{ diaEditar ? 'Editar día' : 'Nuevo día' }}
          </p>

          <div class="flex flex-col gap-3">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">Fecha <span class="text-red-400">*</span></label>
              <input
                v-model="formDia.fecha"
                type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-white transition"
                @change="onFechaDiaChange"
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-1">
                  Código <span class="text-red-400">*</span>
                  <span class="text-xs font-normal text-gray-400 ml-1">ej: J, V, S</span>
                </label>
                <input
                  v-model="formDia.codigo"
                  class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-white uppercase transition"
                  placeholder="J"
                  maxlength="5"
                />
              </div>
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-1">Nombre <span class="text-red-400">*</span></label>
                <input
                  v-model="formDia.nombre"
                  class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-white transition"
                  placeholder="Jueves"
                />
              </div>
            </div>
          </div>

          <div v-if="errDia" class="flex items-center gap-2 mt-3 bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-red-700 text-xs">
            <i class="pi pi-exclamation-circle flex-shrink-0" />{{ errDia }}
          </div>

          <div class="flex gap-2 mt-3">
            <button
              class="flex-1 py-2.5 border border-gray-200 bg-white hover:bg-gray-50 text-gray-600 rounded-xl font-semibold text-sm min-h-[44px] transition"
              @click="cerrarPanelDia"
            >Cancelar</button>
            <button
              class="flex-1 flex items-center justify-center gap-2 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] disabled:opacity-50 transition"
              :disabled="guardandoDia"
              @click="guardarDia"
            >
              <i :class="guardandoDia ? 'pi pi-spin pi-spinner' : 'pi pi-check'" />
              {{ guardandoDia ? 'Guardando…' : (diaEditar ? 'Actualizar' : 'Agregar') }}
            </button>
          </div>
        </div>
      </div>

    </template>

    <!-- ═══════════════ CONFIRMACIONES ═══════════════ -->

    <!-- Eliminar campamento -->
    <Teleport to="body">
      <div
        v-if="confirmElimCamp"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="confirmElimCamp = null"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-sm mt-auto sm:mt-0 p-5">
          <div class="flex justify-center pt-1 pb-3 sm:hidden">
            <div class="w-10 h-1 rounded-full bg-gray-200" />
          </div>
          <div class="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-3">
            <i class="pi pi-trash text-red-500 text-xl" />
          </div>
          <p class="text-center font-bold text-gray-800 mb-1">¿Eliminar campamento?</p>
          <p class="text-center text-sm text-gray-500 mb-1">
            Se eliminará <strong>{{ confirmElimCamp.nombre }}</strong>.
          </p>
          <p class="text-center text-xs text-gray-400 mb-5">Esta acción no puede deshacerse.</p>
          <div class="flex gap-2">
            <button
              class="flex-1 py-3 border border-gray-200 bg-white hover:bg-gray-50 text-gray-600 rounded-xl font-semibold text-sm transition"
              @click="confirmElimCamp = null"
            >Cancelar</button>
            <button
              class="flex-1 py-3 bg-red-500 hover:bg-red-600 text-white rounded-xl font-semibold text-sm transition"
              @click="eliminarCampamento"
            >
              <i class="pi pi-trash mr-1" /> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Eliminar día -->
    <Teleport to="body">
      <div
        v-if="confirmElimDia"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="confirmElimDia = null"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-sm mt-auto sm:mt-0 p-5">
          <div class="flex justify-center pt-1 pb-3 sm:hidden">
            <div class="w-10 h-1 rounded-full bg-gray-200" />
          </div>
          <div class="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-3">
            <i class="pi pi-calendar-times text-red-500 text-xl" />
          </div>
          <p class="text-center font-bold text-gray-800 mb-1">¿Eliminar este día?</p>
          <p class="text-center text-sm text-gray-500 mb-1">
            <strong>{{ confirmElimDia.nombre }} ({{ confirmElimDia.codigo }})</strong>
          </p>
          <p class="text-center text-xs text-gray-400 mb-5">No elimina programaciones ni asistencias ya registradas.</p>
          <div class="flex gap-2">
            <button
              class="flex-1 py-3 border border-gray-200 bg-white hover:bg-gray-50 text-gray-600 rounded-xl font-semibold text-sm transition"
              @click="confirmElimDia = null"
            >Cancelar</button>
            <button
              class="flex-1 py-3 bg-red-500 hover:bg-red-600 text-white rounded-xl font-semibold text-sm transition"
              @click="eliminarDia"
            >
              <i class="pi pi-trash mr-1" /> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>
