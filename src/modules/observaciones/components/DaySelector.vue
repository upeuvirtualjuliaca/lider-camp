<script setup lang="ts">
import type { DiasEvaluacion } from '@/modules/observaciones/services/observaciones.service'

const props = defineProps<{
  momentos: string[]
  activo: string
  dias: DiasEvaluacion[]
  fechas: Record<string, string>
  hoy: string
  labelDia: (m: string) => string
}>()
const emit = defineEmits<{ select: [m: string] }>()

function isCerrado(m: string) {
  return props.dias.find(d => d.momento === m)?.cerrado ?? false
}
</script>

<template>
  <div class="flex gap-2 overflow-x-auto" style="overflow-y: visible; scrollbar-width: none; -webkit-overflow-scrolling: touch">
    <button
      v-for="m in momentos"
      :key="m"
      @click="emit('select', m)"
      class="flex-shrink-0 h-11 px-4 rounded-xl xl:h-10 xl:px-3.5 xl:rounded-[10px] text-[13px] font-semibold border transition-colors whitespace-nowrap flex items-center gap-1.5"
      :class="[
        activo === m
          ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
          : 'bg-white text-[#16201B] border-[#DCE1DD] hover:border-[#0E7C59]',
        isCerrado(m) ? 'opacity-60' : ''
      ]"
    >
      {{ labelDia(m) }}
      <span
        v-if="fechas[m] === hoy"
        class="text-[0.6rem] font-extrabold uppercase tracking-wide"
        :class="activo === m ? 'opacity-80' : 'text-[#0E7C59]'"
      >Hoy</span>
      <svg v-if="isCerrado(m)" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
    </button>
  </div>
</template>
