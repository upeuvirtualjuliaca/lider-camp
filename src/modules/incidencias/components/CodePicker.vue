<script setup lang="ts">
defineProps<{
  tipo: 'bonus' | 'demerito' | ''
}>()

const emit = defineEmits<{
  'update:tipo': [v: 'bonus' | 'demerito']
  'update:codigoSel': [v: string]
}>()
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Tipo cards -->
    <div class="grid grid-cols-2 gap-3">
      <button
        class="flex flex-col items-center justify-center gap-1.5 min-h-[84px] rounded-2xl border-2 transition-colors font-[inherit]"
        :class="tipo === 'bonus'
          ? 'bg-[#E1F3EA] border-[#0E7C59] text-[#0B6B4B]'
          : 'bg-white border-[#E3E7E4] text-[#16201B] hover:bg-[#F4F6F4]'"
        @click="emit('update:tipo', 'bonus'); emit('update:codigoSel', '')"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
        <span class="text-[14px] font-bold">Bonus</span>
        <span class="text-[12px] opacity-70">+50 pts máx.</span>
      </button>
      <button
        class="flex flex-col items-center justify-center gap-1.5 min-h-[84px] rounded-2xl border-2 transition-colors font-[inherit]"
        :class="tipo === 'demerito'
          ? 'bg-[#FDECEC] border-[#A3261F] text-[#A3261F]'
          : 'bg-white border-[#E3E7E4] text-[#16201B] hover:bg-[#F4F6F4]'"
        @click="emit('update:tipo', 'demerito'); emit('update:codigoSel', '')"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
        <span class="text-[14px] font-bold">Demérito</span>
        <span class="text-[12px] opacity-70">D1–D6</span>
      </button>
    </div>

  </div>
</template>
