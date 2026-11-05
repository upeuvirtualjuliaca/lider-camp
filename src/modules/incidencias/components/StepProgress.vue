<script setup lang="ts">
defineProps<{
  paso: number      // 1-based
  total: number
  nombres: string[]
}>()
</script>

<template>
  <div class="flex flex-col gap-2">
    <!-- Bar segments -->
    <div class="flex gap-1">
      <div
        v-for="n in total"
        :key="n"
        class="flex-1 h-1 rounded-full transition-colors"
        :class="n <= paso ? 'bg-[#0E7C59]' : 'bg-[#E3E7E4]'"
      />
    </div>
    <!-- Label -->
    <span class="text-[12px] text-[#5B6660]">
      Paso {{ paso }} de {{ total }} · <strong class="text-[#16201B]">{{ nombres[paso - 1] ?? '' }}</strong>
    </span>
  </div>
</template>
