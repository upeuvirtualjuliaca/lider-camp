<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  indicadoresService,
  type LiderazgoIndicador,
} from '@/modules/liderazgo/services/liderazgo.service'
import type { TablesUpdate } from '@/types/database'

// ── Estado ────────────────────────────────────────────────────────────────────
const cargando   = ref(true)
const error      = ref('')
const indicadores = ref<LiderazgoIndicador[]>([])

const sumaActivos = computed(() =>
  indicadores.value.filter(i => i.activo).reduce((a, i) => a + i.puntaje_max, 0),
)
const sumaOk = computed(() => sumaActivos.value === 100)

// ── Panel crear/editar ────────────────────────────────────────────────────────
const panelOpen  = ref(false)
const guardando  = ref(false)
const errGuardar = ref('')
const esEdicion  = computed(() => !!form.value.id)

interface FormInd {
  id: string | null
  codigo: string
  nombre: string
  descripcion: string
  evidencia: string
  puntaje_max: number
  orden: number
  activo: boolean
}

const form = ref<FormInd>({
  id: null, codigo: '', nombre: '', descripcion: '',
  evidencia: '', puntaje_max: 25, orden: 1, activo: true,
})

const formValido = computed(() =>
  form.value.nombre.trim() !== '' &&
  form.value.descripcion.trim() !== '' &&
  form.value.evidencia.trim() !== '' &&
  form.value.puntaje_max > 0 &&
  (esEdicion.value || form.value.codigo.trim() !== ''),
)

// ── Modal ayuda ───────────────────────────────────────────────────────────────
const ayudaOpen = ref(false)

// ── Carga ─────────────────────────────────────────────────────────────────────
onMounted(cargar)

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    indicadores.value = await indicadoresService.getAll()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar indicadores'
  } finally {
    cargando.value = false
  }
}

// ── CRUD ──────────────────────────────────────────────────────────────────────
function abrirNuevo() {
  const maxOrden = indicadores.value.reduce((a, i) => Math.max(a, i.orden), 0)
  form.value = {
    id: null, codigo: '', nombre: '', descripcion: '',
    evidencia: '', puntaje_max: 25, orden: maxOrden + 1, activo: true,
  }
  errGuardar.value = ''
  panelOpen.value  = true
}

function abrirEditar(ind: LiderazgoIndicador) {
  form.value = {
    id: ind.id, codigo: ind.codigo, nombre: ind.nombre,
    descripcion: ind.descripcion, evidencia: ind.evidencia,
    puntaje_max: ind.puntaje_max, orden: ind.orden, activo: ind.activo,
  }
  errGuardar.value = ''
  panelOpen.value  = true
}

async function guardar() {
  guardando.value  = true
  errGuardar.value = ''
  try {
    if (form.value.id) {
      const datos: TablesUpdate<'liderazgo_indicadores'> = {
        nombre: form.value.nombre,
        descripcion: form.value.descripcion,
        evidencia: form.value.evidencia,
        puntaje_max: form.value.puntaje_max,
        orden: form.value.orden,
        activo: form.value.activo,
      }
      await indicadoresService.actualizar(form.value.id, datos)
    } else {
      await indicadoresService.upsert({
        codigo: form.value.codigo,
        nombre: form.value.nombre,
        descripcion: form.value.descripcion,
        evidencia: form.value.evidencia,
        puntaje_max: form.value.puntaje_max,
        orden: form.value.orden,
        activo: form.value.activo,
      })
    }
    panelOpen.value = false
    await cargar()
  } catch (e: unknown) {
    errGuardar.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div class="ind-page">

    <!-- ── Header ── -->
    <header class="ind-header">
      <div>
        <h1 class="ind-title">Indicadores de Liderazgo</h1>
        <p class="ind-sub">Configuración del criterio de liderazgo</p>
      </div>
      <div class="ind-header-actions">
        <button class="btn-ayuda" title="¿Cómo funciona?" @click="ayudaOpen = true">
          <i class="pi pi-question-circle" />
        </button>
        <button v-if="!cargando" class="btn btn--primary" @click="abrirNuevo">
          <i class="pi pi-plus" /> Nuevo
        </button>
      </div>
    </header>

    <!-- ── Aviso provisional ── -->
    <div class="ind-aviso">
      <i class="pi pi-exclamation-triangle" />
      <span>Los indicadores son <strong>provisionales</strong>. Confirma con el equipo organizador antes de iniciar evaluaciones.</span>
    </div>

    <!-- ── Barra de validación ── -->
    <div v-if="!cargando" :class="['ind-suma', sumaOk ? 'ind-suma--ok' : 'ind-suma--err']">
      <i :class="['pi', sumaOk ? 'pi-check-circle' : 'pi-times-circle']" />
      <span>
        Suma de activos: <strong>{{ sumaActivos }} / 100 pts</strong>
        <template v-if="!sumaOk"> — debe ser exactamente 100</template>
      </span>
    </div>

    <!-- ── Cargando / Error ── -->
    <div v-if="cargando" class="ind-empty">
      <i class="pi pi-spin pi-spinner" style="font-size:1.5rem" />
    </div>
    <div v-else-if="error" class="ind-empty ind-empty--error">
      <i class="pi pi-exclamation-circle" /> {{ error }}
    </div>

    <!-- ── Lista de indicadores ── -->
    <div v-else class="ind-lista">
      <div
        v-for="ind in indicadores"
        :key="ind.id"
        :class="['ind-card', !ind.activo && 'ind-card--inactivo']"
      >
        <div class="ind-card__top">
          <div class="ind-card__left">
            <span class="ind-badge-codigo">{{ ind.codigo }}</span>
            <div>
              <p class="ind-card__nombre">{{ ind.nombre }}</p>
              <p class="ind-card__desc">{{ ind.descripcion }}</p>
            </div>
          </div>
          <button class="btn-editar" @click="abrirEditar(ind)" title="Editar">
            <i class="pi pi-pencil" />
          </button>
        </div>

        <div class="ind-card__footer">
          <span class="ind-card__pts">
            <i class="pi pi-star" /> {{ ind.puntaje_max }} pts/día
          </span>
          <span class="ind-card__orden">Orden {{ ind.orden }}</span>
          <span :class="['ind-badge-estado', ind.activo ? 'ind-badge-estado--on' : 'ind-badge-estado--off']">
            {{ ind.activo ? 'Activo' : 'Inactivo' }}
          </span>
        </div>

        <!-- Evidencia colapsable -->
        <details class="ind-evidencia">
          <summary>¿Cómo se verifica?</summary>
          <p>{{ ind.evidencia }}</p>
        </details>
      </div>

      <div v-if="!indicadores.length" class="ind-empty">
        <i class="pi pi-list" style="font-size:2rem; opacity:.3" />
        <span>Sin indicadores registrados. Crea el primero.</span>
      </div>
    </div>

  </div>

  <!-- ═══ Panel crear / editar ═══ -->
  <Teleport to="body">
    <Transition enter-active-class="m-ea" leave-active-class="m-la" enter-from-class="m-f" leave-to-class="m-f">
      <div v-if="panelOpen" class="m-overlay">
        <div class="m-backdrop" @click="panelOpen = false" />
        <div class="m-panel">

          <div class="m-head">
            <h2 class="m-title">{{ esEdicion ? 'Editar indicador' : 'Nuevo indicador' }}</h2>
            <button class="m-close" @click="panelOpen = false"><i class="pi pi-times" /></button>
          </div>

          <div class="m-body">
            <div v-if="errGuardar" class="m-error">
              <i class="pi pi-exclamation-circle" /> {{ errGuardar }}
            </div>

            <div v-if="!esEdicion" class="campo-g">
              <label class="campo-l">Código <span class="req">*</span></label>
              <input v-model="form.codigo" type="text" class="campo-i" placeholder="Ej: L5" :disabled="guardando" />
            </div>
            <div v-else class="campo-g">
              <label class="campo-l">Código</label>
              <div class="campo-readonly">{{ form.codigo }}</div>
            </div>

            <div class="campo-g">
              <label class="campo-l">Nombre <span class="req">*</span></label>
              <input v-model="form.nombre" type="text" class="campo-i" placeholder="Nombre del indicador" :disabled="guardando" />
            </div>

            <div class="campo-g">
              <label class="campo-l">Descripción <span class="req">*</span></label>
              <textarea v-model="form.descripcion" rows="2" class="campo-i" placeholder="¿Qué evalúa este indicador?" :disabled="guardando" />
            </div>

            <div class="campo-g">
              <label class="campo-l">Evidencia <span class="req">*</span></label>
              <textarea v-model="form.evidencia" rows="2" class="campo-i" placeholder="¿Cómo se verifica?" :disabled="guardando" />
            </div>

            <div class="campo-fila">
              <div class="campo-g">
                <label class="campo-l">Pts máx <span class="req">*</span></label>
                <input
                  v-model.number="form.puntaje_max"
                  type="number" min="1" max="100"
                  class="campo-i"
                  :disabled="guardando || esEdicion"
                />
                <small v-if="esEdicion" class="campo-hint">No editable si ya hay evaluaciones</small>
              </div>
              <div class="campo-g">
                <label class="campo-l">Orden</label>
                <input v-model.number="form.orden" type="number" min="1" class="campo-i" :disabled="guardando" />
              </div>
            </div>

            <div class="campo-g campo-g--row">
              <label class="campo-l">Activo</label>
              <button
                :class="['toggle', form.activo && 'toggle--on']"
                :disabled="guardando"
                @click="form.activo = !form.activo"
              >
                <span class="toggle__thumb" />
              </button>
            </div>
          </div>

          <div class="m-foot">
            <button class="btn btn--ghost" :disabled="guardando" @click="panelOpen = false">Cancelar</button>
            <button class="btn btn--primary" :disabled="!formValido || guardando" @click="guardar">
              <i v-if="guardando" class="pi pi-spin pi-spinner" />
              {{ guardando ? 'Guardando…' : 'Guardar' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- ═══ Modal ¿Cómo funciona? ═══ -->
  <Teleport to="body">
    <Transition enter-active-class="m-ea" leave-active-class="m-la" enter-from-class="m-f" leave-to-class="m-f">
      <div v-if="ayudaOpen" class="m-overlay">
        <div class="m-backdrop" @click="ayudaOpen = false" />
        <div class="m-panel">
          <div class="m-head">
            <div class="m-head__left">
              <div class="m-icon"><i class="pi pi-question-circle" /></div>
              <h2 class="m-title">¿Cómo funciona?</h2>
            </div>
            <button class="m-close" @click="ayudaOpen = false"><i class="pi pi-times" /></button>
          </div>

          <div class="m-body">
            <p class="m-intro">
              El liderazgo se evalúa cada día del campamento con <strong>4 indicadores</strong>,
              cada uno de hasta <strong>25 pts</strong>. Total: 100 pts/día × 4 días = 400 pts máx.
            </p>

            <div class="m-pasos">
              <div class="m-paso">
                <div class="m-paso__n">1</div>
                <div>
                  <p class="m-paso__t">Configura los indicadores aquí</p>
                  <p class="m-paso__d">Define qué se evalúa, cómo se verifica y cuántos puntos vale cada indicador. La suma de activos debe ser exactamente 100.</p>
                </div>
              </div>
              <div class="m-paso">
                <div class="m-paso__n">2</div>
                <div>
                  <p class="m-paso__t">El evaluador califica en campo</p>
                  <p class="m-paso__d">Desde la pantalla de evaluación, selecciona un nivel (0–4) por indicador y equipo. Cada nivel corresponde a un porcentaje del puntaje máximo.</p>
                </div>
              </div>
              <div class="m-paso">
                <div class="m-paso__n m-paso__n--ok">3</div>
                <div>
                  <p class="m-paso__t">El puntaje se calcula automáticamente</p>
                  <p class="m-paso__d">La base de datos suma los puntajes diarios y los incluye en el ranking en tiempo real.</p>
                </div>
              </div>
            </div>

            <div class="m-info-box">
              <p class="m-info-box__tit">Escala de niveles</p>
              <div v-for="(desc, n) in { 4: 'Cumple todo con autonomía', 3: 'Cumple lo esencial, omisión menor', 2: 'Cumple parcialmente', 1: 'Avance mínimo', 0: 'No realiza' }" :key="n" class="m-nivel-fila">
                <span class="m-nivel-badge">Nivel {{ n }}</span>
                <span>{{ desc }}</span>
              </div>
            </div>

            <div class="m-nota">
              <i class="pi pi-info-circle" />
              <span>Si un indicador aún no tiene nivel asignado, no cuenta en el puntaje del día. Todos los indicadores deben evaluarse para que el día quede completo.</span>
            </div>
          </div>

          <div class="m-foot">
            <button class="btn btn--primary btn--full" @click="ayudaOpen = false">Entendido</button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* ─── Page ─── */
.ind-page {
  max-width: 700px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* ─── Header ─── */
.ind-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.ind-title { font-size: 1.3rem; font-weight: 800; margin: 0; }
.ind-sub   { font-size: 0.8rem; color: #6b7280; margin: 0.1rem 0 0; }

.ind-header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.btn-ayuda {
  width: 36px; height: 36px;
  border-radius: 50%;
  border: 1px solid #e2e8f0;
  background: white;
  color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 1rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
}
.btn-ayuda:hover { color: #16a34a; border-color: #bbf7d0; }

/* ─── Aviso ─── */
.ind-aviso {
  display: flex;
  align-items: flex-start;
  gap: 0.6rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 10px;
  padding: 0.75rem 1rem;
  font-size: 0.85rem;
  color: #78350f;
  margin-bottom: 0.75rem;
}
.ind-aviso i { color: #d97706; flex-shrink: 0; margin-top: 0.1rem; }

/* ─── Suma de validación ─── */
.ind-suma {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.65rem 1rem;
  border-radius: 10px;
  font-size: 0.88rem;
  margin-bottom: 1rem;
}
.ind-suma--ok  { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; }
.ind-suma--err { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; }
.ind-suma i { font-size: 1rem; }

/* ─── Lista ─── */
.ind-lista { display: flex; flex-direction: column; gap: 0.65rem; }

.ind-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-left: 4px solid #16a34a;
  border-radius: 10px;
  padding: 0.9rem 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  transition: box-shadow .15s;
}
.ind-card:hover { box-shadow: 0 3px 10px rgba(0,0,0,.08); }
.ind-card--inactivo { opacity: 0.5; border-left-color: #d1d5db; }

.ind-card__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.6rem;
}
.ind-card__left {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  flex: 1;
  min-width: 0;
}
.ind-badge-codigo {
  font-size: 0.72rem;
  font-weight: 800;
  background: #dcfce7;
  color: #166534;
  border-radius: 6px;
  padding: 0.2rem 0.5rem;
  white-space: nowrap;
  flex-shrink: 0;
  margin-top: 0.1rem;
}
.ind-card__nombre {
  font-size: 0.95rem;
  font-weight: 700;
  color: #111827;
  margin: 0 0 0.15rem;
}
.ind-card__desc {
  font-size: 0.82rem;
  color: #6b7280;
  margin: 0;
  line-height: 1.4;
}

.btn-editar {
  width: 40px; height: 40px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  color: #6b7280;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.9rem;
  flex-shrink: 0;
  transition: all .15s;
}
.btn-editar:hover { background: #dcfce7; color: #15803d; border-color: #86efac; }

.ind-card__footer {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 0.4rem;
}
.ind-card__pts {
  font-size: 0.8rem;
  color: #15803d;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}
.ind-card__pts i { font-size: 0.7rem; }
.ind-card__orden { font-size: 0.78rem; color: #9ca3af; margin-left: auto; }

.ind-badge-estado {
  font-size: 0.7rem;
  font-weight: 700;
  border-radius: 4px;
  padding: 0.15rem 0.45rem;
  text-transform: uppercase;
}
.ind-badge-estado--on  { background: #dcfce7; color: #166534; }
.ind-badge-estado--off { background: #f3f4f6; color: #6b7280; }

/* Evidencia colapsable nativa */
.ind-evidencia {
  margin-top: 0.25rem;
  font-size: 0.82rem;
}
.ind-evidencia summary {
  cursor: pointer;
  color: #6b7280;
  font-size: 0.78rem;
  padding: 0.25rem 0;
  user-select: none;
  list-style: none;
  display: flex;
  align-items: center;
  gap: 0.3rem;
}
.ind-evidencia summary::before {
  content: '▸';
  font-size: 0.65rem;
  transition: transform .15s;
}
details[open] .ind-evidencia summary::before { content: '▾'; }
.ind-evidencia p {
  margin: 0.4rem 0 0;
  color: #374151;
  line-height: 1.45;
  padding: 0.5rem 0.75rem;
  background: #f8fafc;
  border-radius: 6px;
  border: 1px solid #f1f5f9;
}

/* ─── Empty ─── */
.ind-empty {
  display: flex; flex-direction: column; align-items: center; gap: 0.5rem;
  padding: 3rem 1rem; text-align: center; color: #9ca3af; font-size: 0.88rem;
}
.ind-empty--error { color: #dc2626; }

/* ─── Botones ─── */
.btn {
  display: inline-flex; align-items: center; gap: 0.35rem;
  min-height: 44px; padding: 0.5rem 1rem;
  border-radius: 8px; border: none;
  font-size: 0.88rem; font-weight: 600;
  cursor: pointer; text-decoration: none;
  transition: background .15s; white-space: nowrap;
}
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover:not(:disabled) { background: #15803d; }
.btn--primary:disabled { opacity: 0.45; cursor: not-allowed; }
.btn--ghost { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn--ghost:hover:not(:disabled) { background: #f0fdf4; }
.btn--ghost:disabled { opacity: 0.5; }
.btn--full { width: 100%; justify-content: center; }

/* ─── Formulario ─── */
.campo-g { display: flex; flex-direction: column; gap: 0.3rem; margin-bottom: 0.85rem; }
.campo-g--row { flex-direction: row; align-items: center; justify-content: space-between; }
.campo-l { font-size: 0.78rem; font-weight: 700; color: #475569; }
.campo-i {
  min-height: 48px; padding: 0.55rem 0.7rem;
  border: 1px solid #d1d5db; border-radius: 8px;
  font-size: 0.95rem; background: white;
  width: 100%; box-sizing: border-box;
  transition: border-color .15s;
}
.campo-i:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
textarea.campo-i { min-height: 80px; resize: vertical; }
.campo-i:disabled { background: #f8fafc; color: #9ca3af; cursor: not-allowed; }
.campo-readonly {
  min-height: 48px; padding: 0.55rem 0.7rem;
  border: 1px solid #e5e7eb; border-radius: 8px;
  font-size: 0.95rem; background: #f8fafc; color: #6b7280;
  display: flex; align-items: center;
}
.campo-hint { font-size: 0.76rem; color: #9ca3af; }
.campo-fila { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.req { color: #dc2626; }

/* Toggle switch nativo */
.toggle {
  position: relative;
  width: 44px; height: 26px;
  border-radius: 13px;
  border: none;
  background: #d1d5db;
  cursor: pointer;
  transition: background .2s;
  flex-shrink: 0;
  padding: 0;
}
.toggle--on { background: #16a34a; }
.toggle:disabled { opacity: 0.5; cursor: not-allowed; }
.toggle__thumb {
  position: absolute;
  top: 3px; left: 3px;
  width: 20px; height: 20px;
  border-radius: 50%;
  background: white;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
  transition: transform .2s;
  display: block;
}
.toggle--on .toggle__thumb { transform: translateX(18px); }

/* ─── Modal ─── */
.m-ea, .m-la { transition: opacity .2s ease; }
.m-f { opacity: 0; }

.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) { .m-overlay { align-items: center; padding: 1rem; } }

.m-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.4);
  backdrop-filter: blur(4px);
}
.m-panel {
  position: relative; width: 100%; max-width: 480px;
  background: white; border-radius: 20px 20px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 92dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.1rem 1.25rem 0.9rem;
  border-bottom: 1px solid #f1f5f9; flex-shrink: 0;
}
.m-head__left { display: flex; align-items: center; gap: 0.6rem; }
.m-icon {
  width: 32px; height: 32px; border-radius: 50%;
  background: #dcfce7; color: #16a34a;
  display: flex; align-items: center; justify-content: center; font-size: 0.88rem;
}
.m-title { font-size: 1rem; font-weight: 800; margin: 0; color: #1e293b; }
.m-close {
  width: 32px; height: 32px; border-radius: 8px; border: none;
  background: transparent; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.82rem; transition: background .15s;
}
.m-close:hover { background: #f1f5f9; }

.m-body {
  overflow-y: auto; padding: 1.1rem 1.25rem; flex: 1;
}
.m-error {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: 0.65rem 0.85rem; color: #b91c1c; font-size: 0.84rem;
  margin-bottom: 0.85rem;
}

.m-intro { font-size: 0.88rem; color: #475569; margin: 0 0 1rem; line-height: 1.55; }

.m-pasos { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1rem; }
.m-paso  { display: flex; gap: 0.75rem; align-items: flex-start; }
.m-paso__n {
  width: 28px; height: 28px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  font-weight: 800; font-size: 0.78rem;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; margin-top: 0.1rem;
}
.m-paso__n--ok { background: #16a34a; color: white; }
.m-paso__t { font-size: 0.88rem; font-weight: 700; color: #1e293b; margin: 0 0 0.1rem; }
.m-paso__d { font-size: 0.8rem; color: #64748b; margin: 0; line-height: 1.4; }

.m-info-box {
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: 0.85rem; margin-bottom: 1rem;
}
.m-info-box__tit {
  font-size: 0.72rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .05em; margin: 0 0 0.6rem;
}
.m-nivel-fila {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.25rem 0; font-size: 0.82rem; color: #475569;
}
.m-nivel-fila + .m-nivel-fila { border-top: 1px solid #f1f5f9; }
.m-nivel-badge {
  font-size: 0.7rem; font-weight: 700;
  background: #dcfce7; color: #166534;
  border-radius: 4px; padding: 0.1rem 0.4rem; white-space: nowrap;
}

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.7rem 0.85rem; background: #f0fdf4;
  border: 1px solid #bbf7d0; border-radius: 8px;
  font-size: 0.78rem; color: #15803d; line-height: 1.45;
}
.m-nota i { flex-shrink: 0; margin-top: 0.1rem; }

.m-foot {
  padding: 0.9rem 1.25rem;
  border-top: 1px solid #f1f5f9; flex-shrink: 0;
  display: flex; gap: 0.5rem;
}
</style>
