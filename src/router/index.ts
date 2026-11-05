import { createRouter, createWebHistory } from 'vue-router'
import { useSessionStore } from '@/modules/auth/store'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    roles?: string[]
    title?: string
    section?: string
  }
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    // ── Rutas públicas ──────────────────────────────────────
    {
      path: '/',
      component: () => import('@/layouts/PublicLayout.vue'),
      children: [
        {
          path: '',
          name: 'home',
          component: () => import('@/views/HomeView.vue'),
        },
        {
          path: 'ranking',
          name: 'ranking',
          component: () => import('@/views/RankingView.vue'),
        },
        {
          path: 'equipo/:id',
          name: 'ficha-equipo',
          component: () => import('@/views/FichaEquipoView.vue'),
        },
        {
          path: 'calendario',
          name: 'calendario',
          component: () => import('@/views/CalendarioView.vue'),
        },
        {
          path: 'reglas',
          name: 'reglas',
          component: () => import('@/views/ReglasView.vue'),
        },
      ],
    },

    // ── Login (ruta independiente) ───────────────────────────
    {
      path: '/login',
      name: 'login',
      component: () => import('@/modules/auth/views/LoginView.vue'),
    },

    // ── Sin permiso ─────────────────────────────────────────
    {
      path: '/sin-permiso',
      name: 'sin-permiso',
      component: () => import('@/views/SinPermisoView.vue'),
    },

    // ── Panel privado ────────────────────────────────────────
    {
      path: '/panel',
      component: () => import('@/layouts/PanelLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'panel-home',
          component: () => import('@/views/panel/PanelHomeView.vue'),
        },
        {
          path: 'usuarios',
          name: 'usuarios',
          component: () => import('@/views/panel/UsuariosView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'campamento',
          name: 'campamento',
          component: () => import('@/modules/equipos/views/CampamentoView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'equipos',
          name: 'equipos',
          component: () => import('@/modules/equipos/views/EquiposView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'equipos/:id',
          name: 'equipo-detalle',
          component: () => import('@/modules/equipos/views/EquipoDetalleView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'criterios',
          name: 'criterios',
          component: () => import('@/modules/criterios/views/CriteriosView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'tipos-calculo',
          name: 'tipos-calculo',
          component: () => import('@/modules/criterios/views/TiposCalculoView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'programacion',
          name: 'programacion',
          component: () => import('@/modules/criterios/views/ProgramacionView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'evaluar',
          name: 'evaluar',
          component: () => import('@/modules/observaciones/views/EvaluarView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'], title: 'Evaluar', section: 'Evaluación' },
        },
        {
          path: 'avance',
          name: 'avance',
          component: () => import('@/modules/observaciones/views/AvanceView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'ranking',
          name: 'ranking-admin',
          component: () => import('@/modules/puntajes/views/RankingAdminView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'] },
        },
        {
          path: 'liderazgo/indicadores',
          name: 'liderazgo-indicadores',
          component: () => import('@/modules/liderazgo/views/IndicadoresView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'incidencias',
          name: 'incidencias',
          component: () => import('@/modules/incidencias/views/IncidenciasView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'], title: 'Incidencias', section: 'Evaluación' },
        },
        {
          path: 'incidencias/nueva',
          name: 'incidencias-nueva',
          component: () => import('@/modules/incidencias/views/NuevaIncidenciaView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'], title: 'Registrar incidencia', section: 'Evaluación' },
        },
        {
          path: 'incidencias/:id',
          name: 'incidencia-detalle',
          component: () => import('@/modules/incidencias/views/IncidenciaDetalleView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'], title: 'Incidencia', section: 'Evaluación' },
        },
        {
          path: 'actividades',
          name: 'actividades',
          component: () => import('@/modules/asistencia/views/ActividadesView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'asistencia',
          name: 'asistencia',
          component: () => import('@/modules/asistencia/views/AsistenciaView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'], title: 'Actividades', section: 'Evaluación' },
        },
        {
          path: 'auditoria',
          name: 'auditoria',
          component: () => import('@/modules/auditoria/views/AuditoriaView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'revisiones',
          name: 'revisiones',
          component: () => import('@/modules/revisiones/views/RevisionesView.vue'),
          meta: { requiresAuth: true, roles: ['admin'], title: 'Revisiones', section: 'Administración' },
        },
        {
          path: 'resultados',
          name: 'resultados',
          component: () => import('@/modules/auditoria/views/ResultadosView.vue'),
          meta: { requiresAuth: true, roles: ['admin'] },
        },
        {
          path: 'reportes',
          name: 'reportes',
          component: () => import('@/modules/auditoria/views/ReportesView.vue'),
          meta: { requiresAuth: true, roles: ['admin', 'evaluador'] },
        },
      ],
    },

    // ── 404 ─────────────────────────────────────────────────
    {
      path: '/:pathMatch(.*)*',
      redirect: '/',
    },
  ],
})

router.beforeEach(async (to) => {
  const session = useSessionStore()

  // Esperar a que inicializar() termine antes de comprobar la sesión.
  // Esto evita que el guard vea session.user = null durante el refresco
  // de página mientras Supabase aún no ha restaurado la sesión del localStorage.
  await session.esperarInicializacion()

  // /login → redirigir a /panel si ya hay sesión activa
  if (to.path === '/login' && session.user && session.estaActivo) {
    return '/panel'
  }

  // Rutas que requieren autenticación
  if (to.meta.requiresAuth) {
    if (!session.user) return '/login'
    if (!session.estaActivo) return '/sin-permiso'

    const roles = to.meta.roles
    if (roles && !roles.includes(session.rol ?? '')) {
      return '/sin-permiso'
    }
  }
})

export default router
