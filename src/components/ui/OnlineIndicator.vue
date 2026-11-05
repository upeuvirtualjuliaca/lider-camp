<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

type Estado = 'online' | 'offline' | 'sync'

const estado = ref<Estado>(navigator.onLine ? 'online' : 'offline')
let syncTimer: ReturnType<typeof setTimeout> | null = null

function onOnline() {
  if (syncTimer) clearTimeout(syncTimer)
  estado.value = 'sync'
  syncTimer = setTimeout(() => { estado.value = 'online' }, 2500)
}

function onOffline() {
  if (syncTimer) { clearTimeout(syncTimer); syncTimer = null }
  estado.value = 'offline'
}

onMounted(() => {
  window.addEventListener('online',  onOnline)
  window.addEventListener('offline', onOffline)
})
onUnmounted(() => {
  window.removeEventListener('online',  onOnline)
  window.removeEventListener('offline', onOffline)
  if (syncTimer) clearTimeout(syncTimer)
})
</script>

<template>
  <!-- Online: punto verde -->
  <span v-if="estado === 'online'" class="oi oi--on" />

  <!-- Offline: punto gris -->
  <span v-else-if="estado === 'offline'" class="oi oi--off" />

  <!-- Sync: pastilla naranja con punto deslizante -->
  <span v-else class="oi oi--sync">
    <span class="oi__slider" />
  </span>
</template>

<style scoped>
/* ── Base ── */
.oi {
  display: inline-block;
  flex-shrink: 0;
  border-radius: 999px;
}

/* ── Online: círculo verde con pulso ── */
.oi--on {
  width: 14px;
  height: 14px;
  background: #059669;
  box-shadow: 0 0 0 3px rgba(5,150,105,0.25);
  animation: oi-pulse 2s infinite;
}

@keyframes oi-pulse {
  0%, 100% { box-shadow: 0 0 0 0   rgba(5,150,105,0.4); }
  50%       { box-shadow: 0 0 0 6px rgba(5,150,105,0); }
}

/* ── Offline: círculo gris sin animación ── */
.oi--off {
  width: 14px;
  height: 14px;
  background: #9ca3af;
  box-shadow: none;
}

/* ── Sync: pastilla naranja con punto que viaja ── */
.oi--sync {
  width: 32px;
  height: 14px;
  background: rgba(251,146,60,0.2);
  border: 1.5px solid #fb923c;
  position: relative;
  overflow: hidden;
}

.oi__slider {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #f97316;
  animation: oi-slide 0.9s ease-in-out infinite alternate;
}

@keyframes oi-slide {
  from { left: 1px;  }
  to   { left: 19px; }
}
</style>
