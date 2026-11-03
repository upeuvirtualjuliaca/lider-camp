<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import {
  incidenciasService,
  codigosService,
  evidenciasService,
  type Incidencia,
  type IncidenciaDetalle,
  type IncidenciaCodigo,
} from '@/modules/incidencias/services/incidencias.service'
import { equiposService, integrantesService, type Equipo, type Integrante } from '@/modules/equipos/services/equipos.service'
import { useCampamentoStore } from '@/stores/campamento'

const campStore = useCampamentoStore()

const lista    = ref<Incidencia[]>([])
const codigos  = ref<IncidenciaCodigo[]>([])
const equipos  = ref<Equipo[]>([])
const cargando = ref(true)
const error    = ref('')

// Filtro de estado
const filtro = ref<'todas' | 'registrado' | 'validado' | 'rechazado'>('registrado')

// Resolución inline
const resolviendoId     = ref<string | null>(null)
const resolviendoAccion = ref<'validar' | 'rechazar' | null>(null)
const motivo            = ref('')
const errorMotivo       = ref('')

// ── Modal de detalle ──────────────────────────────────────────────────────────
const modalAbierto   = ref(false)
const detalle        = ref<IncidenciaDetalle | null>(null)
const detIntegrantes = ref<Integrante[]>([])
const detUrls        = ref<Record<string, string>>({})
const detCargando    = ref(false)
const detError       = ref('')

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const [inc, cod, eq] = await Promise.all([
      incidenciasService.getAll({ campamento_id: campStore.selectedId ?? undefined }),
      codigosService.getAll(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])
    lista.value   = inc
    codigos.value = cod
    equipos.value = eq
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const codigoPorCodigo = computed(() => {
  const m = new Map<string, IncidenciaCodigo>()
  codigos.value.forEach((c) => m.set(c.codigo, c))
  return m
})

function tipoDe(codigo: string) {
  return codigoPorCodigo.value.get(codigo)?.tipo ?? 'demerito'
}

function nombreEquipo(id: string) {
  return equipos.value.find((e) => e.id === id)?.nombre ?? '—'
}

function nombreIntegrante(id: string) {
  const i = detIntegrantes.value.find((x) => x.id === id)
  return i ? `${i.apellidos}, ${i.nombres}` : id
}

// ── Lista filtrada ─────────────────────────────────────────────────────────────
const listaFiltrada = computed(() => {
  if (filtro.value === 'todas') return lista.value
  return lista.value.filter((i) => i.estado === filtro.value)
})

const cntPendiente = computed(() => lista.value.filter(i => i.estado === 'registrado').length)
const cntValidado  = computed(() => lista.value.filter(i => i.estado === 'validado').length)
const cntRechazado = computed(() => lista.value.filter(i => i.estado === 'rechazado').length)

// ── Modal detalle ─────────────────────────────────────────────────────────────
async function abrirDetalle(inc: Incidencia) {
  modalAbierto.value = true
  detCargando.value  = true
  detError.value     = ''
  detalle.value      = null
  detIntegrantes.value = []
  detUrls.value        = {}
  resolviendoId.value     = null
  resolviendoAccion.value = null
  motivo.value            = ''
  errorMotivo.value       = ''
  try {
    const d = await incidenciasService.getPorId(inc.id)
    if (!d) { detError.value = 'No encontrado'; return }
    detalle.value = d
    if (d.integrantes.length) {
      detIntegrantes.value = await integrantesService.getPorEquipo(d.equipo_id)
    }
    for (const ev of d.evidencias) {
      detUrls.value[ev.id] = await evidenciasService.getUrl(ev.ruta_archivo)
    }
  } catch (e: any) {
    detError.value = e.message ?? 'Error al cargar detalle'
  } finally {
    detCargando.value = false
  }
}

function cerrarModal() {
  modalAbierto.value      = false
  detalle.value           = null
  resolviendoId.value     = null
  resolviendoAccion.value = null
  motivo.value            = ''
  errorMotivo.value       = ''
}

// ── Resolución ────────────────────────────────────────────────────────────────
function iniciarResolucion(id: string, accion: 'validar' | 'rechazar') {
  resolviendoId.value     = id
  resolviendoAccion.value = accion
  motivo.value            = ''
  errorMotivo.value       = ''
}

function cancelarResolucion() {
  resolviendoId.value     = null
  resolviendoAccion.value = null
  motivo.value            = ''
}

async function resolver(id: string, accion: 'validar' | 'rechazar') {
  if (!motivo.value.trim()) { errorMotivo.value = 'El motivo es obligatorio'; return }
  errorMotivo.value = ''
  try {
    const actualizado = accion === 'validar'
      ? await incidenciasService.validar(id, motivo.value.trim())
      : await incidenciasService.rechazar(id, motivo.value.trim())
    // Actualizar lista principal
    const idx = lista.value.findIndex((i) => i.id === id)
    if (idx >= 0) lista.value[idx] = actualizado
    // Actualizar detalle si el modal estaba abierto
    if (detalle.value?.id === id) detalle.value = { ...detalle.value, ...actualizado }
    resolviendoId.value     = null
    resolviendoAccion.value = null
    motivo.value = ''
    cerrarModal()
  } catch (e: any) {
    errorMotivo.value = e.message ?? 'Error al guardar'
  }
}

const ESTADO_CFG: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Pendiente', cls: 'badge--amber' },
  validado:   { label: 'Validado',  cls: 'badge--verde' },
  rechazado:  { label: 'Rechazado', cls: 'badge--rojo'  },
}
</script>

<template>
  <div class="bdj-page">

    <!-- ── Header ── -->
    <header class="bdj-header">
      <div>
        <h1 class="bdj-title">Revisiones</h1>
        <p class="bdj-sub">Valida o rechaza las incidencias registradas</p>
      </div>
      <button class="btn btn--ghost btn--sm" :disabled="cargando" @click="cargar">
        <i :class="['pi', cargando ? 'pi-spin pi-spinner' : 'pi-refresh']" />
      </button>
    </header>

    <!-- ── Tabs de estado ── -->
    <div class="bdj-tabs">
      <button
        v-for="tab in [
          { v: 'registrado', label: 'Pendientes', cnt: cntPendiente },
          { v: 'validado',   label: 'Validadas',  cnt: cntValidado  },
          { v: 'rechazado',  label: 'Rechazadas', cnt: cntRechazado },
          { v: 'todas',      label: 'Todas',      cnt: lista.length },
        ]"
        :key="tab.v"
        :class="['bdj-tab', filtro === tab.v && 'bdj-tab--active',
                 tab.v === 'registrado' && filtro === tab.v && 'bdj-tab--amber',
                 tab.v === 'validado'   && filtro === tab.v && 'bdj-tab--verde',
                 tab.v === 'rechazado'  && filtro === tab.v && 'bdj-tab--rojo']"
        @click="filtro = tab.v as any"
      >
        {{ tab.label }}
        <span v-if="tab.cnt > 0" class="bdj-tab-cnt">{{ tab.cnt }}</span>
      </button>
    </div>

    <!-- ── Cargando / Error ── -->
    <div v-if="cargando" class="bdj-empty">
      <i class="pi pi-spin pi-spinner" style="font-size:1.5rem;" />
    </div>
    <div v-else-if="error" class="bdj-empty bdj-empty--error">
      <i class="pi pi-exclamation-circle" /> {{ error }}
    </div>

    <!-- ── Lista ── -->
    <div v-else-if="listaFiltrada.length" class="bdj-lista">
      <div
        v-for="inc in listaFiltrada"
        :key="inc.id"
        :class="['bdj-card', tipoDe(inc.codigo) === 'bonus' ? 'bdj-card--bonus' : 'bdj-card--demerito']"
        @click="abrirDetalle(inc)"
      >
        <div class="bdj-card__top">
          <div class="bdj-card__meta">
            <span :class="['badge', tipoDe(inc.codigo) === 'bonus' ? 'badge--azul' : 'badge--naranja']">
              {{ inc.codigo }}
            </span>
            <span class="bdj-card__equipo">{{ nombreEquipo(inc.equipo_id) }}</span>
            <span :class="['badge', ESTADO_CFG[inc.estado]?.cls ?? 'badge--amber']">
              {{ ESTADO_CFG[inc.estado]?.label ?? inc.estado }}
            </span>
          </div>
          <span :class="['bdj-pts', tipoDe(inc.codigo) === 'bonus' ? 'pts--bonus' : 'pts--demerito']">
            {{ tipoDe(inc.codigo) === 'bonus' ? '+' : '−' }}{{ inc.puntos }} pts
          </span>
        </div>
        <p class="bdj-card__hecho">{{ inc.hecho }}</p>
        <div class="bdj-card__info">
          <i class="pi pi-calendar" /> {{ inc.fecha }}
          <span v-if="inc.hora"> · {{ inc.hora.slice(0,5) }}</span>
        </div>
      </div>
    </div>

    <!-- ── Vacío ── -->
    <div v-else class="bdj-empty">
      <div class="bdj-empty__icon"><i class="pi pi-check-circle" /></div>
      <strong>
        {{ filtro === 'registrado' ? 'Sin pendientes' :
           filtro === 'validado'   ? 'Sin validadas'  :
           filtro === 'rechazado'  ? 'Sin rechazadas' : 'Sin incidencias' }}
      </strong>
      <span>
        {{ filtro === 'registrado' ? 'No hay incidencias pendientes de revisión.' : 'No hay registros en este estado.' }}
      </span>
    </div>
  </div>

  <!-- ══════ Modal detalle ══════ -->
  <Teleport to="body">
    <Transition enter-active-class="m-enter" leave-active-class="m-leave">
      <div v-if="modalAbierto" class="m-overlay" @click.self="cerrarModal">
        <div class="m-panel">

          <!-- Header modal -->
          <div class="m-head">
            <button class="m-close" @click="cerrarModal"><i class="pi pi-arrow-left" /></button>
            <span class="m-head__title">Detalle de incidencia</span>
          </div>

          <!-- Cargando -->
          <div v-if="detCargando" class="m-empty">
            <i class="pi pi-spin pi-spinner" style="font-size:1.5rem" />
          </div>
          <div v-else-if="detError" class="m-empty m-empty--error">{{ detError }}</div>

          <template v-else-if="detalle">
            <div class="m-body">

              <!-- Cabecera incidencia -->
              <div class="det-header">
                <div class="det-header__left">
                  <span :class="['badge', tipoDe(detalle.codigo) === 'bonus' ? 'badge--azul' : 'badge--naranja']">
                    {{ detalle.codigo }}
                  </span>
                  <h2 class="det-title">{{ detalle.codigo_info?.nombre }}</h2>
                </div>
                <span :class="['badge', ESTADO_CFG[detalle.estado]?.cls ?? 'badge--amber']">
                  {{ ESTADO_CFG[detalle.estado]?.label ?? detalle.estado }}
                </span>
              </div>

              <!-- Info principal -->
              <div class="det-card">
                <div class="det-fila">
                  <span class="det-label">Equipo</span>
                  <span>{{ nombreEquipo(detalle.equipo_id) }}</span>
                </div>
                <div v-if="detalle.equipo_apoyado_id" class="det-fila">
                  <span class="det-label">Equipo apoyado</span>
                  <span>{{ nombreEquipo(detalle.equipo_apoyado_id) }}</span>
                </div>
                <div class="det-fila">
                  <span class="det-label">Fecha / Hora</span>
                  <span>{{ detalle.fecha }} {{ detalle.hora?.slice(0,5) }}</span>
                </div>
                <div class="det-fila">
                  <span class="det-label">Puntos</span>
                  <span :class="tipoDe(detalle.codigo) === 'bonus' ? 'pts--bonus' : 'pts--demerito'" style="font-weight:700">
                    {{ tipoDe(detalle.codigo) === 'bonus' ? '+' : '−' }}{{ detalle.puntos }} pts
                  </span>
                </div>
                <div class="det-fila">
                  <span class="det-label">Alcance</span>
                  <span>{{ detalle.alcance }}</span>
                </div>
              </div>

              <!-- Hecho -->
              <div class="det-card">
                <p class="det-section-title">Hecho registrado</p>
                <p class="det-hecho">{{ detalle.hecho }}</p>
                <template v-if="detalle.advertencia_referencia">
                  <p class="det-section-subtitle">Referencia a advertencia previa</p>
                  <p class="det-texto">{{ detalle.advertencia_referencia }}</p>
                </template>
              </div>

              <!-- Integrantes -->
              <div v-if="detalle.integrantes.length" class="det-card">
                <p class="det-section-title">Integrantes involucrados</p>
                <ul class="integrantes-list">
                  <li v-for="ii in detalle.integrantes" :key="ii.id">
                    {{ nombreIntegrante(ii.integrante_id) }}
                  </li>
                </ul>
              </div>

              <!-- Evidencias -->
              <div v-if="detalle.evidencias.length" class="det-card">
                <p class="det-section-title">Evidencia</p>
                <div class="evidencias-grid">
                  <a
                    v-for="ev in detalle.evidencias"
                    :key="ev.id"
                    :href="detUrls[ev.id]"
                    target="_blank"
                    class="evidencia-item"
                  >
                    <img
                      v-if="ev.tipo_archivo.startsWith('image')"
                      :src="detUrls[ev.id]"
                      :alt="ev.nombre_original ?? 'evidencia'"
                      class="evidencia-img"
                    />
                    <div v-else class="evidencia-doc">
                      <i class="pi pi-file-pdf" />
                      <span>{{ ev.nombre_original }}</span>
                    </div>
                  </a>
                </div>
              </div>

              <!-- Resolución existente (validado/rechazado) -->
              <div v-if="detalle.estado !== 'registrado' && detalle.motivo_resolucion" class="det-card det-card--resolucion">
                <p class="det-section-title">Resolución</p>
                <p class="det-texto">{{ detalle.motivo_resolucion }}</p>
                <p v-if="(detalle as any).validado_at" class="det-meta">
                  {{ detalle.estado === 'validado' ? 'Validado' : 'Rechazado' }} el {{ (detalle as any).validado_at?.slice(0,10) }}
                </p>
              </div>

            </div><!-- /m-body -->

            <!-- Acciones: solo si está pendiente -->
            <div v-if="detalle.estado === 'registrado'" class="m-foot">
              <!-- Botones iniciales -->
              <template v-if="!resolviendoId">
                <button class="btn btn--rechazar btn--full-half" @click="iniciarResolucion(detalle.id, 'rechazar')">
                  <i class="pi pi-times-circle" /> Rechazar
                </button>
                <button class="btn btn--validar btn--full-half" @click="iniciarResolucion(detalle.id, 'validar')">
                  <i class="pi pi-check-circle" /> Validar
                </button>
              </template>
              <!-- Panel de confirmación -->
              <template v-else>
                <div class="m-resolucion">
                  <label class="campo-label">
                    {{ resolviendoAccion === 'validar' ? '¿Por qué validar?' : '¿Por qué rechazar?' }}
                    <span class="req">*</span>
                  </label>
                  <textarea v-model="motivo" rows="2" class="campo-input" placeholder="Escribe el motivo…" />
                  <p v-if="errorMotivo" class="error-msg">{{ errorMotivo }}</p>
                  <div class="m-resolucion__btns">
                    <button class="btn btn--ghost btn--sm" @click="cancelarResolucion">Cancelar</button>
                    <button
                      :class="['btn', 'btn--sm', resolviendoAccion === 'validar' ? 'btn--validar' : 'btn--rechazar']"
                      @click="resolver(detalle.id, resolviendoAccion!)"
                    >
                      <i :class="resolviendoAccion === 'validar' ? 'pi pi-check-circle' : 'pi pi-times-circle'" />
                      {{ resolviendoAccion === 'validar' ? 'Confirmar validación' : 'Confirmar rechazo' }}
                    </button>
                  </div>
                </div>
              </template>
            </div>
          </template>

        </div>
      </div>
    </Transition>
  </Teleport>
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
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.bdj-title { font-size: 1.3rem; font-weight: 800; margin: 0; }
.bdj-sub   { font-size: 0.8rem; color: #6b7280; margin: 0.1rem 0 0; }

/* ── Tabs ── */
.bdj-tabs {
  display: flex;
  background: #f3f4f6;
  border-radius: 9px;
  padding: 3px;
  gap: 2px;
  margin-bottom: 1rem;
}
.bdj-tab {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  min-height: 38px;
  border: none;
  border-radius: 7px;
  background: transparent;
  font-size: 0.8rem;
  font-weight: 600;
  color: #6b7280;
  cursor: pointer;
  white-space: nowrap;
  transition: all .15s;
  padding: 0 0.5rem;
}
.bdj-tab--active             { background: white; color: #111827; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.bdj-tab--amber.bdj-tab--active { color: #92400e; }
.bdj-tab--verde.bdj-tab--active { color: #065f46; }
.bdj-tab--rojo.bdj-tab--active  { color: #991b1b; }
.bdj-tab-cnt {
  font-size: 0.68rem;
  background: #e5e7eb;
  color: #374151;
  border-radius: 8px;
  padding: 0 0.3rem;
  min-width: 16px;
  text-align: center;
  line-height: 1.5;
}

/* ── Cards lista ── */
.bdj-lista { display: flex; flex-direction: column; gap: 0.6rem; }
.bdj-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 10px;
  padding: 0.9rem 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.07);
  cursor: pointer;
  transition: box-shadow .15s, transform .1s;
}
.bdj-card:hover { box-shadow: 0 3px 10px rgba(0,0,0,.1); transform: translateY(-1px); }
.bdj-card--bonus    { border-left-color: #16a34a; }
.bdj-card--demerito { border-left-color: #dc2626; }

.bdj-card__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.4rem;
  flex-wrap: wrap;
}
.bdj-card__meta { display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap; flex: 1; }
.bdj-card__equipo { font-weight: 700; font-size: 0.9rem; }
.bdj-pts { font-weight: 800; font-size: 1rem; white-space: nowrap; }
.pts--bonus    { color: #16a34a; }
.pts--demerito { color: #dc2626; }
.bdj-card__hecho {
  font-size: 0.86rem; color: #374151; margin: 0 0 0.35rem; line-height: 1.4;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}
.bdj-card__info { font-size: 0.76rem; color: #9ca3af; display: flex; gap: 0.25rem; }

/* ── Badges ── */
.badge {
  border-radius: 4px; font-size: 0.7rem; font-weight: 700;
  padding: 0.15rem 0.45rem; text-transform: uppercase; white-space: nowrap; flex-shrink: 0;
}
.badge--azul    { background: #dcfce7; color: #166534; }
.badge--naranja { background: #fed7aa; color: #c2410c; }
.badge--verde   { background: #d1fae5; color: #065f46; }
.badge--rojo    { background: #fee2e2; color: #991b1b; }
.badge--amber   { background: #fef3c7; color: #92400e; }

/* ── Empty ── */
.bdj-empty {
  display: flex; flex-direction: column; align-items: center; gap: 0.5rem;
  padding: 3.5rem 1rem; text-align: center; color: #6b7280; font-size: 0.9rem;
}
.bdj-empty__icon {
  width: 56px; height: 56px; border-radius: 50%;
  background: #d1fae5; display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem; color: #16a34a; margin-bottom: 0.25rem;
}
.bdj-empty--error { color: #dc2626; }

/* ── Botones ── */
.btn {
  display: inline-flex; align-items: center; gap: 0.35rem;
  min-height: 44px; padding: 0.5rem 1rem; border-radius: 8px; border: none;
  font-size: 0.88rem; font-weight: 600; cursor: pointer; transition: background 0.15s; white-space: nowrap;
}
.btn--sm { min-height: 40px; padding: 0.45rem 0.85rem; font-size: 0.84rem; }
.btn--ghost   { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn--ghost:hover { background: #f9fafb; }
.btn--validar  { background: #16a34a; color: white; }
.btn--validar:hover  { background: #15803d; }
.btn--rechazar { background: #dc2626; color: white; }
.btn--rechazar:hover { background: #b91c1c; }
.btn--full-half { flex: 1; justify-content: center; }
.btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>

<!-- Modal: estilos globales (fuera de scoped por Teleport) -->
<style>
.m-enter { animation: mSlideUp .25s ease; }
.m-leave { animation: mSlideUp .2s ease reverse; }
@keyframes mSlideUp {
  from { opacity: 0; transform: translateY(40px); }
  to   { opacity: 1; transform: translateY(0); }
}

.m-overlay {
  position: fixed; inset: 0; z-index: 300;
  background: rgba(0,0,0,.45);
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) {
  .m-overlay { align-items: center; padding: 1rem; }
}

.m-panel {
  position: relative;
  width: 100%; max-width: 560px;
  background: white;
  border-radius: 20px 20px 0 0;
  max-height: 92dvh;
  display: flex; flex-direction: column;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
}
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }

.m-head {
  display: flex; align-items: center; gap: 0.75rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.m-close {
  width: 36px; height: 36px; border-radius: 8px;
  border: none; background: #f1f5f9; color: #374151;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.9rem; flex-shrink: 0;
  transition: background .15s;
}
.m-close:hover { background: #e5e7eb; }
.m-head__title { font-size: 1rem; font-weight: 700; color: #111827; }

.m-body { overflow-y: auto; padding: 1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: 0.75rem; }

.m-empty { display: flex; align-items: center; justify-content: center; padding: 3rem; color: #6b7280; }
.m-empty--error { color: #dc2626; }

.m-foot {
  display: flex; gap: 0.5rem;
  padding: 0.85rem 1.25rem;
  border-top: 1px solid #f1f5f9;
  flex-shrink: 0;
}

.m-resolucion { width: 100%; display: flex; flex-direction: column; gap: 0.4rem; }
.m-resolucion__btns { display: flex; gap: 0.5rem; justify-content: flex-end; margin-top: 0.25rem; }

/* Detalle dentro del modal */
.det-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 0.5rem; flex-wrap: wrap; }
.det-header__left { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
.det-title { font-size: 1rem; font-weight: 700; margin: 0; }

.det-card {
  background: #f9fafb; border: 1px solid #f1f5f9; border-radius: 10px; padding: 0.85rem;
}
.det-card--resolucion { background: #f0fdf4; border-color: #dcfce7; }

.det-section-title    { font-size: 0.8rem; font-weight: 700; color: #374151; margin: 0 0 0.5rem; }
.det-section-subtitle { font-size: 0.78rem; font-weight: 600; color: #6b7280; margin: 0.5rem 0 0.25rem; }

.det-fila { display: flex; gap: 0.75rem; font-size: 0.88rem; margin-bottom: 0.35rem; align-items: flex-start; }
.det-label { min-width: 100px; font-weight: 600; color: #6b7280; flex-shrink: 0; font-size: 0.82rem; }
.det-hecho { font-size: 0.9rem; line-height: 1.5; margin: 0; color: #374151; }
.det-texto { font-size: 0.88rem; color: #374151; margin: 0; line-height: 1.4; }
.det-meta  { font-size: 0.78rem; color: #9ca3af; margin-top: 0.3rem; }

.integrantes-list { margin: 0; padding-left: 1.2rem; font-size: 0.88rem; }
.integrantes-list li { margin-bottom: 0.2rem; }

.evidencias-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.evidencia-item  { display: block; }
.evidencia-img   { width: 80px; height: 80px; object-fit: cover; border-radius: 8px; border: 1px solid #e5e7eb; }
.evidencia-doc {
  display: flex; flex-direction: column; align-items: center; gap: 0.2rem;
  width: 80px; padding: 0.5rem; border: 1px solid #e5e7eb; border-radius: 8px;
  font-size: 0.72rem; color: #374151; text-align: center;
}
.evidencia-doc i { font-size: 1.4rem; color: #dc2626; }

.campo-label { display: block; font-size: 0.8rem; font-weight: 600; color: #374151; margin-bottom: 0.2rem; }
.campo-input {
  width: 100%; min-height: 44px; padding: 0.5rem 0.6rem;
  border: 1px solid #d1d5db; border-radius: 6px; font-size: 0.9rem;
  background: white; box-sizing: border-box;
}
.campo-input:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
textarea.campo-input { resize: vertical; min-height: 68px; }
.req { color: #dc2626; }
.error-msg { color: #dc2626; font-size: 0.8rem; margin-top: 0.2rem; }
</style>
