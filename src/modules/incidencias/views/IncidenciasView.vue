<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import {
  incidenciasService,
  codigosService,
  bonusService,
  demeritorService,
  type Incidencia,
  type IncidenciaCodigo,
  type BonusEquipo,
  type DemeritoEquipo,
} from '@/modules/incidencias/services/incidencias.service'
import { equiposService, type Equipo } from '@/modules/equipos/services/equipos.service'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const router    = useRouter()

const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()
const momentoActivo = ref<string>('')
const momentosConProg = ref<string[]>([])

// ── Estado ────────────────────────────────────────────────────────────────────
const cargando  = ref(true)
const error     = ref('')
const lista     = ref<Incidencia[]>([])
const codigos   = ref<IncidenciaCodigo[]>([])
const equipos   = ref<Equipo[]>([])
const bonusList = ref<BonusEquipo[]>([])
const demeList  = ref<DemeritoEquipo[]>([])

// Filtros — solo los que realmente se usan en campo
const filtTab    = ref<'todas' | 'bonus' | 'demerito' | 'pendiente'>('todas')
const filtEquipo = ref('')

// Modal ayuda
const modalOpen = ref(false)

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const [, inc, cod, eq, bon, dem] = await Promise.all([
      cargarCampamento(),
      incidenciasService.getAll({ campamento_id: campStore.selectedId ?? undefined }),
      codigosService.getAll(),
      equiposService.getTodos(campStore.selectedId ?? undefined),
      bonusService.getResumen(campStore.selectedId),
      demeritorService.getResumen(campStore.selectedId),
    ])
    const { supabase } = await import('@/lib/supabase')
    if (campStore.selectedId) {
      const { data: progData } = await supabase
        .from('programacion')
        .select('momento')
        .eq('campamento_id', campStore.selectedId)
        .eq('estado', 'programado')
      momentosConProg.value = [...new Set((progData ?? []).map((r: any) => r.momento as string))]
    }
    const hoy = detectarMomentoActual()
    momentoActivo.value = momentosConProg.value.includes(hoy)
      ? hoy
      : (momentosConProg.value[0] ?? hoy)
    lista.value     = inc
    codigos.value   = cod
    equipos.value   = eq
    bonusList.value = bon
    demeList.value  = dem
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar incidencias'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

// ── Computed ──────────────────────────────────────────────────────────────────
const codigoPorCodigo = computed(() => {
  const m = new Map<string, IncidenciaCodigo>()
  codigos.value.forEach((c) => m.set(c.codigo, c))
  return m
})

function tipoDe(codigo: string) {
  return codigoPorCodigo.value.get(codigo)?.tipo ?? 'demerito'
}

// Incidencias del día seleccionado
const listaDia = computed(() => {
  const fecha = fechas.value[momentoActivo.value]
  if (!fecha) return lista.value
  return lista.value.filter((inc) => inc.fecha === fecha)
})

const listaFiltrada = computed(() => {
  return listaDia.value.filter((inc) => {
    if (filtTab.value === 'bonus'     && tipoDe(inc.codigo) !== 'bonus')     return false
    if (filtTab.value === 'demerito'  && tipoDe(inc.codigo) !== 'demerito')  return false
    if (filtTab.value === 'pendiente' && inc.estado !== 'registrado')        return false
    if (filtEquipo.value && inc.equipo_id !== filtEquipo.value)              return false
    return true
  })
})

// Conteos para las tabs (del día activo)
const cntBonus     = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'bonus').length)
const cntDemerito  = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'demerito').length)
const cntPendiente = computed(() => listaDia.value.filter(i => i.estado === 'registrado').length)

// Impacto real en puntaje (solo validados)
const bonusPts    = computed(() => bonusList.value.reduce((s, b) => s + (b.bonus_codigo ?? 0), 0))
const demeritoPts = computed(() => demeList.value.reduce((s, d) => s + (d.demeritos_codigo ?? 0), 0))

// Códigos para el modal
const bonusCodigos    = computed(() => codigos.value.filter(c => c.tipo === 'bonus'))
const demeritoCodigos = computed(() => codigos.value.filter(c => c.tipo === 'demerito'))

// ── Helpers ───────────────────────────────────────────────────────────────────
const ESTADO_CFG: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Pendiente', cls: 'badge--amber' },
  validado:   { label: 'Validado',  cls: 'badge--verde' },
  rechazado:  { label: 'Rechazado', cls: 'badge--rojo'  },
}

function nombreEquipo(id: string) {
  return equipos.value.find(e => e.id === id)?.nombre ?? '—'
}
</script>

<template>
  <div class="inc-page">

    <!-- ── Header ── -->
    <header class="inc-header">
      <div>
        <h1 class="inc-title">Incidencias</h1>
        <p class="inc-sub">Bonus y deméritos del campamento</p>
      </div>
      <div class="inc-header-actions">
        <button class="btn-ayuda" title="¿Cómo funciona?" @click="modalOpen = true">
          <i class="pi pi-question-circle" />
        </button>
        <router-link
          :to="`/panel/incidencias/nueva${momentoActivo && fechas[momentoActivo] ? '?fecha=' + fechas[momentoActivo] : ''}`"
          class="btn btn--primary"
        >
          <i class="pi pi-plus" /> Registrar
        </router-link>
      </div>
    </header>

    <!-- ── Selector de días ── -->
    <div v-if="momentos.length" class="inc-dias">
      <button
        v-for="m in momentos.filter(m => momentosConProg.includes(m))"
        :key="m"
        class="inc-dia-btn"
        :class="{ 'inc-dia-btn--active': momentoActivo === m }"
        @click="momentoActivo = m"
      >
        {{ labelDia(m) }}
      </button>
    </div>

    <!-- ── Impacto en puntaje ── -->
    <div v-if="!cargando" class="inc-impacto">
      <div class="inc-impacto__item inc-impacto__item--bonus">
        <i class="pi pi-star-fill" />
        <div>
          <span class="inc-impacto__val">+50 pts</span>
          <span class="inc-impacto__lbl">máximo por equipo</span>
        </div>
      </div>
      <div class="inc-impacto__sep" />
      <div class="inc-impacto__item inc-impacto__item--demerito">
        <i class="pi pi-exclamation-triangle" />
        <div>
          <span class="inc-impacto__val">−{{ demeritoPts }} pts</span>
          <span class="inc-impacto__lbl">según gravedad de la falta</span>
        </div>
      </div>
    </div>

    <!-- ── Filtros: tabs + equipo ── -->
    <div class="inc-filtros">
      <!-- Tabs de tipo -->
      <div class="inc-tabs">
        <button
          v-for="tab in [
            { v: 'todas',    label: 'Todas',      cnt: lista.length  },
            { v: 'bonus',    label: 'Bonus',       cnt: cntBonus      },
            { v: 'demerito', label: 'Deméritos',   cnt: cntDemerito   },
            { v: 'pendiente',label: 'Pendientes',  cnt: cntPendiente  },
          ]"
          :key="tab.v"
          :class="['inc-tab', filtTab === tab.v && 'inc-tab--active',
                   tab.v === 'bonus'     && filtTab === tab.v && 'inc-tab--bonus',
                   tab.v === 'demerito'  && filtTab === tab.v && 'inc-tab--demerito',
                   tab.v === 'pendiente' && filtTab === tab.v && 'inc-tab--amber']"
          @click="filtTab = tab.v as any"
        >
          {{ tab.label }}
          <span v-if="tab.cnt > 0" class="inc-tab-cnt">{{ tab.cnt }}</span>
        </button>
      </div>

      <!-- Filtro por equipo -->
      <select v-if="equipos.length > 1" v-model="filtEquipo" class="inc-equipo-sel">
        <option value="">Todos los equipos</option>
        <option v-for="e in equipos" :key="e.id" :value="e.id">{{ e.nombre }}</option>
      </select>
    </div>

    <!-- ── Cargando / Error ── -->
    <div v-if="cargando" class="inc-empty">
      <i class="pi pi-spin pi-spinner" style="font-size:1.5rem" />
    </div>
    <div v-else-if="error" class="inc-empty inc-empty--error">
      <i class="pi pi-exclamation-circle" /> {{ error }}
    </div>

    <!-- ── Lista ── -->
    <div v-else-if="listaFiltrada.length" class="inc-lista">
      <div
        v-for="inc in listaFiltrada"
        :key="inc.id"
        :class="['inc-card', tipoDe(inc.codigo) === 'bonus' ? 'inc-card--bonus' : 'inc-card--demerito']"
        @click="router.push(`/panel/incidencias/${inc.id}`)"
      >
        <div class="inc-card__row">
          <span :class="['badge', tipoDe(inc.codigo) === 'bonus' ? 'badge--azul' : 'badge--naranja']">
            {{ inc.codigo }}
          </span>
          <span class="inc-card__equipo">{{ nombreEquipo(inc.equipo_id) }}</span>
          <span :class="['badge', ESTADO_CFG[inc.estado]?.cls ?? 'badge--amber']">
            {{ ESTADO_CFG[inc.estado]?.label ?? inc.estado }}
          </span>
        </div>
        <p class="inc-card__hecho">{{ inc.hecho }}</p>
        <div class="inc-card__footer">
          <span class="inc-card__meta">{{ inc.fecha }} · {{ inc.hora.slice(0, 5) }}</span>
          <span :class="['inc-card__pts', tipoDe(inc.codigo) === 'bonus' ? 'pts--bonus' : 'pts--demerito']">
            {{ tipoDe(inc.codigo) === 'bonus' ? '+' : '−' }}{{ inc.puntos }} pts
          </span>
        </div>
      </div>
    </div>

    <!-- ── Vacío ── -->
    <div v-else class="inc-empty">
      <i class="pi pi-inbox" style="font-size:2rem; opacity:.3" />
      <span>
        {{ filtTab === 'pendiente' ? 'No hay incidencias pendientes.' :
           filtTab !== 'todas'     ? `No hay incidencias de tipo ${filtTab}.` :
           'Aún no hay incidencias registradas.' }}
      </span>
    </div>

  </div>

  <!-- ═══ Modal ¿Cómo funciona? — patrón Revisiones ═══ -->
  <Teleport to="body">
    <Transition
      enter-active-class="m-enter-active"
      leave-active-class="m-leave-active"
      enter-from-class="m-from"
      leave-to-class="m-from"
    >
      <div v-if="modalOpen" class="m-overlay">
        <div class="m-backdrop" @click="modalOpen = false" />

        <div class="m-panel">
          <div class="m-head">
            <div class="m-head__left">
              <div class="m-icon"><i class="pi pi-question-circle" /></div>
              <h2 class="m-title">¿Cómo funciona?</h2>
            </div>
            <button class="m-close" @click="modalOpen = false"><i class="pi pi-times" /></button>
          </div>

          <div class="m-body">
            <p class="m-intro">
              Las incidencias son eventos que <strong>suman</strong> (bonus) o
              <strong>restan</strong> (deméritos) puntos al equipo.
              Solo cuentan una vez que el admin las <strong>valida</strong>.
            </p>

            <!-- Flujo -->
            <div class="m-pasos">
              <div class="m-paso">
                <div class="m-paso__n">1</div>
                <div>
                  <p class="m-paso__t">Evaluador registra</p>
                  <p class="m-paso__d">Documenta el hecho, código, equipo y sube evidencia.</p>
                </div>
              </div>
              <div class="m-paso">
                <div class="m-paso__n">2</div>
                <div>
                  <p class="m-paso__t">Admin valida en bandeja</p>
                  <p class="m-paso__d">Aprueba o rechaza con un motivo. Solo las aprobadas aplican.</p>
                </div>
              </div>
              <div class="m-paso">
                <div class="m-paso__n m-paso__n--ok">3</div>
                <div>
                  <p class="m-paso__t">Impacta el puntaje final</p>
                  <p class="m-paso__d">Solo incidencias <strong>validadas</strong> afectan el score del equipo.</p>
                </div>
              </div>
            </div>

            <!-- Bonus -->
            <p class="m-sec m-sec--bonus"><i class="pi pi-star-fill" /> Bonus</p>
            <div class="m-codigos">
              <div v-for="c in bonusCodigos" :key="c.codigo" class="m-codigo">
                <span class="badge badge--azul">{{ c.codigo }}</span>
                <div class="m-codigo__info">
                  <strong>{{ c.nombre }}</strong>
                  <span>{{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                    <template v-if="c.tope_equipo"> · tope {{ c.tope_equipo }} pts</template>
                    <template v-if="c.max_acciones"> · máx. {{ c.max_acciones }} acciones</template>
                  </span>
                </div>
              </div>
            </div>

            <!-- Deméritos -->
            <p class="m-sec m-sec--demerito"><i class="pi pi-exclamation-triangle" /> Deméritos</p>
            <div class="m-codigos">
              <div v-for="c in demeritoCodigos" :key="c.codigo" class="m-codigo">
                <span class="badge badge--naranja">{{ c.codigo }}</span>
                <div class="m-codigo__info">
                  <strong>{{ c.nombre }}</strong>
                  <span>{{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                    <template v-if="c.requiere_advertencia"> · requiere advertencia previa</template>
                  </span>
                </div>
              </div>
            </div>

            <!-- Estados -->
            <div class="m-estados">
              <p class="m-estados__tit">Estados</p>
              <div class="m-est-fila">
                <span class="badge badge--amber">Pendiente</span>
                <span>Esperando que el admin revise</span>
              </div>
              <div class="m-est-fila">
                <span class="badge badge--verde">Validado</span>
                <span>Confirmado — ya aplica al puntaje</span>
              </div>
              <div class="m-est-fila">
                <span class="badge badge--rojo">Rechazado</span>
                <span>No procede — no afecta el puntaje</span>
              </div>
            </div>

            <div class="m-nota">
              <i class="pi pi-info-circle" />
              <span>Un solo demérito por episodio. No se descuenta dos veces. El puntaje mínimo del equipo es 0.</span>
            </div>
          </div>

          <div class="m-foot">
            <button class="btn btn--primary btn--full" @click="modalOpen = false">Entendido</button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* ─── Page ─── */
.inc-page {
  max-width: 700px;
  margin: 0 auto;
  padding: 0 1rem 2rem;
}

/* ─── Selector de días ─── */
.inc-dias {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 0.75rem;
}
.inc-dia-btn {
  padding: 0.45rem 1rem;
  border-radius: 999px;
  border: 1px solid #e2e8f0;
  background: white;
  font-size: 0.84rem;
  font-weight: 600;
  color: #6b7280;
  cursor: pointer;
  min-height: 44px;
  transition: all .15s;
}
.inc-dia-btn:hover { border-color: #bbf7d0; color: #15803d; }
.inc-dia-btn--active { background: #16a34a; color: white; border-color: #16a34a; }

/* ─── Header ─── */
.inc-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.inc-title { font-size: 1.3rem; font-weight: 800; margin: 0; }
.inc-sub   { font-size: 0.8rem; color: #6b7280; margin: 0.1rem 0 0; }

.inc-header-actions {
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
  cursor: pointer;
  font-size: 1rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
  flex-shrink: 0;
}
.btn-ayuda:hover { color: #16a34a; border-color: #bbf7d0; }

/* ─── Alerta admin pendientes ─── */
.inc-alerta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 10px;
  padding: 0.85rem 1rem;
  margin-bottom: 0.75rem;
  cursor: pointer;
  transition: background .15s;
}
.inc-alerta:hover { background: #fef9c3; }
.inc-alerta__left {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
}
.inc-alerta__left > i { color: #d97706; font-size: 1.1rem; margin-top: 0.1rem; flex-shrink: 0; }
.inc-alerta__left strong { display: block; font-size: 0.9rem; color: #92400e; }
.inc-alerta__left span   { font-size: 0.78rem; color: #b45309; }
.inc-alerta > .pi-angle-right { color: #d97706; font-size: 1rem; flex-shrink: 0; }

.inc-bandeja-link {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 0.75rem;
}

/* ─── Impacto en puntaje ─── */
.inc-impacto {
  display: flex;
  align-items: center;
  gap: 0;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  margin-bottom: 1rem;
  overflow: hidden;
}
.inc-impacto__item {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.75rem 1rem;
}
.inc-impacto__item i { font-size: 1.1rem; flex-shrink: 0; }
.inc-impacto__item--bonus   i { color: #16a34a; }
.inc-impacto__item--demerito i { color: #dc2626; }
.inc-impacto__val {
  display: block;
  font-size: 1.05rem;
  font-weight: 800;
  line-height: 1;
}
.inc-impacto__item--bonus   .inc-impacto__val { color: #16a34a; }
.inc-impacto__item--demerito .inc-impacto__val { color: #dc2626; }
.inc-impacto__lbl { font-size: 0.72rem; color: #6b7280; display: block; margin-top: 0.1rem; }
.inc-impacto__max { font-size: 0.72rem; font-weight: 500; color: #9ca3af; }
.inc-impacto__sep {
  width: 1px;
  height: 40px;
  background: #e5e7eb;
  flex-shrink: 0;
}

/* ─── Filtros ─── */
.inc-filtros {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  flex-wrap: wrap;
}

.inc-tabs {
  display: flex;
  background: #f3f4f6;
  border-radius: 9px;
  padding: 3px;
  gap: 2px;
  flex: 1;
  min-width: 0;
}
.inc-tab {
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
.inc-tab--active             { background: white; color: #111827; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.inc-tab--bonus.inc-tab--active    { color: #15803d; }
.inc-tab--demerito.inc-tab--active { color: #b91c1c; }
.inc-tab--amber.inc-tab--active    { color: #92400e; }
.inc-tab-cnt {
  font-size: 0.68rem;
  background: #e5e7eb;
  color: #374151;
  border-radius: 8px;
  padding: 0 0.3rem;
  min-width: 16px;
  text-align: center;
  line-height: 1.5;
}
.inc-tab--active .inc-tab-cnt { background: #e5e7eb; }

.inc-equipo-sel {
  min-height: 44px;
  padding: 0.4rem 0.6rem;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  font-size: 0.88rem;
  background: white;
  color: #374151;
  cursor: pointer;
  flex-shrink: 0;
}
.inc-equipo-sel:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }

/* ─── Cards ─── */
.inc-lista { display: flex; flex-direction: column; gap: 0.55rem; }

.inc-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 10px;
  padding: 0.85rem 1rem;
  cursor: pointer;
  transition: box-shadow .15s, transform .1s;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.inc-card:hover { box-shadow: 0 3px 10px rgba(0,0,0,.1); transform: translateY(-1px); }
.inc-card--bonus    { border-left-color: #16a34a; }
.inc-card--demerito { border-left-color: #dc2626; }

.inc-card__row {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-bottom: 0.3rem;
  flex-wrap: wrap;
}
.inc-card__equipo { font-weight: 700; font-size: 0.88rem; flex: 1; min-width: 0; }

.inc-card__hecho {
  font-size: 0.86rem;
  color: #374151;
  margin: 0 0 0.35rem;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.inc-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.inc-card__meta { font-size: 0.76rem; color: #9ca3af; }
.inc-card__pts  { font-weight: 800; font-size: 0.88rem; }
.pts--bonus    { color: #16a34a; }
.pts--demerito { color: #dc2626; }

/* ─── Badges ─── */
.badge {
  border-radius: 4px;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 0.15rem 0.4rem;
  text-transform: uppercase;
  white-space: nowrap;
  flex-shrink: 0;
}
.badge--azul   { background: #dcfce7; color: #166534; }
.badge--naranja { background: #fed7aa; color: #c2410c; }
.badge--verde  { background: #d1fae5; color: #065f46; }
.badge--rojo   { background: #fee2e2; color: #991b1b; }
.badge--amber  { background: #fef3c7; color: #92400e; }

/* ─── Botones ─── */
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
  text-decoration: none;
  transition: background .15s;
  white-space: nowrap;
}
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover { background: #15803d; }
.btn--ghost { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn--ghost:hover { background: #f9fafb; }
.btn--sm { min-height: 40px; padding: 0.45rem 0.85rem; font-size: 0.84rem; }
.btn--full { width: 100%; justify-content: center; }

/* ─── Empty ─── */
.inc-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  text-align: center;
  color: #9ca3af;
  font-size: 0.88rem;
}
.inc-empty--error { color: #dc2626; }

/* ═══ Modal ═══ */
.m-enter-active, .m-leave-active { transition: opacity .2s ease; }
.m-from { opacity: 0; }

.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) {
  .m-overlay { align-items: center; padding: 1rem; }
}

.m-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.4);
  backdrop-filter: blur(4px);
}
.m-panel {
  position: relative;
  width: 100%; max-width: 448px;
  background: white;
  border-radius: 20px 20px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 90dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.1rem 1.25rem 0.9rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.m-head__left { display: flex; align-items: center; gap: 0.6rem; }
.m-icon {
  width: 32px; height: 32px; border-radius: 50%;
  background: #dcfce7; color: #16a34a;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.88rem;
}
.m-title { font-size: 1rem; font-weight: 800; margin: 0; color: #1e293b; }
.m-close {
  width: 32px; height: 32px; border-radius: 8px;
  border: none; background: transparent; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.82rem; transition: background .15s;
}
.m-close:hover { background: #f1f5f9; }

.m-body {
  overflow-y: auto; padding: 1.1rem 1.25rem;
  flex: 1; display: flex; flex-direction: column; gap: 1rem;
}
.m-intro { font-size: 0.88rem; color: #475569; margin: 0; line-height: 1.55; }

.m-pasos { display: flex; flex-direction: column; gap: 0.75rem; }
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

.m-sec {
  font-size: 0.82rem; font-weight: 700; margin: 0;
  display: flex; align-items: center; gap: 0.35rem;
}
.m-sec--bonus    { color: #15803d; }
.m-sec--demerito { color: #b91c1c; }

.m-codigos { display: flex; flex-direction: column; gap: 0.4rem; margin-top: -0.5rem; }
.m-codigo {
  display: flex; align-items: flex-start; gap: 0.55rem;
  padding: 0.55rem 0.7rem;
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 8px;
}
.m-codigo__info {
  display: flex; flex-direction: column; gap: 0.05rem; font-size: 0.82rem;
}
.m-codigo__info strong { color: #1e293b; }
.m-codigo__info span   { font-size: 0.76rem; color: #64748b; }

.m-estados {
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 10px; padding: 0.85rem;
}
.m-estados__tit {
  font-size: 0.72rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .05em; margin: 0 0 0.6rem;
}
.m-est-fila {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.25rem 0; font-size: 0.8rem; color: #64748b;
}
.m-est-fila + .m-est-fila { border-top: 1px solid #f1f5f9; }

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.7rem 0.85rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;
  font-size: 0.78rem; color: #78350f; line-height: 1.45;
}
.m-nota i { flex-shrink: 0; margin-top: 0.1rem; color: #d97706; }

.m-foot {
  padding: 0.9rem 1.25rem;
  border-top: 1px solid #f1f5f9;
  flex-shrink: 0;
}
</style>
