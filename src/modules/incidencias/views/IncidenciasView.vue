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
const momentoActivo   = ref<string>('')
const momentosConProg = ref<string[]>([])

// ── Estado ────────────────────────────────────────────────────────────────────
const cargando  = ref(true)
const error     = ref('')
const lista     = ref<Incidencia[]>([])
const codigos   = ref<IncidenciaCodigo[]>([])
const equipos   = ref<Equipo[]>([])
const bonusList = ref<BonusEquipo[]>([])
const demeList  = ref<DemeritoEquipo[]>([])

const filtTab    = ref<'todas' | 'bonus' | 'demerito' | 'pendiente'>('todas')
const filtEquipo = ref('')
const modalOpen  = ref(false)

// ── Fecha de hoy (local, sin offset UTC) ──────────────────────────────────────
const hoy = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
})

// ── Fecha de inicio del campamento (primer día en dias_campamento) ─────────────
const fechaInicio = computed(() => {
  if (momentos.value.length === 0) return null
  return fechas.value[momentos.value[0]] ?? null
})

const labelFechaInicio = computed(() => {
  if (!fechaInicio.value) return ''
  return labelDia(momentos.value[0])
})

// ── Regla: puede registrar desde el 1er día EXCEPTO el último ─────────────────
// Los días del campamento vienen de dias_campamento (configurados en /panel/campamento)
// accesibles via useDiasCampamento → momentos (ordenados por 'orden')
const puedeRegistrar = computed(() => {
  if (momentos.value.length === 0) return false
  const primerFecha = fechas.value[momentos.value[0]]
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1]]
  if (!primerFecha || !ultimaFecha) return false
  return hoy.value >= primerFecha && hoy.value < ultimaFecha
})

const motivoNoRegistrar = computed(() => {
  if (momentos.value.length === 0) return ''
  const primerFecha = fechas.value[momentos.value[0]]
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1]]
  if (!primerFecha || !ultimaFecha) return ''
  if (hoy.value < primerFecha) return 'El campamento aún no ha comenzado.'
  if (hoy.value >= ultimaFecha) return 'No se pueden registrar incidencias el último día del campamento.'
  return ''
})

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
    momentoActivo.value = detectarMomentoActual()
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

const cntBonus     = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'bonus').length)
const cntDemerito  = computed(() => listaDia.value.filter(i => tipoDe(i.codigo) === 'demerito').length)
const cntPendiente = computed(() => listaDia.value.filter(i => i.estado === 'registrado').length)

const bonusPts    = computed(() => bonusList.value.reduce((s, b) => s + (b.bonus_codigo ?? 0), 0))
const demeritoPts = computed(() => demeList.value.reduce((s, d) => s + (d.demeritos_codigo ?? 0), 0))

const bonusCodigos    = computed(() => codigos.value.filter(c => c.tipo === 'bonus'))
const demeritoCodigos = computed(() => codigos.value.filter(c => c.tipo === 'demerito'))

// ── Helpers ───────────────────────────────────────────────────────────────────
const ESTADO_CFG: Record<string, { label: string; cls: string; icon: string }> = {
  registrado: { label: 'Pendiente', cls: 'badge--amber',  icon: 'pi-clock' },
  validado:   { label: 'Validado',  cls: 'badge--verde',  icon: 'pi-check-circle' },
  rechazado:  { label: 'Rechazado', cls: 'badge--rojo',   icon: 'pi-times-circle' },
}

function nombreEquipo(id: string) {
  return equipos.value.find(e => e.id === id)?.nombre ?? '—'
}

function colorEquipo(id: string) {
  return equipos.value.find(e => e.id === id)?.color ?? '#94a3b8'
}
</script>

<template>
  <div class="inc-page">

    <!-- ══════════════════════════════════════════
         HEADER
    ══════════════════════════════════════════ -->
    <header class="inc-header">
      <div class="inc-header__left">
        <div class="inc-header__icon-wrap">
          <i class="pi pi-bolt inc-header__icon" />
        </div>
        <div>
          <h1 class="inc-title">Incidencias</h1>
          <p class="inc-sub">Bonus y deméritos del campamento</p>
        </div>
      </div>
      <div class="inc-header__actions">
        <button class="btn-ayuda" title="¿Cómo funciona?" @click="modalOpen = true">
          <i class="pi pi-question-circle" />
        </button>
        <router-link
          v-if="puedeRegistrar"
          :to="`/panel/incidencias/nueva${momentoActivo && fechas[momentoActivo] ? '?fecha=' + fechas[momentoActivo] : ''}`"
          class="btn btn--primary"
        >
          <i class="pi pi-plus" /> Registrar
        </router-link>
        <span v-else-if="!cargando" class="btn btn--disabled" :title="motivoNoRegistrar">
          <i class="pi pi-lock" /> Registrar
        </span>
      </div>
    </header>

    <!-- ── Aviso cuando no se puede registrar ── -->
    <div v-if="!cargando && motivoNoRegistrar" class="inc-aviso-bloqueo">
      <i class="pi pi-info-circle inc-aviso-bloqueo__icon" />
      <div>
        <span>{{ motivoNoRegistrar }}</span>
        <span v-if="fechaInicio && hoy < fechaInicio" class="inc-aviso-bloqueo__fecha">
          Inicio del campamento: <strong>{{ labelFechaInicio }}</strong> ({{ fechaInicio }})
        </span>
      </div>
    </div>

    <!-- ══════════════════════════════════════════
         SELECTOR DE DÍAS
    ══════════════════════════════════════════ -->
    <div v-if="momentos.length" class="inc-dias-wrap">
      <div class="inc-dias">
        <button
          v-for="m in momentos.slice(0, -1)"
          :key="m"
          class="inc-dia-btn"
          :class="{ 'inc-dia-btn--active': momentoActivo === m }"
          @click="momentoActivo = m"
        >
          <span class="inc-dia-btn__label">{{ labelDia(m) }}</span>
          <span v-if="fechas[m] === hoy" class="inc-dia-btn__hoy">HOY</span>
        </button>
      </div>
    </div>

    <!-- Cargando / Error -->
    <div v-if="cargando" class="inc-empty">
      <div class="inc-spinner"><i class="pi pi-spin pi-spinner" /></div>
      <span>Cargando incidencias...</span>
    </div>
    <div v-else-if="error" class="inc-empty inc-empty--error">
      <i class="pi pi-exclamation-circle" style="font-size:1.5rem" />
      <span>{{ error }}</span>
    </div>

    <template v-else>

      <!-- ══════════════════════════════════════════
           STATS: Bonus / Deméritos
      ══════════════════════════════════════════ -->
      <div class="inc-stats">
        <div class="inc-stat inc-stat--bonus">
          <div class="inc-stat__icon-wrap inc-stat__icon-wrap--bonus">
            <i class="pi pi-star-fill" />
          </div>
          <div class="inc-stat__body">
            <span class="inc-stat__val">+{{ bonusPts }} pts</span>
            <span class="inc-stat__lbl">Bonus aplicados</span>
          </div>
          <span class="inc-stat__badge">{{ cntBonus }} hoy</span>
        </div>

        <div class="inc-stat inc-stat--demerito">
          <div class="inc-stat__icon-wrap inc-stat__icon-wrap--demerito">
            <i class="pi pi-exclamation-triangle" />
          </div>
          <div class="inc-stat__body">
            <span class="inc-stat__val">{{ demeList.length }} total</span>
            <span class="inc-stat__lbl">Deméritos registrados</span>
          </div>
          <span class="inc-stat__badge inc-stat__badge--demerito">{{ cntDemerito }} hoy</span>
        </div>
      </div>

      <!-- ══════════════════════════════════════════
           FILTROS
      ══════════════════════════════════════════ -->
      <div class="inc-filtros">
        <div class="inc-tabs">
          <button
            v-for="tab in [
              { v: 'todas',     label: 'Todas',      cnt: listaDia.length },
              { v: 'bonus',     label: 'Bonus',      cnt: cntBonus        },
              { v: 'demerito',  label: 'Deméritos',  cnt: cntDemerito     },
              { v: 'pendiente', label: 'Pendientes', cnt: cntPendiente    },
            ]"
            :key="tab.v"
            :class="[
              'inc-tab',
              filtTab === tab.v && 'inc-tab--active',
              tab.v === 'bonus'     && filtTab === tab.v && 'inc-tab--bonus',
              tab.v === 'demerito'  && filtTab === tab.v && 'inc-tab--demerito',
              tab.v === 'pendiente' && filtTab === tab.v && 'inc-tab--amber',
            ]"
            @click="filtTab = tab.v as any"
          >
            {{ tab.label }}
            <span v-if="tab.cnt > 0" class="inc-tab-cnt">{{ tab.cnt }}</span>
          </button>
        </div>

        <select v-if="equipos.length > 1" v-model="filtEquipo" class="inc-equipo-sel">
          <option value="">Todos los equipos</option>
          <option v-for="e in equipos" :key="e.id" :value="e.id">{{ e.nombre }}</option>
        </select>
      </div>

      <!-- ══════════════════════════════════════════
           LISTA
      ══════════════════════════════════════════ -->
      <div v-if="listaFiltrada.length" class="inc-lista">
        <div
          v-for="inc in listaFiltrada"
          :key="inc.id"
          :class="['inc-card', tipoDe(inc.codigo) === 'bonus' ? 'inc-card--bonus' : 'inc-card--demerito']"
          @click="router.push(`/panel/incidencias/${inc.id}`)"
        >
          <!-- Fila superior: código + equipo + estado -->
          <div class="inc-card__top">
            <span :class="['inc-card__codigo', tipoDe(inc.codigo) === 'bonus' ? 'inc-card__codigo--bonus' : 'inc-card__codigo--demerito']">
              {{ inc.codigo }}
            </span>

            <div class="inc-card__equipo-wrap">
              <span
                class="inc-card__equipo-dot"
                :style="{ background: colorEquipo(inc.equipo_id) }"
              />
              <span class="inc-card__equipo">{{ nombreEquipo(inc.equipo_id) }}</span>
            </div>

            <span :class="['badge', ESTADO_CFG[inc.estado]?.cls ?? 'badge--amber']">
              <i :class="['pi', ESTADO_CFG[inc.estado]?.icon ?? 'pi-clock']" style="font-size:0.6rem" />
              {{ ESTADO_CFG[inc.estado]?.label ?? inc.estado }}
            </span>
          </div>

          <!-- Hecho -->
          <p class="inc-card__hecho">{{ inc.hecho }}</p>

          <!-- Pie: fecha + puntos -->
          <div class="inc-card__foot">
            <span class="inc-card__meta">
              <i class="pi pi-calendar" style="font-size:0.65rem" />
              {{ inc.fecha }} · {{ inc.hora.slice(0, 5) }}
            </span>
            <span :class="['inc-card__pts', tipoDe(inc.codigo) === 'bonus' ? 'pts--bonus' : 'pts--demerito']">
              {{ tipoDe(inc.codigo) === 'bonus' ? '+' : '−' }}{{ inc.puntos }} pts
            </span>
          </div>
        </div>
      </div>

      <!-- ── Vacío ── -->
      <div v-else class="inc-empty">
        <div class="inc-empty__icon">
          <i class="pi pi-inbox" />
        </div>
        <p class="inc-empty__title">Sin incidencias</p>
        <p class="inc-empty__sub">
          {{ filtTab === 'pendiente' ? 'No hay incidencias pendientes de validación.' :
             filtTab !== 'todas'     ? `No hay incidencias de tipo "${filtTab}" para este día.` :
             'Aún no hay incidencias registradas para este día.' }}
        </p>
      </div>

    </template>

  </div>

  <!-- ═══════════════════════════════════════════════════════════
       MODAL ¿Cómo funciona?
  ═══════════════════════════════════════════════════════════ -->
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

            <!-- Regla de registro -->
            <div class="m-regla">
              <i class="pi pi-calendar-clock" />
              <span>Se pueden registrar desde el <strong>primer día</strong> del campamento hasta el <strong>penúltimo día</strong> inclusive.</span>
            </div>

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
/* ════════════════════════════════════════
   PAGE
════════════════════════════════════════ */
.inc-page {
  max-width: 700px;
  margin: 0 auto;
  padding: 0 1rem 3rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* ════════════════════════════════════════
   HEADER
════════════════════════════════════════ */
.inc-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding-top: 0.5rem;
}
.inc-header__left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.inc-header__icon-wrap {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: linear-gradient(135deg, #dcfce7, #bbf7d0);
  border: 1.5px solid #86efac;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.inc-header__icon { font-size: 1.2rem; color: #16a34a; }
.inc-title { font-size: 1.25rem; font-weight: 800; margin: 0; color: #0f172a; }
.inc-sub   { font-size: 0.75rem; color: #94a3b8; margin: 0.1rem 0 0; }

.inc-header__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.btn-ayuda {
  width: 38px; height: 38px;
  border-radius: 10px;
  border: 1.5px solid #e2e8f0;
  background: white;
  color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  font-size: 1rem;
  transition: color .15s, border-color .15s, background .15s;
}
.btn-ayuda:hover { color: #16a34a; border-color: #bbf7d0; background: #f0fdf4; }

/* ── Aviso bloqueo ── */
.inc-aviso-bloqueo {
  display: flex;
  align-items: flex-start;
  gap: 0.6rem;
  background: #fffbeb;
  border: 1.5px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 12px;
  padding: 0.75rem 1rem;
  font-size: 0.82rem;
  color: #92400e;
  line-height: 1.45;
}
.inc-aviso-bloqueo__icon { color: #d97706; font-size: 1rem; flex-shrink: 0; margin-top: 0.05rem; }
.inc-aviso-bloqueo > div { display: flex; flex-direction: column; gap: 0.2rem; }
.inc-aviso-bloqueo__fecha { font-size: 0.78rem; color: #b45309; }

/* ════════════════════════════════════════
   SELECTOR DE DÍAS
════════════════════════════════════════ */
.inc-dias-wrap {
  display: flex;
  justify-content: center;
}
.inc-dias {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  justify-content: center;
}
.inc-dia-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.2rem;
  padding: 0.55rem 1.1rem;
  border-radius: 12px;
  border: 1.5px solid #e2e8f0;
  background: white;
  font-size: 0.82rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  min-height: 44px;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  transition: all .15s;
}
.inc-dia-btn:hover { border-color: #86efac; color: #15803d; background: #f0fdf4; }
.inc-dia-btn--active {
  background: linear-gradient(135deg, #16a34a, #15803d);
  color: white;
  border-color: #16a34a;
  box-shadow: 0 4px 12px rgba(22,163,74,0.3);
}
.inc-dia-btn__label { line-height: 1; }
.inc-dia-btn__hoy {
  font-size: 0.55rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  background: rgba(255,255,255,0.25);
  color: white;
  border-radius: 4px;
  padding: 0 0.3rem;
  line-height: 1.6;
}
.inc-dia-btn:not(.inc-dia-btn--active) .inc-dia-btn__hoy {
  background: #dcfce7;
  color: #16a34a;
}

/* ════════════════════════════════════════
   STATS
════════════════════════════════════════ */
.inc-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}
.inc-stat {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  background: white;
  border: 1.5px solid #e5e7eb;
  border-radius: 14px;
  padding: 0.85rem 0.9rem;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
  transition: box-shadow .15s;
}
.inc-stat:hover { box-shadow: 0 4px 12px rgba(0,0,0,.08); }

.inc-stat__icon-wrap {
  width: 38px; height: 38px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  font-size: 1rem;
}
.inc-stat__icon-wrap--bonus   { background: #dcfce7; color: #16a34a; border: 1.5px solid #bbf7d0; }
.inc-stat__icon-wrap--demerito { background: #fee2e2; color: #dc2626; border: 1.5px solid #fecaca; }

.inc-stat__body { flex: 1; min-width: 0; }
.inc-stat__val {
  display: block;
  font-size: 1.05rem;
  font-weight: 800;
  line-height: 1.1;
}
.inc-stat--bonus   .inc-stat__val { color: #16a34a; }
.inc-stat--demerito .inc-stat__val { color: #dc2626; }
.inc-stat__lbl { font-size: 0.68rem; color: #94a3b8; display: block; margin-top: 0.1rem; }

.inc-stat__badge {
  font-size: 0.65rem;
  font-weight: 700;
  background: #dcfce7;
  color: #15803d;
  border-radius: 999px;
  padding: 0.15rem 0.5rem;
  flex-shrink: 0;
  align-self: flex-start;
}
.inc-stat__badge--demerito { background: #fee2e2; color: #dc2626; }

/* ════════════════════════════════════════
   FILTROS
════════════════════════════════════════ */
.inc-filtros {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.inc-tabs {
  display: flex;
  background: #f1f5f9;
  border-radius: 10px;
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
  min-height: 36px;
  border: none;
  border-radius: 8px;
  background: transparent;
  font-size: 0.78rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  white-space: nowrap;
  transition: all .15s;
  padding: 0 0.4rem;
}
.inc-tab:hover { color: #374151; }
.inc-tab--active             { background: white; color: #111827; box-shadow: 0 1px 4px rgba(0,0,0,.1); }
.inc-tab--bonus.inc-tab--active    { color: #15803d; }
.inc-tab--demerito.inc-tab--active { color: #b91c1c; }
.inc-tab--amber.inc-tab--active    { color: #92400e; }
.inc-tab-cnt {
  font-size: 0.65rem;
  background: #e2e8f0;
  color: #374151;
  border-radius: 999px;
  padding: 0 0.35rem;
  min-width: 16px;
  text-align: center;
  line-height: 1.6;
}
.inc-tab--active .inc-tab-cnt { background: #f1f5f9; }

.inc-equipo-sel {
  min-height: 44px;
  padding: 0.4rem 0.65rem;
  border: 1.5px solid #e2e8f0;
  border-radius: 10px;
  font-size: 0.84rem;
  background: white;
  color: #374151;
  cursor: pointer;
  flex-shrink: 0;
}
.inc-equipo-sel:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.12); }

/* ════════════════════════════════════════
   CARDS
════════════════════════════════════════ */
.inc-lista { display: flex; flex-direction: column; gap: 0.6rem; }

.inc-card {
  background: white;
  border: 1.5px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 14px;
  padding: 0.9rem 1rem;
  cursor: pointer;
  transition: box-shadow .15s, transform .1s;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
}
.inc-card:hover { box-shadow: 0 6px 18px rgba(0,0,0,.1); transform: translateY(-1px); }
.inc-card--bonus    { border-left-color: #16a34a; }
.inc-card--demerito { border-left-color: #ef4444; }

.inc-card__top {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}

.inc-card__codigo {
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  border-radius: 6px;
  padding: 0.2rem 0.5rem;
  flex-shrink: 0;
}
.inc-card__codigo--bonus   { background: #dcfce7; color: #15803d; }
.inc-card__codigo--demerito { background: #fee2e2; color: #b91c1c; }

.inc-card__equipo-wrap {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex: 1;
  min-width: 0;
}
.inc-card__equipo-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
  border: 1px solid rgba(0,0,0,0.1);
}
.inc-card__equipo {
  font-weight: 700;
  font-size: 0.86rem;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.inc-card__hecho {
  font-size: 0.84rem;
  color: #475569;
  margin: 0 0 0.5rem;
  line-height: 1.45;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.inc-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.inc-card__meta {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.74rem;
  color: #94a3b8;
}
.inc-card__pts {
  font-weight: 800;
  font-size: 0.9rem;
  letter-spacing: -0.01em;
}
.pts--bonus    { color: #16a34a; }
.pts--demerito { color: #ef4444; }

/* ════════════════════════════════════════
   BADGES
════════════════════════════════════════ */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  border-radius: 6px;
  font-size: 0.67rem;
  font-weight: 700;
  padding: 0.18rem 0.45rem;
  text-transform: uppercase;
  white-space: nowrap;
  flex-shrink: 0;
  letter-spacing: 0.03em;
}
.badge--azul   { background: #dcfce7; color: #166534; }
.badge--naranja { background: #fed7aa; color: #c2410c; }
.badge--verde  { background: #d1fae5; color: #065f46; }
.badge--rojo   { background: #fee2e2; color: #991b1b; }
.badge--amber  { background: #fef3c7; color: #92400e; }

/* ════════════════════════════════════════
   BOTONES
════════════════════════════════════════ */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 40px;
  padding: 0.5rem 1rem;
  border-radius: 10px;
  border: none;
  font-size: 0.84rem;
  font-weight: 700;
  cursor: pointer;
  text-decoration: none;
  transition: background .15s, box-shadow .15s;
  white-space: nowrap;
}
.btn--primary {
  background: linear-gradient(135deg, #16a34a, #15803d);
  color: white;
  box-shadow: 0 2px 8px rgba(22,163,74,0.3);
}
.btn--primary:hover {
  background: linear-gradient(135deg, #15803d, #166534);
  box-shadow: 0 4px 12px rgba(22,163,74,0.4);
}
.btn--disabled {
  background: #f1f5f9;
  color: #94a3b8;
  cursor: not-allowed;
  border: 1.5px solid #e2e8f0;
  box-shadow: none;
}
.btn--full { width: 100%; justify-content: center; }

/* ════════════════════════════════════════
   SPINNER / EMPTY
════════════════════════════════════════ */
.inc-spinner {
  width: 48px; height: 48px;
  border-radius: 50%;
  background: #f0fdf4;
  display: flex; align-items: center; justify-content: center;
  color: #16a34a; font-size: 1.3rem;
}
.inc-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  text-align: center;
  color: #94a3b8;
  font-size: 0.88rem;
}
.inc-empty--error { color: #dc2626; }
.inc-empty__icon {
  width: 56px; height: 56px;
  border-radius: 50%;
  background: #f8fafc;
  border: 1.5px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem;
  color: #cbd5e1;
  margin-bottom: 0.25rem;
}
.inc-empty__title { font-size: 0.95rem; font-weight: 700; color: #64748b; margin: 0; }
.inc-empty__sub   { font-size: 0.82rem; color: #94a3b8; margin: 0; line-height: 1.5; max-width: 260px; }

/* ════════════════════════════════════════
   MODAL
════════════════════════════════════════ */
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
  background: rgba(0,0,0,.45);
  backdrop-filter: blur(4px);
}
.m-panel {
  position: relative;
  width: 100%; max-width: 448px;
  background: white;
  border-radius: 24px 24px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 90dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 20px; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.1rem 1.25rem 0.9rem;
  border-bottom: 1px solid #f1f5f9;
  flex-shrink: 0;
}
.m-head__left { display: flex; align-items: center; gap: 0.6rem; }
.m-icon {
  width: 34px; height: 34px; border-radius: 10px;
  background: #dcfce7; color: #16a34a;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.9rem;
}
.m-title { font-size: 1rem; font-weight: 800; margin: 0; color: #0f172a; }
.m-close {
  width: 32px; height: 32px; border-radius: 8px;
  border: none; background: transparent; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.82rem; transition: background .15s;
}
.m-close:hover { background: #f1f5f9; color: #374151; }

.m-body {
  overflow-y: auto; padding: 1.1rem 1.25rem;
  flex: 1; display: flex; flex-direction: column; gap: 1rem;
}
.m-intro { font-size: 0.88rem; color: #475569; margin: 0; line-height: 1.6; }

.m-regla {
  display: flex;
  align-items: flex-start;
  gap: 0.55rem;
  background: #f0fdf4;
  border: 1.5px solid #bbf7d0;
  border-radius: 10px;
  padding: 0.7rem 0.85rem;
  font-size: 0.82rem;
  color: #166534;
  line-height: 1.5;
}
.m-regla i { flex-shrink: 0; margin-top: 0.1rem; color: #16a34a; }

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
  padding: 0.55rem 0.75rem;
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 10px;
}
.m-codigo__info { display: flex; flex-direction: column; gap: 0.05rem; font-size: 0.82rem; }
.m-codigo__info strong { color: #1e293b; }
.m-codigo__info span   { font-size: 0.76rem; color: #64748b; }

.m-estados {
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 12px; padding: 0.9rem;
}
.m-estados__tit {
  font-size: 0.7rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .06em; margin: 0 0 0.6rem;
}
.m-est-fila {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.3rem 0; font-size: 0.8rem; color: #64748b;
}
.m-est-fila + .m-est-fila { border-top: 1px solid #f1f5f9; }

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.75rem 0.9rem;
  background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px;
  font-size: 0.78rem; color: #78350f; line-height: 1.5;
}
.m-nota i { flex-shrink: 0; margin-top: 0.1rem; color: #d97706; }

.m-foot {
  padding: 0.9rem 1.25rem;
  border-top: 1px solid #f1f5f9;
  flex-shrink: 0;
}
</style>
