<script setup lang="ts">
defineProps<{
  countdown: { dias: number; horas: number; minutos: number; segundos: number }
  proximoMomento: string | null
  momentosFuturos: string[]
  labelDia: (m: string) => string
}>()
</script>

<template>
  <div class="flex flex-col items-center justify-center gap-7 px-5 py-16 min-h-[72vh] text-center">
    <div class="w-[88px] h-[88px] rounded-full bg-gradient-to-br from-[#ECFDF5] to-[#D1FAE5] border-2 border-[#A7F3D0] flex items-center justify-center" style="animation: ev-float 3s ease-in-out infinite">
      <span style="font-size: 2.75rem">⛺</span>
    </div>

    <div class="flex flex-col items-center gap-1.5">
      <h2 class="text-[1.3rem] font-extrabold text-[#0F172A] tracking-tight m-0">La evaluación comenzará pronto</h2>
      <p v-if="proximoMomento" class="text-[0.8rem] font-semibold text-[#94A3B8] uppercase tracking-[0.06em] m-0">Próximo día de evaluación</p>
      <p v-if="proximoMomento" class="text-[1rem] font-bold text-[#059669] m-0">{{ labelDia(proximoMomento) }}</p>
    </div>

    <div v-if="proximoMomento" class="flex items-center gap-1.5 bg-gradient-to-br from-[#ECFDF5] to-[#D1FAE5] border border-[#A7F3D0] rounded-[22px] px-6 py-5">
      <template v-for="(item, i) in [
        { val: countdown.dias, lbl: 'días' },
        { val: countdown.horas, lbl: 'horas' },
        { val: countdown.minutos, lbl: 'min' },
        { val: countdown.segundos, lbl: 'seg' },
      ]" :key="item.lbl">
        <div class="flex flex-col items-center gap-1 min-w-[3rem]">
          <span class="text-[2.4rem] font-extrabold leading-none text-[#0F172A] tabular-nums tracking-tight">{{ String(item.val).padStart(2, '0') }}</span>
          <span class="text-[0.58rem] font-bold uppercase tracking-widest text-[#94A3B8]">{{ item.lbl }}</span>
        </div>
        <span v-if="i < 3" class="text-[1.75rem] font-light text-[#6EE7B7] mb-5 select-none" style="animation: ev-blink 1s step-end infinite">:</span>
      </template>
    </div>

    <div v-if="momentosFuturos.length" class="flex flex-col items-center gap-2.5">
      <p class="text-[0.7rem] font-bold uppercase tracking-[0.08em] text-[#CBD5E1] m-0">Días programados</p>
      <div class="flex flex-wrap gap-2 justify-center">
        <span
          v-for="m in momentosFuturos" :key="m"
          class="flex items-center gap-1.5 text-[0.75rem] font-semibold rounded-full px-3.5 py-1.5 border"
          :class="m === proximoMomento
            ? 'text-[#047857] bg-[#D1FAE5] border-[#6EE7B7] font-bold'
            : 'text-[#64748B] bg-[#F8FAFC] border-[#E2E8F0]'"
        >
          <svg v-if="m === proximoMomento" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></svg>
          {{ labelDia(m) }}
        </span>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes ev-float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-7px); } }
@keyframes ev-blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
</style>
