<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  rankingPublicoService,
  fichaPublicaService,
  type PublicoRanking,
  type PublicoFichaFila as PublicoFichaFilaBase,
} from '@/modules/puntajes/services/puntajes.service'

interface PublicoFichaFila extends PublicoFichaFilaBase {
  criterio_codigo: string | null
  componente: string | null
  puntaje_max: number | null
  puntaje: number | null
}

const route  = useRoute()
const router = useRouter()

const equipoId = route.params.id as string

const resumen  = ref<PublicoRanking | null>(null)
const ficha    = ref<PublicoFichaFila[]>([])
const cargando = ref(true)
const error    = ref('')

onMounted(async () => {
  try {
    const [res, fich] = await Promise.all([
      rankingPublicoService.getPorId(equipoId),
      fichaPublicaService.getPorEquipo(equipoId),
    ])
    resumen.value = res
    ficha.value   = fich as PublicoFichaFila[]
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar la ficha'
  } finally {
    cargando.value = false
  }
})

// ── Días y criterios únicos ───────────────────────────────────────────────────
const ORDEN_DIA: Record<string, number> = { J: 0, V: 1, S: 2, D: 3 }
const LABEL_DIA: Record<string, string> = { J: 'Jueves', V: 'Viernes', S: 'Sábado', D: 'Domingo' }
const ORDEN_COMP: Record<string, number> = { rubrica: 0, asistencia: 1, liderazgo: 2 }

const dias = computed(() => {
  const d = [...new Set(ficha.value.map((f) => f.momento).filter((m): m is string => !!m))]
  return d.sort((a, b) => (ORDEN_DIA[a] ?? 9) - (ORDEN_DIA[b] ?? 9))
})

// Criterios únicos ordenados por componente+nombre (sin duplicados por día)
const criterios = computed(() => {
  const seen = new Map<string, { codigo: string; nombre: string; componente: string }>()
  ficha.value.forEach((f) => {
    const key = f.criterio_codigo ?? ''
    if (key && !seen.has(key)) {
      seen.set(key, {
        codigo: f.criterio_codigo ?? '',
        nombre: f.criterio_nombre ?? '',
        componente: f.componente ?? '',
      })
    }
  })
  return [...seen.values()].sort((a, b) => {
    const co = (ORDEN_COMP[a.componente] ?? 9) - (ORDEN_COMP[b.componente] ?? 9)
    if (co !== 0) return co
    return a.nombre.localeCompare(b.nombre)
  })
})

// Mapa para lookup rápido: "criterio_codigo|momento" → fila
const mapaFicha = computed(() => {
  const m = new Map<string, PublicoFichaFila>()
  ficha.value.forEach((f) => {
    if (f.criterio_codigo && f.momento) m.set(`${f.criterio_codigo}|${f.momento}`, f)
  })
  return m
})

function getCelda(criterio_codigo: string, momento: string): PublicoFichaFila | null {
  return mapaFicha.value.get(`${criterio_codigo}|${momento}`) ?? null
}

function pctCelda(f: PublicoFichaFila): number {
  const max = f.puntaje_max ?? 0
  if (!max) return 0
  return ((f.puntaje ?? 0) / max) * 100
}

function pctColor(pct: number) {
  if (pct >= 80) return '#d1fae5'
  if (pct >= 50) return '#fef9c3'
  if (pct > 0)   return '#fee2e2'
  return '#f3f4f6'
}

// ── Medalla ───────────────────────────────────────────────────────────────────
const MEDALLA_EMOJI: Record<string, string> = {
  oro: '🥇', plata: '🥈', bronce: '🥉', participacion: '🎖',
}
const MEDALLA_LABEL: Record<string, string> = {
  oro: 'Oro', plata: 'Plata', bronce: 'Bronce', participacion: 'Participación',
}
function medallaClase(m: string | null) {
  const map: Record<string, string> = {
    oro: 'medalla--oro', plata: 'medalla--plata', bronce: 'medalla--bronce', participacion: 'medalla--part',
  }
  return map[m ?? ''] ?? 'medalla--part'
}

const hayResultados = computed(() => (resumen.value?.pts_bruto ?? 0) > 0 || ficha.value.length > 0)
</script>

<template>
  <div class="ficha-page">
    <button class="btn-link" @click="router.push('/ranking')">← Ranking</button>

    <div v-if="cargando" class="ficha-empty">Cargando…</div>
    <div v-else-if="error" class="ficha-empty ficha-empty--error">{{ error }}</div>

    <template v-else-if="resumen">
      <!-- Cabecera del equipo -->
      <div class="ficha-header">
        <div
          class="ficha-header__color"
          :style="{ background: resumen.equipo_color ?? '#6b7280' }"
        />
        <div class="ficha-header__info">
          <h1 class="ficha-header__nombre">{{ resumen.equipo_nombre }}</h1>
          <span :class="['medalla-badge', medallaClase(resumen.medalla)]">
            {{ MEDALLA_EMOJI[resumen.medalla ?? 'participacion'] }}
            {{ MEDALLA_LABEL[resumen.medalla ?? 'participacion'] }}
          </span>
        </div>
        <div class="ficha-header__escala">
          <span class="ficha-escala-num">{{ resumen.pts_escala }}</span>
          <span class="ficha-escala-denom">/ 1000</span>
        </div>
      </div>

      <!-- Desglose de puntos -->
      <div class="ficha-desglose">
        <div class="desglose-item">
          <span class="desglose-label">Inscripción</span>
          <span class="desglose-val">{{ resumen.pts_inscripcion }}</span>
        </div>
        <div class="desglose-item">
          <span class="desglose-label">Evaluaciones</span>
          <span class="desglose-val">
            {{ (resumen.pts_rubrica ?? 0) + (resumen.pts_liderazgo ?? 0) + (resumen.pts_asistencia ?? 0) }}
          </span>
        </div>
        <div class="desglose-item desglose-item--bonus">
          <span class="desglose-label">+ Bonus</span>
          <span class="desglose-val">+{{ resumen.pts_bonus }}</span>
        </div>
        <div class="desglose-item desglose-item--demerito">
          <span class="desglose-label">− Deméritos</span>
          <span class="desglose-val">−{{ resumen.pts_demeritos }}</span>
        </div>
        <div class="desglose-item desglose-item--total">
          <span class="desglose-label">Total bruto</span>
          <span class="desglose-val">{{ resumen.pts_bruto }} / 5200</span>
        </div>
      </div>

      <!-- Sin resultados publicados aún -->
      <div v-if="!hayResultados" class="ficha-aviso">
        Los resultados de evaluación aún no han sido publicados.
      </div>

      <!-- Matriz criterio × día -->
      <div v-else-if="ficha.length" class="ficha-matriz-wrap">
        <h2 class="ficha-section-title">Puntaje por criterio × día</h2>
        <div class="ficha-matriz-scroll">
          <table class="ficha-tabla">
            <thead>
              <tr>
                <th class="col-criterio">Criterio</th>
                <th v-for="dia in dias" :key="dia" class="col-dia">
                  {{ LABEL_DIA[dia] ?? dia }}
                </th>
              </tr>
            </thead>
            <tbody>
              <!-- Filas por componente -->
              <template v-for="comp in ['rubrica', 'asistencia', 'liderazgo']" :key="comp">
                <!-- Separador de componente si hay criterios -->
                <tr
                  v-if="criterios.filter((c) => c.componente === comp).length"
                  class="comp-header"
                >
                  <td :colspan="dias.length + 1">
                    {{
                      comp === 'rubrica' ? 'Rúbrica de campamento'
                      : comp === 'asistencia' ? 'Asistencia y participación'
                      : 'Liderazgo de servicio'
                    }}
                  </td>
                </tr>
                <tr
                  v-for="crit in criterios.filter((c) => c.componente === comp)"
                  :key="crit.codigo"
                  class="data-row"
                >
                  <td class="col-criterio">
                    <span class="crit-codigo">{{ crit.codigo }}</span>
                    {{ crit.nombre }}
                  </td>
                  <td
                    v-for="dia in dias"
                    :key="dia"
                    class="col-celda"
                  >
                    <template v-if="getCelda(crit.codigo, dia)">
                      <span
                        class="celda-val"
                        :style="{ background: pctColor(pctCelda(getCelda(crit.codigo, dia)!)) }"
                      >
                        {{ getCelda(crit.codigo, dia)!.puntaje }}
                      </span>
                    </template>
                    <span v-else class="celda-na">—</span>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
        <p class="ficha-leyenda">
          <span class="ley-chip" style="background:#d1fae5">≥ 80</span>
          <span class="ley-chip" style="background:#fef9c3">50–79</span>
          <span class="ley-chip" style="background:#fee2e2">&lt; 50</span>
          <span class="ley-chip" style="background:#f3f4f6">0 / n/a</span>
        </p>
      </div>

      <div v-else class="ficha-aviso">
        Aún no hay puntajes publicados para este equipo.
      </div>
    </template>

    <div v-else class="ficha-empty">Equipo no encontrado.</div>
  </div>
</template>

<style scoped>
.ficha-page { max-width: 700px; margin: 0 auto; padding: 0 1rem; }
.btn-link {
  background: none; border: none; color: #16a34a; cursor: pointer;
  font-size: 0.9rem; padding: 0; margin-bottom: 1rem; display: inline-flex;
  align-items: center; min-height: 44px;
}

/* Cabecera */
.ficha-header {
  display: flex; align-items: center; gap: 0.75rem;
  background: white; border: 1px solid #e5e7eb; border-radius: 12px;
  padding: 1rem; margin-bottom: 0.75rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.ficha-header__color { width: 48px; height: 48px; border-radius: 50%; flex-shrink: 0; border: 2px solid #e5e7eb; }
.ficha-header__info { flex: 1; display: flex; flex-direction: column; gap: 0.3rem; }
.ficha-header__nombre { font-size: 1.15rem; font-weight: 800; margin: 0; }
.ficha-header__escala { text-align: right; }
.ficha-escala-num { font-size: 1.8rem; font-weight: 900; color: #16a34a; line-height: 1; }
.ficha-escala-denom { font-size: 0.82rem; color: #9ca3af; display: block; text-align: right; }

/* Desglose */
.ficha-desglose {
  display: flex; flex-wrap: wrap; gap: 0.4rem; margin-bottom: 0.75rem;
}
.desglose-item {
  display: flex; flex-direction: column; align-items: center; gap: 0.1rem;
  flex: 1 1 80px; background: white; border: 1px solid #e5e7eb; border-radius: 10px;
  padding: 0.6rem 0.4rem; box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.desglose-label { font-size: 0.72rem; color: #6b7280; text-align: center; }
.desglose-val { font-weight: 700; font-size: 0.9rem; }
.desglose-item--bonus .desglose-val    { color: #16a34a; }
.desglose-item--demerito .desglose-val { color: #dc2626; }
.desglose-item--total                  { border-color: #16a34a; }
.desglose-item--total .desglose-val    { color: #16a34a; font-size: 1rem; }

/* Matriz */
.ficha-section-title { font-size: 0.95rem; font-weight: 700; margin: 0 0 0.6rem; }
.ficha-matriz-scroll { overflow-x: auto; }
.ficha-tabla {
  width: 100%; border-collapse: collapse; font-size: 0.82rem;
  background: white; border: 1px solid #e5e7eb; border-radius: 8px;
  overflow: hidden;
}
.ficha-tabla th, .ficha-tabla td { padding: 0.4rem 0.45rem; border: 1px solid #e5e7eb; }
.col-criterio { text-align: left; min-width: 130px; max-width: 180px; }
.col-dia { text-align: center; min-width: 60px; font-weight: 700; font-size: 0.78rem; }
.col-celda { text-align: center; }

.comp-header td {
  background: #f0fdf4; font-weight: 700; font-size: 0.75rem; color: #166534;
  padding: 0.3rem 0.5rem; text-transform: uppercase; letter-spacing: 0.04em;
}

.data-row:hover { background: #f0fdf4; }

.crit-codigo {
  display: inline-block; background: #dcfce7; color: #166534;
  font-size: 0.65rem; font-weight: 700; padding: 0.1rem 0.3rem;
  border-radius: 3px; margin-right: 0.3rem;
}

.celda-val {
  display: inline-block; min-width: 32px; padding: 0.15rem 0.3rem;
  border-radius: 4px; font-weight: 700;
}
.celda-na { color: #d1d5db; }

/* Leyenda */
.ficha-leyenda { display: flex; gap: 0.4rem; flex-wrap: wrap; margin-top: 0.5rem; font-size: 0.72rem; align-items: center; }
.ley-chip { padding: 0.15rem 0.5rem; border-radius: 4px; font-weight: 700; }

/* Medalla */
.medalla-badge {
  font-size: 0.75rem; font-weight: 700; padding: 0.2rem 0.5rem; border-radius: 4px;
  width: fit-content;
}
.medalla--oro    { background: #fef9c3; color: #713f12; }
.medalla--plata  { background: #f1f5f9; color: #475569; }
.medalla--bronce { background: #fef3c7; color: #92400e; }
.medalla--part   { background: #f3f4f6; color: #6b7280; }

/* Avisos */
.ficha-aviso {
  text-align: center; padding: 1.25rem; background: #f0fdf4; border: 1px solid #dcfce7;
  border-radius: 8px; color: #166534; font-size: 0.9rem; margin-bottom: 0.75rem;
}
.ficha-empty { text-align: center; padding: 2.5rem; color: #6b7280; font-size: 0.9rem; }
.ficha-empty--error { color: #dc2626; }
</style>
