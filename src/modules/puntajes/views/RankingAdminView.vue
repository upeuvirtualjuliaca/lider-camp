<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { rankingAdminService, type PuntajeEquipo } from '@/modules/puntajes/services/puntajes.service'
import { useCampamentoStore } from '@/stores/campamento'

const router   = useRouter()
const campStore = useCampamentoStore()
const lista    = ref<PuntajeEquipo[]>([])
const cargando = ref(true)
const error    = ref('')
const mostrarAyuda = ref(false)

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    lista.value = await rankingAdminService.getAll(campStore.selectedId ?? undefined)
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

const MEDALLA_EMOJI: Record<string, string> = {
  oro: '🥇', plata: '🥈', bronce: '🥉', participacion: '🎖',
}

const MEDALLA_ESTILOS: Record<string, { card: string; badge: string; pos: string }> = {
  oro:          { card: 'border-yellow-300 bg-yellow-50',     badge: 'bg-yellow-100 text-yellow-800',  pos: 'text-yellow-600' },
  plata:        { card: 'border-slate-300 bg-slate-50',       badge: 'bg-slate-100 text-slate-700',    pos: 'text-slate-500'  },
  bronce:       { card: 'border-amber-300 bg-amber-50',       badge: 'bg-amber-100 text-amber-800',    pos: 'text-amber-600'  },
  participacion:{ card: 'border-gray-200 bg-white',           badge: 'bg-gray-100 text-gray-600',      pos: 'text-gray-400'   },
}

function estilos(m: string | null) {
  return MEDALLA_ESTILOS[m ?? 'participacion'] ?? MEDALLA_ESTILOS.participacion
}

function medallaLabel(m: string | null) {
  if (!m || m === 'participacion') return 'Part.'
  return m[0]!.toUpperCase() + m.slice(1)
}
</script>

<template>
  <div class="max-w-5xl mx-auto px-3 py-4 sm:px-6 pb-8">

    <!-- Encabezado -->
    <div class="flex items-center justify-between mb-5 gap-2">
      <div class="flex items-center gap-2 flex-1 min-w-0">
        <i class="pi pi-trophy text-green-700 text-xl flex-shrink-0" />
        <div class="min-w-0">
          <h1 class="text-lg font-extrabold text-gray-800 leading-tight">Ranking interno</h1>
          <p class="text-xs text-gray-400">Todos los días · datos en vivo</p>
        </div>
      </div>
      <button
        class="w-10 h-10 rounded-full bg-green-50 border border-green-200 text-green-700 font-bold text-base flex items-center justify-center hover:bg-green-100 transition flex-shrink-0"
        title="¿Cómo funciona el ranking?"
        @click="mostrarAyuda = true"
      >?</button>
    </div>

    <!-- Cargando -->
    <div v-if="cargando" class="flex items-center justify-center py-16 gap-3 text-gray-400">
      <i class="pi pi-spin pi-spinner text-2xl text-green-500" />
      <span class="text-sm">Cargando ranking…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-xl p-4 text-red-700 text-sm flex gap-2 items-start">
      <i class="pi pi-exclamation-triangle mt-0.5 flex-shrink-0" />{{ error }}
    </div>

    <template v-else>
      <!-- Sin equipos -->
      <div v-if="!lista.length" class="flex flex-col items-center justify-center py-16 text-gray-400 gap-2">
        <i class="pi pi-inbox text-4xl" />
        <p class="text-sm">No hay equipos activos.</p>
      </div>

      <template v-else>
        <!-- ── MÓVIL + TABLET: tarjetas ── -->
        <div class="xl:hidden flex flex-col gap-3">
          <div
            v-for="eq in lista"
            :key="eq.equipo_id"
            class="border rounded-2xl p-4 shadow-sm cursor-pointer active:scale-[0.99] transition-all"
            :class="estilos(eq.medalla)!.card"
            @click="router.push(`/equipo/${eq.equipo_id}`)"
          >
            <!-- Fila superior -->
            <div class="flex items-center gap-3 mb-3">
              <!-- Posición -->
              <span
                class="text-2xl font-extrabold w-10 flex-shrink-0 text-center"
                :class="estilos(eq.medalla)!.pos"
              >{{ eq.posicion }}</span>

              <!-- Color dot + nombre -->
              <div class="flex items-center gap-2 flex-1 min-w-0">
                <span
                  class="w-4 h-4 rounded-full flex-shrink-0 border border-white shadow-sm"
                  :style="{ background: eq.equipo_color ?? '#6b7280' }"
                />
                <span class="font-bold text-gray-800 text-base truncate">{{ eq.equipo_nombre }}</span>
              </div>

              <!-- Medalla badge -->
              <span
                class="text-xs font-bold px-2 py-1 rounded-full flex-shrink-0 flex items-center gap-1"
                :class="estilos(eq.medalla)!.badge"
              >
                {{ MEDALLA_EMOJI[eq.medalla ?? 'participacion'] }}
                <span class="hidden sm:inline">{{ medallaLabel(eq.medalla) }}</span>
              </span>
            </div>

            <!-- Puntaje escala destacado -->
            <div class="flex items-baseline justify-between px-1 mb-3">
              <span class="text-xs text-gray-400 font-medium">Puntaje final</span>
              <span class="text-2xl font-extrabold text-green-700">{{ eq.pts_escala }}<span class="text-sm font-semibold text-gray-400 ml-1">/ 1000</span></span>
            </div>

            <!-- Grid de componentes -->
            <div class="grid grid-cols-4 gap-1.5">
              <div class="flex flex-col items-center bg-white/70 rounded-xl py-2 px-1">
                <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">INS</span>
                <span class="text-sm font-bold text-gray-700">{{ eq.pts_inscripcion }}</span>
              </div>
              <div class="flex flex-col items-center bg-white/70 rounded-xl py-2 px-1">
                <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">RUB</span>
                <span class="text-sm font-bold text-gray-700">{{ eq.pts_rubrica }}</span>
              </div>
              <div class="flex flex-col items-center bg-white/70 rounded-xl py-2 px-1">
                <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">LID</span>
                <span class="text-sm font-bold text-gray-700">{{ eq.pts_liderazgo }}</span>
              </div>
              <div class="flex flex-col items-center bg-white/70 rounded-xl py-2 px-1">
                <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">ASIS</span>
                <span class="text-sm font-bold text-gray-700">{{ eq.pts_asistencia }}</span>
              </div>
            </div>

            <!-- Fila bonus / deméritos / bruto -->
            <div class="grid grid-cols-3 gap-1.5 mt-1.5">
              <div class="flex flex-col items-center bg-green-100/60 rounded-xl py-2 px-1">
                <span class="text-[10px] text-green-600 font-semibold uppercase tracking-wide">Bonus</span>
                <span class="text-sm font-bold text-green-700">+{{ eq.pts_bonus }}</span>
              </div>
              <div class="flex flex-col items-center bg-red-50/80 rounded-xl py-2 px-1">
                <span class="text-[10px] text-red-400 font-semibold uppercase tracking-wide">Dem.</span>
                <span class="text-sm font-bold text-red-600">−{{ eq.pts_demeritos }}</span>
              </div>
              <div class="flex flex-col items-center bg-white/80 rounded-xl py-2 px-1 border border-gray-100">
                <span class="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">Bruto</span>
                <span class="text-sm font-bold text-gray-800">{{ eq.pts_bruto }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- ── DESKTOP GRANDE: tabla ── -->
        <div class="hidden xl:block overflow-x-auto rounded-2xl border border-gray-200 shadow-sm">
          <table class="w-full border-collapse text-sm bg-white">
            <thead>
              <tr class="bg-green-50">
                <th class="px-3 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200 w-10">#</th>
                <th class="px-3 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200">Equipo</th>
                <th class="px-3 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200">Medalla</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200" title="Inscripción">INS</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200" title="Rúbrica">RUB</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200" title="Liderazgo">LID</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200" title="Asistencia">ASIS</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-500 uppercase tracking-wide border-b border-gray-200">Base</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-green-600 uppercase tracking-wide border-b border-gray-200">+Bonus</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-red-500 uppercase tracking-wide border-b border-gray-200">−Dem.</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-gray-600 uppercase tracking-wide border-b border-gray-200">Bruto</th>
                <th class="px-3 py-3 text-right text-xs font-bold text-green-700 uppercase tracking-wide border-b border-gray-200">/ 1000</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="eq in lista"
                :key="eq.equipo_id"
                class="border-b border-gray-100 hover:bg-green-50/40 cursor-pointer transition last:border-0"
                @click="router.push(`/equipo/${eq.equipo_id}`)"
              >
                <td class="px-3 py-3 font-bold text-gray-400 text-sm">{{ eq.posicion }}°</td>
                <td class="px-3 py-3">
                  <div class="flex items-center gap-2">
                    <span
                      class="w-3.5 h-3.5 rounded-full flex-shrink-0"
                      :style="{ background: eq.equipo_color ?? '#6b7280' }"
                    />
                    <span class="font-semibold text-gray-800 text-sm">{{ eq.equipo_nombre }}</span>
                  </div>
                </td>
                <td class="px-3 py-3">
                  <span
                    class="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full"
                    :class="estilos(eq.medalla)!.badge"
                  >
                    {{ MEDALLA_EMOJI[eq.medalla ?? 'participacion'] }}
                    {{ medallaLabel(eq.medalla) }}
                  </span>
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-600">{{ eq.pts_inscripcion }}</td>
                <td class="px-3 py-3 text-right text-sm text-gray-600">{{ eq.pts_rubrica }}</td>
                <td class="px-3 py-3 text-right text-sm text-gray-600">{{ eq.pts_liderazgo }}</td>
                <td class="px-3 py-3 text-right text-sm text-gray-600">{{ eq.pts_asistencia }}</td>
                <td class="px-3 py-3 text-right text-sm font-semibold text-gray-700">{{ eq.pts_base }}</td>
                <td class="px-3 py-3 text-right text-sm font-semibold text-green-600">+{{ eq.pts_bonus }}</td>
                <td class="px-3 py-3 text-right text-sm font-semibold text-red-500">−{{ eq.pts_demeritos }}</td>
                <td class="px-3 py-3 text-right text-sm font-bold text-gray-800">{{ eq.pts_bruto }}</td>
                <td class="px-3 py-3 text-right text-base font-extrabold text-green-700">{{ eq.pts_escala }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>

    <!-- Modal de ayuda -->
    <Teleport to="body">
      <div
        v-if="mostrarAyuda"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="mostrarAyuda = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[80vh] overflow-y-auto">
          <div class="flex justify-center pt-3 sm:hidden">
            <div class="w-10 h-1 rounded-full bg-gray-200" />
          </div>
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-trophy text-green-600 text-sm" />
              </div>
              <h2 class="font-bold text-gray-800">Ranking — ¿cómo funciona?</h2>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-400" @click="mostrarAyuda = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>
          <div class="px-5 py-4 space-y-4 text-sm text-gray-700">
            <div>
              <p class="font-semibold text-gray-800 mb-1"><i class="pi pi-info-circle mr-1.5 text-green-600" />Vista interna</p>
              <p class="text-xs text-gray-600 leading-relaxed">Este ranking muestra el desglose completo de puntajes incluyendo todos los componentes. Es visible solo para administradores y evaluadores.</p>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-2"><i class="pi pi-list mr-1.5 text-green-600" />Componentes del puntaje</p>
              <ul class="text-xs text-gray-600 space-y-1.5">
                <li><strong>INS</strong> — Inscripción (hasta 100 pts según fecha)</li>
                <li><strong>RUB</strong> — Rúbrica de observaciones diarias</li>
                <li><strong>LID</strong> — Liderazgo (4 indicadores × 4 días)</li>
                <li><strong>ASIS</strong> — Asistencia a estelar y eventos</li>
                <li><strong class="text-green-600">+Bonus</strong> — B1 y B2 validados (tope 200 pts)</li>
                <li><strong class="text-red-500">−Dem.</strong> — D1–D6 aplicados (sin tope)</li>
                <li><strong>Bruto</strong> — Base + Bonus − Deméritos</li>
                <li><strong class="text-green-700">/ 1000</strong> — Escala final sobre 1000 pts</li>
              </ul>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-1"><i class="pi pi-star mr-1.5 text-green-600" />Medallas</p>
              <div class="text-xs text-gray-600 space-y-1">
                <div class="flex items-center gap-2">🥇 <span class="bg-yellow-100 text-yellow-800 font-bold px-1.5 rounded">Oro</span></div>
                <div class="flex items-center gap-2">🥈 <span class="bg-slate-100 text-slate-700 font-bold px-1.5 rounded">Plata</span></div>
                <div class="flex items-center gap-2">🥉 <span class="bg-amber-100 text-amber-800 font-bold px-1.5 rounded">Bronce</span></div>
                <div class="flex items-center gap-2">🎖 <span class="bg-gray-100 text-gray-600 font-bold px-1.5 rounded">Participación</span></div>
              </div>
            </div>
          </div>
          <div class="px-5 pb-5">
            <button class="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm transition" @click="mostrarAyuda = false">Entendido</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
