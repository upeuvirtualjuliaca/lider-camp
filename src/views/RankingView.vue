<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import {
  rankingDiarioPublicoService, type PublicoRankingDia,
  rankingTotalPublicoService,  type PublicoRankingTotal,
} from '@/modules/puntajes/services/puntajes.service'

const router    = useRouter()
const route     = useRoute()
const cargando  = ref(true)
const error     = ref('')
const modalOpen   = ref(false)
const ultimaAct   = ref<Date | null>(null)
const tabActivo   = ref<'total' | string>('total')
const enConteo    = ref(false)
const segundos    = ref(0)

// Todos los datos de días cerrados
const datosDias    = ref<PublicoRankingDia[]>([])
// Ranking total final (solo cuando campamento cerrado)
const rankingTotal = ref<PublicoRankingTotal[]>([])

// ── Tabs ──────────────────────────────────────────────────────────────────────
const ORDEN_DIAS = ['J', 'V', 'S', 'D']
const LABEL_DIA: Record<string, string> = {
  J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo',
}

const diasConDatos = computed(() => {
  const set = new Set(datosDias.value.map((r) => r.momento))
  return ORDEN_DIAS.filter((m) => set.has(m))
})

const tabs = computed(() => [
  { key: 'total', label: 'Total' },
  ...diasConDatos.value.map((m) => ({ key: m, label: LABEL_DIA[m] ?? m })),
])

// ── Ranking por día ───────────────────────────────────────────────────────────
interface FilaRanking {
  equipo_id: string
  equipo_nombre: string
  equipo_color: string | null
  pts_rubrica: number
  pts_actividades: number
  pts_bonus: number
  pts_demeritos: number
  pts_total: number
  posicion: number
}

const rankingDia = computed<FilaRanking[]>(() => {
  if (tabActivo.value === 'total') return []
  return datosDias.value
    .filter((r) => r.momento === tabActivo.value)
    .sort((a, b) => a.posicion - b.posicion)
    .map((r) => ({
      equipo_id:       r.equipo_id,
      equipo_nombre:   r.equipo_nombre,
      equipo_color:    r.equipo_color,
      pts_rubrica:     r.pts_rubrica,
      pts_actividades: r.pts_actividades,
      pts_bonus:       r.pts_bonus,
      pts_demeritos:   r.pts_demeritos,
      pts_total:       r.pts_total,
      posicion:        r.posicion,
    }))
})

const hayResultados = computed(() => rankingDia.value.some((r) => r.pts_total > 0))
const campCerrado   = computed(() => datosDias.value.some((r) => r.pts_actividades > 0 || r.pts_bonus > 0 || r.pts_demeritos > 0))

const top3 = computed(() => ({
  primero: rankingDia.value.find((r) => r.posicion === 1) ?? null,
  segundo: rankingDia.value.find((r) => r.posicion === 2) ?? null,
  tercero: rankingDia.value.find((r) => r.posicion === 3) ?? null,
}))

const horaAct = computed(() => {
  if (!ultimaAct.value) return ''
  return ultimaAct.value.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })
})

// ── Podio total ───────────────────────────────────────────────────────────────
const top3Total = computed(() => ({
  primero: rankingTotal.value.find((r) => r.posicion === 1) ?? null,
  segundo: rankingTotal.value.find((r) => r.posicion === 2) ?? null,
  tercero: rankingTotal.value.find((r) => r.posicion === 3) ?? null,
}))

const MEDALLA_EMOJI: Record<string, string> = {
  oro: '🥇', plata: '🥈', bronce: '🥉', participacion: '🎖',
}
const MEDALLA_LABEL: Record<string, string> = {
  oro: 'Oro', plata: 'Plata', bronce: 'Bronce', participacion: 'Participación',
}
function badgeClase(m: string | null) {
  const map: Record<string, string> = {
    oro: 'badge--oro', plata: 'badge--plata',
    bronce: 'badge--bronce', participacion: 'badge--part',
  }
  return map[m ?? ''] ?? 'badge--part'
}

// ── Carga ─────────────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  error.value    = ''
  try {
    const [dias, total] = await Promise.all([
      rankingDiarioPublicoService.getAll(),
      rankingTotalPublicoService.getAll(),
    ])
    datosDias.value    = dias
    rankingTotal.value = total
    ultimaAct.value    = new Date()
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar el ranking'
  } finally {
    cargando.value = false
  }
}

onMounted(async () => {
  await cargar()
  if (route.query.countdown === '1') {
    tabActivo.value = 'total'
    segundos.value  = 60
    enConteo.value  = true
    router.replace('/ranking')
    const timer = setInterval(() => {
      segundos.value--
      if (segundos.value <= 0) {
        clearInterval(timer)
        enConteo.value = false
        if (rankingTotal.value.length) iniciarRevelacion()
      }
    }, 1000)
  }
})

// ── Revelación de resultados ──────────────────────────────────────────────────
const enRevela       = ref(false)
const revelaEtapa    = ref(0)       // 0=espera 1=3ro 2=2do 3=1ro 4=ver-btn
const confettiActivo = ref(false)
const cuentaScore    = ref({ p: 0, s: 0, t: 0 })

const confettiPiezas = Array.from({ length: 75 }, (_, i) => {
  const cols = ['#fbbf24','#34d399','#60a5fa','#f472b6','#a78bfa','#fb7185','#fde047','#4ade80','#ff6b6b','#38bdf8']
  return {
    id:       i,
    left:     (Math.random() * 100).toFixed(1) + '%',
    delay:    (Math.random() * 2).toFixed(2)   + 's',
    duration: (2 + Math.random() * 2.8).toFixed(2) + 's',
    color:    cols[Math.floor(Math.random() * cols.length)],
    size:     Math.round(5 + Math.random() * 9) + 'px',
    round:    Math.random() > 0.45,
    rot:      Math.round(Math.random() * 360),
  }
})

function animarScore(key: 'p' | 's' | 't', target: number) {
  const steps = 60
  const ms    = 1800 / steps
  let step = 0
  const iv = setInterval(() => {
    step++
    cuentaScore.value[key] = Math.round(target * Math.min(step / steps, 1))
    if (step >= steps) { cuentaScore.value[key] = target; clearInterval(iv) }
  }, ms)
}

function saltarRevela() {
  enRevela.value       = false
  confettiActivo.value = false
  revelaEtapa.value    = 0
}

function iniciarRevelacion() {
  cuentaScore.value = { p: 0, s: 0, t: 0 }
  revelaEtapa.value = 0
  enRevela.value    = true
  // 3er lugar
  setTimeout(() => { revelaEtapa.value = 1; animarScore('t', top3Total.value.tercero?.pts_bruto ?? 0) }, 800)
  // 2do lugar
  setTimeout(() => { revelaEtapa.value = 2; animarScore('s', top3Total.value.segundo?.pts_bruto ?? 0) }, 3600)
  // 1er lugar + confetti
  setTimeout(() => {
    revelaEtapa.value    = 3
    confettiActivo.value = true
    animarScore('p', top3Total.value.primero?.pts_bruto ?? 0)
  }, 6400)
  // Botón continuar
  setTimeout(() => { revelaEtapa.value = 4 }, 9000)
}

// ── Helpers visuales ──────────────────────────────────────────────────────────
function posClase(pos: number) {
  if (pos === 1) return 'rk-pos--1'
  if (pos === 2) return 'rk-pos--2'
  if (pos === 3) return 'rk-pos--3'
  return 'rk-pos--n'
}
function cardClase(pos: number) {
  return pos === 1 && hayResultados.value ? 'rk-card--1' : ''
}
function podioItemClase(pos: number) {
  return `podio-item--${pos}`
}
</script>

<template>
  <div class="rk-page">

    <!-- Encabezado -->
    <div class="rk-header">
      <div class="rk-header__left">
        <i class="pi pi-trophy rk-icon" />
        <div>
          <h1 class="rk-title">Ranking LiderCamp 2026-II</h1>
          <p v-if="ultimaAct" class="rk-sub">Actualizado a las {{ horaAct }}</p>
        </div>
      </div>
      <div class="rk-header__right">
        <button class="btn-refresh" :disabled="cargando" title="Actualizar ranking" @click="cargar">
          <i :class="['pi', cargando ? 'pi-spin pi-spinner' : 'pi-refresh']" />
        </button>
        <button class="btn-ayuda" title="¿Cómo funciona?" @click="modalOpen = true">
          <i class="pi pi-question-circle" />
        </button>
      </div>
    </div>

    <!-- ── Contador de revelación ── -->
    <Transition name="cnt">
      <div v-if="enConteo" class="cnt-overlay">
        <div class="cnt-box">
          <p class="cnt-label">Revelando resultados finales en</p>
          <div class="cnt-num">{{ segundos }}</div>
          <p class="cnt-sub">¡Prepárense para ver el ranking final!</p>
          <div class="cnt-barra">
            <div class="cnt-barra__fill" :style="{ width: (1 - segundos / 60) * 100 + '%' }" />
          </div>
        </div>
      </div>
    </Transition>

    <!-- ── Revelación de resultados finales ── -->
    <Transition name="rv">
      <div v-if="enRevela" class="rv-overlay">

        <!-- Confetti -->
        <div v-if="confettiActivo" class="rv-confetti" aria-hidden="true">
          <div
            v-for="p in confettiPiezas" :key="p.id"
            class="rv-pieza"
            :style="{
              left: p.left, background: p.color,
              width: p.size, height: p.size,
              borderRadius: p.round ? '50%' : '3px',
              animationDelay: p.delay, animationDuration: p.duration,
            }"
          />
        </div>

        <!-- Botón saltar -->
        <button class="rv-skip" @click="saltarRevela">
          Saltar <i class="pi pi-angle-double-right" />
        </button>

        <!-- Título -->
        <div class="rv-head">
          <p class="rv-titulo">Resultados Finales</p>
          <p class="rv-sub">LiderCamp 2026-II</p>
        </div>

        <!-- Tarjetas del podio (aparecen una a una) -->
        <div class="rv-podio">

          <!-- 3er lugar -->
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 1 && top3Total.tercero" class="rv-card rv-card--3">
              <div class="rv-badge rv-badge--3">🥉 3er Puesto</div>
              <span class="rv-dot" :style="{ background: top3Total.tercero.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre">{{ top3Total.tercero.equipo_nombre }}</p>
              <div class="rv-score rv-score--3">
                <span class="rv-score__n">{{ cuentaScore.t }}</span>
                <span class="rv-score__u">pts</span>
              </div>
            </div>
          </Transition>

          <!-- 2do lugar -->
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 2 && top3Total.segundo" class="rv-card rv-card--2">
              <div class="rv-badge rv-badge--2">🥈 2° Puesto</div>
              <span class="rv-dot" :style="{ background: top3Total.segundo.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre">{{ top3Total.segundo.equipo_nombre }}</p>
              <div class="rv-score rv-score--2">
                <span class="rv-score__n">{{ cuentaScore.s }}</span>
                <span class="rv-score__u">pts</span>
              </div>
            </div>
          </Transition>

          <!-- 1er lugar -->
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 3 && top3Total.primero" class="rv-card rv-card--1">
              <div class="rv-crown">👑</div>
              <div class="rv-badge rv-badge--1">🥇 Primer Puesto</div>
              <span class="rv-dot rv-dot--1" :style="{ background: top3Total.primero.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre rv-nombre--1">{{ top3Total.primero.equipo_nombre }}</p>
              <div class="rv-score rv-score--1">
                <span class="rv-score__n">{{ cuentaScore.p }}</span>
                <span class="rv-score__u">pts</span>
              </div>
            </div>
          </Transition>

        </div>

        <!-- Botón ver ranking completo -->
        <Transition name="rv-card">
          <button v-if="revelaEtapa >= 4" class="rv-btn-ver" @click="saltarRevela">
            Ver ranking completo <i class="pi pi-arrow-right" />
          </button>
        </Transition>

      </div>
    </Transition>

    <!-- Cargando inicial -->
    <div v-if="cargando && !datosDias.length" class="rk-empty">
      <i class="pi pi-spin pi-spinner rk-empty__icon" />
      <span>Cargando ranking…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="rk-error">
      <i class="pi pi-exclamation-triangle" />
      {{ error }}
    </div>

    <template v-else>

      <!-- Tabs -->
      <div class="rk-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          :class="['rk-tab', tabActivo === tab.key && 'rk-tab--active']"
          @click="tabActivo = tab.key"
        >{{ tab.label }}</button>
      </div>

      <!-- Tab Total -->
      <template v-if="tabActivo === 'total'">
        <!-- Esperando fin del contador -->
        <div v-if="enConteo" class="rk-empty">
          <i class="pi pi-spin pi-spinner rk-empty__icon" />
          <span class="rk-empty__msg">Los resultados se revelarán en {{ segundos }} segundos…</span>
        </div>

        <!-- Sin datos: campamento aún no cerrado -->
        <div v-else-if="!rankingTotal.length" class="rk-empty">
          <i class="pi pi-lock rk-empty__icon" />
          <span class="rk-empty__msg">Esta información se procesará una vez cerrado el campamento.</span>
        </div>

        <!-- Ranking total procesado -->
        <template v-else>
          <!-- Podio -->
          <div v-if="top3Total.primero" class="podio">
            <div v-if="top3Total.segundo" :class="['podio-item', podioItemClase(2)]">
              <div class="podio-medalla">🥈</div>
              <div class="podio-color" :style="{ background: top3Total.segundo.equipo_color ?? '#6b7280' }" />
              <div class="podio-nombre">{{ top3Total.segundo.equipo_nombre }}</div>
              <div class="podio-pts">{{ top3Total.segundo.pts_bruto }}<span class="podio-pts__de"> pts</span></div>
              <div class="podio-base podio-base--2" />
            </div>
            <div :class="['podio-item', podioItemClase(1)]">
              <div class="podio-corona">👑</div>
              <div class="podio-medalla podio-medalla--1">🥇</div>
              <div class="podio-color podio-color--1" :style="{ background: top3Total.primero!.equipo_color ?? '#6b7280' }" />
              <div class="podio-nombre podio-nombre--1">{{ top3Total.primero!.equipo_nombre }}</div>
              <div class="podio-pts podio-pts--1">{{ top3Total.primero!.pts_bruto }}<span class="podio-pts__de"> pts</span></div>
              <div class="podio-base podio-base--1" />
            </div>
            <div v-if="top3Total.tercero" :class="['podio-item', podioItemClase(3)]">
              <div class="podio-medalla">🥉</div>
              <div class="podio-color" :style="{ background: top3Total.tercero.equipo_color ?? '#6b7280' }" />
              <div class="podio-nombre">{{ top3Total.tercero.equipo_nombre }}</div>
              <div class="podio-pts">{{ top3Total.tercero.pts_bruto }}<span class="podio-pts__de"> pts</span></div>
              <div class="podio-base podio-base--3" />
            </div>
          </div>

          <!-- Lista completa -->
          <div class="rk-lista">
            <div
              v-for="eq in rankingTotal"
              :key="eq.equipo_id"
              :class="['rk-card', eq.posicion === 1 ? 'rk-card--1' : '']"
            >
              <span :class="['rk-pos', posClase(eq.posicion)]">{{ eq.posicion }}°</span>
              <div class="rk-equipo">
                <span class="rk-dot" :style="{ background: eq.equipo_color ?? '#6b7280' }" />
                <span class="rk-nombre">{{ eq.equipo_nombre }}</span>
              </div>
              <span class="rk-pts">{{ eq.pts_bruto }}<span class="rk-pts__de"> pts</span></span>
            </div>
          </div>
          <p class="rk-nota"><i class="pi pi-info-circle" /> Rúbrica + Actividades + Bonus − Deméritos.</p>
        </template>
      </template>

      <!-- Sin días cerrados aún (tabs de día) -->
      <div v-else-if="!diasConDatos.length" class="rk-aviso">
        <i class="pi pi-clock" />
        <div>
          <strong>Resultados pendientes</strong>
          <span>Los puntajes se mostrarán cuando el administrador cierre cada día.</span>
        </div>
      </div>

      <!-- Sin datos para el tab activo -->
      <div v-else-if="!rankingDia.length" class="rk-empty">
        <i class="pi pi-calendar-times rk-empty__icon" />
        <span>Sin datos para este día.</span>
      </div>

      <template v-else>

        <!-- ── PODIO ── -->
        <div v-if="hayResultados && top3.primero" class="podio">
          <!-- 2° lugar -->
          <div
            v-if="top3.segundo"
            :class="['podio-item', podioItemClase(2)]"
            @click="router.push(`/equipo/${top3.segundo.equipo_id}`)"
          >
            <div class="podio-puesto podio-puesto--2">2° Puesto</div>
            <div class="podio-color" :style="{ background: top3.segundo.equipo_color ?? '#6b7280' }" />
            <div class="podio-nombre">{{ top3.segundo.equipo_nombre }}</div>
            <div class="podio-pts">{{ top3.segundo.pts_total }}<span class="podio-pts__de"> pts</span></div>
            <div class="podio-base podio-base--2" />
          </div>

          <!-- 1° lugar -->
          <div
            :class="['podio-item', podioItemClase(1)]"
            @click="router.push(`/equipo/${top3.primero!.equipo_id}`)"
          >
            <div class="podio-corona">⭐</div>
            <div class="podio-puesto podio-puesto--1">1er Puesto</div>
            <div class="podio-color podio-color--1" :style="{ background: top3.primero!.equipo_color ?? '#6b7280' }" />
            <div class="podio-nombre podio-nombre--1">{{ top3.primero!.equipo_nombre }}</div>
            <div class="podio-pts podio-pts--1">{{ top3.primero!.pts_total }}<span class="podio-pts__de"> pts</span></div>
            <div class="podio-base podio-base--1" />
          </div>

          <!-- 3° lugar -->
          <div
            v-if="top3.tercero"
            :class="['podio-item', podioItemClase(3)]"
            @click="router.push(`/equipo/${top3.tercero.equipo_id}`)"
          >
            <div class="podio-puesto podio-puesto--3">3er Puesto</div>
            <div class="podio-color" :style="{ background: top3.tercero.equipo_color ?? '#6b7280' }" />
            <div class="podio-nombre">{{ top3.tercero.equipo_nombre }}</div>
            <div class="podio-pts">{{ top3.tercero.pts_total }}<span class="podio-pts__de"> pts</span></div>
            <div class="podio-base podio-base--3" />
          </div>
        </div>

        <!-- ── LISTA COMPLETA ── -->
        <div class="rk-lista">
          <div
            v-for="eq in rankingDia"
            :key="eq.equipo_id"
            :class="['rk-card', cardClase(eq.posicion)]"
            @click="router.push(`/equipo/${eq.equipo_id}`)"
          >
            <span :class="['rk-pos', posClase(eq.posicion)]">{{ eq.posicion }}°</span>
            <div class="rk-equipo">
              <span class="rk-dot" :style="{ background: eq.equipo_color ?? '#6b7280' }" />
              <span class="rk-nombre">{{ eq.equipo_nombre }}</span>
            </div>
            <span class="rk-pts">
              {{ eq.pts_total }}
              <span class="rk-pts__de"> pts</span>
            </span>
            <i class="pi pi-angle-right rk-arrow" />
          </div>
        </div>

        <p class="rk-nota">
          <i class="pi pi-info-circle" />
          {{ campCerrado ? 'Rúbrica + Actividades + Bonus − Deméritos.' : 'Toca un equipo para ver su ficha detallada.' }}
        </p>

      </template>
    </template>

    <!-- ── Modal ¿Cómo funciona? ── -->
    <Teleport to="body">
      <Transition name="m-ea" @enter="(el: any) => el.style.opacity = '1'" @leave="(el: any) => el.style.opacity = '0'">
        <div v-if="modalOpen" class="m-overlay" @click.self="modalOpen = false">
          <div class="m-backdrop" @click="modalOpen = false" />
          <div class="m-panel">
            <div class="m-drag" />
            <div class="m-head">
              <div class="m-head__left">
                <div class="m-icon"><i class="pi pi-trophy" /></div>
                <h2 class="m-title">¿Cómo funciona el ranking?</h2>
              </div>
              <button class="m-close" @click="modalOpen = false">
                <i class="pi pi-times" />
              </button>
            </div>

            <div class="m-body">
              <p class="m-intro">
                El puntaje de cada equipo se calcula a partir de varios componentes evaluados
                durante los 4 días del campamento (J, V, S, D).
              </p>

              <div class="m-pasos">
                <div class="m-paso">
                  <div class="m-paso__n">1</div>
                  <div>
                    <p class="m-paso__t">Puntaje base</p>
                    <p class="m-paso__d">Inscripción + Rúbrica de observaciones diarias + Liderazgo + Asistencia a eventos.</p>
                  </div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n">2</div>
                  <div>
                    <p class="m-paso__t">Bonus y deméritos</p>
                    <p class="m-paso__d">Se suman los bonus validados (B1/B2, máx. 200 pts) y se restan los deméritos aplicados (D1–D6, sin tope).</p>
                  </div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n m-paso__n--ok">3</div>
                  <div>
                    <p class="m-paso__t">Escala 1000</p>
                    <p class="m-paso__d">El puntaje bruto se convierte a una escala de 0 a 1000 para comparar equipos de manera justa.</p>
                  </div>
                </div>
              </div>

              <div class="m-medallas">
                <p class="m-medallas__tit">Medallas</p>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥇</span>
                  <span class="m-medalla-badge badge--oro">Oro</span>
                  <span class="m-medalla-rango">Mayor puntaje</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥈</span>
                  <span class="m-medalla-badge badge--plata">Plata</span>
                  <span class="m-medalla-rango">2° y 3° lugar</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥉</span>
                  <span class="m-medalla-badge badge--bronce">Bronce</span>
                  <span class="m-medalla-rango">Resto del podio</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🎖</span>
                  <span class="m-medalla-badge badge--part">Participación</span>
                  <span class="m-medalla-rango">Todos los demás</span>
                </div>
              </div>

              <div class="m-nota">
                <i class="pi pi-clock" />
                Los resultados se publican por día a medida que el administrador los activa.
              </div>
            </div>

            <div class="m-foot">
              <button class="btn btn--primary btn--full" @click="modalOpen = false">Entendido</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
/* ─── Página ─── */
.rk-page {
  max-width: 640px;
  margin: 0 auto;
  padding: 1rem 1rem 2rem;
}

/* ─── Encabezado ─── */
.rk-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.rk-header__left {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex: 1;
  min-width: 0;
}
.rk-header__right {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}
.rk-icon  { font-size: 1.4rem; color: #16a34a; flex-shrink: 0; }
.rk-title { font-size: 1.1rem; font-weight: 800; margin: 0; color: #111827; line-height: 1.2; }
.rk-sub   { font-size: 0.75rem; color: #9ca3af; margin: 0.1rem 0 0; }

.btn-refresh {
  width: 36px; height: 36px; border-radius: 50%;
  border: 1px solid #e2e8f0; background: white; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.9rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
}
.btn-refresh:hover:not(:disabled) { color: #16a34a; border-color: #bbf7d0; }
.btn-refresh:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-ayuda {
  width: 36px; height: 36px; border-radius: 50%;
  border: 1px solid #e2e8f0; background: white; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 1rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
}
.btn-ayuda:hover { color: #16a34a; border-color: #bbf7d0; }

/* ─── Tabs ─── */
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

/* ─── Aviso ─── */
.rk-aviso {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 10px;
  padding: 0.85rem 1rem;
  margin-bottom: 1.25rem;
  font-size: 0.85rem;
}
.rk-aviso i { color: #d97706; flex-shrink: 0; margin-top: 0.15rem; }
.rk-aviso strong { display: block; color: #92400e; font-size: 0.9rem; }
.rk-aviso span   { color: #b45309; font-size: 0.8rem; line-height: 1.4; }

/* ─── Estados vacíos ─── */
.rk-empty {
  display: flex; flex-direction: column; align-items: center; gap: 0.5rem;
  padding: 3rem 1rem; text-align: center; color: #9ca3af; font-size: 0.9rem;
}
.rk-empty__icon { font-size: 2.5rem; margin-bottom: 0.25rem; }
.rk-empty__msg  { max-width: 260px; text-align: center; line-height: 1.5; color: #6b7280; }

.rk-error {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px;
  padding: 0.85rem 1rem; color: #b91c1c; font-size: 0.88rem;
}

/* ─── PODIO ─── */
.podio {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  padding: 0 0.25rem;
}

.podio-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  max-width: 130px;
  cursor: pointer;
  transition: transform .15s;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px 12px 0 0;
  padding: 0.65rem 0.5rem 0;
  box-shadow: 0 2px 8px rgba(0,0,0,.07);
  position: relative;
  overflow: hidden;
}
.podio-item:hover { transform: translateY(-4px); box-shadow: 0 6px 16px rgba(0,0,0,.12); }

.podio-item--1 {
  order: 2;
  background: linear-gradient(160deg, #fefce8 0%, white 60%);
  border-color: #fde68a;
  padding-top: 0.4rem;
}
.podio-item--2 { order: 1; }
.podio-item--3 { order: 3; }

.podio-corona { font-size: 1.1rem; line-height: 1; margin-bottom: 0.1rem; }
.podio-medalla { font-size: 1.75rem; line-height: 1; }
.podio-medalla--1 { font-size: 2.1rem; }

.podio-puesto {
  font-size: 0.65rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .05em;
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  line-height: 1.4;
}
.podio-puesto--1 { background: #fef3c7; color: #92400e; }
.podio-puesto--2 { background: #f1f5f9; color: #475569; }
.podio-puesto--3 { background: #ffedd5; color: #9a3412; }

.podio-color {
  width: 28px; height: 28px; border-radius: 50%;
  border: 2px solid #e5e7eb; margin: 0.35rem 0 0.2rem;
  flex-shrink: 0;
}
.podio-color--1 { width: 34px; height: 34px; }

.podio-nombre {
  font-weight: 700; font-size: 0.78rem; text-align: center;
  color: #111827; line-height: 1.2; padding: 0 0.15rem;
  max-width: 100%; overflow: hidden; text-overflow: ellipsis;
  white-space: nowrap; width: 100%;
}
.podio-nombre--1 { font-size: 0.85rem; }

.podio-pts {
  font-size: 0.88rem; font-weight: 800; color: #16a34a; margin: 0.15rem 0 0;
}
.podio-pts--1  { font-size: 1rem; }
.podio-pts__de { font-size: 0.65rem; color: #9ca3af; font-weight: 600; }

.podio-base {
  width: calc(100% + 2px); margin: 0.5rem -1px -1px;
  border-radius: 0; flex-shrink: 0;
}
.podio-base--1 { height: 40px; background: linear-gradient(180deg, #fde68a, #f59e0b); }
.podio-base--2 { height: 28px; background: linear-gradient(180deg, #e2e8f0, #94a3b8); }
.podio-base--3 { height: 20px; background: linear-gradient(180deg, #fed7aa, #f97316); }

/* ─── Lista ─── */
.rk-lista { display: flex; flex-direction: column; gap: 0.4rem; }

.rk-card {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 0.75rem 0.85rem;
  cursor: pointer;
  transition: box-shadow .15s, border-color .15s;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  min-height: 52px;
}
.rk-card:hover { box-shadow: 0 3px 10px rgba(0,0,0,.08); border-color: #d1d5db; }
.rk-card--1 {
  border-color: #fde68a;
  background: linear-gradient(90deg, #fefce8 0%, white 60%);
}

.rk-pos {
  font-weight: 800; font-size: 0.88rem;
  min-width: 32px; text-align: center; flex-shrink: 0;
}
.rk-pos--1 { color: #d97706; font-size: 1rem; }
.rk-pos--2 { color: #64748b; }
.rk-pos--3 { color: #f97316; }
.rk-pos--n { color: #9ca3af; }

.rk-equipo {
  display: flex; align-items: center; gap: 0.5rem; flex: 1; min-width: 0;
}
.rk-dot {
  width: 20px; height: 20px; border-radius: 50%;
  border: 1.5px solid #e5e7eb; flex-shrink: 0;
}
.rk-nombre {
  font-weight: 600; font-size: 0.9rem; color: #111827;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

.rk-pts {
  font-weight: 800; font-size: 0.95rem; color: #16a34a;
  min-width: 60px; text-align: right; flex-shrink: 0; white-space: nowrap;
}
.rk-pts__de { font-size: 0.72rem; color: #9ca3af; font-weight: 600; }

.rk-arrow { font-size: 0.75rem; color: #d1d5db; flex-shrink: 0; }

/* Nota final */
.rk-nota {
  text-align: center; font-size: 0.8rem; color: #9ca3af;
  margin-top: 0.85rem;
  display: flex; align-items: center; justify-content: center; gap: 0.35rem;
}

/* ─── Responsive ─── */
@media (max-width: 360px) {
  .rk-title { font-size: 0.95rem; }
  .rk-card  { padding: 0.6rem 0.65rem; }
  .podio-item { max-width: 110px; }
}
@media (min-width: 480px) {
  .rk-title { font-size: 1.2rem; }
  .podio { gap: 0.75rem; }
  .podio-item { max-width: 150px; }
  .podio-nombre { font-size: 0.85rem; }
  .podio-nombre--1 { font-size: 0.95rem; }
}
@media (min-width: 640px) {
  .rk-page { padding: 1.5rem 1.5rem 3rem; }
  .rk-title { font-size: 1.3rem; }
}

/* ─── Badge medalla (modal) ─── */
.badge--oro    { background: #fef9c3; color: #92400e; }
.badge--plata  { background: #f1f5f9; color: #475569; }
.badge--bronce { background: #ffedd5; color: #9a3412; }
.badge--part   { background: #f3f4f6; color: #6b7280; }

/* ─── Modal ─── */
.m-ea-enter-active, .m-ea-leave-active { transition: opacity .2s ease; }
.m-ea-enter-from, .m-ea-leave-to { opacity: 0; }

.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) { .m-overlay { align-items: center; padding: 1rem; } }

.m-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.4); backdrop-filter: blur(4px);
}
.m-panel {
  position: relative; width: 100%; max-width: 480px;
  background: white; border-radius: 20px 20px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 90dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }

.m-drag {
  width: 36px; height: 4px; border-radius: 2px;
  background: #e5e7eb; margin: 0.65rem auto 0; flex-shrink: 0;
}
@media (min-width: 640px) { .m-drag { display: none; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem 0.85rem;
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

.m-body { overflow-y: auto; padding: 1.1rem 1.25rem; flex: 1; }
.m-intro { font-size: 0.88rem; color: #475569; margin: 0 0 1rem; line-height: 1.55; }

.m-pasos { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.25rem; }
.m-paso  { display: flex; gap: 0.75rem; align-items: flex-start; }
.m-paso__n {
  width: 28px; height: 28px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  font-weight: 800; font-size: 0.78rem;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; margin-top: 0.05rem;
}
.m-paso__n--ok { background: #16a34a; color: white; }
.m-paso__t { font-size: 0.88rem; font-weight: 700; color: #1e293b; margin: 0 0 0.1rem; }
.m-paso__d { font-size: 0.8rem; color: #64748b; margin: 0; line-height: 1.4; }

.m-medallas {
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: 0.85rem; margin-bottom: 1rem;
}
.m-medallas__tit {
  font-size: 0.72rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .05em; margin: 0 0 0.6rem;
}
.m-medalla-fila {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.25rem 0; font-size: 0.82rem;
  border-top: 1px solid #f1f5f9;
}
.m-medalla-fila:first-of-type { border-top: none; }
.m-medalla-emoji { font-size: 1rem; flex-shrink: 0; }
.m-medalla-badge {
  font-size: 0.7rem; font-weight: 700;
  padding: 0.15rem 0.5rem; border-radius: 20px; flex-shrink: 0;
}
.m-medalla-rango { font-size: 0.78rem; color: #6b7280; }

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.7rem 0.85rem; background: #f0fdf4;
  border: 1px solid #bbf7d0; border-radius: 8px;
  font-size: 0.78rem; color: #15803d; line-height: 1.45;
}
.m-nota i { flex-shrink: 0; margin-top: 0.1rem; }

.m-foot { padding: 0.9rem 1.25rem; border-top: 1px solid #f1f5f9; flex-shrink: 0; }

.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 0.35rem;
  min-height: 44px; padding: 0.5rem 1.25rem;
  border-radius: 8px; border: none;
  font-size: 0.88rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover { background: #15803d; }
.btn--full { width: 100%; }

/* ══════════════════════════════════════════════════════
   REVELACIÓN DE RESULTADOS
══════════════════════════════════════════════════════ */
.rv-enter-active { transition: opacity .5s ease; }
.rv-leave-active { transition: opacity .9s ease; }
.rv-enter-from, .rv-leave-to { opacity: 0; }

.rv-overlay {
  position: fixed; inset: 0; z-index: 400;
  background: radial-gradient(ellipse at 50% 0%, #1e1b4b 0%, #0f172a 60%);
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  padding: 1.5rem; gap: 1.5rem;
  overflow: hidden;
}

/* Confetti */
.rv-confetti { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
.rv-pieza {
  position: absolute; top: -14px;
  animation: rv-fall linear forwards;
}
@keyframes rv-fall {
  0%   { transform: translateY(0)      rotate(0deg);   opacity: 1; }
  85%  { opacity: 1; }
  100% { transform: translateY(108vh)  rotate(600deg); opacity: 0; }
}

/* Saltar */
.rv-skip {
  position: absolute; top: 1rem; right: 1rem;
  background: rgba(255,255,255,.08); border: 1px solid rgba(255,255,255,.18);
  color: #94a3b8; border-radius: 8px;
  padding: 0.4rem 0.9rem; font-size: 0.78rem; font-weight: 600;
  cursor: pointer; display: flex; align-items: center; gap: 0.35rem;
  transition: background .15s;
  z-index: 1;
}
.rv-skip:hover { background: rgba(255,255,255,.15); }

/* Título */
.rv-head { text-align: center; z-index: 1; }
.rv-titulo {
  font-size: 1.55rem; font-weight: 900; color: #f1f5f9;
  margin: 0; letter-spacing: .01em;
}
.rv-sub {
  font-size: 0.82rem; color: #64748b; margin: 0.2rem 0 0;
  text-transform: uppercase; letter-spacing: .08em;
}

/* Podio */
.rv-podio {
  width: 100%; max-width: 400px;
  display: flex; flex-direction: column; gap: 0.65rem;
  z-index: 1;
}

/* Tarjetas */
.rv-card {
  display: flex; align-items: center; gap: 0.75rem;
  border-radius: 14px; padding: 0.85rem 1rem;
  position: relative;
}
.rv-card--3 {
  background: rgba(255,255,255,.06);
  border: 1px solid rgba(255,255,255,.1);
}
.rv-card--2 {
  background: rgba(148,163,184,.1);
  border: 1px solid rgba(148,163,184,.25);
}
.rv-card--1 {
  background: linear-gradient(135deg, rgba(251,191,36,.18) 0%, rgba(217,119,6,.12) 100%);
  border: 2px solid rgba(251,191,36,.7);
  box-shadow: 0 0 40px rgba(251,191,36,.22), inset 0 1px 0 rgba(255,255,255,.08);
  padding: 1rem 1.1rem 1.1rem;
  flex-wrap: wrap; gap: 0.5rem 0.75rem;
}

/* Corona 1er lugar */
.rv-crown {
  width: 100%; text-align: center;
  font-size: 1.6rem; line-height: 1;
  animation: rv-bounce .7s ease-in-out infinite alternate;
  order: -1;
}
@keyframes rv-bounce {
  from { transform: translateY(0) scale(1); }
  to   { transform: translateY(-5px) scale(1.1); }
}

/* Badge */
.rv-badge {
  font-size: 0.7rem; font-weight: 800; white-space: nowrap;
  padding: 0.22rem 0.65rem; border-radius: 20px; flex-shrink: 0;
}
.rv-badge--3 { background: rgba(249,115,22,.2);  color: #fed7aa; }
.rv-badge--2 { background: rgba(148,163,184,.2); color: #cbd5e1; }
.rv-badge--1 { background: rgba(251,191,36,.25); color: #fde68a; font-size: 0.78rem; }

/* Dot de color */
.rv-dot {
  width: 18px; height: 18px; border-radius: 50%; flex-shrink: 0;
  border: 2px solid rgba(255,255,255,.25);
}
.rv-dot--1 { width: 24px; height: 24px; box-shadow: 0 0 10px rgba(251,191,36,.4); }

/* Nombre */
.rv-nombre {
  flex: 1; font-weight: 700; font-size: 0.92rem;
  color: #cbd5e1; white-space: nowrap;
  overflow: hidden; text-overflow: ellipsis; margin: 0;
  min-width: 0;
}
.rv-nombre--1 { font-size: 1.08rem; color: #fef3c7; }

/* Score */
.rv-score { display: flex; align-items: baseline; gap: 0.15rem; flex-shrink: 0; }
.rv-score__n { font-weight: 900; color: #64748b; font-size: 1.25rem; line-height: 1; }
.rv-score--2 .rv-score__n { color: #94a3b8; font-size: 1.35rem; }
.rv-score--1 .rv-score__n {
  color: #fbbf24; font-size: 1.75rem;
  text-shadow: 0 0 20px rgba(251,191,36,.5);
}
.rv-score__u { font-size: 0.68rem; color: #475569; font-weight: 700; }
.rv-score--1 .rv-score__u { color: #fde68a; }

/* Transición de cada tarjeta */
.rv-card-enter-active {
  transition: all .55s cubic-bezier(.34, 1.56, .64, 1);
}
.rv-card-enter-from { opacity: 0; transform: translateY(50px) scale(.88); }

/* Botón continuar */
.rv-btn-ver {
  display: flex; align-items: center; gap: 0.5rem;
  background: #16a34a; color: white; border: none;
  border-radius: 12px; padding: 0.9rem 2.2rem;
  font-size: 0.95rem; font-weight: 700; cursor: pointer;
  box-shadow: 0 4px 24px rgba(22,163,74,.45);
  transition: transform .15s, box-shadow .15s;
  z-index: 1;
}
.rv-btn-ver:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(22,163,74,.5); }

/* ─── Contador de revelación ─── */
.cnt-enter-active { transition: opacity .4s ease; }
.cnt-leave-active { transition: opacity .6s ease; }
.cnt-enter-from, .cnt-leave-to { opacity: 0; }

.cnt-overlay {
  position: fixed;
  inset: 0;
  z-index: 300;
  background: linear-gradient(160deg, #052e16 0%, #14532d 50%, #166534 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
}

.cnt-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  text-align: center;
  max-width: 320px;
  width: 100%;
}

.cnt-label {
  font-size: 0.95rem;
  font-weight: 700;
  color: #bbf7d0;
  letter-spacing: .03em;
  text-transform: uppercase;
  margin: 0;
}

.cnt-num {
  font-size: 7rem;
  font-weight: 900;
  color: #ffffff;
  line-height: 1;
  text-shadow: 0 0 40px rgba(74, 222, 128, 0.6);
  animation: cnt-pulse 1s ease-in-out infinite;
}

@keyframes cnt-pulse {
  0%, 100% { transform: scale(1);   opacity: 1; }
  50%       { transform: scale(1.06); opacity: .9; }
}

.cnt-sub {
  font-size: 0.88rem;
  color: #86efac;
  margin: 0;
  line-height: 1.5;
}

.cnt-barra {
  width: 100%;
  height: 6px;
  background: rgba(255,255,255,.15);
  border-radius: 3px;
  overflow: hidden;
  margin-top: 0.5rem;
}

.cnt-barra__fill {
  height: 100%;
  background: #4ade80;
  border-radius: 3px;
  transition: width 1s linear;
}
</style>
