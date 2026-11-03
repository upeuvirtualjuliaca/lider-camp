<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  incidenciasService,
  evidenciasService,
  type IncidenciaDetalle,
  type IncidenciaCodigo,
} from '@/modules/incidencias/services/incidencias.service'
import { integrantesService, type Integrante } from '@/modules/equipos/services/equipos.service'

const route  = useRoute()
const router = useRouter()

const id = route.params.id as string

// ── Estado ────────────────────────────────────────────────────────────────────
const incidencia    = ref<IncidenciaDetalle | null>(null)
const integrantes   = ref<Integrante[]>([])
const urlsEvidencia = ref<Record<string, string>>({})
const cargando      = ref(true)
const error         = ref('')


// ── Carga ─────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const inc = await incidenciasService.getPorId(id)
    if (!inc) { error.value = 'Incidencia no encontrada'; return }
    incidencia.value = inc

    // Cargar integrantes con nombre si hay ids
    if (inc.integrantes.length) {
      integrantes.value = await integrantesService.getPorEquipo(inc.equipo_id)
    }

    // URLs firmadas de evidencias
    for (const ev of inc.evidencias) {
      urlsEvidencia.value[ev.id] = await evidenciasService.getUrl(ev.ruta_archivo)
    }
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar'
  } finally {
    cargando.value = false
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────────
function estadoBadge(estado: string) {
  const m: Record<string, string> = {
    registrado: 'badge--gris',
    validado:   'badge--verde',
    rechazado:  'badge--rojo',
  }
  return m[estado] ?? 'badge--gris'
}

const esBonus = computed(() =>
  (incidencia.value?.codigo_info as IncidenciaCodigo | null)?.tipo === 'bonus'
)

function nombreIntegrante(id: string) {
  const i = integrantes.value.find((x) => x.id === id)
  return i ? `${i.apellidos}, ${i.nombres}` : id
}

</script>

<template>
  <div class="det-page">
    <button class="btn-link" @click="router.back()">← Volver</button>

    <div v-if="cargando" class="det-empty">Cargando…</div>
    <div v-else-if="error" class="det-empty det-empty--error">{{ error }}</div>

    <template v-else-if="incidencia">
      <!-- Cabecera -->
      <div class="det-header">
        <div class="det-header__left">
          <span :class="['badge', esBonus ? 'badge--azul' : 'badge--naranja']">
            {{ incidencia.codigo }}
          </span>
          <h1 class="det-title">{{ incidencia.codigo_info?.nombre }}</h1>
        </div>
        <span :class="['badge', estadoBadge(incidencia.estado)]">{{ incidencia.estado }}</span>
      </div>

      <!-- Info principal -->
      <div class="det-card">
        <div class="det-fila">
          <span class="det-label">Equipo</span>
          <span class="det-valor">{{ incidencia.equipo_id }}</span>
        </div>
        <div v-if="incidencia.equipo_apoyado_id" class="det-fila">
          <span class="det-label">Equipo apoyado</span>
          <span class="det-valor">{{ incidencia.equipo_apoyado_id }}</span>
        </div>
        <div class="det-fila">
          <span class="det-label">Fecha / Hora</span>
          <span class="det-valor">{{ incidencia.fecha }} {{ incidencia.hora?.slice(0, 5) }}</span>
        </div>
        <div v-if="incidencia.momento" class="det-fila">
          <span class="det-label">Momento</span>
          <span class="det-valor">{{ incidencia.momento }}</span>
        </div>
        <div class="det-fila">
          <span class="det-label">Puntos</span>
          <span :class="['det-valor', 'det-pts', esBonus ? 'pts--bonus' : 'pts--demerito']">
            {{ esBonus ? '+' : '−' }}{{ incidencia.puntos }} pts
          </span>
        </div>
        <div class="det-fila">
          <span class="det-label">Alcance</span>
          <span class="det-valor">{{ incidencia.alcance }}</span>
        </div>
        <div v-if="incidencia.cantidad_personas > 1" class="det-fila">
          <span class="det-label">Personas</span>
          <span class="det-valor">{{ incidencia.cantidad_personas }}</span>
        </div>
      </div>

      <!-- Hecho -->
      <div class="det-card">
        <h2 class="det-section-title">Hecho registrado</h2>
        <p class="det-hecho">{{ incidencia.hecho }}</p>

        <template v-if="incidencia.advertencia_referencia">
          <h3 class="det-section-subtitle">Referencia a advertencia previa</h3>
          <p class="det-texto">{{ incidencia.advertencia_referencia }}</p>
        </template>

        <template v-if="incidencia.justificacion_grupal">
          <h3 class="det-section-subtitle">Justificación / contexto</h3>
          <p class="det-texto">{{ incidencia.justificacion_grupal }}</p>
        </template>
      </div>

      <!-- Integrantes involucrados -->
      <div v-if="incidencia.integrantes.length" class="det-card">
        <h2 class="det-section-title">Integrantes involucrados</h2>
        <ul class="integrantes-list">
          <li v-for="ii in incidencia.integrantes" :key="ii.id">
            {{ nombreIntegrante(ii.integrante_id) }}
          </li>
        </ul>
      </div>

      <!-- Evidencias -->
      <div class="det-card">
        <h2 class="det-section-title">Evidencia</h2>
        <div v-if="incidencia.evidencias.length" class="evidencias-grid">
          <a
            v-for="ev in incidencia.evidencias"
            :key="ev.id"
            :href="urlsEvidencia[ev.id]"
            target="_blank"
            class="evidencia-item"
          >
            <img
              v-if="ev.tipo_archivo.startsWith('image')"
              :src="urlsEvidencia[ev.id]"
              :alt="ev.nombre_original ?? 'evidencia'"
              class="evidencia-img"
            />
            <div v-else class="evidencia-doc">
              <i class="pi pi-file-pdf" />
              <span>{{ ev.nombre_original }}</span>
            </div>
          </a>
        </div>
        <p v-else class="det-texto det-texto--vacio">Sin archivos adjuntos.</p>
      </div>

    </template>
  </div>
</template>

<style scoped>
.det-page { max-width: 650px; margin: 0 auto; padding: 0 1rem; }
.btn-link {
  background: none; border: none; color: #16a34a; cursor: pointer;
  font-size: 0.9rem; padding: 0; margin-bottom: 1rem; display: inline-flex;
  align-items: center; min-height: 44px;
}

.det-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 0.75rem; margin-bottom: 1rem; }
.det-header__left { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
.det-title { font-size: 1.05rem; font-weight: 700; margin: 0; }

.det-card {
  background: white; border: 1px solid #e5e7eb; border-radius: 10px;
  padding: 1rem; margin-bottom: 0.75rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.08);
}
.det-card--validar { border-color: #fbbf24; background: #fffbeb; }

.det-section-title { font-size: 0.9rem; font-weight: 700; margin: 0 0 0.6rem; color: #374151; }
.det-section-subtitle { font-size: 0.82rem; font-weight: 600; margin: 0.75rem 0 0.3rem; color: #6b7280; }

.det-fila { display: flex; gap: 0.75rem; font-size: 0.9rem; margin-bottom: 0.4rem; align-items: flex-start; }
.det-label { min-width: 110px; font-weight: 600; color: #6b7280; flex-shrink: 0; }
.det-pts { font-weight: 700; font-size: 1rem; }
.pts--bonus    { color: #16a34a; }
.pts--demerito { color: #dc2626; }

.det-hecho { font-size: 0.9rem; line-height: 1.5; margin: 0; }
.det-texto { font-size: 0.9rem; color: #374151; margin: 0; line-height: 1.4; }
.det-texto--vacio { color: #9ca3af; font-style: italic; }
.det-meta { font-size: 0.82rem; color: #9ca3af; margin-top: 0.3rem; }

/* Integrantes */
.integrantes-list { margin: 0; padding-left: 1.2rem; font-size: 0.9rem; }
.integrantes-list li { margin-bottom: 0.25rem; }

/* Evidencias */
.evidencias-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.evidencia-item { display: block; }
.evidencia-img { width: 88px; height: 88px; object-fit: cover; border-radius: 8px; border: 1px solid #e5e7eb; }
.evidencia-doc {
  display: flex; flex-direction: column; align-items: center; gap: 0.2rem;
  width: 88px; padding: 0.6rem; border: 1px solid #e5e7eb; border-radius: 8px;
  font-size: 0.75rem; color: #374151; text-align: center;
}
.evidencia-doc i { font-size: 1.5rem; color: #dc2626; }

/* Campos */
.campo-grupo { margin-bottom: 0.75rem; }
.campo-label { display: block; font-size: 0.82rem; font-weight: 600; margin-bottom: 0.3rem; }
.campo-input {
  width: 100%; min-height: 44px; padding: 0.5rem 0.6rem; border: 1px solid #d1d5db;
  border-radius: 6px; font-size: 0.95rem; background: white; box-sizing: border-box;
}
.campo-input:focus { outline: none; border-color: #16a34a; box-shadow: 0 0 0 3px rgba(22,163,74,.15); }
textarea.campo-input { resize: vertical; min-height: 72px; }
.req { color: #dc2626; }

/* Acciones */
.det-acciones { display: flex; gap: 0.5rem; justify-content: flex-end; margin-top: 0.75rem; flex-wrap: wrap; }

/* Badges */
.badge { border-radius: 4px; font-size: 0.72rem; font-weight: 700; padding: 0.15rem 0.45rem; text-transform: uppercase; }
.badge--azul    { background: #dcfce7; color: #166534; }
.badge--naranja { background: #fed7aa; color: #c2410c; }
.badge--verde   { background: #d1fae5; color: #065f46; }
.badge--rojo    { background: #fee2e2; color: #991b1b; }
.badge--gris    { background: #f3f4f6; color: #374151; }

/* Botones */
.btn {
  display: inline-flex; align-items: center; gap: 0.35rem;
  min-height: 44px; padding: 0.5rem 1rem; border-radius: 6px; border: none;
  font-size: 0.9rem; font-weight: 600; cursor: pointer; transition: background 0.15s;
}
.btn--sm { min-height: 44px; padding: 0.5rem 0.85rem; font-size: 0.85rem; }
.btn--primary  { background: #16a34a; color: white; }
.btn--primary:hover:not(:disabled) { background: #15803d; }
.btn--ghost { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn--ghost:hover:not(:disabled) { background: #f0fdf4; }
.btn--validar  { background: #16a34a; color: white; }
.btn--validar:hover:not(:disabled) { background: #15803d; }
.btn--rechazar { background: #dc2626; color: white; }
.btn--rechazar:hover:not(:disabled) { background: #b91c1c; }
.btn:disabled { opacity: 0.5; cursor: not-allowed; }

.paso-desc { font-size: 0.9rem; color: #374151; margin: 0 0 0.75rem; }
.error-msg { color: #dc2626; font-size: 0.82rem; margin-bottom: 0.5rem; }

.det-empty { text-align: center; padding: 2.5rem; color: #6b7280; font-size: 0.9rem; }
.det-empty--error { color: #dc2626; }
</style>
