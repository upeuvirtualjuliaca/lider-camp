<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Password from 'primevue/password'
import Message from 'primevue/message'
import { useSessionStore } from '@/modules/auth/store'

const session = useSessionStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const cargando = ref(false)

function traducirError(msg: string): string {
  if (msg.includes('Invalid login credentials')) return 'Correo o contraseña incorrectos.'
  if (msg.includes('Email not confirmed'))       return 'Confirma tu correo antes de ingresar.'
  if (msg.includes('desactivada'))               return msg
  return 'Ocurrió un error. Intenta de nuevo.'
}

async function ingresar() {
  error.value = ''
  if (!email.value || !password.value) {
    error.value = 'Ingresa tu correo y contraseña.'
    return
  }
  cargando.value = true
  try {
    await session.login(email.value, password.value)
    router.push('/panel')
  } catch (e: unknown) {
    error.value = traducirError(e instanceof Error ? e.message : 'Error desconocido.')
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-card__header">
        <h1>LiderCamp 2026-II</h1>
        <p>Ingresa con tu correo y contraseña</p>
      </div>

      <form class="login-form" @submit.prevent="ingresar">
        <div class="login-form__field">
          <label for="email">Correo electrónico</label>
          <InputText
            id="email"
            v-model="email"
            type="email"
            placeholder="tu@correo.com"
            autocomplete="email"
            :disabled="cargando"
            fluid
          />
        </div>

        <div class="login-form__field">
          <label for="password">Contraseña</label>
          <Password
            id="password"
            v-model="password"
            placeholder="••••••••"
            :feedback="false"
            toggle-mask
            autocomplete="current-password"
            :disabled="cargando"
            fluid
          />
        </div>

        <Message v-if="error" severity="error" :closable="false">{{ error }}</Message>

        <Button
          type="submit"
          label="Ingresar"
          icon="pi pi-sign-in"
          :loading="cargando"
          fluid
        />
      </form>
    </div>
  </div>
</template>

<style scoped>
/* ── Variables de tema verde ── */
:root {
  --lc-primary: #16a34a;
  --lc-primary-light: #dcfce7;
  --lc-green-50: #f0fdf4;
  --lc-green-100: #dcfce7;
}

.login-page {
  min-height: 100dvh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background: var(--lc-green-50, #f0fdf4);
}

.login-card {
  width: 100%;
  max-width: 26rem;
  background: white;
  border-radius: 10px;
  padding: 1.5rem 1.25rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}

@media (min-width: 640px) {
  .login-card {
    padding: 2rem;
  }
}

.login-card__header {
  text-align: center;
  margin-bottom: 1.5rem;
}

.login-card__header h1 {
  font-size: 1.4rem;
  font-weight: 800;
  color: var(--lc-primary, #16a34a);
  margin: 0 0 0.25rem;
}

.login-card__header p {
  font-size: 0.9rem;
  color: var(--p-text-muted-color, #6b7280);
  margin: 0;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.login-form__field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.login-form__field label {
  font-size: 0.82rem;
  font-weight: 500;
  color: var(--p-text-color, #374151);
}

/* Inputs touch-friendly */
.login-form__field :deep(input) {
  min-height: 44px;
  font-size: 0.95rem;
}

.login-form__field :deep(input:focus) {
  border-color: var(--lc-primary, #16a34a);
  box-shadow: 0 0 0 2px var(--lc-primary-light, #dcfce7);
}

/* Botón submit touch-friendly */
.login-form :deep(.p-button) {
  min-height: 44px;
  background-color: var(--lc-primary, #16a34a);
  border-color: var(--lc-primary, #16a34a);
}

.login-form :deep(.p-button:hover) {
  background-color: #15803d;
  border-color: #15803d;
}
</style>
