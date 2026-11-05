<script setup lang="ts">
import type { Incidencia } from '../services/incidencias.service'

const props = defineProps<{
  inc: Incidencia
  tipo: 'bonus' | 'demerito'
  equipoNombre: string
  selected?: boolean
}>()

const ESTADO: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Registrada',  cls: 'bg-[#EEF0EE] text-[#4A544F]' },
  descargo:   { label: 'En descargo', cls: 'bg-[#FFF1D6] text-[#7A4F00]' },
  validado:   { label: 'Validada',    cls: 'bg-[#E1F3EA] text-[#0B6B4B]' },
  rechazado:  { label: 'Rechazada',   cls: 'bg-[#FDECEC] text-[#A3261F]' },
}

function estadoLabel(e: string) { return ESTADO[e]?.label ?? e }
function estadoCls(e: string)   { return ESTADO[e]?.cls ?? 'bg-[#EEF0EE] text-[#4A544F]' }

function ptsCls() {
  if (props.inc.estado === 'rechazado') return 'text-[#8A948E]'
  return props.tipo === 'bonus' ? 'text-[#0B6B4B]' : 'text-[#A3261F]'
}

function ptsLabel() {
  const prefix = props.tipo === 'bonus' ? '+' : '−'
  return `${prefix}${props.inc.puntos}`
}

function horaCorta(h: string) {
  return (h ?? '').slice(0, 5)
}
</script>

<template>
  <li
    class="border-b border-[#EEF1EF] last:border-b-0 cursor-pointer transition-colors"
    :class="selected ? 'bg-[#E1F3EA]' : 'hover:bg-[#F4F6F4]'"
  >
    <div class="flex items-start gap-3 px-4 py-3.5">
      <!-- Code badge -->
      <span
        class="flex-shrink-0 w-10 h-10 rounded-[10px] flex items-center justify-center text-[13px] font-bold"
        :class="tipo === 'bonus' ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#FDECEC] text-[#A3261F]'"
      >{{ inc.codigo }}</span>

      <!-- Content -->
      <div class="flex-1 min-w-0 flex flex-col gap-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-[14px] font-semibold text-[#16201B] truncate">{{ equipoNombre }}</span>
          <span class="text-[14px] font-bold flex-shrink-0" :class="ptsCls()">{{ ptsLabel() }}</span>
        </div>
        <span class="text-[13px] text-[#3A4540] leading-snug line-clamp-2">{{ inc.hecho }}</span>
        <div class="flex items-center gap-2">
          <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px]" :class="estadoCls(inc.estado)">{{ estadoLabel(inc.estado) }}</span>
          <span class="text-[12px] text-[#5B6660]">{{ horaCorta(inc.hora) }}</span>
        </div>
      </div>
    </div>
  </li>
</template>
