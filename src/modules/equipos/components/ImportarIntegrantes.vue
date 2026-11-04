<script setup lang="ts">
import { ref, computed } from 'vue'
import ExcelJS from 'exceljs'
import Button from 'primevue/button'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import type { TablesInsert } from '@/types/database'

const props = defineProps<{ equipoId: string }>()
const emit  = defineEmits<{ importar: [filas: TablesInsert<'integrantes'>[]] }>()

const visible     = ref(false)
const pegado      = ref(false)
const cargando    = ref(false)
const errorArchivo = ref('')
const inputRef    = ref<HTMLInputElement | null>(null)

type FilaPreview = TablesInsert<'integrantes'> & { _error?: string; _alumno: string; _prog: string }
const preview = ref<FilaPreview[]>([])

const CABECERAS_ESPERADAS = ['CODIGO', 'NOMBRES', 'FACULTAD', 'PROGRAMA ESTUDIO', 'CICLO', 'GRUPO']

function abrirSelector() {
  errorArchivo.value = ''
  inputRef.value?.click()
}

async function onArchivo(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!inputRef.value) return
  inputRef.value.value = ''           // reset para permitir re-selección del mismo archivo
  if (!file) return

  errorArchivo.value = ''
  cargando.value     = true
  pegado.value       = false
  preview.value      = []

  try {
    const buffer   = await file.arrayBuffer()
    const wb       = new ExcelJS.Workbook()
    await wb.xlsx.load(buffer)

    const ws = wb.worksheets[0]
    if (!ws) throw new Error('El archivo no tiene hojas.')

    // Leer todas las filas como valores de texto
    const filas: string[][] = []
    ws.eachRow((row) => {
      filas.push(
        (row.values as (ExcelJS.CellValue | null)[])
          .slice(1)                              // exceljs indexa desde 1; slice(1) lo convierte a 0-based
          .map((v) => (v === null || v === undefined ? '' : String(v).trim())),
      )
    })

    if (!filas.length) throw new Error('La hoja está vacía.')

    // Detectar fila de cabecera: buscar la primera fila que contenga "ALUMNO"
    let inicioData = 0
    const primeraFila = filas[0].map((c) => c.toUpperCase())
    if (primeraFila.some((c) => c.includes('NOMBRES') || c.includes('CODIGO'))) {
      // Verificar que las cabeceras esperadas estén presentes
      const faltantes = CABECERAS_ESPERADAS.filter(
        (cab) => !primeraFila.some((c) => c.includes(cab)),
      )
      if (faltantes.length) {
        throw new Error(`Cabeceras no encontradas: ${faltantes.join(', ')}.\nSe esperan: ${CABECERAS_ESPERADAS.join(' · ')}`)
      }
      // Mapear índices reales por nombre de columna
      const idxCodigo   = primeraFila.findIndex((c) => c.includes('CODIGO'))
      const idxAlumno   = primeraFila.findIndex((c) => c.includes('NOMBRES'))
      const idxFacultad = primeraFila.findIndex((c) => c.includes('FACULTAD'))
      const idxPrograma = primeraFila.findIndex((c) => c.includes('PROGRAMA'))
      const idxCiclo    = primeraFila.findIndex((c) => c.includes('CICLO'))
      const idxGrupo    = primeraFila.findIndex((c) => c.includes('GRUPO'))
      inicioData = 1

      procesarFilas(filas.slice(inicioData), { idxCodigo, idxAlumno, idxFacultad, idxPrograma, idxCiclo, idxGrupo })
    } else {
      // Sin cabecera → asumir orden fijo: CODIGO ALUMNO FACULTAD PROGRAMA CICLO GRUPO
      procesarFilas(filas, { idxCodigo: 0, idxAlumno: 1, idxFacultad: 2, idxPrograma: 3, idxCiclo: 4, idxGrupo: 5 })
    }

    pegado.value = true
  } catch (err: any) {
    errorArchivo.value = err.message ?? 'No se pudo leer el archivo.'
  } finally {
    cargando.value = false
  }
}

function procesarFilas(
  filas: string[][],
  idx: { idxCodigo: number; idxAlumno: number; idxFacultad: number; idxPrograma: number; idxCiclo: number; idxGrupo: number },
) {
  const hoy = new Date().toISOString().split('T')[0]

  const resultado: FilaPreview[] = filas
    .filter((c) => c.some((v) => v !== ''))   // descartar filas completamente vacías
    .map((c) => {
      const codigo   = c[idx.idxCodigo]   || null
      const nombreCompleto = c[idx.idxAlumno]   ?? ''
      const facultad = c[idx.idxFacultad] ?? ''
      const programa = c[idx.idxPrograma] ?? ''
      const ciclo    = c[idx.idxCiclo]    ?? ''
      const grupo    = c[idx.idxGrupo]    ?? ''

      // NOMBRES → "AP.PATERNO AP.MATERNO NOMBRE1 NOMBRE2..."
      // Si hay coma: antes=apellidos, después=nombres
      // Si no hay coma: primeras 2 palabras=apellidos, resto=nombres
      let apellidos = ''
      let nombres   = ''
      const coma = nombreCompleto.indexOf(',')
      if (coma >= 0) {
        apellidos = nombreCompleto.slice(0, coma).trim()
        nombres   = nombreCompleto.slice(coma + 1).trim()
      } else {
        const palabras = nombreCompleto.trim().split(/\s+/)
        apellidos = palabras.slice(0, 2).join(' ')
        nombres   = palabras.slice(2).join(' ')
      }

      const extra = [
        facultad && `Facultad: ${facultad}`,
        programa && `Programa: ${programa}`,
        ciclo    && `Ciclo: ${ciclo}`,
        grupo    && `Grupo: ${grupo}`,
      ].filter(Boolean).join(' | ')

      const _error: string | undefined =
        !nombreCompleto ? 'Columna NOMBRES vacía' :
        !apellidos      ? 'No se pudo leer apellidos' :
        !nombres        ? 'No se pudo leer nombres (menos de 3 palabras)' :
        undefined

      return {
        equipo_id:            props.equipoId,
        nombres,
        apellidos,
        codigo_universitario: codigo,
        fecha_inscripcion:    hoy,
        observaciones:        extra || null,
        _alumno:              nombreCompleto,
        _prog:                [facultad, programa].filter(Boolean).join(' · ') || '—',
        _error,
      }
    })

  // Marcar códigos duplicados dentro del lote
  const vistos = new Map<string, number>()
  resultado.forEach((f, i) => {
    if (f._error || !f.codigo_universitario) return
    if (vistos.has(f.codigo_universitario)) {
      f._error = `Código duplicado (fila ${vistos.get(f.codigo_universitario)! + 1})`
    } else {
      vistos.set(f.codigo_universitario, i)
    }
  })

  preview.value = resultado
}

function confirmar() {
  const validas = preview.value
    .filter((f) => !f._error)
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    .map(({ _error, _alumno, _prog, ...rest }) => rest)
  emit('importar', validas)
  visible.value  = false
  preview.value  = []
  pegado.value   = false
  errorArchivo.value = ''
}

function cerrar() {
  visible.value      = false
  preview.value      = []
  pegado.value       = false
  errorArchivo.value = ''
}

const errores = computed(() => preview.value.filter((f) => f._error).length)
const validas = computed(() => preview.value.length - errores.value)
</script>

<template>
  <Button label="Importar Excel" icon="pi pi-upload" severity="secondary" size="small" @click="visible = true" />

  <!-- Input oculto para selección de archivo -->
  <input
    ref="inputRef"
    type="file"
    accept=".xlsx,.xls"
    style="display:none"
    @change="onArchivo"
  />

  <Dialog
    v-model:visible="visible"
    header="Importar integrantes desde Excel"
    modal
    :style="{ width: '95vw', maxWidth: '54rem' }"
    @hide="cerrar"
  >
    <div class="importar">

      <!-- Zona de carga -->
      <div class="importar__zona" @click="abrirSelector" @dragover.prevent @drop.prevent="onArchivo">
        <i class="pi pi-file-excel importar__zona-icono" />
        <p class="importar__zona-titulo">
          {{ cargando ? 'Leyendo archivo…' : 'Selecciona o arrastra tu archivo Excel' }}
        </p>
        <p class="importar__zona-sub">
          Columnas esperadas: <strong>CODIGO · NOMBRES · FACULTAD · PROGRAMA ESTUDIO · CICLO · GRUPO</strong>
        </p>
        <Button
          label="Elegir archivo .xlsx / .xls"
          icon="pi pi-folder-open"
          severity="secondary"
          size="small"
          :loading="cargando"
          @click.stop="abrirSelector"
        />
      </div>

      <!-- Error de lectura -->
      <div v-if="errorArchivo" class="importar__error">
        <i class="pi pi-exclamation-triangle" />
        <pre>{{ errorArchivo }}</pre>
      </div>

      <!-- Preview -->
      <template v-if="pegado">
        <DataTable
          :value="preview"
          size="small"
          striped-rows
          scroll-height="320px"
          scrollable
          class="importar__tabla"
        >
          <Column field="codigo_universitario" header="Código"             style="min-width:7rem" />
          <Column field="_alumno"              header="Nombres completos"  style="min-width:14rem" />
          <Column field="apellidos"            header="Apellidos"          style="min-width:9rem" />
          <Column field="nombres"              header="Nombres"            style="min-width:9rem" />
          <Column field="_prog"                header="Facultad / Programa" style="min-width:12rem" />
          <Column header="Estado"              style="min-width:11rem">
            <template #body="{ data }">
              <Tag v-if="data._error"  severity="danger"  :value="data._error" />
              <Tag v-else              severity="success" value="OK" />
            </template>
          </Column>
        </DataTable>

        <p class="importar__resumen">
          <span class="text-green fw-600">{{ validas }} válidas</span>
          <template v-if="errores > 0">
            · <span class="text-red fw-600">{{ errores }} con errores</span> (se omitirán)
          </template>
        </p>
      </template>

    </div>

    <template #footer>
      <Button label="Cancelar" severity="secondary" text @click="cerrar" />
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
.importar { display: flex; flex-direction: column; gap: 0.85rem; }

.importar__zona {
  border: 2px dashed #d1d5db;
  border-radius: 12px;
  padding: 2rem 1.5rem;
  display: flex; flex-direction: column; align-items: center; gap: 0.6rem;
  cursor: pointer; text-align: center;
  transition: border-color .15s, background .15s;
  background: #fafafa;
}
.importar__zona:hover { border-color: #16a34a; background: #f0fdf4; }

.importar__zona-icono { font-size: 2.2rem; color: #16a34a; }
.importar__zona-titulo { margin: 0; font-size: 0.95rem; font-weight: 600; color: #374151; }
.importar__zona-sub   { margin: 0; font-size: 0.78rem; color: #9ca3af; }

.importar__error {
  display: flex; align-items: flex-start; gap: 0.5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: 0.75rem 1rem; color: #b91c1c; font-size: 0.82rem;
}
.importar__error pre { margin: 0; white-space: pre-wrap; }

.importar__tabla   { font-size: 0.85rem; }
.importar__resumen { margin: 0; font-size: 0.85rem; }
.text-green { color: #16a34a; }
.text-red   { color: #dc2626; }
.fw-600     { font-weight: 600; }
</style>
