<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  publicoService,
  type PublicoCalendario,
  type PublicoActividad,
} from '@/modules/criterios/services/criterios.service'
import {
  rankingDiarioPublicoService,
} from '@/modules/puntajes/services/puntajes.service'

// ── Constantes ────────────────────────────────────────────────────────────────
const ORDEN_DIAS = ['J', 'V', 'S', 'D'] as const

const LABEL_DIA: Record<string, string> = {
  J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo',
}
const LABEL_DIA_CORTO: Record<string, string> = {
  J: 'Jue', V: 'Vie', S: 'Sáb', D: 'Dom',
}
const CAT_LABEL: Record<string, string> = {
  inscripcion: 'Inscripción',
  armado: 'Campamento',
  orden_cocina: 'Cocinas',
  ceremonias_participacion: 'Uniformidad',
  liderazgo: 'Movilización y Compromiso',
  vidal: 'Worship',
  lavanderia: 'Barras',
  ginkana: 'Ginkana',
  concurso_los_que_mas_saben: 'Concurso Los que más saben',
  dramas_biblicos: 'Dramas Bíblicos',
  concurso_de_comida: 'Líder Chef',
  horarios: 'Horarios',
}
const CAT_ORDEN: Record<string, number> = {
  inscripcion: 1, armado: 2, orden_cocina: 3, ceremonias_participacion: 4,
  liderazgo: 5, vidal: 6, lavanderia: 7, ginkana: 8,
  concurso_los_que_mas_saben: 9, dramas_biblicos: 10, concurso_de_comida: 11, horarios: 12,
}

// ── Estado ────────────────────────────────────────────────────────────────────
const calendario  = ref<PublicoCalendario[]>([])
const actividades = ref<PublicoActividad[]>([])
const diaActivo   = ref('')
const vistaActiva = ref<'dia' | 'semana'>('dia')
const cargando    = ref(true)
const error       = ref('')

// ── Carga ─────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const cal = await publicoService.getCalendario()
    calendario.value = cal

    const campId = cal[0]?.campamento_id ?? null
    const [diasData, acts] = await Promise.all([
      rankingDiarioPublicoService.getAll(),
      campId ? publicoService.getActividades(campId) : Promise.resolve([]),
    ])
    actividades.value = acts

    // Determinar qué días ya tienen datos publicados
    const publicados = new Set(diasData.map(d => d.momento))
    const idx = ORDEN_DIAS.filter(m => publicados.has(m)).length
    const hoy = idx < ORDEN_DIAS.length ? (ORDEN_DIAS[idx] ?? '') : ''
    diaActivo.value = hoy || diasConCriterios.value[0] || ''
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar el calendario'
  } finally {
    cargando.value = false
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────────
function formatHora(h: string | null): string {
  return h ? h.slice(0, 5) : ''
}

// ── Computed: días con criterios ──────────────────────────────────────────────
const diasConCriterios = computed(() => {
  const conCrit = new Set(
    calendario.value
      .filter(c => c.momento !== 'UNICO' && c.estado !== 'cancelado')
      .map(c => c.momento),
  )
  return ORDEN_DIAS.filter(d => conCrit.has(d))
})

// Día actual = primer día no publicado que tiene criterios
const diaActual = computed(() => {
  return diaActivo.value  // ya calculado en onMounted
})

// ── Computed: vista por día ───────────────────────────────────────────────────
const calendarioDia = computed(() =>
  calendario.value.filter(c => c.momento === diaActivo.value && c.estado !== 'cancelado'),
)

const gruposDia = computed(() => {
  const rubrica = calendarioDia.value.filter(c => c.tipo_calculo === 'rubrica')
  const catMap = new Map<string, string[]>()
  rubrica.forEach(c => {
    if (!catMap.has(c.categoria)) catMap.set(c.categoria, [])
    catMap.get(c.categoria)!.push(c.nombre)
  })
  return [...catMap.entries()]
    .sort((a, b) => (CAT_ORDEN[a[0]] ?? 99) - (CAT_ORDEN[b[0]] ?? 99))
    .map(([cat, names]) => ({ cat, label: CAT_LABEL[cat] ?? cat, names }))
})

const countCriteriosDia = computed(() =>
  calendarioDia.value.filter(c => c.tipo_calculo === 'rubrica').length,
)

// Criterios que existen en otros días pero no en el día activo
const criteriosNoHoy = computed(() => {
  const hoySet = new Set(
    calendarioDia.value.filter(c => c.tipo_calculo === 'rubrica').map(c => c.nombre),
  )
  const otros = new Set(
    calendario.value
      .filter(c => c.tipo_calculo === 'rubrica' && c.momento !== diaActivo.value && c.momento !== 'UNICO')
      .map(c => c.nombre),
  )
  return [...otros].filter(n => !hoySet.has(n)).sort()
})

const actividadesHoy = computed(() =>
  actividades.value
    .filter(a => a.momento === diaActivo.value)
    .sort((a, b) => (a.hora_inicio ?? '') < (b.hora_inicio ?? '') ? -1 : 1),
)

function countActDia(dia: string): number {
  return actividades.value.filter(a => a.momento === dia).length
}

// ── Computed: semana completa ─────────────────────────────────────────────────
const criteriosSemana = computed(() => {
  const seen = new Map<string, { codigo: string; nombre: string; categoria: string; orden: number }>()
  calendario.value
    .filter(c => c.tipo_calculo === 'rubrica' && c.momento !== 'UNICO')
    .forEach(c => {
      if (!seen.has(c.codigo))
        seen.set(c.codigo, { codigo: c.codigo, nombre: c.nombre, categoria: c.categoria, orden: c.orden })
    })
  return [...seen.values()].sort((a, b) => {
    const co = (CAT_ORDEN[a.categoria] ?? 99) - (CAT_ORDEN[b.categoria] ?? 99)
    return co !== 0 ? co : a.orden - b.orden
  })
})

const gruposSemana = computed(() => {
  const catMap = new Map<string, typeof criteriosSemana.value>()
  criteriosSemana.value.forEach(c => {
    if (!catMap.has(c.categoria)) catMap.set(c.categoria, [])
    catMap.get(c.categoria)!.push(c)
  })
  return [...catMap.entries()]
    .sort((a, b) => (CAT_ORDEN[a[0]] ?? 99) - (CAT_ORDEN[b[0]] ?? 99))
    .map(([cat, crit]) => ({ cat, label: CAT_LABEL[cat] ?? cat, criterios: crit }))
})

function getEstadoCelda(codigo: string, momento: string): 'programado' | 'cancelado' | null {
  const fila = calendario.value.find(c => c.codigo === codigo && c.momento === momento)
  if (!fila) return null
  return fila.estado === 'cancelado' ? 'cancelado' : 'programado'
}
</script>

<template>
  <div class="min-h-screen bg-[#F4F6F4] pb-14">

    <!-- ── Barra de días fija (solo móvil) ──────────────────────────────── -->
    <div
      v-if="!cargando && !error && diasConCriterios.length"
      role="tablist"
      aria-label="Día"
      class="md:hidden sticky top-16 z-40 bg-white border-b border-[#E3E7E4] px-4 py-2.5 grid gap-2"
      :style="{ gridTemplateColumns: `repeat(${diasConCriterios.length}, minmax(0, 1fr))` }"
    >
      <button
        v-for="dia in diasConCriterios"
        :key="dia"
        role="tab"
        :aria-selected="dia === diaActivo"
        @click="diaActivo = dia"
        :class="[
          dia === diaActivo
            ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
            : 'bg-white text-[#16201B] border-[#DCE1DD]',
          'h-14 rounded-xl border flex flex-col items-center justify-center gap-0.5 cursor-pointer font-[inherit] transition-colors'
        ]"
      >
        <span class="text-sm font-bold">{{ LABEL_DIA_CORTO[dia] }}</span>
        <span class="text-[11px]">
          {{ dia === diaActivo ? 'Hoy' : (countActDia(dia) + ' act.') }}
        </span>
      </button>
    </div>

    <!-- ── Encabezado de página ──────────────────────────────────────────── -->
    <div class="max-w-[1080px] mx-auto px-4 md:px-6 pt-7 pb-0 flex flex-wrap items-end justify-between gap-4">
      <div class="flex flex-col gap-1">
        <h1 class="m-0 text-3xl font-extrabold tracking-tight">Calendario</h1>
        <p class="m-0 text-sm text-[#5B6660]">Qué se evalúa y qué actividades hay cada día del campamento.</p>
      </div>
      <!-- Selector vista (solo desktop) -->
      <div role="tablist" aria-label="Vista" class="hidden md:flex p-1 bg-[#E9EDEA] rounded-xl gap-0.5">
        <button
          role="tab"
          :aria-selected="vistaActiva === 'dia'"
          @click="vistaActiva = 'dia'"
          :class="[
            vistaActiva === 'dia'
              ? 'bg-white text-[#16201B] font-bold shadow-sm'
              : 'bg-transparent text-[#5B6660] font-medium',
            'h-9 px-4 rounded-[9px] text-sm border-0 cursor-pointer transition-all font-[inherit]'
          ]"
        >Por día</button>
        <button
          role="tab"
          :aria-selected="vistaActiva === 'semana'"
          @click="vistaActiva = 'semana'"
          :class="[
            vistaActiva === 'semana'
              ? 'bg-white text-[#16201B] font-bold shadow-sm'
              : 'bg-transparent text-[#5B6660] font-medium',
            'h-9 px-4 rounded-[9px] text-sm border-0 cursor-pointer transition-all font-[inherit]'
          ]"
        >Semana completa</button>
      </div>
    </div>

    <!-- ── Main ─────────────────────────────────────────────────────────── -->
    <main class="max-w-[1080px] mx-auto px-4 md:px-6 mt-5 flex flex-col gap-5">

      <!-- Cargando -->
      <div v-if="cargando" class="flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-[#0E7C59] border-t-transparent rounded-full animate-spin"></div>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="text-center py-10 text-red-600 text-sm">{{ error }}</div>

      <!-- Sin datos -->
      <div v-else-if="!diasConCriterios.length" class="text-center py-10 text-[#5B6660] text-sm">
        No hay criterios programados.
      </div>

      <template v-else>

        <!-- ════════════════════════════════════════════════════════════════
             VISTA: POR DÍA
             ════════════════════════════════════════════════════════════ -->
        <template v-if="vistaActiva === 'dia'">

          <!-- Tarjetas de día (ocultas en móvil — usa barra sticky arriba) -->
          <div
            role="tablist"
            aria-label="Día"
            class="hidden md:grid gap-2.5"
            :style="{ gridTemplateColumns: `repeat(${diasConCriterios.length}, minmax(150px, 1fr))` }"
          >
            <button
              v-for="dia in diasConCriterios"
              :key="dia"
              role="tab"
              :aria-selected="dia === diaActivo"
              @click="diaActivo = dia"
              :class="[
                dia === diaActivo
                  ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
                  : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]',
                'min-h-[68px] rounded-2xl border flex flex-col items-start justify-center gap-1 px-4 cursor-pointer font-[inherit] transition-colors text-left'
              ]"
            >
              <span class="text-base font-bold">{{ LABEL_DIA[dia] }}</span>
              <span class="text-xs opacity-85">
                <template v-if="dia === diaActivo && countActDia(dia) === 0">
                  Hoy
                </template>
                <template v-else>
                  {{ dia === diaActivo ? 'Hoy · ' : '' }}{{ countCriteriosDia }} criterios · {{ countActDia(dia) }} act.
                </template>
              </span>
            </button>
          </div>

          <!-- Contenido del día: Se evalúa + Actividades -->
          <div class="flex flex-col gap-4 md:flex-row md:flex-wrap md:items-start">

            <!-- Actividades (primero en móvil, segundo en desktop) -->
            <aside
              aria-label="Actividades del día"
              class="order-1 md:order-2 md:flex-[2_1_300px] bg-white border border-[#E3E7E4] rounded-2xl p-5 flex flex-col gap-4"
            >
              <h2 class="m-0 text-xl font-extrabold">Actividades</h2>

              <template v-if="actividadesHoy.length">
                <div v-for="act in actividadesHoy" :key="act.id" class="flex gap-3 items-start">
                  <span class="w-14 flex-shrink-0 h-10 rounded-xl bg-[#E1F3EA] text-[#0B6B4B] flex items-center justify-center text-sm font-extrabold">
                    {{ formatHora(act.hora_inicio) || '—' }}
                  </span>
                  <span class="flex flex-col gap-0.5">
                    <span class="text-[15px] font-bold leading-snug">{{ act.nombre }}</span>
                    <span v-if="act.lugar" class="text-sm text-[#5B6660]">{{ act.lugar }}</span>
                  </span>
                </div>
                <p class="m-0 pt-3 border-t border-[#EEF1EF] text-sm leading-relaxed text-[#5B6660]">
                  La asistencia a los programas cuenta para tu escuela. Meta: 95 % de participación.
                </p>
              </template>

              <p v-else class="m-0 text-sm text-[#5B6660]">
                Sin actividades programadas para este día.
              </p>
            </aside>

            <!-- Se evalúa (segundo en móvil, primero en desktop) -->
            <section
              aria-label="Criterios del día"
              class="order-2 md:order-1 md:flex-[3_1_420px] bg-white border border-[#E3E7E4] rounded-2xl p-5 flex flex-col gap-5"
            >
              <div class="flex justify-between items-baseline gap-3">
                <h2 class="m-0 text-xl font-extrabold">
                  Se evalúa el {{ (LABEL_DIA[diaActivo] ?? diaActivo).toLowerCase() }}
                </h2>
                <span class="text-sm text-[#5B6660] whitespace-nowrap">{{ countCriteriosDia }} criterios</span>
              </div>

              <template v-if="gruposDia.length">
                <div v-for="grupo in gruposDia" :key="grupo.cat" class="flex flex-col gap-2">
                  <span class="text-xs font-bold tracking-widest uppercase text-[#5B6660]">{{ grupo.label }}</span>
                  <div class="flex flex-wrap gap-2">
                    <span
                      v-for="nombre in grupo.names"
                      :key="nombre"
                      class="h-9 px-3.5 rounded-full bg-[#F4F6F4] border border-[#E3E7E4] flex items-center text-sm font-medium"
                    >{{ nombre }}</span>
                  </div>
                </div>
              </template>

              <p v-else class="m-0 text-sm text-[#5B6660]">Sin criterios programados para este día.</p>

              <!-- No se evalúan hoy -->
              <p
                v-if="criteriosNoHoy.length"
                class="m-0 pt-4 border-t border-[#EEF1EF] text-sm leading-relaxed text-[#5B6660]"
              >
                <strong class="text-[#16201B]">No se evalúan este día:</strong>
                {{ criteriosNoHoy.join(', ') }}.
              </p>
            </section>
          </div>
        </template>

        <!-- ════════════════════════════════════════════════════════════════
             VISTA: SEMANA COMPLETA (solo desktop)
             ════════════════════════════════════════════════════════════ -->
        <template v-if="vistaActiva === 'semana'">
          <section class="hidden md:block bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
            <div class="overflow-x-auto">
              <div
                role="table"
                aria-label="Criterios por día"
                class="min-w-[560px]"
              >
                <!-- Encabezado de columnas -->
                <div
                  role="row"
                  class="border-b border-[#E3E7E4]"
                  :style="{ display: 'grid', gridTemplateColumns: `minmax(220px, 1fr) repeat(${diasConCriterios.length}, 120px)` }"
                >
                  <span role="columnheader" class="px-5 py-3.5 text-sm font-semibold text-[#5B6660]">Criterio</span>
                  <span
                    v-for="dia in diasConCriterios"
                    :key="dia"
                    role="columnheader"
                    :class="[
                      dia === diaActivo ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'text-[#16201B]',
                      'flex flex-col items-center justify-center py-3 gap-0.5'
                    ]"
                  >
                    <span class="text-sm font-bold">{{ LABEL_DIA_CORTO[dia] }}</span>
                    <span v-if="dia === diaActivo" class="text-[11px] font-semibold">Hoy</span>
                  </span>
                </div>

                <!-- Grupos de criterios -->
                <div v-for="grupo in gruposSemana" :key="grupo.cat" role="rowgroup">
                  <!-- Cabecera de categoría -->
                  <div
                    role="row"
                    class="px-5 py-3 bg-[#FAFBFA] border-b border-[#EEF1EF] text-xs font-bold tracking-widest uppercase text-[#5B6660]"
                  >{{ grupo.label }}</div>

                  <!-- Filas de criterios -->
                  <div
                    v-for="crit in grupo.criterios"
                    :key="crit.codigo"
                    role="row"
                    class="border-b border-[#EEF1EF] last:border-b-0 min-h-[46px]"
                    :style="{ display: 'grid', gridTemplateColumns: `minmax(220px, 1fr) repeat(${diasConCriterios.length}, 120px)` }"
                  >
                    <span role="rowheader" class="px-5 flex items-center text-sm text-[#16201B]">
                      {{ crit.nombre }}
                    </span>
                    <span
                      v-for="dia in diasConCriterios"
                      :key="dia"
                      role="cell"
                      :class="[
                        dia === diaActivo ? 'bg-[#F0F8F4]' : '',
                        'flex items-center justify-center'
                      ]"
                      :aria-label="getEstadoCelda(crit.codigo, dia) === 'programado' ? 'Se evalúa' : getEstadoCelda(crit.codigo, dia) === 'cancelado' ? 'Cancelado' : 'No se evalúa'"
                    >
                      <!-- Programado: punto verde -->
                      <span
                        v-if="getEstadoCelda(crit.codigo, dia) === 'programado'"
                        class="w-3 h-3 rounded-full bg-[#0E7C59]"
                      ></span>
                      <!-- Cancelado: cuadro rojo -->
                      <span
                        v-else-if="getEstadoCelda(crit.codigo, dia) === 'cancelado'"
                        class="w-3 h-3 rounded-sm bg-[#A3261F]"
                      ></span>
                      <!-- No se evalúa: círculo vacío -->
                      <span
                        v-else
                        class="w-3 h-3 rounded-full border-2 border-[#DCE1DD] box-border"
                      ></span>
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Leyenda -->
            <div class="flex flex-wrap gap-4 px-5 py-3.5 border-t border-[#EEF1EF] text-sm text-[#5B6660]">
              <span class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-full bg-[#0E7C59]" aria-hidden="true"></span>Se evalúa
              </span>
              <span class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-full border-2 border-[#DCE1DD]" aria-hidden="true"></span>No se evalúa
              </span>
              <span class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-sm bg-[#A3261F]" aria-hidden="true"></span>Cancelado
              </span>
              <span class="flex items-center gap-2">
                <span class="w-3.5 h-3 rounded-sm bg-[#E1F3EA]" aria-hidden="true"></span>Hoy
              </span>
            </div>
          </section>
        </template>

        <!-- ── Notas ─────────────────────────────────────────────────────── -->
        <section class="bg-white border border-[#E3E7E4] rounded-2xl px-5 py-4 text-sm text-[#3A4540] flex flex-wrap gap-y-1.5 gap-x-6 leading-relaxed">
          <span><strong>Inscripción:</strong> se califica una sola vez, según la fecha de inscripción de cada integrante.</span>
          <span><strong>Domingo 8:</strong> clausura y entrega de medallas; no hay criterios evaluados.</span>
        </section>

      </template>
    </main>
  </div>
</template>
