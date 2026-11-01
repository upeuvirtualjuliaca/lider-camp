<script setup lang="ts">
import Button from 'primevue/button'
import { useSessionStore } from '@/modules/auth/store'

const session = useSessionStore()
</script>

<template>
  <div class="sin-permiso">
    <i class="pi pi-lock sin-permiso__icon" />
    <h2>Sin permiso</h2>
    <p v-if="!session.user">No tienes una sesión activa.</p>
    <p v-else-if="!session.estaActivo">Tu cuenta está desactivada. Contacta al administrador.</p>
    <p v-else>No tienes permiso para acceder a esta sección.</p>

    <div class="sin-permiso__actions">
      <RouterLink v-if="!session.user" to="/login">
        <Button label="Iniciar sesión" icon="pi pi-sign-in" />
      </RouterLink>
      <RouterLink v-else to="/panel">
        <Button label="Ir al panel" icon="pi pi-home" />
      </RouterLink>
      <RouterLink to="/">
        <Button label="Inicio" icon="pi pi-arrow-left" severity="secondary" text />
      </RouterLink>
    </div>
  </div>
</template>

<style scoped>
.sin-permiso {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 3rem 1rem;
  text-align: center;
}

.sin-permiso__icon {
  font-size: 3rem;
  color: var(--p-red-400, #f87171);
}

.sin-permiso h2 {
  font-size: 1.5rem;
  font-weight: 700;
  margin: 0;
}

.sin-permiso p {
  color: var(--p-text-muted-color, #6b7280);
  margin: 0;
}

.sin-permiso__actions {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}
</style>
