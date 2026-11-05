<script setup lang="ts">
import type { Equipo } from '@/modules/equipos/services/equipos.service'

const props = defineProps<{
  equipos: Equipo[]
  modelValue: string
  titulo?: string
  excluir?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [id: string]
}>()

function iniciales(nombre: string) {
  return nombre.split(' ').filter(Boolean).slice(0, 2).map(w => (w[0] ?? '').toUpperCase()).join('')
}
</script>

<template>
  <div>
    <p v-if="titulo" class="text-[13px] font-semibold text-[#5B6660] mb-2 mt-0">{{ titulo }}</p>
    <div class="grid grid-cols-2 gap-2">
      <button
        v-for="eq in equipos.filter(e => e.id !== excluir)"
        :key="eq.id"
        class="flex items-center gap-2.5 px-3 py-2.5 rounded-xl border-2 text-left transition-colors font-[inherit]"
        :class="modelValue === eq.id
          ? 'bg-[#E1F3EA] border-[#0E7C59]'
          : 'bg-white border-[#E3E7E4] hover:bg-[#F4F6F4]'"
        @click="emit('update:modelValue', eq.id)"
      >
        <span
          class="w-[30px] h-[30px] rounded-full flex items-center justify-center text-[11px] font-bold text-white flex-shrink-0"
          :style="{ background: eq.color ?? '#0E7C59' }"
        >{{ iniciales(eq.nombre) }}</span>
        <span class="text-[13px] font-semibold text-[#16201B] leading-tight min-w-0 truncate">{{ eq.nombre }}</span>
      </button>
    </div>
  </div>
</template>
