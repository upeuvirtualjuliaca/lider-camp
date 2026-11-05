<script setup lang="ts">
import CompositionBar from './CompositionBar.vue'

export interface TableRow {
  equipo_id:       string
  equipo_nombre:   string
  equipo_color:    string
  iniciales:       string
  posicion:        number
  posLabel:        string
  pts_rubrica:     number
  pts_actividades: number
  pts_bonus:       number
  pts_demeritos:   number
  pts_total:       number
}

const props = defineProps<{
  rows:     TableRow[]
  maxTotal: number    // highest pts_total in the list (for composition bar scale)
  periodo:  string    // e.g. "jueves 5 de noviembre"
}>()
</script>

<template>
  <section class="bg-white border border-[#E3E7E4] rounded-2xl overflow-hidden">

    <!-- Table header row -->
    <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3.5 border-b border-[#EEF1EF]">
      <h2 class="m-0 text-[15px] font-bold">Posiciones · {{ periodo }}</h2>
      <!-- Legend (web only) -->
      <div class="hidden xl:flex flex-wrap gap-3.5 text-[12px] text-[#5B6660]">
        <span class="flex items-center gap-1.5">
          <span class="w-3 h-2 rounded-sm bg-[#0E7C59]" aria-hidden="true" />Rúbrica
        </span>
        <span class="flex items-center gap-1.5">
          <span class="w-3 h-2 rounded-sm bg-[#2E6FA8]" aria-hidden="true" />Actividades
        </span>
        <span class="flex items-center gap-1.5">
          <span class="w-3 h-2 rounded-sm bg-[#9BCFB5]" aria-hidden="true" />Bonus
        </span>
      </div>
    </div>

    <div class="overflow-x-auto">
      <!-- Column headers -->
      <div
        role="row"
        class="hidden xl:grid gap-2 px-4 py-2.5 border-b border-[#E3E7E4] text-[12px] font-semibold text-[#5B6660]"
        style="grid-template-columns: 56px minmax(180px, 1.4fr) minmax(150px, 1fr) 80px 90px 70px 80px 84px;"
      >
        <span role="columnheader">Pos.</span>
        <span role="columnheader">Equipo</span>
        <span role="columnheader">Composición</span>
        <span role="columnheader" class="text-right">Rúbrica</span>
        <span role="columnheader" class="text-right">Actividades</span>
        <span role="columnheader" class="text-right">Bonus</span>
        <span role="columnheader" class="text-right">Deméritos</span>
        <span role="columnheader" class="text-right">Total</span>
      </div>
      <!-- Tablet headers -->
      <div
        role="row"
        class="xl:hidden grid gap-2 px-4 py-2.5 border-b border-[#E3E7E4] text-[12px] font-semibold text-[#5B6660]"
        style="grid-template-columns: 56px 1fr 90px 100px 100px 90px;"
      >
        <span role="columnheader">Pos.</span>
        <span role="columnheader">Equipo</span>
        <span role="columnheader" class="text-right">Rúbrica</span>
        <span role="columnheader" class="text-right">Actividades</span>
        <span role="columnheader" class="text-right">Ajustes</span>
        <span role="columnheader" class="text-right">Total</span>
      </div>

      <!-- Data rows -->
      <div
        v-for="row in rows"
        :key="row.equipo_id"
        role="row"
        class="border-b border-[#EEF1EF] last:border-b-0 items-center px-4 min-h-[52px] box-border"
      >
        <!-- Web row -->
        <div
          class="hidden xl:grid gap-2 items-center py-2.5"
          style="grid-template-columns: 56px minmax(180px, 1.4fr) minmax(150px, 1fr) 80px 90px 70px 80px 84px;"
        >
          <span
            role="cell"
            class="text-[15px] font-bold"
            :class="row.posicion <= 3 ? 'text-[#16201B]' : 'text-[#5B6660]'"
          >{{ row.posLabel }}</span>

          <span role="cell" class="flex items-center gap-2.5 min-w-0">
            <span
              class="w-8 h-8 rounded-[9px] flex items-center justify-center font-bold text-[12px] text-white flex-shrink-0"
              :style="{ background: row.equipo_color }"
              aria-hidden="true"
            >{{ row.iniciales }}</span>
            <span class="text-[14px] font-semibold truncate">{{ row.equipo_nombre }}</span>
          </span>

          <span role="cell">
            <CompositionBar
              :rub="row.pts_rubrica"
              :act="row.pts_actividades"
              :bonus="row.pts_bonus"
              :max="maxTotal"
            />
          </span>

          <span role="cell" class="text-right text-[13px]">{{ row.pts_rubrica }}</span>
          <span role="cell" class="text-right text-[13px]">{{ row.pts_actividades }}</span>
          <span
            role="cell"
            class="text-right text-[13px]"
            :class="row.pts_bonus > 0 ? 'text-[#0B6B4B] font-semibold' : 'text-[#8A948E]'"
          >{{ row.pts_bonus > 0 ? '+' + row.pts_bonus : row.pts_bonus }}</span>
          <span
            role="cell"
            class="text-right text-[13px]"
            :class="row.pts_demeritos > 0 ? 'text-[#A3261F] font-semibold' : 'text-[#8A948E]'"
          >{{ row.pts_demeritos > 0 ? '−' + row.pts_demeritos : row.pts_demeritos }}</span>
          <span role="cell" class="text-right text-[15px] font-bold">{{ row.pts_total }}</span>
        </div>

        <!-- Tablet row -->
        <div
          class="xl:hidden grid gap-2 items-center py-2"
          style="grid-template-columns: 56px 1fr 90px 100px 100px 90px;"
        >
          <span
            role="cell"
            class="text-[15px] font-bold"
            :class="row.posicion <= 3 ? 'text-[#16201B]' : 'text-[#5B6660]'"
          >{{ row.posLabel }}</span>

          <span role="cell" class="flex items-center gap-2.5 min-w-0">
            <span
              class="w-[30px] h-[30px] rounded-[8px] flex items-center justify-center font-bold text-[11px] text-white flex-shrink-0"
              :style="{ background: row.equipo_color }"
              aria-hidden="true"
            >{{ row.iniciales }}</span>
            <span class="text-[14px] font-semibold truncate">{{ row.equipo_nombre }}</span>
          </span>

          <span role="cell" class="text-right text-[13px]">{{ row.pts_rubrica }}</span>
          <span role="cell" class="text-right text-[13px]">{{ row.pts_actividades }}</span>
          <!-- Ajustes = bonus - deméritos -->
          <span
            role="cell"
            class="text-right text-[13px] font-semibold"
            :class="(row.pts_bonus - row.pts_demeritos) > 0
              ? 'text-[#0B6B4B]'
              : (row.pts_bonus - row.pts_demeritos) < 0
                ? 'text-[#A3261F]'
                : 'text-[#8A948E]'"
          >
            {{ (row.pts_bonus - row.pts_demeritos) > 0
              ? '+' + (row.pts_bonus - row.pts_demeritos)
              : (row.pts_bonus - row.pts_demeritos) < 0
                ? '−' + Math.abs(row.pts_bonus - row.pts_demeritos)
                : '0' }}
          </span>
          <span role="cell" class="text-right text-[15px] font-bold">{{ row.pts_total }}</span>
        </div>
      </div>
    </div>

    <!-- Footer note -->
    <p class="m-0 px-4 py-3 text-[12px] text-[#5B6660]">
      Los empates comparten posición. Total = rúbrica + actividades + bonus − deméritos (solo validados).
    </p>

  </section>
</template>
