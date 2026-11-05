<script setup lang="ts">
const props = defineProps<{
  puntajes: number[]
  selected: number | null
  disabled?: boolean
}>()
const emit = defineEmits<{ pick: [pts: number] }>()

function label(pts: number): string {
  return String(pts).replace('.', ',')
}
</script>

<template>
  <div class="grid grid-cols-5 gap-1.5">
    <button
      v-for="pts in puntajes"
      :key="pts"
      :disabled="disabled"
      @click="emit('pick', pts)"
      class="h-12 rounded-xl text-[15px] font-bold border transition-colors"
      :class="[
        selected === pts
          ? 'bg-[#0E7C59] border-[#0E7C59] text-white'
          : 'bg-[#F4F6F4] border-[#DCE1DD] text-[#16201B]',
        disabled ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer hover:border-[#0E7C59]'
      ]"
    >{{ label(pts) }}</button>
  </div>
</template>
