<script setup lang="ts">
const props = defineProps<{
  rub:   number
  act:   number
  bonus: number
  max:   number
}>()

const pct = (v: number) => props.max > 0 ? Math.min(100, Math.round(v / props.max * 100)) : 0
</script>

<template>
  <div class="flex h-2.5 rounded-full bg-[#EEF1EF] overflow-hidden" aria-hidden="true">
    <div class="h-full bg-[#0E7C59] transition-all duration-300" :style="{ width: pct(rub)   + '%' }" />
    <div class="h-full bg-[#2E6FA8] transition-all duration-300" :style="{ width: pct(act)   + '%' }" />
    <div class="h-full bg-[#9BCFB5] transition-all duration-300" :style="{ width: pct(bonus) + '%' }" />
  </div>
</template>
