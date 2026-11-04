<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  campamentoAdminService,
} from '@/modules/auditoria/services/auditoria.service'
import {
  diasService, programacionRubricaService, type DiasEvaluacion,
} from '@/modules/observaciones/services/observaciones.service'
import { actividadesService } from '@/modules/asistencia/services/asistencia.service'
import { useCampamentoStore } from '@/stores/campamento'

const LABEL_DIA: Record<string, string> = {
  J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo',
}

const campStore = useCampamentoStore()
const router    = useRouter()

const diasDelCampamento  = ref<DiasEvaluacion[]>([])
const momentosConProg    = ref<Set<string>>(new Set())

// Solo exigir cierre de días que tienen contenido programado (los que aparecen en Avance)
const diasAbiertos = computed(() =>
  diasDelCampamento.value.filter(
    (d) => !d.cerrado && momentosConProg.value.has(d.momento ?? ''),
  ),
)

const cerrado       = ref(false)
const cerradoAt     = ref<string | null>(null)
const motivoCierre  = ref<string | null>(null)
const cargando      = ref(true)
const errorMsg      = ref('')

const motivoInput   = ref('')
const forzar        = ref(false)
const cerrando      = ref(false)
const reabriendo    = ref(false)
const errCierre     = ref('')
const confirmCierre = ref(false)
const mostrarAyuda  = ref(false)

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargar() {
  cargando.value = true
  errorMsg.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    const [camp, diasData, momentosRubrica, conteosAct] = await Promise.all([
      campamentoAdminService.getEstado(campStore.selectedId),
      diasService.getTodos(campStore.selectedId),
      programacionRubricaService.getMomentosConProgramacion(campStore.selectedId),
      actividadesService.getConteosPorCampamento(campStore.selectedId),
    ])
    diasDelCampamento.value = diasData
    momentosConProg.value   = new Set([...momentosRubrica, ...Object.keys(conteosAct)])
    cerrado.value      = camp.cerrado
    cerradoAt.value    = camp.cerrado_at
    motivoCierre.value = camp.motivo_cierre
  } catch (e: unknown) {
    errorMsg.value = e instanceof Error ? e.message : 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

async function cerrarCampamento() {
  if (!motivoInput.value.trim()) { errCierre.value = 'Ingresa el motivo del cierre.'; return }
  cerrando.value = true; errCierre.value = ''
  try {
    await campamentoAdminService.cerrar(campStore.selectedId!, motivoInput.value.trim(), forzar.value)
    confirmCierre.value = false; motivoInput.value = ''; forzar.value = false
    router.push('/ranking?countdown=1')
  } catch (e: unknown) {
    errCierre.value = e instanceof Error ? e.message : 'Error al cerrar'
  } finally {
    cerrando.value = false
  }
}

async function reabrirCampamento() {
  if (!motivoInput.value.trim()) { errCierre.value = 'Ingresa el motivo de reapertura.'; return }
  reabriendo.value = true; errCierre.value = ''
  try {
    await campamentoAdminService.reabrir(campStore.selectedId!, motivoInput.value.trim())
    motivoInput.value = ''
    await cargar()
  } catch (e: unknown) {
    errCierre.value = e instanceof Error ? e.message : 'Error al reabrir'
  } finally {
    reabriendo.value = false
  }
}

function formatFecha(ts: string | null) {
  if (!ts) return '—'
  return new Date(ts).toLocaleString('es-PE', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6 sm:px-6 sm:py-8">

      <!-- ─── Cabecera ─── -->
      <div class="flex items-start justify-between gap-3 mb-6">
        <div>
          <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Publicación</h1>
          <p class="mt-1 text-sm text-slate-500">
            Controla qué resultados ve el público y el estado del campamento
          </p>
        </div>
        <button
          class="w-9 h-9 flex items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 hover:text-green-600 hover:border-green-300 shadow-sm transition-colors flex-shrink-0"
          title="¿Cómo funciona este módulo?"
          @click="mostrarAyuda = true"
        >
          <i class="pi pi-question-circle text-base" />
        </button>
      </div>

      <!-- ─── Cargando ─── -->
      <div v-if="cargando" class="flex items-center justify-center gap-2 py-16 text-slate-400">
        <i class="pi pi-spin pi-spinner" /><span class="text-sm">Cargando…</span>
      </div>

      <div v-else-if="errorMsg" class="flex items-center gap-2 bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-red-700 text-sm">
        <i class="pi pi-exclamation-circle" /> {{ errorMsg }}
      </div>

      <template v-else>

        <!-- ─── Banner campamento cerrado ─── -->
        <div v-if="cerrado" class="flex items-start gap-3 bg-red-50 border border-red-200 rounded-2xl px-4 py-4 mb-5">
          <div class="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <i class="pi pi-lock text-red-600" />
          </div>
          <div>
            <p class="text-sm font-bold text-red-700">Campamento cerrado</p>
            <p class="text-xs text-red-600 mt-0.5">
              Cerrado el {{ formatFecha(cerradoAt) }}
              <span v-if="motivoCierre"> · {{ motivoCierre }}</span>
            </p>
            <p class="text-xs text-red-500 mt-1">Los evaluadores no pueden registrar ni modificar datos.</p>
          </div>
        </div>

        <!-- ══════════════════════════════════════════
             Estado del campamento
        ══════════════════════════════════════════ -->
        <div
          class="bg-white rounded-2xl border shadow-sm overflow-hidden"
          :class="cerrado ? 'border-red-100' : 'border-slate-100'"
        >
          <!-- Header sección -->
          <div class="flex items-center gap-2.5 px-5 py-4 border-b"
            :class="cerrado ? 'border-red-50 bg-red-50/50' : 'border-slate-50'">
            <div
              class="w-8 h-8 rounded-lg flex items-center justify-center"
              :class="cerrado ? 'bg-red-100' : 'bg-slate-100'"
            >
              <i :class="['text-sm', cerrado ? 'pi pi-lock text-red-600' : 'pi pi-lock-open text-slate-500']" />
            </div>
            <div>
              <h2 class="text-sm font-bold text-slate-800">
                {{ cerrado ? 'Campamento cerrado' : 'Estado del campamento' }}
              </h2>
              <p class="text-xs text-slate-400">
                {{ cerrado ? 'Solo el admin puede modificar datos' : 'Abierto — evaluadores pueden registrar datos' }}
              </p>
            </div>
          </div>

          <div class="p-5">

            <!-- ESTADO: Abierto → opción de cerrar -->
            <template v-if="!cerrado">
              <p class="text-sm text-slate-500 mb-4 leading-relaxed">
                Al cerrar el campamento, los evaluadores <strong class="text-slate-700">ya no podrán</strong>
                registrar ni modificar ningún dato. El administrador conserva acceso total.
              </p>

              <!-- Advertencia: días sin cerrar -->
              <div v-if="diasAbiertos.length > 0" class="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 mb-4">
                <i class="pi pi-exclamation-triangle text-amber-500 mt-0.5 flex-shrink-0" />
                <div>
                  <p class="text-sm font-semibold text-amber-800 mb-1">Debes cerrar todos los días antes de cerrar el campamento.</p>
                  <p class="text-xs text-amber-700">
                    Días pendientes:
                    <strong>{{ diasAbiertos.map(d => LABEL_DIA[d.momento ?? ''] ?? d.momento).join(', ') }}</strong>
                  </p>
                  <p class="text-xs text-amber-600 mt-1">Ve a la vista de <strong>Avance</strong> y cierra cada día antes de continuar.</p>
                </div>
              </div>

              <!-- Formulario de cierre -->
              <div v-if="!confirmCierre">
                <button
                  class="inline-flex items-center gap-2 px-5 h-11 font-semibold text-sm rounded-xl transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  :class="diasAbiertos.length > 0 ? 'bg-slate-300 text-slate-500 cursor-not-allowed' : 'bg-red-600 hover:bg-red-700 text-white'"
                  :disabled="diasAbiertos.length > 0"
                  @click="confirmCierre = true"
                >
                  <i class="pi pi-lock text-sm" />
                  Cerrar campamento
                </button>
              </div>

              <div v-else class="flex flex-col gap-4">
                <div class="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3">
                  <i class="pi pi-exclamation-triangle text-amber-500 mt-0.5" />
                  <p class="text-sm text-amber-800">
                    Esta acción impedirá que los evaluadores registren datos. Podrás reabrir después si es necesario.
                  </p>
                </div>

                <div class="flex flex-col gap-1.5">
                  <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Motivo del cierre *</label>
                  <textarea
                    v-model="motivoInput"
                    rows="3"
                    placeholder="Ej. Campamento finalizado, resultados oficiales listos…"
                    class="w-full px-3.5 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 resize-none focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                  />
                </div>

                <label class="flex items-center gap-3 cursor-pointer select-none">
                  <div
                    class="w-5 h-5 rounded border-2 flex items-center justify-center transition-colors flex-shrink-0"
                    :class="forzar ? 'bg-green-600 border-green-600' : 'border-slate-300 bg-white'"
                    @click="forzar = !forzar"
                  >
                    <i v-if="forzar" class="pi pi-check text-white text-[10px]" />
                  </div>
                  <div>
                    <p class="text-sm font-semibold text-slate-700">Forzar cierre</p>
                    <p class="text-xs text-slate-400">Cierra aunque haya incidencias pendientes de resolver</p>
                  </div>
                </label>

                <div v-if="errCierre" class="flex items-center gap-2 text-red-600 text-sm bg-red-50 border border-red-100 rounded-xl px-3 py-2">
                  <i class="pi pi-exclamation-circle text-sm" /> {{ errCierre }}
                </div>

                <div class="flex gap-3">
                  <button
                    class="flex-1 h-11 rounded-xl border border-slate-200 text-slate-500 font-semibold text-sm hover:bg-slate-50 transition-colors"
                    @click="confirmCierre = false; errCierre = ''"
                  >
                    Cancelar
                  </button>
                  <button
                    class="flex-[2] h-11 rounded-xl bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold text-sm flex items-center justify-center gap-2 transition-colors"
                    :disabled="cerrando"
                    @click="cerrarCampamento"
                  >
                    <i v-if="cerrando" class="pi pi-spin pi-spinner" />
                    <i v-else class="pi pi-lock" />
                    {{ cerrando ? 'Cerrando…' : 'Confirmar cierre' }}
                  </button>
                </div>
              </div>
            </template>

            <!-- ESTADO: Cerrado → opción de reabrir -->
            <template v-else>
              <p class="text-sm text-slate-500 mb-4 leading-relaxed">
                El campamento está cerrado. Puedes reabrirlo para hacer correcciones o ajustes de último momento.
              </p>

              <div class="flex flex-col gap-3">
                <div class="flex flex-col gap-1.5">
                  <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Motivo de reapertura *</label>
                  <textarea
                    v-model="motivoInput"
                    rows="2"
                    placeholder="Ej. Corrección de puntaje solicitada por evaluador…"
                    class="w-full px-3.5 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 resize-none focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                  />
                </div>

                <div v-if="errCierre" class="flex items-center gap-2 text-red-600 text-sm bg-red-50 border border-red-100 rounded-xl px-3 py-2">
                  <i class="pi pi-exclamation-circle text-sm" /> {{ errCierre }}
                </div>

                <button
                  class="inline-flex items-center justify-center gap-2 h-11 px-6 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold text-sm rounded-xl transition-colors"
                  :disabled="reabriendo"
                  @click="reabrirCampamento"
                >
                  <i v-if="reabriendo" class="pi pi-spin pi-spinner" />
                  <i v-else class="pi pi-lock-open" />
                  {{ reabriendo ? 'Reabriendo…' : 'Reabrir campamento' }}
                </button>
              </div>
            </template>

          </div>
        </div>

      </template>
    </div><!-- /max-w -->

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

          <div class="px-6 py-5 flex flex-col gap-5 overflow-y-auto max-h-[70dvh]">

            <!-- Publicación -->
            <div>
              <div class="flex items-center gap-2 mb-2">
                <div class="w-7 h-7 rounded-lg bg-green-100 flex items-center justify-center">
                  <i class="pi pi-eye text-green-600 text-xs" />
                </div>
                <h3 class="text-sm font-bold text-slate-700">Publicación de resultados</h3>
              </div>
              <p class="text-sm text-slate-500 leading-relaxed ml-9">
                Cada día configurado del campamento tiene un interruptor de publicación.
                Mientras un día esté <strong class="text-slate-700">oculto</strong>, los estudiantes
                no ven esos puntajes en el ranking público. Al <strong class="text-green-700">publicar</strong>,
                los resultados de ese día aparecen inmediatamente en la pantalla pública.
              </p>
            </div>

            <!-- Completitud -->
            <div>
              <div class="flex items-center gap-2 mb-2">
                <div class="w-7 h-7 rounded-lg bg-amber-100 flex items-center justify-center">
                  <i class="pi pi-chart-bar text-amber-600 text-xs" />
                </div>
                <h3 class="text-sm font-bold text-slate-700">Indicadores de completitud</h3>
              </div>
              <p class="text-sm text-slate-500 leading-relaxed ml-9">
                Cada tarjeta de día muestra cuántos equipos tienen rúbrica, liderazgo y
                asistencia registrados. Publica cuando todos los datos estén completos para
                evitar mostrar resultados parciales.
              </p>
              <div class="ml-9 mt-2 flex flex-col gap-1.5">
                <div class="flex items-center gap-2">
                  <span class="text-xs font-bold text-green-600">Verde</span>
                  <span class="text-xs text-slate-500">— todos los equipos tienen el dato</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-xs font-bold text-amber-600">Ámbar</span>
                  <span class="text-xs text-slate-500">— datos parciales, faltan algunos</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-xs font-bold text-red-500">Rojo</span>
                  <span class="text-xs text-slate-500">— sin datos registrados</span>
                </div>
              </div>
            </div>

            <!-- Cierre -->
            <div>
              <div class="flex items-center gap-2 mb-2">
                <div class="w-7 h-7 rounded-lg bg-red-100 flex items-center justify-center">
                  <i class="pi pi-lock text-red-600 text-xs" />
                </div>
                <h3 class="text-sm font-bold text-slate-700">Cierre del campamento</h3>
              </div>
              <p class="text-sm text-slate-500 leading-relaxed ml-9">
                El cierre es el paso final. Una vez cerrado, los evaluadores <strong class="text-slate-700">no pueden</strong>
                ingresar ni editar datos. Úsalo cuando el campamento termine y los resultados sean definitivos.
                Puedes reabrir en cualquier momento si necesitas hacer correcciones.
              </p>
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
