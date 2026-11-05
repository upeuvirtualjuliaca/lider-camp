<script setup lang="ts">
import { ref } from 'vue'
import type { ActividadConProgramacion } from '@/modules/asistencia/services/asistencia.service'

const props = defineProps<{
  actividades: ActividadConProgramacion[]
  selected: ActividadConProgramacion | null
  loading?: boolean
}>()

const emit = defineEmits<{ select: [act: ActividadConProgramacion] }>()
const open = ref(false)

function pick(act: ActividadConProgramacion) {
  if (act.estado === 'cancelada') return
  emit('select', act)
  open.value = false
}

function statusConfig(estado: string) {
  if (estado === 'realizada') return { text: 'Realizada', cls: 'bg-[#E1F3EA] text-[#0B6B4B]' }
  if (estado === 'cancelada') return { text: 'Cancelada', cls: 'bg-[#FFE4E4] text-[#9B1C1C]' }
  return { text: 'Programada', cls: 'bg-[#EEF0EE] text-[#4A544F]' }
}
</script>

<template>
  <div class="relative">
    <!-- Trigger -->
    <button
      type="button"
      @click="open = !open"
      class="w-full flex items-center gap-3 min-h-[52px] px-3.5 py-1.5 rounded-xl border border-[#DCE1DD] bg-[#F4F6F4] text-left transition-colors hover:border-[#B5BDB8]"
      :class="open ? 'border-[#0E7C59] bg-white' : ''"
    >
      <template v-if="loading">
        <span class="text-[13px] text-[#5B6660]">Cargando…</span>
      </template>
      <template v-else-if="selected">
        <span class="text-[14px] font-bold text-[#0E7C59] flex-shrink-0">{{ selected.hora_inicio?.slice(0, 5) ?? '—' }}</span>
        <span class="flex-1 min-w-0">
          <span class="text-[14px] font-semibold text-[#16201B] truncate block">{{ selected.nombre }}</span>
          <span class="text-[12px] text-[#5B6660] truncate block">
            {{ selected.lugar }}<template v-if="selected.lugar && (selected.programacion as any)?.criterios?.nombre"> · </template>{{ (selected.programacion as any)?.criterios?.nombre }}
          </span>
        </span>
        <span
          class="flex-shrink-0 text-[11px] font-semibold px-2 py-0.5 rounded-[6px]"
          :class="statusConfig(selected.estado ?? '').cls"
        >{{ statusConfig(selected.estado ?? '').text }}</span>
      </template>
      <template v-else>
        <span class="text-[14px] text-[#5B6660] flex-1">Selecciona una actividad</span>
      </template>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8A948E" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="flex-shrink-0 transition-transform" :class="open ? 'rotate-180' : ''" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
    </button>

    <!-- Overlay + dropdown -->
    <template v-if="open">
      <div class="fixed inset-0 z-40" @click="open = false" />
      <div class="absolute left-0 right-0 top-full mt-1 z-50 bg-white border border-[#E3E7E4] rounded-2xl shadow-lg overflow-hidden max-h-80 overflow-y-auto">
        <button
          v-for="act in actividades"
          :key="act.id"
          type="button"
          :disabled="act.estado === 'cancelada'"
          @click="pick(act)"
          class="w-full flex items-center gap-3 px-4 py-3 text-left border-b border-[#EEF1EF] last:border-0 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :class="selected?.id === act.id ? 'bg-[#E1F3EA]' : 'hover:bg-[#F4F6F4]'"
        >
          <span class="text-[13px] font-bold flex-shrink-0" :class="act.estado === 'cancelada' ? 'text-[#5B6660]' : 'text-[#0E7C59]'">{{ act.hora_inicio?.slice(0, 5) ?? '—' }}</span>
          <span class="flex-1 min-w-0">
            <span class="text-[14px] font-semibold text-[#16201B] block truncate" :class="act.estado === 'cancelada' ? 'line-through' : ''">{{ act.nombre }}</span>
            <span class="text-[12px] text-[#5B6660]">{{ act.lugar }}</span>
          </span>
          <span class="flex-shrink-0 text-[11px] font-semibold px-2 py-0.5 rounded-[6px]" :class="statusConfig(act.estado ?? '').cls">{{ statusConfig(act.estado ?? '').text }}</span>
        </button>
        <div v-if="!actividades.length" class="px-4 py-6 text-center text-[13px] text-[#5B6660]">Sin actividades este día</div>
      </div>
    </template>
  </div>
</template>
