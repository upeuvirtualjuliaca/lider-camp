<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'
import {
  diasService,
  observacionesService,
  programacionRubricaService,
  type DiasEvaluacion,
  type PuntajeEquipoDia,
  type ProgresoEvaluacion,
} from '@/modules/observaciones/services/observaciones.service'
import {
  evaluacionesService,
  type LiderazgoEquipoDia,
} from '@/modules/liderazgo/services/liderazgo.service'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'

// ── Tipos ────────────────────────────────────────────────────────────────────
interface ProgramacionDia {
  id: string
  momento: string
  estado: string
  motivo: string | null
  puntaje_max: number
  criterio_id: string
  criterios: {
    id: string
    codigo: string
    nombre: string
    orden: number
    tipo_calculo: string
    activo: boolean
  }
}

// ── Constantes ────────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

// ── Estado ────────────────────────────────────────────────────────────────────
const session = useSessionStore()
const campStore = useCampamentoStore()
const cargando = ref(true)
const error = ref('')

const dias = ref<DiasEvaluacion[]>([])
const momentoActivo = ref<string>('')

const equipos = ref<Equipo[]>([])
const programacionDia = ref<ProgramacionDia[]>([])
const puntajesDia = ref<PuntajeEquipoDia[]>([])
const progreso = ref<ProgresoEvaluacion[]>([])
const liderazgoDia = ref<LiderazgoEquipoDia[]>([])

// Observaciones por criterio+equipo: clave `${programacion_id}|${equipo_id}`
const obsMap = ref<Map<string, number | null>>(new Map())

// Dialogs
const dialogCerrar = ref(false)
const dialogAbrir = ref(false)
const procesandoDia = ref(false)
const errorDialog = ref('')

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const [, diasData, equiposData] = await Promise.all([
      cargarCampamento(),
      campStore.selectedId ? diasService.getTodos(campStore.selectedId) : Promise.resolve([]),
      equiposService.getTodos(campStore.selectedId ?? undefined),
    ])

    momentoActivo.value = detectarMomentoActual()
    dias.value = diasData
    equipos.value = equiposData.filter((e) => e.activo)

    await cargarDatosDia()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

// ── Helpers ───────────────────────────────────────────────────────────────────
const diaActual = computed<DiasEvaluacion | undefined>(() =>
  dias.value.find((d) => d.momento === momentoActivo.value),
)

const diaCerrado = computed(() => diaActual.value?.cerrado ?? false)

const progresoDelDia = computed<ProgresoEvaluacion | undefined>(() =>
  progreso.value.find((p) => p.momento === momentoActivo.value),
)

const porcentaje = computed(() => Math.round(progresoDelDia.value?.porcentaje ?? 0))

const progresoBg = computed(() => {
  if (porcentaje.value >= 100) return 'bg-green-500'
  if (porcentaje.value >= 60) return 'bg-yellow-400'
  return 'bg-red-400'
})

async function cargarDatosDia() {
  try {
    const campId = campStore.selectedId
    const { data: progData, error: errProg } = await supabase_safe(() =>
      programacionRubricaService.getPorDia(momentoActivo.value, campId),
    )
    if (errProg) throw new Error(errProg)
    programacionDia.value = progData as unknown as ProgramacionDia[]

    const [puntajes, progresoData, lidData] = await Promise.all([
      observacionesService.getPuntajeEquipoDia(momentoActivo.value, campId),
      observacionesService.getProgreso(campId),
      evaluacionesService.getResumenDia(momentoActivo.value, campId),
    ])

    puntajesDia.value = puntajes
    progreso.value = progresoData
    liderazgoDia.value = lidData

    await cargarObservacionesDetalle()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos del día'
  }
}

async function cargarObservacionesDetalle() {
  obsMap.value = new Map()
  const promises = programacionDia.value
    .filter((p) => p.estado === 'programado')
    .map(async (prog) => {
      try {
        const obs = await observacionesService.getPorCriterioYDia(prog.id)
        for (const o of obs) {
          obsMap.value.set(`${prog.id}|${o.equipo_id}`, o.puntaje)
        }
      } catch {
        // silencioso por criterio
      }
    })
  await Promise.all(promises)
}

async function seleccionarMomento(m: string) {
  momentoActivo.value = m
  await cargarDatosDia()
}

// ── Celda de la matriz ────────────────────────────────────────────────────────
function getCelda(
  prog: ProgramacionDia,
  equipo: Equipo,
): { tipo: 'puntaje' | 'cancelado' | 'na' | 'pendiente'; valor: number | null } {
  if (prog.estado === 'no_programado') return { tipo: 'na', valor: null }
  if (prog.estado === 'cancelado') return { tipo: 'cancelado', valor: null }
  const key = `${prog.id}|${equipo.id}`
  const val = obsMap.value.get(key)
  if (val !== undefined && val !== null) return { tipo: 'puntaje', valor: val }
  return { tipo: 'pendiente', valor: null }
}

function celdaClase(tipo: string) {
  if (tipo === 'puntaje')   return 'bg-green-100 text-green-800 font-bold'
  if (tipo === 'pendiente') return 'bg-yellow-50 text-yellow-700'
  if (tipo === 'cancelado') return 'bg-red-50 text-red-500 text-[10px] font-semibold'
  return 'bg-gray-50 text-gray-400'
}

// ── Cerrar / Abrir día ────────────────────────────────────────────────────────
async function cerrarDia() {
  procesandoDia.value = true
  errorDialog.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    const updated = await diasService.cerrar(campStore.selectedId, momentoActivo.value, session.user!.id)
    const idx = dias.value.findIndex((d) => d.momento === momentoActivo.value)
    if (idx !== -1) dias.value[idx] = updated
    dialogCerrar.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al cerrar el día'
  } finally {
    procesandoDia.value = false
  }
}

async function abrirDia() {
  procesandoDia.value = true
  errorDialog.value = ''
  try {
    if (!campStore.selectedId) throw new Error('No hay campamento seleccionado.')
    const updated = await diasService.abrir(campStore.selectedId, momentoActivo.value)
    const idx = dias.value.findIndex((d) => d.momento === momentoActivo.value)
    if (idx !== -1) dias.value[idx] = updated
    dialogAbrir.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al reabrir el día'
  } finally {
    procesandoDia.value = false
  }
}

// ── Celda de liderazgo ────────────────────────────────────────────────────────
function getLidCelda(equipo: Equipo): { clase: string; texto: string } {
  const d = liderazgoDia.value.find((r) => r.equipo_id === equipo.id)
  if (!d) return { clase: 'bg-gray-50 text-gray-400', texto: '—' }
  if ((d.indicadores_calificados ?? 0) === 0) return { clase: 'bg-yellow-50 text-yellow-700', texto: '' }
  const pts = Number(d.puntos_obtenidos)
  const texto = `${pts % 1 === 0 ? pts : pts.toFixed(1)} (${d.indicadores_calificados}/${d.total_indicadores})`
  const clase = d.indicadores_calificados === d.total_indicadores
    ? 'bg-green-100 text-green-800 font-bold'
    : 'bg-yellow-50 text-yellow-700'
  return { clase, texto }
}

// wrapper helper
async function supabase_safe<T>(fn: () => Promise<T>): Promise<{ data: T; error: null } | { data: null; error: string }> {
  try {
    const data = await fn()
    return { data, error: null }
  } catch (e: unknown) {
    return { data: null, error: e instanceof Error ? e.message : 'Error desconocido' }
  }
}
</script>

<template>
  <div class="av-page">

    <!-- ── Header ── -->
    <header class="av-header">
      <div>
        <h1 class="av-title">Avance de evaluación</h1>
        <p class="av-sub">Progreso del día por criterio y equipo</p>
      </div>
    </header>

    <!-- ── Cargando / Error ── -->
    <div v-if="cargando" class="av-empty">
      <i class="pi pi-spin pi-spinner" style="font-size:1.5rem" />
    </div>
    <div v-else-if="error" class="av-empty av-empty--error">
      <i class="pi pi-exclamation-circle" /> {{ error }}
    </div>

    <template v-else>

      <!-- ── Selector de día ── -->
      <div class="av-dias">
        <button
          v-for="m in momentos"
          :key="m"
          :class="['av-dia-btn',
            momentoActivo === m && 'av-dia-btn--active',
            dias.find(d => d.momento === m)?.cerrado && momentoActivo !== m && 'av-dia-btn--cerrado']"
          @click="seleccionarMomento(m)"
        >
          {{ labelDia(m) }}
          <span v-if="dias.find(d => d.momento === m)?.cerrado" class="av-dia-badge">
            <i class="pi pi-lock" />
          </span>
        </button>
      </div>

      <!-- ── Tarjeta de progreso ── -->
      <div v-if="progresoDelDia" class="av-progreso-card">
        <div class="av-progreso-card__top">
          <span class="av-progreso-card__texto">
            <strong>{{ progresoDelDia.observaciones_registradas ?? 0 }}</strong>
            de
            <strong>{{ progresoDelDia.observaciones_esperadas ?? 0 }}</strong>
            observaciones registradas
          </span>
          <span
            :class="['av-pct',
              porcentaje >= 100 ? 'av-pct--ok' :
              porcentaje >= 60  ? 'av-pct--mid' : 'av-pct--low']"
          >{{ porcentaje }}%</span>
        </div>
        <div class="av-barra">
          <div
            class="av-barra__fill"
            :class="porcentaje >= 100 ? 'av-barra__fill--ok' : porcentaje >= 60 ? 'av-barra__fill--mid' : 'av-barra__fill--low'"
            :style="{ width: Math.min(porcentaje, 100) + '%' }"
          />
        </div>
      </div>

      <!-- ── Cerrar / Reabrir día ── -->
      <div class="av-acciones">
        <button v-if="!diaCerrado" class="btn btn--amber" @click="dialogCerrar = true">
          <i class="pi pi-lock" /> Cerrar día
        </button>
        <button v-else class="btn btn--ghost" @click="dialogAbrir = true">
          <i class="pi pi-lock-open" /> Reabrir día
        </button>
        <span :class="['av-estado-badge', diaCerrado ? 'av-estado-badge--cerrado' : 'av-estado-badge--abierto']">
          <i :class="diaCerrado ? 'pi pi-lock' : 'pi pi-lock-open'" />
          {{ diaCerrado ? 'Día cerrado' : 'Día abierto' }}
        </span>
      </div>

      <!-- ── Matriz criterios × equipos ── -->
      <div class="av-matriz-wrap">
        <div class="av-matriz-header">
          <p class="av-matriz-titulo">Observaciones — {{ labelDia(momentoActivo) }}</p>
          <div class="av-leyenda">
            <span class="av-leyenda-item">
              <span class="av-leyenda-dot av-leyenda-dot--ok" /> Registrado
            </span>
            <span class="av-leyenda-item">
              <span class="av-leyenda-dot av-leyenda-dot--pend" /> Pendiente
            </span>
            <span class="av-leyenda-item">
              <span class="av-leyenda-dot av-leyenda-dot--canc" /> Cancelado
            </span>
            <span class="av-leyenda-item">
              <span class="av-leyenda-dot av-leyenda-dot--na" /> N/A
            </span>
          </div>
        </div>

        <div class="av-tabla-scroll">
          <table class="av-tabla">
            <thead>
              <tr>
                <th class="av-th av-th--sticky">Criterio</th>
                <th v-for="eq in equipos" :key="eq.id" class="av-th av-th--eq">
                  <span class="av-eq-dot" :style="{ background: eq.color }" />
                  <span class="av-eq-nombre" :title="eq.nombre">{{ eq.nombre }}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <!-- Filas de criterios -->
              <tr v-for="prog in programacionDia" :key="prog.id" class="av-fila">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-badge">{{ prog.criterios.codigo }}</span>
                  <span class="av-criterio-nombre">{{ prog.criterios.nombre }}</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  :class="['av-td', 'av-td--celda', `av-celda--${getCelda(prog, eq).tipo}`]"
                >
                  <template v-if="getCelda(prog, eq).tipo === 'puntaje'">{{ getCelda(prog, eq).valor }}</template>
                  <template v-else-if="getCelda(prog, eq).tipo === 'cancelado'">✕</template>
                  <template v-else-if="getCelda(prog, eq).tipo === 'na'">—</template>
                </td>
              </tr>

              <!-- Fila Liderazgo -->
              <tr v-if="liderazgoDia.length > 0" class="av-fila av-fila--lid">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-badge av-criterio-badge--lid">LID</span>
                  <span class="av-criterio-nombre">Liderazgo</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  :class="['av-td', 'av-td--celda', getLidCelda(eq).clase]"
                >
                  {{ getLidCelda(eq).texto }}
                </td>
              </tr>

              <!-- Sin datos -->
              <tr v-if="!programacionDia.length && !liderazgoDia.length">
                <td :colspan="equipos.length + 1" class="av-td-vacio">
                  Sin criterios programados para este día.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

    </template>

    <!-- ── Modal cerrar día ── -->
    <Teleport to="body">
      <div v-if="dialogCerrar" class="m-overlay" @click.self="dialogCerrar = false">
        <div class="m-confirm">
          <div class="m-confirm__drag" />
          <div class="m-confirm__icon m-confirm__icon--amber">
            <i class="pi pi-lock" />
          </div>
          <h3 class="m-confirm__title">¿Cerrar el día?</h3>
          <p class="m-confirm__dia">{{ labelDia(momentoActivo) }}</p>
          <p class="m-confirm__desc">Los evaluadores ya no podrán registrar observaciones.</p>
          <div v-if="errorDialog" class="m-confirm__error">
            <i class="pi pi-exclamation-circle" /> {{ errorDialog }}
          </div>
          <div class="m-confirm__btns">
            <button class="btn btn--ghost" :disabled="procesandoDia" @click="dialogCerrar = false">Cancelar</button>
            <button class="btn btn--amber" :disabled="procesandoDia" @click="cerrarDia">
              <i :class="procesandoDia ? 'pi pi-spin pi-spinner' : 'pi pi-lock'" />
              {{ procesandoDia ? 'Cerrando…' : 'Cerrar día' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal reabrir día ── -->
    <Teleport to="body">
      <div v-if="dialogAbrir" class="m-overlay" @click.self="dialogAbrir = false">
        <div class="m-confirm">
          <div class="m-confirm__drag" />
          <div class="m-confirm__icon m-confirm__icon--green">
            <i class="pi pi-lock-open" />
          </div>
          <h3 class="m-confirm__title">¿Reabrir el día?</h3>
          <p class="m-confirm__dia">{{ labelDia(momentoActivo) }}</p>
          <p class="m-confirm__desc">Los evaluadores podrán volver a registrar observaciones.</p>
          <div v-if="errorDialog" class="m-confirm__error">
            <i class="pi pi-exclamation-circle" /> {{ errorDialog }}
          </div>
          <div class="m-confirm__btns">
            <button class="btn btn--ghost" :disabled="procesandoDia" @click="dialogAbrir = false">Cancelar</button>
            <button class="btn btn--primary" :disabled="procesandoDia" @click="abrirDia">
              <i :class="procesandoDia ? 'pi pi-spin pi-spinner' : 'pi pi-lock-open'" />
              {{ procesandoDia ? 'Reabriendo…' : 'Reabrir día' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
/* ─── Page ─── */
.av-page {
  max-width: 900px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* ─── Header ─── */
.av-header { margin-bottom: 1rem; }
.av-title  { font-size: 1.3rem; font-weight: 800; margin: 0; }
.av-sub    { font-size: 0.8rem; color: #6b7280; margin: 0.1rem 0 0; }

/* ─── Empty ─── */
.av-empty {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.5rem; padding: 3rem 1rem;
  text-align: center; color: #9ca3af; font-size: 0.88rem;
}
.av-empty--error { color: #dc2626; }

/* ─── Selector de días ─── */
.av-dias {
  display: flex;
  gap: 0.5rem;
  overflow-x: auto;
  padding-bottom: 4px;
  margin-bottom: 1rem;
  scrollbar-width: none;
}
.av-dias::-webkit-scrollbar { display: none; }

.av-dia-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  min-height: 44px;
  padding: 0.5rem 1.1rem;
  border-radius: 22px;
  border: 2px solid #e5e7eb;
  background: white;
  font-size: 0.88rem;
  font-weight: 600;
  color: #6b7280;
  cursor: pointer;
  white-space: nowrap;
  transition: all .15s;
  flex-shrink: 0;
}
.av-dia-btn:hover { border-color: #bbf7d0; color: #15803d; }
.av-dia-btn--active { background: #16a34a; border-color: #16a34a; color: white; }
.av-dia-btn--cerrado { background: #fffbeb; border-color: #fde68a; color: #92400e; }

.av-dia-badge {
  display: inline-flex;
  align-items: center;
  font-size: 0.65rem;
  opacity: .85;
}

/* ─── Progreso ─── */
.av-progreso-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  padding: 1rem;
  margin-bottom: 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.av-progreso-card__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.6rem;
}
.av-progreso-card__texto { font-size: 0.88rem; color: #6b7280; }
.av-progreso-card__texto strong { color: #111827; }

.av-pct { font-size: 1.2rem; font-weight: 800; white-space: nowrap; }
.av-pct--ok  { color: #16a34a; }
.av-pct--mid { color: #d97706; }
.av-pct--low { color: #dc2626; }

.av-barra {
  height: 10px;
  background: #f3f4f6;
  border-radius: 5px;
  overflow: hidden;
}
.av-barra__fill {
  height: 100%;
  border-radius: 5px;
  transition: width .5s ease;
}
.av-barra__fill--ok  { background: #16a34a; }
.av-barra__fill--mid { background: #f59e0b; }
.av-barra__fill--low { background: #ef4444; }

/* ─── Acciones cerrar/reabrir ─── */
.av-acciones {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.av-estado-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.82rem;
  font-weight: 600;
  padding: 0.4rem 0.75rem;
  border-radius: 8px;
  border: 1px solid;
}
.av-estado-badge--abierto { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }
.av-estado-badge--cerrado { background: #fffbeb; border-color: #fde68a; color: #92400e; }

/* ─── Botones ─── */
.btn {
  display: inline-flex; align-items: center; gap: 0.4rem;
  min-height: 44px; padding: 0.5rem 1.1rem;
  border-radius: 8px; border: none;
  font-size: 0.88rem; font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: background .15s;
}
.btn:disabled { opacity: 0.5; cursor: not-allowed; }
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover:not(:disabled) { background: #15803d; }
.btn--amber { background: #f59e0b; color: white; }
.btn--amber:hover:not(:disabled) { background: #d97706; }
.btn--ghost { background: white; border: 2px solid #d1d5db; color: #374151; }
.btn--ghost:hover:not(:disabled) { background: #f9fafb; }

/* ─── Matriz ─── */
.av-matriz-wrap {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.av-matriz-header {
  padding: 0.85rem 1rem 0.6rem;
  border-bottom: 1px solid #f3f4f6;
}
.av-matriz-titulo {
  font-size: 0.72rem;
  font-weight: 700;
  color: #9ca3af;
  text-transform: uppercase;
  letter-spacing: .05em;
  margin: 0 0 0.5rem;
}
.av-leyenda {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}
.av-leyenda-item {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.72rem;
  color: #6b7280;
}
.av-leyenda-dot {
  width: 10px; height: 10px;
  border-radius: 3px; flex-shrink: 0;
  border: 1px solid transparent;
}
.av-leyenda-dot--ok   { background: #bbf7d0; border-color: #86efac; }
.av-leyenda-dot--pend { background: #fef9c3; border-color: #fde047; }
.av-leyenda-dot--canc { background: #fecaca; border-color: #f87171; }
.av-leyenda-dot--na   { background: #f3f4f6; border-color: #d1d5db; }

.av-tabla-scroll { overflow-x: auto; }
.av-tabla { border-collapse: collapse; width: 100%; min-width: max-content; }

/* Cabecera */
.av-th {
  padding: 0.6rem 0.5rem;
  background: #f0fdf4;
  border-bottom: 2px solid #bbf7d0;
  font-size: 0.7rem;
  font-weight: 700;
  color: #374151;
  white-space: nowrap;
}
.av-th--sticky {
  text-align: left;
  position: sticky; left: 0; z-index: 10;
  background: #f0fdf4;
  border-right: 1px solid #bbf7d0;
  min-width: 140px;
}
.av-th--eq {
  text-align: center;
  min-width: 60px;
}
.av-eq-dot {
  display: block;
  width: 10px; height: 10px;
  border-radius: 50%;
  margin: 0 auto 0.2rem;
}
.av-eq-nombre {
  display: block;
  font-size: 0.65rem;
  font-weight: 700;
  color: #4b5563;
  max-width: 56px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Filas */
.av-fila:hover td { filter: brightness(.97); }
.av-fila--lid td  { background: #fafafa; }

.av-td {
  padding: 0.45rem 0.4rem;
  border-bottom: 1px solid #f3f4f6;
  font-size: 0.78rem;
  vertical-align: middle;
}
.av-td--sticky {
  position: sticky; left: 0; z-index: 5;
  background: white;
  border-right: 1px solid #f3f4f6;
  padding: 0.5rem 0.6rem;
  display: flex;
  align-items: center;
  gap: 0.4rem;
}
.av-td--celda {
  text-align: center;
  font-weight: 700;
  font-size: 0.75rem;
}

/* Criterio badge y nombre */
.av-criterio-badge {
  font-size: 0.62rem; font-weight: 800;
  background: #f3f4f6; color: #4b5563;
  border-radius: 4px; padding: 0.1rem 0.35rem;
  white-space: nowrap; flex-shrink: 0;
}
.av-criterio-badge--lid {
  background: #e0e7ff; color: #3730a3;
}
.av-criterio-nombre {
  font-size: 0.72rem; color: #374151;
  line-height: 1.3;
}

/* Celdas coloreadas */
.av-celda--puntaje   { background: #dcfce7; color: #166534; }
.av-celda--pendiente { background: #fefce8; color: #713f12; }
.av-celda--cancelado { background: #fee2e2; color: #991b1b; font-size: 0.65rem; }
.av-celda--na        { background: #f9fafb; color: #9ca3af; }

/* Clases que viene del script (getLidCelda) — sobrescribir */
.bg-green-100  { background: #dcfce7 !important; }
.text-green-800 { color: #166534 !important; }
.bg-yellow-50  { background: #fefce8 !important; }
.text-yellow-700 { color: #713f12 !important; }

.av-td-vacio {
  padding: 2rem; text-align: center;
  color: #9ca3af; font-size: 0.88rem;
}

/* ─── Modal confirm ─── */
.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
  background: rgba(0,0,0,.45);
  backdrop-filter: blur(4px);
}
@media (min-width: 640px) {
  .m-overlay { align-items: center; }
}

.m-confirm {
  position: relative;
  width: 100%; max-width: 360px;
  background: white;
  border-radius: 20px 20px 0 0;
  padding: 1.25rem 1.5rem 2rem;
  box-shadow: 0 -4px 24px rgba(0,0,0,.15);
  display: flex; flex-direction: column; align-items: center; gap: 0.4rem;
}
@media (min-width: 640px) {
  .m-confirm { border-radius: 16px; padding: 1.5rem; }
}

.m-confirm__drag {
  width: 36px; height: 4px;
  border-radius: 2px; background: #e5e7eb;
  margin-bottom: 0.5rem;
}
@media (min-width: 640px) { .m-confirm__drag { display: none; } }

.m-confirm__icon {
  width: 52px; height: 52px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.4rem;
  margin-bottom: 0.25rem;
}
.m-confirm__icon--amber { background: #fef3c7; color: #d97706; }
.m-confirm__icon--green { background: #dcfce7; color: #16a34a; }

.m-confirm__title { font-size: 1rem; font-weight: 800; color: #111827; margin: 0; }
.m-confirm__dia   { font-size: 0.88rem; color: #374151; margin: 0; }
.m-confirm__desc  { font-size: 0.8rem; color: #9ca3af; margin: 0 0 0.5rem; text-align: center; }

.m-confirm__error {
  display: flex; align-items: center; gap: 0.4rem;
  background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 8px; padding: 0.6rem 0.75rem;
  font-size: 0.82rem; color: #b91c1c;
  width: 100%; margin-bottom: 0.25rem;
}

.m-confirm__btns {
  display: flex; gap: 0.5rem; width: 100%; margin-top: 0.5rem;
}
.m-confirm__btns .btn { flex: 1; justify-content: center; }
</style>
