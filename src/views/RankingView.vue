<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import {
  rankingDiarioPublicoService, type PublicoRankingDia,
  rankingTotalPublicoService,  type PublicoRankingTotal,
} from '@/modules/puntajes/services/puntajes.service'
import { publicoService, type PublicoCalendario } from '@/modules/criterios/services/criterios.service'

const router    = useRouter()
const route     = useRoute()
const cargando  = ref(true)
const error     = ref('')
const modalOpen   = ref(false)
const ultimaAct   = ref<Date | null>(null)
const tabActivo   = ref<'total' | string>('total')
const enConteo    = ref(false)
const segundos    = ref(0)

const datosDias    = ref<PublicoRankingDia[]>([])
const rankingTotal = ref<PublicoRankingTotal[]>([])
const calendario   = ref<PublicoCalendario[]>([])

// ── Tabs ──────────────────────────────────────────────────────────────────────
const ORDEN_DIAS = ['J', 'V', 'S', 'D']
const LABEL_DIA: Record<string, string> = {
  J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo',
}
const LABEL_DIA_CORTO: Record<string, string> = {
  J: 'jueves', V: 'viernes', S: 'sábado', D: 'domingo',
}

const totalGeneral = computed(() =>
  calendario.value
    .filter((c) => c.estado !== 'cancelado' && c.estado !== 'na')
    .reduce((sum, c) => sum + (c.puntaje_max ?? 0), 0),
)

const totalDiaActual = computed(() => {
  if (tabActivo.value === 'total') return 0
  return calendario.value
    .filter((c) => c.momento === tabActivo.value && c.estado !== 'cancelado' && c.estado !== 'na')
    .reduce((sum, c) => sum + (c.puntaje_max ?? 0), 0)
})

const diasConDatos = computed(() => {
  const set = new Set(datosDias.value.map((r) => r.momento))
  return ORDEN_DIAS.filter((m) => set.has(m))
})

const tabs = computed(() => [
  { key: 'total', label: 'Total' },
  ...diasConDatos.value.map((m) => ({ key: m, label: LABEL_DIA[m] ?? m })),
])

const ultimoDia = computed(() =>
  diasConDatos.value.length ? diasConDatos.value[diasConDatos.value.length - 1] : null,
)

const subtitulo = computed(() => {
  if (!ultimaAct.value) return ''
  const hora = ultimaAct.value.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })
  if (!ultimoDia.value) return `Actualizado ${hora}`
  return `Publicado hasta el ${LABEL_DIA_CORTO[ultimoDia.value] ?? ultimoDia.value} · actualizado ${hora}`
})

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

const top3 = computed(() => ({
  primero: rankingDia.value.find((r) => r.posicion === 1) ?? null,
  segundo: rankingDia.value.find((r) => r.posicion === 2) ?? null,
  tercero: rankingDia.value.find((r) => r.posicion === 3) ?? null,
}))

const top3Total = computed(() => ({
  primero: rankingTotal.value.find((r) => r.posicion === 1) ?? null,
  segundo: rankingTotal.value.find((r) => r.posicion === 2) ?? null,
  tercero: rankingTotal.value.find((r) => r.posicion === 3) ?? null,
}))

// ── Helpers ───────────────────────────────────────────────────────────────────
function posLabelDia(r: FilaRanking): string {
  const count = rankingDia.value.filter((x) => x.posicion === r.posicion).length
  return r.posicion + '°' + (count > 1 ? ' =' : '')
}
function posLabelTotal(r: PublicoRankingTotal): string {
  const count = rankingTotal.value.filter((x) => x.posicion === r.posicion).length
  return r.posicion + '°' + (count > 1 ? ' =' : '')
}
function posColor(pos: number): string {
  return pos <= 3 ? '#16201B' : '#5B6660'
}
function siglas(nombre: string): string {
  const stop = new Set(['de', 'del', 'la', 'las', 'los', 'el', 'y', 'e', 'o', 'en'])
  const letters = nombre
    .split(/[\s.,()]+/)
    .filter((w) => w.length > 1 && !stop.has(w.toLowerCase()))
    .map((w) => w[0]!.toUpperCase())
  if (letters.length >= 2) return letters.slice(0, 3).join('')
  if (letters.length === 1) return letters[0] + nombre.replace(/[^A-Za-záéíóú]/gi, '').slice(1, 2).toUpperCase()
  return nombre.replace(/[^A-Za-záéíóú]/gi, '').slice(0, 2).toUpperCase()
}

const MEDALLA_BADGE: Record<string, { bg: string; color: string; text: string }> = {
  oro:           { bg: '#F6E3A3', color: '#6B4E0A', text: 'Oro' },
  plata:         { bg: '#E6E9EC', color: '#3A4540', text: 'Plata' },
  bronce:        { bg: '#F1D2B8', color: '#6B3A1F', text: 'Bronce' },
  participacion: { bg: '#E1F3EA', color: '#0B6B4B', text: 'Participación' },
}
const MEDALLA_EMOJI: Record<string, string> = {
  oro: '🥇', plata: '🥈', bronce: '🥉', participacion: '🎖',
}
const MEDALLA_RANGO: Record<string, string> = {
  oro: 'Mayor puntaje', plata: '2° y 3° lugar', bronce: 'Resto del podio', participacion: 'Todos los demás',
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
    const campamentoId = dias[0]?.campamento_id ?? total[0]?.campamento_id ?? null
    if (campamentoId) {
      calendario.value = await publicoService.getCalendarioCampamento(campamentoId)
    }
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
const revelaEtapa    = ref(0)
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
  const steps = 60; const ms = 1800 / steps; let step = 0
  const iv = setInterval(() => {
    step++
    cuentaScore.value[key] = Math.round(target * Math.min(step / steps, 1))
    if (step >= steps) { cuentaScore.value[key] = target; clearInterval(iv) }
  }, ms)
}
function saltarRevela() {
  enRevela.value = false; confettiActivo.value = false; revelaEtapa.value = 0
}
function iniciarRevelacion() {
  cuentaScore.value = { p: 0, s: 0, t: 0 }; revelaEtapa.value = 0; enRevela.value = true
  setTimeout(() => { revelaEtapa.value = 1; animarScore('t', top3Total.value.tercero?.pts_bruto ?? 0) }, 800)
  setTimeout(() => { revelaEtapa.value = 2; animarScore('s', top3Total.value.segundo?.pts_bruto ?? 0) }, 3600)
  setTimeout(() => { revelaEtapa.value = 3; confettiActivo.value = true; animarScore('p', top3Total.value.primero?.pts_bruto ?? 0) }, 6400)
  setTimeout(() => { revelaEtapa.value = 4 }, 9000)
}
</script>

<template>
  <div class="min-h-screen" style="background:#F4F6F4">

    <!-- ── Contador de revelación ────────────────────────────────────────── -->
    <Transition name="cnt">
      <div v-if="enConteo" class="cnt-overlay">
        <div class="cnt-box">
          <p class="cnt-label">Revelando resultados finales en</p>
          <div class="cnt-num">{{ segundos }}</div>
          <p class="cnt-sub">¡Prepárense para ver el ranking final!</p>
          <div class="cnt-barra"><div class="cnt-barra__fill" :style="{ width: (1 - segundos / 60) * 100 + '%' }" /></div>
        </div>
      </div>
    </Transition>

    <!-- ── Revelación de resultados finales ──────────────────────────────── -->
    <Transition name="rv">
      <div v-if="enRevela" class="rv-overlay">
        <div v-if="confettiActivo" class="rv-confetti" aria-hidden="true">
          <div
            v-for="p in confettiPiezas" :key="p.id" class="rv-pieza"
            :style="{ left: p.left, background: p.color, width: p.size, height: p.size, borderRadius: p.round ? '50%' : '3px', animationDelay: p.delay, animationDuration: p.duration }"
          />
        </div>
        <button class="rv-skip" @click="saltarRevela">Saltar <i class="pi pi-angle-double-right" /></button>
        <div class="rv-head">
          <p class="rv-titulo">Resultados Finales</p>
          <p class="rv-sub">LiderCamp 2026-II</p>
        </div>
        <div class="rv-podio">
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 1 && top3Total.tercero" class="rv-card rv-card--3">
              <div class="rv-badge rv-badge--3">🥉 3er Puesto</div>
              <span class="rv-dot" :style="{ background: top3Total.tercero.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre">{{ top3Total.tercero.equipo_nombre }}</p>
              <div class="rv-score rv-score--3"><span class="rv-score__n">{{ cuentaScore.t }}</span><span class="rv-score__u">pts</span></div>
            </div>
          </Transition>
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 2 && top3Total.segundo" class="rv-card rv-card--2">
              <div class="rv-badge rv-badge--2">🥈 2° Puesto</div>
              <span class="rv-dot" :style="{ background: top3Total.segundo.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre">{{ top3Total.segundo.equipo_nombre }}</p>
              <div class="rv-score rv-score--2"><span class="rv-score__n">{{ cuentaScore.s }}</span><span class="rv-score__u">pts</span></div>
            </div>
          </Transition>
          <Transition name="rv-card">
            <div v-if="revelaEtapa >= 3 && top3Total.primero" class="rv-card rv-card--1">
              <div class="rv-crown">👑</div>
              <div class="rv-badge rv-badge--1">🥇 Primer Puesto</div>
              <span class="rv-dot rv-dot--1" :style="{ background: top3Total.primero.equipo_color ?? '#6b7280' }" />
              <p class="rv-nombre rv-nombre--1">{{ top3Total.primero.equipo_nombre }}</p>
              <div class="rv-score rv-score--1"><span class="rv-score__n">{{ cuentaScore.p }}</span><span class="rv-score__u">pts</span></div>
            </div>
          </Transition>
        </div>
        <Transition name="rv-card">
          <button v-if="revelaEtapa >= 4" class="rv-btn-ver" @click="saltarRevela">
            Ver ranking completo <i class="pi pi-arrow-right" />
          </button>
        </Transition>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════════════════════════
         CONTENIDO PRINCIPAL
    ══════════════════════════════════════════════════════════ -->
    <main class="max-w-[960px] mx-auto px-4 md:px-6 py-6 md:py-8 flex flex-col gap-5">

      <!-- Cabecera -->
      <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div class="flex flex-col gap-1.5">
          <h1 class="m-0 text-[26px] md:text-[32px] font-extrabold text-[#16201B]"
            style="letter-spacing:-0.8px">Ranking oficial</h1>
          <span v-if="subtitulo" class="text-sm text-[#5B6660]">{{ subtitulo }}</span>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <!-- Segmented tabs -->
          <div role="tablist" aria-label="Periodo" class="flex p-1 rounded-[12px]" style="background:#E9EDEA">
            <button
              v-for="tab in tabs" :key="tab.key"
              role="tab" :aria-selected="tabActivo === tab.key"
              class="h-[38px] px-3.5 md:px-[18px] rounded-[9px] border-0 font-[inherit] text-sm cursor-pointer transition-all"
              :style="tabActivo === tab.key
                ? 'background:#FFFFFF;color:#16201B;font-weight:700;box-shadow:0 1px 2px rgba(22,32,27,0.12)'
                : 'background:transparent;color:#5B6660;font-weight:500'"
              @click="tabActivo = tab.key"
            >{{ tab.label }}</button>
          </div>
          <!-- Actualizar -->
          <button
            class="w-11 h-11 rounded-full border border-[#E3E7E4] bg-white flex items-center justify-center cursor-pointer transition-colors hover:border-[#0B6B4B] disabled:opacity-50"
            :disabled="cargando" title="Actualizar ranking" @click="cargar"
          >
            <i :class="['pi text-[#5B6660]', cargando ? 'pi-spin pi-spinner' : 'pi-refresh']" style="font-size:18px" />
          </button>
        </div>
      </div>

      <!-- Error -->
      <div v-if="error" class="flex items-center gap-2 bg-red-50 border border-red-200 rounded-[10px] p-3 text-red-700 text-sm">
        <i class="pi pi-exclamation-triangle flex-shrink-0" />{{ error }}
      </div>

      <!-- Cargando inicial -->
      <div v-else-if="cargando && !datosDias.length" class="flex flex-col items-center gap-2 py-16 text-[#5B6660] text-sm">
        <i class="pi pi-spin pi-spinner" style="font-size:2.5rem" />
        <span>Cargando ranking…</span>
      </div>

      <template v-else>

        <!-- ══ TAB TOTAL ══════════════════════════════════════════════════ -->
        <template v-if="tabActivo === 'total'">

          <div v-if="enConteo" class="flex flex-col items-center gap-2 py-16 text-[#5B6660] text-sm">
            <i class="pi pi-spin pi-spinner" style="font-size:2.5rem" />
            <span>Los resultados se revelarán en {{ segundos }} segundos…</span>
          </div>

          <!-- Campamento no cerrado -->
          <div
            v-else-if="!rankingTotal.length"
            class="bg-white border border-[#E3E7E4] rounded-[20px] p-6 md:p-8 flex flex-col md:flex-row md:flex-wrap items-center gap-5 md:gap-6"
          >
            <span class="w-16 h-16 rounded-[18px] flex items-center justify-center flex-shrink-0" style="background:#F6E3A3" aria-hidden="true">
              <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="#8A6410" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M8 21h8M12 17v4"/>
                <path d="M7 4h10v5a5 5 0 0 1-10 0V4z"/>
                <path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>
              </svg>
            </span>
            <div class="flex flex-col gap-1.5 flex-1 min-w-[200px] text-center md:text-left">
              <span class="text-lg md:text-[20px] font-extrabold text-[#16201B]">El ganador se revela al cierre</span>
              <span class="text-sm md:text-[15px] leading-relaxed text-[#5B6660]">
                El ranking total y las medallas se publican el domingo al cerrar el campamento. Mientras tanto, mira cómo va tu escuela día a día.
              </span>
            </div>
            <button
              class="h-12 px-5 rounded-[12px] border-0 font-[inherit] text-[15px] font-semibold text-white cursor-pointer flex-shrink-0"
              style="background:#0E7C59"
              @click="tabActivo = diasConDatos.length ? diasConDatos[diasConDatos.length - 1]! : 'total'"
            >Ver {{ diasConDatos.length ? LABEL_DIA[diasConDatos[diasConDatos.length - 1]!] ?? 'último día' : 'primer día' }}</button>
          </div>

          <!-- Ranking total procesado -->
          <template v-else>
            <section aria-label="Podio" class="grid grid-cols-3 gap-2 md:gap-3.5 items-end">
              <!-- 2° lugar (columna izquierda) -->
              <div
                v-if="top3Total.segundo"
                class="bg-white border border-[#E3E7E4] rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-2.5 md:p-4"
              >
                <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#EEF1EF;color:#3A4540">2°</span>
                <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                  :style="{ background: top3Total.segundo.equipo_color ?? '#5B6660' }" aria-hidden="true"
                >{{ siglas(top3Total.segundo.equipo_nombre) }}</span>
                <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3Total.segundo.equipo_nombre }}</span>
                <span class="text-lg md:text-[26px] font-extrabold text-[#16201B]">{{ top3Total.segundo.pts_bruto }}</span>
              </div>
              <!-- 1° lugar (columna central) -->
              <div
                class="bg-white rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-3 md:p-[22px_16px_18px]"
                style="border:1px solid #C99A1E;box-shadow:0 0 0 3px #FBF1D2"
              >
                <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#F6E3A3;color:#6B4E0A">1°</span>
                <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                  :style="{ background: top3Total.primero!.equipo_color ?? '#5B6660' }" aria-hidden="true"
                >{{ siglas(top3Total.primero!.equipo_nombre) }}</span>
                <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3Total.primero!.equipo_nombre }}</span>
                <span class="text-lg md:text-[30px] font-extrabold text-[#16201B]">{{ top3Total.primero!.pts_bruto }}</span>
              </div>
              <!-- 3° lugar (columna derecha) -->
              <div
                v-if="top3Total.tercero"
                class="bg-white border border-[#E3E7E4] rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-2.5 md:p-4"
              >
                <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#EEF1EF;color:#3A4540">3°</span>
                <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                  :style="{ background: top3Total.tercero.equipo_color ?? '#5B6660' }" aria-hidden="true"
                >{{ siglas(top3Total.tercero.equipo_nombre) }}</span>
                <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3Total.tercero.equipo_nombre }}</span>
                <span class="text-lg md:text-[26px] font-extrabold text-[#16201B]">{{ top3Total.tercero.pts_bruto }}</span>
              </div>
            </section>

            <section aria-label="Todas las escuelas" class="bg-white border border-[#E3E7E4] rounded-[20px] overflow-hidden">
              <ol class="list-none m-0 p-0">
                <li v-for="eq in rankingTotal" :key="eq.equipo_id" style="border-bottom:1px solid #EEF1EF">
                  <a href="#" class="flex items-center gap-3 md:gap-3.5 px-4 md:px-5 no-underline"
                    style="min-height:60px"
                    @click.prevent="router.push(`/equipo/${eq.equipo_id}`)">
                    <span class="text-sm md:text-base font-extrabold flex-shrink-0 w-9 md:w-10"
                      :style="{ color: posColor(eq.posicion) }">{{ posLabelTotal(eq) }}</span>
                    <span class="w-8 h-8 md:w-9 md:h-9 rounded-[9px] md:rounded-[10px] flex items-center justify-center font-bold text-[11px] md:text-xs text-white flex-shrink-0"
                      :style="{ background: eq.equipo_color ?? '#5B6660' }" aria-hidden="true"
                    >{{ siglas(eq.equipo_nombre) }}</span>
                    <span class="flex-1 text-sm md:text-[15px] font-semibold text-[#16201B]">{{ eq.equipo_nombre }}</span>
                    <span class="text-base md:text-lg font-extrabold text-[#16201B] flex-shrink-0">{{ eq.pts_bruto }}</span>
                    <span v-if="totalGeneral" class="text-xs text-[#5B6660] hidden md:inline-block w-14 flex-shrink-0">/ {{ totalGeneral }}</span>
                    <svg class="hidden md:block flex-shrink-0" width="16" height="16" viewBox="0 0 24 24" fill="none"
                      stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                      <path d="M9 6l6 6-6 6"/>
                    </svg>
                  </a>
                </li>
              </ol>
            </section>
            <p class="text-xs md:text-[13px] text-[#5B6660] text-center m-0">
              Toca una escuela para ver su ficha. Los empates comparten posición (=). Solo se muestran resultados validados y publicados.
            </p>
          </template>
        </template>

        <!-- ══ SIN DÍAS AÚN ════════════════════════════════════════════════ -->
        <div
          v-else-if="!diasConDatos.length"
          class="flex items-start gap-2.5 rounded-[10px] p-3.5 text-sm"
          style="background:#fffbeb;border:1px solid #fde68a;border-left:4px solid #f59e0b"
        >
          <i class="pi pi-clock text-amber-600 flex-shrink-0 mt-0.5" />
          <div class="flex flex-col gap-0.5">
            <strong class="text-amber-900 text-[15px]">Resultados pendientes</strong>
            <span class="text-amber-700 leading-relaxed">Los puntajes se mostrarán cuando el administrador cierre cada día.</span>
          </div>
        </div>

        <!-- Sin datos para este día -->
        <div v-else-if="!rankingDia.length" class="flex flex-col items-center gap-2 py-16 text-[#5B6660] text-sm">
          <i class="pi pi-calendar-times" style="font-size:2.5rem" />
          <span>Sin datos para este día.</span>
        </div>

        <template v-else>
          <!-- ══ TAB DÍA ════════════════════════════════════════════════════ -->

          <!-- Podio diario -->
          <section v-if="hayResultados && top3.primero" aria-label="Podio" class="grid grid-cols-3 gap-2 md:gap-3.5 items-end">
            <!-- 2° -->
            <div v-if="top3.segundo" class="bg-white border border-[#E3E7E4] rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-2.5 md:p-4">
              <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#EEF1EF;color:#3A4540">{{ posLabelDia(top3.segundo) }}</span>
              <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                :style="{ background: top3.segundo.equipo_color ?? '#5B6660' }" aria-hidden="true"
              >{{ siglas(top3.segundo.equipo_nombre) }}</span>
              <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3.segundo.equipo_nombre }}</span>
              <span class="text-lg md:text-[26px] font-extrabold text-[#16201B]">{{ top3.segundo.pts_total }}</span>
            </div>
            <!-- 1° -->
            <div class="bg-white rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-3 md:p-[22px_16px_18px]"
              style="border:1px solid #C99A1E;box-shadow:0 0 0 3px #FBF1D2">
              <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#F6E3A3;color:#6B4E0A">{{ posLabelDia(top3.primero!) }}</span>
              <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                :style="{ background: top3.primero!.equipo_color ?? '#5B6660' }" aria-hidden="true"
              >{{ siglas(top3.primero!.equipo_nombre) }}</span>
              <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3.primero!.equipo_nombre }}</span>
              <span class="text-lg md:text-[30px] font-extrabold text-[#16201B]">{{ top3.primero!.pts_total }}</span>
            </div>
            <!-- 3° -->
            <div v-if="top3.tercero" class="bg-white border border-[#E3E7E4] rounded-[16px] md:rounded-[20px] flex flex-col items-center gap-1.5 md:gap-2.5 p-2.5 md:p-4">
              <span class="text-xs font-bold px-2 py-0.5 rounded-[12px]" style="background:#EEF1EF;color:#3A4540">{{ posLabelDia(top3.tercero) }}</span>
              <span class="w-10 h-10 md:w-14 md:h-14 rounded-[12px] md:rounded-[16px] flex items-center justify-center font-extrabold text-sm md:text-lg text-white"
                :style="{ background: top3.tercero.equipo_color ?? '#5B6660' }" aria-hidden="true"
              >{{ siglas(top3.tercero.equipo_nombre) }}</span>
              <span class="text-xs md:text-base font-semibold text-center text-[#16201B] leading-snug">{{ top3.tercero.equipo_nombre }}</span>
              <span class="text-lg md:text-[26px] font-extrabold text-[#16201B]">{{ top3.tercero.pts_total }}</span>
            </div>
          </section>

          <!-- Lista completa diaria -->
          <section aria-label="Todas las escuelas" class="bg-white border border-[#E3E7E4] rounded-[16px] md:rounded-[20px] overflow-hidden">
            <ol class="list-none m-0 p-0">
              <li v-for="eq in rankingDia" :key="eq.equipo_id" style="border-bottom:1px solid #EEF1EF">
                <a href="#" class="flex items-center gap-3 md:gap-3.5 px-3.5 md:px-5 no-underline"
                  style="min-height:56px"
                  @click.prevent="router.push(`/equipo/${eq.equipo_id}?dia=${tabActivo}`)">
                  <span class="text-sm md:text-base font-extrabold flex-shrink-0 w-9 md:w-10"
                    :style="{ color: posColor(eq.posicion) }">{{ posLabelDia(eq) }}</span>
                  <span class="w-8 h-8 md:w-9 md:h-9 rounded-[9px] md:rounded-[10px] flex items-center justify-center font-bold text-[11px] md:text-xs text-white flex-shrink-0"
                    :style="{ background: eq.equipo_color ?? '#5B6660' }" aria-hidden="true"
                  >{{ siglas(eq.equipo_nombre) }}</span>
                  <span class="flex-1 text-[14px] md:text-[15px] font-semibold text-[#16201B]">{{ eq.equipo_nombre }}</span>
                  <span class="text-base md:text-lg font-extrabold text-[#16201B] flex-shrink-0">{{ eq.pts_total }}</span>
                  <span v-if="totalDiaActual" class="text-xs text-[#5B6660] hidden md:inline-block w-14 flex-shrink-0">/ {{ totalDiaActual }}</span>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                    stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                    class="flex-shrink-0" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
                </a>
              </li>
            </ol>
          </section>
          <p class="text-xs md:text-[12px] text-[#5B6660] text-center m-0">
            Puntos sobre {{ totalDiaActual || '…' }}. Los empates comparten posición (=).
          </p>
        </template>

        <!-- Botón ayuda -->
        <div class="flex justify-center pt-1">
          <button
            class="flex items-center gap-1.5 text-sm text-[#5B6660] bg-transparent border-0 cursor-pointer hover:text-[#0B6B4B] transition-colors p-1"
            @click="modalOpen = true"
          >
            <i class="pi pi-question-circle text-sm" />
            ¿Cómo funciona el ranking?
          </button>
        </div>

      </template>
    </main>

    <!-- ── Modal ¿Cómo funciona? ──────────────────────────────────────────── -->
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
              <button class="m-close" @click="modalOpen = false"><i class="pi pi-times" /></button>
            </div>
            <div class="m-body">
              <p class="m-intro">
                El puntaje de cada equipo se calcula a partir de varios componentes evaluados durante los 4 días del campamento (J, V, S, D).
              </p>
              <div class="m-pasos">
                <div class="m-paso">
                  <div class="m-paso__n">1</div>
                  <div><p class="m-paso__t">Puntaje base</p><p class="m-paso__d">Inscripción + Rúbrica de observaciones diarias + Liderazgo + Asistencia a eventos.</p></div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n">2</div>
                  <div><p class="m-paso__t">Bonus y deméritos</p><p class="m-paso__d">Se suman los bonus validados (B1/B2, máx. 200 pts) y se restan los deméritos aplicados (D1–D6, sin tope).</p></div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n m-paso__n--ok">3</div>
                  <div><p class="m-paso__t">Escala 1000</p><p class="m-paso__d">El puntaje bruto se convierte a una escala de 0 a 1000 para comparar equipos de manera justa.</p></div>
                </div>
              </div>
              <div class="m-medallas">
                <p class="m-medallas__tit">Medallas</p>
                <div v-for="(badge, key) in MEDALLA_BADGE" :key="key" class="m-medalla-fila">
                  <span class="m-medalla-emoji">{{ MEDALLA_EMOJI[key] }}</span>
                  <span class="m-medalla-badge" :style="{ background: badge.bg, color: badge.color }">{{ badge.text }}</span>
                  <span class="m-medalla-rango">{{ MEDALLA_RANGO[key] }}</span>
                </div>
              </div>
              <div class="m-nota"><i class="pi pi-clock" /> Los resultados se publican por día a medida que el administrador los activa.</div>
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
.rv-confetti { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
.rv-pieza { position: absolute; top: -14px; animation: rv-fall linear forwards; }
@keyframes rv-fall {
  0%   { transform: translateY(0) rotate(0deg); opacity: 1; }
  85%  { opacity: 1; }
  100% { transform: translateY(108vh) rotate(600deg); opacity: 0; }
}
.rv-skip {
  position: absolute; top: 1rem; right: 1rem;
  background: rgba(255,255,255,.08); border: 1px solid rgba(255,255,255,.18);
  color: #94a3b8; border-radius: 8px;
  padding: .4rem .9rem; font-size: .78rem; font-weight: 600;
  cursor: pointer; display: flex; align-items: center; gap: .35rem;
  transition: background .15s; z-index: 1;
}
.rv-skip:hover { background: rgba(255,255,255,.15); }
.rv-head { text-align: center; z-index: 1; }
.rv-titulo { font-size: 1.55rem; font-weight: 900; color: #f1f5f9; margin: 0; letter-spacing: .01em; }
.rv-sub { font-size: .82rem; color: #64748b; margin: .2rem 0 0; text-transform: uppercase; letter-spacing: .08em; }
.rv-podio { width: 100%; max-width: 400px; display: flex; flex-direction: column; gap: .65rem; z-index: 1; }
.rv-card { display: flex; align-items: center; gap: .75rem; border-radius: 14px; padding: .85rem 1rem; position: relative; }
.rv-card--3 { background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.1); }
.rv-card--2 { background: rgba(148,163,184,.1); border: 1px solid rgba(148,163,184,.25); }
.rv-card--1 { background: linear-gradient(135deg, rgba(251,191,36,.18) 0%, rgba(217,119,6,.12) 100%); border: 2px solid rgba(251,191,36,.7); box-shadow: 0 0 40px rgba(251,191,36,.22), inset 0 1px 0 rgba(255,255,255,.08); padding: 1rem 1.1rem 1.1rem; flex-wrap: wrap; gap: .5rem .75rem; }
.rv-crown { width: 100%; text-align: center; font-size: 1.6rem; line-height: 1; animation: rv-bounce .7s ease-in-out infinite alternate; order: -1; }
@keyframes rv-bounce { from { transform: translateY(0) scale(1); } to { transform: translateY(-5px) scale(1.1); } }
.rv-badge { font-size: .7rem; font-weight: 800; white-space: nowrap; padding: .22rem .65rem; border-radius: 20px; flex-shrink: 0; }
.rv-badge--3 { background: rgba(249,115,22,.2); color: #fed7aa; }
.rv-badge--2 { background: rgba(148,163,184,.2); color: #cbd5e1; }
.rv-badge--1 { background: rgba(251,191,36,.25); color: #fde68a; font-size: .78rem; }
.rv-dot { width: 18px; height: 18px; border-radius: 50%; flex-shrink: 0; border: 2px solid rgba(255,255,255,.25); }
.rv-dot--1 { width: 24px; height: 24px; box-shadow: 0 0 10px rgba(251,191,36,.4); }
.rv-nombre { flex: 1; font-weight: 700; font-size: .92rem; color: #cbd5e1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin: 0; min-width: 0; }
.rv-nombre--1 { font-size: 1.08rem; color: #fef3c7; }
.rv-score { display: flex; align-items: baseline; gap: .15rem; flex-shrink: 0; }
.rv-score__n { font-weight: 900; color: #64748b; font-size: 1.25rem; line-height: 1; }
.rv-score--2 .rv-score__n { color: #94a3b8; font-size: 1.35rem; }
.rv-score--1 .rv-score__n { color: #fbbf24; font-size: 1.75rem; text-shadow: 0 0 20px rgba(251,191,36,.5); }
.rv-score__u { font-size: .68rem; color: #475569; font-weight: 700; }
.rv-score--1 .rv-score__u { color: #fde68a; }
.rv-card-enter-active { transition: all .55s cubic-bezier(.34, 1.56, .64, 1); }
.rv-card-enter-from { opacity: 0; transform: translateY(50px) scale(.88); }
.rv-btn-ver { display: flex; align-items: center; gap: .5rem; background: #16a34a; color: white; border: none; border-radius: 12px; padding: .9rem 2.2rem; font-size: .95rem; font-weight: 700; cursor: pointer; box-shadow: 0 4px 24px rgba(22,163,74,.45); transition: transform .15s, box-shadow .15s; z-index: 1; }
.rv-btn-ver:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(22,163,74,.5); }

/* ══════════════════════════════════════════════════════
   CONTADOR DE REVELACIÓN
══════════════════════════════════════════════════════ */
.cnt-enter-active { transition: opacity .4s ease; }
.cnt-leave-active { transition: opacity .6s ease; }
.cnt-enter-from, .cnt-leave-to { opacity: 0; }
.cnt-overlay { position: fixed; inset: 0; z-index: 300; background: linear-gradient(160deg, #052e16 0%, #14532d 50%, #166534 100%); display: flex; align-items: center; justify-content: center; padding: 1.5rem; }
.cnt-box { display: flex; flex-direction: column; align-items: center; gap: 1rem; text-align: center; max-width: 320px; width: 100%; }
.cnt-label { font-size: .95rem; font-weight: 700; color: #bbf7d0; letter-spacing: .03em; text-transform: uppercase; margin: 0; }
.cnt-num { font-size: 7rem; font-weight: 900; color: #fff; line-height: 1; text-shadow: 0 0 40px rgba(74,222,128,.6); animation: cnt-pulse 1s ease-in-out infinite; }
@keyframes cnt-pulse { 0%, 100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.06); opacity: .9; } }
.cnt-sub { font-size: .88rem; color: #86efac; margin: 0; line-height: 1.5; }
.cnt-barra { width: 100%; height: 6px; background: rgba(255,255,255,.15); border-radius: 3px; overflow: hidden; margin-top: .5rem; }
.cnt-barra__fill { height: 100%; background: #4ade80; border-radius: 3px; transition: width 1s linear; }

/* ══════════════════════════════════════════════════════
   MODAL
══════════════════════════════════════════════════════ */
.m-ea-enter-active, .m-ea-leave-active { transition: opacity .2s ease; }
.m-ea-enter-from, .m-ea-leave-to { opacity: 0; }
.m-overlay { position: fixed; inset: 0; z-index: 200; display: flex; align-items: flex-end; justify-content: center; }
@media (min-width: 640px) { .m-overlay { align-items: center; padding: 1rem; } }
.m-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,.4); backdrop-filter: blur(4px); }
.m-panel { position: relative; width: 100%; max-width: 480px; background: white; border-radius: 20px 20px 0 0; box-shadow: 0 20px 60px rgba(0,0,0,.25); display: flex; flex-direction: column; overflow: hidden; max-height: 90dvh; }
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }
.m-drag { width: 36px; height: 4px; border-radius: 2px; background: #e5e7eb; margin: .65rem auto 0; flex-shrink: 0; }
@media (min-width: 640px) { .m-drag { display: none; } }
.m-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem .85rem; border-bottom: 1px solid #f1f5f9; flex-shrink: 0; }
.m-head__left { display: flex; align-items: center; gap: .6rem; }
.m-icon { width: 32px; height: 32px; border-radius: 50%; background: #dcfce7; color: #16a34a; display: flex; align-items: center; justify-content: center; font-size: .88rem; }
.m-title { font-size: 1rem; font-weight: 800; margin: 0; color: #1e293b; }
.m-close { width: 32px; height: 32px; border-radius: 8px; border: none; background: transparent; color: #94a3b8; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .82rem; transition: background .15s; }
.m-close:hover { background: #f1f5f9; }
.m-body { overflow-y: auto; padding: 1.1rem 1.25rem; flex: 1; }
.m-intro { font-size: .88rem; color: #475569; margin: 0 0 1rem; line-height: 1.55; }
.m-pasos { display: flex; flex-direction: column; gap: .75rem; margin-bottom: 1.25rem; }
.m-paso { display: flex; gap: .75rem; align-items: flex-start; }
.m-paso__n { width: 28px; height: 28px; border-radius: 50%; background: #dcfce7; color: #15803d; font-weight: 800; font-size: .78rem; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-top: .05rem; }
.m-paso__n--ok { background: #16a34a; color: white; }
.m-paso__t { font-size: .88rem; font-weight: 700; color: #1e293b; margin: 0 0 .1rem; }
.m-paso__d { font-size: .8rem; color: #64748b; margin: 0; line-height: 1.4; }
.m-medallas { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: .85rem; margin-bottom: 1rem; }
.m-medallas__tit { font-size: .72rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; margin: 0 0 .6rem; }
.m-medalla-fila { display: flex; align-items: center; gap: .5rem; padding: .25rem 0; font-size: .82rem; border-top: 1px solid #f1f5f9; }
.m-medalla-fila:first-of-type { border-top: none; }
.m-medalla-emoji { font-size: 1rem; flex-shrink: 0; }
.m-medalla-badge { font-size: .7rem; font-weight: 700; padding: .15rem .5rem; border-radius: 20px; flex-shrink: 0; }
.m-medalla-rango { font-size: .78rem; color: #6b7280; }
.m-nota { display: flex; align-items: flex-start; gap: .5rem; padding: .7rem .85rem; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; font-size: .78rem; color: #15803d; line-height: 1.45; }
.m-nota i { flex-shrink: 0; margin-top: .1rem; }
.m-foot { padding: .9rem 1.25rem; border-top: 1px solid #f1f5f9; flex-shrink: 0; }
.btn { display: inline-flex; align-items: center; justify-content: center; gap: .35rem; min-height: 44px; padding: .5rem 1.25rem; border-radius: 8px; border: none; font-size: .88rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover { background: #15803d; }
.btn--full { width: 100%; }

/* último li sin border-bottom */
ol li:last-child { border-bottom: none !important; }
</style>
