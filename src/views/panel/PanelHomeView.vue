<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore }    from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import { useDiasCampamento }  from '@/composables/useDiasCampamento'
import { inicioService, type ProgresoHoy, type MisNotasHoy, type MisIncidencias, type PendienteHoy, type ActividadHoy, type DiaCampamentoConEstado } from '@/modules/inicio/services/inicio.service'
import ProgressRing from '@/components/ui/ProgressRing.vue'

const router    = useRouter()
const session   = useSessionStore()
const campStore = useCampamentoStore()
const { dias, momentos, cargar: cargarDias, labelDia, detectarMomentoActual } = useDiasCampamento()

// ── Estado ────────────────────────────────────────────────────────────────────
const cargando        = ref(true)
const progreso        = ref<ProgresoHoy>({ registradas: 0, esperadas: 0, porcentaje: 0 })
const misNotas        = ref<MisNotasHoy>({ total: 0, ultima: null })
const misIncidencias  = ref<MisIncidencias>({ total: 0, pendientes: 0 })
const pendientes      = ref<PendienteHoy[]>([])
const actividades     = ref<ActividadHoy[]>([])
const diasCamp        = ref<DiaCampamentoConEstado[]>([])
const momentoActual   = ref('')

// ── Saludo ────────────────────────────────────────────────────────────────────
const saludo = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Buenos días'
  if (h < 19) return 'Buenas tardes'
  return 'Buenas noches'
})

const primerNombre = computed(() => {
  const n = session.perfil?.nombre_completo ?? 'Usuario'
  return n.split(' ')[0]
})

// ── Subtítulo de día ──────────────────────────────────────────────────────────
const subtituloDia = computed(() => {
  if (!momentoActual.value || dias.value.length === 0) return ''
  const idx = dias.value.findIndex(d => d.codigo === momentoActual.value)
  if (idx === -1) return ''
  return `Día ${idx + 1} de ${dias.value.length} · ${labelDia(momentoActual.value)}`
})

// ── Próxima actividad (para móvil) ───────────────────────────────────────────
const proximaActividad = computed<ActividadHoy | null>(() => {
  const ahora = new Date()
  const hhmm = `${String(ahora.getHours()).padStart(2,'0')}:${String(ahora.getMinutes()).padStart(2,'0')}`
  // Buscar la primera "programada" o "en_curso" cuya hora >= ahora
  return actividades.value.find(a =>
    (a.estado === 'programada' || a.estado === 'en_curso') &&
    (a.hora_inicio ?? '') >= hhmm
  ) ?? actividades.value.find(a => a.estado === 'programada') ?? null
})

// ── Estado de actividad → config visual ──────────────────────────────────────
function estadoActividadCfg(estado: string): { label: string; cls: string; timeColor: string } {
  switch (estado) {
    case 'realizada':   return { label: 'Realizada',   cls: 'bg-[#E1F3EA] text-[#0B6B4B]', timeColor: 'text-[#5B6660]' }
    case 'en_curso':    return { label: 'En curso',    cls: 'bg-[#FFF1D6] text-[#7A4F00]', timeColor: 'text-[#0B6B4B]' }
    case 'cancelada':   return { label: 'Cancelada',   cls: 'bg-[#FEE2E2] text-[#991B1B] line-through', timeColor: 'text-[#9CA3AF]' }
    default:            return { label: 'Programada',  cls: 'bg-[#EEF0EE] text-[#4A544F]', timeColor: 'text-[#5B6660]' }
  }
}

// ── Estado de día ─────────────────────────────────────────────────────────────
function diaEstadoCfg(d: DiaCampamentoConEstado) {
  if (d.publicado) return { label: 'Publicado', cls: 'border-[#0E7C59] bg-[#E1F3EA] text-[#0B6B4B]' }
  if (d.cerrado)   return { label: 'Cerrado',   cls: 'border-[#E3E7E4] bg-[#F3F4F6] text-[#6B7280]' }
  if (d.esHoy)     return { label: 'Abierto',   cls: 'border-[#0E7C59] bg-white text-[#0B6B4B]' }
  return { label: 'Próximo', cls: 'border-[#E3E7E4] bg-white text-[#9CA3AF]' }
}

// ── Hora formateada ───────────────────────────────────────────────────────────
function formatHora(h: string | null) {
  if (!h) return '—'
  return h.slice(0, 5)
}

// ── Cargar datos ──────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  try {
    await cargarDias()
    momentoActual.value = detectarMomentoActual()

    const campId = campStore.selectedId
    if (!campId || !momentoActual.value) return

    const evalId = session.user?.id ?? ''

    const [p, n, inc, pend, acts, dc] = await Promise.all([
      inicioService.getProgresoHoy(campId, momentoActual.value),
      inicioService.getMisNotasHoy(campId, momentoActual.value, evalId),
      inicioService.getMisIncidencias(campId, evalId),
      inicioService.getPendientesHoy(campId, momentoActual.value, evalId),
      inicioService.getActividadesHoy(campId, momentoActual.value),
      inicioService.getDiasCampamento(campId),
    ])

    progreso.value       = p
    misNotas.value       = n
    misIncidencias.value = inc
    pendientes.value     = pend
    actividades.value    = acts
    diasCamp.value       = dc
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)

function irAEvaluar() {
  router.push('/panel/evaluar')
}
</script>

<template>
  <div class="max-w-[1120px] mx-auto px-4 py-6 md:px-6 xl:px-8 xl:py-8 flex flex-col gap-5">

    <!-- ═══════════════════════════════════════════
         SALUDO + BOTÓN
    ═══════════════════════════════════════════ -->
    <section class="flex items-end justify-between gap-4">
      <div class="flex flex-col gap-1">
        <span v-if="subtituloDia" class="text-[13px] font-semibold text-[#0B6B4B]">{{ subtituloDia }}</span>
        <div v-else class="h-4 w-40 bg-[#E3E7E4] rounded animate-pulse" />
        <h1 class="m-0 text-[26px] md:text-[28px] font-bold tracking-tight leading-tight">{{ saludo }}, {{ primerNombre }}</h1>
        <span v-if="!cargando" class="text-[14px] text-[#5B6660]">
          <template v-if="campStore.cerrado">El campamento está cerrado.</template>
          <template v-else-if="progreso.esperadas > 0">Tienes {{ progreso.esperadas - progreso.registradas }} notas pendientes hoy.</template>
          <template v-else>No hay notas programadas para hoy.</template>
        </span>
        <div v-else class="h-4 w-56 bg-[#E3E7E4] rounded animate-pulse" />
      </div>
      <!-- Botón continuar: oculto en móvil (va dentro de la tarjeta verde) -->
      <button
        class="hidden md:flex h-12 items-center gap-2.5 px-5 rounded-xl bg-[#0E7C59] text-white text-[15px] font-semibold flex-shrink-0 border-0 cursor-pointer hover:bg-[#0B6B4B] transition-colors"
        @click="irAEvaluar"
      >
        Continuar evaluando
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
      </button>
    </section>

    <!-- ═══════════════════════════════════════════
         TARJETA VERDE PROGRESO (solo móvil)
    ═══════════════════════════════════════════ -->
    <section class="md:hidden">
      <div
        class="bg-[#0E7C59] text-white rounded-2xl p-4 flex flex-col gap-3 cursor-pointer"
        @click="irAEvaluar"
      >
        <div class="flex items-center justify-between text-[13px] opacity-90">
          <span>Avance de hoy</span>
          <span v-if="!cargando">{{ progreso.registradas }} de {{ progreso.esperadas }} notas</span>
          <span v-else class="w-20 h-4 bg-white/20 rounded animate-pulse" />
        </div>
        <span v-if="!cargando" class="text-[32px] font-bold tracking-tight">{{ progreso.porcentaje }}%</span>
        <div v-else class="h-9 w-16 bg-white/20 rounded animate-pulse" />
        <div class="h-1.5 bg-white/25 rounded-full overflow-hidden">
          <div class="h-1.5 bg-white rounded-full transition-all" :style="{ width: progreso.porcentaje + '%' }" />
        </div>
        <span class="h-11 rounded-xl bg-white text-[#0B6B4B] flex items-center justify-center gap-2 text-[15px] font-bold">
          Continuar evaluando
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </span>
      </div>
    </section>

    <!-- ═══════════════════════════════════════════
         STAT CARDS
    ═══════════════════════════════════════════ -->
    <section aria-label="Resumen de hoy" class="grid grid-cols-2 md:grid-cols-3 gap-3 md:gap-4">

      <!-- Avance del día (anillo) — solo tablet/desktop -->
      <div class="hidden md:flex bg-white border border-[#E3E7E4] rounded-2xl p-4 items-center gap-4">
        <template v-if="cargando">
          <div class="w-14 h-14 rounded-full bg-[#E3E7E4] animate-pulse flex-shrink-0" />
          <div class="flex flex-col gap-1 flex-1">
            <div class="h-3 w-20 bg-[#E3E7E4] rounded animate-pulse" />
            <div class="h-5 w-28 bg-[#E3E7E4] rounded animate-pulse" />
          </div>
        </template>
        <template v-else>
          <ProgressRing :percent="progreso.porcentaje" :size="56" :thickness="8" />
          <div class="flex flex-col gap-0.5">
            <span class="text-[13px] text-[#5B6660]">Avance del día</span>
            <span class="text-[18px] font-bold">{{ progreso.registradas }} de {{ progreso.esperadas }}</span>
          </div>
        </template>
      </div>

      <!-- Mis notas hoy -->
      <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
        <span class="text-[12px] md:text-[13px] text-[#5B6660]">Mis notas hoy</span>
        <template v-if="cargando">
          <div class="h-7 w-12 bg-[#E3E7E4] rounded animate-pulse" />
        </template>
        <template v-else>
          <span class="text-[24px] md:text-[26px] font-bold">{{ misNotas.total }}</span>
          <span v-if="misNotas.ultima" class="text-[11px] text-[#5B6660] leading-tight truncate">
            Última: {{ misNotas.ultima.criterio }} · hace {{ misNotas.ultima.haceMin }}min
          </span>
        </template>
      </div>

      <!-- Mis incidencias -->
      <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex flex-col gap-1">
        <span class="text-[12px] md:text-[13px] text-[#5B6660]">Mis incidencias</span>
        <template v-if="cargando">
          <div class="h-7 w-8 bg-[#E3E7E4] rounded animate-pulse" />
        </template>
        <template v-else>
          <span class="text-[24px] md:text-[26px] font-bold">{{ misIncidencias.total }}</span>
          <span v-if="misIncidencias.pendientes > 0" class="text-[11px] md:text-[12px] text-[#7A4F00] font-semibold">
            {{ misIncidencias.pendientes }} sin validar
          </span>
        </template>
      </div>

    </section>

    <!-- ═══════════════════════════════════════════
         PENDIENTES + ACTIVIDADES (2 col en md+)
    ═══════════════════════════════════════════ -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-5 items-start">

      <!-- PENDIENTES DE HOY -->
      <section aria-label="Pendientes de hoy" class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">
        <div class="flex justify-between items-center px-4 md:px-5 py-4 border-b border-[#EEF1EF]">
          <h2 class="m-0 text-[15px] md:text-[16px] font-bold">Pendientes de hoy</h2>
          <button class="text-[13px] font-semibold text-[#0B6B4B] border-0 bg-transparent cursor-pointer" @click="irAEvaluar">Ver todo</button>
        </div>

        <!-- Skeleton -->
        <template v-if="cargando">
          <div v-for="i in 4" :key="i" class="flex items-center gap-3 px-4 md:px-5 py-4 border-b border-[#EEF1EF] last:border-0">
            <div class="flex-1 flex flex-col gap-1.5">
              <div class="h-4 w-40 bg-[#E3E7E4] rounded animate-pulse" />
              <div class="h-3 w-24 bg-[#E3E7E4] rounded animate-pulse" />
            </div>
            <div class="h-5 w-20 bg-[#E3E7E4] rounded animate-pulse" />
          </div>
        </template>

        <!-- Vacío -->
        <template v-else-if="pendientes.length === 0">
          <div class="flex flex-col items-center gap-2 px-5 py-8 text-center">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#0E7C59" stroke-width="1.5" aria-hidden="true"><path d="M20 6L9 17l-5-5"/></svg>
            <span class="text-[14px] font-semibold text-[#16201B]">¡Todo calificado por hoy!</span>
            <span class="text-[12px] text-[#5B6660]">No quedan pendientes para este día.</span>
          </div>
        </template>

        <!-- Lista (máx 5 en desktop, 3 en móvil) -->
        <ul v-else class="list-none m-0 p-0">
          <li
            v-for="(p, idx) in pendientes.slice(0, 5)"
            :key="p.programacion_id"
            class="border-b border-[#EEF1EF] last:border-0 md:block"
            :class="idx >= 3 ? 'hidden md:block' : ''"
          >
            <button
              class="w-full flex items-center gap-3 px-4 md:px-5 min-h-[58px] border-0 bg-transparent text-left cursor-pointer hover:bg-[#F9FAF9] transition-colors"
              @click="irAEvaluar"
            >
              <span class="flex-1 min-w-0 flex flex-col gap-0.5">
                <span class="text-[14px] md:text-[14px] font-semibold truncate">{{ p.nombre }}</span>
                <span class="text-[12px] text-[#5B6660]">{{ p.categoria }}</span>
              </span>
              <span class="text-[12px] font-semibold px-2 py-1 rounded-md bg-[#FFF1D6] text-[#7A4F00] flex-shrink-0">{{ p.faltantes }} equipos</span>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
            </button>
          </li>
        </ul>
      </section>

      <!-- ACTIVIDADES DE HOY (tablet/desktop) + PRÓXIMA ACTIVIDAD (móvil) -->
      <div class="flex flex-col gap-5">

        <!-- Actividades de hoy (tablet/desktop) -->
        <section aria-label="Actividades de hoy" class="hidden md:flex bg-white border border-[#E3E7E4] rounded-2xl p-4 md:p-5 flex-col gap-4">
          <h2 class="m-0 text-[15px] md:text-[16px] font-bold">Actividades de hoy</h2>

          <!-- Skeleton -->
          <template v-if="cargando">
            <div v-for="i in 4" :key="i" class="flex gap-3 items-start">
              <div class="h-4 w-10 bg-[#E3E7E4] rounded animate-pulse flex-shrink-0" />
              <div class="flex-1 flex flex-col gap-1">
                <div class="h-4 w-36 bg-[#E3E7E4] rounded animate-pulse" />
                <div class="h-3 w-24 bg-[#E3E7E4] rounded animate-pulse" />
              </div>
              <div class="h-5 w-20 bg-[#E3E7E4] rounded animate-pulse flex-shrink-0" />
            </div>
          </template>

          <!-- Vacío -->
          <div v-else-if="actividades.length === 0" class="text-[13px] text-[#5B6660] py-2">
            No hay actividades programadas hoy.
          </div>

          <!-- Lista -->
          <div v-else v-for="a in actividades" :key="a.id" class="flex gap-3 items-start">
            <span
              class="w-[46px] flex-shrink-0 text-[13px] font-bold"
              :class="estadoActividadCfg(a.estado).timeColor"
            >{{ formatHora(a.hora_inicio) }}</span>
            <span class="flex-1 flex flex-col gap-0.5 min-w-0">
              <span class="text-[14px] font-semibold">{{ a.nombre }}</span>
              <span v-if="a.lugar" class="text-[12px] text-[#5B6660]">{{ a.lugar }}</span>
            </span>
            <span
              class="text-[11px] font-semibold px-2 py-0.5 rounded-md flex-shrink-0"
              :class="estadoActividadCfg(a.estado).cls"
            >{{ estadoActividadCfg(a.estado).label }}</span>
          </div>
        </section>

        <!-- Próxima actividad (solo móvil) -->
        <section aria-label="Próxima actividad" class="md:hidden flex flex-col gap-2">
          <h2 class="m-0 mx-0.5 text-[12px] font-bold uppercase tracking-widest text-[#5B6660]">Próxima actividad</h2>
          <template v-if="cargando">
            <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex items-center gap-4">
              <div class="w-[52px] h-[52px] rounded-xl bg-[#E3E7E4] animate-pulse flex-shrink-0" />
              <div class="flex-1 flex flex-col gap-2">
                <div class="h-4 w-36 bg-[#E3E7E4] rounded animate-pulse" />
                <div class="h-3 w-24 bg-[#E3E7E4] rounded animate-pulse" />
              </div>
            </div>
          </template>
          <template v-else-if="proximaActividad">
            <div class="bg-white border border-[#E3E7E4] rounded-2xl p-4 flex items-center gap-4">
              <span class="w-[52px] h-[52px] rounded-xl bg-[#F4F6F4] border border-[#DCE1DD] flex flex-col items-center justify-center flex-shrink-0">
                <span class="text-[14px] font-bold">{{ formatHora(proximaActividad.hora_inicio) }}</span>
              </span>
              <span class="flex-1 flex flex-col gap-0.5 min-w-0">
                <span class="text-[15px] font-semibold">{{ proximaActividad.nombre }}</span>
                <span v-if="proximaActividad.lugar" class="text-[12px] text-[#5B6660]">{{ proximaActividad.lugar }}</span>
              </span>
            </div>
          </template>
          <div v-else class="bg-white border border-[#E3E7E4] rounded-2xl px-4 py-5 text-[13px] text-[#5B6660]">
            No hay actividades próximas hoy.
          </div>
        </section>

        <!-- Días del campamento (solo desktop ≥1280px) -->
        <section aria-label="Días del campamento" class="hidden xl:flex flex-col gap-3">
          <h2 class="m-0 text-[12px] font-bold uppercase tracking-widest text-[#5B6660]">Días del campamento</h2>
          <div class="grid grid-cols-4 gap-3">
            <template v-if="cargando">
              <div v-for="i in 4" :key="i" class="h-[72px] bg-[#E3E7E4] rounded-2xl animate-pulse" />
            </template>
            <template v-else-if="diasCamp.length === 0">
              <div class="col-span-4 text-[13px] text-[#5B6660]">Sin días configurados.</div>
            </template>
            <div
              v-else
              v-for="d in diasCamp" :key="d.codigo"
              class="bg-white rounded-2xl border-2 px-3 py-3 flex flex-col gap-0.5"
              :class="diaEstadoCfg(d).cls"
            >
              <span class="text-[13px] font-bold">{{ d.codigo }}</span>
              <span class="text-[11px] opacity-70">{{ new Date(d.fecha + 'T12:00:00').toLocaleDateString('es', { day: 'numeric', month: 'short' }) }}</span>
              <span class="text-[10px] font-semibold uppercase tracking-wide mt-0.5">{{ diaEstadoCfg(d).label }}</span>
            </div>
          </div>
        </section>

      </div>
    </div>

  </div>
</template>
