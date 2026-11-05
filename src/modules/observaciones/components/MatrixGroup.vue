<script setup lang="ts">
import MatrixCell from './MatrixCell.vue'

export interface MCellData { tipo: 'puntaje'|'pendiente'|'na'|'cancelado'; valor?: string|null }
export interface MRowData  { id: string; nombre: string; maxLabel: string; nameColor: string; cells: MCellData[]; av: string; avColor: string }
export interface MGroupData { id: string; nombre: string; rows: MRowData[]; summary: string; pct: number; open: boolean }

const props = defineProps<{
  grupo: MGroupData
  cols: number       // number of team columns
  compact?: boolean  // tablet mode: smaller cells
}>()

const emit = defineEmits<{ toggle: [] }>()

function gridStyle() {
  const first = props.compact ? '210px' : '250px'
  const last  = props.compact ? '56px'  : '80px'
  const mid   = `repeat(${props.cols}, minmax(${props.compact ? 0 : 56}px, 1fr))`
  return `display: grid; grid-template-columns: ${first} ${mid} ${last};`
}
</script>

<template>
  <tbody>
    <!-- Group header row -->
    <tr>
      <td
        :colspan="cols + 2"
        class="border-b border-[#EEF1EF] bg-[#FAFBFA] p-0"
      >
        <button
          class="w-full flex items-center gap-2.5 px-4 py-2.5 text-left bg-transparent border-0 cursor-pointer font-[inherit] hover:bg-[#F4F6F4] transition-colors"
          :aria-expanded="grupo.open"
          @click="emit('toggle')"
        >
          <span
            class="flex-shrink-0 transition-transform duration-150"
            :style="{ transform: grupo.open ? 'rotate(90deg)' : 'rotate(0deg)' }"
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
          </span>
          <span class="text-[12px] font-bold uppercase tracking-[0.6px] text-[#3A4540]">{{ grupo.nombre }}</span>
          <span class="text-[12px] text-[#5B6660]">{{ grupo.summary }}</span>
          <span class="ml-auto w-[120px] h-[5px] bg-[#E3E7E4] rounded-full overflow-hidden flex-shrink-0">
            <span
              class="block h-full bg-[#0E7C59] rounded-full"
              :style="{ width: grupo.pct + '%' }"
            />
          </span>
        </button>
      </td>
    </tr>

    <!-- Data rows -->
    <template v-if="grupo.open">
      <tr v-for="row in grupo.rows" :key="row.id" class="border-b border-[#EEF1EF] hover:bg-[#FAFBFA]">
        <!-- Sticky criterion column -->
        <td
          class="sticky left-0 z-[5] bg-white px-4 py-1.5 align-middle"
          :style="{ minWidth: compact ? '210px' : '250px' }"
        >
          <div class="flex flex-col justify-center">
            <span class="text-[13px] font-medium leading-snug" :style="{ color: row.nameColor }">
              {{ row.nombre }}
            </span>
            <span class="text-[11px] text-[#8A948E]">{{ row.maxLabel }}</span>
          </div>
        </td>
        <!-- Cell columns -->
        <td
          v-for="(cell, ci) in row.cells"
          :key="ci"
          class="px-[3px] py-[3px] align-middle"
        >
          <MatrixCell :tipo="cell.tipo" :valor="cell.valor ?? null" :small="compact" />
        </td>
        <!-- Advance column -->
        <td
          class="text-right px-3 align-middle"
          :style="{ minWidth: compact ? '56px' : '80px' }"
        >
          <span
            class="text-[12px] font-semibold"
            :style="{ color: row.avColor }"
          >{{ row.av }}</span>
        </td>
      </tr>
    </template>
  </tbody>
</template>
