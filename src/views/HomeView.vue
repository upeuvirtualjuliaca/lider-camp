<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import {
  publicoService,
  type PublicoCampamento,
  type PublicoCalendario,
} from '@/modules/criterios/services/criterios.service'
import {
  rankingDiarioPublicoService,
  rankingTotalPublicoService,
  type PublicoRankingDia,
  type PublicoRankingTotal,
} from '@/modules/puntajes/services/puntajes.service'

// ── Estado ──────────────────────────────────────────────────────────────
const campamento  = ref<PublicoCampamento | null>(null)
const calendario  = ref<PublicoCalendario[]>([])
const datosDias   = ref<PublicoRankingDia[]>([])
const rankingTotal = ref<PublicoRankingTotal[]>([])
const cargando    = ref(true)
const error       = ref('')

// ── Constantes ──────────────────────────────────────────────────────────
const ORDEN_DIAS = ['J', 'V', 'S', 'D'] as const
const LABEL_DIA: Record<string, string> = {
  J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo',
}

// ── Computed: estado del campamento ─────────────────────────────────────
const campFinalizado = computed(() => rankingTotal.value.length > 0)

const diasPublicados = computed(() => {
  const set = new Set(datosDias.value.map((r) => r.momento))
  return ORDEN_DIAS.filter((m) => set.has(m))
})

const diaActual = computed(() => {
  if (campFinalizado.value) return null
  const idx = diasPublicados.value.length
  return idx < ORDEN_DIAS.length ? (ORDEN_DIAS[idx] ?? null) : null
})

const numDia = computed(() =>
  Math.min(diasPublicados.value.length + 1, 4),
)

// ── Computed: criterios de hoy ───────────────────────────────────────────
const criteriosHoy = computed(() => {
  if (!diaActual.value) return []
  return calendario.value
    .filter((c) => c.momento === diaActual.value && c.estado !== 'cancelado' && c.estado !== 'na')
    .sort((a, b) => a.orden - b.orden)
    .map((c) => c.nombre)
})

// ── Computed: Top 3 (último día publicado) ───────────────────────────────
const ultimoDia = computed(() =>
  diasPublicados.value.length ? diasPublicados.value[diasPublicados.value.length - 1] : null,
)

const top3 = computed<PublicoRankingDia[]>(() => {
  if (!ultimoDia.value) return []
  return datosDias.value
    .filter((r) => r.momento === ultimoDia.value)
    .sort((a, b) => a.posicion - b.posicion)
    .slice(0, 3)
})

// ── Helpers visuales ────────────────────────────────────────────────────
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

// ── Carga ────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [camp, dias, total] = await Promise.all([
      publicoService.getCampamentoActivo(),
      rankingDiarioPublicoService.getAll(),
      rankingTotalPublicoService.getAll(),
    ])
    campamento.value  = camp
    datosDias.value   = dias
    rankingTotal.value = total

    if (camp?.id) {
      calendario.value = await publicoService.getCalendarioCampamento(camp.id)
    }
  } catch (e: any) {
    error.value = e?.message ?? 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
})

// ── Datos estáticos ──────────────────────────────────────────────────────
const pasos = [
  {
    n: '1',
    titulo: 'Criterios diarios',
    texto: 'Carpas, orden, cocina, ceremonias y más, con una rúbrica de 5 niveles.',
  },
  {
    n: '2',
    titulo: 'Liderazgo y asistencia',
    texto: 'Cuatro indicadores de liderazgo por día y meta del 95 % de asistencia.',
  },
  {
    n: '3',
    titulo: 'Bonus y deméritos',
    texto: 'El servicio extraordinario suma; el ruido o el uso de recursos ajenos restan.',
  },
  {
    n: '4',
    titulo: 'Ranking y medallas',
    texto: 'El puntaje se convierte a escala de 1000 y define la medalla al cierre.',
  },
]

function scrollToHoy() {
  document.querySelector('#hoy')?.scrollIntoView({ behavior: 'smooth' })
}

const medallas = [
  { nombre: 'Oro',           bg: '#F6E3A3', ring: '#C99A1E' },
  { nombre: 'Plata',         bg: '#E6E9EC', ring: '#9AA3AB' },
  { nombre: 'Bronce',        bg: '#F1D2B8', ring: '#B06A35' },
  { nombre: 'Participación', bg: '#E1F3EA', ring: '#5FAF8A' },
]
</script>

<template>
  <div>

    <!-- ══════════════════════════════════════════════════════════
         HERO
    ══════════════════════════════════════════════════════════ -->
    <section class="hero relative overflow-hidden" style="background:#10261D;min-height:min(560px,90dvh)">
      <!-- Video de fondo -->
      <video
        class="absolute inset-0 w-full h-full object-cover pointer-events-none z-0"
        :src="'/lider-camp/videos/hero.mp4'"
        autoplay muted loop playsinline
      />
      <!-- Overlay negro ~55% -->
      <div class="absolute inset-0 z-[1]" style="background:rgba(0,0,0,0.55)" />

      <!-- Contenido -->
      <div class="relative z-[2] max-w-[760px] mx-auto px-5 md:px-8 py-14 md:py-20 flex flex-col gap-4">

        <!-- Pill estado -->
        <span
          v-if="!cargando && campamento"
          class="self-start flex items-center gap-2 h-7 px-3 rounded-[14px] text-xs font-semibold text-white"
          style="background:rgba(255,255,255,0.12)"
        >
          <span
            class="w-[7px] h-[7px] rounded-full flex-shrink-0"
            :style="{ background: campFinalizado ? '#9AA3AB' : '#4CD08F' }"
            aria-hidden="true"
          />
          <template v-if="campFinalizado">Finalizado</template>
          <template v-else>En curso · Día {{ numDia }} de 4</template>
        </span>

        <!-- Edición -->
        <span
          v-if="campamento?.edicion"
          class="text-xs font-bold tracking-[1.2px] uppercase"
          style="color:#F2C14E"
        >Edición {{ campamento.edicion }}</span>

        <!-- Título -->
        <h1 class="m-0 font-extrabold text-white leading-tight"
          style="font-size:clamp(2rem,6vw,3.2rem);letter-spacing:-0.03em">
          Creados para grandes hazañas
        </h1>

        <!-- Subtítulo -->
        <p class="m-0 text-base leading-relaxed" style="color:rgba(255,255,255,0.85)">
          Sigue en vivo el desempeño de tu escuela y el ranking oficial del campamento.
        </p>

        <!-- Acciones -->
        <div class="flex flex-col sm:flex-row gap-3 mt-2">
          <RouterLink
            to="/ranking"
            class="h-[52px] px-6 rounded-[14px] flex items-center justify-center gap-2 text-base font-bold no-underline transition-transform hover:-translate-y-0.5"
            style="background:#FFFFFF;color:#0B6B4B"
          >Ver ranking</RouterLink>
          <a
            href="#hoy"
            class="h-[50px] px-6 rounded-[14px] flex items-center justify-center text-[15px] font-semibold no-underline transition-colors"
            style="border:1px solid rgba(255,255,255,0.4);color:#FFFFFF;background:transparent"
            @click.prevent="scrollToHoy"
          >¿Qué se evalúa hoy?</a>
        </div>

      </div>
    </section>

    <!-- ══════════════════════════════════════════════════════════
         TOP 3
    ══════════════════════════════════════════════════════════ -->
    <section class="px-4 md:px-6 py-5 -mt-1">
      <div class="max-w-[960px] mx-auto">
        <div
          class="bg-white border border-[#E3E7E4] rounded-[18px] p-4 flex flex-col gap-3"
          style="box-shadow:0 4px 16px rgba(22,32,27,0.06)"
        >
          <!-- Cabecera -->
          <div class="flex justify-between items-baseline">
            <span class="text-[15px] font-bold text-[#16201B]">Top 3</span>
            <span v-if="ultimoDia" class="text-xs text-[#5B6660]">
              Hasta el {{ LABEL_DIA[ultimoDia] }}
            </span>
          </div>

          <!-- Cargando -->
          <template v-if="cargando">
            <div v-for="i in 3" :key="i" class="h-10 rounded-xl bg-[#F4F6F4] animate-pulse" />
          </template>

          <!-- Sin datos -->
          <div v-else-if="!top3.length" class="py-4 text-center text-sm text-[#5B6660]">
            Los puntajes se mostrarán cuando finalice el primer día.
          </div>

          <!-- Filas top 3 -->
          <template v-else>
            <div
              v-for="eq in top3" :key="eq.equipo_id"
              class="flex items-center gap-3"
            >
              <span
                class="w-7 text-[15px] font-extrabold flex-shrink-0"
                :style="{ color: eq.posicion === 1 ? '#0B6B4B' : '#5B6660' }"
              >{{ eq.posicion }}°</span>
              <span
                class="w-9 h-9 rounded-[10px] flex items-center justify-center text-xs font-bold text-white flex-shrink-0"
                :style="{ background: eq.equipo_color ?? '#5B6660' }"
                aria-hidden="true"
              >{{ siglas(eq.equipo_nombre) }}</span>
              <span class="flex-1 text-sm font-semibold text-[#16201B]">{{ eq.equipo_nombre }}</span>
              <span class="text-base font-extrabold text-[#16201B]">{{ eq.pts_total }}</span>
            </div>
          </template>

          <!-- Ver todas -->
          <RouterLink
            to="/ranking"
            class="h-11 rounded-[12px] flex items-center justify-center text-sm font-semibold no-underline mt-1"
            style="background:#F4F6F4;color:#0B6B4B"
          >Ver las 12 escuelas</RouterLink>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════════════════════
         ESTO SE EVALÚA HOY
    ══════════════════════════════════════════════════════════ -->
    <section
      v-if="!campFinalizado && (cargando || campamento)"
      id="hoy"
      class="px-4 md:px-6 py-6 flex flex-col gap-3 max-w-[960px] mx-auto w-full"
    >
      <!-- Label día -->
      <span
        v-if="diaActual"
        class="text-xs font-bold tracking-[0.6px] uppercase"
        style="color:#0B6B4B"
      >Hoy · {{ LABEL_DIA[diaActual] }}</span>

      <h2 class="m-0 text-2xl font-extrabold text-[#16201B]" style="letter-spacing:-0.5px">
        Esto se evalúa hoy
      </h2>

      <!-- Chips criterios -->
      <div v-if="cargando" class="flex flex-wrap gap-2">
        <div v-for="i in 6" :key="i" class="h-9 w-24 rounded-[17px] bg-[#E3E7E4] animate-pulse" />
      </div>
      <div v-else-if="criteriosHoy.length" class="flex flex-wrap gap-2">
        <span
          v-for="c in criteriosHoy" :key="c"
          class="h-[34px] px-3 rounded-[17px] border border-[#E3E7E4] flex items-center text-[13px] font-medium text-[#16201B]"
          style="background:#F4F6F4"
        >{{ c }}</span>
      </div>
      <p v-else class="text-sm text-[#5B6660] m-0">Sin criterios programados para hoy.</p>

      <!-- Link calendario -->
      <RouterLink
        to="/calendario"
        class="text-sm font-semibold no-underline self-start"
        style="color:#0B6B4B"
      >Ver calendario completo →</RouterLink>
    </section>

    <!-- ══════════════════════════════════════════════════════════
         ¿CÓMO SE GANA LIDERCAMP?
    ══════════════════════════════════════════════════════════ -->
    <section class="px-4 md:px-6 py-8 flex flex-col gap-4" style="background:#F4F6F4">
      <div class="max-w-[960px] mx-auto w-full flex flex-col gap-4">
        <h2 class="m-0 text-2xl font-extrabold text-[#16201B]" style="letter-spacing:-0.5px">
          ¿Cómo se gana LiderCamp?
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div
            v-for="p in pasos" :key="p.n"
            class="bg-white border border-[#E3E7E4] rounded-[16px] p-4 flex gap-3.5"
          >
            <span
              class="w-9 h-9 flex-shrink-0 rounded-[10px] flex items-center justify-center text-sm font-extrabold"
              style="background:#E1F3EA;color:#0B6B4B"
            >{{ p.n }}</span>
            <div class="flex flex-col gap-1">
              <span class="text-base font-bold text-[#16201B]">{{ p.titulo }}</span>
              <span class="text-sm leading-relaxed text-[#5B6660]">{{ p.texto }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════════════════════
         MEDALLAS AL CIERRE
    ══════════════════════════════════════════════════════════ -->
    <section class="px-4 md:px-6 py-8 flex flex-col gap-3 max-w-[960px] mx-auto w-full">
      <h2 class="m-0 text-[22px] font-extrabold text-[#16201B]">Medallas al cierre</h2>
      <div class="grid grid-cols-2 gap-2.5">
        <div
          v-for="m in medallas" :key="m.nombre"
          class="border border-[#E3E7E4] rounded-[14px] p-3 flex items-center gap-2.5"
        >
          <span
            class="w-8 h-8 rounded-full flex-shrink-0"
            :style="{ background: m.bg, border: `3px solid ${m.ring}`, boxSizing: 'border-box' }"
            aria-hidden="true"
          />
          <span class="text-sm font-bold text-[#16201B]">{{ m.nombre }}</span>
        </div>
      </div>
      <RouterLink
        to="/reglas"
        class="h-12 rounded-[12px] border border-[#DCE1DD] flex items-center justify-center text-[15px] font-semibold no-underline text-[#16201B] mt-1"
      >Leer las reglas</RouterLink>
    </section>

    <!-- ══════════════════════════════════════════════════════════
         CTA ADMIN/EVALUADOR
    ══════════════════════════════════════════════════════════ -->
    <section class="border-t border-[#E3E7E4] px-4 md:px-6 py-6 flex flex-col gap-3 max-w-[960px] mx-auto w-full">
      <span class="text-[15px] font-bold text-[#16201B]">¿Eres evaluador o administrador?</span>
      <RouterLink
        to="/login"
        class="h-12 rounded-[12px] flex items-center justify-center text-[15px] font-semibold no-underline text-white"
        style="background:#0E7C59"
      >Ingresar al panel</RouterLink>
    </section>

  </div>
</template>
