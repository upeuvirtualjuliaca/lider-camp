<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import { computed } from 'vue'
import { useSessionStore } from '@/modules/auth/store'

const route   = useRoute()
const router  = useRouter()
const session = useSessionStore()

interface NavItem { label: string; to: string; roles: string[] }

const items: NavItem[] = [
  { label: 'Inicio',      to: '/panel',              roles: ['admin', 'evaluador'] },
  { label: 'Evaluar',     to: '/panel/evaluar',       roles: ['admin', 'evaluador'] },
  { label: 'Actividades', to: '/panel/asistencia',    roles: ['admin', 'evaluador'] },
  { label: 'Incidencias', to: '/panel/incidencias',   roles: ['admin', 'evaluador'] },
]

const rol = computed(() => session.rol ?? '')
const visibles = computed(() => items.filter(i => i.roles.includes(rol.value)))

function isActive(item: NavItem) {
  return item.to === '/panel' ? route.path === '/panel' : route.path.startsWith(item.to)
}

// SVG paths por ítem
const icons: Record<string, string> = {
  '/panel':            'M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  '/panel/evaluar':    'M9 11l3 3 8-8 M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9',
  '/panel/asistencia': 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M22 21v-2a4 4 0 0 0-3-3.9 M9 7a4 4 0 1 0 0-8 4 4 0 0 0 0 8',
  '/panel/incidencias':'M12 9v4M12 17h.01 M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0-3.4 0z',
}
</script>

<template>
  <nav
    aria-label="Navegación principal"
    class="fixed bottom-0 inset-x-0 z-20 bg-white border-t border-[#E3E7E4] grid pb-[env(safe-area-inset-bottom,0px)] md:hidden"
    :style="{ gridTemplateColumns: `repeat(${visibles.length}, minmax(0, 1fr))` }"
  >
    <button
      v-for="item in visibles"
      :key="item.to"
      class="flex flex-col items-center gap-[3px] py-[6px] text-[11px] font-medium transition-colors"
      :class="isActive(item) ? 'text-[#0E7C59] font-semibold' : 'text-[#5B6660]'"
      @click="router.push(item.to)"
    >
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path v-if="item.to === '/panel'" d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>
        <template v-else-if="item.to === '/panel/evaluar'">
          <path d="M9 11l3 3 8-8"/>
          <path d="M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9"/>
        </template>
        <template v-else-if="item.to === '/panel/asistencia'">
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
          <circle cx="9" cy="7" r="4"/>
          <path d="M22 21v-2a4 4 0 0 0-3-3.9"/>
        </template>
        <template v-else-if="item.to === '/panel/incidencias'">
          <path d="M12 9v4M12 17h.01"/>
          <path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/>
        </template>
      </svg>
      {{ item.label }}
    </button>
  </nav>
</template>
