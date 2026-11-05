<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { RouterLink, RouterView, useRouter, useRoute } from 'vue-router'
import { useSessionStore }    from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import SyncStatus             from '@/components/ui/SyncStatus.vue'
import { initOfflineQueue }   from '@/lib/offlineQueue'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const router    = useRouter()
const route     = useRoute()

const menuAbierto      = ref(false)
const sidebarCollapsed = ref(false)

onMounted(async () => {
  await campStore.cargar()
  initOfflineQueue()
})

const iniciales = computed(() => {
  const n = session.perfil?.nombre_completo ?? ''
  return n.split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?'
})

// ── Navegación ───────────────────────────────────────────────────────────────
interface NavItem    { label: string; icon: string; to: string; roles: string[] }
interface NavSection { id: string; label: string; items: NavItem[] }

const navInicio: NavItem = { label: 'Inicio', icon: 'pi pi-home', to: '/panel', roles: ['admin', 'evaluador'] }

const sections: NavSection[] = [
  {
    id: 'evaluacion', label: 'Evaluación',
    items: [
      { label: 'Evaluar',     icon: 'pi pi-star',                 to: '/panel/evaluar',               roles: ['admin', 'evaluador'] },
      { label: 'Actividades',  icon: 'pi pi-users',                to: '/panel/asistencia',            roles: ['admin', 'evaluador'] },
      { label: 'Incidencias', icon: 'pi pi-exclamation-triangle', to: '/panel/incidencias',           roles: ['admin', 'evaluador'] },
      /* { label: 'Liderazgo',   icon: 'pi pi-bolt',                 to: '/panel/liderazgo/indicadores', roles: ['admin'] }, */
    ],
  },
  {
    id: 'seguimiento', label: 'Seguimiento',
    items: [
      { label: 'Avance',  icon: 'pi pi-chart-line', to: '/panel/avance',  roles: ['admin'] },
      { label: 'Ranking', icon: 'pi pi-trophy',     to: '/panel/ranking', roles: ['admin', 'evaluador'] },
    ],
  },
  {
    id: 'datos', label: 'Datos',
    items: [
      { label: 'Equipos',          icon: 'pi pi-flag',          to: '/panel/equipos',       roles: ['admin', 'evaluador'] },
      { label: 'Tipos de cálculo', icon: 'pi pi-calculator',    to: '/panel/tipos-calculo', roles: ['admin'] },
      { label: 'Criterios',        icon: 'pi pi-list-check',    to: '/panel/criterios',     roles: ['admin'] },
      { label: 'Programación',     icon: 'pi pi-calendar',      to: '/panel/programacion',  roles: ['admin'] },
      { label: 'Actividades',      icon: 'pi pi-calendar-plus', to: '/panel/actividades',   roles: ['admin'] },
    ],
  },
  {
    id: 'admin', label: 'Administración',
    items: [
      { label: 'Campamento',  icon: 'pi pi-building',  to: '/panel/campamento', roles: ['admin'] },
      { label: 'Revisiones',  icon: 'pi pi-file-edit', to: '/panel/revisiones', roles: ['admin'] },
      { label: 'Publicación', icon: 'pi pi-flag-fill', to: '/panel/resultados', roles: ['admin'] },
      { label: 'Auditoría',   icon: 'pi pi-history',   to: '/panel/auditoria',  roles: ['admin'] },
      { label: 'Reportes',    icon: 'pi pi-download',  to: '/panel/reportes',   roles: ['admin'] },
      { label: 'Usuarios',    icon: 'pi pi-id-card',   to: '/panel/usuarios',   roles: ['admin'] },
    ],
  },
]

const rol = computed(() => session.rol ?? '')

const seccionesVisibles = computed(() =>
  sections
    .map(s => ({ ...s, items: s.items.filter(i => i.roles.includes(rol.value)) }))
    .filter(s => s.items.length)
)

const todosItems = computed(() => [
  navInicio,
  ...sections.flatMap(s => s.items.filter(i => i.roles.includes(rol.value))),
])

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
  <div class="app-shell">

    <!-- ══════════════ TOPBAR MÓVIL ══════════════ -->
    <header class="topbar">
      <button class="topbar__btn" @click="menuAbierto = true" aria-label="Abrir menú">
        <i class="pi pi-bars" />
      </button>
      <span class="topbar__brand">🏕 LiderCamp 2026-II</span>
      <SyncStatus />
      <div class="topbar__avatar">{{ iniciales }}</div>
    </header>

    <!-- ══════════════ DRAWER MÓVIL ══════════════ -->
    <Teleport to="body">
      <div class="mob-overlay" :class="{ 'mob-overlay--on': menuAbierto }" @click.self="menuAbierto = false">
        <aside class="mob-drawer" :class="{ 'mob-drawer--open': menuAbierto }">

          <!-- Cabecera -->
          <div class="sb-head">
            <div class="sb-head__brand">
              <span class="sb-head__icon">🏕</span>
              <div class="sb-head__texts">
                <span class="sb-head__title">LiderCamp</span>
                <span class="sb-head__sub">2026-II</span>
              </div>
            </div>
            <button class="sb-head__close" @click="menuAbierto = false" aria-label="Cerrar">
              <i class="pi pi-times" />
            </button>
          </div>

          <!-- Campamento -->
          <div v-if="campStore.campamentos.length > 0" class="sb-camp">
            <i class="pi pi-building sb-camp__ic" />
            <select v-if="campStore.campamentos.length > 1"
              class="sb-camp__sel" :value="campStore.selectedId ?? ''"
              @change="campStore.seleccionar(($event.target as HTMLSelectElement).value)">
              <option v-for="c in campStore.campamentos" :key="c.id" :value="c.id">
                {{ c.nombre }}{{ c.activo ? '' : ' (inactivo)' }}
              </option>
            </select>
            <span v-else class="sb-camp__nombre">{{ campStore.campamento?.nombre }}</span>
          </div>

          <!-- Navegación -->
          <nav class="sb-nav">
            <button :class="['sb-item', isActive(navInicio) && 'sb-item--active']" @click="navegar(navInicio.to)">
              <i :class="navInicio.icon" class="sb-item__ic" />
              <span class="sb-item__lbl">{{ navInicio.label }}</span>
            </button>

            <div v-for="sec in seccionesVisibles" :key="sec.id" class="sb-section">
              <button class="sb-section__hdr" @click="toggleSection(sec.id)">
                <span class="sb-section__title">{{ sec.label }}</span>
                <i class="pi sb-section__chev" :class="openSections.has(sec.id) ? 'pi-chevron-up' : 'pi-chevron-down'" />
              </button>
              <div class="sb-section__body" :class="openSections.has(sec.id) && 'sb-section__body--open'">
                <div>
                  <button v-for="item in sec.items" :key="item.to"
                    :class="['sb-item sb-item--sub', isActive(item) && 'sb-item--active']"
                    @click="navegar(item.to)">
                    <i :class="item.icon" class="sb-item__ic" />
                    <span class="sb-item__lbl">{{ item.label }}</span>
                  </button>
                </div>
              </div>
            </div>
          </nav>

          <!-- Footer -->
          <div class="sb-foot">
            <div class="sb-foot__user">
              <div class="sb-foot__avatar">{{ iniciales }}</div>
              <div class="sb-foot__info">
                <strong class="sb-foot__name">{{ session.perfil?.nombre_completo }}</strong>
                <span class="sb-foot__rol">{{ rol === 'admin' ? 'Administrador' : 'Evaluador' }}</span>
              </div>
            </div>
            <button class="sb-foot__logout" @click="cerrarSesion" title="Cerrar sesión">
              <i class="pi pi-sign-out" />
            </button>
          </div>

        </aside>
      </div>
    </Teleport>

    <!-- ══════════════ BODY ESCRITORIO ══════════════ -->
    <div class="app-body">

      <!-- SIDEBAR ESCRITORIO -->
      <aside :class="['sidebar', sidebarCollapsed && 'sidebar--rail']">

        <!-- RAIL (colapsado) -->
        <template v-if="sidebarCollapsed">
          <div class="sb-head sb-head--rail">
            <button class="sb-toggle" @click="sidebarCollapsed = false" title="Expandir">
              <i class="pi pi-chevron-right" />
            </button>
          </div>
          <nav class="rail-nav">
            <RouterLink
              v-for="item in todosItems" :key="item.to" :to="item.to"
              :class="['rail-item', isActive(item) && 'rail-item--active']"
              :title="item.label">
              <i :class="item.icon" />
            </RouterLink>
          </nav>
          <div class="rail-foot">
            <button class="rail-logout" @click="cerrarSesion" title="Cerrar sesión">
              <i class="pi pi-sign-out" />
            </button>
          </div>
        </template>

        <!-- EXPANDIDO -->
        <template v-else>

          <!-- Cabecera escritorio -->
          <div class="sb-head">
            <div class="sb-head__brand">
              <span class="sb-head__icon">🏕</span>
              <div class="sb-head__texts">
                <span class="sb-head__title">LiderCamp</span>
                <span class="sb-head__sub">2026-II</span>
              </div>
            </div>
            <button class="sb-toggle" @click="sidebarCollapsed = true" title="Colapsar">
              <i class="pi pi-chevron-left" />
            </button>
          </div>

          <!-- Campamento escritorio -->
          <div v-if="campStore.campamentos.length > 0" class="sb-camp">
            <i class="pi pi-building sb-camp__ic" />
            <select v-if="campStore.campamentos.length > 1"
              class="sb-camp__sel" :value="campStore.selectedId ?? ''"
              @change="campStore.seleccionar(($event.target as HTMLSelectElement).value)">
              <option v-for="c in campStore.campamentos" :key="c.id" :value="c.id">
                {{ c.nombre }}{{ c.activo ? '' : ' (inactivo)' }}
              </option>
            </select>
            <span v-else class="sb-camp__nombre">{{ campStore.campamento?.nombre }}</span>
          </div>

          <!-- Navegación escritorio -->
          <nav class="sb-nav">
            <RouterLink :to="navInicio.to" :class="['sb-item', isActive(navInicio) && 'sb-item--active']">
              <i :class="navInicio.icon" class="sb-item__ic" />
              <span class="sb-item__lbl">{{ navInicio.label }}</span>
            </RouterLink>

            <div v-for="sec in seccionesVisibles" :key="sec.id" class="sb-section">
              <button class="sb-section__hdr" @click="toggleSection(sec.id)">
                <span class="sb-section__title">{{ sec.label }}</span>
                <i class="pi sb-section__chev" :class="openSections.has(sec.id) ? 'pi-chevron-up' : 'pi-chevron-down'" />
              </button>
              <div class="sb-section__body" :class="openSections.has(sec.id) && 'sb-section__body--open'">
                <div>
                  <RouterLink v-for="item in sec.items" :key="item.to" :to="item.to"
                    :class="['sb-item sb-item--sub', isActive(item) && 'sb-item--active']">
                    <i :class="item.icon" class="sb-item__ic" />
                    <span class="sb-item__lbl">{{ item.label }}</span>
                  </RouterLink>
                </div>
              </div>
            </div>
          </nav>

          <!-- Footer escritorio -->
          <div class="sb-foot">
            <div class="sb-foot__user">
              <div class="sb-foot__avatar">{{ iniciales }}</div>
              <div class="sb-foot__info">
                <strong class="sb-foot__name">{{ session.perfil?.nombre_completo }}</strong>
                <span class="sb-foot__rol">{{ rol === 'admin' ? 'Administrador' : 'Evaluador' }}</span>
              </div>
            </div>
            <button class="sb-foot__logout" @click="cerrarSesion" title="Cerrar sesión">
              <i class="pi pi-sign-out" />
            </button>
          </div>

        </template>
      </aside>

      <!-- CONTENIDO -->
      <main class="main-content">
        <div v-if="campStore.cerrado" class="banner-cerrado">
          <i class="pi pi-lock" /> Campamento cerrado — solo el administrador puede modificar datos.
        </div>
        <RouterView />
      </main>

    </div>
  </div>
</template>

<style scoped>
/* ══════════════════════════════════════════
   SHELL
══════════════════════════════════════════ */
.app-shell { display: flex; flex-direction: column; min-height: 100dvh; }
.app-body  { display: flex; flex: 1; }

/* ══════════════════════════════════════════
   TOPBAR MÓVIL
══════════════════════════════════════════ */
.topbar {
  display: flex; align-items: center; gap: 0.75rem;
  height: 56px; padding: 0 1rem;
  background: #059669; color: #fff;
  position: sticky; top: 0; z-index: 100; flex-shrink: 0;
  box-shadow: 0 2px 10px rgba(5,150,105,0.40);
}
.topbar__btn {
  width: 44px; height: 44px;
  display: flex; align-items: center; justify-content: center;
  background: rgba(255,255,255,0.15); border: none; border-radius: 10px;
  color: #fff; font-size: 1.15rem; cursor: pointer; flex-shrink: 0;
  transition: background 0.15s;
}
.topbar__btn:hover { background: rgba(255,255,255,0.25); }
.topbar__brand { flex: 1; font-size: 1.05rem; font-weight: 800; letter-spacing: -0.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.topbar__avatar {
  width: 38px; height: 38px; border-radius: 50%;
  background: rgba(255,255,255,0.20); border: 2px solid rgba(255,255,255,0.50);
  display: flex; align-items: center; justify-content: center;
  font-size: 0.8rem; font-weight: 800; color: #fff; flex-shrink: 0;
}

/* ══════════════════════════════════════════
   OVERLAY + DRAWER MÓVIL
══════════════════════════════════════════ */
.mob-overlay {
  position: fixed; inset: 0; z-index: 300;
  background: transparent; pointer-events: none;
  transition: background 0.28s;
}
.mob-overlay--on {
  background: rgba(0,0,0,0.5); backdrop-filter: blur(3px); pointer-events: all;
}
.mob-drawer {
  position: absolute; left: 0; top: 0; bottom: 0;
  width: min(300px, 86vw);
  transform: translateX(-100%);
  transition: transform 0.3s cubic-bezier(0.4,0,0.2,1);
  box-shadow: 6px 0 32px rgba(0,0,0,0.28);
  display: flex; flex-direction: column;
  background: #059669;
}
.mob-drawer--open { transform: translateX(0); }

/* ══════════════════════════════════════════
   SIDEBAR ESCRITORIO
══════════════════════════════════════════ */
.sidebar {
  display: none; width: 264px; flex-shrink: 0;
  background: #059669; flex-direction: column;
  position: sticky; top: 0; height: 100dvh; overflow: hidden;
  transition: width 0.25s cubic-bezier(0.4,0,0.2,1);
}
.sidebar--rail { width: 68px; }

/* Rail */
.rail-nav {
  flex: 1; display: flex; flex-direction: column; align-items: center;
  padding: 0.75rem 0; gap: 0.2rem; overflow-y: auto; scrollbar-width: none;
}
.rail-nav::-webkit-scrollbar { display: none; }
.rail-item {
  width: 46px; height: 46px; border-radius: 13px;
  display: flex; align-items: center; justify-content: center;
  text-decoration: none; color: rgba(255,255,255,0.65); font-size: 1.05rem;
  transition: background 0.15s, color 0.15s; position: relative;
}
.rail-item:hover { background: rgba(255,255,255,0.13); color: #fff; }
.rail-item--active { background: #fff; color: #047857; }
.rail-item--active::after {
  content: ''; position: absolute; right: -11px; top: 28%; bottom: 28%;
  width: 3px; background: #fff; border-radius: 3px 0 0 3px;
}
.rail-foot {
  display: flex; justify-content: center; align-items: center;
  height: 64px; border-top: 1px solid rgba(255,255,255,0.14);
  background: #047857; flex-shrink: 0;
}
.rail-logout {
  width: 44px; height: 44px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  border: none; background: rgba(255,255,255,0.10);
  color: rgba(255,255,255,0.65); font-size: 1rem; cursor: pointer;
  transition: background 0.14s, color 0.14s;
}
.rail-logout:hover { background: rgba(239,68,68,0.28); color: #fca5a5; }

/* ══════════════════════════════════════════
   SIDEBAR SHARED ELEMENTS (sb-*)
══════════════════════════════════════════ */

/* Cabecera */
.sb-head {
  display: flex; align-items: center; justify-content: space-between;
  height: 68px; padding: 0 0.85rem 0 1.15rem;
  background: #047857;
  border-bottom: 1px solid rgba(255,255,255,0.12);
  flex-shrink: 0; gap: 0.5rem;
}
.sb-head--rail { justify-content: center; padding: 0; }
.sb-head__brand { display: flex; align-items: center; gap: 0.7rem; flex: 1; min-width: 0; }
.sb-head__icon { font-size: 1.7rem; line-height: 1; flex-shrink: 0; }
.sb-head__texts { display: flex; flex-direction: column; min-width: 0; }
.sb-head__title {
  font-size: 1.18rem; font-weight: 800; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  letter-spacing: -0.02em; line-height: 1.2;
}
.sb-head__sub {
  font-size: 0.68rem; color: rgba(255,255,255,0.50);
  font-weight: 600; text-transform: uppercase; letter-spacing: 0.09em; margin-top: 1px;
}
.sb-head__close,
.sb-toggle {
  width: 34px; height: 34px; display: flex; align-items: center; justify-content: center;
  border-radius: 8px; border: none; background: rgba(255,255,255,0.12);
  color: rgba(255,255,255,0.75); font-size: 0.78rem; cursor: pointer; flex-shrink: 0;
  transition: background 0.14s, color 0.14s;
}
.sb-head__close:hover,
.sb-toggle:hover { background: rgba(255,255,255,0.22); color: #fff; }

/* Campamento */
.sb-camp {
  display: flex; align-items: center; gap: 0.55rem;
  margin: 0.9rem 0.85rem 0.1rem;
  padding: 0.58rem 0.85rem;
  background: rgba(255,255,255,0.12);
  border: 1px solid rgba(255,255,255,0.18);
  border-radius: 12px; flex-shrink: 0;
}
.sb-camp__ic { font-size: 0.88rem; color: rgba(255,255,255,0.7); flex-shrink: 0; }
.sb-camp__sel {
  flex: 1; min-width: 0; background: transparent; border: none; outline: none;
  font-size: 0.9rem; font-weight: 600; color: #fff; cursor: pointer;
}
.sb-camp__sel option { background: #047857; color: #fff; }
.sb-camp__nombre {
  font-size: 0.9rem; font-weight: 600; color: #fff;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1;
}

/* Navegación */
.sb-nav {
  flex: 1; overflow-y: auto; overflow-x: hidden;
  padding: 0.65rem 0.7rem 0.5rem;
  display: flex; flex-direction: column; gap: 0.06rem;
  scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.18) transparent;
}
.sb-nav::-webkit-scrollbar { width: 4px; }
.sb-nav::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.18); border-radius: 4px; }

.sb-item {
  display: flex; align-items: center; gap: 0.85rem;
  width: 100%; padding: 0 0.95rem; height: 50px;
  border-radius: 11px; border: none; background: none;
  color: rgba(255,255,255,0.85); font-size: 0.97rem; font-weight: 500;
  cursor: pointer; text-align: left; text-decoration: none;
  transition: background 0.15s, color 0.15s;
  position: relative; flex-shrink: 0; white-space: nowrap;
}
.sb-item:hover {
  background: rgba(255,255,255,0.10);
  color: #fff;
}
.sb-item--active {
  background: #fff;
  color: #047857;
  font-weight: 700;
  box-shadow: 0 2px 8px rgba(0,0,0,0.12);
}
.sb-item--active .sb-item__ic { opacity: 1; color: #047857; }
.sb-item__ic {
  font-size: 0.98rem; flex-shrink: 0; width: 20px; text-align: center; opacity: 0.75;
}
.sb-item__lbl { flex: 1; overflow: hidden; text-overflow: ellipsis; }

/* Sub-items */
.sb-item--sub { height: 46px; font-size: 0.94rem; padding-left: 1.05rem; }
.sb-item--sub .sb-item__ic { font-size: 0.88rem; }

/* Secciones */
.sb-section { display: flex; flex-direction: column; margin-top: 0.55rem; }
.sb-section__hdr {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 0.95rem; min-height: 28px;
  background: none; border: none; cursor: pointer; width: 100%;
  color: rgba(255,255,255,0.45); font-size: 0.71rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.11em; border-radius: 7px;
  transition: color 0.13s; user-select: none;
}
.sb-section__hdr:hover { color: rgba(255,255,255,0.80); }
.sb-section__title { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sb-section__chev { font-size: 0.58rem; opacity: 0.50; flex-shrink: 0; transition: transform 0.18s; }
.sb-section__body {
  display: grid; grid-template-rows: 0fr;
  transition: grid-template-rows 0.22s ease; overflow: hidden;
}
.sb-section__body--open { grid-template-rows: 1fr; }
.sb-section__body > div { overflow: hidden; }

/* Footer */
.sb-foot {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.85rem 0.9rem; gap: 0.65rem;
  background: #047857;
  border-top: 1px solid rgba(255,255,255,0.12);
  flex-shrink: 0;
}
.sb-foot__user { display: flex; align-items: center; gap: 0.65rem; min-width: 0; flex: 1; }
.sb-foot__avatar {
  width: 40px; height: 40px; border-radius: 50%;
  background: rgba(255,255,255,0.18); border: 2px solid rgba(255,255,255,0.35);
  display: flex; align-items: center; justify-content: center;
  font-size: 0.85rem; font-weight: 800; color: #fff; flex-shrink: 0; letter-spacing: 0.02em;
}
.sb-foot__info { display: flex; flex-direction: column; min-width: 0; }
.sb-foot__name {
  font-size: 0.9rem; font-weight: 700; color: #fff;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; line-height: 1.3;
}
.sb-foot__rol {
  font-size: 0.7rem; color: rgba(255,255,255,0.55); font-weight: 500; margin-top: 1px;
}
.sb-foot__logout {
  width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;
  border-radius: 10px; border: none; background: rgba(255,255,255,0.10);
  color: rgba(255,255,255,0.65); font-size: 0.98rem; cursor: pointer; flex-shrink: 0;
  transition: background 0.14s, color 0.14s;
}
.sb-foot__logout:hover { background: rgba(239,68,68,0.25); color: #fca5a5; }

/* ══════════════════════════════════════════
   CONTENIDO PRINCIPAL
══════════════════════════════════════════ */
.main-content { flex: 1; padding: 1rem; min-width: 0; background: var(--lc-bg); overflow-x: hidden; }

.banner-cerrado {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fee2e2; border: 1px solid #fca5a5; border-radius: 8px;
  padding: 0.6rem 0.9rem; font-size: 0.85rem; font-weight: 600; color: #991b1b;
  margin-bottom: 1rem;
}

/* ══════════════════════════════════════════
   ESCRITORIO ≥ 768px
══════════════════════════════════════════ */
@media (min-width: 768px) {
  .topbar       { display: none; }
  .app-body     { min-height: 100dvh; }
  .sidebar      { display: flex; }
  .main-content { padding: 1.5rem; }
}
</style>
