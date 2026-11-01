<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
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
const PASOS = [
  { n: 1, label: 'Tipo y código' },
  { n: 2, label: 'Equipo' },
  { n: 3, label: 'Detalles' },
  { n: 4, label: 'Integrantes' },
  { n: 5, label: 'Evidencia' },
  { n: 6, label: 'Confirmar' },
]

// ── Formulario ────────────────────────────────────────────────────────────────
const tipo      = ref<'bonus' | 'demerito' | ''>('')
const codigoSel = ref('')
const equipoId  = ref('')
const equipoApId = ref('')
const fecha     = ref('')
const hora      = ref('')
const hecho     = ref('')
const alcance   = ref('equipo')
const cantPersonas = ref(1)
const advertenciaRef = ref('')
const justificacionGrupal = ref('')
const integranteIds  = ref<string[]>([])
const archivos       = ref<File[]>([])
const guardando      = ref(false)
const error          = ref('')
const incidenciaCreada = ref('')

// ── Código seleccionado ────────────────────────────────────────────────────────
const codigoInfo = computed<IncidenciaCodigo | null>(
  () => codigos.value.find((c) => c.codigo === codigoSel.value) ?? null,
)

const codigosFiltrados = computed(() =>
  tipo.value ? codigos.value.filter((c) => c.tipo === tipo.value) : [],
)

// Al cambiar equipo, cargar integrantes
watch(equipoId, async (id) => {
  integrantes.value = []
  integranteIds.value = []
  if (id) integrantes.value = await integrantesService.getPorEquipo(id)
})

// Al cambiar código, resetear campos específicos
watch(codigoSel, () => {
  advertenciaRef.value = ''
  justificacionGrupal.value = ''
  cantPersonas.value = 1
  integranteIds.value = []
})

// ── Validación por paso ───────────────────────────────────────────────────────
const puedeAvanzar = computed(() => {
  switch (paso.value) {
    case 1: return !!tipo.value && !!codigoSel.value
    case 2: {
      if (!equipoId.value) return false
      if (codigoInfo.value?.requiere_equipo_apoyado && !equipoApId.value) return false
      return true
    }
    case 3: {
      if (!fecha.value || !hora.value || hecho.value.trim().length < 10) return false
      if (codigoInfo.value?.requiere_advertencia && !advertenciaRef.value.trim()) return false
      return true
    }
    case 4: return true  // integrantes opcionales excepto D6
    case 5: return true  // evidencia opcional
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
  if (paso.value === 4 && integrantesObligatorios.value) return
  paso.value++
}
function retroceder() { paso.value-- }

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
    // 1. Crear incidencia
    const puntos = codigoInfo.value!.por_persona
      ? codigoInfo.value!.puntos * cantPersonas.value
      : codigoInfo.value!.puntos

    const inc = await incidenciasService.crear({
      codigo: codigoSel.value,
      equipo_id: equipoId.value,
      equipo_apoyado_id: codigoInfo.value?.requiere_equipo_apoyado ? equipoApId.value : null,
      fecha: fecha.value,
      hora: hora.value,
      hecho: hecho.value.trim(),
      alcance: alcance.value,
      cantidad_personas: cantPersonas.value,
      advertencia_referencia: codigoInfo.value?.requiere_advertencia ? advertenciaRef.value.trim() || null : null,
      justificacion_grupal: justificacionGrupal.value.trim() || null,
      puntos,
      registrado_por: session.user.id,
    })

    incidenciaCreada.value = inc.id

    // 2. Integrantes
    if (integranteIds.value.length) {
      await incidenciaIntegrantesService.setPorIncidencia(inc.id, integranteIds.value)
    }

    // 3. Evidencias
    for (const arch of archivos.value) {
      await evidenciasService.subir(inc.id, arch, session.user.id)
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
        v-for="p in PASOS"
        :key="p.n"
        :class="['step-dot', { 'step-dot--active': paso === p.n, 'step-dot--done': paso > p.n }]"
      >
        <span class="step-dot__n">{{ paso > p.n ? '✓' : p.n }}</span>
        <span class="step-dot__label">{{ p.label }}</span>
      </div>
    </div>

    <!-- PASO 1: Tipo y código -->
    <div v-if="paso === 1" class="wizard-body">
      <h2 class="paso-title">¿Qué tipo de incidencia?</h2>

      <div class="tipo-btns">
        <button
          :class="['tipo-btn', tipo === 'bonus' && 'tipo-btn--active tipo-btn--bonus']"
          @click="tipo = 'bonus'; codigoSel = ''"
        >
          <i class="pi pi-star-fill" />
          <span>Bonus</span>
          <small>B1, B2</small>
        </button>
        <button
          :class="['tipo-btn', tipo === 'demerito' && 'tipo-btn--active tipo-btn--demerito']"
          @click="tipo = 'demerito'; codigoSel = ''"
        >
          <i class="pi pi-exclamation-triangle" />
          <span>Demérito</span>
          <small>D1–D6</small>
        </button>
      </div>

      <div v-if="tipo" class="campo-grupo">
        <label class="campo-label">Código</label>
        <div class="codigo-grid">
          <button
            v-for="c in codigosFiltrados"
            :key="c.codigo"
            :class="['codigo-btn', codigoSel === c.codigo && 'codigo-btn--active']"
            @click="codigoSel = c.codigo"
          >
            <strong>{{ c.codigo }}</strong>
            <span>{{ c.nombre }}</span>
            <em>{{ c.por_persona ? `${c.puntos} pts/persona` : `${c.puntos} pts` }}</em>
          </button>
        </div>
      </div>

      <div v-if="codigoInfo" class="codigo-info-box">
        <p v-if="codigoInfo.tope_equipo">Tope por equipo: <strong>{{ codigoInfo.tope_equipo }} pts</strong></p>
        <p v-if="codigoInfo.max_acciones">Máx. acciones: <strong>{{ codigoInfo.max_acciones }}</strong></p>
        <p v-if="codigoInfo.requiere_advertencia" class="info--advertencia">
          ⚠ Requiere referencia a la advertencia previa
        </p>
        <p v-if="codigoInfo.requiere_equipo_apoyado" class="info--b2">
          ℹ Requiere seleccionar el equipo apoyado
        </p>
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

    <!-- PASO 3: Detalles -->
    <div v-else-if="paso === 3" class="wizard-body">
      <h2 class="paso-title">¿Cuándo y qué pasó?</h2>

      <div class="campo-grupo">
        <label class="campo-label">Fecha</label>
        <input v-model="fecha" type="date" class="campo-input" />
      </div>
      <div class="campo-grupo">
        <label class="campo-label">Hora</label>
        <input v-model="hora" type="time" class="campo-input" />
      </div>
      <div class="campo-grupo">
        <label class="campo-label">Hecho <small>(min. 10 caracteres)</small></label>
        <textarea v-model="hecho" rows="4" class="campo-input" placeholder="Describe el hecho objetivamente…" />
      </div>
      <div class="campo-grupo">
        <label class="campo-label">Alcance</label>
        <select v-model="alcance" class="campo-input">
          <option value="equipo">Equipo completo</option>
          <option value="integrantes">Integrantes específicos</option>
        </select>
      </div>

      <div v-if="codigoInfo?.codigo === 'D6'" class="campo-grupo">
        <label class="campo-label">Cantidad de personas involucradas</label>
        <input v-model.number="cantPersonas" type="number" min="1" class="campo-input" />
        <small class="campo-hint">Puntos: {{ codigoInfo.puntos }} × {{ cantPersonas }} = {{ codigoInfo.puntos * cantPersonas }} pts</small>
      </div>

      <div v-if="codigoInfo?.requiere_advertencia" class="campo-grupo">
        <label class="campo-label">Referencia a la advertencia previa <span class="req">*</span></label>
        <input v-model="advertenciaRef" type="text" class="campo-input" placeholder="Hora y contexto de la advertencia…" />
      </div>

      <div class="campo-grupo">
        <label class="campo-label">Justificación / contexto grupal <small>(opcional)</small></label>
        <textarea v-model="justificacionGrupal" rows="2" class="campo-input" placeholder="Contexto adicional…" />
      </div>
    </div>

    <!-- PASO 4: Integrantes -->
    <div v-else-if="paso === 4" class="wizard-body">
      <h2 class="paso-title">Integrantes involucrados</h2>
      <p class="paso-desc">
        <template v-if="codigoInfo?.codigo === 'D6'">
          D6 — Alcohol: selecciona a las personas involucradas
          <strong class="req">(obligatorio)</strong>.
        </template>
        <template v-else>
          Opcional. Selecciona si la incidencia afecta a personas específicas.
        </template>
      </p>

      <div v-if="integrantes.length" class="integrantes-grid">
        <button
          v-for="ing in integrantes"
          :key="ing.id"
          :class="['integrante-btn', integranteIds.includes(ing.id) && 'integrante-btn--sel']"
          :disabled="(ing as any).expulsado"
          @click="toggleIntegrante(ing.id)"
        >
          {{ ing.apellidos }}, {{ ing.nombres }}
          <span v-if="(ing as any).expulsado" class="tag-expulsado">expulsado</span>
        </button>
      </div>
      <p v-else class="paso-desc">
        <template v-if="equipoId">Cargando integrantes…</template>
        <template v-else>Primero selecciona un equipo.</template>
      </p>

      <p v-if="integrantesObligatorios" class="error-msg">
        Para D6 debes seleccionar al menos un integrante.
      </p>
    </div>

    <!-- PASO 5: Evidencia -->
    <div v-else-if="paso === 5" class="wizard-body">
      <h2 class="paso-title">Evidencia <small>(opcional)</small></h2>

      <label class="upload-area">
        <input type="file" accept="image/*,application/pdf" multiple @change="onArchivoChange" />
        <i class="pi pi-upload" />
        <span>Toca para adjuntar fotos o PDF</span>
        <small>JPG, PNG, WEBP, HEIC, PDF — máx. 10 MB c/u</small>
      </label>

      <div v-if="archivos.length" class="archivos-lista">
        <div v-for="(a, i) in archivos" :key="i" class="archivo-chip">
          <i :class="a.type.startsWith('image') ? 'pi pi-image' : 'pi pi-file-pdf'" />
          <span class="archivo-chip__nombre">{{ a.name }}</span>
          <button class="archivo-chip__quitar" @click="quitarArchivo(i)">✕</button>
        </div>
      </div>
    </div>

    <!-- PASO 6: Confirmar -->
    <div v-else-if="paso === 6" class="wizard-body">
      <h2 class="paso-title">Confirmar registro</h2>

      <div class="resumen">
        <div class="resumen-fila">
          <span class="resumen-label">Tipo / Código</span>
          <span>
            <span :class="['badge', tipo === 'bonus' ? 'badge--azul' : 'badge--naranja']">{{ codigoSel }}</span>
            {{ codigoInfo?.nombre }}
          </span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Equipo</span>
          <span>{{ nombreEquipo(equipoId) }}</span>
        </div>
        <div v-if="equipoApId" class="resumen-fila">
          <span class="resumen-label">Equipo apoyado</span>
          <span>{{ nombreEquipo(equipoApId) }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Fecha / Hora</span>
          <span>{{ fecha }} {{ hora }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Hecho</span>
          <span>{{ hecho }}</span>
        </div>
        <div class="resumen-fila">
          <span class="resumen-label">Puntos</span>
          <strong>{{ codigoInfo?.por_persona ? codigoInfo.puntos * cantPersonas : codigoInfo?.puntos }} pts</strong>
        </div>
        <div v-if="integranteIds.length" class="resumen-fila">
          <span class="resumen-label">Integrantes</span>
          <span>{{ integranteIds.length }} seleccionado(s)</span>
        </div>
        <div v-if="archivos.length" class="resumen-fila">
          <span class="resumen-label">Evidencia</span>
          <span>{{ archivos.length }} archivo(s)</span>
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
          v-if="paso < 6"
          class="btn btn--primary"
          :disabled="!puedeAvanzar || (paso === 4 && integrantesObligatorios)"
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
/* connector line between dots */
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
</style>
