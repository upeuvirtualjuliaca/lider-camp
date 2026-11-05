<script setup lang="ts">
export interface PodiumRow {
  equipo_id: string
  equipo_nombre: string
  equipo_color: string
  iniciales: string
  posicion: number
  posLabel: string
  pts_total: number
}

defineProps<{
  rows: PodiumRow[]   // sorted 1st→3rd; length may be < 3
}>()
</script>

<template>
  <!--
    Visual order:
      Mobile & Web (xl): 2nd – 1st – 3rd  (center card is tallest)
      Tablet (md…xl):    1st – 2nd – 3rd  (horizontal cards, all same height)

    rows[0] = 1st place  → CSS order: xl:order-1 md:order-0  (mobile: order-1)
    rows[1] = 2nd place  → CSS order: xl:order-0 md:order-1  (mobile: order-0)
    rows[2] = 3rd place  → CSS order: 2 always
  -->
  <section aria-label="Podio" class="grid grid-cols-3 gap-2 md:gap-3 xl:gap-4 items-end md:items-stretch xl:items-end">
    <template v-for="(row, idx) in rows.slice(0, 3)" :key="row.equipo_id">

      <!-- ── WEB + MOBILE: column card ── -->
      <div
        class="md:hidden xl:flex flex-col items-center gap-2 rounded-2xl border-2 py-3 px-2 xl:py-5 xl:px-4"
        :class="[
          idx === 0
            ? 'border-[#0E7C59] bg-white xl:py-[26px] xl:px-4'
            : 'border-[#E3E7E4] bg-white',
          idx === 1 ? 'order-0' : idx === 0 ? 'order-1' : 'order-2',
        ]"
        :style="idx === 0 ? 'box-shadow: 0 0 0 3px #E1F3EA;' : ''"
      >
        <!-- position badge -->
        <span
          class="text-[11px] xl:text-[13px] font-bold px-2 py-0.5 rounded-[9px]"
          :class="idx === 0 ? 'bg-[#0E7C59] text-white' : 'bg-[#EEF1EF] text-[#3A4540]'"
        >{{ row.posLabel }}</span>
        <!-- avatar -->
        <span
          class="w-10 h-10 xl:w-[52px] xl:h-[52px] rounded-[12px] xl:rounded-[14px] flex items-center justify-center font-bold text-[13px] xl:text-[17px] text-white"
          :style="{ background: row.equipo_color }"
          aria-hidden="true"
        >{{ row.iniciales }}</span>
        <!-- name -->
        <span class="text-[11px] xl:text-[16px] font-bold text-center leading-tight line-clamp-2">{{ row.equipo_nombre }}</span>
        <!-- score -->
        <span class="text-[17px] xl:text-[28px] font-bold leading-none">
          {{ row.pts_total }}
          <span class="text-[11px] xl:text-[13px] font-medium text-[#5B6660]">pts</span>
        </span>
      </div>

      <!-- ── TABLET: horizontal card ── -->
      <div
        class="hidden md:flex xl:hidden items-center gap-3 rounded-2xl border-2 p-3.5"
        :class="[
          idx === 0
            ? 'border-[#0E7C59] bg-white'
            : 'border-[#E3E7E4] bg-white',
          'order-' + idx,
        ]"
        :style="idx === 0 ? 'box-shadow: 0 0 0 3px #E1F3EA;' : ''"
      >
        <span
          class="text-[13px] font-bold px-2.5 py-1 rounded-[10px] flex-shrink-0"
          :class="idx === 0 ? 'bg-[#0E7C59] text-white' : 'bg-[#EEF1EF] text-[#3A4540]'"
        >{{ row.posLabel }}</span>
        <span
          class="w-[42px] h-[42px] rounded-[12px] flex items-center justify-center font-bold text-[14px] text-white flex-shrink-0"
          :style="{ background: row.equipo_color }"
          aria-hidden="true"
        >{{ row.iniciales }}</span>
        <div class="flex-1 min-w-0 flex flex-col">
          <span class="text-[14px] xl:text-[15px] font-bold leading-tight truncate">{{ row.equipo_nombre }}</span>
          <span class="text-[20px] xl:text-[22px] font-bold leading-none mt-0.5">
            {{ row.pts_total }}
            <span class="text-[12px] font-medium text-[#5B6660]">pts</span>
          </span>
        </div>
      </div>

    </template>
  </section>
</template>
