<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import {
  codigosService,
  incidenciasService,
  incidenciaIntegrantesService,
  evidenciasService,
  type IncidenciaCodigo,
} from '@/modules/incidencias/services/incidencias.service'
import { equiposService, integrantesService, type Equipo, type Integrante } from '@/modules/equipos/services/equipos.service'
import CodePicker   from '../components/CodePicker.vue'
import TeamGrid     from '../components/TeamGrid.vue'
import StepProgress from '../components/StepProgress.vue'
import SummaryPanel from '../components/SummaryPanel.vue'

const router    = useRouter()
const route     = useRoute()
const session   = useSessionStore()
const campStore = useCampamentoStore()

const PASO_NOMBRES = ['Tipo', 'Equipo', 'Detalles', 'Confirmar']

// ── Referencia ────────────────────────────────────────────────────────────────
const codigos     = ref<IncidenciaCodigo[]>([])
const equipos     = ref<Equipo[]>([])
const integrantes = ref<Integrante[]>([])
const cargandoRef = ref(true)

onMounted(async () => {
  try {
    const [cod, eq] = await Promise.all([
      codigosService.getAll(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])
    codigos.value = cod
    equipos.value = eq
  } finally {
    cargandoRef.value = false
  }
})

// ── Helpers de fecha/hora ─────────────────────────────────────────────────────
function fechaHoy() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}
function horaInicial() {
  const n = new Date()
  return `${String(n.getHours()).padStart(2,'0')}:${String(n.getMinutes()).padStart(2,'0')}`
}

// ── Formulario ────────────────────────────────────────────────────────────────
const tipo           = ref<'bonus' | 'demerito' | ''>('')
const codigoSel      = ref('')
const equipoId       = ref('')
const equipoApId     = ref('')
const fecha          = ref((route.query.fecha as string) || fechaHoy())
const hora           = ref(horaInicial())
const hecho          = ref('')
const alcance        = ref('equipo')
const puntosBonus    = ref<number>(25)
const puntosDemerito = ref<number>(0)
const cantPersonas   = ref(1)
const advertencia    = ref('')
const justificacionGrupal = ref('')
const integranteIds  = ref<string[]>([])
const archivos       = ref<File[]>([])
const fotosUrls      = ref<string[]>([])
const guardando      = ref(false)
const errorGuardar   = ref('')

// ── Código info ───────────────────────────────────────────────────────────────
const codigoInfo = computed<IncidenciaCodigo | null>(
  () => codigos.value.find(c => c.codigo === codigoSel.value) ?? null
)

const puntosCalculados = computed(() => {
  return tipo.value === 'bonus' ? puntosBonus.value : puntosDemerito.value
})

// Al cambiar tipo: auto-rellenar hora y auto-seleccionar código
watch(tipo, (t) => {
  const now = new Date()
  hora.value = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`
  codigoSel.value  = ''
  puntosDemerito.value = 0
  if (t === 'bonus') {
    codigoSel.value = codigos.value.find(c => c.tipo === 'bonus')?.codigo ?? ''
  } else if (t === 'demerito') {
    const primerDemerito = codigos.value.find(
      c => c.tipo === 'demerito' && !c.requiere_advertencia && !c.requiere_equipo_apoyado && !c.por_persona
    )
    codigoSel.value      = primerDemerito?.codigo ?? ''
    puntosDemerito.value = primerDemerito?.puntos ?? 0
  }
})

// Al cambiar equipo, cargar integrantes
watch(equipoId, async (id) => {
  integrantes.value  = []
  integranteIds.value = []
  if (id) integrantes.value = await integrantesService.getPorEquipo(id)
})

// Al cambiar código, resetear campos extra
watch(codigoSel, (nuevo) => {
  advertencia.value     = ''
  justificacionGrupal.value = ''
  cantPersonas.value    = 1
  integranteIds.value   = []
  const cat = codigos.value.find(c => c.codigo === nuevo)
  puntosDemerito.value  = cat?.puntos ?? 0
})

// D6: actualizar total al cambiar cantidad de personas
watch(cantPersonas, (n) => {
  if (codigoInfo.value?.por_persona) {
    puntosDemerito.value = (codigoInfo.value.puntos ?? 0) * n
  }
})

function toggleIntegrante(id: string) {
  const idx = integranteIds.value.indexOf(id)
  if (idx >= 0) integranteIds.value.splice(idx, 1)
  else integranteIds.value.push(id)
}

// ── Paso móvil ────────────────────────────────────────────────────────────────
const paso = ref(1)

const puedeAvanzar = computed(() => {
  switch (paso.value) {
    case 1: return !!tipo.value
    case 2: return !!equipoId.value
    case 3: {
      if (hecho.value.trim().length < 10) return false
      if (tipo.value === 'demerito' && (!puntosDemerito.value || puntosDemerito.value <= 0)) return false
      return true
    }
    default: return true
  }
})

function avanzar()    { if (puedeAvanzar.value) paso.value++ }
function retroceder() { paso.value-- }

// ── Cámara ────────────────────────────────────────────────────────────────────
const camaraActiva = ref(false)
const camaraError  = ref('')
const videoRef     = ref<HTMLVideoElement | null>(null)
const streamRef    = ref<MediaStream | null>(null)

async function abrirCamara() {
  camaraError.value  = ''
  camaraActiva.value = true
  await nextTick()
  try {
    let stream: MediaStream
    try {
      stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
    } catch {
      stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    }
    streamRef.value = stream
    if (videoRef.value) videoRef.value.srcObject = stream
  } catch {
    camaraActiva.value = false
    camaraError.value  = 'No se pudo acceder a la cámara.'
  }
}

function cerrarCamara() {
  streamRef.value?.getTracks().forEach(t => t.stop())
  streamRef.value    = null
  camaraActiva.value = false
}

function capturarFoto() {
  if (!videoRef.value) return
  const v = videoRef.value
  const w = v.videoWidth  || v.clientWidth
  const h = v.videoHeight || v.clientHeight
  if (!w || !h) return
  const canvas = document.createElement('canvas')
  canvas.width = w; canvas.height = h
  canvas.getContext('2d')!.drawImage(v, 0, 0, w, h)
  canvas.toBlob(blob => {
    if (blob) {
      archivos.value  = [...archivos.value, new File([blob], `foto_${Date.now()}.jpg`, { type: 'image/jpeg' })]
      fotosUrls.value = [...fotosUrls.value, URL.createObjectURL(blob)]
    }
    cerrarCamara()
  }, 'image/jpeg', 0.85)
}

function quitarFoto(i: number) {
  URL.revokeObjectURL(fotosUrls.value[i]!)
  archivos.value  = archivos.value.filter((_, idx) => idx !== i)
  fotosUrls.value = fotosUrls.value.filter((_, idx) => idx !== i)
}

// ── Archivos adjuntos ─────────────────────────────────────────────────────────
function onArchivoChange(e: Event) {
  const input = e.target as HTMLInputElement
  if (!input.files) return
  for (const f of Array.from(input.files)) {
    archivos.value  = [...archivos.value, f]
    fotosUrls.value = [...fotosUrls.value, URL.createObjectURL(f)]
  }
  input.value = ''
}
function quitarArchivo(i: number) { quitarFoto(i) }

// ── Puede registrar (todos los pasos completos) ───────────────────────────────
const puedeRegistrar = computed(() => {
  if (!tipo.value || !codigoSel.value || !equipoId.value) return false
  if (!hora.value || hecho.value.trim().length < 10) return false
  if (tipo.value === 'demerito' && (!puntosDemerito.value || puntosDemerito.value <= 0)) return false
  return true
})

// ── Guardar ───────────────────────────────────────────────────────────────────
async function guardar() {
  if (!session.user) return
  guardando.value    = true
  errorGuardar.value = ''
  try {
    const puntos = tipo.value === 'bonus' ? puntosBonus.value : puntosDemerito.value

    const inc = await incidenciasService.crear({
      codigo:                  codigoSel.value,
      equipo_id:               equipoId.value,
      equipo_apoyado_id:       null,
      fecha:                   fecha.value,
      hora:                    hora.value,
      hecho:                   hecho.value.trim(),
      alcance:                 alcance.value,
      cantidad_personas:       1,
      advertencia_referencia:  null,
      justificacion_grupal:    null,
      puntos,
      registrado_por:          session.user.id,
    }, integranteIds.value)

    // Subir evidencias (fotos tomadas + archivos adjuntados)
    for (const archivo of archivos.value) {
      await evidenciasService.subir(inc.id, archivo, session.user.id)
    }

    router.push(`/panel/incidencias/${inc.id}`)
  } catch (e: any) {
    errorGuardar.value = e.message ?? 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

function nombreEquipo(id: string) {
  return equipos.value.find(e => e.id === id)?.nombre ?? ''
}

// ── Detectar si es mobile ─────────────────────────────────────────────────────
const isMobile = computed(() => {
  if (typeof window === 'undefined') return false
  return window.innerWidth < 768
})
</script>

<template>
  <div class="flex flex-col min-h-full overflow-auto bg-[#F4F6F4]" style="font-family: Inter, system-ui, sans-serif">

    <!-- ═══════════════════ LOADING ═══════════════════ -->
    <div v-if="cargandoRef" class="flex-1 flex items-center justify-center p-8">
      <svg class="animate-spin h-6 w-6 text-[#0E7C59]" viewBox="0 0 24 24" fill="none"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/></svg>
    </div>

    <template v-else>

      <!-- ══════════════════════════════════════
           MOBILE: wizard (< md)
      ══════════════════════════════════════ -->
      <div class="md:hidden flex flex-col h-full">

        <!-- Mobile header -->
        <div class="bg-white border-b border-[#E3E7E4] px-4 pt-3 pb-4 flex-shrink-0">
          <div class="flex items-center justify-between mb-3">
            <span class="text-[17px] font-bold text-[#16201B]">Registrar incidencia</span>
            <button
              class="w-9 h-9 rounded-xl flex items-center justify-center text-[#5B6660] hover:bg-[#F4F6F4] font-[inherit]"
              @click="router.back()"
              aria-label="Cancelar"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
          </div>
          <StepProgress :paso="paso" :total="4" :nombres="PASO_NOMBRES" />
        </div>

        <!-- Step content -->
        <div class="flex-1 overflow-y-auto px-4 py-5">

          <!-- Paso 1: Tipo -->
          <div v-if="paso === 1">
            <h2 class="text-[16px] font-bold text-[#16201B] mb-4">Tipo</h2>
            <CodePicker
              :tipo="tipo"
              @update:tipo="tipo = $event"
              @update:codigoSel="codigoSel = $event"
            />
          </div>

          <!-- Paso 2: Equipo -->
          <div v-else-if="paso === 2">
            <h2 class="text-[16px] font-bold text-[#16201B] mb-4">Equipo</h2>
            <TeamGrid
              :equipos="equipos"
              :modelValue="equipoId"
              @update:modelValue="equipoId = $event"
            />
            <!-- Equipo apoyado (B2) -->
            <div v-if="codigoInfo?.requiere_equipo_apoyado" class="mt-4">
              <TeamGrid
                titulo="Equipo que recibió el apoyo"
                :equipos="equipos"
                :modelValue="equipoApId"
                :excluir="equipoId"
                @update:modelValue="equipoApId = $event"
              />
            </div>
          </div>

          <!-- Paso 3: Detalles -->
          <div v-else-if="paso === 3" class="flex flex-col gap-4">
            <h2 class="text-[16px] font-bold text-[#16201B] mb-0">Detalles</h2>

            <!-- Puntos bonus: selector 12.5 / 25 / 50 -->
            <div v-if="tipo === 'bonus'" class="flex flex-col gap-1.5">
              <label class="text-[13px] font-semibold text-[#16201B]">Puntos a aplicar</label>
              <div class="grid grid-cols-3 gap-2">
                <button
                  v-for="pts in [12.5, 25, 50]"
                  :key="pts"
                  class="flex flex-col items-center gap-1 min-h-[64px] p-3 border-2 rounded-xl transition-colors font-[inherit]"
                  :class="puntosBonus === pts
                    ? 'border-[#0E7C59] bg-[#E1F3EA]'
                    : 'border-[#E3E7E4] bg-white hover:bg-[#F4F6F4]'"
                  @click="puntosBonus = pts"
                >
                  <strong class="text-[20px]" :class="puntosBonus === pts ? 'text-[#0B6B4B]' : 'text-[#16201B]'">{{ pts }}</strong>
                  <span class="text-[12px]" :class="puntosBonus === pts ? 'text-[#0B6B4B]' : 'text-[#5B6660]'">pts</span>
                </button>
              </div>
            </div>

            <!-- Puntos demérito: input numérico -->
            <div v-else-if="tipo === 'demerito'" class="flex flex-col gap-1.5">
              <label class="text-[13px] font-semibold text-[#16201B]">
                Puntos a aplicar <span class="text-[#A3261F]">*</span>
              </label>
              <input
                v-model.number="puntosDemerito"
                type="number"
                min="0"
                step="0.5"
                class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white"
                placeholder="Ej. 10"
              />
            </div>

            <!-- Descripción del hecho -->
            <div class="flex flex-col gap-1.5">
              <label class="text-[13px] font-semibold text-[#16201B]">
                Descripción del hecho <span class="text-[#A3261F]">*</span>
                <span class="text-[12px] font-normal text-[#5B6660] ml-1">(mín. 10 caracteres)</span>
              </label>
              <textarea
                v-model="hecho"
                rows="4"
                placeholder="Describe el hecho objetivamente…"
                class="w-full px-3 py-2.5 text-[14px] border border-[#DCE1DD] rounded-xl resize-none focus:outline-none focus:border-[#0E7C59] focus:ring-2 focus:ring-[#E1F3EA] font-[inherit]"
              />
            </div>

            <!-- Advertencia previa (D1) -->
            <div v-if="codigoInfo?.requiere_advertencia" class="flex flex-col gap-1.5">
              <label class="text-[13px] font-semibold text-[#16201B]">Advertencia previa (referencia)</label>
              <input
                v-model="advertencia"
                type="text"
                placeholder="Hora o descripción de la advertencia previa…"
                class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white"
              />
            </div>

            <!-- Personas involucradas + integrantes (D6) -->
            <div v-if="codigoInfo?.por_persona" class="flex flex-col gap-3">
              <div class="flex flex-col gap-1.5">
                <label class="text-[13px] font-semibold text-[#16201B]">
                  Personas involucradas <span class="text-[#A3261F]">*</span>
                </label>
                <input
                  v-model.number="cantPersonas"
                  type="number"
                  min="1"
                  class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white w-28"
                />
              </div>
              <!-- Integrante picker para D6 -->
              <div v-if="integrantes.length" class="flex flex-col gap-1.5">
                <label class="text-[13px] font-semibold text-[#16201B]">Selecciona los integrantes involucrados</label>
                <div class="flex flex-col gap-1.5">
                  <button
                    v-for="int in integrantes"
                    :key="int.id"
                    class="flex items-center gap-2.5 h-12 px-3.5 rounded-xl border-2 text-left transition-colors font-[inherit]"
                    :class="integranteIds.includes(int.id) ? 'border-[#0E7C59] bg-[#E1F3EA]' : 'border-[#E3E7E4] bg-white hover:bg-[#F4F6F4]'"
                    @click="toggleIntegrante(int.id)"
                  >
                    <span v-if="integranteIds.includes(int.id)" class="text-[#0B6B4B] font-bold text-[13px]">✓</span>
                    <span class="text-[14px]" :class="integranteIds.includes(int.id) ? 'font-semibold text-[#0B6B4B]' : 'text-[#16201B]'">
                      {{ int.apellidos }}, {{ int.nombres }}
                    </span>
                  </button>
                </div>
              </div>
            </div>

            <!-- Evidencia: cámara + adjuntar archivo -->
            <div class="flex flex-col gap-2">
              <label class="text-[13px] font-semibold text-[#16201B]">Evidencia</label>
              <div class="flex gap-2">
                <button
                  type="button"
                  class="flex items-center gap-2 h-11 px-4 rounded-xl border-2 border-[#0E7C59] bg-[#E1F3EA] text-[#0B6B4B] text-[13px] font-semibold font-[inherit]"
                  @click="abrirCamara"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  Cámara
                </button>
                <label class="flex items-center gap-2 h-11 px-4 rounded-xl border-2 border-[#E3E7E4] bg-white text-[#16201B] text-[13px] font-semibold cursor-pointer">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                  Adjuntar
                  <input type="file" accept="image/*,video/*" multiple class="hidden" @change="onArchivoChange" />
                </label>
              </div>
              <p v-if="camaraError" class="text-[12px] text-[#A3261F] m-0">{{ camaraError }}</p>
              <div v-if="archivos.length" class="flex flex-wrap gap-2 mt-1">
                <div v-for="(_, i) in archivos" :key="i" class="relative w-16 h-16 rounded-xl overflow-hidden border border-[#E3E7E4]">
                  <img :src="fotosUrls[i]" alt="foto" class="w-full h-full object-cover" />
                  <button
                    class="absolute top-0.5 right-0.5 w-5 h-5 rounded-md bg-black/50 text-white flex items-center justify-center text-[10px]"
                    @click="quitarArchivo(i)"
                  >✕</button>
                </div>
              </div>
            </div>
          </div>

          <!-- Paso 4: Confirmar -->
          <div v-else-if="paso === 4" class="flex flex-col gap-0">
            <h2 class="text-[16px] font-bold text-[#16201B] mb-4">Confirmar</h2>
            <div class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
              <div class="divide-y divide-[#EEF1EF]">
                <div class="flex items-center justify-between px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660]">Tipo</span>
                  <span class="text-[13px] font-semibold" :class="tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'">
                    {{ tipo === 'bonus' ? 'Bonus' : 'Demérito' }}
                  </span>
                </div>
                <div class="flex items-center justify-between px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660]">Código</span>
                  <span class="text-[13px] font-semibold text-[#16201B]">{{ codigoSel }} · {{ codigoInfo?.nombre }}</span>
                </div>
                <div class="flex items-center justify-between px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660]">Equipo</span>
                  <span class="text-[13px] font-semibold text-[#16201B]">{{ nombreEquipo(equipoId) }}</span>
                </div>
                <div class="px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660] block mb-1">Descripción</span>
                  <span class="text-[13px] text-[#16201B] leading-snug">{{ hecho }}</span>
                </div>
                <div class="flex items-center justify-between px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660]">Puntos</span>
                  <span class="text-[15px] font-bold" :class="tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'">
                    {{ tipo === 'bonus' ? '+' : '−' }}{{ puntosCalculados }}
                  </span>
                </div>
                <div v-if="archivos.length" class="flex items-center justify-between px-4 py-3 gap-3">
                  <span class="text-[13px] text-[#5B6660]">Fotos</span>
                  <span class="text-[13px] text-[#16201B]">{{ archivos.length }} foto(s)</span>
                </div>
              </div>
            </div>
            <div class="mt-3 bg-[#EEF0EE] rounded-xl px-4 py-2.5 text-center">
              <span class="text-[12px] font-semibold text-[#4A544F]">Quedará Registrada, pendiente de validación</span>
            </div>
            <p v-if="errorGuardar" class="text-[13px] text-[#A3261F] text-center mt-2 m-0">{{ errorGuardar }}</p>
          </div>
        </div>

        <!-- Mobile footer -->
        <div class="bg-white border-t border-[#E3E7E4] px-4 py-3 flex gap-3 flex-shrink-0">
          <button
            v-if="paso > 1"
            class="h-[50px] px-[18px] rounded-[14px] border border-[#DCE1DD] text-[14px] font-semibold text-[#16201B] bg-white font-[inherit]"
            :disabled="guardando"
            @click="retroceder"
          >Anterior</button>
          <button
            v-if="paso < 4"
            class="flex-1 h-[50px] rounded-[14px] text-[14px] font-semibold text-white bg-[#0E7C59] disabled:opacity-50 font-[inherit]"
            :disabled="!puedeAvanzar"
            @click="avanzar"
          >Siguiente</button>
          <button
            v-else
            class="flex-1 h-[50px] rounded-[14px] text-[14px] font-semibold text-white bg-[#0E7C59] disabled:opacity-50 font-[inherit]"
            :disabled="!puedeRegistrar || guardando"
            @click="guardar"
          >
            {{ guardando ? 'Guardando…' : 'Registrar incidencia' }}
          </button>
        </div>
      </div>

      <!-- ══════════════════════════════════════
           TABLET / DESKTOP: single page (≥ md)
      ══════════════════════════════════════ -->
      <div class="hidden md:flex flex-col flex-1">

        <!-- Desktop top bar -->
        <div class="bg-white border-b border-[#E3E7E4] px-6 py-3 flex items-center gap-3 flex-shrink-0">
          <button
            class="flex items-center gap-1.5 text-[13px] font-semibold text-[#0E7C59] hover:underline font-[inherit] bg-transparent border-0 cursor-pointer"
            @click="router.back()"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
            Volver
          </button>
          <div class="w-px h-4 bg-[#E3E7E4]" />
          <span class="text-[13px] text-[#5B6660]">Evaluación / Incidencias / <strong class="text-[#16201B]">Registrar</strong></span>
        </div>

        <!-- Form + summary sidebar -->
        <div class="flex flex-1 overflow-y-auto">

          <!-- FORM (left) -->
          <div class="flex-1 min-w-0 px-6 py-6 flex flex-col gap-6 max-w-2xl">

            <!-- Section 1: Tipo -->
            <section>
              <div class="flex items-center gap-3 mb-4">
                <span class="w-7 h-7 rounded-full bg-[#0E7C59] text-white text-[13px] font-bold flex items-center justify-center flex-shrink-0">1</span>
                <h2 class="text-[15px] font-bold text-[#16201B] m-0">Tipo</h2>
              </div>
              <CodePicker
                :tipo="tipo"
                :codigoSel="codigoSel"
                :codigos="codigos"
                @update:tipo="tipo = $event"
                @update:codigoSel="codigoSel = $event"
              />
            </section>

            <!-- Section 2: Equipo -->
            <section>
              <div class="flex items-center gap-3 mb-4">
                <span class="w-7 h-7 rounded-full bg-[#0E7C59] text-white text-[13px] font-bold flex items-center justify-center flex-shrink-0">2</span>
                <h2 class="text-[15px] font-bold text-[#16201B] m-0">Equipo</h2>
              </div>
              <TeamGrid
                :equipos="equipos"
                :modelValue="equipoId"
                @update:modelValue="equipoId = $event"
              />
              <!-- Equipo apoyado (B2) -->
              <div v-if="codigoInfo?.requiere_equipo_apoyado" class="mt-4">
                <TeamGrid
                  titulo="Equipo que recibió el apoyo"
                  :equipos="equipos"
                  :modelValue="equipoApId"
                  :excluir="equipoId"
                  @update:modelValue="equipoApId = $event"
                />
              </div>
            </section>

            <!-- Section 3: ¿Qué pasó? -->
            <section>
              <div class="flex items-center gap-3 mb-4">
                <span class="w-7 h-7 rounded-full bg-[#0E7C59] text-white text-[13px] font-bold flex items-center justify-center flex-shrink-0">3</span>
                <h2 class="text-[15px] font-bold text-[#16201B] m-0">¿Qué pasó?</h2>
              </div>

              <div class="flex flex-col gap-4">
                <!-- Puntos bonus: selector 12.5 / 25 / 50 -->
                <div v-if="tipo === 'bonus'" class="flex flex-col gap-1.5">
                  <label class="text-[13px] font-semibold text-[#16201B]">Puntos a aplicar</label>
                  <div class="grid grid-cols-3 gap-2 max-w-xs">
                    <button
                      v-for="pts in [12.5, 25, 50]"
                      :key="pts"
                      class="flex flex-col items-center gap-1 min-h-[64px] p-3 border-2 rounded-xl transition-colors font-[inherit]"
                      :class="puntosBonus === pts
                        ? 'border-[#0E7C59] bg-[#E1F3EA]'
                        : 'border-[#E3E7E4] bg-white hover:bg-[#F4F6F4]'"
                      @click="puntosBonus = pts"
                    >
                      <strong class="text-[20px]" :class="puntosBonus === pts ? 'text-[#0B6B4B]' : 'text-[#16201B]'">{{ pts }}</strong>
                      <span class="text-[12px]" :class="puntosBonus === pts ? 'text-[#0B6B4B]' : 'text-[#5B6660]'">pts</span>
                    </button>
                  </div>
                </div>

                <!-- Puntos demérito: input numérico -->
                <div v-else-if="tipo === 'demerito'" class="flex flex-col gap-1.5">
                  <label class="text-[13px] font-semibold text-[#16201B]">
                    Puntos a aplicar <span class="text-[#A3261F]">*</span>
                  </label>
                  <input
                    v-model.number="puntosDemerito"
                    type="number"
                    min="0"
                    step="0.5"
                    class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white w-32"
                    placeholder="Ej. 10"
                  />
                </div>

                <!-- Descripción del hecho -->
                <div class="flex flex-col gap-1.5">
                  <label class="text-[13px] font-semibold text-[#16201B]">
                    Descripción del hecho <span class="text-[#A3261F]">*</span>
                    <span class="text-[12px] font-normal text-[#5B6660] ml-1">(mín. 10 caracteres)</span>
                  </label>
                  <textarea
                    v-model="hecho"
                    rows="4"
                    placeholder="Describe el hecho objetivamente…"
                    class="w-full px-3 py-2.5 text-[14px] border border-[#DCE1DD] rounded-xl resize-none focus:outline-none focus:border-[#0E7C59] focus:ring-2 focus:ring-[#E1F3EA] font-[inherit]"
                  />
                </div>

                <!-- Advertencia previa (D1) -->
                <div v-if="codigoInfo?.requiere_advertencia" class="flex flex-col gap-1.5">
                  <label class="text-[13px] font-semibold text-[#16201B]">Advertencia previa (referencia)</label>
                  <input
                    v-model="advertencia"
                    type="text"
                    placeholder="Hora o descripción de la advertencia previa…"
                    class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white"
                  />
                </div>

                <!-- Personas involucradas + integrantes (D6) -->
                <div v-if="codigoInfo?.por_persona" class="flex flex-col gap-3">
                  <div class="flex flex-col gap-1.5">
                    <label class="text-[13px] font-semibold text-[#16201B]">
                      Personas involucradas <span class="text-[#A3261F]">*</span>
                    </label>
                    <input
                      v-model.number="cantPersonas"
                      type="number"
                      min="1"
                      class="h-11 px-3 text-[14px] border border-[#DCE1DD] rounded-xl focus:outline-none focus:border-[#0E7C59] font-[inherit] bg-white w-32"
                    />
                  </div>
                  <!-- Integrante picker para D6 -->
                  <div v-if="integrantes.length" class="flex flex-col gap-1.5">
                    <label class="text-[13px] font-semibold text-[#16201B]">Selecciona los integrantes involucrados</label>
                    <div class="flex flex-col gap-1.5">
                      <button
                        v-for="int in integrantes"
                        :key="int.id"
                        class="flex items-center gap-2.5 h-12 px-3.5 rounded-xl border-2 text-left transition-colors font-[inherit]"
                        :class="integranteIds.includes(int.id) ? 'border-[#0E7C59] bg-[#E1F3EA]' : 'border-[#E3E7E4] bg-white hover:bg-[#F4F6F4]'"
                        @click="toggleIntegrante(int.id)"
                      >
                        <span v-if="integranteIds.includes(int.id)" class="text-[#0B6B4B] font-bold text-[13px]">✓</span>
                        <span class="text-[14px]" :class="integranteIds.includes(int.id) ? 'font-semibold text-[#0B6B4B]' : 'text-[#16201B]'">
                          {{ int.apellidos }}, {{ int.nombres }}
                        </span>
                      </button>
                    </div>
                  </div>
                </div>

                <!-- Evidencia -->
                <div class="flex flex-col gap-2">
                  <label class="text-[13px] font-semibold text-[#16201B]">Evidencia</label>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      class="flex items-center gap-2 h-11 px-4 rounded-xl border-2 border-[#0E7C59] bg-[#E1F3EA] text-[#0B6B4B] text-[14px] font-semibold font-[inherit]"
                      @click="abrirCamara"
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                      Cámara
                    </button>
                    <label class="flex items-center gap-2 h-11 px-4 rounded-xl border-2 border-[#E3E7E4] bg-white text-[#16201B] text-[14px] font-semibold cursor-pointer">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                      Adjuntar
                      <input type="file" accept="image/*,video/*" multiple class="hidden" @change="onArchivoChange" />
                    </label>
                  </div>
                  <p v-if="camaraError" class="text-[12px] text-[#A3261F] m-0">{{ camaraError }}</p>
                  <div v-if="archivos.length" class="flex flex-wrap gap-2">
                    <div v-for="(_, i) in archivos" :key="i" class="relative w-16 h-16 rounded-xl overflow-hidden border border-[#E3E7E4]">
                      <img :src="fotosUrls[i]" alt="foto" class="w-full h-full object-cover" />
                      <button
                        class="absolute top-0.5 right-0.5 w-5 h-5 rounded-md bg-black/50 text-white flex items-center justify-center text-[10px]"
                        @click="quitarFoto(i)"
                      >✕</button>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </div>

          <!-- SUMMARY SIDEBAR (right) -->
          <div class="hidden lg:block w-[280px] flex-shrink-0 p-6 border-l border-[#E3E7E4]">
            <SummaryPanel
              :tipo="tipo"
              :codigoInfo="codigoInfo"
              :equipoNombre="nombreEquipo(equipoId)"
              :hecho="hecho"
              :fecha="fecha"
              :hora="hora"
              :puntos="puntosCalculados"
              :guardando="guardando"
              :puedeRegistrar="puedeRegistrar"
              :error="errorGuardar"
              @registrar="guardar"
            />
          </div>
        </div>

        <!-- Tablet footer (lg:hidden) — tablet doesn't have wide sidebar -->
        <div class="lg:hidden bg-white border-t border-[#E3E7E4] px-6 py-3 flex items-center justify-between gap-4 flex-shrink-0">
          <span v-if="codigoInfo" class="text-[13px] text-[#5B6660]">
            Código {{ codigoSel }} ·
            <strong class="font-bold" :class="tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'">
              {{ tipo === 'bonus' ? '+' : '−' }}{{ puntosCalculados }} pts
            </strong>
          </span>
          <span v-else class="text-[13px] text-[#8A948E]">Selecciona tipo y código</span>
          <p v-if="errorGuardar" class="text-[12px] text-[#A3261F] m-0">{{ errorGuardar }}</p>
          <button
            class="h-11 px-6 rounded-xl text-[14px] font-semibold text-white bg-[#0E7C59] hover:bg-[#0B6B4B] transition-colors disabled:opacity-50 font-[inherit] flex-shrink-0"
            :disabled="!puedeRegistrar || guardando"
            @click="guardar"
          >
            {{ guardando ? 'Guardando…' : 'Registrar incidencia' }}
          </button>
        </div>
      </div>

    </template>
  </div>

  <!-- ═══════════════════ CAMERA MODAL ═══════════════════ -->
  <teleport to="body">
    <div v-if="camaraActiva" class="fixed inset-0 bg-black/88 z-[9999] flex items-center justify-center p-4">
      <div class="flex flex-col gap-4 w-full max-w-sm">
        <video ref="videoRef" autoplay playsinline class="w-full rounded-2xl bg-black max-h-[60dvh] object-cover" />
        <div class="flex gap-3 justify-center">
          <button class="h-11 px-5 rounded-xl border border-white/30 text-white text-[14px] font-semibold font-[inherit]" @click="cerrarCamara">Cancelar</button>
          <button class="h-11 px-5 rounded-xl bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit]" @click="capturarFoto">
            <svg class="inline-block mr-1.5" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
            Capturar
          </button>
        </div>
      </div>
    </div>
  </teleport>
</template>
