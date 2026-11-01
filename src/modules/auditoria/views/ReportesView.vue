<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { useCampamentoStore } from '@/stores/campamento'

const campStore    = useCampamentoStore()
const generando    = ref<string | null>(null)
const error        = ref('')
const mostrarAyuda = ref(false)

// ── Helpers ────────────────────────────────────────────────────────────────────

async function fetchRanking() {
  let q = supabase.from('v_puntaje_equipo').select('*').order('posicion')
  if (campStore.selectedId) q = q.eq('campamento_id', campStore.selectedId)
  const { data, error: err } = await q
  if (err) throw err
  return data ?? []
}

async function fetchAuditoria() {
  const { data, error: err } = await supabase
    .from('v_auditoria_legible')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1000)
  if (err) throw err
  return data ?? []
}

async function fetchIncidencias() {
  const { data, error: err } = await supabase
    .from('incidencias')
    .select('*, incidencia_codigos(codigo, nombre, tipo)')
    .order('created_at', { ascending: false })
  if (err) throw err
  return data ?? []
}

// ── Excel: ranking ─────────────────────────────────────────────────────────────

async function exportarRankingExcel() {
  generando.value = 'ranking-excel'
  error.value     = ''
  try {
    const rows = await fetchRanking()
    const { default: ExcelJS } = await import('exceljs')
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('Ranking')

    ws.columns = [
      { header: 'Pos',        key: 'posicion',       width: 6  },
      { header: 'Equipo',     key: 'equipo_nombre',  width: 22 },
      { header: 'Medalla',    key: 'medalla',        width: 14 },
      { header: 'Inscr.',     key: 'pts_inscripcion',width: 8  },
      { header: 'Rúbrica',    key: 'pts_rubrica',    width: 9  },
      { header: 'Liderazgo',  key: 'pts_liderazgo',  width: 10 },
      { header: 'Asistencia', key: 'pts_asistencia', width: 10 },
      { header: 'Base',       key: 'pts_base',       width: 8  },
      { header: 'Bonus',      key: 'pts_bonus',      width: 8  },
      { header: 'Deméritos',  key: 'pts_demeritos',  width: 10 },
      { header: 'Bruto',      key: 'pts_bruto',      width: 8  },
      { header: '/ 1000',     key: 'pts_escala',     width: 8  },
    ]

    const headerRow = ws.getRow(1)
    headerRow.font = { bold: true }
    headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE5E7EB' } }

    rows.forEach((r) => ws.addRow(r))

    const buf = await wb.xlsx.writeBuffer()
    descargar(buf, 'ranking-lidercamp.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  } catch (e: any) {
    error.value = e.message ?? 'Error al generar'
  } finally {
    generando.value = null
  }
}

// ── Excel: auditoría ───────────────────────────────────────────────────────────

async function exportarAuditoriaExcel() {
  generando.value = 'audit-excel'
  error.value     = ''
  try {
    const rows = await fetchAuditoria()
    const { default: ExcelJS } = await import('exceljs')
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('Auditoría')

    ws.columns = [
      { header: 'Fecha',     key: 'created_at',       width: 20 },
      { header: 'Tabla',     key: 'tabla',            width: 22 },
      { header: 'Acción',    key: 'accion',           width: 9  },
      { header: 'ID',        key: 'registro_id',      width: 38 },
      { header: 'Evaluador', key: 'evaluador_nombre', width: 22 },
      { header: 'Rol',       key: 'evaluador_rol',    width: 12 },
    ]

    const headerRow = ws.getRow(1)
    headerRow.font = { bold: true }
    headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE5E7EB' } }

    rows.forEach((r) => ws.addRow({
      ...r,
      created_at: r.created_at ? new Date(r.created_at).toLocaleString('es-PE') : '',
    }))

    const buf = await wb.xlsx.writeBuffer()
    descargar(buf, 'auditoria-lidercamp.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  } catch (e: any) {
    error.value = e.message ?? 'Error al generar'
  } finally {
    generando.value = null
  }
}

// ── PDF: ranking ───────────────────────────────────────────────────────────────

async function exportarRankingPdf() {
  generando.value = 'ranking-pdf'
  error.value     = ''
  try {
    const rows = await fetchRanking()
    const { jsPDF } = await import('jspdf')
    const { default: autoTable } = await import('jspdf-autotable')

    const doc = new jsPDF({ orientation: 'landscape' })
    doc.setFontSize(14)
    doc.text('Ranking LiderCamp 2026-II', 14, 16)
    doc.setFontSize(9)
    doc.text(`Generado: ${new Date().toLocaleString('es-PE')}`, 14, 22)

    autoTable(doc, {
      startY: 26,
      head: [['Pos', 'Equipo', 'Medalla', 'INS', 'RUB', 'LID', 'ASIS', 'Base', 'Bonus', 'Dem.', 'Bruto', '/1000']],
      body: rows.map((r) => [
        r.posicion,
        r.equipo_nombre,
        r.medalla ?? '—',
        r.pts_inscripcion,
        r.pts_rubrica,
        r.pts_liderazgo,
        r.pts_asistencia,
        r.pts_base,
        r.pts_bonus,
        r.pts_demeritos,
        r.pts_bruto,
        r.pts_escala,
      ]),
      styles: { fontSize: 8 },
      headStyles: { fillColor: [22, 163, 74] },
    })

    doc.save('ranking-lidercamp.pdf')
  } catch (e: any) {
    error.value = e.message ?? 'Error al generar'
  } finally {
    generando.value = null
  }
}

// ── Excel: incidencias ─────────────────────────────────────────────────────────

async function exportarIncidenciasExcel() {
  generando.value = 'inc-excel'
  error.value     = ''
  try {
    const rows = await fetchIncidencias()
    const { default: ExcelJS } = await import('exceljs')
    const wb = new ExcelJS.Workbook()
    const ws = wb.addWorksheet('Incidencias')

    ws.columns = [
      { header: 'Fecha',  key: 'fecha',  width: 12 },
      { header: 'Hora',   key: 'hora',   width: 8  },
      { header: 'Código', key: 'codigo', width: 8  },
      { header: 'Tipo',   key: 'tipo',   width: 10 },
      { header: 'Estado', key: 'estado', width: 12 },
      { header: 'Puntos', key: 'puntos', width: 8  },
      { header: 'Hecho',  key: 'hecho',  width: 40 },
    ]

    const headerRow = ws.getRow(1)
    headerRow.font = { bold: true }
    headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE5E7EB' } }

    rows.forEach((r: any) => ws.addRow({
      fecha:  r.fecha  ?? '',
      hora:   r.hora   ?? '',
      codigo: r.codigo ?? '',
      tipo:   (r.incidencia_codigos as any)?.tipo ?? '',
      estado: r.estado ?? '',
      puntos: r.puntos ?? 0,
      hecho:  r.hecho  ?? '',
    }))

    const buf = await wb.xlsx.writeBuffer()
    descargar(buf, 'incidencias-lidercamp.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  } catch (e: any) {
    error.value = e.message ?? 'Error al generar'
  } finally {
    generando.value = null
  }
}

// ── Utilidad: descargar blob ───────────────────────────────────────────────────

function descargar(data: ArrayBuffer | Blob, nombre: string, mime: string) {
  const blob = data instanceof Blob ? data : new Blob([data], { type: mime })
  const url  = URL.createObjectURL(blob)
  const a    = document.createElement('a')
  a.href     = url
  a.download = nombre
  a.click()
  URL.revokeObjectURL(url)
}

// ── Config de reportes ─────────────────────────────────────────────────────────

const reportes = [
  {
    id:     'ranking-excel',
    titulo: 'Ranking completo',
    desc:   'Puntajes por equipo con todos los componentes: inscripción, rúbrica, liderazgo, asistencia, bonus y deméritos.',
    icono:  'pi-trophy',
    accion: exportarRankingExcel,
    ext:    'Excel',
    color:  'green',
  },
  {
    id:     'ranking-pdf',
    titulo: 'Ranking imprimible',
    desc:   'Tabla de ranking en formato PDF, lista para imprimir o compartir.',
    icono:  'pi-print',
    accion: exportarRankingPdf,
    ext:    'PDF',
    color:  'red',
  },
  {
    id:     'audit-excel',
    titulo: 'Historial de auditoría',
    desc:   'Todos los cambios registrados en el sistema durante el campamento (hasta 1 000 registros).',
    icono:  'pi-history',
    accion: exportarAuditoriaExcel,
    ext:    'Excel',
    color:  'green',
  },
  {
    id:     'inc-excel',
    titulo: 'Bonus y deméritos',
    desc:   'Lista completa de incidencias registradas: código, tipo, estado, puntos y descripción del hecho.',
    icono:  'pi-exclamation-triangle',
    accion: exportarIncidenciasExcel,
    ext:    'Excel',
    color:  'green',
  },
]
</script>

<template>
  <div class="max-w-2xl mx-auto px-3 py-4 sm:px-6">

    <!-- Encabezado -->
    <div class="flex items-center justify-between mb-5 gap-2">
      <div class="flex items-center gap-2">
        <i class="pi pi-download text-green-700 text-xl" />
        <h1 class="text-lg font-extrabold text-gray-800">Reportes</h1>
      </div>
      <button
        class="w-10 h-10 rounded-full bg-green-50 border border-green-200 text-green-700 font-bold text-base flex items-center justify-center hover:bg-green-100 transition"
        title="¿Qué son los reportes?"
        @click="mostrarAyuda = true"
      >?</button>
    </div>

    <!-- Error global -->
    <div v-if="error" class="flex items-start gap-2 bg-red-50 border border-red-200 rounded-xl p-4 mb-4 text-red-700 text-sm">
      <i class="pi pi-exclamation-triangle mt-0.5 flex-shrink-0" />
      <span>{{ error }}</span>
    </div>

    <!-- Estado de generación -->
    <div v-if="generando" class="flex items-center gap-3 bg-green-50 border border-green-200 rounded-xl px-4 py-3 mb-4 text-green-700 text-sm font-medium">
      <i class="pi pi-spin pi-spinner" />
      Generando archivo, un momento…
    </div>

    <!-- Tarjetas de reportes -->
    <div class="flex flex-col gap-3">
      <div
        v-for="rep in reportes"
        :key="rep.id"
        class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm flex items-start gap-4"
        :class="{ 'opacity-60': generando && generando !== rep.id }"
      >
        <!-- Icono -->
        <div
          class="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 text-xl"
          :class="rep.color === 'red' ? 'bg-red-50 text-red-500' : 'bg-green-50 text-green-600'"
        >
          <i :class="['pi', rep.icono]" />
        </div>

        <!-- Info -->
        <div class="flex-1 min-w-0">
          <p class="font-bold text-gray-800 text-sm">{{ rep.titulo }}</p>
          <p class="text-xs text-gray-500 mt-0.5 leading-relaxed">{{ rep.desc }}</p>
          <!-- Formato badge -->
          <span
            class="inline-block mt-2 text-xs font-bold px-2 py-0.5 rounded-full"
            :class="rep.color === 'red'
              ? 'bg-red-100 text-red-600'
              : 'bg-green-100 text-green-700'"
          >{{ rep.ext }}</span>
        </div>

        <!-- Botón -->
        <button
          class="flex-shrink-0 flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-xl font-bold text-sm min-h-[44px] min-w-[72px] text-white transition disabled:opacity-50 disabled:cursor-default"
          :class="rep.color === 'red'
            ? 'bg-red-500 hover:bg-red-600'
            : 'bg-green-600 hover:bg-green-700'"
          :disabled="!!generando"
          @click="rep.accion"
        >
          <i v-if="generando === rep.id" class="pi pi-spin pi-spinner text-sm" />
          <i v-else class="pi text-sm" :class="rep.color === 'red' ? 'pi-file-pdf' : 'pi-file-excel'" />
          <span>{{ rep.ext }}</span>
        </button>
      </div>
    </div>

    <!-- Nota al pie -->
    <p class="text-xs text-gray-400 text-center mt-6 leading-relaxed">
      Los archivos se generan en tu dispositivo con los datos actuales.<br class="hidden sm:inline" />
      No se almacenan en el servidor.
    </p>

    <!-- Modal de ayuda -->
    <Teleport to="body">
      <div
        v-if="mostrarAyuda"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="mostrarAyuda = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[80vh] overflow-y-auto">
          <!-- Handle (mobile) -->
          <div class="flex justify-center pt-3 sm:hidden">
            <div class="w-10 h-1 rounded-full bg-gray-200" />
          </div>
          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-download text-green-600 text-sm" />
              </div>
              <h2 class="font-bold text-gray-800">Reportes — ¿cómo funcionan?</h2>
            </div>
            <button
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-400"
              @click="mostrarAyuda = false"
            >
              <i class="pi pi-times text-sm" />
            </button>
          </div>
          <!-- Contenido -->
          <div class="px-5 py-4 space-y-4 text-sm text-gray-700">
            <div>
              <p class="font-semibold text-gray-800 mb-1">
                <i class="pi pi-info-circle mr-1.5 text-green-600" />¿Qué son los reportes?
              </p>
              <p class="text-xs text-gray-600 leading-relaxed">
                Permiten exportar los datos del campamento a archivos descargables.
                Se generan directamente en tu dispositivo con la información más reciente de la base de datos.
              </p>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-2">
                <i class="pi pi-list mr-1.5 text-green-600" />Reportes disponibles
              </p>
              <ul class="text-xs text-gray-600 space-y-2">
                <li class="flex gap-2">
                  <span class="bg-green-100 text-green-700 font-bold px-1.5 py-0.5 rounded text-[11px] flex-shrink-0 h-fit">XLSX</span>
                  <span><strong>Ranking completo</strong> — puntajes detallados por equipo con todos los componentes.</span>
                </li>
                <li class="flex gap-2">
                  <span class="bg-red-100 text-red-600 font-bold px-1.5 py-0.5 rounded text-[11px] flex-shrink-0 h-fit">PDF</span>
                  <span><strong>Ranking imprimible</strong> — tabla resumida en formato PDF, ideal para mostrar en pantalla o imprimir.</span>
                </li>
                <li class="flex gap-2">
                  <span class="bg-green-100 text-green-700 font-bold px-1.5 py-0.5 rounded text-[11px] flex-shrink-0 h-fit">XLSX</span>
                  <span><strong>Auditoría</strong> — historial de cambios realizados en el sistema (últimos 1 000 registros).</span>
                </li>
                <li class="flex gap-2">
                  <span class="bg-green-100 text-green-700 font-bold px-1.5 py-0.5 rounded text-[11px] flex-shrink-0 h-fit">XLSX</span>
                  <span><strong>Incidencias</strong> — bonus y deméritos con código, tipo, estado y descripción.</span>
                </li>
              </ul>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-1">
                <i class="pi pi-exclamation-circle mr-1.5 text-green-600" />Consideraciones
              </p>
              <p class="text-xs text-gray-600 leading-relaxed">
                Solo un reporte puede generarse a la vez. El botón se desactiva mientras se procesa.
                Si hay un error, aparecerá un mensaje en la parte superior.
              </p>
            </div>
          </div>
          <div class="px-5 pb-5">
            <button
              class="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm transition"
              @click="mostrarAyuda = false"
            >Entendido</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
