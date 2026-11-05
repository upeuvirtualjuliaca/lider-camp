<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { RouterLink, RouterView, useRouter, useRoute } from 'vue-router'
import { useSessionStore }    from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import SyncStatus             from '@/components/ui/SyncStatus.vue'
import BottomNav              from '@/components/ui/BottomNav.vue'
import NavIcon                from '@/components/ui/NavIcon.vue'
import { initOfflineQueue }   from '@/lib/offlineQueue'
import { precalentarCache }   from '@/lib/precalentarCache'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const router    = useRouter()
const route     = useRoute()

const menuAbierto = ref(false)

onMounted(async () => {
  await campStore.cargar()
  initOfflineQueue()
  if (campStore.selectedId) precalentarCache(campStore.selectedId)
})

const iniciales = computed(() => {
  const n = session.perfil?.nombre_completo ?? ''
  return n.split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
})

// ── Fecha legible ─────────────────────────────────────────────────────────────
const fechaHoy = computed(() => {
  const d = new Date()
  return d.toLocaleDateString('es', { weekday: 'long', day: 'numeric', month: 'long' })
    .replace(/^\w/, c => c.toUpperCase())
})

// ── Conectividad ─────────────────────────────────────────────────────────────
const online = ref(navigator.onLine)
if (typeof window !== 'undefined') {
  window.addEventListener('online',  () => { online.value = true  })
  window.addEventListener('offline', () => { online.value = false })
}

// ── Navegación ────────────────────────────────────────────────────────────────
interface NavItem    { label: string; iconKey: string; to: string; roles: string[] }
interface NavSection { id: string; label: string; items: NavItem[] }

const navInicio: NavItem = { label: 'Inicio', iconKey: 'home', to: '/panel', roles: ['admin', 'evaluador'] }

const sections: NavSection[] = [
  {
    id: 'evaluacion', label: 'Evaluación',
    items: [
      { label: 'Evaluar',      iconKey: 'check',    to: '/panel/evaluar',     roles: ['admin', 'evaluador'] },
      { label: 'Actividades',  iconKey: 'users',    to: '/panel/asistencia',  roles: ['admin', 'evaluador'] },
      { label: 'Incidencias',  iconKey: 'alert',    to: '/panel/incidencias', roles: ['admin', 'evaluador'] },
    ],
  },
  {
    id: 'seguimiento', label: 'Seguimiento',
    items: [
      { label: 'Avance',  iconKey: 'chart',   to: '/panel/avance',  roles: ['admin'] },
      { label: 'Ranking', iconKey: 'trophy',  to: '/panel/ranking', roles: ['admin', 'evaluador'] },
    ],
  },
  {
    id: 'datos', label: 'Datos',
    items: [
      { label: 'Equipos',          iconKey: 'flag',      to: '/panel/equipos',       roles: ['admin', 'evaluador'] },
      { label: 'Tipos de cálculo', iconKey: 'calc',      to: '/panel/tipos-calculo', roles: ['admin'] },
      { label: 'Criterios',        iconKey: 'list',      to: '/panel/criterios',     roles: ['admin'] },
      { label: 'Programación',     iconKey: 'calendar',  to: '/panel/programacion',  roles: ['admin'] },
      { label: 'Actividades (cfg)',iconKey: 'calplus',   to: '/panel/actividades',   roles: ['admin'] },
    ],
  },
  {
    id: 'admin', label: 'Administración',
    items: [
      { label: 'Campamento',  iconKey: 'building', to: '/panel/campamento', roles: ['admin'] },
      { label: 'Revisiones',  iconKey: 'edit',     to: '/panel/revisiones', roles: ['admin'] },
      { label: 'Publicación', iconKey: 'flagfill', to: '/panel/resultados', roles: ['admin'] },
      { label: 'Auditoría',   iconKey: 'history',  to: '/panel/auditoria',  roles: ['admin'] },
      { label: 'Reportes',    iconKey: 'download', to: '/panel/reportes',   roles: ['admin'] },
      { label: 'Usuarios',    iconKey: 'idcard',   to: '/panel/usuarios',   roles: ['admin'] },
    ],
  },
]

const rol = computed(() => session.rol ?? '')

const seccionesVisibles = computed(() =>
  sections
    .map(s => ({ ...s, items: s.items.filter(i => i.roles.includes(rol.value)) }))
    .filter(s => s.items.length)
)

const openSections = ref<Set<string>>(new Set())

function toggleSection(id: string) {
  const n = new Set(openSections.value)
  n.has(id) ? n.delete(id) : n.add(id)
  openSections.value = n
}

watch(() => route.path, (path) => {
  for (const s of sections) {
    if (s.items.some(i => path.startsWith(i.to) && i.to !== '/panel')) {
      openSections.value = new Set([...openSections.value, s.id])
      break
    }
  }
}, { immediate: true })

function isActive(item: NavItem) {
  return item.to === '/panel' ? route.path === '/panel' : route.path.startsWith(item.to)
}

async function cerrarSesion() { await session.logout(); router.push('/login') }
function navegar(to: string)  { menuAbierto.value = false; router.push(to) }
</script>

<template>
  <div class="min-h-dvh bg-[#F4F6F4] text-[#16201B]" style="font-family: Inter, system-ui, sans-serif">

    <!-- ══════════ MOBILE HEADER (<768px) ══════════ -->
    <header class="md:hidden fixed top-0 inset-x-0 z-20 h-14 bg-white border-b border-[#E3E7E4] flex items-center px-4 gap-3">
      <button
        class="w-11 h-11 flex items-center justify-center rounded-xl border-0 bg-transparent text-[#16201B]"
        aria-label="Abrir menú"
        @click="menuAbierto = true"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
          <path d="M4 7h16M4 12h16M4 17h16"/>
        </svg>
      </button>
      <div class="flex-1 flex flex-col items-center">
        <span class="text-[17px] font-bold leading-tight">{{ route.meta?.title ?? 'Inicio' }}</span>
        <span class="text-[12px] text-[#5B6660]">LiderCamp 2026-II</span>
      </div>
      <SyncStatus />
      <button
        class="w-9 h-9 rounded-full border-0 bg-[#0E7C59] text-white text-[13px] font-bold flex-shrink-0"
        :aria-label="`Mi cuenta: ${session.perfil?.nombre_completo}`"
      >{{ iniciales }}</button>
    </header>

    <!-- ══════════ MOBILE DRAWER ══════════ -->
    <Teleport to="body">
      <div
        class="fixed inset-0 z-40 transition-colors duration-300"
        :class="menuAbierto ? 'bg-black/50 backdrop-blur-sm pointer-events-auto' : 'pointer-events-none'"
        @click.self="menuAbierto = false"
      >
        <aside
          class="absolute left-0 top-0 bottom-0 flex flex-col bg-white transition-transform duration-300 shadow-2xl"
          style="width: min(300px, 86vw)"
          :style="{ transform: menuAbierto ? 'translateX(0)' : 'translateX(-100%)' }"
        >
          <!-- Head -->
          <div class="flex items-center justify-between h-16 px-4 border-b border-[#E3E7E4] flex-shrink-0">
            <div class="flex items-center gap-2">
              <span class="w-8 h-8 rounded-xl bg-[#0E7C59] flex items-center justify-content-center text-white text-xs font-bold flex items-center justify-center">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" aria-hidden="true"><path d="M3 20h18L12 4 3 20z"/><path d="M10 20l2-4 2 4"/></svg>
              </span>
              <div class="flex flex-col">
                <span class="text-[15px] font-bold text-[#16201B] leading-tight">LiderCamp</span>
                <span class="text-[11px] text-[#5B6660] font-medium">2026-II</span>
              </div>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-lg border-0 bg-transparent text-[#5B6660]" @click="menuAbierto = false" aria-label="Cerrar">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
          </div>

          <!-- Campamento -->
          <div v-if="campStore.campamentos.length > 0" class="mx-3 my-2 flex items-center gap-2 bg-[#F4F6F4] border border-[#E3E7E4] rounded-xl px-3 py-2 flex-shrink-0">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2" aria-hidden="true"><path d="M3 21V7l9-4 9 4v14M9 21v-6h6v6"/></svg>
            <select v-if="campStore.campamentos.length > 1"
              class="flex-1 min-w-0 bg-transparent border-0 outline-none text-[14px] font-semibold text-[#16201B]"
              :value="campStore.selectedId ?? ''"
              @change="campStore.seleccionar(($event.target as HTMLSelectElement).value)">
              <option v-for="c in campStore.campamentos" :key="c.id" :value="c.id">
                {{ c.nombre }}{{ c.activo ? '' : ' (inactivo)' }}
              </option>
            </select>
            <span v-else class="text-[14px] font-semibold text-[#16201B] truncate flex-1">{{ campStore.campamento?.nombre }}</span>
          </div>

          <!-- Nav -->
          <nav class="flex-1 overflow-y-auto px-2 py-1 flex flex-col gap-0.5">
            <!-- Inicio -->
            <button
              :class="['w-full flex items-center gap-3 px-3 h-11 rounded-xl border-0 text-[15px] font-medium transition-colors text-left',
                isActive(navInicio) ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'bg-transparent text-[#16201B] hover:bg-[#F4F6F4]']"
              @click="navegar(navInicio.to)"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
              Inicio
            </button>

            <div v-for="sec in seccionesVisibles" :key="sec.id" class="flex flex-col mt-3">
              <button class="w-full flex items-center justify-between px-3 h-6 border-0 bg-transparent cursor-pointer" @click="toggleSection(sec.id)">
                <span class="text-[11px] font-bold uppercase tracking-widest text-[#5B6660]">{{ sec.label }}</span>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2.5" aria-hidden="true">
                  <path :d="openSections.has(sec.id) ? 'M18 15l-6-6-6 6' : 'M6 9l6 6 6-6'"/>
                </svg>
              </button>
              <div
                class="overflow-hidden transition-all duration-200"
                :style="{ maxHeight: openSections.has(sec.id) ? sec.items.length * 48 + 'px' : '0px' }"
              >
                <button
                  v-for="item in sec.items" :key="item.to"
                  :class="['w-full flex items-center gap-3 px-3 h-11 rounded-xl border-0 text-[14px] font-medium transition-colors text-left mt-0.5',
                    isActive(item) ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'bg-transparent text-[#16201B] hover:bg-[#F4F6F4]']"
                  @click="navegar(item.to)"
                >
                  <NavIcon :key-name="item.iconKey" />
                  {{ item.label }}
                </button>
              </div>
            </div>
          </nav>

          <!-- Footer -->
          <div class="flex items-center gap-3 px-3 py-3 border-t border-[#E3E7E4] flex-shrink-0">
            <div class="w-9 h-9 rounded-full bg-[#0E7C59] flex items-center justify-center text-white text-[13px] font-bold flex-shrink-0">{{ iniciales }}</div>
            <div class="flex flex-col flex-1 min-w-0">
              <strong class="text-[14px] font-bold text-[#16201B] truncate leading-tight">{{ session.perfil?.nombre_completo }}</strong>
              <span class="text-[12px] text-[#5B6660]">{{ rol === 'admin' ? 'Administrador' : 'Evaluador' }}</span>
            </div>
            <button class="w-9 h-9 flex items-center justify-center rounded-xl border-0 bg-[#FEE2E2] text-[#991B1B]" @click="cerrarSesion" title="Cerrar sesión">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
            </button>
          </div>
        </aside>
      </div>
    </Teleport>

    <!-- ══════════ RAIL SIDEBAR (768–1279px) ══════════ -->
    <aside class="hidden md:flex xl:hidden fixed inset-y-0 left-0 z-10 w-[88px] bg-white border-r border-[#E3E7E4] flex-col items-center py-4 gap-1">
      <!-- Logo -->
      <span class="w-10 h-10 rounded-xl bg-[#0E7C59] flex items-center justify-center mb-3 flex-shrink-0">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" aria-hidden="true"><path d="M3 20h18L12 4 3 20z"/><path d="M10 20l2-4 2 4"/></svg>
      </span>

      <!-- Inicio -->
      <RouterLink
        :to="navInicio.to"
        class="w-[72px] flex flex-col items-center gap-1 py-2 rounded-xl no-underline text-[11px] font-semibold transition-colors"
        :class="isActive(navInicio) ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'text-[#5B6660] hover:bg-[#F4F6F4]'"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        Inicio
      </RouterLink>

      <!-- Evaluar -->
      <RouterLink
        to="/panel/evaluar"
        class="w-[72px] flex flex-col items-center gap-1 py-2 rounded-xl no-underline text-[11px] font-medium transition-colors"
        :class="route.path.startsWith('/panel/evaluar') ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#5B6660] hover:bg-[#F4F6F4]'"
        v-if="['admin','evaluador'].includes(rol)"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 11l3 3 8-8"/><path d="M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9"/></svg>
        Evaluar
      </RouterLink>

      <!-- Actividades -->
      <RouterLink
        to="/panel/asistencia"
        class="w-[72px] flex flex-col items-center gap-1 py-2 rounded-xl no-underline text-[11px] font-medium transition-colors"
        :class="route.path.startsWith('/panel/asistencia') ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#5B6660] hover:bg-[#F4F6F4]'"
        v-if="['admin','evaluador'].includes(rol)"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/></svg>
        Actividades
      </RouterLink>

      <!-- Incidencias -->
      <RouterLink
        to="/panel/incidencias"
        class="w-[72px] flex flex-col items-center gap-1 py-2 rounded-xl no-underline text-[11px] font-medium transition-colors"
        :class="route.path.startsWith('/panel/incidencias') ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#5B6660] hover:bg-[#F4F6F4]'"
        v-if="['admin','evaluador'].includes(rol)"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
        Incidencias
      </RouterLink>

      <!-- Resultados/ranking -->
      <RouterLink
        to="/panel/ranking"
        class="w-[72px] flex flex-col items-center gap-1 py-2 rounded-xl no-underline text-[11px] font-medium transition-colors"
        :class="route.path.startsWith('/panel/ranking') ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#5B6660] hover:bg-[#F4F6F4]'"
        v-if="['admin','evaluador'].includes(rol)"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>
        Resultados
      </RouterLink>

      <!-- Avatar + logout abajo -->
      <div class="mt-auto flex flex-col items-center gap-2">
        <SyncStatus />
        <button
          class="w-10 h-10 rounded-full border-0 bg-[#0E7C59] text-white text-[13px] font-bold"
          :aria-label="`Mi cuenta: ${session.perfil?.nombre_completo}`"
          :title="session.perfil?.nombre_completo ?? ''"
        >{{ iniciales }}</button>
        <button
          class="w-9 h-9 flex items-center justify-center rounded-xl border-0 bg-transparent text-[#5B6660] hover:bg-[#FEE2E2] hover:text-[#991B1B] transition-colors"
          @click="cerrarSesion" title="Cerrar sesión"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
        </button>
      </div>
    </aside>

    <!-- ══════════ DESKTOP SIDEBAR (≥1280px) ══════════ -->
    <aside class="hidden xl:flex fixed inset-y-0 left-0 z-10 w-[264px] bg-white border-r border-[#E3E7E4] flex-col">
      <!-- Head -->
      <div class="flex items-center gap-3 h-16 px-5 border-b border-[#E3E7E4] flex-shrink-0">
        <span class="w-9 h-9 rounded-xl bg-[#0E7C59] flex items-center justify-center flex-shrink-0">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" aria-hidden="true"><path d="M3 20h18L12 4 3 20z"/><path d="M10 20l2-4 2 4"/></svg>
        </span>
        <div class="flex flex-col flex-1 min-w-0">
          <span class="text-[16px] font-bold text-[#16201B] leading-tight">LiderCamp</span>
          <span class="text-[11px] text-[#5B6660] font-medium">2026-II</span>
        </div>
      </div>

      <!-- Campamento -->
      <div v-if="campStore.campamentos.length > 0" class="mx-3 my-3 flex items-center gap-2 bg-[#F4F6F4] border border-[#E3E7E4] rounded-xl px-3 py-2 flex-shrink-0">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2" aria-hidden="true"><path d="M3 21V7l9-4 9 4v14M9 21v-6h6v6"/></svg>
        <select v-if="campStore.campamentos.length > 1"
          class="flex-1 min-w-0 bg-transparent border-0 outline-none text-[14px] font-semibold text-[#16201B]"
          :value="campStore.selectedId ?? ''"
          @change="campStore.seleccionar(($event.target as HTMLSelectElement).value)">
          <option v-for="c in campStore.campamentos" :key="c.id" :value="c.id">
            {{ c.nombre }}{{ c.activo ? '' : ' (inactivo)' }}
          </option>
        </select>
        <span v-else class="text-[14px] font-semibold text-[#16201B] truncate flex-1">{{ campStore.campamento?.nombre }}</span>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto px-2 py-1 flex flex-col gap-0.5">
        <!-- Inicio -->
        <RouterLink
          :to="navInicio.to"
          class="flex items-center gap-3 px-3 h-11 rounded-xl no-underline text-[14px] font-medium transition-colors"
          :class="isActive(navInicio) ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#16201B] hover:bg-[#F4F6F4]'"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
          Inicio
        </RouterLink>

        <div v-for="sec in seccionesVisibles" :key="sec.id" class="flex flex-col mt-4">
          <button class="w-full flex items-center justify-between px-3 h-6 border-0 bg-transparent cursor-pointer" @click="toggleSection(sec.id)">
            <span class="text-[11px] font-bold uppercase tracking-widest text-[#5B6660]">{{ sec.label }}</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#5B6660" stroke-width="2.5" aria-hidden="true">
              <path :d="openSections.has(sec.id) ? 'M18 15l-6-6-6 6' : 'M6 9l6 6 6-6'"/>
            </svg>
          </button>
          <div
            class="overflow-hidden transition-all duration-200"
            :style="{ maxHeight: openSections.has(sec.id) ? sec.items.length * 48 + 'px' : '0px' }"
          >
            <RouterLink
              v-for="item in sec.items" :key="item.to" :to="item.to"
              class="flex items-center gap-3 px-3 h-11 rounded-xl no-underline text-[14px] font-medium transition-colors mt-0.5"
              :class="isActive(item) ? 'bg-[#E1F3EA] text-[#0B6B4B] font-semibold' : 'text-[#16201B] hover:bg-[#F4F6F4]'"
            >
              <NavIcon :key-name="item.iconKey" />
              {{ item.label }}
            </RouterLink>
          </div>
        </div>
      </nav>

      <!-- Footer usuario -->
      <div class="flex items-center gap-3 px-3 py-3 border-t border-[#E3E7E4] flex-shrink-0 bg-[#FAFAFA]">
        <div class="w-9 h-9 rounded-full bg-[#0E7C59] flex items-center justify-center text-white text-[13px] font-bold flex-shrink-0">{{ iniciales }}</div>
        <div class="flex flex-col flex-1 min-w-0">
          <strong class="text-[13px] font-bold text-[#16201B] truncate leading-tight">{{ session.perfil?.nombre_completo }}</strong>
          <span class="text-[12px] text-[#5B6660]">{{ rol === 'admin' ? 'Administrador' : 'Evaluador' }}</span>
        </div>
        <button class="w-8 h-8 flex items-center justify-center rounded-xl border-0 bg-transparent text-[#5B6660] hover:bg-[#FEE2E2] hover:text-[#991B1B] transition-colors" @click="cerrarSesion" title="Cerrar sesión">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
        </button>
      </div>
    </aside>

    <!-- ══════════ DESKTOP TOPBAR (≥1280px) ══════════ -->
    <header class="hidden xl:flex fixed top-0 left-[264px] right-0 z-10 h-16 bg-white border-b border-[#E3E7E4] items-center px-8 gap-4">
      <!-- Migas -->
      <nav aria-label="Ruta actual" class="flex items-center gap-2 text-[13px] text-[#5B6660] flex-1">
        <template v-if="route.meta?.section">
          <span>{{ route.meta.section }}</span>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 18l6-6-6-6"/></svg>
        </template>
        <span class="text-[#16201B] font-semibold">{{ route.meta?.title ?? 'Inicio' }}</span>
      </nav>
      <!-- Fecha + estado conexión -->
      <div class="flex items-center gap-4 flex-shrink-0">
        <SyncStatus />
        <span class="text-[13px] text-[#5B6660] hidden lg:block">{{ fechaHoy }}</span>
        <span
          class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[12px] font-semibold"
          :class="online ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#F3F4F6] text-[#6B7280]'"
        >
          <span class="w-1.5 h-1.5 rounded-full" :class="online ? 'bg-[#0E7C59]' : 'bg-[#9CA3AF]'"></span>
          {{ online ? 'En línea' : 'Sin conexión' }}
        </span>
      </div>
    </header>

    <!-- ══════════ MAIN CONTENT ══════════ -->
    <main
      class="pt-14 pb-20 md:pt-0 md:pb-0 md:pl-[88px] xl:pl-[264px] xl:pt-16 min-h-dvh"
    >
      <div v-if="campStore.cerrado" class="flex items-center gap-2 bg-[#FEE2E2] border border-[#FCA5A5] rounded-lg px-4 py-3 text-[14px] font-semibold text-[#991B1B] mx-4 mt-4 xl:mx-8 xl:mt-6">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
        Campamento cerrado — solo el administrador puede modificar datos.
      </div>
      <RouterView />
    </main>

    <!-- ══════════ BOTTOM NAV (mobile only, via component) ══════════ -->
    <BottomNav />

  </div>
</template>
