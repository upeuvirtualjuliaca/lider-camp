<script setup lang="ts">
import { computed } from 'vue'
import ProgressRing from '@/components/ui/ProgressRing.vue'
import type { Equipo } from '@/modules/equipos/services/equipos.service'

const props = defineProps<{
  equipo: Equipo
  progreso: { calificados: number; total: number }
  active: boolean
}>()

const pct = computed(() =>
  props.progreso.total > 0
    ? Math.round(props.progreso.calificados / props.progreso.total * 100)
    : 0
)

function iniciales(nombre: string): string {
  return nombre.split(' ').filter(Boolean).slice(0, 2).map(w => (w[0] ?? '').toUpperCase()).join('')
}
</script>

<template>
  <button
    class="w-full flex items-center gap-2.5 min-h-[60px] px-2.5 rounded-xl border text-left transition-colors font-[inherit]"
    :class="active
      ? 'bg-[#E1F3EA] border-[#0E7C59]'
      : 'bg-white border-transparent hover:bg-[#F4F6F4]'"
  >
    <span
      class="w-9 h-9 rounded-[10px] flex items-center justify-center font-bold text-[13px] text-white flex-shrink-0"
      :style="{ background: equipo.color }"
      aria-hidden="true"
    >{{ iniciales(equipo.nombre) }}</span>

    <span class="flex-1 min-w-0 flex flex-col items-start gap-0.5">
      <span class="text-[14px] font-semibold text-[#16201B] truncate w-full">{{ equipo.nombre }}</span>
      <span class="text-[12px] text-[#5B6660]">{{ progreso.calificados }}/{{ progreso.total }} criterios</span>
    </span>

    <ProgressRing :percent="pct" :size="34" :thickness="4" />
  </button>
</template>
