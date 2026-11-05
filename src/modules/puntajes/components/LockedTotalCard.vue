<script setup lang="ts">
defineProps<{
  diasCerrados:  number
  totalDias:     number      // always 4
  ultimoDiaLabel: string    // e.g. "jueves"  — empty string when no day has data
}>()

const emit = defineEmits<{ verUltimoDia: [] }>()
</script>

<template>
  <section
    class="bg-white border border-[#E3E7E4] rounded-2xl p-6 xl:p-7 flex flex-col md:flex-row md:flex-wrap items-center gap-5 md:gap-6 text-center md:text-left"
    aria-label="Ranking total bloqueado"
  >
    <!-- Lock icon -->
    <span class="w-16 h-16 rounded-[18px] bg-[#EEF1EF] flex items-center justify-center flex-shrink-0" aria-hidden="true">
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>
      </svg>
    </span>

    <!-- Text + progress -->
    <div class="flex-1 min-w-0 md:min-w-[220px] flex flex-col gap-1.5">
      <span class="text-[17px] xl:text-[18px] font-bold text-[#16201B] leading-snug">
        El ranking total se calcula al cerrar el campamento
      </span>
      <span class="text-[13px] xl:text-[14px] text-[#5B6660] leading-relaxed">
        Mientras tanto puedes revisar el ranking de cada día.
        Días cerrados: <strong class="text-[#16201B]">{{ diasCerrados }} de {{ totalDias }}</strong>.
      </span>
      <!-- 4-segment bar -->
      <div
        class="grid gap-1 mt-1.5 max-w-[280px] mx-auto md:mx-0"
        :style="{ gridTemplateColumns: `repeat(${totalDias}, minmax(0, 1fr))` }"
        role="progressbar"
        :aria-valuenow="diasCerrados"
        :aria-valuemax="totalDias"
      >
        <span
          v-for="i in totalDias"
          :key="i"
          class="h-1.5 rounded-full"
          :class="i <= diasCerrados ? 'bg-[#0E7C59]' : 'bg-[#E3E7E4]'"
        />
      </div>
    </div>

    <!-- CTA button -->
    <button
      v-if="ultimoDiaLabel"
      class="h-11 xl:h-[44px] px-5 rounded-xl border-0 bg-[#0E7C59] text-white text-[14px] font-semibold font-[inherit] cursor-pointer hover:bg-[#0B6B4B] transition-colors w-full md:w-auto"
      @click="emit('verUltimoDia')"
    >
      Ver ranking del {{ ultimoDiaLabel }}
    </button>
  </section>
</template>
