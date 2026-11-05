<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  nombre: string
  done: number
  total: number
  max?: number
  active: boolean
  isLiderazgo?: boolean
}>()

const chip = computed(() => {
  if (props.isLiderazgo) return { text: `${props.done}/${props.total}`, cls: 'bg-[#E1F3EA] text-[#0B6B4B]' }
  if (props.done === props.total && props.total > 0) return { text: 'Completo', cls: 'bg-[#E1F3EA] text-[#0B6B4B]' }
  if (props.done > 0) return { text: 'En curso', cls: 'bg-[#FFF1D6] text-[#7A4F00]' }
  return { text: 'Sin empezar', cls: 'bg-[#EEF0EE] text-[#4A544F]' }
})
</script>

<template>
  <button
    class="w-full flex items-center gap-2.5 min-h-[56px] px-3 rounded-xl border text-left transition-colors font-[inherit]"
    :class="[
      active ? 'bg-[#E1F3EA] border-[#0E7C59]' : 'bg-white border-transparent hover:bg-[#F4F6F4]',
      isLiderazgo ? 'border-[#A7F3D0] bg-gradient-to-r from-[#ECFDF5] to-white' : ''
    ]"
  >
    <span
      v-if="isLiderazgo"
      class="w-6 h-6 rounded-lg bg-[#E1F3EA] text-[#0E7C59] flex items-center justify-center flex-shrink-0"
      aria-hidden="true"
    >
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
    </span>

    <span class="flex-1 min-w-0 flex flex-col items-start gap-0.5">
      <span class="text-[14px] font-semibold text-[#16201B]">{{ nombre }}</span>
      <span class="text-[12px] text-[#5B6660]">
        {{ done }}/{{ total }}<template v-if="max !== undefined"> · máx. {{ max }}</template>
      </span>
    </span>

    <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0" :class="chip.cls">
      {{ chip.text }}
    </span>
  </button>
</template>
