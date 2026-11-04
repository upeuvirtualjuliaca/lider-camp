<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import { useToast } from 'primevue/usetoast'
import {
  equiposService, integrantesService,
  type Equipo, type Integrante, type InscripcionEquipo,
} from '@/modules/equipos/services/equipos.service'
import { campamentoService, type Campamento } from '@/modules/equipos/services/campamento.service'
import { useCampamentoStore } from '@/stores/campamento'
import { useSessionStore } from '@/modules/auth/store'
import IntegranteFormDialog from '@/modules/equipos/components/IntegranteFormDialog.vue'
import ImportarIntegrantes from '@/modules/equipos/components/ImportarIntegrantes.vue'
import type { TablesInsert } from '@/types/database'

const route      = useRoute()
const toast      = useToast()
const session    = useSessionStore()
const campStore  = useCampamentoStore()

const equipoId = route.params['id'] as string
const equipo      = ref<Equipo | null>(null)
const integrantes = ref<Integrante[]>([])
const inscripcion = ref<InscripcionEquipo | null>(null)
const campamento  = ref<Campamento | null>(null)
const cargando    = ref(true)
const dialogVisible     = ref(false)
const integranteEditando = ref<Integrante | null>(null)
const busqueda = ref('')

const integrantesFiltrados = computed(() => {
  const q = busqueda.value.toLowerCase().trim()
  if (!q) return integrantes.value
  return integrantes.value.filter((i) =>
    i.nombres.toLowerCase().includes(q) ||
    i.apellidos.toLowerCase().includes(q) ||
    (i.codigo_universitario ?? '').toLowerCase().includes(q),
  )
})

// Fórmula visible en la tarjeta de puntaje
const formulaInscripcion = computed(() => {
  const ins = inscripcion.value
  if (!ins || ins.nomina === 0) return null
  const c = ins.inscritos_completos
  const p = ins.inscritos_parciales
  const n = ins.nomina
  const pts = Number(ins.puntaje_inscripcion).toFixed(2)
  return `(${c}×100 + ${p}×50) / ${n} = ${pts}`
})

function categoriaIntegrante(fecha: string): 'completa' | 'parcial' | 'tardia' {
  const c = campamento.value
  if (!c) return 'tardia'
  if (fecha <= c.fecha_limite_inscripcion_completa) return 'completa'
  if (fecha <= c.fecha_limite_inscripcion_parcial)  return 'parcial'
  return 'tardia'
}

const catConfig = {
  completa: { label: 'Completa', severity: 'success'  as const },
  parcial:  { label: 'Parcial',  severity: 'warn'     as const },
  tardia:   { label: 'Tardía',   severity: 'danger'   as const },
}

async function cargar() {
  cargando.value = true
  try {
    const [eq, ints, inscs, camp] = await Promise.all([
      equiposService.getPorId(equipoId),
      integrantesService.getPorEquipo(equipoId),
      equiposService.getInscripciones(),
      campStore.selectedId ? campamentoService.getById(campStore.selectedId) : Promise.resolve(null),
    ])
    equipo.value      = eq
    integrantes.value = ints
    inscripcion.value = inscs.find((i) => i.equipo_id === equipoId) ?? null
    campamento.value  = camp
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cargar el equipo.', life: 4000 })
  } finally {
    cargando.value = false
  }
}

function abrirNuevo()              { integranteEditando.value = null; dialogVisible.value = true }
function abrirEditar(i: Integrante) { integranteEditando.value = i;   dialogVisible.value = true }

async function guardar(datos: Partial<Integrante>) {
  try {
    if (integranteEditando.value) {
      await integrantesService.actualizar(integranteEditando.value.id, datos)
      toast.add({ severity: 'success', summary: 'Actualizado', detail: 'Integrante actualizado.', life: 3000 })
    } else {
      await integrantesService.crear(datos as TablesInsert<'integrantes'>)
      toast.add({ severity: 'success', summary: 'Creado', detail: 'Integrante agregado.', life: 3000 })
    }
    dialogVisible.value = false
    await cargar()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo guardar.', life: 4000 })
  }
}

async function toggleActivo(i: Integrante) {
  try {
    await integrantesService.actualizar(i.id, { activo: !i.activo })
    await cargar()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cambiar el estado.', life: 4000 })
  }
}

async function importar(filas: TablesInsert<'integrantes'>[]) {
  try {
    await integrantesService.crearMasivo(filas)
    toast.add({ severity: 'success', summary: 'Importados', detail: `${filas.length} integrantes importados.`, life: 3000 })
    await cargar()
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'Error en la importación.', life: 4000 })
  }
}

onMounted(cargar)
</script>

<template>
  <div class="detalle-view">
    <!-- Encabezado del equipo -->
    <div class="equipo-header">
      <span class="color-dot" :style="{ background: equipo?.color ?? '#ccc' }" />
      <div>
        <h2 class="page-title">{{ equipo?.nombre ?? '…' }}</h2>
        <p class="escuela">{{ equipo?.escuela_profesional }}</p>
      </div>
    </div>

    <!-- Tarjetas de inscripción -->
    <div v-if="inscripcion" class="inscripcion-card">
      <div class="inscripcion-stat">
        <span class="inscripcion-stat__val">{{ inscripcion.nomina }}</span>
        <span class="inscripcion-stat__lbl">Nómina</span>
      </div>
      <div class="inscripcion-stat">
        <span class="inscripcion-stat__val text-green">{{ inscripcion.inscritos_completos }}</span>
        <span class="inscripcion-stat__lbl">Completos (×100)</span>
      </div>
      <div class="inscripcion-stat">
        <span class="inscripcion-stat__val text-yellow">{{ inscripcion.inscritos_parciales }}</span>
        <span class="inscripcion-stat__lbl">Parciales (×50)</span>
      </div>
      <div class="inscripcion-stat">
        <span class="inscripcion-stat__val text-red">{{ inscripcion.inscritos_tardios }}</span>
        <span class="inscripcion-stat__lbl">Tardíos (×0)</span>
      </div>
      <div class="inscripcion-stat inscripcion-stat--puntaje">
        <span class="inscripcion-stat__val text-blue">{{ Number(inscripcion.puntaje_inscripcion).toFixed(2) }}</span>
        <span class="inscripcion-stat__lbl">Puntaje</span>
        <span v-if="formulaInscripcion" class="inscripcion-formula">{{ formulaInscripcion }}</span>
      </div>
    </div>

    <!-- ── Cabecera de integrantes ── -->
    <div class="integrantes-cabecera">
      <div class="integrantes-cabecera__fila">
        <div class="integrantes-cabecera__titulo">
          <h3 class="section-title">Integrantes</h3>
          <span v-if="integrantes.length > 0" class="count-badge">{{ integrantes.length }}</span>
        </div>
        <div v-if="session.esAdmin" class="integrantes-cabecera__acciones">
          <ImportarIntegrantes :equipo-id="equipoId" @importar="importar" />
          <Button label="Agregar" icon="pi pi-plus" size="small" @click="abrirNuevo" />
        </div>
      </div>
      <IconField class="integrantes-cabecera__busqueda">
        <InputIcon class="pi pi-search" />
        <InputText
          v-model="busqueda"
          placeholder="Buscar por nombre, apellido o código..."
          fluid
        />
      </IconField>
    </div>

    <DataTable
      :value="integrantesFiltrados"
      :loading="cargando"
      striped-rows
      responsive-layout="scroll"
    >
      <Column header="#" style="width:3rem">
        <template #body="{ index }">{{ (index as number) + 1 }}</template>
      </Column>
      <Column field="codigo_universitario" header="Código" class="col-codigo" />
      <Column field="apellidos"            header="Apellidos" />
      <Column field="nombres"              header="Nombres" />
      <Column field="fecha_inscripcion"    header="F. Inscripción" class="col-fecha" />
      <Column header="Categoría" style="width:7rem" class="col-categoria">
        <template #body="{ data }">
          <Tag
            v-if="(data as Integrante).fecha_inscripcion"
            :value="catConfig[categoriaIntegrante((data as Integrante).fecha_inscripcion!)].label"
            :severity="catConfig[categoriaIntegrante((data as Integrante).fecha_inscripcion!)].severity"
          />
        </template>
      </Column>
      <Column header="Elegible" style="width:6rem" class="col-elegible">
        <template #body="{ data }">
          <Tag
            :value="(data as Integrante).elegible ? 'Sí' : 'No'"
            :severity="(data as Integrante).elegible ? 'success' : 'secondary'"
          />
        </template>
      </Column>
      <Column header="Estado" style="width:6rem">
        <template #body="{ data }">
          <Tag
            :value="(data as Integrante).activo ? 'Activo' : 'Baja'"
            :severity="(data as Integrante).activo ? 'success' : 'secondary'"
          />
        </template>
      </Column>
      <Column v-if="session.esAdmin" header="" style="width:6rem">
        <template #body="{ data }">
          <div class="row-actions">
            <Button icon="pi pi-pencil" text rounded size="small" @click="abrirEditar(data as Integrante)" />
            <Button
              :icon="(data as Integrante).activo ? 'pi pi-ban' : 'pi pi-check'"
              text rounded size="small"
              :severity="(data as Integrante).activo ? 'warn' : 'success'"
              @click="toggleActivo(data as Integrante)"
            />
          </div>
        </template>
      </Column>
    </DataTable>

    <IntegranteFormDialog
      v-model:visible="dialogVisible"
      :integrante="integranteEditando"
      :equipo-id="equipoId"
      @guardar="guardar"
    />
  </div>
</template>

<style scoped>
/* ── Vista raíz ── */
.detalle-view {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 16px;
}

/* ── Encabezado del equipo ── */
.equipo-header { display: flex; align-items: center; gap: 0.75rem; }
.color-dot     { width: 1.5rem; height: 1.5rem; border-radius: 50%; flex-shrink: 0; border: 1px solid rgba(0,0,0,0.1); }
.page-title    { font-size: 1.3rem; font-weight: 700; margin: 0; }
.escuela       { margin: 0; font-size: 0.9rem; color: var(--p-text-muted-color); }
.section-title { font-size: 1rem; font-weight: 600; margin: 0; }
.row-actions   { display: flex; gap: 0.25rem; }

/* Touch targets for action buttons */
.row-actions :deep(.p-button) {
  min-height: 44px;
  min-width: 44px;
}

/* ── Cabecera integrantes ── */
.integrantes-cabecera           { display: flex; flex-direction: column; gap: 0.625rem; }
.integrantes-cabecera__fila     { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; flex-wrap: wrap; }
.integrantes-cabecera__titulo   { display: flex; align-items: center; gap: 0.5rem; }
.integrantes-cabecera__acciones { display: flex; align-items: center; gap: 0.5rem; flex-shrink: 0; }
.integrantes-cabecera__busqueda { width: 100%; }

/* Touch target for search input */
.integrantes-cabecera__busqueda :deep(input) {
  min-height: 44px;
  font-size: 0.95rem;
}
.integrantes-cabecera__busqueda :deep(input:focus) {
  border-color: var(--lc-primary);
  box-shadow: 0 0 0 2px rgba(22, 163, 74, 0.2);
}

/* Touch target for header buttons */
.integrantes-cabecera__acciones :deep(.p-button) {
  min-height: 44px;
}

.count-badge {
  display: inline-flex;
  align-items: center;
  background: var(--lc-green-50);
  color: var(--lc-primary);
  font-size: 0.82rem;
  font-weight: 700;
  padding: 0.1rem 0.55rem;
  border-radius: 99px;
  border: 1px solid var(--lc-green-100);
}

.text-green  { color: #16a34a; }
.text-yellow { color: #ca8a04; }
.text-red    { color: #dc2626; }
.text-blue   { color: var(--lc-primary); }

/* ── Tarjeta inscripción ── */
.inscripcion-card {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  background: white;
  border-radius: 10px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
  padding: 1rem;
  border: 1px solid var(--lc-green-100);
}
.inscripcion-stat {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 5rem;
  flex: 1;
}
.inscripcion-stat__val { font-size: 1.5rem; font-weight: 700; }
.inscripcion-stat__lbl { font-size: 0.82rem; color: var(--p-text-muted-color); text-align: center; }
.inscripcion-stat--puntaje {
  border-left: 2px solid var(--lc-green-100);
  padding-left: 0.75rem;
}
.inscripcion-formula {
  font-size: 0.82rem;
  color: var(--p-text-muted-color);
  text-align: center;
  margin-top: 0.2rem;
  white-space: nowrap;
}

/* ── Tablet+ ≥ 640px ── */
@media (min-width: 640px) {
  .detalle-view { padding: 24px; }
}

/* ── Columnas responsivas ── */
@media (max-width: 600px) {
  .col-codigo, .col-fecha, .col-categoria, .col-elegible { display: none; }
}
</style>
