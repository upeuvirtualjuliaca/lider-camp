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
import {
  actividadesService,
  evalRegistrosService,
  type ActividadConProgramacion,
} from '@/modules/asistencia/services/asistencia.service'
import { incidenciasService } from '@/modules/incidencias/services/incidencias.service'
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
const momentosConProg = ref<Set<string>>(new Set())

const equipos = ref<Equipo[]>([])
const programacionDia = ref<ProgramacionDia[]>([])
const puntajesDia = ref<PuntajeEquipoDia[]>([])
const progreso = ref<ProgresoEvaluacion[]>([])
const liderazgoDia = ref<LiderazgoEquipoDia[]>([])
const actividadesDia = ref<ActividadConProgramacion[]>([])
// clave: `${actividad_id}|${equipo_id}` → puntaje
const actMap = ref<Map<string, number | null>>(new Map())
// equipo_id → total bonus / deméritos
const bonusMap    = ref<Map<string, number>>(new Map())
const demeritosMap = ref<Map<string, number>>(new Map())

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
    const [, diasData, equiposData, momentosRubrica, conteosAct] = await Promise.all([
      cargarCampamento(),
      campStore.selectedId ? diasService.getTodos(campStore.selectedId) : Promise.resolve([]),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      programacionRubricaService.getMomentosConProgramacion(campStore.selectedId),
      campStore.selectedId ? actividadesService.getConteosPorCampamento(campStore.selectedId) : Promise.resolve({} as Record<string, number>),
    ])
    momentosConProg.value = new Set([...momentosRubrica, ...Object.keys(conteosAct)])

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
const momentosFiltrados = computed(() =>
  momentos.value.filter((m) => momentosConProg.value.has(m)),
)

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

// Total del día por equipo: rúbrica + actividades + liderazgo + bonus − deméritos
const totalDiaMap = computed(() => {
  const map = new Map<string, number>()
  for (const eq of equipos.value) {
    const rubrica   = Number(puntajesDia.value.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
    const lid       = Number(liderazgoDia.value.find((l) => l.equipo_id === eq.id)?.puntos_obtenidos ?? 0)
    const bonus     = bonusMap.value.get(eq.id) ?? 0
    const demeritos = demeritosMap.value.get(eq.id) ?? 0

    // Suma de actividades de este equipo
    let actividades = 0
    for (const act of actividadesDia.value) {
      actividades += actMap.value.get(`${act.id}|${eq.id}`) ?? 0
    }

    map.set(eq.id, Math.max(0, rubrica + lid + actividades + bonus - demeritos))
  }
  return map
})

async function cargarDatosDia() {
  try {
    const campId = campStore.selectedId
    const { data: progData, error: errProg } = await supabase_safe(() =>
      programacionRubricaService.getPorDia(momentoActivo.value, campId),
    )
    if (errProg) throw new Error(errProg)
    programacionDia.value = progData as unknown as ProgramacionDia[]

    const [puntajes, progresoData, lidData, actData] = await Promise.all([
      observacionesService.getPuntajeEquipoDia(momentoActivo.value, campId),
      observacionesService.getProgreso(campId),
      evaluacionesService.getResumenDia(momentoActivo.value, campId),
      actividadesService.getPorDia(momentoActivo.value),
    ])

    puntajesDia.value = puntajes
    progreso.value = progresoData
    liderazgoDia.value = lidData
    const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
    // Contar actividades por programacion_id para dividir el puntaje_max
    const contProg: Record<string, number> = {}
    for (const a of actFiltradas) {
      const pid = a.programacion_id ?? ''
      contProg[pid] = (contProg[pid] ?? 0) + 1
    }
    actividadesDia.value = actFiltradas.map((a) => ({
      ...a,
      _puntaje_individual: Math.round(a.programacion.puntaje_max / (contProg[a.programacion_id ?? ''] ?? 1)),
    })) as any

    // Cargar puntajes por equipo para cada actividad (suma de actividad_eval_registros)
    const newActMap = new Map<string, number | null>()
    await Promise.all(
      actFiltradas.map(async (a) => {
        try {
          const registros = await evalRegistrosService.getPorActividad(a.id)
          // Agrupar por (criterio, equipo) y promediar entre evaluadores
          const byKey = new Map<string, number[]>()
          for (const r of registros) {
            const key = `${r.criterio_eval_id}|${r.equipo_id}`
            if (!byKey.has(key)) byKey.set(key, [])
            byKey.get(key)!.push(Number(r.puntaje))
          }
          // Sumar promedios por equipo
          const totales: Record<string, number> = {}
          for (const [key, puntajes] of byKey) {
            const equipoId = key.split('|')[1] ?? ''
            if (!equipoId) continue
            const avg = puntajes.reduce((a, b) => a + b, 0) / puntajes.length
            totales[equipoId] = (totales[equipoId] ?? 0) + avg
          }
          for (const [equipoId, total] of Object.entries(totales)) {
            newActMap.set(`${a.id}|${equipoId}`, total)
          }
        } catch { /* silencioso */ }
      }),
    )
    actMap.value = newActMap

    // Cargar bonus y deméritos validados solo del día activo
    const newBonusMap     = new Map<string, number>()
    const newDemeritosMap = new Map<string, number>()
    const incData = await incidenciasService.getValidadasPorMomento(momentoActivo.value, campId)
    for (const inc of incData) {
      if (inc.tipo === 'bonus') {
        newBonusMap.set(inc.equipo_id, (newBonusMap.get(inc.equipo_id) ?? 0) + inc.puntos)
      } else if (inc.tipo === 'demerito') {
        newDemeritosMap.set(inc.equipo_id, (newDemeritosMap.get(inc.equipo_id) ?? 0) + inc.puntos)
      }
    }
    bonusMap.value     = newBonusMap
    demeritosMap.value = newDemeritosMap

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
        // Agrupar por equipo y promediar (puede haber varios evaluadores por equipo)
        const byEquipo = new Map<string, number[]>()
        for (const o of obs) {
          if (!byEquipo.has(o.equipo_id)) byEquipo.set(o.equipo_id, [])
          byEquipo.get(o.equipo_id)!.push(o.puntaje)
        }
        for (const [equipo_id, puntajes] of byEquipo) {
          const avg = Math.round(puntajes.reduce((a, b) => a + b, 0) / puntajes.length)
          obsMap.value.set(`${prog.id}|${equipo_id}`, avg)
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
          v-for="m in momentosFiltrados"
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
              <tr v-for="(prog, idx) in programacionDia" :key="prog.id" class="av-fila">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-num">{{ idx + 1 }}</span>
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

              <!-- Filas de actividades -->
              <tr v-for="act in actividadesDia" :key="act.id" class="av-fila av-fila--act">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-num">Act</span>
                  <span class="av-criterio-nombre">{{ act.nombre }}</span>
                  <span class="av-act-pts">{{ (act as any)._puntaje_individual }} pts</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  :class="['av-td', 'av-td--celda',
                    actMap.get(`${act.id}|${eq.id}`) != null
                      ? 'av-celda--puntaje'
                      : 'av-celda--pendiente']"
                >
                  {{ actMap.get(`${act.id}|${eq.id}`) ?? '—' }}
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

              <!-- Fila Bonus -->
              <tr v-if="bonusMap.size > 0" class="av-fila av-fila--bonus">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-num">B</span>
                  <span class="av-criterio-nombre">Bonus (validados)</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  :class="['av-td', 'av-td--celda',
                    bonusMap.get(eq.id) ? 'av-celda--bonus' : 'av-celda--na']"
                >{{ bonusMap.get(eq.id) ?? '—' }}</td>
              </tr>

              <!-- Fila Deméritos -->
              <tr v-if="demeritosMap.size > 0" class="av-fila av-fila--demerito">
                <td class="av-td av-td--sticky">
                  <span class="av-criterio-num">D</span>
                  <span class="av-criterio-nombre">Deméritos (validados)</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  :class="['av-td', 'av-td--celda',
                    demeritosMap.get(eq.id) ? 'av-celda--demerito' : 'av-celda--na']"
                >{{ demeritosMap.get(eq.id) ?? '—' }}</td>
              </tr>

              <!-- Fila Total día -->
              <tr class="av-fila av-fila--total">
                <td class="av-td av-td--sticky av-td--total">
                  <span class="av-criterio-nombre" style="font-weight:800">Total del día</span>
                </td>
                <td
                  v-for="eq in equipos"
                  :key="eq.id"
                  class="av-td av-td--celda av-celda--total"
                >{{ totalDiaMap.get(eq.id) ?? 0 }}</td>
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
.av-fila--lid td     { background: #fafafa; }
.av-fila--act td     { background: #f0f9ff; }
.av-fila--bonus td   { background: #f0fdf4; }
.av-fila--demerito td { background: #fff7ed; }
.av-celda--bonus    { background: #bbf7d0 !important; color: #166534 !important; font-weight: 700; }
.av-celda--demerito { background: #fed7aa !important; color: #9a3412 !important; font-weight: 700; }
.av-fila--total td  { background: #1e293b; }
.av-td--total       { background: #1e293b !important; }
.av-celda--total    { background: #1e293b !important; color: #f1f5f9 !important; font-weight: 800; font-size: 0.85rem; }

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
.av-criterio-num {
  font-size: 0.6rem;
  font-weight: 700;
  color: #9ca3af;
  min-width: 14px;
  text-align: right;
  flex-shrink: 0;
}
.av-criterio-badge {
  font-size: 0.62rem; font-weight: 800;
  background: #f3f4f6; color: #4b5563;
  border-radius: 4px; padding: 0.1rem 0.35rem;
  white-space: nowrap; flex-shrink: 0;
}
.av-criterio-badge--lid {
  background: #e0e7ff; color: #3730a3;
}
.av-act-pts {
  font-size: 0.62rem;
  font-weight: 700;
  color: #0369a1;
  background: #e0f2fe;
  border-radius: 4px;
  padding: 0.1rem 0.3rem;
  white-space: nowrap;
  flex-shrink: 0;
  margin-left: auto;
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
