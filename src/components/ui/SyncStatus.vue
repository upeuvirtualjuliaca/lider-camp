<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { pendingCount, sync } from '@/lib/offlineQueue'

const online = ref(navigator.onLine)

function onOnline()  { online.value = true  }
function onOffline() { online.value = false }

onMounted(() => {
  window.addEventListener('online',  onOnline)
  window.addEventListener('offline', onOffline)
})
onUnmounted(() => {
  window.removeEventListener('online',  onOnline)
  window.removeEventListener('offline', onOffline)
})
</script>

<template>
  <div
    v-if="!online || pendingCount > 0"
    class="sync-status"
    :class="{ 'sync-status--offline': !online }"
    :title="online ? `${pendingCount} registro(s) pendiente(s) de sincronizar` : 'Sin conexión — los cambios se guardarán al reconectar'"
  >
    <i :class="online ? 'pi pi-cloud-upload' : 'pi pi-wifi'" class="sync-status__icon" />
    <span class="sync-status__txt">
      {{ online ? pendingCount : '?' }}
    </span>
    <button v-if="online && pendingCount > 0" class="sync-status__btn" @click="sync" aria-label="Sincronizar ahora">
      <i class="pi pi-refresh" />
    </button>
  </div>
</template>

<style scoped>
.sync-status {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.25rem 0.6rem;
  border-radius: 999px;
  background: rgba(234, 179, 8, 0.15);
  border: 1px solid rgba(234, 179, 8, 0.4);
  color: #92400e;
  font-size: 0.78rem;
  font-weight: 700;
  white-space: nowrap;
  cursor: default;
}
.sync-status--offline {
  background: rgba(239, 68, 68, 0.12);
  border-color: rgba(239, 68, 68, 0.35);
  color: #991b1b;
}
.sync-status__icon { font-size: 0.75rem; }
.sync-status__btn {
  background: none;
  border: none;
  padding: 0 0 0 0.15rem;
  cursor: pointer;
  color: inherit;
  font-size: 0.75rem;
  line-height: 1;
  display: flex;
  align-items: center;
}
.sync-status__btn:hover { opacity: 0.7; }
</style>
