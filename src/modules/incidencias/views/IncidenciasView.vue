<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import { cachedFetch, TTL_1H } from '@/lib/localCache'
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
  return fechas.value[momentos.value[0] ?? ''] ?? null
})

const labelFechaInicio = computed(() => {
  if (!fechaInicio.value) return ''
  return labelDia(momentos.value[0] ?? '')
})

// ── Regla: puede registrar desde el 1er día EXCEPTO el último ─────────────────
const puedeRegistrar = computed(() => {
  if (momentos.value.length === 0) return false
  const primerFecha = fechas.value[momentos.value[0] ?? '']
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1] ?? '']
  if (!primerFecha || !ultimaFecha) return false
  return hoy.value >= primerFecha && hoy.value < ultimaFecha
})

const motivoNoRegistrar = computed(() => {
  if (momentos.value.length === 0) return ''
  const primerFecha = fechas.value[momentos.value[0] ?? '']
  const ultimaFecha = fechas.value[momentos.value[momentos.value.length - 1] ?? '']
  if (!primerFecha || !ultimaFecha) return ''
  if (hoy.value < primerFecha) return 'El campamento aún no ha comenzado.'
  if (hoy.value >= ultimaFecha) return 'No se pueden registrar incidencias el último día del campamento.'
  return ''
})

// ── Carga inicial ─────────────────────────────────────────────────────────────
async function cargar() {
  if (codigos.value.length > 0 && equipos.value.length > 0 && !navigator.onLine) return

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
    if (campStore.selectedId) {
      const campId = campStore.selectedId
      const momentos = await cachedFetch<string[]>(`prog_momentos_${campId}`, async () => {
        const { supabase } = await import('@/lib/supabase')
        const { data: progData } = await supabase
          .from('programacion')
          .select('momento')
          .eq('campamento_id', campId)
          .eq('estado', 'programado')
        return [...new Set((progData ?? []).map((r: any) => r.momento as string))]
      }, TTL_1H)
      momentosConProg.value = momentos
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
const ESTADO_CFG: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Pendiente', cls: 'st--amber' },
  validado:   { label: 'Validado',  cls: 'st--green' },
  rechazado:  { label: 'Rechazado', cls: 'st--red'   },
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

    <!-- ══════════ TOPBAR ══════════ -->
    <div class="inc-topbar">
      <div class="inc-topbar__left"></div>
      <div class="inc-topbar__right">
        <button class="inc-btn-help" title="¿Cómo funciona?" @click="modalOpen = true">
          <i class="pi pi-question-circle" />
        </button>
        <router-link
          v-if="puedeRegistrar"
          :to="`/panel/incidencias/nueva${momentoActivo && fechas[momentoActivo] ? '?fecha=' + fechas[momentoActivo] : ''}`"
          class="inc-btn-new"
        >
          <i class="pi pi-plus" /> Registrar
        </router-link>
        <span v-else-if="!cargando" class="inc-btn-new inc-btn-new--off" :title="motivoNoRegistrar">
          <i class="pi pi-lock" /> Registrar
        </span>
      </div>
    </div>

    <!-- ══════════ AVISO BLOQUEO ══════════ -->
    <div v-if="!cargando && motivoNoRegistrar" class="inc-aviso">
      <i class="pi pi-info-circle" />
      <div>
        <span>{{ motivoNoRegistrar }}</span>
        <span v-if="fechaInicio && hoy < fechaInicio" class="inc-aviso__fecha">
          Inicio: <strong>{{ labelFechaInicio }}</strong> ({{ fechaInicio }})
        </span>
      </div>
    </div>

    <!-- ══════════ SELECTOR DE DÍAS ══════════ -->
    <div v-if="momentos.length" class="inc-dias-wrap">
      <div class="inc-dias">
        <button
          v-for="m in momentos.slice(0, -1)"
          :key="m"
          class="inc-dia"
          :class="{ 'inc-dia--on': momentoActivo === m }"
          @click="momentoActivo = m"
        >
          <span class="inc-dia__nombre">{{ labelDia(m) }}</span>
          <span v-if="fechas[m] === hoy" class="inc-dia__hoy">HOY</span>
        </button>
      </div>
    </div>

    <!-- ══════════ CARGANDO / ERROR ══════════ -->
    <div v-if="cargando" class="inc-estado">
      <div class="inc-estado__ring"><i class="pi pi-spin pi-spinner" /></div>
      <span>Cargando incidencias...</span>
    </div>
    <div v-else-if="error" class="inc-estado inc-estado--error">
      <i class="pi pi-exclamation-circle" style="font-size:1.4rem" />
      <span>{{ error }}</span>
    </div>

    <template v-else>

      <!-- ══════════ STATS ══════════ -->
      <div class="inc-stats">
        <div class="inc-stat inc-stat--bonus">
          <div class="inc-stat__ic-wrap">
            <i class="pi pi-star-fill" />
          </div>
          <div class="inc-stat__body">
            <span class="inc-stat__num">{{ cntBonus }}</span>
            <span class="inc-stat__lbl">Bonus hoy</span>
          </div>
          <span class="inc-stat__pts inc-stat__pts--bonus">+{{ bonusPts }} pts</span>
        </div>

        <div class="inc-stat inc-stat--deme">
          <div class="inc-stat__ic-wrap">
            <i class="pi pi-exclamation-triangle" />
          </div>
          <div class="inc-stat__body">
            <span class="inc-stat__num">{{ cntDemerito }}</span>
            <span class="inc-stat__lbl">Deméritos hoy</span>
          </div>
          <span class="inc-stat__pts inc-stat__pts--deme">−{{ demeritoPts }} pts</span>
        </div>
      </div>

      <!-- ══════════ FILTROS ══════════ -->
      <div class="inc-filtros">
        <div class="inc-tabs-scroll">
          <div class="inc-tabs">
            <button
              v-for="tab in [
                { v: 'todas',     label: 'Todas',      cnt: listaDia.length },
                { v: 'bonus',     label: 'Bonus',      cnt: cntBonus        },
                { v: 'demerito',  label: 'Deméritos',  cnt: cntDemerito     },
                { v: 'pendiente', label: 'Pendientes', cnt: cntPendiente    },
              ]"
              :key="tab.v"
              :class="['inc-tab', filtTab === tab.v && 'inc-tab--on', filtTab === tab.v && `inc-tab--${tab.v}`]"
              @click="filtTab = tab.v as any"
            >
              {{ tab.label }}
              <span v-if="tab.cnt > 0" class="inc-tab__cnt">{{ tab.cnt }}</span>
            </button>
          </div>
        </div>

        <select v-if="equipos.length > 1" v-model="filtEquipo" class="inc-equipo-sel">
          <option value="">Todos los equipos</option>
          <option v-for="e in equipos" :key="e.id" :value="e.id">{{ e.nombre }}</option>
        </select>
      </div>

      <!-- ══════════ LISTA ══════════ -->
      <div v-if="listaFiltrada.length" class="inc-lista">
        <div
          v-for="inc in listaFiltrada"
          :key="inc.id"
          :class="['inc-card', tipoDe(inc.codigo) === 'bonus' ? 'inc-card--bonus' : 'inc-card--deme']"
          @click="router.push(`/panel/incidencias/${inc.id}`)"
        >
          <!-- Fila superior -->
          <div class="inc-card__head">
            <span :class="['inc-cod', tipoDe(inc.codigo) === 'bonus' ? 'inc-cod--b' : 'inc-cod--d']">
              {{ inc.codigo }}
            </span>
            <div class="inc-card__equipo">
              <span class="inc-card__dot" :style="{ background: colorEquipo(inc.equipo_id) }" />
              <span class="inc-card__eq">{{ nombreEquipo(inc.equipo_id) }}</span>
            </div>
            <span :class="['inc-st', ESTADO_CFG[inc.estado]?.cls ?? 'st--amber']">
              {{ ESTADO_CFG[inc.estado]?.label ?? inc.estado }}
            </span>
          </div>

          <!-- Hecho -->
          <p class="inc-card__hecho">{{ inc.hecho }}</p>

          <!-- Pie -->
          <div class="inc-card__foot">
            <span class="inc-card__meta">
              <i class="pi pi-calendar" />
              {{ inc.fecha }} · {{ inc.hora.slice(0, 5) }}
            </span>
            <span :class="['inc-card__pts', tipoDe(inc.codigo) === 'bonus' ? 'pts--b' : 'pts--d']">
              {{ tipoDe(inc.codigo) === 'bonus' ? '+' : '−' }}{{ inc.puntos }} pts
            </span>
          </div>
        </div>
      </div>

      <!-- Vacío -->
      <div v-else class="inc-vacio">
        <div class="inc-vacio__ic"><i class="pi pi-inbox" /></div>
        <p class="inc-vacio__title">Sin incidencias</p>
        <p class="inc-vacio__sub">
          {{
            filtTab === 'pendiente' ? 'No hay incidencias pendientes de validación.' :
            filtTab !== 'todas'     ? `No hay incidencias de tipo "${filtTab}" para este día.` :
            'Aún no hay incidencias registradas para este día.'
          }}
        </p>
      </div>

    </template>
  </div>

  <!-- ═══════════════════════════════════════════════
       MODAL ¿Cómo funciona?
  ═══════════════════════════════════════════════ -->
  <Teleport to="body">
    <Transition enter-active-class="m-in" leave-active-class="m-in" enter-from-class="m-from" leave-to-class="m-from">
      <div v-if="modalOpen" class="m-overlay">
        <div class="m-backdrop" @click="modalOpen = false" />
        <div class="m-panel">

          <div class="m-head">
            <div class="m-head__left">
              <div class="m-ic"><i class="pi pi-question-circle" /></div>
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

            <div class="m-regla">
              <i class="pi pi-calendar-clock" />
              <span>Se pueden registrar desde el <strong>primer día</strong> hasta el <strong>penúltimo día</strong> inclusive.</span>
            </div>

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

            <p class="m-sec m-sec--bonus"><i class="pi pi-star-fill" /> Bonus</p>
            <div class="m-codigos">
              <div v-for="c in bonusCodigos" :key="c.codigo" class="m-codigo">
                <span class="m-cod m-cod--b">{{ c.codigo }}</span>
                <div class="m-codigo__info">
                  <strong>{{ c.nombre }}</strong>
                  <span>{{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                    <template v-if="c.tope_equipo"> · tope {{ c.tope_equipo }} pts</template>
                    <template v-if="c.max_acciones"> · máx. {{ c.max_acciones }} acciones</template>
                  </span>
                </div>
              </div>
            </div>

            <p class="m-sec m-sec--deme"><i class="pi pi-exclamation-triangle" /> Deméritos</p>
            <div class="m-codigos">
              <div v-for="c in demeritoCodigos" :key="c.codigo" class="m-codigo">
                <span class="m-cod m-cod--d">{{ c.codigo }}</span>
                <div class="m-codigo__info">
                  <strong>{{ c.nombre }}</strong>
                  <span>{{ c.puntos }} pts{{ c.por_persona ? '/persona' : '' }}
                    <template v-if="c.requiere_advertencia"> · requiere advertencia previa</template>
                  </span>
                </div>
              </div>
            </div>

            <div class="m-estados">
              <p class="m-estados__tit">Estados</p>
              <div class="m-est-row"><span class="inc-st st--amber">Pendiente</span><span>Esperando revisión del admin</span></div>
              <div class="m-est-row"><span class="inc-st st--green">Validado</span><span>Confirmado — aplica al puntaje</span></div>
              <div class="m-est-row"><span class="inc-st st--red">Rechazado</span><span>No procede — no afecta el puntaje</span></div>
            </div>

            <div class="m-nota">
              <i class="pi pi-info-circle" />
              <span>Un solo demérito por episodio. El puntaje mínimo del equipo es 0.</span>
            </div>
          </div>

          <div class="m-foot">
            <button class="inc-btn-new" style="width:100%;justify-content:center" @click="modalOpen = false">
              Entendido
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* ════════════════════════════════════════════
   PAGE
════════════════════════════════════════════ */
.inc-page {
  max-width: 640px;
  margin: 0 auto;
  padding: 0 1rem 4rem;
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}

/* ════════════════════════════════════════════
   TOPBAR
════════════════════════════════════════════ */
.inc-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  padding-top: 0.5rem;
}
.inc-topbar__left {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}
.inc-topbar__right {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

.inc-btn-help {
  width: 36px; height: 36px;
  border-radius: 10px;
  border: 1.5px solid #e2e8f0;
  background: white;
  color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.95rem;
  transition: color .15s, border-color .15s, background .15s;
  flex-shrink: 0;
}
.inc-btn-help:hover { color: #059669; border-color: #a7f3d0; background: #ecfdf5; }

.inc-btn-new {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  min-height: 36px;
  padding: 0 0.9rem;
  border-radius: 10px;
  border: none;
  font-size: 0.84rem;
  font-weight: 700;
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;
  background: linear-gradient(135deg, #059669, #047857);
  color: white;
  box-shadow: 0 2px 8px rgba(5,150,105,0.3);
  transition: box-shadow .15s, background .15s;
}
.inc-btn-new:hover { box-shadow: 0 4px 14px rgba(5,150,105,0.4); }
.inc-btn-new--off {
  background: #f1f5f9;
  color: #94a3b8;
  box-shadow: none;
  border: 1.5px solid #e2e8f0;
  cursor: not-allowed;
}

/* ════════════════════════════════════════════
   AVISO BLOQUEO
════════════════════════════════════════════ */
.inc-aviso {
  display: flex;
  align-items: flex-start;
  gap: 0.6rem;
  background: #fffbeb;
  border: 1.5px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 12px;
  padding: 0.7rem 0.9rem;
  font-size: 0.82rem;
  color: #92400e;
  line-height: 1.45;
}
.inc-aviso > .pi { color: #d97706; font-size: 1rem; flex-shrink: 0; margin-top: 0.05rem; }
.inc-aviso > div { display: flex; flex-direction: column; gap: 0.15rem; }
.inc-aviso__fecha { font-size: 0.76rem; color: #b45309; }

/* ════════════════════════════════════════════
   SELECTOR DE DÍAS
════════════════════════════════════════════ */
.inc-dias-wrap {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
  margin: 0 -1rem;
  padding: 0 1rem;
}
.inc-dias-wrap::-webkit-scrollbar { display: none; }
.inc-dias {
  display: flex;
  gap: 0.5rem;
  padding-bottom: 2px;
}
.inc-dia {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  flex-shrink: 0;
  min-width: 72px;
  padding: 0.6rem 0.75rem;
  border-radius: 14px;
  border: 1.5px solid #e2e8f0;
  background: white;
  cursor: pointer;
  transition: all .15s;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.inc-dia:hover { border-color: #6ee7b7; background: #ecfdf5; }
.inc-dia__nombre {
  font-size: 0.82rem;
  font-weight: 600;
  color: #64748b;
  line-height: 1;
}
.inc-dia__hoy {
  font-size: 0.55rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  background: #d1fae5;
  color: #059669;
  border-radius: 4px;
  padding: 0.1rem 0.3rem;
  line-height: 1.6;
}
.inc-dia--on {
  background: linear-gradient(135deg, #059669, #047857);
  border-color: #059669;
  box-shadow: 0 4px 12px rgba(5,150,105,0.3);
}
.inc-dia--on .inc-dia__nombre { color: white; font-weight: 700; }
.inc-dia--on .inc-dia__hoy {
  background: rgba(255,255,255,0.25);
  color: white;
}

/* ════════════════════════════════════════════
   CARGANDO / ERROR
════════════════════════════════════════════ */
.inc-estado {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
  padding: 3rem 1rem;
  color: #94a3b8;
  font-size: 0.88rem;
  text-align: center;
}
.inc-estado--error { color: #dc2626; }
.inc-estado__ring {
  width: 48px; height: 48px; border-radius: 50%;
  background: #ecfdf5; display: flex; align-items: center; justify-content: center;
  color: #059669; font-size: 1.3rem;
}

/* ════════════════════════════════════════════
   STATS
════════════════════════════════════════════ */
.inc-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}
.inc-stat {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: white;
  border: 1.5px solid #e5e7eb;
  border-radius: 14px;
  padding: 0.8rem 0.85rem;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.inc-stat__ic-wrap {
  width: 36px; height: 36px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; font-size: 0.95rem;
}
.inc-stat--bonus .inc-stat__ic-wrap  { background: #d1fae5; color: #059669; border: 1.5px solid #a7f3d0; }
.inc-stat--deme  .inc-stat__ic-wrap  { background: #fee2e2; color: #dc2626; border: 1.5px solid #fecaca; }

.inc-stat__body { flex: 1; min-width: 0; }
.inc-stat__num {
  display: block;
  font-size: 1.3rem; font-weight: 800; line-height: 1;
}
.inc-stat--bonus .inc-stat__num { color: #059669; }
.inc-stat--deme  .inc-stat__num { color: #dc2626; }
.inc-stat__lbl { font-size: 0.65rem; color: #94a3b8; display: block; margin-top: 0.1rem; }

.inc-stat__pts {
  font-size: 0.72rem; font-weight: 700;
  border-radius: 999px; padding: 0.15rem 0.5rem;
  flex-shrink: 0; align-self: flex-start; white-space: nowrap;
}
.inc-stat__pts--bonus { background: #d1fae5; color: #047857; }
.inc-stat__pts--deme  { background: #fee2e2; color: #dc2626; }

/* ════════════════════════════════════════════
   FILTROS
════════════════════════════════════════════ */
.inc-filtros {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.inc-tabs-scroll {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
  margin: 0 -1rem;
  padding: 0 1rem;
}
.inc-tabs-scroll::-webkit-scrollbar { display: none; }
.inc-tabs {
  display: flex;
  background: #f1f5f9;
  border-radius: 12px;
  padding: 3px;
  gap: 2px;
  width: max-content;
  min-width: 100%;
}
.inc-tab {
  flex: 1;
  display: flex; align-items: center; justify-content: center;
  gap: 0.25rem;
  min-height: 38px;
  padding: 0 0.65rem;
  border: none; border-radius: 10px;
  background: transparent;
  font-size: 0.8rem; font-weight: 600;
  color: #64748b;
  cursor: pointer; white-space: nowrap;
  transition: all .15s;
}
.inc-tab:hover { color: #374151; }
.inc-tab--on { background: white; color: #111827; box-shadow: 0 1px 4px rgba(0,0,0,.1); }
.inc-tab--bonus.inc-tab--on    { color: #047857; }
.inc-tab--demerito.inc-tab--on { color: #b91c1c; }
.inc-tab--pendiente.inc-tab--on { color: #92400e; }
.inc-tab__cnt {
  font-size: 0.62rem; font-weight: 700;
  background: #e2e8f0; color: #374151;
  border-radius: 999px; padding: 0 0.35rem;
  min-width: 16px; text-align: center; line-height: 1.6;
}
.inc-tab--on .inc-tab__cnt { background: #f1f5f9; }

.inc-equipo-sel {
  width: 100%;
  min-height: 42px;
  padding: 0.4rem 0.75rem;
  border: 1.5px solid #e2e8f0;
  border-radius: 10px;
  font-size: 0.84rem;
  background: white;
  color: #374151;
  cursor: pointer;
}
.inc-equipo-sel:focus { outline: none; border-color: #059669; box-shadow: 0 0 0 3px rgba(5,150,105,.12); }

/* ════════════════════════════════════════════
   CARDS
════════════════════════════════════════════ */
.inc-lista { display: flex; flex-direction: column; gap: 0.55rem; }

.inc-card {
  background: white;
  border: 1.5px solid #e5e7eb;
  border-left-width: 4px;
  border-radius: 14px;
  padding: 0.85rem 0.95rem;
  cursor: pointer;
  transition: box-shadow .15s, transform .1s;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.inc-card:active { transform: scale(0.99); }
.inc-card:hover  { box-shadow: 0 4px 16px rgba(0,0,0,.09); }
.inc-card--bonus { border-left-color: #059669; }
.inc-card--deme  { border-left-color: #ef4444; }

.inc-card__head {
  display: flex; align-items: center; gap: 0.45rem;
  margin-bottom: 0.45rem; flex-wrap: wrap;
}
.inc-cod {
  font-size: 0.7rem; font-weight: 800;
  letter-spacing: 0.04em; border-radius: 6px;
  padding: 0.18rem 0.45rem; flex-shrink: 0;
}
.inc-cod--b { background: #d1fae5; color: #047857; }
.inc-cod--d { background: #fee2e2; color: #b91c1c; }

.inc-card__equipo {
  display: flex; align-items: center; gap: 0.35rem;
  flex: 1; min-width: 0;
}
.inc-card__dot {
  width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0;
  border: 1px solid rgba(0,0,0,.1);
}
.inc-card__eq {
  font-weight: 700; font-size: 0.84rem; color: #1e293b;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

/* Estado badge inline */
.inc-st {
  font-size: 0.65rem; font-weight: 700;
  border-radius: 6px; padding: 0.18rem 0.45rem;
  white-space: nowrap; flex-shrink: 0;
  text-transform: uppercase; letter-spacing: 0.04em;
}
.st--amber { background: #fef3c7; color: #92400e; }
.st--green { background: #d1fae5; color: #065f46; }
.st--red   { background: #fee2e2; color: #991b1b; }

.inc-card__hecho {
  font-size: 0.83rem; color: #475569;
  margin: 0 0 0.45rem; line-height: 1.45;
  display: -webkit-box; -webkit-line-clamp: 2;
  -webkit-box-orient: vertical; overflow: hidden;
}
.inc-card__foot {
  display: flex; align-items: center; justify-content: space-between;
}
.inc-card__meta {
  display: flex; align-items: center; gap: 0.3rem;
  font-size: 0.72rem; color: #94a3b8;
}
.inc-card__meta .pi { font-size: 0.6rem; }
.inc-card__pts { font-weight: 800; font-size: 0.88rem; }
.pts--b { color: #059669; }
.pts--d { color: #ef4444; }

/* ════════════════════════════════════════════
   VACÍO
════════════════════════════════════════════ */
.inc-vacio {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.4rem; padding: 3rem 1rem; text-align: center;
}
.inc-vacio__ic {
  width: 54px; height: 54px; border-radius: 50%;
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.4rem; color: #cbd5e1; margin-bottom: 0.2rem;
}
.inc-vacio__title { font-size: 0.95rem; font-weight: 700; color: #64748b; margin: 0; }
.inc-vacio__sub   { font-size: 0.8rem; color: #94a3b8; margin: 0; line-height: 1.5; max-width: 260px; }

/* ════════════════════════════════════════════
   MODAL
════════════════════════════════════════════ */
.m-in   { transition: opacity .2s ease; }
.m-from { opacity: 0; }

.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) { .m-overlay { align-items: center; padding: 1rem; } }

.m-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.45); backdrop-filter: blur(4px);
}
.m-panel {
  position: relative; width: 100%; max-width: 440px;
  background: white; border-radius: 24px 24px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 90dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 20px; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.15rem 0.85rem;
  border-bottom: 1px solid #f1f5f9; flex-shrink: 0;
}
.m-head__left { display: flex; align-items: center; gap: 0.6rem; }
.m-ic {
  width: 32px; height: 32px; border-radius: 9px;
  background: #d1fae5; color: #059669;
  display: flex; align-items: center; justify-content: center; font-size: 0.88rem;
}
.m-title { font-size: 0.98rem; font-weight: 800; margin: 0; color: #0f172a; }
.m-close {
  width: 30px; height: 30px; border-radius: 8px;
  border: none; background: transparent; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.8rem; transition: background .15s;
}
.m-close:hover { background: #f1f5f9; color: #374151; }

.m-body {
  overflow-y: auto; padding: 1rem 1.15rem;
  flex: 1; display: flex; flex-direction: column; gap: 0.9rem;
}
.m-intro { font-size: 0.86rem; color: #475569; margin: 0; line-height: 1.6; }

.m-regla {
  display: flex; align-items: flex-start; gap: 0.5rem;
  background: #ecfdf5; border: 1.5px solid #a7f3d0; border-radius: 10px;
  padding: 0.65rem 0.8rem; font-size: 0.81rem; color: #166534; line-height: 1.5;
}
.m-regla .pi { flex-shrink: 0; margin-top: 0.1rem; color: #059669; }

.m-pasos { display: flex; flex-direction: column; gap: 0.65rem; }
.m-paso  { display: flex; gap: 0.7rem; align-items: flex-start; }
.m-paso__n {
  width: 26px; height: 26px; border-radius: 50%;
  background: #d1fae5; color: #047857;
  font-weight: 800; font-size: 0.76rem;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; margin-top: 0.1rem;
}
.m-paso__n--ok { background: #059669; color: white; }
.m-paso__t { font-size: 0.86rem; font-weight: 700; color: #1e293b; margin: 0 0 0.08rem; }
.m-paso__d { font-size: 0.78rem; color: #64748b; margin: 0; line-height: 1.4; }

.m-sec {
  font-size: 0.8rem; font-weight: 700; margin: 0;
  display: flex; align-items: center; gap: 0.35rem;
}
.m-sec--bonus { color: #047857; }
.m-sec--deme  { color: #b91c1c; }

.m-codigos { display: flex; flex-direction: column; gap: 0.35rem; margin-top: -0.4rem; }
.m-codigo {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.5rem 0.7rem;
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 10px;
}
.m-cod {
  font-size: 0.68rem; font-weight: 800; letter-spacing: 0.04em;
  border-radius: 6px; padding: 0.18rem 0.45rem; flex-shrink: 0;
}
.m-cod--b { background: #d1fae5; color: #047857; }
.m-cod--d { background: #fee2e2; color: #b91c1c; }
.m-codigo__info { display: flex; flex-direction: column; gap: 0.05rem; font-size: 0.8rem; }
.m-codigo__info strong { color: #1e293b; }
.m-codigo__info span   { font-size: 0.74rem; color: #64748b; }

.m-estados {
  background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 12px; padding: 0.85rem;
}
.m-estados__tit {
  font-size: 0.68rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .06em; margin: 0 0 0.55rem;
}
.m-est-row {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.28rem 0; font-size: 0.78rem; color: #64748b;
}
.m-est-row + .m-est-row { border-top: 1px solid #f1f5f9; }

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.7rem 0.85rem;
  background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px;
  font-size: 0.77rem; color: #78350f; line-height: 1.5;
}
.m-nota .pi { flex-shrink: 0; margin-top: 0.1rem; color: #d97706; }

.m-foot {
  padding: 0.85rem 1.15rem;
  border-top: 1px solid #f1f5f9; flex-shrink: 0;
}

/* ════════════════════════════════════════════
   RESPONSIVE TABLET / DESKTOP
════════════════════════════════════════════ */
@media (min-width: 480px) {
  .inc-filtros { flex-direction: row; align-items: center; }
  .inc-tabs { width: auto; }
  .inc-tabs-scroll { margin: 0; padding: 0; overflow: visible; }
  .inc-equipo-sel { width: auto; flex-shrink: 0; }
}

@media (min-width: 640px) {
  .inc-page { padding: 0 1.5rem 4rem; }
  .inc-dias-wrap { margin: 0; padding: 0; overflow: visible; }
  .inc-dias { flex-wrap: wrap; }
  .inc-dia { min-width: 80px; }
  .inc-stat__num { font-size: 1.5rem; }
}
</style>
