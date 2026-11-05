<script setup lang="ts">
import type { IncidenciaCodigo } from '../services/incidencias.service'

defineProps<{
  tipo: 'bonus' | 'demerito' | ''
  codigoInfo: IncidenciaCodigo | null
  equipoNombre: string
  hecho: string
  fecha: string
  hora: string
  puntos: number
  guardando?: boolean
  puedeRegistrar: boolean
  error?: string
}>()

const emit = defineEmits<{
  registrar: []
}>()
</script>

<template>
  <div class="bg-white border border-[#E3E7E4] rounded-2xl p-5 flex flex-col gap-4 sticky top-0">
    <h2 class="text-[15px] font-bold text-[#16201B] m-0">Resumen</h2>

    <div class="flex flex-col gap-0 divide-y divide-[#EEF1EF]">
      <div class="flex justify-between gap-2 py-2.5">
        <span class="text-[13px] text-[#5B6660]">Tipo</span>
        <span
          v-if="tipo"
          class="text-[13px] font-semibold"
          :class="tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'"
        >{{ tipo === 'bonus' ? 'Bonus' : 'Demérito' }}</span>
        <span v-else class="text-[13px] text-[#8A948E]">—</span>
      </div>

      <div class="flex justify-between gap-2 py-2.5">
        <span class="text-[13px] text-[#5B6660]">Código</span>
        <span v-if="codigoInfo" class="text-[13px] font-semibold text-[#16201B]">{{ codigoInfo.codigo }} · {{ codigoInfo.nombre }}</span>
        <span v-else class="text-[13px] text-[#8A948E]">—</span>
      </div>

      <div class="flex justify-between gap-2 py-2.5">
        <span class="text-[13px] text-[#5B6660]">Equipo</span>
        <span v-if="equipoNombre" class="text-[13px] font-semibold text-[#16201B]">{{ equipoNombre }}</span>
        <span v-else class="text-[13px] text-[#8A948E]">—</span>
      </div>

      <div v-if="hecho" class="py-2.5">
        <span class="text-[13px] text-[#5B6660] block mb-1">Descripción</span>
        <span class="text-[13px] text-[#16201B] line-clamp-3 leading-snug">{{ hecho }}</span>
      </div>

      <div class="flex justify-between gap-2 py-2.5">
        <span class="text-[13px] text-[#5B6660]">Puntos</span>
        <span
          v-if="codigoInfo"
          class="text-[15px] font-bold"
          :class="tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'"
        >{{ tipo === 'bonus' ? '+' : '−' }}{{ puntos }}</span>
        <span v-else class="text-[13px] text-[#8A948E]">—</span>
      </div>
    </div>

    <!-- Estado chip -->
    <div class="bg-[#EEF0EE] rounded-lg px-3 py-2 text-center">
      <span class="text-[12px] font-semibold text-[#4A544F]">Quedará Registrada, pendiente de validación</span>
    </div>

    <!-- Error -->
    <p v-if="error" class="text-[13px] text-[#A3261F] m-0 text-center">{{ error }}</p>

    <!-- Submit -->
    <button
      class="w-full h-11 rounded-xl text-[14px] font-semibold text-white bg-[#0E7C59] hover:bg-[#0B6B4B] transition-colors disabled:opacity-50 font-[inherit]"
      :disabled="!puedeRegistrar || guardando"
      @click="emit('registrar')"
    >
      <span v-if="guardando">Guardando…</span>
      <span v-else>Registrar incidencia</span>
    </button>
  </div>
</template>
