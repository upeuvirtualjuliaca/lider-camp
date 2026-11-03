<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick } from 'vue'
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

const router  = useRouter()
const route   = useRoute()
const session = useSessionStore()
const campStore = useCampamentoStore()

// ── Datos de referencia ───────────────────────────────────────────────────────
const codigos  = ref<IncidenciaCodigo[]>([])
const equipos  = ref<Equipo[]>([])
const integrantes = ref<Integrante[]>([])
const cargandoRef = ref(true)

onMounted(async () => {
  try {
    const [cod, eq] = await Promise.all([codigosService.getAll(), equiposService.getTodos(campStore.selectedId ?? undefined)])
    codigos.value = cod
    equipos.value = eq
  } finally {
    cargandoRef.value = false
  }
})

// ── Pasos ─────────────────────────────────────────────────────────────────────
const paso = ref(1)

const PASOS_DEMERITO = [
  { n: 1, label: 'Tipo' },
  { n: 2, label: 'Equipo' },
  { n: 3, label: 'Detalles' },
  { n: 4, label: 'Confirmar' },
]
const PASOS_BONUS = [
  { n: 1, label: 'Tipo' },
  { n: 2, label: 'Equipo' },
  { n: 3, label: 'Detalles' },
  { n: 4, label: 'Confirmar' },
]

const pasosActivos = computed(() => tipo.value === 'bonus' ? PASOS_BONUS : PASOS_DEMERITO)
const pasoFinal    = computed(() => 4)

// ── Formulario ────────────────────────────────────────────────────────────────
const tipo      = ref<'bonus' | 'demerito' | ''>('')
const codigoSel = ref('')
const equipoId  = ref('')
const equipoApId = ref('')
const fecha     = ref((route.query.fecha as string) || new Date().toISOString().slice(0, 10))
const hora      = ref('')
const hecho     = ref('')
const alcance         = ref('equipo')
const puntosBonus     = ref<number>(25)
const puntosDemerito  = ref<number>(0)
const cantPersonas    = ref(1)
const advertenciaRef = ref('')
const justificacionGrupal = ref('')
const integranteIds  = ref<string[]>([])
const archivos         = ref<File[]>([])
const fotosBonus       = ref<File[]>([])
const fotosBonusUrls   = ref<string[]>([])
const guardando      = ref(false)
const error          = ref('')

// ── Código seleccionado ────────────────────────────────────────────────────────
const codigoInfo = computed<IncidenciaCodigo | null>(
  () => codigos.value.find((c) => c.codigo === codigoSel.value) ?? null,
)

const codigosFiltrados = computed(() =>
  tipo.value ? codigos.value.filter((c) => c.tipo === tipo.value) : [],
)

// Al cambiar tipo: auto-rellenar hora y auto-seleccionar código
watch(tipo, (t) => {
  const now = new Date()
  hora.value = now.toTimeString().slice(0, 5)
  codigoSel.value = ''
  puntosDemerito.value = 0
  if (t === 'bonus') {
    const primerBonus = codigos.value.find((c) => c.tipo === 'bonus')
    codigoSel.value = primerBonus?.codigo ?? ''
  } else if (t === 'demerito') {
    // Auto-seleccionar primer demerito sin requerimientos especiales
    const primerDemerito = codigos.value.find(
      (c) => c.tipo === 'demerito' && !c.requiere_advertencia && !c.requiere_equipo_apoyado && !c.por_persona
    )
    codigoSel.value = primerDemerito?.codigo ?? ''
    puntosDemerito.value = primerDemerito?.puntos ?? 0
  }
})

// Al cambiar equipo, cargar integrantes
watch(equipoId, async (id) => {
  integrantes.value = []
  integranteIds.value = []
  if (id) integrantes.value = await integrantesService.getPorEquipo(id)
})

// Al cambiar código, resetear campos específicos
watch(codigoSel, (nuevo) => {
  advertenciaRef.value = ''
  justificacionGrupal.value = ''
  cantPersonas.value = 1
  integranteIds.value = []
  const cat = codigos.value.find((c) => c.codigo === nuevo)
  puntosDemerito.value = cat?.puntos ?? 0
})

// D6: actualizar total al cambiar cantidad de personas
watch(cantPersonas, (n) => {
  if (codigoInfo.value?.por_persona) {
    puntosDemerito.value = (codigoInfo.value.puntos ?? 0) * n
  }
})

// ── Validación por paso ───────────────────────────────────────────────────────
const puedeAvanzar = computed(() => {
  switch (paso.value) {
    case 1: return !!tipo.value
    case 2: return !!equipoId.value
    case 3: {
      if (!hora.value || hecho.value.trim().length < 10) return false
      if (tipo.value === 'demerito') {
        if (!puntosDemerito.value || puntosDemerito.value <= 0) return false
      }
      return true
    }
    default: return true
  }
})

// Paso 4 obligatorio para D6
const integrantesObligatorios = computed(() =>
  codigoInfo.value?.codigo === 'D6' && integranteIds.value.length === 0
)

// ── Navegación ────────────────────────────────────────────────────────────────
function avanzar() {
  if (!puedeAvanzar.value) return
  paso.value++
}
function retroceder() { paso.value-- }

// ── Cámara ────────────────────────────────────────────────────────────────────
const camaraActiva  = ref(false)
const camaraError   = ref('')
const videoRef      = ref<HTMLVideoElement | null>(null)
const streamRef     = ref<MediaStream | null>(null)

async function abrirCamara() {
  camaraError.value = ''
  camaraActiva.value = true
  await nextTick()
  try {
    // Intentar cámara trasera primero (móvil/tablet), luego cualquier cámara (laptop)
    let stream: MediaStream
    try {
      stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
    } catch {
      stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    }
    streamRef.value = stream
    if (videoRef.value) {
      videoRef.value.srcObject = stream
    }
  } catch {
    camaraActiva.value = false
    camaraError.value = 'No se pudo acceder a la cámara. Verifica los permisos del navegador.'
  }
}

function cerrarCamara() {
  streamRef.value?.getTracks().forEach((t) => t.stop())
  streamRef.value = null
  camaraActiva.value = false
}

function capturarFoto() {
  if (!videoRef.value) return
  const video = videoRef.value
  const w = video.videoWidth  || video.clientWidth
  const h = video.videoHeight || video.clientHeight
  if (!w || !h) return
  const canvas = document.createElement('canvas')
  canvas.width  = w
  canvas.height = h
  canvas.getContext('2d')!.drawImage(video, 0, 0, w, h)
  canvas.toBlob((blob) => {
    if (blob) {
      const file = new File([blob], `bonus_${Date.now()}.jpg`, { type: 'image/jpeg' })
      fotosBonus.value = [...fotosBonus.value, file]
      fotosBonusUrls.value = [...fotosBonusUrls.value, URL.createObjectURL(blob)]
    }
    cerrarCamara()   // cerrar DESPUÉS de guardar el blob
  }, 'image/jpeg', 0.85)
}

function quitarFotoBonus(i: number) {
  URL.revokeObjectURL(fotosBonusUrls.value[i]!)
  fotosBonus.value    = fotosBonus.value.filter((_, idx) => idx !== i)
  fotosBonusUrls.value = fotosBonusUrls.value.filter((_, idx) => idx !== i)
}

// ── Archivos ──────────────────────────────────────────────────────────────────
function onArchivoChange(e: Event) {
  const input = e.target as HTMLInputElement
  if (input.files) archivos.value = [...archivos.value, ...Array.from(input.files)]
  input.value = ''
}
function quitarArchivo(i: number) {
  archivos.value = archivos.value.filter((_, idx) => idx !== i)
}

// ── Guardar ───────────────────────────────────────────────────────────────────
async function guardar() {
  if (!session.user) return
  guardando.value = true
  error.value = ''

  try {
    const puntos = tipo.value === 'bonus'
      ? puntosBonus.value
      : puntosDemerito.value

    const inc = await incidenciasService.crear({
      codigo: codigoSel.value,
      equipo_id: equipoId.value,
      equipo_apoyado_id: null,
      fecha: fecha.value,
      hora: hora.value,
      hecho: hecho.value.trim(),
      alcance: 'equipo',
      cantidad_personas: 1,
      advertencia_referencia: null,
      justificacion_grupal: null,
      puntos,
      registrado_por: session.user.id,
    })

    // Fotos (bonus y demerito usan la misma cámara)
    for (const foto of fotosBonus.value) {
      await evidenciasService.subir(inc.id, foto, session.user.id)
    }

    router.push(`/panel/incidencias/${inc.id}`)
  } catch (e: any) {
    error.value = e.message ?? 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function toggleIntegrante(id: string) {
  const idx = integranteIds.value.indexOf(id)
  if (idx >= 0) integranteIds.value.splice(idx, 1)
  else integranteIds.value.push(id)
}
function nombreEquipo(id: string) {
  return equipos.value.find((e) => e.id === id)?.nombre ?? ''
}
</script>

<template>
  <div class="wizard">
    <div class="wizard-back">
      <button class="btn-link" @click="router.back()">← Volver</button>
      <h1 class="wizard-title">Nueva incidencia</h1>
    </div>

    <!-- Indicador de pasos -->
    <div class="wizard-steps">
      <div
        v-for="p in pasosActivos"
        :key="p.n"
        :class="['step-dot', { 'step-dot--active': paso === p.n, 'step-dot--done': paso > p.n }]"
      >
        <span class="step-dot__n">{{ paso > p.n ? '✓' : p.n }}</span>
        <span class="step-dot__label">{{ p.label }}</span>
      </div>
    </div>

    <!-- PASO 1: Tipo -->
    <div v-if="paso === 1" class="wizard-body">
      <h2 class="paso-title">¿Qué tipo de incidencia?</h2>

      <div class="tipo-btns">
        <button
          :class="['tipo-btn', tipo === 'bonus' && 'tipo-btn--active tipo-btn--bonus']"
          @click="tipo = 'bonus'"
        >
          <i class="pi pi-star-fill" />
          <span>Bonus</span>
          <small>+50 pts máx.</small>
        </button>
        <button
          :class="['tipo-btn', tipo === 'demerito' && 'tipo-btn--active tipo-btn--demerito']"
          @click="tipo = 'demerito'"
        >
          <i class="pi pi-exclamation-triangle" />
          <span>Demérito</span>
          <small>D1–D6</small>
        </button>
      </div>
    </div>

    <!-- PASO 2: Equipo -->
    <div v-else-if="paso === 2" class="wizard-body">
      <h2 class="paso-title">¿Qué equipo?</h2>

      <div class="campo-grupo">
        <label class="campo-label">Equipo involucrado</label>
        <select v-model="equipoId" class="campo-input">
          <option value="">— Selecciona —</option>
          <option v-for="e in equipos" :key="e.id" :value="e.id">{{ e.nombre }}</option>
        </select>
      </div>

      <div v-if="codigoInfo?.requiere_equipo_apoyado" class="campo-grupo">
        <label class="campo-label">Equipo que recibió el apoyo (B2)</label>
        <select v-model="equipoApId" class="campo-input">
          <option value="">— Selecciona —</option>
          <option
            v-for="e in equipos.filter((x) => x.id !== equipoId)"
            :key="e.id" :value="e.id"
          >{{ e.nombre }}</option>
        </select>
      </div>
    </div>

    <!-- PASO 3: Detalles — Bonus -->
    <div v-else-if="paso === 3 && tipo === 'bonus'" class="wizard-body">
      <h2 class="paso-title">¿Cuándo y qué pasó?</h2>

      <div class="campo-grupo">
        <label class="campo-label">Nombre / Tipo de incidencia <small>(min. 10 caracteres)</small></label>
        <textarea v-model="hecho" rows="4" class="campo-input" placeholder="Describe el servicio o cooperación observado…" />
      </div>

      <!-- Captura de foto -->
      <div class="campo-grupo">
        <label class="campo-label">Foto <small>(opcional)</small></label>
        <button type="button" class="camara-btn" @click="abrirCamara">
          <i class="pi pi-camera" />
          <span>Tomar foto</span>
        </button>
        <p v-if="camaraError" class="error-msg">{{ camaraError }}</p>
        <div v-if="fotosBonus.length" class="fotos-preview">
          <div v-for="(_, i) in fotosBonus" :key="i" class="foto-thumb">
            <img :src="fotosBonusUrls[i]" alt="foto" />
            <button class="foto-thumb__quitar" @click="quitarFotoBonus(i)">✕</button>
          </div>
        </div>
      </div>

      <div class="campo-grupo">
        <label class="campo-label">Puntos a aplicar</label>
        <div class="puntos-grid">
          <button
            v-for="pts in [12.5, 25, 50]"
            :key="pts"
            :class="['puntos-btn', puntosBonus === pts && 'puntos-btn--active']"
            @click="puntosBonus = pts"
          >
            <strong>{{ pts }}</strong>
            <span>pts</span>
          </button>
        </div>
      </div>
    </div>

    <!-- PASO 3: Detalles — Deméritos -->
    <div v-else-if="paso === 3 && tipo === 'demerito'" class="wizard-body">
      <h2 class="paso-title">¿Cuándo y qué pasó?</h2>

      <div class="campo-grupo">
        <label class="campo-label">Nombre / Tipo de incidencia <small>(min. 10 caracteres)</small></label>
        <textarea v-model="hecho" rows="4" class="campo-input" placeholder="Describe el hecho objetivamente…" />
      </div>

      <!-- Captura de foto -->
      <div class="campo-grupo">
        <label class="campo-label">Foto <small>(opcional)</small></label>
        <button type="button" class="camara-btn" @click="abrirCamara">
          <i class="pi pi-camera" />
          <span>Tomar foto</span>
        </button>
        <p v-if="camaraError" class="error-msg">{{ camaraError }}</p>
        <div v-if="fotosBonus.length" class="fotos-preview">
          <div v-for="(_, i) in fotosBonus" :key="i" class="foto-thumb">
            <img :src="fotosBonusUrls[i]" alt="foto" />
            <button class="foto-thumb__quitar" @click="quitarFotoBonus(i)">✕</button>
          </div>
        </div>
      </div>

      <div class="campo-grupo">
        <label class="campo-label">Puntos a aplicar <span class="req">*</span></label>
        <input v-model.number="puntosDemerito" type="number" min="0" step="0.5" class="campo-input" placeholder="Ej. 10" />
      </div>
    </div>

    <!-- PASO 4 (Bonus): Confirmar -->
    <div v-else-if="paso === 4 && tipo === 'bonus'" class="wizard-body">
      <h2 class="paso-title">Confirmar registro</h2>

      <div class="resumen">
        <div class="resumen-fila">
          <span class="resumen-label">Tipo</span>
          <span><span class="badge badge--azul">BONUS</span> {{ codigoInfo?.nombre }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Equipo</span>
          <span>{{ nombreEquipo(equipoId) }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Fecha / Hora</span>
          <span>{{ fecha }} {{ hora }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Nombre</span>
          <span>{{ hecho }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Puntos</span>
          <strong>{{ puntosBonus }} pts</strong>
        </div>
        <div v-if="fotosBonus.length" class="resumen-fila">
          <span class="resumen-label">Fotos</span>
          <span>{{ fotosBonus.length }} foto(s)</span>
        </div>
        <div class="resumen-fila resumen-fila--nota">
          <span class="resumen-label">Estado</span>
          <span class="badge badge--gris">Registrado (pendiente de validación)</span>
        </div>
      </div>

      <div v-if="error" class="error-msg">{{ error }}</div>
    </div>

    <!-- PASO 4: Confirmar (solo demerito) -->
    <div v-else-if="paso === 4 && tipo === 'demerito'" class="wizard-body">
      <h2 class="paso-title">Confirmar registro</h2>

      <div class="resumen">
        <div class="resumen-fila">
          <span class="resumen-label">Tipo</span>
          <span><span class="badge badge--naranja">{{ codigoSel }}</span> {{ codigoInfo?.nombre }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Equipo</span>
          <span>{{ nombreEquipo(equipoId) }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Fecha / Hora</span>
          <span>{{ fecha }} {{ hora }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Descripción</span>
          <span>{{ hecho }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Puntos</span>
          <strong>−{{ puntosDemerito }} pts</strong>
        </div>
        <div v-if="fotosBonus.length" class="resumen-fila">
          <span class="resumen-label">Fotos</span>
          <span>{{ fotosBonus.length }} foto(s)</span>
        </div>
        <div class="resumen-fila resumen-fila--nota">
          <span class="resumen-label">Estado</span>
          <span class="badge badge--gris">Registrado (pendiente de validación)</span>
        </div>
      </div>

      <div v-if="error" class="error-msg">{{ error }}</div>
    </div>

    <!-- Navegación -->
    <div class="wizard-nav">
      <button v-if="paso > 1" class="btn btn--ghost" :disabled="guardando" @click="retroceder">
        ← Anterior
      </button>
      <div class="wizard-nav__right">
        <button
          v-if="paso < pasoFinal"
          class="btn btn--primary"
          :disabled="!puedeAvanzar"
          @click="avanzar"
        >
          Siguiente →
        </button>
        <button
          v-else
          class="btn btn--primary"
          :disabled="guardando"
          @click="guardar"
        >
          <i v-if="guardando" class="pi pi-spin pi-spinner" />
          {{ guardando ? 'Guardando…' : 'Registrar incidencia' }}
        </button>
      </div>
    </div>
  </div>

  <!-- Modal cámara -->
  <teleport to="body">
    <div v-if="camaraActiva" class="camara-overlay">
      <div class="camara-modal">
        <video ref="videoRef" autoplay playsinline class="camara-video" />
        <div class="camara-modal__btns">
          <button type="button" class="btn btn--ghost" @click="cerrarCamara">Cancelar</button>
          <button type="button" class="btn btn--primary camara-capturar" @click="capturarFoto">
            <i class="pi pi-camera" /> Capturar
          </button>
        </div>
      </div>
    </div>
  </teleport>
</template>

<style scoped>
.wizard {
  max-width: 600px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* ── Header ── */
.wizard-back {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}
.wizard-title { font-size: 1.2rem; font-weight: 800; margin: 0; }
.btn-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  background: none;
  border: none;
  color: #16a34a;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  padding: 0;
  min-height: 44px;
}
.btn-link:hover { text-decoration: underline; }

/* ── Steps ── */
.wizard-steps {
  display: flex;
  gap: 0;
  margin-bottom: 1.5rem;
  overflow-x: auto;
  padding-bottom: 4px;
}
.step-dot {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.2rem;
  flex: 1;
  min-width: 52px;
  position: relative;
}
.step-dot:not(:last-child)::after {
  content: '';
  position: absolute;
  top: 15px;
  left: calc(50% + 16px);
  right: calc(-50% + 16px);
  height: 2px;
  background: #e5e7eb;
}
.step-dot--done:not(:last-child)::after { background: #16a34a; }

.step-dot__n {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.82rem;
  font-weight: 800;
  background: #e5e7eb;
  color: #9ca3af;
  position: relative;
  z-index: 1;
  transition: all 0.15s;
}
.step-dot--active .step-dot__n { background: #16a34a; color: white; box-shadow: 0 0 0 4px rgba(22,163,74,.2); }
.step-dot--done .step-dot__n   { background: #15803d; color: white; }
.step-dot__label {
  font-size: 0.62rem;
  color: #9ca3af;
  text-align: center;
  line-height: 1.2;
}
.step-dot--active .step-dot__label { color: #16a34a; font-weight: 700; }
.step-dot--done .step-dot__label   { color: #15803d; }

/* ── Body ── */
.wizard-body {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 1.25rem;
  margin-bottom: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,.06);
}
.paso-title { font-size: 1.05rem; font-weight: 800; margin: 0 0 0.75rem; color: #111827; }
.paso-desc  { font-size: 0.88rem; color: #6b7280; margin: 0 0 0.75rem; line-height: 1.45; }

/* ── Tipo botones ── */
.tipo-btns {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.tipo-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  min-height: 96px;
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  background: white;
  cursor: pointer;
  transition: all 0.15s;
}
.tipo-btn i    { font-size: 1.6rem; }
.tipo-btn span { font-weight: 700; font-size: 0.9rem; }
.tipo-btn small { font-size: 0.8rem; color: #9ca3af; }
.tipo-btn:not(.tipo-btn--bonus):not(.tipo-btn--demerito):hover { border-color: #d1d5db; background: #f9fafb; }
.tipo-btn--bonus    { border-color: #16a34a; background: #f0fdf4; }
.tipo-btn--bonus i  { color: #16a34a; }
.tipo-btn--demerito { border-color: #dc2626; background: #fef2f2; }
.tipo-btn--demerito i { color: #dc2626; }

/* ── Código grid ── */
.codigo-grid { display: flex; flex-direction: column; gap: 0.5rem; }
.codigo-btn {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-height: 54px;
  padding: 0.65rem 0.85rem;
  border: 2px solid #e5e7eb;
  border-radius: 10px;
  background: white;
  cursor: pointer;
  text-align: left;
  transition: all 0.15s;
}
.codigo-btn:hover { border-color: #d1d5db; background: #f9fafb; }
.codigo-btn strong { min-width: 34px; font-size: 0.9rem; color: #111827; }
.codigo-btn span   { flex: 1; font-size: 0.88rem; color: #374151; }
.codigo-btn em     { font-size: 0.8rem; color: #9ca3af; font-style: normal; white-space: nowrap; }
.codigo-btn--active { border-color: #16a34a; background: #f0fdf4; }
.codigo-btn--active strong { color: #15803d; }

/* Info box */
.codigo-info-box {
  margin-top: 0.75rem;
  padding: 0.75rem;
  background: #f0fdf4;
  border: 1px solid #dcfce7;
  border-radius: 8px;
  font-size: 0.82rem;
  color: #374151;
}
.codigo-info-box p { margin: 0.2rem 0; }
.info--advertencia { color: #b45309; }
.info--b2 { color: #15803d; }

/* ── Campos ── */
.campo-grupo { margin-bottom: 1rem; }
.campo-label {
  display: block;
  font-size: 0.8rem;
  font-weight: 700;
  color: #374151;
  margin-bottom: 0.3rem;
}
.campo-input {
  width: 100%;
  min-height: 48px;
  padding: 0.55rem 0.7rem;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  font-size: 0.95rem;
  background: white;
  box-sizing: border-box;
  transition: border-color 0.15s;
}
.campo-input:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
textarea.campo-input { resize: vertical; min-height: 88px; }
.campo-hint { font-size: 0.8rem; color: #6b7280; margin-top: 0.25rem; display: block; }
.req { color: #dc2626; }

/* ── Integrantes ── */
.integrantes-grid { display: flex; flex-direction: column; gap: 0.5rem; }
.integrante-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 52px;
  padding: 0.6rem 0.85rem;
  border: 2px solid #e5e7eb;
  border-radius: 10px;
  background: white;
  cursor: pointer;
  font-size: 0.9rem;
  text-align: left;
  transition: all 0.15s;
}
.integrante-btn:hover { border-color: #d1d5db; background: #f9fafb; }
.integrante-btn--sel { border-color: #16a34a; background: #f0fdf4; font-weight: 600; }
.integrante-btn--sel::before {
  content: '✓';
  color: #16a34a;
  font-weight: 900;
  margin-right: 0.25rem;
}
.integrante-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.tag-expulsado {
  font-size: 0.7rem;
  background: #fee2e2;
  color: #991b1b;
  border-radius: 4px;
  padding: 0.1rem 0.35rem;
  margin-left: auto;
  font-weight: 600;
}

/* ── Upload ── */
.upload-area {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 2rem 1.5rem;
  border: 2px dashed #d1d5db;
  border-radius: 12px;
  cursor: pointer;
  text-align: center;
  margin-bottom: 1rem;
  transition: all 0.15s;
  background: #fafafa;
}
.upload-area:hover { border-color: #16a34a; background: #f0fdf4; }
.upload-area input  { display: none; }
.upload-area i      { font-size: 2rem; color: #9ca3af; }
.upload-area span   { font-size: 0.9rem; color: #374151; font-weight: 600; }
.upload-area small  { font-size: 0.8rem; color: #9ca3af; }

.archivos-lista { display: flex; flex-direction: column; gap: 0.4rem; }
.archivo-chip {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.65rem;
  background: #f0fdf4;
  border: 1px solid #dcfce7;
  border-radius: 8px;
  font-size: 0.82rem;
}
.archivo-chip__nombre { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.archivo-chip__quitar {
  background: none;
  border: none;
  cursor: pointer;
  color: #9ca3af;
  font-size: 0.85rem;
  min-height: 32px;
  min-width: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
}
.archivo-chip__quitar:hover { background: #fee2e2; color: #dc2626; }

/* ── Resumen ── */
.resumen { display: flex; flex-direction: column; gap: 0; }
.resumen-fila {
  display: flex;
  gap: 0.75rem;
  font-size: 0.88rem;
  align-items: flex-start;
  padding: 0.55rem 0;
  border-bottom: 1px solid #f3f4f6;
}
.resumen-fila:last-child { border-bottom: none; }
.resumen-label {
  min-width: 110px;
  font-weight: 700;
  color: #6b7280;
  flex-shrink: 0;
  font-size: 0.8rem;
}

/* ── Badges ── */
.badge {
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.15rem 0.45rem;
  text-transform: uppercase;
  white-space: nowrap;
}
.badge--azul    { background: #dcfce7; color: #166534; }
.badge--naranja { background: #fed7aa; color: #c2410c; }
.badge--gris    { background: #f3f4f6; color: #374151; }

/* ── Navegación ── */
.wizard-nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
  gap: 0.5rem;
}
.wizard-nav__right { margin-left: auto; }

/* ── Botones ── */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 48px;
  padding: 0.55rem 1.2rem;
  border-radius: 8px;
  border: none;
  font-size: 0.95rem;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.15s, transform 0.1s;
}
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover:not(:disabled) { background: #15803d; }
.btn--primary:active:not(:disabled) { transform: scale(0.98); }
.btn--primary:disabled { opacity: 0.45; cursor: not-allowed; }
.btn--ghost { background: transparent; color: #374151; border: 1px solid #d1d5db; }
.btn--ghost:hover:not(:disabled) { background: #f0fdf4; }
.btn--ghost:disabled { opacity: 0.5; }

.error-msg { color: #dc2626; font-size: 0.83rem; margin-top: 0.5rem; }

/* ── Cámara bonus ── */
.camara-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 48px;
  padding: 0.6rem 1.1rem;
  border: 2px solid #16a34a;
  border-radius: 10px;
  background: #f0fdf4;
  color: #15803d;
  font-size: 0.9rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.15s;
}
.camara-btn:hover { background: #dcfce7; }
.camara-btn i { font-size: 1.2rem; }


.fotos-preview {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.6rem;
}
.foto-thumb {
  position: relative;
  width: 80px;
  height: 80px;
  border-radius: 8px;
  overflow: hidden;
  border: 2px solid #d1d5db;
}
.foto-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.foto-thumb__quitar {
  position: absolute;
  top: 2px;
  right: 2px;
  background: rgba(0,0,0,.55);
  color: white;
  border: none;
  border-radius: 4px;
  width: 22px;
  height: 22px;
  font-size: 0.7rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* ── Puntos bonus ── */
.puntos-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.6rem;
}
.puntos-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.2rem;
  min-height: 64px;
  padding: 0.75rem;
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  background: white;
  cursor: pointer;
  transition: all 0.15s;
}
.puntos-btn strong { font-size: 1.3rem; color: #111827; }
.puntos-btn span   { font-size: 0.75rem; color: #9ca3af; font-weight: 600; }
.puntos-btn:hover  { border-color: #d1d5db; background: #f9fafb; }
.puntos-btn--active { border-color: #16a34a; background: #f0fdf4; }
.puntos-btn--active strong { color: #15803d; }
.puntos-btn--active span   { color: #16a34a; }
</style>

<!-- Estilos globales para el modal de cámara (teleport sale del scoped) -->
<style>
.camara-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.88);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}
.camara-modal {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  max-width: 480px;
}
.camara-video {
  width: 100%;
  border-radius: 12px;
  background: #000;
  max-height: 60dvh;
  object-fit: cover;
}
.camara-modal__btns {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
}
.camara-capturar { min-width: 140px; justify-content: center; }
</style>
