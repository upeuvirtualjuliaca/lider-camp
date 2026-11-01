import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import Aura from '@primevue/themes/aura'
import { definePreset } from '@primevue/themes'
import ToastService from 'primevue/toastservice'
import Toast from 'primevue/toast'
import 'primeicons/primeicons.css'

import App from './App.vue'
import router from './router'
import { useSessionStore } from './modules/auth/store'

// Tema verde LiderCamp
const LiderCampTheme = definePreset(Aura, {
  semantic: {
    primary: {
      50:  '{green.50}',
      100: '{green.100}',
      200: '{green.200}',
      300: '{green.300}',
      400: '{green.400}',
      500: '{green.500}',
      600: '{green.600}',
      700: '{green.700}',
      800: '{green.800}',
      900: '{green.900}',
      950: '{green.950}',
    },
  },
})

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(PrimeVue, {
  theme: {
    preset: LiderCampTheme,
    options: { darkModeSelector: '.dark' },
  },
})
app.use(ToastService)
app.use(router)

app.component('Toast', Toast)

// Inicializar sesión antes de montar para que el guard tenga datos
const session = useSessionStore()
session.inicializar().then(() => {
  app.mount('#app')
})
