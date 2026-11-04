<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { equiposService } from '@/modules/equipos/services/equipos.service'
import { observacionesService, programacionRubricaService, diasService, type DiasEvaluacion } from '@/modules/observaciones/services/observaciones.service'
import { campamentoAdminService } from '@/modules/auditoria/services/auditoria.service'
import { actividadesService, evalRegistrosService } from '@/modules/asistencia/services/asistencia.service'
import { incidenciasService } from '@/modules/incidencias/services/incidencias.service'

const campStore = useCampamentoStore()

// ── Tab activo: 'total' | momento del día ─────────────────────────────────────
const tabActivo = ref<'total' | string>('total')


// ── Datos por día ─────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarDias, labelDia, detectarMomentoActual } = useDiasCampamento()
const momentosConProg = ref<Set<string>>(new Set())
const diasEvaluacion  = ref<DiasEvaluacion[]>([])

interface FilaDia {
  equipo_id: string
  equipo_nombre: string
  equipo_color: string
  posicion: number
  pts_rubrica: number
  pts_actividades: number
  pts_bonus: number
  pts_demeritos: number
  pts_total: number
}
const listaDia       = ref<FilaDia[]>([])
const listaTotal     = ref<FilaDia[]>([])
const campCerrado    = ref(false)

const cargando = ref(true)
const error    = ref('')

// ── Lista activa según tab ────────────────────────────────────────────────────
const listaActiva = computed(() => listaDia.value)

const esDia = computed(() => tabActivo.value !== 'total')

const diaCerrado = computed(() => {
  if (!esDia.value) return false
  return diasEvaluacion.value.find((d) => d.momento === tabActivo.value)?.cerrado ?? false
})

// ── Tabs disponibles ──────────────────────────────────────────────────────────
const tabs = computed(() => [
  { key: 'total', label: 'Total' },
  ...momentos.value
    .filter((m) => momentosConProg.value.has(m))
    .map((m) => ({ key: m, label: labelDia(m) })),
])

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const campId = campStore.selectedId
    await cargarDias()
    const [momentosR, diasData, campEstado] = await Promise.all([
      programacionRubricaService.getMomentosConProgramacion(campId),
      campId ? diasService.getTodos(campId) : Promise.resolve([] as DiasEvaluacion[]),
      campId ? campamentoAdminService.getEstado(campId) : Promise.resolve({ cerrado: false } as any),
    ])
    momentosConProg.value = new Set(momentosR)
    diasEvaluacion.value  = diasData
    campCerrado.value     = campEstado.cerrado ?? false

    // Si campamento cerrado: acumular totales por día; si abierto: limpiar
    if (campCerrado.value) {
      await cargarTotal()
    } else {
      listaTotal.value = []
    }

    // Auto-seleccionar día actual si existe
    const hoy = detectarMomentoActual()
    if (hoy && momentosConProg.value.has(hoy)) tabActivo.value = hoy
    else tabActivo.value = 'total'

    if (esDia.value) await cargarDatosDia(tabActivo.value)
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

async function cargarDatosDia(momento: string) {
  // Solo procesar si el día está cerrado
  const cerrado = diasEvaluacion.value.find((d) => d.momento === momento)?.cerrado ?? false
  if (!cerrado) { listaDia.value = []; return }

  cargando.value = true
  try {
    const campId = campStore.selectedId
    const equipos = await equiposService.getTodos(campId ?? undefined)
    const activos = equipos.filter((e) => e.activo)

    const [puntajesDia, actData, incData] = await Promise.all([
      observacionesService.getPuntajeEquipoDia(momento, campId),
      actividadesService.getPorDia(momento),
      incidenciasService.getValidadasPorMomento(momento, campId),
    ])

    // Puntajes de actividades por equipo
    const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
    const actPts: Record<string, number> = {}
    await Promise.all(
      actFiltradas.map(async (a) => {
        const regs = await evalRegistrosService.getPorActividad(a.id)
        // Promediar entre evaluadores por (criterio, equipo), luego sumar criterios
        const byKey = new Map<string, number[]>()
        for (const r of regs) {
          const key = `${r.criterio_eval_id}|${r.equipo_id}`
          if (!byKey.has(key)) byKey.set(key, [])
          byKey.get(key)!.push(Number(r.puntaje))
        }
        for (const [key, puntajes] of byKey) {
          const equipoId = key.split('|')[1]
          const avg = puntajes.reduce((a, b) => a + b, 0) / puntajes.length
          actPts[equipoId] = (actPts[equipoId] ?? 0) + avg
        }
      }),
    )

    // Bonus y deméritos del día (solo para mostrar, no afectan el ranking)
    const bonusPts: Record<string, number>     = {}
    const demeritosPts: Record<string, number> = {}
    for (const inc of incData) {
      if (inc.tipo === 'bonus')    bonusPts[inc.equipo_id]     = (bonusPts[inc.equipo_id]     ?? 0) + inc.puntos
      if (inc.tipo === 'demerito') demeritosPts[inc.equipo_id] = (demeritosPts[inc.equipo_id] ?? 0) + inc.puntos
    }

    // Construir filas — si campamento cerrado: rúbrica + actividades + bonus − deméritos
    //                   si campamento abierto: solo rúbrica
    const filas: FilaDia[] = activos.map((eq) => {
      const rub   = Number(puntajesDia.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
      const act   = actPts[eq.id] ?? 0
      const bon   = bonusPts[eq.id] ?? 0
      const dem   = demeritosPts[eq.id] ?? 0
      const total = campCerrado.value
        ? Math.max(0, rub + act + bon - dem)
        : rub
      return { equipo_id: eq.id, equipo_nombre: eq.nombre, equipo_color: eq.color ?? '#6b7280',
        posicion: 0, pts_rubrica: rub, pts_actividades: act,
        pts_bonus: bon, pts_demeritos: dem, pts_total: total }
    })

    // Ordenar y asignar posición
    filas.sort((a, b) => b.pts_total - a.pts_total)
    filas.forEach((f, i) => { f.posicion = i + 1 })
    listaDia.value = filas
  } finally {
    cargando.value = false
  }
}

async function cargarTotal() {
  const campId = campStore.selectedId
  const equipos = await equiposService.getTodos(campId ?? undefined)
  const activos = equipos.filter((e) => e.activo)

  // Acumular puntos por equipo a través de todos los días cerrados con programación
  const diasCerrados = diasEvaluacion.value.filter(
    (d) => d.cerrado && momentosConProg.value.has(d.momento ?? ''),
  )

  const acum: Record<string, { rub: number; act: number; bon: number; dem: number }> = {}
  for (const eq of activos) acum[eq.id] = { rub: 0, act: 0, bon: 0, dem: 0 }

  await Promise.all(
    diasCerrados.map(async (dia) => {
      const momento = dia.momento ?? ''
      const [puntajesDia, actData, incData] = await Promise.all([
        observacionesService.getPuntajeEquipoDia(momento, campId),
        actividadesService.getPorDia(momento),
        incidenciasService.getValidadasPorMomento(momento, campId),
      ])

      const actFiltradas = actData.filter((a) => a.estado !== 'cancelada')
      const actPts: Record<string, number> = {}
      await Promise.all(
        actFiltradas.map(async (a) => {
          const regs = await evalRegistrosService.getPorActividad(a.id)
          for (const r of regs) {
            actPts[r.equipo_id] = (actPts[r.equipo_id] ?? 0) + (r.puntaje ?? 0)
          }
        }),
      )

      for (const eq of activos) {
        if (!acum[eq.id]) continue
        acum[eq.id].rub += Number(puntajesDia.find((p) => p.equipo_id === eq.id)?.suma_puntaje ?? 0)
        acum[eq.id].act += actPts[eq.id] ?? 0
        for (const inc of incData.filter((i) => i.equipo_id === eq.id)) {
          if (inc.tipo === 'bonus')    acum[eq.id].bon += inc.puntos
          if (inc.tipo === 'demerito') acum[eq.id].dem += inc.puntos
        }
      }
    }),
  )

  const filas: FilaDia[] = activos.map((eq) => {
    const { rub, act, bon, dem } = acum[eq.id] ?? { rub: 0, act: 0, bon: 0, dem: 0 }
    return {
      equipo_id: eq.id,
      equipo_nombre: eq.nombre,
      equipo_color: eq.color ?? '#6b7280',
      posicion: 0,
      pts_rubrica: rub,
      pts_actividades: act,
      pts_bonus: bon,
      pts_demeritos: dem,
      pts_total: Math.max(0, rub + act + bon - dem),
    }
  })
  filas.sort((a, b) => b.pts_total - a.pts_total)
  filas.forEach((f, i) => { f.posicion = i + 1 })
  listaTotal.value = filas
}

async function seleccionarTab(key: string) {
  tabActivo.value = key
  if (key !== 'total') await cargarDatosDia(key)
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

function posClase(pos: number) {
  if (pos === 1) return 'rk-pos--oro'
  if (pos === 2) return 'rk-pos--plata'
  if (pos === 3) return 'rk-pos--bronce'
  return 'rk-pos--part'
}
</script>

<template>
  <div class="rk-page">

    <!-- Header -->
    <header class="rk-header">
      <div class="rk-header__left">
        <i class="pi pi-trophy rk-header__icon" />
        <div>
          <h1 class="rk-header__title">Ranking interno</h1>
          <p class="rk-header__sub">{{ esDia ? labelDia(tabActivo) : 'Acumulado total · todos los días' }}</p>
        </div>
      </div>
      <button class="rk-refresh" title="Actualizar" @click="esDia ? cargarDatosDia(tabActivo) : cargar()">
        <i :class="cargando ? 'pi pi-spin pi-spinner' : 'pi pi-refresh'" />
      </button>
    </header>

    <!-- Tabs -->
    <div class="rk-tabs">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        :class="['rk-tab', tabActivo === tab.key && 'rk-tab--active']"
        @click="seleccionarTab(tab.key)"
      >{{ tab.label }}</button>
    </div>

    <!-- Cargando -->
    <div v-if="cargando" class="rk-empty">
      <i class="pi pi-spin pi-spinner rk-empty__icon" />
      <span>Cargando…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="rk-error">
      <i class="pi pi-exclamation-triangle" /> {{ error }}
    </div>

    <!-- Tab Total: mensaje si campamento abierto -->
    <div v-else-if="!esDia && !campCerrado" class="rk-empty">
      <i class="pi pi-lock rk-empty__icon" />
      <span class="rk-empty__msg">Esta información se procesará una vez cerrado el campamento.</span>
    </div>

    <!-- Tab Total: ranking acumulado cuando campamento cerrado -->
    <div v-else-if="!esDia && campCerrado" class="rk-lista">
      <div
        v-for="eq in listaTotal"
        :key="eq.equipo_id"
        class="rk-card"
        :class="eq.posicion === 1 ? 'rk-card--oro' : eq.posicion === 2 ? 'rk-card--plata' : eq.posicion === 3 ? 'rk-card--bronce' : 'rk-card--part'"
      >
        <div class="rk-card__top">
          <span class="rk-pos" :class="posClase(eq.posicion)">{{ eq.posicion }}°</span>
          <div class="rk-equipo">
            <span class="rk-equipo__dot" :style="{ background: eq.equipo_color }" />
            <span class="rk-equipo__nombre">{{ eq.equipo_nombre }}</span>
          </div>
          <div class="rk-escala">
            <span class="rk-escala__num rk-escala__num--dia">{{ eq.pts_total }}</span>
            <span class="rk-escala__max">pts</span>
          </div>
        </div>
        <div class="rk-barra">
          <div class="rk-barra__fill" :style="{ width: listaTotal[0]?.pts_total ? eq.pts_total / listaTotal[0].pts_total * 100 + '%' : '0%', background: '#16a34a' }" />
        </div>
        <div class="rk-desglose">
          <div class="rk-grupo">
            <p class="rk-grupo__titulo">Componentes</p>
            <div class="rk-grupo__items">
              <div class="rk-item"><span class="rk-item__label">Rúbrica</span><span class="rk-item__val">{{ eq.pts_rubrica }}</span></div>
              <div class="rk-item"><span class="rk-item__label">Actividades</span><span class="rk-item__val">{{ eq.pts_actividades }}</span></div>
              <div class="rk-item rk-item--subtotal"><span class="rk-item__label">Subtotal</span><span class="rk-item__val">{{ eq.pts_rubrica + eq.pts_actividades }}</span></div>
            </div>
          </div>
          <div class="rk-grupo">
            <p class="rk-grupo__titulo">Ajustes</p>
            <div class="rk-grupo__items">
              <div v-if="eq.pts_bonus" class="rk-item rk-item--bonus"><span class="rk-item__label">+ Bonus</span><span class="rk-item__val">{{ eq.pts_bonus }}</span></div>
              <div v-if="eq.pts_demeritos" class="rk-item rk-item--demerito"><span class="rk-item__label">− Deméritos</span><span class="rk-item__val">{{ eq.pts_demeritos }}</span></div>
              <div class="rk-item rk-item--bruto"><span class="rk-item__label">Total</span><span class="rk-item__val">{{ eq.pts_total }}</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Día no cerrado todavía -->
    <div v-else-if="esDia && !diaCerrado" class="rk-empty">
      <i class="pi pi-lock-open rk-empty__icon" />
      <span class="rk-empty__msg">Esta información será mostrada una vez cerrado el día.</span>
    </div>

    <!-- Sin datos para el día -->
    <div v-else-if="!listaActiva.length" class="rk-empty">
      <i class="pi pi-calendar-times rk-empty__icon" />
      <span>Sin datos para este día.</span>
    </div>

    <!-- ── POR DÍA: tarjetas simplificadas ── -->
    <div v-else class="rk-lista">
      <div
        v-for="eq in listaDia"
        :key="eq.equipo_id"
        class="rk-card rk-card--dia"
        :class="eq.posicion <= 3 ? (eq.posicion === 1 ? 'rk-card--oro' : eq.posicion === 2 ? 'rk-card--plata' : 'rk-card--bronce') : 'rk-card--part'"
      >
        <div class="rk-card__top">
          <span class="rk-pos" :class="posClase(eq.posicion)">{{ eq.posicion }}°</span>
          <div class="rk-equipo">
            <span class="rk-equipo__dot" :style="{ background: eq.equipo_color }" />
            <span class="rk-equipo__nombre">{{ eq.equipo_nombre }}</span>
          </div>
          <div class="rk-escala">
            <span class="rk-escala__num rk-escala__num--dia">{{ eq.pts_total }}</span>
            <span class="rk-escala__max">pts</span>
          </div>
        </div>
        <div class="rk-desglose">
          <div class="rk-grupo">
            <p class="rk-grupo__titulo">Del día</p>
            <div class="rk-grupo__items">
              <div class="rk-item"><span class="rk-item__label">Rúbrica</span><span class="rk-item__val">{{ eq.pts_rubrica }}</span></div>
              <div class="rk-item"><span class="rk-item__label">Actividades</span><span class="rk-item__val">{{ eq.pts_actividades }}</span></div>
            </div>
          </div>
          <div v-if="eq.pts_bonus || eq.pts_demeritos" class="rk-grupo">
            <p class="rk-grupo__titulo">Ajustes del día</p>
            <div class="rk-grupo__items">
              <div v-if="eq.pts_bonus" class="rk-item rk-item--bonus"><span class="rk-item__label">+ Bonus</span><span class="rk-item__val">{{ eq.pts_bonus }}</span></div>
              <div v-if="eq.pts_demeritos" class="rk-item rk-item--demerito"><span class="rk-item__label">− Deméritos</span><span class="rk-item__val">{{ eq.pts_demeritos }}</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.rk-page {
  max-width: 680px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* Header */
.rk-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.25rem;
}
.rk-header__left {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}
.rk-header__icon {
  font-size: 1.3rem;
  color: #15803d;
}
.rk-header__title {
  font-size: 1.15rem;
  font-weight: 800;
  color: #111827;
  margin: 0;
  line-height: 1.2;
}
.rk-header__sub {
  font-size: 0.75rem;
  color: #9ca3af;
  margin: 0;
}
.rk-refresh {
  width: 38px; height: 38px;
  border-radius: 50%;
  border: 1.5px solid #d1fae5;
  background: #f0fdf4;
  color: #16a34a;
  font-size: 0.95rem;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: background .15s;
}
.rk-refresh:hover { background: #dcfce7; }

/* Empty / Error */
.rk-empty {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.5rem; padding: 3rem 1rem;
  color: #9ca3af; font-size: 0.88rem;
}
.rk-empty__icon { font-size: 2rem; }
.rk-empty__msg {
  max-width: 260px;
  text-align: center;
  line-height: 1.5;
  color: #6b7280;
}
.rk-error {
  background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 10px; padding: 0.9rem 1rem;
  color: #b91c1c; font-size: 0.85rem;
  display: flex; align-items: center; gap: 0.5rem;
}

/* Tabs */
.rk-tabs {
  display: flex;
  gap: 0.4rem;
  overflow-x: auto;
  scrollbar-width: none;
  margin-bottom: 1rem;
  padding-bottom: 2px;
}
.rk-tabs::-webkit-scrollbar { display: none; }
.rk-tab {
  flex-shrink: 0;
  padding: 0.4rem 1rem;
  border-radius: 20px;
  border: 2px solid #e5e7eb;
  background: white;
  font-size: 0.82rem;
  font-weight: 600;
  color: #6b7280;
  cursor: pointer;
  min-height: 36px;
  transition: all .15s;
}
.rk-tab:hover { border-color: #bbf7d0; color: #15803d; }
.rk-tab--active { background: #16a34a; border-color: #16a34a; color: white; }

/* Lista */
.rk-lista { display: flex; flex-direction: column; gap: 0.75rem; }

/* Card */
.rk-card {
  border: 2px solid #e5e7eb;
  border-radius: 16px;
  padding: 1rem;
  background: white;
  cursor: pointer;
  transition: transform .12s, box-shadow .12s;
}
.rk-card:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(0,0,0,.08); }
.rk-card--oro    { border-color: #fde68a; background: #fffbeb; }
.rk-card--plata  { border-color: #cbd5e1; background: #f8fafc; }
.rk-card--bronce { border-color: #fcd34d; background: #fffbeb; }
.rk-card--part   { border-color: #e5e7eb; background: white; }

/* Top row */
.rk-card__top {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-bottom: 0.6rem;
}

/* Posición */
.rk-pos {
  font-size: 1.5rem;
  font-weight: 900;
  width: 2.4rem;
  text-align: center;
  flex-shrink: 0;
  line-height: 1;
}
.rk-pos--oro    { color: #d97706; }
.rk-pos--plata  { color: #64748b; }
.rk-pos--bronce { color: #b45309; }
.rk-pos--part   { color: #9ca3af; }

/* Equipo */
.rk-equipo {
  display: flex; align-items: center; gap: 0.5rem;
  flex: 1; min-width: 0;
}
.rk-equipo__dot {
  width: 14px; height: 14px;
  border-radius: 50%;
  flex-shrink: 0;
  border: 2px solid white;
  box-shadow: 0 0 0 1px rgba(0,0,0,.1);
}
.rk-equipo__nombre {
  font-weight: 700;
  font-size: 0.95rem;
  color: #111827;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Badge medalla */
.rk-badge {
  font-size: 0.72rem;
  font-weight: 700;
  padding: 0.25rem 0.6rem;
  border-radius: 20px;
  flex-shrink: 0;
  display: none;
}
@media (min-width: 400px) { .rk-badge { display: inline-flex; align-items: center; gap: 0.25rem; } }
.rk-badge--oro    { background: #fef3c7; color: #92400e; }
.rk-badge--plata  { background: #f1f5f9; color: #475569; }
.rk-badge--bronce { background: #fef3c7; color: #78350f; }
.rk-badge--part   { background: #f3f4f6; color: #6b7280; }

/* Escala */
.rk-escala {
  display: flex; align-items: baseline; gap: 0.15rem;
  flex-shrink: 0;
}
.rk-escala__num {
  font-size: 1.5rem;
  font-weight: 900;
  color: #15803d;
  line-height: 1;
}
.rk-escala__max {
  font-size: 0.72rem;
  color: #9ca3af;
  font-weight: 600;
}

/* Barra */
.rk-barra {
  height: 6px;
  background: #f3f4f6;
  border-radius: 3px;
  overflow: hidden;
  margin-bottom: 0.85rem;
}
.rk-barra__fill {
  height: 100%;
  border-radius: 3px;
  transition: width .4s ease;
}

/* Desglose */
.rk-desglose {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}
@media (max-width: 420px) {
  .rk-desglose { grid-template-columns: 1fr; }
}

.rk-grupo__titulo {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #9ca3af;
  margin: 0 0 0.4rem;
}
.rk-grupo__items {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.rk-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.22rem 0.5rem;
  border-radius: 6px;
  background: rgba(0,0,0,.03);
}
.rk-item__label {
  font-size: 0.75rem;
  color: #6b7280;
}
.rk-item__val {
  font-size: 0.8rem;
  font-weight: 700;
  color: #374151;
}
.rk-item--subtotal {
  background: #f0fdf4;
  margin-top: 0.1rem;
}
.rk-item--subtotal .rk-item__label,
.rk-item--subtotal .rk-item__val { color: #15803d; font-weight: 800; }

.rk-item--bonus   { background: #f0fdf4; }
.rk-item--bonus   .rk-item__label { color: #16a34a; font-weight: 600; }
.rk-item--bonus   .rk-item__val   { color: #15803d; }

.rk-item--demerito { background: #fff7ed; }
.rk-item--demerito .rk-item__label { color: #ea580c; font-weight: 600; }
.rk-item--demerito .rk-item__val   { color: #c2410c; }

.rk-item--bruto {
  background: #1e293b;
  margin-top: 0.1rem;
}
.rk-item--bruto .rk-item__label { color: #94a3b8; font-weight: 700; }
.rk-item--bruto .rk-item__val   { color: #f1f5f9; font-size: 0.85rem; }

.rk-escala__num--dia { font-size: 1.3rem; }
.rk-card--dia .rk-barra { display: none; }
</style>
