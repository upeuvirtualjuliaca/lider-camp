<script setup lang="ts">
defineProps<{
  nombre: string
  nameColor: string
  dots: string[]          // array of 12 hex color strings
  av: string
  avColor: string
}>()
</script>

<template>
  <li class="border-b border-[#EEF1EF] last:border-b-0 px-4 py-3 flex flex-col gap-2">
    <div class="flex items-center justify-between gap-2">
      <span class="text-[14px] font-semibold leading-snug" :style="{ color: nameColor }">{{ nombre }}</span>
      <span class="text-[13px] font-bold flex-shrink-0" :style="{ color: avColor }">{{ av }}</span>
    </div>
    <span aria-hidden="true" class="grid gap-[3px]" :style="{ gridTemplateColumns: `repeat(${dots.length}, minmax(0,1fr))` }">
      <span
        v-for="(c, i) in dots"
        :key="i"
        class="h-[8px] rounded-[2px]"
        :style="{ background: c }"
      />
    </span>
  </li>
</template>
