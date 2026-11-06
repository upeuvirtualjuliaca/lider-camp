<script setup lang="ts">
import { computed } from 'vue'
import type { IncidenciaDetalle } from '@/modules/incidencias/services/incidencias.service'

const props = defineProps<{
  detalle: IncidenciaDetalle | null
  cargando: boolean
  error: string
  detUrls: Record<string, string>
  comentarioAdmin: string
  accionando: boolean
  accionError: string
  pendPos: { pos: number; total: number } | null
  tipoDe: (codigo: string) => 'bonus' | 'demerito'
  nombreEquipo: (id: string) => string
}>()

const emit = defineEmits<{
  'update:comentarioAdmin': [val: string]
  validar: []
  abrirRechazo: []
  reabrir: []
}>()

const ESTADO_CFG: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Registrada',  cls: 'bg-[#EEF0EE] text-[#4A544F]' },
  descargo:   { label: 'En descargo', cls: 'bg-[#FFF1D6] text-[#7A4F00]' },
  validado:   { label: 'Validada',    cls: 'bg-[#E1F3EA] text-[#0B6B4B]' },
  rechazado:  { label: 'Rechazada',   cls: 'bg-[#FDECEC] text-[#A3261F]' },
}

const isPending  = computed(() => props.detalle?.estado === 'registrado' || props.detalle?.estado === 'descargo')
const isResolved = computed(() => props.detalle?.estado === 'validado'   || props.detalle?.estado === 'rechazado')

function fmt(fecha: string, hora: string | null): string {
  const DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
  const d = new Date(fecha + 'T12:00:00')
  return `${DIAS[d.getDay()]} ${d.getDate()}${hora ? ' · ' + hora.slice(0, 5) : ''}`
}

function fmtDate(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('es-PE', { day: 'numeric', month: 'long', year: 'numeric' })
}
</script>

<template>
  <!-- Loading -->
  <div v-if="cargando" class="flex-1 flex flex-col gap-3 p-5">
    <div class="h-20 bg-[#EEF1EF] rounded-2xl animate-pulse" />
    <div class="h-32 bg-[#EEF1EF] rounded-2xl animate-pulse" />
    <div class="h-40 bg-[#EEF1EF] rounded-2xl animate-pulse" />
  </div>

  <!-- Error -->
  <div v-else-if="error" class="flex-1 flex items-center justify-center p-6 text-[14px] text-[#A3261F]">
    {{ error }}
  </div>

  <!-- Empty state (no selection) -->
  <div v-else-if="!detalle" class="flex-1 flex flex-col items-center justify-center gap-3 p-6 text-center">
    <span class="w-12 h-12 rounded-full bg-[#EEF1EF] flex items-center justify-center">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 11l3 3 8-8"/><rect x="3" y="3" width="18" height="18" rx="2"/></svg>
    </span>
    <span class="text-[14px] text-[#5B6660]">Selecciona una incidencia para revisarla</span>
  </div>

  <!-- Detail -->
  <template v-else>
    <div class="flex-1 overflow-y-auto p-4 md:p-[18px] md:px-[22px] flex flex-col gap-3">

      <!-- Header card: code + nombre + team/fecha -->
      <section class="bg-white border border-[#E3E7E4] rounded-2xl p-3.5 flex flex-col gap-3">
        <div class="flex items-center gap-2.5">
          <span
            class="w-10 h-10 rounded-[10px] flex items-center justify-center text-[13px] font-bold flex-shrink-0"
            :class="tipoDe(detalle.codigo) === 'bonus' ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#FDECEC] text-[#A3261F]'"
          >{{ detalle.codigo }}</span>
          <div class="flex-1 min-w-0">
            <div class="text-[15px] font-bold leading-tight">{{ detalle.codigo_info?.nombre ?? detalle.codigo }}</div>
            <div class="text-[12px] text-[#5B6660] mt-0.5">
              {{ nombreEquipo(detalle.equipo_id) }} · {{ fmt(detalle.fecha, detalle.hora) }}
            </div>
          </div>
          <span
            class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0"
            :class="ESTADO_CFG[detalle.estado]?.cls ?? 'bg-[#EEF0EE] text-[#4A544F]'"
          >{{ ESTADO_CFG[detalle.estado]?.label ?? detalle.estado }}</span>
        </div>

        <!-- Mini cards: Puntos / Alcance / Registró -->
        <div class="grid grid-cols-3 gap-2">
          <div class="bg-[#F4F6F4] rounded-[10px] px-2.5 py-2">
            <div class="text-[11px] text-[#5B6660] mb-0.5">Puntos</div>
            <div
              class="text-[14px] font-bold"
              :class="tipoDe(detalle.codigo) === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'"
            >{{ tipoDe(detalle.codigo) === 'bonus' ? '+' : '−' }}{{ detalle.puntos }}</div>
          </div>
          <div class="bg-[#F4F6F4] rounded-[10px] px-2.5 py-2">
            <div class="text-[11px] text-[#5B6660] mb-0.5">Alcance</div>
            <div class="text-[13px] font-semibold truncate">{{ detalle.alcance ?? '—' }}</div>
          </div>
          <div class="bg-[#F4F6F4] rounded-[10px] px-2.5 py-2">
            <div class="text-[11px] text-[#5B6660] mb-0.5">Registró</div>
            <div class="text-[13px] font-semibold truncate">{{ detalle.evaluador_nombre ?? '—' }}</div>
          </div>
        </div>

        <!-- Hecho -->
        <p class="text-[14px] leading-relaxed m-0">{{ detalle.hecho }}</p>

        <!-- Evidencia -->
        <template v-if="detalle.evidencias?.length">
          <div class="flex gap-2 flex-wrap">
            <a
              v-for="ev in detalle.evidencias" :key="ev.id"
              :href="detUrls[ev.id] ?? '#'"
              target="_blank"
              class="block"
            >
              <img
                v-if="ev.tipo_archivo?.startsWith('image')"
                :src="detUrls[ev.id]"
                alt="evidencia"
                class="w-[110px] h-[84px] object-cover rounded-xl border border-[#E3E7E4]"
              />
              <div v-else class="w-[110px] h-[84px] rounded-xl border border-[#E3E7E4] bg-[#F4F6F4] flex flex-col items-center justify-center gap-1 text-[12px] text-[#5B6660] p-2 text-center">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="2" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                <span class="truncate max-w-full">{{ ev.nombre_original }}</span>
              </div>
            </a>
          </div>
        </template>
        <div v-else class="h-[84px] rounded-xl bg-[#EEF1EF] border border-[#DCE1DD] flex items-center justify-center text-[13px] text-[#5B6660]">
          Sin evidencia adjunta
        </div>
      </section>

      <!-- ── PENDING: admin comment ── -->
      <template v-if="isPending">
        <label class="flex flex-col gap-1.5">
          <span class="text-[12px] font-bold uppercase tracking-[0.6px] text-[#5B6660]">Comentario del administrador</span>
          <textarea
            :value="comentarioAdmin"
            @input="emit('update:comentarioAdmin', ($event.target as HTMLTextAreaElement).value)"
            placeholder="Observaciones o justificación para aplicar esta incidencia…"
            class="min-h-[72px] border border-[#DCE1DD] rounded-xl px-3 py-2.5 text-[15px] resize-y bg-white outline-none focus:border-[#0E7C59] focus:ring-2 focus:ring-[#0E7C59]/20"
            style="font-family: inherit"
          />
        </label>

        <!-- Action error -->
        <p v-if="accionError" class="text-[13px] text-[#A3261F] px-1">{{ accionError }}</p>
      </template>

      <!-- ── RESOLVED: resolution box ── -->
      <template v-if="isResolved">
        <div
          class="rounded-2xl p-4 flex flex-col gap-2"
          :class="detalle.estado === 'validado' ? 'bg-[#E1F3EA]' : 'bg-[#FDECEC]'"
        >
          <div class="flex items-center gap-2">
            <svg v-if="detalle.estado === 'validado'" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#0B6B4B" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M20 6L9 17l-5-5"/></svg>
            <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#A3261F" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            <span
              class="text-[15px] font-bold"
              :class="detalle.estado === 'validado' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'"
            >{{ detalle.estado === 'validado' ? 'Validada · suma al puntaje' : 'Rechazada · no suma puntos' }}</span>
          </div>
          <p v-if="detalle.motivo_resolucion" class="text-[14px] m-0" :class="detalle.estado === 'validado' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'">
            {{ detalle.motivo_resolucion }}
          </p>
          <p class="text-[12px] m-0" :class="detalle.estado === 'validado' ? 'text-[#0B6B4B]/70' : 'text-[#A3261F]/70'">
            {{ detalle.estado === 'validado' ? 'Validado' : 'Rechazado' }}
            <template v-if="(detalle as any).updated_at"> el {{ fmtDate((detalle as any).updated_at) }}</template>
          </p>
        </div>

        <!-- Reabrir -->
        <button
          class="h-10 w-full border border-[#DCE1DD] bg-white rounded-xl text-[14px] font-semibold text-[#16201B] flex items-center justify-center gap-2 hover:bg-[#F4F6F4] transition-colors disabled:opacity-50"
          :disabled="accionando"
          @click="emit('reabrir')"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M1 4v6h6"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>
          Reabrir revisión
        </button>

        <!-- Action error -->
        <p v-if="accionError" class="text-[13px] text-[#A3261F] px-1">{{ accionError }}</p>
      </template>

    </div><!-- /scrollable body -->

    <!-- ── Action bar (pending, shown in desktop panel; mobile footer is in parent) ── -->
    <div v-if="isPending" class="hidden md:flex flex-shrink-0 flex-col gap-2 px-4 md:px-[18px] py-3 border-t border-[#E3E7E4] bg-white">
      <div class="flex gap-2.5">
        <button
          class="flex-1 h-12 rounded-[14px] border border-[#DCE1DD] bg-white text-[15px] font-semibold text-[#A3261F] hover:bg-[#FDECEC] transition-colors disabled:opacity-50"
          :disabled="accionando"
          @click="emit('abrirRechazo')"
        >Rechazar…</button>
        <button
          class="flex-[2] h-12 rounded-[14px] border-0 bg-[#0E7C59] hover:bg-[#0B6B4B] text-[15px] font-semibold text-white transition-colors disabled:opacity-50"
          :disabled="accionando"
          @click="emit('validar')"
        >Validar</button>
      </div>
    </div>

  </template>
</template>
