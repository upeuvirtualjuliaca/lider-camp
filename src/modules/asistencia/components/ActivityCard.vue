<script setup lang="ts">
import type { ActividadConProgramacion } from '@/modules/asistencia/services/asistencia.service'

const props = defineProps<{
  actividad: ActividadConProgramacion
  notasDone: number
  notasTotal: number
  active?: boolean
}>()

function statusConfig(estado: string) {
  if (estado === 'realizada') return { text: 'Realizada', bg: 'bg-[#E1F3EA]', color: 'text-[#0B6B4B]' }
  if (estado === 'cancelada') return { text: 'Cancelada', bg: 'bg-[#FFE4E4]', color: 'text-[#9B1C1C]' }
  return { text: 'Programada', bg: 'bg-[#EEF0EE]', color: 'text-[#4A544F]' }
}

const cfg = statusConfig(props.actividad.estado ?? '')
const pct = props.notasTotal > 0 ? Math.round(props.notasDone / props.notasTotal * 100) : 0
const hora = props.actividad.hora_inicio ? props.actividad.hora_inicio.slice(0, 5) : ''
</script>

<template>
  <!-- Mobile: horizontal layout -->
  <div
    class="bg-white rounded-2xl border p-3.5 flex gap-3.5 transition-colors cursor-pointer"
    :class="[
      actividad.estado === 'cancelada' ? 'opacity-60' : '',
      active ? 'border-[#0E7C59] shadow-[0_0_0_3px_#E1F3EA]' : 'border-[#E3E7E4] hover:border-[#C5CFC9]'
    ]"
  >
    <!-- Time badge -->
    <span
      class="w-14 h-14 flex-shrink-0 flex flex-col items-center justify-center rounded-xl"
      :class="actividad.estado === 'cancelada' ? 'bg-[#F4F6F4]' : 'bg-[#E1F3EA]'"
    >
      <span
        class="text-[15px] font-bold"
        :class="actividad.estado === 'cancelada' ? 'text-[#5B6660]' : 'text-[#0B6B4B]'"
      >{{ hora || '—' }}</span>
    </span>

    <!-- Content -->
    <span class="flex-1 min-w-0 flex flex-col gap-1.5">
      <span class="flex items-start justify-between gap-2">
        <span
          class="text-[15px] font-semibold leading-snug"
          :class="actividad.estado === 'cancelada' ? 'line-through text-[#5B6660]' : 'text-[#16201B]'"
        >{{ actividad.nombre }}</span>
        <span
          class="flex-shrink-0 text-[11px] font-semibold px-2 py-0.5 rounded-[6px]"
          :class="[cfg.bg, cfg.color]"
        >{{ cfg.text }}</span>
      </span>

      <span class="text-[12px] text-[#5B6660]">
        <template v-if="actividad.lugar">{{ actividad.lugar }}</template>
        <template v-if="actividad.lugar && (actividad.programacion as any)?.criterios?.nombre"> · </template>
        <template v-if="(actividad.programacion as any)?.criterios?.nombre">{{ (actividad.programacion as any).criterios.nombre }}</template>
      </span>

      <span v-if="notasTotal > 0" class="flex items-center gap-2 text-[12px] text-[#5B6660]">
        <span class="flex-1 h-1 bg-[#E3E7E4] rounded overflow-hidden">
          <span class="block h-1 bg-[#0E7C59]" :style="{ width: pct + '%' }" />
        </span>
        {{ notasDone }} de {{ notasTotal }} notas
      </span>
    </span>
  </div>
</template>
