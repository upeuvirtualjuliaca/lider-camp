<script setup lang="ts">
defineProps<{ activo: 'equipos' | 'criterios' }>()
const emit = defineEmits<{ change: [tab: 'equipos' | 'criterios'] }>()
</script>

<template>
  <div class="flex p-1 bg-[#EEF1EF] rounded-xl" role="tablist" aria-label="Modo de evaluación">
    <button
      role="tab"
      :aria-selected="activo === 'equipos'"
      @click="emit('change', 'equipos')"
      class="h-9 px-4 rounded-[9px] text-[14px] transition-colors whitespace-nowrap"
      :class="activo === 'equipos'
        ? 'bg-white text-[#0E7C59] font-semibold shadow-[0_1px_2px_rgba(22,32,27,0.12)]'
        : 'text-[#5B6660] font-medium'"
    >Por equipo</button>
    <button
      role="tab"
      :aria-selected="activo === 'criterios'"
      @click="emit('change', 'criterios')"
      class="h-9 px-4 rounded-[9px] text-[14px] transition-colors whitespace-nowrap"
      :class="activo === 'criterios'
        ? 'bg-white text-[#0E7C59] font-semibold shadow-[0_1px_2px_rgba(22,32,27,0.12)]'
        : 'text-[#5B6660] font-medium'"
    >Por criterio</button>
  </div>
</template>
