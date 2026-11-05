<script setup lang="ts">
defineProps<{
  percent: number   // 0–100
  size?: number     // outer diameter px, default 56
  thickness?: number // inner inset px, default 8
}>()
</script>

<template>
  <div
    :style="{
      width:  (size ?? 56) + 'px',
      height: (size ?? 56) + 'px',
      borderRadius: '50%',
      background: `conic-gradient(#0E7C59 ${percent}%, #E3E7E4 0)`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: '0',
    }"
    role="img"
    :aria-label="`${percent} por ciento`"
  >
    <div
      :style="{
        width:  (size ?? 56) - (thickness ?? 8) * 2 + 'px',
        height: (size ?? 56) - (thickness ?? 8) * 2 + 'px',
        borderRadius: '50%',
        background: '#FFFFFF',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: ((size ?? 56) < 50 ? 11 : 13) + 'px',
        fontWeight: '700',
        color: '#16201B',
      }"
    >{{ percent }}%</div>
  </div>
</template>
