<script setup lang="ts">
import { ref, computed } from 'vue'
import Button from 'primevue/button'
import Textarea from 'primevue/textarea'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import type { TablesInsert } from '@/types/database'

const props = defineProps<{ equipoId: string }>()
const emit  = defineEmits<{ importar: [filas: TablesInsert<'integrantes'>[]] }>()

const visible = ref(false)
const texto   = ref('')
const preview = ref<Array<TablesInsert<'integrantes'> & { _error?: string }>>([])
const pegado  = ref(false)

/* Parsea líneas pegadas desde Excel: nombres<TAB>apellidos<TAB>codigo<TAB>fecha */
function parsear() {
  pegado.value  = true
  const lineas  = texto.value.split('\n').filter((l) => l.trim())

  // Primera pasada: parsear cada fila
  const filas = lineas.map((linea) => {
    const cols     = linea.split('\t')
    const nombres  = cols[0]?.trim() ?? ''
    const apellidos = cols[1]?.trim() ?? ''
    const codigo   = cols[2]?.trim() || null
    const fechaRaw = cols[3]?.trim() ?? ''

    // Acepta dd/mm/yyyy o yyyy-mm-dd
    let fecha = ''
    const partesBarra = fechaRaw.split('/')
    if (partesBarra.length === 3) {
      const [d, m, y] = partesBarra
      fecha = `${y}-${m?.padStart(2, '0')}-${d?.padStart(2, '0')}`
    } else {
      fecha = fechaRaw
    }

    const _error: string | undefined =
      !nombres    ? 'Nombres requerido' :
      !apellidos  ? 'Apellidos requerido' :
      !/^\d{4}-\d{2}-\d{2}$/.test(fecha) ? 'Fecha inválida (dd/mm/yyyy)' :
      undefined

    return {
      equipo_id:            props.equipoId,
      nombres,
      apellidos,
      codigo_universitario: codigo,
      fecha_inscripcion:    fecha,
      _error,
    }
  })

  // Segunda pasada: marcar códigos duplicados dentro del lote
  const codigosVistos = new Map<string, number>() // código → primera posición
  filas.forEach((f, idx) => {
    if (f._error || !f.codigo_universitario) return
    if (codigosVistos.has(f.codigo_universitario)) {
      f._error = `Código duplicado (igual a fila ${(codigosVistos.get(f.codigo_universitario)! + 1)})`
    } else {
      codigosVistos.set(f.codigo_universitario, idx)
    }
  })

  preview.value = filas
}

function confirmar() {
  const validas = preview.value
    .filter((f) => !f._error)
    .map(({ _error, ...rest }) => rest)
  emit('importar', validas)
  visible.value = false
  texto.value   = ''
  preview.value = []
  pegado.value  = false
}

const errores = computed(() => preview.value.filter((f) => f._error).length)
const validas = computed(() => preview.value.length - errores.value)
</script>

<template>
  <Button label="Importar Excel" icon="pi pi-upload" severity="secondary" size="small" @click="visible = true" />

  <Dialog
    v-model:visible="visible"
    header="Importar integrantes desde Excel"
    modal
    :style="{ width: '95vw', maxWidth: '48rem' }"
  >
    <div class="importar">
      <p class="importar__instrucciones">
        En Excel, selecciona las columnas en este orden y cópialas (Ctrl+C):
        <strong>Nombres · Apellidos · Código universitario · Fecha inscripción (dd/mm/yyyy)</strong>.
        Luego pégalas aquí (Ctrl+V).
      </p>

      <Textarea
        v-model="texto"
        rows="6"
        placeholder="Pega las filas de Excel aquí..."
        fluid
        @input="pegado = false"
      />

      <Button
        label="Previsualizar"
        icon="pi pi-eye"
        size="small"
        :disabled="!texto.trim()"
        @click="parsear"
      />

      <DataTable
        v-if="pegado"
        :value="preview"
        size="small"
        striped-rows
        class="importar__tabla"
      >
        <Column field="nombres"              header="Nombres" />
        <Column field="apellidos"            header="Apellidos" />
        <Column field="codigo_universitario" header="Código" />
        <Column field="fecha_inscripcion"    header="Fecha" />
        <Column header="Estado" style="min-width:12rem">
          <template #body="{ data }">
            <Tag v-if="data._error"  severity="danger"  :value="data._error" />
            <Tag v-else              severity="success" value="OK" />
          </template>
        </Column>
      </DataTable>

      <p v-if="pegado" class="importar__resumen">
        <span class="text-green fw-600">{{ validas }} válidas</span>
        <template v-if="errores > 0">
          · <span class="text-red fw-600">{{ errores }} con errores</span> (se omitirán)
        </template>
      </p>
    </div>

    <template #footer>
      <Button label="Cancelar" severity="secondary" text @click="visible = false" />
      <Button
        label="Importar válidas"
        icon="pi pi-check"
        :disabled="!pegado || validas === 0"
        @click="confirmar"
      />
    </template>
  </Dialog>
</template>

<style scoped>
.importar { display: flex; flex-direction: column; gap: 0.75rem; }
.importar__instrucciones { margin: 0; font-size: 0.875rem; color: var(--p-text-muted-color); }
.importar__tabla { font-size: 0.85rem; }
.importar__resumen { margin: 0; font-size: 0.85rem; }
.text-green { color: #16a34a; }
.text-red   { color: #dc2626; }
.fw-600     { font-weight: 600; }
</style>
