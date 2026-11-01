<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import Message from 'primevue/message'
import ProgressSpinner from 'primevue/progressspinner'
import {
  publicoService,
  type PublicoCalendario,
} from '@/modules/criterios/services/criterios.service'

// ── Estado ─────────────────────────────────────────────
const filas = ref<PublicoCalendario[]>([])
const cargando = ref(true)
const error = ref('')

// ── Constantes ──────────────────────────────────────────
const MOMENTOS = ['J', 'V', 'S', 'D'] as const
const MOMENTO_UNICO = 'UNICO'

const LABELS_MOMENTO: Record<string, string> = {
  J: 'Jue',
  V: 'Vie',
  S: 'Sáb',
  D: 'Dom',
}

const LABELS_CATEGORIA: Record<string, string> = {
  inscripcion: 'Inscripción',
  armado: 'Armado de campamento',
  orden_cocina: 'Orden y cocina',
  ceremonias_participacion: 'Ceremonias y participación',
  liderazgo: 'Liderazgo',
}

const ORDEN_CATEGORIAS = [
  'inscripcion',
  'armado',
  'orden_cocina',
  'ceremonias_participacion',
  'liderazgo',
]

// ── Carga ───────────────────────────────────────────────
onMounted(async () => {
  try {
    filas.value = await publicoService.getCalendario()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar el calendario'
  } finally {
    cargando.value = false
  }
})

// ── Computed ────────────────────────────────────────────

/** Criterios únicos (sin duplicar) agrupados por categoría */
const criteriosUnicos = computed(() => {
  const vistos = new Set<string>()
  const lista: PublicoCalendario[] = []
  for (const f of filas.value) {
    if (!vistos.has(f.codigo)) {
      vistos.add(f.codigo)
      lista.push(f)
    }
  }
  return lista
})

const grupos = computed(() => {
  const mapa: Record<string, PublicoCalendario[]> = criteriosUnicos.value.reduce(
    (acc, c) => {
      if (!acc[c.categoria]) acc[c.categoria] = []
      ;(acc[c.categoria] as PublicoCalendario[]).push(c)
      return acc
    },
    {} as Record<string, PublicoCalendario[]>,
  )
  return ORDEN_CATEGORIAS.filter((cat) => mapa[cat]?.length).map((cat) => ({
    categoria: cat,
    items: mapa[cat] ?? [],
  }))
})

/** Obtener estado de un criterio para un momento dado */
function getEstado(codigo: string, momento: string): string | null {
  const fila = filas.value.find((f) => f.codigo === codigo && f.momento === momento)
  return fila ? fila.estado : null
}

/** ¿El criterio es UNICO? */
function esUnico(codigo: string): boolean {
  return filas.value.some((f) => f.codigo === codigo && f.momento === MOMENTO_UNICO)
}
</script>

<template>
  <div class="calendario-view">
    <h1 class="calendario-view__titulo">Calendario de evaluación</h1>
    <p class="calendario-view__desc">
      Días en que se evalúa cada criterio durante el campamento.
    </p>

    <div v-if="cargando" class="calendario-view__cargando">
      <ProgressSpinner style="width: 2rem; height: 2rem" />
    </div>

    <Message v-else-if="error" severity="error" :closable="false">{{ error }}</Message>

    <div v-else class="calendario-wrap">
      <table class="calendario-tabla">
        <thead>
          <tr>
            <th class="cal-th cal-th--nombre">Criterio</th>
            <th
              v-for="mom in MOMENTOS"
              :key="mom"
              class="cal-th cal-th--dia"
            >
              {{ LABELS_MOMENTO[mom] }}
            </th>
            <th class="cal-th cal-th--dia">Único</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="grupo in grupos" :key="grupo.categoria">
            <!-- Cabecera categoría -->
            <tr class="cal-fila-cat">
              <td :colspan="6" class="cal-td-cat">
                {{ LABELS_CATEGORIA[grupo.categoria] ?? grupo.categoria }}
              </td>
            </tr>

            <!-- Filas de criterios -->
            <tr
              v-for="criterio in grupo.items"
              :key="criterio.codigo"
              class="cal-fila"
            >
              <td class="cal-td cal-td--nombre">
                <span class="cal-codigo">{{ criterio.codigo }}</span>
                {{ criterio.nombre }}
              </td>

              <template v-if="esUnico(criterio.codigo)">
                <!-- Días vacíos -->
                <td
                  v-for="mom in MOMENTOS"
                  :key="mom"
                  class="cal-td cal-td--celda cal-td--na"
                >
                  <span class="cal-icono cal-icono--na">—</span>
                </td>
                <!-- Único -->
                <td class="cal-td cal-td--celda">
                  <span class="cal-icono cal-icono--unico">Único</span>
                </td>
              </template>

              <template v-else>
                <td
                  v-for="mom in MOMENTOS"
                  :key="mom"
                  class="cal-td cal-td--celda"
                  :class="{ 'cal-td--na': !getEstado(criterio.codigo, mom) }"
                >
                  <template v-if="getEstado(criterio.codigo, mom) === 'programado'">
                    <span class="cal-icono cal-icono--ok">✓</span>
                  </template>
                  <template v-else-if="getEstado(criterio.codigo, mom) === 'cancelado'">
                    <span class="cal-icono cal-icono--cancel">✗</span>
                  </template>
                  <template v-else>
                    <span class="cal-icono cal-icono--na">—</span>
                  </template>
                </td>
                <!-- Columna Único vacía -->
                <td class="cal-td cal-td--celda cal-td--na">
                  <span class="cal-icono cal-icono--na">—</span>
                </td>
              </template>
            </tr>
          </template>
        </tbody>
      </table>

      <!-- Leyenda -->
      <div class="calendario-leyenda">
        <span class="leyenda-item"><span class="cal-icono cal-icono--ok">✓</span> Programado</span>
        <span class="leyenda-item"><span class="cal-icono cal-icono--na">—</span> No aplica</span>
        <span class="leyenda-item"><span class="cal-icono cal-icono--cancel">✗</span> Cancelado</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.calendario-view {
  max-width: 900px;
  margin: 0 auto;
  padding: 1.5rem 1rem;
}
@media (min-width: 640px) { .calendario-view { padding: 2rem 1.5rem; } }

.calendario-view__titulo {
  font-size: 1.35rem;
  font-weight: 700;
  margin: 0 0 0.25rem;
}

.calendario-view__desc {
  font-size: 0.9rem;
  color: var(--p-text-muted-color, #6b7280);
  margin: 0 0 1.25rem;
}

.calendario-view__cargando {
  display: flex;
  justify-content: center;
  padding: 3rem 0;
}

.calendario-wrap {
  overflow-x: auto;
  /* Asegura scroll horizontal táctil en móvil */
  -webkit-overflow-scrolling: touch;
}

/* ── Tabla ── */
.calendario-tabla {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}

.cal-th {
  padding: 0.6rem 0.5rem;
  text-align: center;
  font-weight: 700;
  background: var(--lc-green-100, #dcfce7);
  border: 1px solid #bbf7d0;
  white-space: nowrap;
}

.cal-th--nombre {
  text-align: left;
  min-width: 180px;
}

.cal-th--dia {
  min-width: 56px;
}

.cal-fila:hover td {
  background: var(--lc-green-50, #f0fdf4);
}

.cal-td {
  padding: 0.45rem 0.5rem;
  border: 1px solid #e5e7eb;
  vertical-align: middle;
}

.cal-td--nombre {
  font-size: 0.82rem;
}

.cal-td--celda {
  text-align: center;
}

.cal-td--na {
  background: #f9fafb;
}

.cal-fila-cat .cal-td-cat {
  background: var(--lc-green-50, #f0fdf4);
  color: var(--lc-primary, #16a34a);
  font-weight: 700;
  font-size: 0.82rem;
  padding: 0.4rem 0.5rem;
  border: 1px solid #bbf7d0;
}

.cal-codigo {
  font-size: 0.7rem;
  font-weight: 700;
  background: #e5e7eb;
  border-radius: 999px;
  padding: 0.1rem 0.4rem;
  margin-right: 0.35rem;
  white-space: nowrap;
}

/* ── Iconos estado ── */
.cal-icono {
  font-size: 0.88rem;
  font-weight: 700;
}

.cal-icono--ok {
  color: #16a34a;
}

.cal-icono--cancel {
  color: #dc2626;
}

.cal-icono--na {
  color: #9ca3af;
  font-weight: 400;
}

.cal-icono--unico {
  font-size: 0.75rem;
  color: var(--lc-primary, #16a34a);
  font-weight: 600;
}

/* ── Leyenda ── */
.calendario-leyenda {
  display: flex;
  gap: 1.25rem;
  flex-wrap: wrap;
  margin-top: 0.75rem;
  font-size: 0.82rem;
  color: var(--p-text-muted-color, #6b7280);
}

.leyenda-item {
  display: flex;
  align-items: center;
  gap: 0.3rem;
}
</style>
