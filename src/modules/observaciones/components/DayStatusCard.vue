<script setup lang="ts">
defineProps<{
  cerrado: boolean
  esAdmin: boolean
  pendientes: number
}>()

const emit = defineEmits<{
  cerrar: []
  reabrir: []
}>()
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Estado chip -->
    <div class="flex items-center justify-between gap-2">
      <span class="text-[13px] text-[#5B6660]">Estado del día</span>
      <span
        v-if="!cerrado"
        class="flex items-center gap-1.5 text-[12px] font-semibold px-2.5 py-1 rounded-xl bg-[#E1F3EA] text-[#0B6B4B]"
      >
        <span class="w-[7px] h-[7px] rounded-full bg-[#0E7C59] flex-shrink-0" aria-hidden="true" />
        Abierto · se puede calificar
      </span>
      <span
        v-else
        class="flex items-center gap-1.5 text-[12px] font-semibold px-2.5 py-1 rounded-xl bg-[#EEF1EF] text-[#5B6660]"
      >
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
        Cerrado
      </span>
    </div>

    <!-- Botón (solo admin) -->
    <template v-if="esAdmin">
      <button
        v-if="!cerrado"
        class="h-11 rounded-xl border border-[#16201B] bg-white text-[14px] font-semibold text-[#16201B] flex items-center justify-center gap-2 font-[inherit] cursor-pointer hover:bg-[#F4F6F4] transition-colors"
        @click="emit('cerrar')"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
        Cerrar día
      </button>
      <button
        v-else
        class="h-11 rounded-xl border border-[#DCE1DD] bg-white text-[14px] font-semibold text-[#16201B] flex items-center justify-center gap-2 font-[inherit] cursor-pointer hover:bg-[#F4F6F4] transition-colors"
        @click="emit('reabrir')"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="14" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>
        Reabrir día
      </button>
      <p class="text-[12px] text-[#5B6660] m-0">
        Al cerrar, los evaluadores ya no podrán editar las notas de este día.
      </p>
    </template>
  </div>
</template>
