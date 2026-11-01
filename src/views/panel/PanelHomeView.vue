<script setup lang="ts">
import { useSessionStore } from '@/modules/auth/store'

const session = useSessionStore()

const etiquetaRol: Record<string, string> = {
  admin: 'Administrador',
  evaluador: 'Evaluador',
}
</script>

<template>
  <div class="panel-home">
    <h2 class="panel-home__title">
      Bienvenido, {{ session.perfil?.nombre_completo ?? 'Usuario' }}
    </h2>
    <p class="panel-home__rol">
      Rol: <strong>{{ etiquetaRol[session.rol ?? ''] ?? session.rol }}</strong>
    </p>
    <p class="panel-home__info">
      Módulos en construcción. Usa el menú para navegar.
    </p>
  </div>
</template>

<style scoped>
.panel-home {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem 0;
}

.panel-home__title {
  font-size: 1.4rem;
  font-weight: 700;
  margin: 0;
  color: var(--p-text-color, #111827);
}

.panel-home__rol {
  margin: 0;
  color: var(--p-text-muted-color, #6b7280);
  font-size: 0.95rem;
}

.panel-home__info {
  margin: 1rem 0 0;
  padding: 1rem;
  background: var(--lc-green-50, #f0fdf4);
  border-radius: 10px;
  border: 1px solid #bbf7d0;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
  color: var(--p-text-muted-color, #6b7280);
  font-size: 0.9rem;
}
</style>
