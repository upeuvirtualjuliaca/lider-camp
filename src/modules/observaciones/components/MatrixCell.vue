<script setup lang="ts">
defineProps<{
  tipo: 'puntaje' | 'pendiente' | 'na' | 'cancelado'
  valor?: string | null
  small?: boolean
}>()
</script>

<template>
  <div
    class="flex items-center justify-center rounded-[6px] font-[inherit]"
    :class="[
      small ? 'h-[28px] text-[11px]' : 'h-[30px] text-[12px]',
      tipo === 'puntaje'   ? 'bg-[#E1F3EA] text-[#0B6B4B] font-bold'  : '',
      tipo === 'pendiente' ? 'bg-[#FFF1D6]'                             : '',
      tipo === 'na'        ? 'bg-[#F4F6F4] text-[#8A948E]'             : '',
      tipo === 'cancelado' ? 'bg-[#FDECEC] text-[#A3261F] font-semibold' : '',
    ]"
  >
    <template v-if="tipo === 'puntaje'">{{ valor }}</template>
    <template v-else-if="tipo === 'na'">—</template>
    <template v-else-if="tipo === 'cancelado'">×</template>
    <template v-else>
      <span class="w-[6px] h-[6px] rounded-full bg-[#B07800]" />
    </template>
  </div>
</template>
