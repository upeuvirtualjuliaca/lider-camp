<script setup lang="ts">
import MatrixGroup from './MatrixGroup.vue'
import type { MGroupData } from './MatrixGroup.vue'

export interface MTeamData { id: string; nombre: string; color: string; iniciales: string; pct: number }

defineProps<{
  equipos:   MTeamData[]
  grupos:    MGroupData[]
  totalRow:  string[]
  compact?:  boolean
}>()

const emit = defineEmits<{ toggleGroup: [id: string] }>()
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full border-collapse" :style="{ minWidth: compact ? '840px' : '900px', fontSize: compact ? '12px' : '13px' }">

      <!-- ── Sticky header ── -->
      <thead class="sticky top-0 z-20">
        <tr class="border-b border-[#E3E7E4]">
          <!-- Criterion column header -->
          <th
            class="sticky left-0 z-30 bg-white px-4 py-2.5 text-left text-[12px] font-semibold text-[#5B6660] align-bottom"
            :style="{ minWidth: compact ? '210px' : '250px' }"
          >
            Criterio
          </th>

          <!-- Team column headers -->
          <th
            v-for="eq in equipos"
            :key="eq.id"
            :title="eq.nombre"
            class="bg-white py-2 px-0 text-center align-top"
            :style="{ minWidth: compact ? '0' : '56px' }"
          >
            <div class="flex flex-col items-center gap-1">
              <span
                class="rounded-[8px] flex items-center justify-center text-white font-bold"
                :style="{
                  width:  compact ? '28px' : '30px',
                  height: compact ? '28px' : '30px',
                  fontSize: compact ? '10px' : '11px',
                  background: eq.color,
                }"
              >{{ eq.iniciales }}</span>
              <span class="text-[10px] font-semibold text-[#5B6660]">{{ eq.pct }}%</span>
            </div>
          </th>

          <!-- Advance header -->
          <th
            class="bg-white px-3 py-2.5 text-right text-[12px] font-semibold text-[#5B6660] align-bottom"
            :style="{ minWidth: compact ? '56px' : '80px' }"
          >
            {{ compact ? 'Av.' : 'Avance' }}
          </th>
        </tr>
      </thead>

      <!-- ── Groups ── -->
      <MatrixGroup
        v-for="g in grupos"
        :key="g.id"
        :grupo="g"
        :cols="equipos.length"
        :compact="compact"
        @toggle="emit('toggleGroup', g.id)"
      />

      <!-- ── Total row ── -->
      <tbody>
        <tr class="bg-[#EEF1EF]">
          <td
            class="sticky left-0 z-[5] bg-[#EEF1EF] px-4 py-3 text-[13px] font-bold text-[#16201B]"
            :style="{ minWidth: compact ? '210px' : '250px' }"
          >
            Total del día
          </td>
          <td
            v-for="(v, i) in totalRow"
            :key="i"
            class="py-3 px-0 text-center text-[13px] font-bold text-[#16201B]"
          >
            {{ v }}
          </td>
          <td />
        </tr>
      </tbody>

    </table>
  </div>
</template>
