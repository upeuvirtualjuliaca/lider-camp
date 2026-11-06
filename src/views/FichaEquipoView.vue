<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  rankingPublicoService,
  rankingDiarioPublicoService,
  rubricaDiaPublicaService,
  type PublicoRanking,
  type PublicoRankingDia,
  type RubricaDiaFila,
} from '@/modules/puntajes/services/puntajes.service'
import { publicoService, type PublicoCalendario } from '@/modules/criterios/services/criterios.service'

// ── Constantes ────────────────────────────────────────────────────────────────
const ORDEN_DIA: Record<string, number> = { J: 0, V: 1, S: 2, D: 3 }
const LABEL_DIA: Record<string, string> = { J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo' }

// Nombres de categoría (de la tabla categorias_criterios)
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
  __actividades: 'Actividades',
}
const CAT_ORDEN: Record<string, number> = {
  inscripcion: 1, armado: 2, orden_cocina: 3, ceremonias_participacion: 4,
  liderazgo: 5, vidal: 6, lavanderia: 7, ginkana: 8,
  concurso_los_que_mas_saben: 9, dramas_biblicos: 10, concurso_de_comida: 11, horarios: 12,
  __actividades: 90,
}

// ── Estado ────────────────────────────────────────────────────────────────────
const route   = useRoute()
const router  = useRouter()
const equipoId = route.params.id as string
const diaParam = (route.query.dia as string) || null

const resumen       = ref<PublicoRanking | null>(null)
const diasEquipo    = ref<PublicoRankingDia[]>([])
const todasDiasRaw  = ref<PublicoRankingDia[]>([])
const calendario    = ref<PublicoCalendario[]>([])
const rubricaDia    = ref<RubricaDiaFila[]>([])
const diaActivo     = ref(diaParam ?? '')
const cargando      = ref(true)
const cargandoRub   = ref(false)
const error         = ref('')
const gruposAbiertos = ref<Set<string>>(new Set())

// ── Carga inicial ─────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [rankingTot, diasDia] = await Promise.all([
      rankingPublicoService.getPorId(equipoId),
      rankingDiarioPublicoService.getAll(),
    ])

    resumen.value      = rankingTot
    todasDiasRaw.value = diasDia
    diasEquipo.value   = diasDia.filter(d => d.equipo_id === equipoId)

    const campId =
      rankingTot?.campamento_id ??
      diasEquipo.value[0]?.campamento_id ??
      null

    if (!diaActivo.value && diasEquipo.value.length) {
      diaActivo.value = diasEquipo.value[diasEquipo.value.length - 1]!.momento
    }

    if (campId) {
      calendario.value = await publicoService.getCalendarioCampamento(campId)
    }

    if (diaActivo.value) {
      cargandoRub.value = true
      rubricaDia.value = await rubricaDiaPublicaService.getPorEquipoDia(equipoId, diaActivo.value)
      cargandoRub.value = false
    }
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
})

// Abre todos los grupos al cargar/cambiar día
watch(
  () => [rubricaDia.value, calendario.value],
  () => { gruposAbiertos.value = new Set(grupos.value.map(g => g.clave)) },
  { deep: false },
)

// ── Cambiar día ───────────────────────────────────────────────────────────────
async function seleccionarDia(dia: string) {
  if (dia === diaActivo.value) return
  diaActivo.value = dia
  rubricaDia.value = []
  cargandoRub.value = true
  try {
    rubricaDia.value = await rubricaDiaPublicaService.getPorEquipoDia(equipoId, dia)
  } finally {
    cargandoRub.value = false
  }
  router.replace({ query: { dia } })
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function siglas(nombre: string): string {
  const words = nombre.split(/\s+/).filter(w => w.length > 2)
  return words.slice(0, 2).map(w => w[0]!.toUpperCase()).join('') || nombre.slice(0, 2).toUpperCase()
}

function barColor(pct: number): string {
  if (pct >= 100) return '#0E7C59'
  if (pct >= 50)  return '#5FAF8A'
  if (pct > 0)    return '#E0A43A'
  return '#D1D5DB'
}

function irAlRanking() {
  router.push(diaActivo.value ? `/ranking?dia=${diaActivo.value}` : '/ranking')
}

// ── Computeds: equipo ─────────────────────────────────────────────────────────
const equipoNombre = computed(
  () => resumen.value?.equipo_nombre ?? diasEquipo.value[0]?.equipo_nombre ?? '',
)
const equipoColor = computed(
  () => resumen.value?.equipo_color ?? diasEquipo.value[0]?.equipo_color ?? '#6b7280',
)
const campamentoId = computed(
  () => resumen.value?.campamento_id ?? diasEquipo.value[0]?.campamento_id ?? null,
)

// ── Computeds: día seleccionado ───────────────────────────────────────────────
const diaData = computed(() =>
  diasEquipo.value.find(d => d.momento === diaActivo.value) ?? null,
)

// Todos los días posibles en el calendario (ordenados J→D)
const todosDias = computed(() => {
  const set = [...new Set(calendario.value.map(c => c.momento))]
  return set.sort((a, b) => (ORDEN_DIA[a] ?? 9) - (ORDEN_DIA[b] ?? 9))
})

// Días que ya tienen datos cerrados
const diasConDatos = computed(() => new Set(diasEquipo.value.map(d => d.momento)))

// Posición y total equipos
const posicionDia = computed(() => diaData.value?.posicion ?? null)
const totalEquiposDia = computed(() => {
  if (!diaData.value || !campamentoId.value) return 0
  return todasDiasRaw.value.filter(
    d => d.campamento_id === campamentoId.value && d.momento === diaActivo.value,
  ).length
})

// ── Computeds: máximos del día ────────────────────────────────────────────────
const calendarioDia = computed(() =>
  calendario.value.filter(c => c.momento === diaActivo.value && c.estado !== 'cancelado'),
)
const maxRubricaDia = computed(() =>
  calendarioDia.value
    .filter(c => c.tipo_calculo === 'rubrica')
    .reduce((s, c) => s + (c.puntaje_max ?? 0), 0),
)
const maxActividadesDia = computed(() =>
  calendarioDia.value
    .filter(c => c.tipo_calculo === 'asistencia' || c.tipo_calculo === 'programa_estelar')
    .reduce((s, c) => s + (c.puntaje_max ?? 0), 0),
)
const maxTotalDia = computed(() => maxRubricaDia.value + maxActividadesDia.value)

// ── Computeds: puntos del día ─────────────────────────────────────────────────
const ptsRubricaDia = computed(() =>
  diaData.value?.pts_rubrica ?? rubricaDia.value.reduce((s, r) => s + r.puntaje, 0),
)
const ptsTotalDia = computed(() =>
  diaData.value?.pts_total ?? ptsRubricaDia.value,
)
const pctDia = computed(() =>
  maxTotalDia.value ? Math.round((ptsTotalDia.value / maxTotalDia.value) * 100) : 0,
)

// Anchos de barra apilada (%)
const wRubrica = computed(() =>
  maxTotalDia.value ? Math.min(100, (ptsRubricaDia.value / maxTotalDia.value) * 100) : 0,
)
const wActividades = computed(() => {
  if (!maxTotalDia.value || !diaData.value) return 0
  return Math.min(100, (diaData.value.pts_actividades / maxTotalDia.value) * 100)
})

// ── Computeds: grupos de criterios ───────────────────────────────────────────
interface CriterioRow { nombre: string; puntaje: number; puntaje_max: number; pendiente: boolean }
interface Grupo       { clave: string; label: string; orden: number; rows: CriterioRow[]; sum: number; max: number }

const grupos = computed((): Grupo[] => {
  const calMap = new Map<string, PublicoCalendario>()
  calendarioDia.value.forEach(c => { if (c.codigo) calMap.set(c.codigo, c) })

  const catMap = new Map<string, Grupo>()

  // Rubrica: filas con puntaje real
  rubricaDia.value.forEach(r => {
    const cat = calMap.get(r.criterio_codigo)?.categoria ?? 'otros'
    if (!catMap.has(cat)) {
      catMap.set(cat, { clave: cat, label: CAT_LABEL[cat] ?? cat, orden: CAT_ORDEN[cat] ?? 99, rows: [], sum: 0, max: 0 })
    }
    const g = catMap.get(cat)!
    g.rows.push({ nombre: r.criterio_nombre, puntaje: r.puntaje, puntaje_max: r.puntaje_max, pendiente: false })
    g.sum += r.puntaje
    g.max += r.puntaje_max
  })

  // Actividades: criterios de asistencia y programa_estelar (sin desglose individual)
  const actCrits = calendarioDia.value.filter(
    c => c.tipo_calculo === 'asistencia' || c.tipo_calculo === 'programa_estelar',
  )
  if (actCrits.length) {
    const actMax = actCrits.reduce((s, c) => s + (c.puntaje_max ?? 0), 0)
    catMap.set('__actividades', {
      clave: '__actividades', label: 'Actividades', orden: 90,
      rows: actCrits.map(c => ({ nombre: c.nombre, puntaje: 0, puntaje_max: c.puntaje_max ?? 0, pendiente: true })),
      sum: diaData.value?.pts_actividades ?? 0,
      max: actMax,
    })
  }

  return [...catMap.values()].sort((a, b) => a.orden - b.orden)
})

function toggleGrupo(clave: string) {
  const s = new Set(gruposAbiertos.value)
  if (s.has(clave)) s.delete(clave)
  else s.add(clave)
  gruposAbiertos.value = s
}

// ── Estado general ────────────────────────────────────────────────────────────
const noEncontrado = computed(
  () => !cargando.value && !error.value && !equipoNombre.value && !rubricaDia.value.length,
)
const backLabel = computed(() => {
  const dia = diaParam ?? diaActivo.value
  return dia ? `Ranking del ${(LABEL_DIA[dia] ?? dia).toLowerCase()}` : 'Ranking'
})
</script>

<template>
  <div class="min-h-screen bg-[#F4F6F4] pb-14">
    <!-- Enlace de regreso -->
    <div class="max-w-[1040px] mx-auto px-4 md:px-6 pt-4 pb-1">
      <button
        class="flex items-center gap-1 text-[#0B6B4B] text-sm font-semibold h-9 px-2 -ml-2 rounded-xl hover:bg-white/70 transition-colors"
        @click="irAlRanking()"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 6l-6 6 6 6"/></svg>
        {{ backLabel }}
      </button>
    </div>

    <!-- Cargando -->
    <div v-if="cargando" class="flex justify-center items-center py-20">
      <div class="w-8 h-8 border-4 border-[#0E7C59] border-t-transparent rounded-full animate-spin"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="max-w-[1040px] mx-auto px-4 md:px-6 py-10 text-center text-red-600 text-sm">
      {{ error }}
    </div>

    <!-- No encontrado -->
    <div v-else-if="noEncontrado" class="max-w-[1040px] mx-auto px-4 md:px-6 py-10 text-center text-[#5B6660] text-sm">
      Equipo no encontrado.
    </div>

    <!-- Contenido principal -->
    <main v-else class="max-w-[1040px] mx-auto px-4 md:px-6 flex flex-col gap-4">

      <!-- ── Tarjeta de cabecera ─────────────────────────────────────────── -->
      <section class="bg-white border border-[#E3E7E4] rounded-2xl p-5 md:p-6 flex flex-col gap-4">

        <!-- Equipo: badge + nombre + posición + total -->
        <div class="flex flex-wrap items-center gap-4">
          <!-- Badge con iniciales -->
          <span
            :style="{ background: equipoColor }"
            class="size-[52px] md:size-16 rounded-2xl text-white flex items-center justify-center text-lg md:text-2xl font-extrabold flex-shrink-0 select-none"
            aria-hidden="true"
          >{{ siglas(equipoNombre) }}</span>

          <!-- Nombre + posición -->
          <div class="flex-1 min-w-[180px] flex flex-col gap-1.5">
            <h1 class="m-0 text-xl md:text-3xl font-extrabold tracking-tight leading-tight">
              {{ equipoNombre || '—' }}
            </h1>
            <div v-if="posicionDia" class="flex flex-wrap items-center gap-2">
              <span
                :class="[
                  posicionDia === 1
                    ? 'bg-[#F6E3A3] text-[#6B4E0A]'
                    : 'bg-[#E3E7E4] text-[#5B6660]',
                  'text-xs font-bold px-2.5 py-1 rounded-xl'
                ]"
              >{{ posicionDia }}° del {{ (LABEL_DIA[diaActivo] ?? diaActivo).toLowerCase() }}</span>
              <span v-if="totalEquiposDia" class="text-sm text-[#5B6660]">de {{ totalEquiposDia }} escuelas</span>
            </div>
          </div>

          <!-- Puntaje total -->
          <div class="flex flex-col items-end gap-0.5">
            <span class="text-4xl md:text-5xl font-extrabold tracking-tight leading-none text-[#16201B]">
              {{ ptsTotalDia }}
            </span>
            <span v-if="maxTotalDia" class="text-sm text-[#5B6660] whitespace-nowrap">
              de {{ maxTotalDia }} pts · {{ pctDia }}%
            </span>
          </div>
        </div>

        <!-- Barra apilada rubrica + actividades -->
        <div v-if="maxTotalDia" class="h-2.5 rounded-full bg-[#EEF1EF] overflow-hidden flex" aria-hidden="true">
          <span :style="{ width: wRubrica + '%' }" class="h-full bg-[#0E7C59] transition-all duration-500"></span>
          <span :style="{ width: wActividades + '%' }" class="h-full bg-[#2E6FA8] transition-all duration-500"></span>
        </div>

        <!-- Pestañas de día -->
        <div v-if="todosDias.length" role="tablist" aria-label="Día" class="flex flex-wrap gap-1.5">
          <button
            v-for="dia in todosDias"
            :key="dia"
            role="tab"
            :aria-selected="dia === diaActivo"
            :disabled="!diasConDatos.has(dia)"
            @click="diasConDatos.has(dia) && seleccionarDia(dia)"
            :class="[
              dia === diaActivo
                ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
                : diasConDatos.has(dia)
                  ? 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'
                  : 'bg-white text-[#8A948E] border-dashed border-[#DCE1DD] cursor-default',
              'h-9 px-3.5 rounded-xl text-sm font-semibold border transition-colors'
            ]"
          >
            {{ LABEL_DIA[dia] ?? dia }}
            <span v-if="!diasConDatos.has(dia)" class="text-xs font-normal"> · no publicado</span>
          </button>
        </div>
      </section>

      <!-- ── Tarjetas de resumen (2×2 → 4) ─────────────────────────────── -->
      <section aria-label="Resumen del día" class="grid grid-cols-2 md:grid-cols-4 gap-3">

        <!-- Criterios -->
        <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
          <span class="flex items-center gap-1.5 text-sm text-[#5B6660]">
            <span class="w-2.5 h-2.5 rounded bg-[#0E7C59]" aria-hidden="true"></span>
            Criterios
          </span>
          <span class="text-2xl font-extrabold">{{ ptsRubricaDia }}</span>
          <span v-if="maxRubricaDia" class="text-xs text-[#5B6660]">/ {{ maxRubricaDia }}</span>
        </div>

        <!-- Actividades -->
        <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
          <span class="flex items-center gap-1.5 text-sm text-[#5B6660]">
            <span class="w-2.5 h-2.5 rounded bg-[#2E6FA8]" aria-hidden="true"></span>
            Actividades
          </span>
          <span class="text-2xl font-extrabold">{{ diaData?.pts_actividades ?? 0 }}</span>
          <span v-if="maxActividadesDia" class="text-xs text-[#5B6660]">/ {{ maxActividadesDia }}</span>
          <span v-if="!diaData" class="text-xs text-[#7A4F00] font-semibold">Pendiente de publicar</span>
        </div>

        <!-- Bonus -->
        <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
          <span class="text-sm text-[#5B6660]">Bonus</span>
          <span v-if="diaData?.pts_bonus" class="text-2xl font-extrabold text-[#0B6B4B]">Aplicados</span>
          <span v-else class="text-2xl font-extrabold text-[#8A948E]">0</span>
          <span v-if="!diaData?.pts_bonus" class="text-xs text-[#5B6660]">Sin bonus este día</span>
        </div>

        <!-- Deméritos -->
        <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
          <span class="text-sm text-[#5B6660]">Deméritos</span>
          <span v-if="diaData?.pts_demeritos" class="text-2xl font-extrabold text-[#B91C1C]">Aplicados</span>
          <span v-else class="text-2xl font-extrabold text-[#8A948E]">0</span>
          <span v-if="!diaData?.pts_demeritos" class="text-xs text-[#5B6660]">Sin deméritos este día</span>
        </div>
      </section>

      <!-- ── Detalle por criterio ────────────────────────────────────────── -->
      <section aria-label="Detalle por criterio" class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
        <!-- Encabezado de sección -->
        <div class="flex justify-between items-center px-5 py-4 border-b border-[#EEF1EF]">
          <h2 class="m-0 text-lg font-extrabold">Detalle por criterio</h2>
          <span class="text-xs text-[#5B6660] hidden sm:inline">Obtenido / máximo</span>
        </div>

        <!-- Spinner de carga de rubrica -->
        <div v-if="cargandoRub" class="p-5 text-center text-sm text-[#5B6660]">
          Cargando criterios…
        </div>

        <!-- Grupos de criterios -->
        <template v-else-if="grupos.length">
          <div
            v-for="grupo in grupos"
            :key="grupo.clave"
            class="border-b border-[#EEF1EF] last:border-b-0"
          >
            <!-- Cabecera del grupo (clic para plegar/desplegar) -->
            <button
              class="w-full flex items-center gap-3 px-5 py-3.5 bg-white hover:bg-[#F4F6F4] text-left font-[inherit] cursor-pointer border-0 transition-colors"
              @click="toggleGrupo(grupo.clave)"
            >
              <span class="flex-1 text-xs font-bold tracking-widest uppercase text-[#5B6660] truncate">
                {{ grupo.label }}
              </span>
              <span class="text-sm font-bold text-[#16201B] whitespace-nowrap">
                {{ grupo.sum }}
                <span class="font-medium text-[#8A948E]"> / {{ grupo.max }}</span>
              </span>
              <svg
                class="flex-shrink-0 transition-transform duration-200"
                :style="gruposAbiertos.has(grupo.clave) ? 'transform:rotate(180deg)' : ''"
                width="16" height="16" viewBox="0 0 24 24" fill="none"
                stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                aria-hidden="true"
              ><path d="M6 9l6 6 6-6"/></svg>
            </button>

            <!-- Filas de criterios -->
            <div v-if="gruposAbiertos.has(grupo.clave)">
              <div
                v-for="(row, i) in grupo.rows"
                :key="i"
                class="grid grid-cols-[1fr_auto] md:grid-cols-[minmax(160px,1fr)_minmax(100px,200px)_88px] gap-3 md:gap-4 items-center px-5 py-2.5 min-h-[44px] border-t border-[#EEF1EF]"
              >
                <!-- Nombre -->
                <span class="text-sm font-medium text-[#16201B]">{{ row.nombre }}</span>

                <!-- Barra de progreso (solo desktop) -->
                <span class="hidden md:block h-2 rounded-full bg-[#EEF1EF] overflow-hidden" aria-hidden="true">
                  <span
                    :style="{
                      width: (row.pendiente || !row.puntaje_max ? 0 : Math.min(100, Math.round(row.puntaje / row.puntaje_max * 100))) + '%',
                      background: barColor(row.puntaje_max ? row.puntaje / row.puntaje_max * 100 : 0)
                    }"
                    class="block h-full rounded-full transition-all duration-500"
                  ></span>
                </span>

                <!-- Puntaje -->
                <span
                  :class="[
                    'text-right text-sm font-bold whitespace-nowrap',
                    row.pendiente ? 'text-[#7A4F00]' : 'text-[#16201B]'
                  ]"
                >
                  <template v-if="row.pendiente">Pendiente</template>
                  <template v-else>
                    {{ row.puntaje }}
                    <span class="font-medium text-[#8A948E]"> / {{ row.puntaje_max }}</span>
                  </template>
                </span>
              </div>
            </div>
          </div>
        </template>

        <!-- Sin datos -->
        <div v-else class="p-6 text-sm text-[#5B6660] text-center">
          Sin criterios registrados para este día.
        </div>
      </section>

      <!-- Nota al pie -->
      <p class="text-xs text-[#5B6660] text-center px-4 mt-2">
        Solo se muestran resultados validados y publicados.
      </p>
    </main>
  </div>
</template>
