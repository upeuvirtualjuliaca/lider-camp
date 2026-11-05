<script setup lang="ts">
defineProps<{
  equipo_id:    string
  equipo_color: string
  iniciales:    string
  equipo_nombre: string
  posLabel:     string
  posicion:     number
  pts_total:    number
  pts_rubrica:  number
  pts_actividades: number
  pts_bonus:    number
  pts_demeritos: number
  open:         boolean
}>()

const emit = defineEmits<{ toggle: [] }>()
</script>

<template>
  <li class="border-b border-[#EEF1EF] last:border-b-0">
    <!-- Summary row (always visible) -->
    <button
      class="w-full flex items-center gap-3 px-3.5 min-h-[58px] border-0 bg-white font-[inherit] text-[#16201B] text-left cursor-pointer"
      :aria-expanded="open"
      @click="emit('toggle')"
    >
      <!-- Position -->
      <span
        class="w-8 text-[14px] font-bold flex-shrink-0"
        :class="posicion <= 3 ? 'text-[#16201B]' : 'text-[#5B6660]'"
      >{{ posLabel }}</span>
      <!-- Avatar -->
      <span
        class="w-[34px] h-[34px] rounded-[10px] flex items-center justify-center font-bold text-[12px] text-white flex-shrink-0"
        :style="{ background: equipo_color }"
        aria-hidden="true"
      >{{ iniciales }}</span>
      <!-- Name -->
      <span class="flex-1 min-w-0 text-[14px] font-semibold truncate">{{ equipo_nombre }}</span>
      <!-- Total -->
      <span class="text-[16px] font-bold flex-shrink-0">{{ pts_total }}</span>
      <!-- Chevron -->
      <span
        class="flex-shrink-0 transition-transform duration-150"
        :style="{ transform: open ? 'rotate(180deg)' : 'rotate(0deg)' }"
        aria-hidden="true"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 9l6 6 6-6"/>
        </svg>
      </span>
    </button>

    <!-- Detail panel -->
    <div v-if="open" class="grid grid-cols-4 gap-1.5 px-3.5 pb-3.5">
      <div class="bg-[#F4F6F4] rounded-[10px] p-2 flex flex-col gap-0.5">
        <span class="text-[10px] text-[#5B6660] leading-none">Rúbrica</span>
        <span class="text-[14px] font-bold">{{ pts_rubrica }}</span>
      </div>
      <div class="bg-[#F4F6F4] rounded-[10px] p-2 flex flex-col gap-0.5">
        <span class="text-[10px] text-[#5B6660] leading-none">Actividades</span>
        <span class="text-[14px] font-bold">{{ pts_actividades }}</span>
      </div>
      <div class="bg-[#F4F6F4] rounded-[10px] p-2 flex flex-col gap-0.5">
        <span class="text-[10px] text-[#5B6660] leading-none">Bonus</span>
        <span class="text-[14px] font-bold" :class="pts_bonus > 0 ? 'text-[#0B6B4B]' : 'text-[#8A948E]'">
          {{ pts_bonus > 0 ? '+' + pts_bonus : pts_bonus }}
        </span>
      </div>
      <div class="bg-[#F4F6F4] rounded-[10px] p-2 flex flex-col gap-0.5">
        <span class="text-[10px] text-[#5B6660] leading-none">Deméritos</span>
        <span class="text-[14px] font-bold" :class="pts_demeritos > 0 ? 'text-[#A3261F]' : 'text-[#8A948E]'">
          {{ pts_demeritos > 0 ? '−' + pts_demeritos : pts_demeritos }}
        </span>
      </div>
    </div>
  </li>
</template>
