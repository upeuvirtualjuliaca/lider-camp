<script setup lang="ts">
defineProps<{ titulo: string }>()
</script>

<template>
  <div class="proximamente">
    <i class="pi pi-clock proximamente__icon" />
    <h2>{{ titulo }}</h2>
    <p>Esta sección estará disponible próximamente.</p>
    <RouterLink to="/">
      <span class="proximamente__back">← Volver al inicio</span>
    </RouterLink>
  </div>
</template>

<style scoped>
.proximamente {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 3rem 1rem;
  text-align: center;
}

.proximamente__icon {
  font-size: 2.5rem;
  color: var(--p-text-muted-color, #9ca3af);
}

.proximamente h2 { margin: 0; font-size: 1.4rem; }
.proximamente p  { margin: 0; color: var(--p-text-muted-color, #6b7280); }

.proximamente__back {
  color: var(--p-primary-500, #3b82f6);
  text-decoration: none;
  font-size: 0.9rem;
  cursor: pointer;
}
</style>
