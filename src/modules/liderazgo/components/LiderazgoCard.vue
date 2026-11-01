<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import {
  indicadoresService,
  evaluacionesService,
  type LiderazgoIndicador,
  type LiderazgoEvaluacion,
} from '@/modules/liderazgo/services/liderazgo.service'
import { useSessionStore } from '@/modules/auth/store'

// ── Props ─────────────────────────────────────────────────────────────────────
const props = defineProps<{
  equipoId: string
  programacionId: string
  readonly: boolean
  compact?: boolean
}>()

type EstadoGuardado = 'idle' | 'guardando' | 'guardado' | 'error'

interface FilaInd {
  nivel: number | null
  comentario: string
  estado: EstadoGuardado
  // UI state
  infoAbierta: boolean
  motivoPendiente: string
  esperandoMotivo: boolean
  nivelPendiente: number | null
}

// ── Descriptores ──────────────────────────────────────────────────────────────
const NIVELES_CFG = [
  { nivel: 4, label: '100%', desc: 'Cumple todo con autonomía',        color: '#15803d', bg: '#dcfce7', border: '#86efac' },
  { nivel: 3, label: '75%',  desc: 'Cumple lo esencial',               color: '#1d4ed8', bg: '#dbeafe', border: '#93c5fd' },
  { nivel: 2, label: '50%',  desc: 'Cumple parcialmente',              color: '#92400e', bg: '#fef3c7', border: '#fcd34d' },
  { nivel: 1, label: '25%',  desc: 'Avance mínimo',                    color: '#9a3412', bg: '#ffedd5', border: '#fdba74' },
  { nivel: 0, label: '0%',   desc: 'No realiza',                       color: '#6b7280', bg: '#f3f4f6', border: '#d1d5db' },
]

function nivelCfg(n: number) {
  return NIVELES_CFG.find(c => c.nivel === n) ?? NIVELES_CFG[4]
}

function nivelAPuntos(nivel: number, puntajeMax: number): number {
  return (nivel * puntajeMax) / 4
}

// ── Estado ────────────────────────────────────────────────────────────────────
const session    = useSessionStore()
const cargando   = ref(true)
const indicadores = ref<LiderazgoIndicador[]>([])
const filas      = ref<Map<string, FilaInd>>(new Map())

// ── Subtotal ──────────────────────────────────────────────────────────────────
const subtotal = computed(() => {
  let sum = 0
  for (const ind of indicadores.value) {
    const f = filas.value.get(ind.id)
    if (f?.nivel !== null && f?.nivel !== undefined) {
      sum += nivelAPuntos(f.nivel, ind.puntaje_max)
    }
  }
  return sum
})

const puntajeMax = computed(() =>
  indicadores.value.reduce((a, i) => a + i.puntaje_max, 0),
)

const calificados = computed(() => {
  let n = 0
  for (const [, f] of filas.value) { if (f.nivel !== null) n++ }
  return n
})

const pctCompleto = computed(() =>
  indicadores.value.length ? Math.round(calificados.value / indicadores.value.length * 100) : 0,
)

// ── Carga ─────────────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  try {
    const [inds, evals] = await Promise.all([
      indicadoresService.getAll(),
      evaluacionesService.getPorEquipoDia(props.equipoId, props.programacionId),
    ])
    indicadores.value = inds.filter(i => i.activo)

    const nuevas = new Map<string, FilaInd>()
    for (const ind of indicadores.value) {
      const ev = evals.find((e: LiderazgoEvaluacion) => e.indicador_id === ind.id)
      nuevas.set(ind.id, {
        nivel: ev?.nivel ?? null,
        comentario: ev?.comentario ?? '',
        estado: 'idle',
        infoAbierta: false,
        motivoPendiente: '',
        esperandoMotivo: false,
        nivelPendiente: null,
      })
    }
    filas.value = nuevas
  } finally {
    cargando.value = false
  }
}

watch(() => [props.equipoId, props.programacionId], cargar)
onMounted(cargar)

// ── Guardado ──────────────────────────────────────────────────────────────────
async function guardarNivel(ind: LiderazgoIndicador, nuevoNivel: number, motivo?: string) {
  const fila = filas.value.get(ind.id)
  if (!fila) return

  const nivelAnterior = fila.nivel
  fila.nivel = nuevoNivel
  fila.estado = 'guardando'
  fila.esperandoMotivo = false
  fila.nivelPendiente  = null

  try {
    await evaluacionesService.upsert({
      equipo_id: props.equipoId,
      programacion_id: props.programacionId,
      indicador_id: ind.id,
      nivel: nuevoNivel,
      comentario: fila.comentario || null,
      evaluador_id: session.user!.id,
      motivo_cambio: motivo ?? null,
    })
    fila.estado = 'guardado'
    setTimeout(() => { if (fila.estado === 'guardado') fila.estado = 'idle' }, 2000)
  } catch {
    fila.nivel  = nivelAnterior
    fila.estado = 'error'
  }
}

function onNivel(ind: LiderazgoIndicador, nuevoNivel: number) {
  if (props.readonly) return
  const fila = filas.value.get(ind.id)
  if (!fila) return

  // Ya tiene nivel distinto → pedir motivo inline
  if (fila.nivel !== null && fila.nivel !== nuevoNivel) {
    fila.nivelPendiente  = nuevoNivel
    fila.motivoPendiente = ''
    fila.esperandoMotivo = true
  } else {
    guardarNivel(ind, nuevoNivel)
  }
}

function confirmarMotivo(ind: LiderazgoIndicador) {
  const fila = filas.value.get(ind.id)
  if (!fila || fila.nivelPendiente === null) return
  guardarNivel(ind, fila.nivelPendiente, fila.motivoPendiente || undefined)
}

function cancelarMotivo(indId: string) {
  const fila = filas.value.get(indId)
  if (fila) { fila.esperandoMotivo = false; fila.nivelPendiente = null }
}
</script>

<template>
  <div class="lid-card" :class="compact && 'lid-card--compact'">

    <!-- ── Header con progreso ── -->
    <div class="lid-header">
      <div class="lid-header__left">
        <span class="lid-badge">LID</span>
        <span class="lid-titulo">Liderazgo de servicio</span>
      </div>
      <div v-if="!cargando" class="lid-score">
        <span class="lid-score__val">{{ subtotal % 1 === 0 ? subtotal : subtotal.toFixed(1) }}</span>
        <span class="lid-score__sep">/</span>
        <span class="lid-score__max">{{ puntajeMax }}</span>
      </div>
    </div>

    <!-- Barra de progreso -->
    <div v-if="!cargando && indicadores.length" class="lid-progress">
      <div class="lid-progress__bar" :style="{ width: pctCompleto + '%' }" />
    </div>
    <p v-if="!cargando" class="lid-completado">
      {{ calificados }}/{{ indicadores.length }} indicadores calificados
    </p>

    <div v-if="cargando" class="lid-cargando">
      <i class="pi pi-spin pi-spinner" /> Cargando…
    </div>

    <!-- ── Indicadores ── -->
    <template v-else>
      <div v-for="ind in indicadores" :key="ind.id" class="lid-ind">

        <!-- Cabecera indicador -->
        <div class="lid-ind__head">
          <div class="lid-ind__meta">
            <span class="lid-badge-sm">{{ ind.codigo }}</span>
            <span class="lid-ind__nombre">{{ ind.nombre }}</span>
          </div>
          <div class="lid-ind__right">
            <!-- Estado guardado -->
            <span v-if="filas.get(ind.id)?.estado === 'guardando'" class="lid-dot lid-dot--saving">
              <i class="pi pi-spin pi-spinner" />
            </span>
            <span v-else-if="filas.get(ind.id)?.estado === 'guardado'" class="lid-dot lid-dot--ok">
              <i class="pi pi-check" />
            </span>
            <span v-else-if="filas.get(ind.id)?.estado === 'error'" class="lid-dot lid-dot--err">
              <i class="pi pi-times" />
            </span>
            <!-- Info toggle -->
            <button
              class="lid-info-btn"
              :class="filas.get(ind.id)?.infoAbierta && 'lid-info-btn--active'"
              @click="() => { const f = filas.get(ind.id); if (f) f.infoAbierta = !f.infoAbierta }"
            >
              <i class="pi pi-question-circle" />
            </button>
          </div>
        </div>

        <!-- Panel info expandible -->
        <div v-if="filas.get(ind.id)?.infoAbierta" class="lid-info-panel">
          <p class="lid-info-panel__desc">{{ ind.descripcion }}</p>
          <p class="lid-info-panel__ev"><strong>Evidencia:</strong> {{ ind.evidencia }}</p>
          <div class="lid-info-panel__niveles">
            <div v-for="cfg in NIVELES_CFG" :key="cfg.nivel" class="lid-info-nivel">
              <span class="lid-info-nivel__pct" :style="{ color: cfg.color }">{{ cfg.label }}</span>
              <span class="lid-info-nivel__pts">({{ nivelAPuntos(cfg.nivel, ind.puntaje_max) }} pts)</span>
              <span class="lid-info-nivel__desc">{{ cfg.desc }}</span>
            </div>
          </div>
        </div>

        <!-- Botones de nivel -->
        <div class="lid-niveles">
          <button
            v-for="cfg in NIVELES_CFG"
            :key="cfg.nivel"
            class="lid-nivel-btn"
            :class="[
              filas.get(ind.id)?.nivel === cfg.nivel && 'lid-nivel-btn--sel',
              readonly && 'lid-nivel-btn--readonly',
            ]"
            :style="filas.get(ind.id)?.nivel === cfg.nivel
              ? { background: cfg.bg, borderColor: cfg.border, color: cfg.color }
              : {}"
            :disabled="readonly"
            @click="onNivel(ind, cfg.nivel)"
          >
            <span class="lid-nivel-btn__pct">{{ cfg.label }}</span>
            <span class="lid-nivel-btn__pts">{{ nivelAPuntos(cfg.nivel, ind.puntaje_max) }} pts</span>
          </button>
        </div>

        <!-- Descriptor del nivel seleccionado -->
        <p
          v-if="filas.get(ind.id)?.nivel !== null && filas.get(ind.id)?.nivel !== undefined"
          class="lid-desc-sel"
          :style="{ color: nivelCfg(filas.get(ind.id)!.nivel!).color }"
        >
          <i class="pi pi-check-circle" />
          {{ nivelCfg(filas.get(ind.id)!.nivel!).desc }}
        </p>

        <!-- Panel motivo de cambio (inline) -->
        <div v-if="filas.get(ind.id)?.esperandoMotivo" class="lid-motivo">
          <p class="lid-motivo__aviso">
            <i class="pi pi-info-circle" />
            Este indicador ya tenía un valor. Explica brevemente el motivo del cambio:
          </p>
          <textarea
            v-model="filas.get(ind.id)!.motivoPendiente"
            rows="2"
            class="lid-motivo__input"
            placeholder="Ej: Corrección tras revisión del equipo…"
          />
          <div class="lid-motivo__btns">
            <button class="btn-sm btn-sm--ghost" @click="cancelarMotivo(ind.id)">
              <i class="pi pi-times" /> Cancelar
            </button>
            <button class="btn-sm btn-sm--ok" @click="confirmarMotivo(ind)">
              <i class="pi pi-check" /> Confirmar cambio
            </button>
          </div>
        </div>

        <!-- Comentario (siempre visible si hay texto, expandible si no) -->
        <details class="lid-comentario" :open="!!filas.get(ind.id)?.comentario">
          <summary>
            <i class="pi pi-comment" />
            Comentario interno
            <span v-if="filas.get(ind.id)?.comentario" class="lid-comentario__dot" />
          </summary>
          <textarea
            v-model="filas.get(ind.id)!.comentario"
            rows="2"
            class="lid-comentario__input"
            placeholder="Observación interna (opcional)…"
            :disabled="readonly"
          />
        </details>

      </div>
    </template>
  </div>
</template>

<style scoped>
/* ─── Card ─── */
.lid-card {
  background: white;
  border: 2px solid #dcfce7;
  border-radius: 12px;
  padding: 1rem;
  margin-top: 0.75rem;
}
.lid-card--compact {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  margin-top: 0;
}

/* ─── Header ─── */
.lid-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}
.lid-header__left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.lid-badge {
  font-size: 0.7rem; font-weight: 800;
  background: #dcfce7; color: #166534;
  border-radius: 6px; padding: 0.2rem 0.5rem;
  white-space: nowrap;
}
.lid-titulo { font-size: 0.88rem; font-weight: 700; color: #15803d; }

.lid-score {
  display: flex;
  align-items: baseline;
  gap: 0.15rem;
}
.lid-score__val { font-size: 1.1rem; font-weight: 800; color: #15803d; }
.lid-score__sep { font-size: 0.85rem; color: #94a3b8; }
.lid-score__max { font-size: 0.85rem; color: #6b7280; }

/* Progress bar */
.lid-progress {
  height: 4px;
  background: #dcfce7;
  border-radius: 2px;
  margin-bottom: 0.25rem;
  overflow: hidden;
}
.lid-progress__bar {
  height: 100%;
  background: #16a34a;
  border-radius: 2px;
  transition: width .3s;
}
.lid-completado {
  font-size: 0.72rem;
  color: #6b7280;
  margin: 0 0 0.75rem;
}

.lid-cargando {
  font-size: 0.82rem; color: #9ca3af;
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.5rem 0;
}

/* ─── Indicador ─── */
.lid-ind {
  border-top: 1px solid #f1f5f9;
  padding-top: 0.75rem;
  margin-top: 0.75rem;
}

.lid-ind__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.4rem;
  margin-bottom: 0.55rem;
}
.lid-ind__meta {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex: 1;
  min-width: 0;
}
.lid-badge-sm {
  font-size: 0.65rem; font-weight: 800;
  background: #dcfce7; color: #166534;
  border-radius: 4px; padding: 0.1rem 0.35rem;
  white-space: nowrap; flex-shrink: 0;
}
.lid-ind__nombre {
  font-size: 0.88rem; font-weight: 600; color: #1e293b;
}
.lid-ind__right {
  display: flex; align-items: center; gap: 0.4rem; flex-shrink: 0;
}

/* Dots estado */
.lid-dot {
  width: 24px; height: 24px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.65rem; flex-shrink: 0;
}
.lid-dot--saving { background: #fff7ed; color: #f97316; }
.lid-dot--ok     { background: #dcfce7; color: #16a34a; }
.lid-dot--err    { background: #fee2e2; color: #dc2626; }

/* Botón info */
.lid-info-btn {
  width: 32px; height: 32px; border-radius: 8px;
  border: 1px solid #dcfce7;
  background: #f0fdf4; color: #16a34a;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.88rem;
  transition: all .15s;
}
.lid-info-btn:hover, .lid-info-btn--active {
  background: #dcfce7; color: #15803d; border-color: #86efac;
}

/* ─── Panel info ─── */
.lid-info-panel {
  background: #f8fafc;
  border: 1px solid #dcfce7;
  border-radius: 8px;
  padding: 0.75rem;
  margin-bottom: 0.55rem;
  font-size: 0.82rem;
}
.lid-info-panel__desc {
  color: #374151; margin: 0 0 0.5rem; line-height: 1.45;
}
.lid-info-panel__ev {
  color: #4b5563; margin: 0 0 0.6rem; font-size: 0.8rem;
}
.lid-info-panel__niveles { display: flex; flex-direction: column; gap: 0.2rem; }
.lid-info-nivel {
  display: flex; align-items: baseline; gap: 0.4rem;
  font-size: 0.78rem; color: #475569;
  padding: 0.2rem 0;
  border-top: 1px solid #f1f5f9;
}
.lid-info-nivel:first-child { border-top: none; }
.lid-info-nivel__pct { font-weight: 800; min-width: 30px; }
.lid-info-nivel__pts { color: #94a3b8; font-size: 0.72rem; white-space: nowrap; }
.lid-info-nivel__desc { flex: 1; }

/* ─── Botones de nivel ─── */
.lid-niveles {
  display: flex;
  gap: 0.35rem;
  margin-bottom: 0.4rem;
}
.lid-nivel-btn {
  flex: 1;
  min-height: 52px;
  border-radius: 8px;
  border: 2px solid #e5e7eb;
  background: white;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.1rem;
  transition: all .15s;
  padding: 0.3rem 0.25rem;
}
.lid-nivel-btn:hover:not(.lid-nivel-btn--readonly):not(.lid-nivel-btn--sel) {
  border-color: #86efac;
  background: #f0fdf4;
}
.lid-nivel-btn--sel {
  transform: scale(1.03);
  box-shadow: 0 2px 8px rgba(0,0,0,.1);
}
.lid-nivel-btn--readonly { cursor: not-allowed; opacity: 0.6; }

.lid-nivel-btn__pct {
  font-size: 0.82rem;
  font-weight: 800;
  line-height: 1;
}
.lid-nivel-btn__pts {
  font-size: 0.68rem;
  color: inherit;
  opacity: 0.75;
  white-space: nowrap;
}

/* ─── Descriptor seleccionado ─── */
.lid-desc-sel {
  font-size: 0.76rem;
  font-style: italic;
  display: flex;
  align-items: center;
  gap: 0.3rem;
  margin: 0 0 0.3rem;
}
.lid-desc-sel i { font-size: 0.7rem; }

/* ─── Panel motivo inline ─── */
.lid-motivo {
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 8px;
  padding: 0.75rem;
  margin-bottom: 0.4rem;
}
.lid-motivo__aviso {
  font-size: 0.8rem; color: #92400e;
  display: flex; align-items: flex-start; gap: 0.4rem;
  margin: 0 0 0.5rem;
}
.lid-motivo__aviso i { flex-shrink: 0; margin-top: 0.1rem; }
.lid-motivo__input {
  width: 100%; min-height: 60px; padding: 0.5rem 0.6rem;
  border: 1px solid #fcd34d; border-radius: 6px;
  font-size: 0.88rem; background: white; resize: vertical;
  box-sizing: border-box; margin-bottom: 0.5rem;
}
.lid-motivo__input:focus {
  outline: none; border-color: #f59e0b;
  box-shadow: 0 0 0 3px rgba(245,158,11,.15);
}
.lid-motivo__btns {
  display: flex; gap: 0.4rem; justify-content: flex-end;
}

/* ─── Comentario ─── */
.lid-comentario { margin-top: 0.35rem; font-size: 0.8rem; }
.lid-comentario summary {
  cursor: pointer; color: #6b7280; font-size: 0.76rem;
  padding: 0.25rem 0; user-select: none;
  list-style: none; display: flex; align-items: center; gap: 0.3rem;
}
.lid-comentario summary::before { content: '▸'; font-size: 0.6rem; }
details[open] > summary::before { content: '▾'; }
.lid-comentario__dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: #16a34a; display: inline-block;
}
.lid-comentario__input {
  width: 100%; margin-top: 0.35rem;
  min-height: 60px; padding: 0.5rem 0.6rem;
  border: 1px solid #d1d5db; border-radius: 6px;
  font-size: 0.82rem; resize: vertical; box-sizing: border-box; background: white;
}
.lid-comentario__input:focus {
  outline: none; border-color: #16a34a;
  box-shadow: 0 0 0 3px rgba(22,163,74,.15);
}
.lid-comentario__input:disabled { background: #f8fafc; }

/* ─── Botones pequeños (motivo) ─── */
.btn-sm {
  display: inline-flex; align-items: center; gap: 0.3rem;
  min-height: 36px; padding: 0.4rem 0.75rem;
  border-radius: 6px; border: none;
  font-size: 0.8rem; font-weight: 600; cursor: pointer;
  transition: background .15s;
}
.btn-sm--ghost { background: white; border: 1px solid #d1d5db; color: #374151; }
.btn-sm--ghost:hover { background: #f9fafb; }
.btn-sm--ok { background: #f59e0b; color: white; }
.btn-sm--ok:hover { background: #d97706; }
</style>
