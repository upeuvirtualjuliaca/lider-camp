<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { solicitudesService, type SolicitudRevision } from '@/modules/auditoria/services/auditoria.service'
import { useSessionStore }    from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const lista    = ref<SolicitudRevision[]>([])
const cargando = ref(true)

// ── Formulario nueva solicitud ────────────────────────────────────────────────
const mostrarForm  = ref(false)
const guardando    = ref(false)
const errGuardar   = ref('')
const formArea     = ref('')
const formDesc     = ref('')

// ── Ayuda ─────────────────────────────────────────────────────────────────────
const mostrarAyuda = ref(false)

// ── Resolver (admin) ──────────────────────────────────────────────────────────
const resolviendo  = ref<string | null>(null)
const respuesta    = ref('')

// ── Filtro de estado ──────────────────────────────────────────────────────────
const filtroEstado = ref<'todas' | 'pendiente' | 'aprobada' | 'rechazada'>('todas')

// Mapa de áreas legibles → tabla técnica
const AREAS = [
  { label: 'Observaciones / Evaluación', tabla: 'observaciones' },
  { label: 'Asistencia',                 tabla: 'asistencia_actividad' },
  { label: 'Liderazgo',                  tabla: 'liderazgo_dia' },
  { label: 'Incidencias / Bonus / Deméritos', tabla: 'incidencias' },
  { label: 'Inscripción de integrantes', tabla: 'integrantes' },
  { label: 'Otro',                       tabla: 'general' },
]

function areaLabel(tabla: string | null) {
  if (!tabla) return 'General'
  return AREAS.find((a) => a.tabla === tabla)?.label ?? tabla
}

// ── Computed ──────────────────────────────────────────────────────────────────
const listaFiltrada = computed(() =>
  filtroEstado.value === 'todas'
    ? lista.value
    : lista.value.filter((s) => s.estado === filtroEstado.value)
)

const cntPendientes = computed(() => lista.value.filter((s) => s.estado === 'pendiente').length)

// ── Cargar ────────────────────────────────────────────────────────────────────
onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargar() {
  cargando.value = true
  try {
    lista.value = session.esAdmin
      ? await solicitudesService.getTodas(campStore.selectedId ?? undefined)
      : await solicitudesService.getMias(campStore.selectedId ?? undefined)
  } finally {
    cargando.value = false
  }
}

// ── Crear solicitud ───────────────────────────────────────────────────────────
function abrirForm() {
  formArea.value    = ''
  formDesc.value    = ''
  errGuardar.value  = ''
  mostrarForm.value = true
}

async function crearSolicitud() {
  if (!formArea.value || !formDesc.value.trim()) {
    errGuardar.value = 'Selecciona el área y describe el problema.'
    return
  }
  guardando.value  = true
  errGuardar.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    await solicitudesService.crear(
      { tabla: formArea.value, descripcion: formDesc.value.trim() },
      campStore.selectedId,
    )
    mostrarForm.value = false
    await cargar()
  } catch (e: unknown) {
    errGuardar.value = e instanceof Error ? e.message : 'Error al enviar'
  } finally {
    guardando.value = false
  }
}

// ── Resolver ──────────────────────────────────────────────────────────────────
function iniciarResolver(id: string) {
  resolviendo.value = id
  respuesta.value   = ''
}

async function confirmar(id: string, decision: 'aprobada' | 'rechazada') {
  try {
    await solicitudesService.resolver(id, decision, respuesta.value || undefined)
    resolviendo.value = null
    await cargar()
  } catch (e: unknown) {
    alert(e instanceof Error ? e.message : 'Error al resolver')
  }
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function formatFecha(ts: string | null) {
  if (!ts) return '—'
  return new Date(ts).toLocaleString('es-PE', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

const ESTADO_CFG = {
  pendiente: { label: 'Pendiente', cls: 'bg-amber-50 text-amber-700 ring-amber-200' },
  aprobada:  { label: 'Aprobada',  cls: 'bg-green-50 text-green-700 ring-green-200' },
  rechazada: { label: 'Rechazada', cls: 'bg-red-50 text-red-700 ring-red-200'       },
}

function estadoCfg(est: string | null) {
  return ESTADO_CFG[est as keyof typeof ESTADO_CFG] ?? ESTADO_CFG.pendiente
}
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6 sm:px-6 sm:py-8">

      <!-- ─── Cabecera ─── -->
      <div class="flex items-start justify-between gap-3 mb-2">
        <div>
          <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Revisiones</h1>
          <p class="mt-1 text-sm text-slate-500">
            {{ session.esAdmin ? 'Gestiona las solicitudes del equipo' : 'Reporta un error para que el admin lo revise' }}
          </p>
        </div>

        <!-- Botones cabecera -->
        <div class="flex items-center gap-2 flex-shrink-0">
          <!-- Botón ayuda -->
          <button
            class="w-9 h-9 flex items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 hover:text-green-600 hover:border-green-300 shadow-sm transition-colors"
            title="¿Cómo funciona este módulo?"
            @click="mostrarAyuda = true"
          >
            <i class="pi pi-question-circle text-base" />
          </button>

          <!-- Botón nueva solicitud (todos los roles) -->
          <button
            class="inline-flex items-center gap-2 px-4 h-10 bg-green-600 hover:bg-green-700 text-white font-semibold text-sm rounded-xl shadow-sm transition-colors"
            @click="abrirForm"
          >
            <i class="pi pi-plus text-xs" />
            Nueva solicitud
          </button>
        </div>
      </div>

      <!-- ─── Banner pendientes (admin) ─── -->
      <div
        v-if="session.esAdmin && cntPendientes > 0"
        class="flex items-center gap-2.5 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 mb-4 text-sm text-amber-800"
      >
        <i class="pi pi-clock text-amber-500" />
        <span>
          Tienes <strong>{{ cntPendientes }}</strong>
          {{ cntPendientes === 1 ? 'solicitud pendiente' : 'solicitudes pendientes' }} por resolver.
        </span>
      </div>

      <!-- ─── Filtros de estado ─── -->
      <div class="flex gap-2 mb-4 flex-wrap">
        <button
          v-for="f in (['todas','pendiente','aprobada','rechazada'] as const)"
          :key="f"
          class="px-3 h-8 rounded-lg text-xs font-semibold border transition-colors"
          :class="filtroEstado === f
            ? 'bg-green-600 text-white border-green-600'
            : 'bg-white text-slate-500 border-slate-200 hover:border-green-300 hover:text-green-700'"
          @click="filtroEstado = f"
        >
          {{ f === 'todas' ? `Todas (${lista.length})` : f.charAt(0).toUpperCase() + f.slice(1) }}
          <span v-if="f === 'pendiente' && cntPendientes > 0" class="ml-1 bg-amber-400 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{{ cntPendientes }}</span>
        </button>
      </div>

      <!-- ─── Cargando ─── -->
      <div v-if="cargando" class="flex items-center justify-center gap-2 py-16 text-slate-400">
        <i class="pi pi-spin pi-spinner" />
        <span class="text-sm">Cargando…</span>
      </div>

      <!-- ─── Sin resultados ─── -->
      <div v-else-if="listaFiltrada.length === 0" class="flex flex-col items-center gap-3 py-16 text-slate-400">
        <div class="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center">
          <i class="pi pi-inbox text-2xl text-slate-300" />
        </div>
        <p class="text-sm">
          {{ lista.length === 0 ? 'No hay solicitudes aún.' : 'No hay solicitudes con este estado.' }}
        </p>
        <button
          v-if="lista.length === 0"
          class="inline-flex items-center gap-2 px-4 h-10 bg-green-600 hover:bg-green-700 text-white font-semibold text-sm rounded-xl transition-colors mt-1"
          @click="abrirForm"
        >
          <i class="pi pi-plus text-xs" />
          Crear primera solicitud
        </button>
      </div>

      <!-- ─── Lista de solicitudes ─── -->
      <div v-else class="flex flex-col gap-3">
        <div
          v-for="s in listaFiltrada"
          :key="s.id"
          class="bg-white rounded-2xl border shadow-sm overflow-hidden transition-all"
          :class="s.estado === 'pendiente' ? 'border-amber-100' : 'border-slate-100'"
        >
          <!-- Franja lateral de color por estado -->
          <div class="flex">
            <div
              class="w-1 flex-shrink-0"
              :class="{
                'bg-amber-400': s.estado === 'pendiente',
                'bg-green-500': s.estado === 'aprobada',
                'bg-red-400':   s.estado === 'rechazada',
              }"
            />

            <div class="flex-1 p-4">

              <!-- Fila superior: área + badge + fecha -->
              <div class="flex items-start justify-between gap-2 mb-2">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-sm font-semibold text-slate-700">{{ areaLabel(s.tabla) }}</span>
                  <span
                    class="inline-flex items-center text-[11px] font-semibold px-2 py-0.5 rounded-full ring-1"
                    :class="estadoCfg(s.estado).cls"
                  >
                    {{ estadoCfg(s.estado).label }}
                  </span>
                </div>
                <span class="text-xs text-slate-400 flex-shrink-0">{{ formatFecha(s.created_at) }}</span>
              </div>

              <!-- Descripción -->
              <p class="text-sm text-slate-600 leading-relaxed">{{ s.descripcion }}</p>

              <!-- Respuesta del admin (si existe) -->
              <div v-if="s.respuesta" class="mt-3 flex items-start gap-2 bg-green-50 border border-green-100 rounded-xl px-3 py-2.5">
                <i class="pi pi-check-circle text-green-500 text-sm mt-0.5 flex-shrink-0" />
                <div>
                  <p class="text-xs font-semibold text-green-700 mb-0.5">Respuesta del administrador</p>
                  <p class="text-xs text-green-800">{{ s.respuesta }}</p>
                </div>
              </div>

              <!-- Panel resolver — solo admin en pendientes -->
              <div v-if="session.esAdmin && s.estado === 'pendiente'" class="mt-3 border-t border-slate-50 pt-3">

                <template v-if="resolviendo === s.id">
                  <textarea
                    v-model="respuesta"
                    rows="2"
                    placeholder="Comentario de resolución (opcional)…"
                    class="w-full px-3 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition mb-2"
                  />
                  <div class="flex gap-2 justify-end">
                    <button
                      class="px-4 h-9 rounded-lg border border-slate-200 text-slate-500 text-sm font-semibold hover:bg-slate-50 transition-colors"
                      @click="resolviendo = null"
                    >
                      Cancelar
                    </button>
                    <button
                      class="px-4 h-9 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-semibold flex items-center gap-1.5 transition-colors"
                      @click="confirmar(s.id, 'rechazada')"
                    >
                      <i class="pi pi-times text-xs" /> Rechazar
                    </button>
                    <button
                      class="px-4 h-9 rounded-lg bg-green-600 hover:bg-green-700 text-white text-sm font-semibold flex items-center gap-1.5 transition-colors"
                      @click="confirmar(s.id, 'aprobada')"
                    >
                      <i class="pi pi-check text-xs" /> Aprobar
                    </button>
                  </div>
                </template>

                <button
                  v-else
                  class="w-full h-9 rounded-xl border border-dashed border-slate-300 text-slate-500 text-sm font-semibold hover:border-green-400 hover:text-green-600 hover:bg-green-50 transition-all"
                  @click="iniciarResolver(s.id)"
                >
                  Resolver esta solicitud
                </button>
              </div>

            </div>
          </div>
        </div>
      </div>

    </div><!-- /max-w -->

    <!-- ══════════════════════════════════════════════════════
         MODAL: Nueva solicitud
    ═══════════════════════════════════════════════════════ -->
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div v-if="mostrarForm" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:p-4">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="mostrarForm = false" />

        <div class="relative w-full sm:max-w-lg bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90dvh]">

          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
            <div>
              <h2 class="text-base font-bold text-slate-800">Nueva solicitud de revisión</h2>
              <p class="text-xs text-slate-400 mt-0.5">El administrador recibirá y revisará tu reporte</p>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 transition-colors" @click="mostrarForm = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <div class="overflow-y-auto px-6 py-5 flex flex-col gap-4">

            <!-- Área -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                ¿En qué área está el problema? *
              </label>
              <div class="grid grid-cols-2 gap-2">
                <button
                  v-for="a in AREAS"
                  :key="a.tabla"
                  type="button"
                  class="flex items-center gap-2 px-3 py-2.5 rounded-xl border-2 text-left transition-all text-sm"
                  :class="formArea === a.tabla
                    ? 'border-green-500 bg-green-50 text-green-700 font-semibold'
                    : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'"
                  @click="formArea = a.tabla"
                >
                  <i
                    class="text-sm flex-shrink-0"
                    :class="{
                      'pi pi-star':           a.tabla === 'observaciones',
                      'pi pi-users':          a.tabla === 'asistencia_actividad',
                      'pi pi-bolt':           a.tabla === 'liderazgo_dia',
                      'pi pi-exclamation-triangle': a.tabla === 'incidencias',
                      'pi pi-id-card':        a.tabla === 'integrantes',
                      'pi pi-ellipsis-h':     a.tabla === 'general',
                    }"
                  />
                  <span class="leading-tight">{{ a.label }}</span>
                </button>
              </div>
            </div>

            <!-- Descripción -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                ¿Qué necesita corrección? *
              </label>
              <textarea
                v-model="formDesc"
                rows="4"
                placeholder="Describe el problema con el mayor detalle posible: equipo afectado, día, qué está mal y cómo debería estar…"
                class="w-full px-3.5 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 resize-none focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
              />
              <p class="text-xs text-slate-400">{{ formDesc.length }} caracteres</p>
            </div>

            <div v-if="errGuardar" class="flex items-center gap-2 text-red-600 text-sm bg-red-50 border border-red-200 rounded-xl px-3 py-2">
              <i class="pi pi-exclamation-circle text-sm" />
              {{ errGuardar }}
            </div>

          </div>

          <div class="px-6 py-4 border-t border-slate-100 flex gap-3">
            <button class="flex-1 h-11 rounded-xl border border-slate-200 text-slate-500 font-semibold text-sm hover:bg-slate-50 transition-colors" @click="mostrarForm = false">
              Cancelar
            </button>
            <button
              class="flex-[2] h-11 rounded-xl bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold text-sm flex items-center justify-center gap-2 transition-colors"
              :disabled="guardando"
              @click="crearSolicitud"
            >
              <i v-if="guardando" class="pi pi-spin pi-spinner" />
              <i v-else class="pi pi-send" />
              {{ guardando ? 'Enviando…' : 'Enviar solicitud' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════════════════════
         PANEL DE AYUDA
    ═══════════════════════════════════════════════════════ -->
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div v-if="mostrarAyuda" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:p-4">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="mostrarAyuda = false" />

        <div class="relative w-full sm:max-w-md bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl overflow-hidden">

          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-question-circle text-green-600 text-sm" />
              </div>
              <h2 class="text-base font-bold text-slate-800">¿Cómo funciona?</h2>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 transition-colors" @click="mostrarAyuda = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <div class="px-6 py-5 flex flex-col gap-4 overflow-y-auto max-h-[70dvh]">

            <p class="text-sm text-slate-600 leading-relaxed">
              Este módulo permite a los <strong>evaluadores</strong> reportar errores o inconsistencias
              en los puntajes para que el <strong>administrador</strong> los revise y corrija.
            </p>

            <!-- Pasos -->
            <div class="flex flex-col gap-3">
              <div v-if="!session.esAdmin" class="flex gap-3">
                <div class="w-7 h-7 rounded-full bg-green-100 text-green-700 font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5">1</div>
                <div>
                  <p class="text-sm font-semibold text-slate-700">Detectas un error</p>
                  <p class="text-xs text-slate-500 mt-0.5">Por ejemplo: una observación mal puntuada, una asistencia registrada incorrectamente, o un demérito aplicado por error.</p>
                </div>
              </div>
              <div v-if="!session.esAdmin" class="flex gap-3">
                <div class="w-7 h-7 rounded-full bg-green-100 text-green-700 font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5">2</div>
                <div>
                  <p class="text-sm font-semibold text-slate-700">Creas una solicitud</p>
                  <p class="text-xs text-slate-500 mt-0.5">Selecciona el área afectada y describe el problema con detalle: equipo, día, qué está mal y cómo debería estar.</p>
                </div>
              </div>
              <div class="flex gap-3">
                <div
                  class="w-7 h-7 rounded-full bg-green-100 text-green-700 font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5"
                  :class="session.esAdmin ? '' : ''"
                >{{ session.esAdmin ? '1' : '3' }}</div>
                <div>
                  <p class="text-sm font-semibold text-slate-700">El admin revisa</p>
                  <p class="text-xs text-slate-500 mt-0.5">El administrador analiza el caso, hace la corrección en el sistema si corresponde, y marca la solicitud como <span class="text-green-700 font-medium">aprobada</span> o <span class="text-red-600 font-medium">rechazada</span> con un comentario.</p>
                </div>
              </div>
              <div class="flex gap-3">
                <div class="w-7 h-7 rounded-full bg-green-100 text-green-700 font-bold text-xs flex items-center justify-center flex-shrink-0 mt-0.5">{{ session.esAdmin ? '2' : '4' }}</div>
                <div>
                  <p class="text-sm font-semibold text-slate-700">Ves la respuesta</p>
                  <p class="text-xs text-slate-500 mt-0.5">Podrás ver el resultado y el comentario del admin directamente en la lista de solicitudes.</p>
                </div>
              </div>
            </div>

            <!-- Estados -->
            <div class="bg-slate-50 rounded-xl p-4">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2.5">Estados de una solicitud</p>
              <div class="flex flex-col gap-2">
                <div class="flex items-center gap-2">
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full ring-1 bg-amber-50 text-amber-700 ring-amber-200">Pendiente</span>
                  <span class="text-xs text-slate-500">Esperando que el admin la revise</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full ring-1 bg-green-50 text-green-700 ring-green-200">Aprobada</span>
                  <span class="text-xs text-slate-500">El error fue confirmado y corregido</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full ring-1 bg-red-50 text-red-700 ring-red-200">Rechazada</span>
                  <span class="text-xs text-slate-500">El admin no encontró el error o no procede</span>
                </div>
              </div>
            </div>

          </div>

          <div class="px-6 py-4 border-t border-slate-100">
            <button
              class="w-full h-11 rounded-xl bg-green-600 hover:bg-green-700 text-white font-semibold text-sm transition-colors"
              @click="mostrarAyuda = false"
            >
              Entendido
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>
