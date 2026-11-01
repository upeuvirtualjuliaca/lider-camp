<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { tiposCalculoService, type TipoCalculo } from '@/modules/criterios/services/criterios.service'
import { useSessionStore } from '@/modules/auth/store'

// ── Estado ────────────────────────────────────────────────────────────────────
const session  = useSessionStore()
const tipos    = ref<TipoCalculo[]>([])
const cargando = ref(true)
const error    = ref('')

// ── Dialog crear / editar ─────────────────────────────────────────────────────
const dialogForm  = ref(false)
const esEdicion   = ref(false)
const guardando   = ref(false)
const errorGuardado = ref('')

const form = ref({
  clave:       '',
  nombre:      '',
  descripcion: '',
  formula:     '',
  orden:       0,
})

// ── Dialog eliminar ───────────────────────────────────────────────────────────
const dialogEliminar = ref(false)
const eliminando     = ref(false)
const errorEliminar  = ref('')
const tipoAEliminar  = ref<TipoCalculo | null>(null)

const dialogAyuda = ref(false)

// ── Helpers ───────────────────────────────────────────────────────────────────
function claveDesdeNombre(nombre: string): string {
  return nombre
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
}

// ── Carga ─────────────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    tipos.value = await tiposCalculoService.getTodos()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)

// ── Abrir modales ─────────────────────────────────────────────────────────────
function abrirNuevo() {
  esEdicion.value = false
  form.value = { clave: '', nombre: '', descripcion: '', formula: '', orden: tipos.value.length + 1 }
  errorGuardado.value = ''
  dialogForm.value = true
}

function abrirEditar(t: TipoCalculo) {
  esEdicion.value = true
  form.value = {
    clave:       t.clave,
    nombre:      t.nombre,
    descripcion: t.descripcion ?? '',
    formula:     t.formula ?? '',
    orden:       t.orden,
  }
  errorGuardado.value = ''
  dialogForm.value = true
}

function abrirEliminar(t: TipoCalculo) {
  tipoAEliminar.value = t
  errorEliminar.value = ''
  dialogEliminar.value = true
}

// ── CRUD ──────────────────────────────────────────────────────────────────────
async function guardar() {
  if (!form.value.nombre.trim()) {
    errorGuardado.value = 'El nombre es obligatorio.'
    return
  }
  guardando.value = true
  errorGuardado.value = ''
  try {
    if (esEdicion.value) {
      const actualizado = await tiposCalculoService.actualizar(form.value.clave, {
        nombre:      form.value.nombre.trim(),
        descripcion: form.value.descripcion.trim() || null,
        formula:     form.value.formula.trim() || null,
        orden:       form.value.orden,
      })
      const idx = tipos.value.findIndex((t) => t.clave === form.value.clave)
      if (idx >= 0) tipos.value[idx] = actualizado
    } else {
      const clave = form.value.clave.trim() || claveDesdeNombre(form.value.nombre)
      const nuevo = await tiposCalculoService.crear({
        clave,
        nombre:      form.value.nombre.trim(),
        descripcion: form.value.descripcion.trim() || null,
        formula:     form.value.formula.trim() || null,
        orden:       form.value.orden,
      })
      tipos.value.push(nuevo)
      tipos.value.sort((a, b) => a.orden - b.orden)
    }
    dialogForm.value = false
  } catch (e: unknown) {
    errorGuardado.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

async function confirmarEliminar() {
  if (!tipoAEliminar.value) return
  eliminando.value = true
  errorEliminar.value = ''
  try {
    await tiposCalculoService.eliminar(tipoAEliminar.value.clave)
    tipos.value = tipos.value.filter((t) => t.clave !== tipoAEliminar.value!.clave)
    dialogEliminar.value = false
  } catch (e: unknown) {
    // FK RESTRICT: hay criterios usando este tipo
    const msg = e instanceof Error ? e.message : ''
    errorEliminar.value = msg.includes('violat') || msg.includes('restrict') || msg.includes('foreign')
      ? 'No se puede eliminar: hay criterios que usan este tipo de cálculo. Cámbialo primero en Criterios.'
      : msg || 'Error al eliminar'
  } finally {
    eliminando.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl mx-auto px-3 py-4 sm:px-6">

    <!-- ── Header ─────────────────────────────────────────────────────────── -->
    <div class="flex items-start justify-between gap-3 mb-5">
      <div>
        <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Tipos de cálculo</h1>
        <p class="mt-1 text-sm text-slate-500">Define cómo se calcula el puntaje de cada tipo de criterio</p>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <button
          class="w-9 h-9 flex items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 hover:text-green-600 hover:border-green-300 shadow-sm transition-colors"
          title="¿Cómo funciona este módulo?"
          @click="dialogAyuda = true"
        >
          <i class="pi pi-question-circle text-base" />
        </button>
        <button
          v-if="session.esAdmin"
          class="inline-flex items-center gap-2 px-4 h-10 bg-green-600 hover:bg-green-700 text-white font-semibold text-sm rounded-xl shadow-sm transition-colors"
          @click="abrirNuevo"
        >
          <i class="pi pi-plus text-xs" />
          Nuevo tipo
        </button>
      </div>
    </div>

    <!-- ── Cargando ───────────────────────────────────────────────────────── -->
    <div v-if="cargando" class="flex justify-center py-14">
      <svg class="animate-spin h-8 w-8 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
    </div>

    <!-- ── Error ──────────────────────────────────────────────────────────── -->
    <div v-else-if="error" class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
      <i class="pi pi-exclamation-circle flex-shrink-0" />
      {{ error }}
    </div>

    <!-- ── Lista de tipos ─────────────────────────────────────────────────── -->
    <div v-else class="flex flex-col gap-3">

      <!-- Estado vacío -->
      <div v-if="!tipos.length" class="flex flex-col items-center justify-center py-14 gap-3 text-center">
        <i class="pi pi-calculator text-4xl text-gray-300" />
        <p class="text-base font-semibold text-gray-500 m-0">Sin tipos de cálculo</p>
        <p class="text-sm text-gray-400 m-0">Crea el primer tipo usando el botón de arriba.</p>
      </div>

      <!-- Tarjeta por tipo -->
      <div
        v-for="tipo in tipos"
        :key="tipo.clave"
        class="bg-white border border-gray-200 rounded-2xl shadow-sm overflow-hidden"
      >
        <!-- Cuerpo -->
        <div class="px-4 py-4 flex items-start gap-3">
          <!-- Icono / orden -->
          <div class="w-9 h-9 rounded-xl bg-green-100 flex items-center justify-center flex-shrink-0 mt-0.5">
            <span class="text-xs font-bold text-green-700">{{ tipo.orden }}</span>
          </div>

          <div class="flex-1 min-w-0">
            <!-- Nombre + clave -->
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-gray-900">{{ tipo.nombre }}</span>
              <span class="text-xs font-mono bg-gray-100 text-gray-500 rounded-lg px-2 py-0.5">{{ tipo.clave }}</span>
            </div>

            <!-- Descripción -->
            <p v-if="tipo.descripcion" class="text-xs text-gray-500 mt-1 leading-relaxed">
              {{ tipo.descripcion }}
            </p>

            <!-- Fórmula / regla -->
            <div v-if="tipo.formula" class="mt-2">
              <span class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Regla</span>
              <code class="block mt-1 text-xs font-mono bg-slate-50 border border-slate-200 text-slate-700 rounded-lg px-3 py-2 leading-relaxed">
                {{ tipo.formula }}
              </code>
            </div>
          </div>

          <!-- Acciones (admin) -->
          <div v-if="session.esAdmin" class="flex gap-1.5 flex-shrink-0">
            <button
              class="w-9 h-9 flex items-center justify-center rounded-xl border border-gray-200 text-gray-400 hover:border-green-300 hover:text-green-600 hover:bg-green-50 transition"
              title="Editar"
              @click="abrirEditar(tipo)"
            >
              <i class="pi pi-pencil text-xs" />
            </button>
            <button
              class="w-9 h-9 flex items-center justify-center rounded-xl border border-gray-200 text-gray-400 hover:border-red-300 hover:text-red-500 hover:bg-red-50 transition"
              title="Eliminar"
              @click="abrirEliminar(tipo)"
            >
              <i class="pi pi-trash text-xs" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Modal crear / editar ───────────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogForm"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogForm = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[92dvh] overflow-y-auto">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 bg-gray-200 rounded-full" /></div>

          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <h2 class="text-base font-bold text-gray-800 m-0">
              {{ esEdicion ? 'Editar tipo de cálculo' : 'Nuevo tipo de cálculo' }}
            </h2>
            <button class="w-8 h-8 flex items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 transition" @click="dialogForm = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Campos -->
          <div class="flex flex-col gap-4 px-5 py-5">

            <!-- Nombre -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Nombre *</label>
              <input
                v-model="form.nombre"
                type="text"
                placeholder="Ej: Rúbrica"
                class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[48px] bg-gray-50 focus:bg-white transition"
              />
            </div>

            <!-- Clave (solo en creación) -->
            <div v-if="!esEdicion" class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">
                Clave <span class="text-gray-400 normal-case font-normal">(se genera automáticamente)</span>
              </label>
              <input
                v-model="form.clave"
                type="text"
                :placeholder="form.nombre ? claveDesdeNombre(form.nombre) : 'clave_unica'"
                class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm font-mono focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[48px] bg-gray-50 focus:bg-white transition"
              />
              <p class="text-xs text-gray-400">Identificador único en minúsculas. No se puede cambiar después.</p>
            </div>

            <!-- Descripción -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">
                Descripción <span class="text-gray-400 normal-case font-normal">(opcional)</span>
              </label>
              <textarea
                v-model="form.descripcion"
                rows="2"
                placeholder="Explica brevemente qué mide este tipo..."
                class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none"
              />
            </div>

            <!-- Fórmula / Regla -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">
                Fórmula / Regla <span class="text-gray-400 normal-case font-normal">(opcional)</span>
              </label>
              <textarea
                v-model="form.formula"
                rows="2"
                placeholder="Ej: min(100, presentes / convocados / 0.95 × 100)"
                class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm font-mono focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none"
              />
            </div>

            <!-- Orden -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Orden</label>
              <input
                v-model.number="form.orden"
                type="number"
                min="1"
                class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[48px] bg-gray-50 focus:bg-white transition"
              />
            </div>

            <!-- Error -->
            <div v-if="errorGuardado" class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-3 py-2.5 text-xs">
              <i class="pi pi-exclamation-circle flex-shrink-0" />
              {{ errorGuardado }}
            </div>
          </div>

          <!-- Footer -->
          <div class="flex gap-2 px-5 pb-5">
            <button
              class="flex-1 py-3 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 min-h-[48px] transition"
              @click="dialogForm = false"
            >
              Cancelar
            </button>
            <button
              class="flex-1 flex items-center justify-center gap-1.5 py-3 bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white rounded-xl font-semibold text-sm min-h-[48px] transition"
              :disabled="!form.nombre.trim() || guardando"
              @click="guardar"
            >
              <svg v-if="guardando" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <i v-else class="pi pi-check text-xs" />
              {{ esEdicion ? 'Guardar cambios' : 'Crear tipo' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal confirmar eliminar ───────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogEliminar"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogEliminar = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-sm mt-auto sm:mt-0">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 bg-gray-200 rounded-full" /></div>

          <div class="px-5 py-5 flex flex-col gap-3">
            <!-- Ícono de advertencia -->
            <div class="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto">
              <i class="pi pi-trash text-red-500 text-xl" />
            </div>
            <h2 class="text-base font-bold text-gray-800 text-center m-0">Eliminar tipo de cálculo</h2>
            <p class="text-sm text-gray-600 text-center m-0">
              ¿Eliminar <strong>{{ tipoAEliminar?.nombre }}</strong>?
              Los criterios que lo usan quedarán sin tipo asignado.
            </p>

            <div v-if="errorEliminar" class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-3 py-2.5 text-xs">
              <i class="pi pi-exclamation-circle flex-shrink-0 mt-0.5" />
              {{ errorEliminar }}
            </div>

            <div class="flex gap-2 mt-1">
              <button
                class="flex-1 py-3 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 min-h-[48px] transition"
                @click="dialogEliminar = false"
              >
                Cancelar
              </button>
              <button
                class="flex-1 flex items-center justify-center gap-1.5 py-3 bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white rounded-xl font-semibold text-sm min-h-[48px] transition"
                :disabled="eliminando"
                @click="confirmarEliminar"
              >
                <svg v-if="eliminando" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                <i v-else class="pi pi-trash text-xs" />
                Eliminar
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal ayuda ────────────────────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogAyuda"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogAyuda = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[80vh] overflow-y-auto">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>

          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-calculator text-green-600 text-sm" />
              </div>
              <h2 class="font-bold text-gray-800">Tipos de cálculo — ¿cómo funciona?</h2>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-400" @click="dialogAyuda = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <div class="px-5 py-4 space-y-3 text-sm text-gray-700">
            <p class="text-xs text-gray-600 leading-relaxed">
              Cada criterio tiene un <strong>tipo de cálculo</strong> que define cómo se genera su puntaje. Aquí puedes crear, editar y eliminar esos tipos, y documentar su fórmula o regla.
            </p>
            <ul class="text-xs text-gray-600 space-y-2">
              <li><strong>Clave</strong> — identificador único (no se puede cambiar). Se usa internamente.</li>
              <li><strong>Nombre</strong> — etiqueta visible en toda la app.</li>
              <li><strong>Descripción</strong> — explica qué mide este tipo.</li>
              <li><strong>Fórmula / Regla</strong> — documenta cómo se calcula el puntaje.</li>
              <li><strong>Orden</strong> — posición en la lista.</li>
            </ul>
            <div class="bg-amber-50 border border-amber-200 rounded-xl px-3 py-2.5 text-xs text-amber-800">
              <i class="pi pi-info-circle mr-1.5" />
              No puedes eliminar un tipo mientras existan criterios que lo usen. Cámbialo primero desde <strong>Criterios</strong>.
            </div>
          </div>

          <div class="px-5 pb-5">
            <button class="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm transition" @click="dialogAyuda = false">
              Entendido
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>
