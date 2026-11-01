<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  pendientesService,
  incidenciasService,
  type IncidenciaPendiente,
} from '@/modules/incidencias/services/incidencias.service'
import { useCampamentoStore } from '@/stores/campamento'

const router    = useRouter()
const campStore = useCampamentoStore()

const lista    = ref<IncidenciaPendiente[]>([])
const cargando = ref(true)
const error    = ref('')

// Resolución rápida
const resolviendo = ref<string | null>(null)
const motivo      = ref('')
const errorMotivo = ref('')

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    lista.value = await pendientesService.getAll(campStore.selectedId)
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

function iniciarResolucion(id: string) {
  resolviendo.value = id
  motivo.value = ''
  errorMotivo.value = ''
}

function cancelarResolucion() {
  resolviendo.value = null
  motivo.value = ''
}

async function resolver(inc: IncidenciaPendiente, accion: 'validar' | 'rechazar') {
  if (!motivo.value.trim()) { errorMotivo.value = 'El motivo es obligatorio'; return }
  const fn = accion === 'validar' ? incidenciasService.validar : incidenciasService.rechazar
  try {
    await fn(inc.id, motivo.value.trim())
    lista.value = lista.value.filter((i) => i.id !== inc.id)
    resolviendo.value = null
  } catch (e: any) {
    errorMotivo.value = e.message ?? 'Error'
  }
}

function edadEnHoras(created_at: string): string {
  const diff = Date.now() - new Date(created_at).getTime()
  const h = Math.floor(diff / 3_600_000)
  if (h < 1) return 'hace menos de 1 h'
  if (h < 24) return `hace ${h} h`
  return `hace ${Math.floor(h / 24)} d`
}
</script>

<template>
  <div class="bdj-page">

    <!-- ── Header ── -->
    <header class="bdj-header">
      <button class="btn-back" @click="router.push('/panel/incidencias')">
        <i class="pi pi-arrow-left" /> Incidencias
      </button>
      <div class="bdj-header__center">
        <h1 class="bdj-title">Bandeja de validación</h1>
        <p v-if="!cargando && lista.length > 0" class="bdj-sub">
          {{ lista.length }} pendiente{{ lista.length !== 1 ? 's' : '' }} — más antigua primero
        </p>
      </div>
      <button class="btn btn--ghost" :disabled="cargando" @click="cargar" title="Actualizar">
        <i :class="['pi', cargando ? 'pi-spin pi-spinner' : 'pi-refresh']" />
      </button>
    </header>

    <!-- ── Cargando / Error ── -->
    <div v-if="cargando" class="bdj-empty">
      <i class="pi pi-spin pi-spinner" style="font-size:1.5rem;" />
    </div>
    <div v-else-if="error" class="bdj-empty bdj-empty--error">
      <i class="pi pi-exclamation-circle" /> {{ error }}
    </div>

    <!-- ── Lista ── -->
    <div v-else-if="lista.length" class="bdj-lista">
      <div
        v-for="inc in lista"
        :key="inc.id"
        :class="['bdj-card', inc.tipo === 'bonus' ? 'bdj-card--bonus' : 'bdj-card--demerito']"
      >
        <!-- Cabecera card -->
        <div class="bdj-card__top">
          <div class="bdj-card__meta">
            <span :class="['badge', inc.tipo === 'bonus' ? 'badge--azul' : 'badge--naranja']">
              {{ inc.codigo }}
            </span>
            <span class="bdj-card__equipo">{{ inc.equipo_nombre }}</span>
            <span class="bdj-card__edad">{{ edadEnHoras(inc.created_at) }}</span>
          </div>
          <span :class="['bdj-pts', inc.tipo === 'bonus' ? 'pts--bonus' : 'pts--demerito']">
            {{ inc.tipo === 'bonus' ? '+' : '−' }}{{ inc.puntos }} pts
          </span>
        </div>

        <!-- Hecho -->
        <p class="bdj-card__hecho">{{ inc.hecho }}</p>

        <!-- Descargo si existe -->
        <div v-if="inc.descargo_equipo" class="bdj-descargo">
          <i class="pi pi-comment" />
          <span><strong>Descargo:</strong> {{ inc.descargo_equipo }}</span>
        </div>

        <!-- Metadatos -->
        <div class="bdj-card__info">
          <i class="pi pi-calendar" /> {{ inc.fecha }}
          <span v-if="inc.hora"> · {{ inc.hora.slice(0,5) }}</span>
          <span v-if="inc.momento"> · {{ inc.momento }}</span>
          · {{ inc.registrado_por_nombre }}
        </div>

        <!-- Acciones -->
        <div v-if="resolviendo !== inc.id" class="bdj-card__acciones">
          <button
            class="btn btn--ghost btn--sm"
            @click="router.push(`/panel/incidencias/${inc.id}`)"
          >
            <i class="pi pi-eye" /> Ver detalle
          </button>
          <button class="btn btn--primary btn--sm" @click="iniciarResolucion(inc.id)">
            <i class="pi pi-check-square" /> Resolver
          </button>
        </div>

        <!-- Panel resolución inline -->
        <div v-else class="bdj-resolucion">
          <div class="campo-grupo">
            <label class="campo-label">Motivo <span class="req">*</span></label>
            <textarea v-model="motivo" rows="2" class="campo-input" placeholder="Escribe el motivo de la decisión…" />
            <p v-if="errorMotivo" class="error-msg">{{ errorMotivo }}</p>
          </div>
          <div class="bdj-resolucion__btns">
            <button class="btn btn--ghost btn--sm" @click="cancelarResolucion">
              <i class="pi pi-times" /> Cancelar
            </button>
            <button class="btn btn--rechazar btn--sm" @click="resolver(inc, 'rechazar')">
              <i class="pi pi-times-circle" /> Rechazar
            </button>
            <button class="btn btn--validar btn--sm" @click="resolver(inc, 'validar')">
              <i class="pi pi-check-circle" /> Validar
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Vacío ── -->
    <div v-else class="bdj-empty">
      <div class="bdj-empty__icon">
        <i class="pi pi-check-circle" />
      </div>
      <strong>Todo al día</strong>
      <span>No hay incidencias pendientes de validación.</span>
    </div>

  </div>
</template>

<style scoped>
.bdj-page {
  max-width: 700px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* ── Header ── */
.bdj-header {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.btn-back {
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
  white-space: nowrap;
}
.btn-back:hover { text-decoration: underline; }

.bdj-header__center { flex: 1; }
.bdj-title { font-size: 1.2rem; font-weight: 800; margin: 0; }
.bdj-sub { font-size: 0.8rem; color: #6b7280; margin: 0.15rem 0 0; }

/* ── Cards ── */
.bdj-lista { display: flex; flex-direction: column; gap: 0.75rem; }

.bdj-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 10px;
  padding: 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.07);
}
.bdj-card--bonus    { border-left-color: #16a34a; }
.bdj-card--demerito { border-left-color: #dc2626; }

.bdj-card__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}
.bdj-card__meta {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-wrap: wrap;
  flex: 1;
}
.bdj-card__equipo { font-weight: 700; font-size: 0.9rem; }
.bdj-card__edad   { font-size: 0.78rem; color: #9ca3af; }
.bdj-pts { font-weight: 800; font-size: 1rem; white-space: nowrap; }
.pts--bonus    { color: #16a34a; }
.pts--demerito { color: #dc2626; }

.bdj-card__hecho {
  font-size: 0.88rem;
  color: #374151;
  margin: 0 0 0.5rem;
  line-height: 1.45;
}

.bdj-descargo {
  display: flex;
  align-items: flex-start;
  gap: 0.4rem;
  font-size: 0.82rem;
  color: #374151;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 6px;
  padding: 0.4rem 0.6rem;
  margin-bottom: 0.4rem;
}
.bdj-descargo i { flex-shrink: 0; margin-top: 0.1rem; color: #d97706; }

.bdj-card__info {
  font-size: 0.78rem;
  color: #9ca3af;
  margin-bottom: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.25rem;
  flex-wrap: wrap;
}
.bdj-card__info i { font-size: 0.7rem; }

/* Acciones */
.bdj-card__acciones {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
  flex-wrap: wrap;
}

/* Resolución inline */
.bdj-resolucion {
  margin-top: 0.75rem;
  padding: 0.9rem;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}
.campo-grupo { margin-bottom: 0.5rem; }
.campo-label { display: block; font-size: 0.78rem; font-weight: 600; margin-bottom: 0.25rem; color: #374151; }
.campo-input {
  width: 100%;
  min-height: 44px;
  padding: 0.5rem 0.6rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.9rem;
  background: white;
  box-sizing: border-box;
}
.campo-input:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
textarea.campo-input { resize: vertical; min-height: 72px; }
.req { color: #dc2626; }

.bdj-resolucion__btns {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
  flex-wrap: wrap;
  margin-top: 0.5rem;
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

/* ── Botones ── */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 44px;
  padding: 0.5rem 1rem;
  border-radius: 8px;
  border: none;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  white-space: nowrap;
}
.btn--sm { min-height: 44px; padding: 0.5rem 0.85rem; font-size: 0.84rem; }
.btn--primary  { background: #16a34a; color: white; }
.btn--primary:hover { background: #15803d; }
.btn--ghost { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn--ghost:hover { background: #f0fdf4; }
.btn--validar  { background: #16a34a; color: white; }
.btn--validar:hover { background: #15803d; }
.btn--rechazar { background: #dc2626; color: white; }
.btn--rechazar:hover { background: #b91c1c; }
.btn:disabled { opacity: 0.5; cursor: not-allowed; }

/* ── Empty ── */
.bdj-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3.5rem 1rem;
  text-align: center;
  color: #6b7280;
  font-size: 0.9rem;
}
.bdj-empty__icon {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: #d1fae5;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  color: #16a34a;
  margin-bottom: 0.25rem;
}
.bdj-empty--error { color: #dc2626; }

.error-msg { color: #dc2626; font-size: 0.82rem; margin-top: 0.25rem; }
</style>
