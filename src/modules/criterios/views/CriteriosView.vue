<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'
import {
  criteriosService,
  plantillasService,
  categoriasService,
  tiposCalculoService,
  type Criterio,
  type Plantilla,
  type PlantillaItem,
  type CategoriaCriterio,
  type TipoCalculo,
} from '@/modules/criterios/services/criterios.service'

const session   = useSessionStore()
const campStore = useCampamentoStore()
const esAdmin   = computed(() => session.rol === 'admin')

// ── Tabs ──────────────────────────────────────────────────────────────────────
type Tab = 'general' | 'campamento'
const tabActivo = ref<Tab>('general')

// ── Estado global ─────────────────────────────────────────────────────────────
const criterios   = ref<Criterio[]>([])
const plantillas  = ref<Plantilla[]>([])
const categorias  = ref<CategoriaCriterio[]>([])
const cargando    = ref(true)
const error       = ref('')

// ── Tab 1: items por plantilla (cargados al expandir) ─────────────────────────
const itemsPorPlantilla  = ref<Record<string, PlantillaItem[]>>({})
const expandidas         = ref<Set<string>>(new Set())
const cargandoExpansion  = ref<string | null>(null)

// ── Tab 1: plantilla seleccionada para usar ───────────────────────────────────
const plantillaSeleccionada = ref<Plantilla | null>(null)
// ID de la plantilla que fue aplicada al campamento actual (persistido en localStorage)
const plantillaEnUsoId = ref<string | null>(null)

// ── Tab 2: copia de trabajo (en memoria, independiente de la plantilla) ───────
const workingIds         = ref<string[]>([])
const workingIdsSnapshot = ref<string[]>([])  // snapshot en el momento del último apply

// ── Tab 2: aplicar ────────────────────────────────────────────────────────────
const aplicando    = ref(false)
const aplicadoOk   = ref(false)
const errorAplicar = ref('')

// ¿El working copy tiene cambios respecto al último apply?
const hayModificaciones = computed(() => {
  if (!aplicadoOk.value) return false
  const a = new Set(workingIds.value)
  const b = new Set(workingIdsSnapshot.value)
  if (a.size !== b.size) return true
  for (const id of a) if (!b.has(id)) return true
  return false
})

// ── Claves localStorage ────────────────────────────────────────────────────────
function lsKey(campId: string)        { return `lc_plantilla_en_uso_${campId}` }
function lsWorkingKey(campId: string) { return `lc_working_ids_${campId}` }
function lsSnapshotKey(campId: string){ return `lc_snapshot_ids_${campId}` }
function lsSelKey(campId: string)     { return `lc_plantilla_sel_${campId}` }

/** Restaura todo el estado de Tab 2 desde localStorage para el campamento actual */
function cargarEstadoCampamento() {
  const campId = campStore.selectedId
  if (!campId) {
    plantillaEnUsoId.value    = null
    workingIds.value          = []
    workingIdsSnapshot.value  = []
    aplicadoOk.value          = false
    return
  }

  plantillaEnUsoId.value = localStorage.getItem(lsKey(campId))

  const rawWorking  = localStorage.getItem(lsWorkingKey(campId))
  const rawSnapshot = localStorage.getItem(lsSnapshotKey(campId))
  workingIds.value         = rawWorking  ? (JSON.parse(rawWorking)  as string[]) : []
  workingIdsSnapshot.value = rawSnapshot ? (JSON.parse(rawSnapshot) as string[]) : []
  aplicadoOk.value         = workingIdsSnapshot.value.length > 0

  // Restaurar plantilla seleccionada (puede ser null si aún no se cargaron plantillas)
  const selId = localStorage.getItem(lsSelKey(campId))
  if (selId && plantillas.value.length) {
    plantillaSeleccionada.value = plantillas.value.find((p) => p.id === selId) ?? null
  } else {
    plantillaSeleccionada.value = null
  }
}

/** Persiste el working copy actual en localStorage */
function persistirWorking() {
  if (!campStore.selectedId) return
  localStorage.setItem(lsWorkingKey(campStore.selectedId), JSON.stringify(workingIds.value))
}

/** Persiste la plantilla seleccionada */
function persistirSeleccionada() {
  if (!campStore.selectedId || !plantillaSeleccionada.value) return
  localStorage.setItem(lsSelKey(campStore.selectedId), plantillaSeleccionada.value.id)
}

// Observar cambios en workingIds para persistir automáticamente
watch(workingIds, persistirWorking, { deep: true })
// Observar cambios en plantillaSeleccionada para persistir
watch(plantillaSeleccionada, persistirSeleccionada)

// ── Constantes ────────────────────────────────────────────────────────────────
const PALETA_COLORES: Record<string, string> = {
  violet:  'bg-violet-100 text-violet-700',
  amber:   'bg-amber-100 text-amber-700',
  emerald: 'bg-emerald-100 text-emerald-700',
  sky:     'bg-sky-100 text-sky-700',
  rose:    'bg-rose-100 text-rose-700',
  slate:   'bg-slate-100 text-slate-700',
  indigo:  'bg-indigo-100 text-indigo-700',
  teal:    'bg-teal-100 text-teal-700',
  orange:  'bg-orange-100 text-orange-700',
  blue:    'bg-blue-100 text-blue-700',
  green:   'bg-green-100 text-green-700',
  purple:  'bg-purple-100 text-purple-700',
  red:     'bg-red-100 text-red-700',
  pink:    'bg-pink-100 text-pink-700',
  yellow:  'bg-yellow-100 text-yellow-700',
  gray:    'bg-gray-100 text-gray-600',
}
const PALETA_OPTIONS = [
  { label: 'Violeta',    value: 'violet',  hex: '#8b5cf6' },
  { label: 'Ámbar',      value: 'amber',   hex: '#f59e0b' },
  { label: 'Esmeralda',  value: 'emerald', hex: '#10b981' },
  { label: 'Azul cielo', value: 'sky',     hex: '#0ea5e9' },
  { label: 'Rosa',       value: 'rose',    hex: '#f43f5e' },
  { label: 'Pizarra',    value: 'slate',   hex: '#64748b' },
  { label: 'Índigo',     value: 'indigo',  hex: '#6366f1' },
  { label: 'Teal',       value: 'teal',    hex: '#14b8a6' },
  { label: 'Naranja',    value: 'orange',  hex: '#f97316' },
  { label: 'Azul',       value: 'blue',    hex: '#3b82f6' },
  { label: 'Verde',      value: 'green',   hex: '#22c55e' },
  { label: 'Púrpura',    value: 'purple',  hex: '#a855f7' },
]

function toSlug(str: string): string {
  return str
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
}
const LABELS_TIPO = computed<Record<string, string>>(() =>
  Object.fromEntries(tiposCalculo.value.map((t) => [t.clave, t.nombre]))
)

function labelCategoria(clave: string): string {
  return categorias.value.find((c) => c.clave === clave)?.nombre ?? clave
}
function colorCategoria(clave: string): string {
  const color = categorias.value.find((c) => c.clave === clave)?.color ?? 'gray'
  return PALETA_COLORES[color] ?? 'bg-gray-100 text-gray-600'
}

// ── Computed ──────────────────────────────────────────────────────────────────
function agrupar(lista: Criterio[]) {
  const mapa: Record<string, Criterio[]> = {}
  for (const c of lista) {
    if (!mapa[c.categoria]) mapa[c.categoria] = []
    ;(mapa[c.categoria] as Criterio[]).push(c)
  }
  const orden = categorias.value.length
    ? categorias.value.map((c) => c.clave)
    : ['inscripcion', 'armado', 'orden_cocina', 'ceremonias_participacion', 'liderazgo']
  const extra = Object.keys(mapa).filter((k) => !orden.includes(k))
  return [...orden, ...extra]
    .filter((cat) => mapa[cat]?.length)
    .map((cat) => ({ categoria: cat, items: mapa[cat] ?? [] }))
}

/** Criterios de una plantilla según sus items cargados */
function criteriosDePlantilla(plantillaId: string): Criterio[] {
  const ids = new Set((itemsPorPlantilla.value[plantillaId] ?? []).map((i) => i.criterio_id))
  return criterios.value.filter((c) => ids.has(c.id))
}

/** Copia de trabajo en Tab 2: criterios seleccionados */
const criteriosWorking = computed(() =>
  criterios.value.filter((c) => workingIds.value.includes(c.id)),
)
const workingPorCategoria = computed(() => agrupar(criteriosWorking.value))

/** Criterios disponibles para agregar en Tab 2 (los que NO están en la copia de trabajo) */
const criteriosDisponiblesTab2 = computed(() =>
  criterios.value.filter((c) => !workingIds.value.includes(c.id)),
)

// ── Carga inicial ─────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [c, p, cat, tc] = await Promise.all([
      criteriosService.getTodos(),
      plantillasService.getTodas(),
      categoriasService.getTodas(),
      tiposCalculoService.getTodos(),
    ])
    criterios.value  = c
    plantillas.value = p
    categorias.value = cat
    tiposCalculo.value = tc
    cargarEstadoCampamento()  // plantillas ya cargadas → restaura seleccionada también
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar'
  } finally {
    cargando.value = false
  }
})

// ── Tab 1: expandir/colapsar criterios de una plantilla ───────────────────────
async function toggleExpandir(plantillaId: string) {
  if (expandidas.value.has(plantillaId)) {
    expandidas.value.delete(plantillaId)
    return
  }
  expandidas.value.add(plantillaId)
  if (!itemsPorPlantilla.value[plantillaId]) {
    cargandoExpansion.value = plantillaId
    try {
      itemsPorPlantilla.value[plantillaId] = await plantillasService.getItems(plantillaId)
    } finally {
      cargandoExpansion.value = null
    }
  }
}

// ── Tab 1: agregar criterio a la plantilla ────────────────────────────────────
const dialogAgregarTab1  = ref(false)
const plantillaParaAgreg = ref<string>('')
const nuevoNombre1       = ref('')
const nuevaCategoria1    = ref('')
const agregandoTab1      = ref(false)
const errorAgregarTab1   = ref('')

function abrirAgregarTab1(plantillaId: string) {
  plantillaParaAgreg.value = plantillaId
  nuevoNombre1.value       = ''
  nuevaCategoria1.value    = categorias.value[0]?.clave ?? ''
  errorAgregarTab1.value   = ''
  dialogAgregarTab1.value  = true
}

function autoCodigoDeNombre(nombre: string): string {
  // Genera un código de 3 letras: iniciales de cada palabra, máximo 3
  const iniciales = nombre.trim().split(/\s+/).map((w) => w[0]?.toUpperCase() ?? '').join('').slice(0, 3)
  if (!iniciales) return 'CRI'
  // Si ya existe ese código, agrega sufijo numérico
  let codigo = iniciales
  let n = 2
  while (criterios.value.some((c) => c.codigo === codigo)) {
    codigo = iniciales.slice(0, 2) + n
    n++
  }
  return codigo
}

async function confirmarAgregarTab1() {
  if (!nuevoNombre1.value.trim() || !nuevaCategoria1.value) {
    errorAgregarTab1.value = 'Nombre y categoría son obligatorios.'
    return
  }
  agregandoTab1.value    = true
  errorAgregarTab1.value = ''
  try {
    const orden = criterios.value.length ? Math.max(...criterios.value.map((c) => c.orden)) + 1 : 10
    const nuevo = await criteriosService.crear({
      codigo:       autoCodigoDeNombre(nuevoNombre1.value),
      nombre:       nuevoNombre1.value.trim(),
      categoria:    nuevaCategoria1.value,
      tipo_calculo: 'rubrica',
      orden,
      activo:       true,
    })
    criterios.value.push(nuevo)
    criterios.value.sort((a, b) => a.orden - b.orden)
    await plantillasService.agregarCriterio(plantillaParaAgreg.value, nuevo.id)
    itemsPorPlantilla.value[plantillaParaAgreg.value] =
      await plantillasService.getItems(plantillaParaAgreg.value)
    dialogAgregarTab1.value = false
  } catch (e: unknown) {
    errorAgregarTab1.value = e instanceof Error ? e.message : 'Error al agregar'
  } finally {
    agregandoTab1.value = false
  }
}

// ── Tab 1: quitar criterio de la plantilla ────────────────────────────────────
async function quitarDePlantilla(plantillaId: string, criterioId: string) {
  try {
    await plantillasService.quitarCriterio(plantillaId, criterioId)
    itemsPorPlantilla.value[plantillaId] =
      (itemsPorPlantilla.value[plantillaId] ?? []).filter((i) => i.criterio_id !== criterioId)
  } catch { /* silencioso */ }
}

// ── Tab 1: "Usar" plantilla → inicializa la copia de trabajo en Tab 2 ─────────
// Diálogo de confirmación cuando ya hay una selección personalizada
const confirmarUsarVisible = ref(false)
const plantillaPendiente   = ref<Plantilla | null>(null)

function usarPlantilla(plantilla: Plantilla) {
  // Si ya hay un working copy con contenido diferente a esta plantilla, pedir confirmación
  if (workingIds.value.length > 0 && plantillaSeleccionada.value?.id !== plantilla.id) {
    plantillaPendiente.value   = plantilla
    confirmarUsarVisible.value = true
    return
  }
  _aplicarUsoPlantilla(plantilla)
}

async function _aplicarUsoPlantilla(plantilla: Plantilla) {
  confirmarUsarVisible.value  = false
  plantillaSeleccionada.value = plantilla
  errorAplicar.value          = ''

  // Si se cambia de plantilla, resetear snapshot y aplicadoOk para que el botón vuelva a estar activo
  if (plantillaEnUsoId.value !== plantilla.id) {
    aplicadoOk.value         = false
    workingIdsSnapshot.value = []
    if (campStore.selectedId) {
      localStorage.removeItem(lsSnapshotKey(campStore.selectedId))
    }
  }

  // Asegurar que los items estén cargados
  if (!itemsPorPlantilla.value[plantilla.id]) {
    cargandoExpansion.value = plantilla.id
    try {
      itemsPorPlantilla.value[plantilla.id] = await plantillasService.getItems(plantilla.id)
    } finally {
      cargandoExpansion.value = null
    }
  }

  // Copia de trabajo = criterios de la plantilla (reemplaza la anterior)
  workingIds.value = [...new Set(
    (itemsPorPlantilla.value[plantilla.id] ?? []).map((i) => i.criterio_id),
  )]

  tabActivo.value = 'campamento'
}

watch(() => campStore.selectedId, () => {
  errorAplicar.value = ''
  cargarEstadoCampamento()
})

// ── Tab 2: agregar criterio a la copia de trabajo ────────────────────────────
const dialogAgregarTab2  = ref(false)
const pasoAgregarTab2    = ref<'inicio' | 'categoria' | 'criterio'>('inicio')
const nuevoNombre2       = ref('')
const nuevaCategoria2    = ref('')
const catNombreInline    = ref('')
const catColorInline     = ref('slate')
const errorAgregarTab2   = ref('')
const agregandoTab2      = ref(false)

function abrirAgregarTab2() {
  errorAgregarTab2.value  = ''
  pasoAgregarTab2.value   = 'inicio'
  nuevoNombre2.value      = ''
  nuevaCategoria2.value   = OPCIONES_CATEGORIA.value[0]?.value ?? ''
  catNombreInline.value   = ''
  catColorInline.value    = 'slate'
  dialogAgregarTab2.value = true
}

async function confirmarAgregarTab2() {
  errorAgregarTab2.value = ''

  if (pasoAgregarTab2.value === 'categoria') {
    if (!catNombreInline.value.trim()) { errorAgregarTab2.value = 'El nombre de la categoría es obligatorio.'; return }
    agregandoTab2.value = true
    try {
      let clave = toSlug(catNombreInline.value.trim()) || 'categoria'
      if (categorias.value.some((c) => c.clave === clave)) clave = `${clave}_${Date.now().toString(36)}`
      const orden = categorias.value.length ? Math.max(...categorias.value.map((c) => c.orden)) + 1 : 1
      const nueva = await categoriasService.crear({ clave, nombre: catNombreInline.value.trim(), color: catColorInline.value, orden })
      categorias.value.push(nueva)
      categorias.value.sort((a, b) => a.orden - b.orden)
      nuevaCategoria2.value = nueva.clave
      catNombreInline.value = ''
      catColorInline.value  = 'slate'
      pasoAgregarTab2.value = 'criterio'
    } catch (e: unknown) {
      errorAgregarTab2.value = e instanceof Error ? e.message : 'Error al crear categoría'
    } finally {
      agregandoTab2.value = false
    }
    return
  }

  if (!nuevoNombre2.value.trim() || !nuevaCategoria2.value) {
    errorAgregarTab2.value = 'Nombre y categoría son obligatorios.'
    return
  }
  agregandoTab2.value = true
  try {
    const orden = criterios.value.length ? Math.max(...criterios.value.map((c) => c.orden)) + 1 : 10
    const nuevo = await criteriosService.crear({
      codigo:       autoCodigoDeNombre(nuevoNombre2.value),
      nombre:       nuevoNombre2.value.trim(),
      categoria:    nuevaCategoria2.value,
      tipo_calculo: 'rubrica',
      orden,
      activo:       true,
    })
    criterios.value.push(nuevo)
    criterios.value.sort((a, b) => a.orden - b.orden)
    if (!workingIds.value.includes(nuevo.id)) workingIds.value = [...workingIds.value, nuevo.id]
    dialogAgregarTab2.value = false
  } catch (e: unknown) {
    errorAgregarTab2.value = e instanceof Error ? e.message : 'Error al crear criterio'
  } finally {
    agregandoTab2.value = false
  }
}

// ── Tab 2: quitar criterio de la copia de trabajo ────────────────────────────
const confirmarQuitarVisible = ref(false)
const criterioAQuitar        = ref<Criterio | null>(null)

function abrirConfirmarQuitar(criterio: Criterio) {
  criterioAQuitar.value = criterio
  confirmarQuitarVisible.value = true
}

function confirmarQuitar() {
  if (!criterioAQuitar.value) return
  workingIds.value = workingIds.value.filter((id) => id !== criterioAQuitar.value!.id)
  confirmarQuitarVisible.value = false
}

// ── Tab 2: Aplicar al campamento ──────────────────────────────────────────────
async function aplicarAlCampamento() {
  if (!campStore.selectedId || !plantillaSeleccionada.value) return
  aplicando.value    = true
  errorAplicar.value = ''
  aplicadoOk.value   = false
  try {
    const plantillaItems = itemsPorPlantilla.value[plantillaSeleccionada.value.id] ?? []
    const payload = workingIds.value.flatMap((criterioId) => {
      const mis = plantillaItems.filter((i) => i.criterio_id === criterioId)
      if (mis.length > 0) {
        return mis.map((i) => ({
          criterio_id: i.criterio_id,
          momento:     i.momento,
          puntaje_max: i.puntaje_max,
          estado:      i.estado,
        }))
      }
      // Criterio agregado a la copia de trabajo pero no está en la plantilla → fila UNICO
      return [{ criterio_id: criterioId, momento: 'UNICO', puntaje_max: 100, estado: 'programado' }]
    })
    await plantillasService.aplicarACampamento(campStore.selectedId, payload)
    aplicadoOk.value         = true
    workingIdsSnapshot.value = [...workingIds.value]
    plantillaEnUsoId.value   = plantillaSeleccionada.value!.id
    const campId = campStore.selectedId
    localStorage.setItem(lsKey(campId),         plantillaSeleccionada.value!.id)
    localStorage.setItem(lsSnapshotKey(campId), JSON.stringify(workingIdsSnapshot.value))
    localStorage.setItem(lsWorkingKey(campId),  JSON.stringify(workingIds.value))
  } catch (e: unknown) {
    errorAplicar.value = e instanceof Error ? e.message : 'Error al aplicar'
  } finally {
    aplicando.value = false
  }
}

// ── Gestión de categorías ─────────────────────────────────────────────────────
const gestionCategoriasVisible = ref(false)
const dialogCategoria          = ref(false)
const categoriaEditando        = ref<CategoriaCriterio | null>(null)
const formCatClave             = ref('')
const formCatNombre            = ref('')
const formCatColor             = ref('slate')
const formCatOrden             = ref(0)
const guardandoCat             = ref(false)
const errorCat                 = ref('')

function abrirNuevaCategoria() {
  categoriaEditando.value = null
  formCatClave.value  = ''
  formCatNombre.value = ''
  formCatColor.value  = 'slate'
  formCatOrden.value  = categorias.value.length ? Math.max(...categorias.value.map((c) => c.orden)) + 1 : 1
  errorCat.value      = ''
  dialogCategoria.value = true
}

function abrirEditarCategoria(cat: CategoriaCriterio) {
  categoriaEditando.value = cat
  formCatClave.value  = cat.clave
  formCatNombre.value = cat.nombre
  formCatColor.value  = cat.color
  formCatOrden.value  = cat.orden
  errorCat.value      = ''
  dialogCategoria.value = true
}

async function guardarCategoria() {
  if (!formCatNombre.value.trim()) { errorCat.value = 'El nombre es obligatorio.'; return }
  guardandoCat.value = true; errorCat.value = ''
  try {
    if (categoriaEditando.value) {
      const act = await categoriasService.actualizar(categoriaEditando.value.clave, {
        nombre: formCatNombre.value.trim(),
        color:  formCatColor.value,
        orden:  formCatOrden.value,
      })
      const idx = categorias.value.findIndex((c) => c.clave === act.clave)
      if (idx !== -1) categorias.value[idx] = act
    } else {
      // Generar clave automáticamente desde el nombre; si colisiona agregar sufijo numérico
      let clave = toSlug(formCatNombre.value.trim()) || 'categoria'
      if (categorias.value.some((c) => c.clave === clave)) {
        clave = `${clave}_${Date.now().toString(36)}`
      }
      const nueva = await categoriasService.crear({
        clave,
        nombre: formCatNombre.value.trim(),
        color:  formCatColor.value,
        orden:  formCatOrden.value,
      })
      categorias.value.push(nueva)
    }
    categorias.value.sort((a, b) => a.orden - b.orden)
    dialogCategoria.value = false
  } catch (e: unknown) {
    errorCat.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardandoCat.value = false
  }
}

const confirmarElimCatVisible = ref(false)
const categoriaAEliminar      = ref<CategoriaCriterio | null>(null)
const eliminandoCat           = ref(false)
const errorElimCat            = ref('')

function abrirEliminarCategoria(cat: CategoriaCriterio) {
  categoriaAEliminar.value = cat; errorElimCat.value = ''
  confirmarElimCatVisible.value = true
}

async function confirmarEliminarCategoria() {
  if (!categoriaAEliminar.value) return
  eliminandoCat.value = true; errorElimCat.value = ''
  try {
    await categoriasService.eliminar(categoriaAEliminar.value.clave)
    categorias.value = categorias.value.filter((c) => c.clave !== categoriaAEliminar.value!.clave)
    confirmarElimCatVisible.value = false
  } catch (e: unknown) {
    errorElimCat.value = e instanceof Error ? e.message : 'No se puede eliminar (puede tener criterios asociados)'
  } finally {
    eliminandoCat.value = false
  }
}

// ── Form editar criterio (compartido entre Tab 1 y Tab 2) ─────────────────────
const OPCIONES_CATEGORIA = computed(() =>
  categorias.value.map((c) => ({ label: c.nombre, value: c.clave }))
)
const tiposCalculo = ref<TipoCalculo[]>([])
const OPCIONES_TIPO = computed(() =>
  tiposCalculo.value.map((t) => ({ label: t.nombre, value: t.clave }))
)

const dialogCriterio   = ref(false)
const criterioEditando = ref<Criterio | null>(null)
const formNombre       = ref('')
const formCategoria    = ref('')
const formTipo         = ref('')
const formActivo       = ref(true)
const formAbarca       = ref('')
const formNoAbarca     = ref('')
const formEvidencia    = ref('')
const guardando        = ref(false)
const errorDialog      = ref('')

function abrirEditarCriterio(criterio: Criterio) {
  criterioEditando.value = criterio
  formNombre.value       = criterio.nombre
  formCategoria.value    = criterio.categoria
  formTipo.value         = criterio.tipo_calculo
  formActivo.value       = criterio.activo
  formAbarca.value       = criterio.abarca    ?? ''
  formNoAbarca.value     = criterio.no_abarca ?? ''
  formEvidencia.value    = criterio.evidencia ?? ''
  errorDialog.value      = ''
  dialogCriterio.value   = true
}

function validarForm(): boolean {
  if (!formNombre.value.trim())  { errorDialog.value = 'El nombre es obligatorio.';      return false }
  if (!formCategoria.value)      { errorDialog.value = 'Selecciona una categoría.';      return false }
  if (!formTipo.value)           { errorDialog.value = 'Selecciona un tipo de cálculo.'; return false }
  return true
}

async function guardarCriterio() {
  if (!validarForm()) return
  guardando.value = true; errorDialog.value = ''
  try {
    const datos = {
      nombre:       formNombre.value.trim(),
      categoria:    formCategoria.value,
      tipo_calculo: formTipo.value,
      activo:       formActivo.value,
      abarca:       formAbarca.value.trim() || null,
      no_abarca:    formNoAbarca.value.trim() || null,
      evidencia:    formEvidencia.value.trim() || null,
    }
    if (criterioEditando.value) {
      const act = await criteriosService.actualizar(criterioEditando.value.id, datos)
      const idx = criterios.value.findIndex((c) => c.id === act.id)
      if (idx !== -1) criterios.value[idx] = act
    }
    criterios.value.sort((a, b) => a.orden - b.orden)
    dialogCriterio.value = false
  } catch (e: unknown) {
    errorDialog.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

// ── Form crear/editar plantilla ───────────────────────────────────────────────
const dialogPlantilla  = ref(false)
const esNuevaPlantilla = ref(false)
const plantillaEdit    = ref<Plantilla | null>(null)
const formPNombre      = ref('')
const formPDesc        = ref('')
const formPActivo      = ref(true)
const guardandoP       = ref(false)
const errorP           = ref('')

function abrirNuevaPlantilla() {
  esNuevaPlantilla.value = true; plantillaEdit.value = null
  formPNombre.value = ''; formPDesc.value = ''; formPActivo.value = true; errorP.value = ''
  dialogPlantilla.value = true
}

function abrirEditarPlantilla(p: Plantilla, ev: Event) {
  ev.stopPropagation()
  esNuevaPlantilla.value = false; plantillaEdit.value = p
  formPNombre.value = p.nombre; formPDesc.value = p.descripcion ?? ''; formPActivo.value = p.activo; errorP.value = ''
  dialogPlantilla.value = true
}

async function guardarPlantilla() {
  if (!formPNombre.value.trim()) { errorP.value = 'El nombre es obligatorio.'; return }
  guardandoP.value = true; errorP.value = ''
  try {
    const datos = { nombre: formPNombre.value.trim(), descripcion: formPDesc.value.trim() || null, activo: formPActivo.value }
    if (esNuevaPlantilla.value) {
      plantillas.value.push(await plantillasService.crear(datos))
    } else if (plantillaEdit.value) {
      const act = await plantillasService.actualizar(plantillaEdit.value.id, datos)
      const idx = plantillas.value.findIndex((p) => p.id === act.id)
      if (idx !== -1) plantillas.value[idx] = act
    }
    dialogPlantilla.value = false
  } catch (e: unknown) {
    errorP.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardandoP.value = false
  }
}

// ── Eliminar plantilla ────────────────────────────────────────────────────────
const confirmarElimPlantillaVisible = ref(false)
const plantillaAEliminar            = ref<Plantilla | null>(null)
const eliminandoP                   = ref(false)
const errorEliminP                  = ref('')

function abrirEliminarPlantilla(p: Plantilla, ev: Event) {
  ev.stopPropagation()
  plantillaAEliminar.value = p; errorEliminP.value = ''
  confirmarElimPlantillaVisible.value = true
}

async function confirmarEliminarPlantilla() {
  if (!plantillaAEliminar.value) return
  eliminandoP.value = true; errorEliminP.value = ''
  try {
    await plantillasService.eliminar(plantillaAEliminar.value.id)
    plantillas.value = plantillas.value.filter((p) => p.id !== plantillaAEliminar.value!.id)
    if (plantillaSeleccionada.value?.id === plantillaAEliminar.value.id) {
      plantillaSeleccionada.value = null; workingIds.value = []; tabActivo.value = 'general'
    }
    confirmarElimPlantillaVisible.value = false
  } catch (e: unknown) {
    errorEliminP.value = e instanceof Error ? e.message : 'Error al eliminar'
  } finally {
    eliminandoP.value = false
  }
}
</script>

<template>
  <div class="max-w-3xl mx-auto px-3 py-5 sm:px-6 pb-12">

    <!-- Encabezado -->
    <div class="flex items-center justify-between gap-3 flex-wrap mb-5">
      <h1 class="flex items-center gap-2 text-xl font-bold text-gray-900 m-0">
        <i class="pi pi-list-check text-green-600" />
        Criterios de evaluación
      </h1>
      <button
        v-if="esAdmin && tabActivo === 'general'"
        class="flex items-center gap-1.5 px-4 py-2.5 bg-white border border-gray-200 hover:border-green-400 hover:bg-green-50 text-gray-700 rounded-xl font-semibold text-sm min-h-[44px] transition shadow-sm"
        @click="abrirNuevaPlantilla"
      >
        <i class="pi pi-plus text-xs text-green-600" />
        Nueva plantilla
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 bg-gray-100 rounded-xl p-1 mb-5">
      <button
        class="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg font-semibold text-sm transition min-h-[44px]"
        :class="tabActivo === 'general' ? 'bg-white text-green-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'"
        @click="tabActivo = 'general'"
      >
        <i class="pi pi-clipboard text-sm" />
        Criterio General
      </button>
      <button
        class="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg font-semibold text-sm transition min-h-[44px]"
        :class="tabActivo === 'campamento' ? 'bg-white text-green-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'"
        @click="tabActivo = 'campamento'"
      >
        <i class="pi pi-building text-sm" />
        <span class="hidden sm:inline truncate max-w-[160px]">Criterios para {{ campStore.nombre ?? 'este campamento' }}</span>
        <span class="sm:hidden">Para este campamento</span>
      </button>
    </div>

    <!-- ════════════════════════════════════════════════════════ -->
    <!-- TAB 1: CRITERIO GENERAL                                  -->
    <!-- ════════════════════════════════════════════════════════ -->
    <template v-if="tabActivo === 'general'">

      <div v-if="cargando" class="flex justify-center py-16">
        <i class="pi pi-spin pi-spinner text-green-500 text-3xl" />
      </div>
      <div v-else-if="error" class="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">{{ error }}</div>

      <div v-else class="flex flex-col gap-4">

        <!-- Panel gestión de categorías (solo admin) -->
        <div v-if="esAdmin" class="bg-white border border-gray-200 rounded-2xl shadow-sm overflow-hidden">
          <button
            class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 transition"
            @click="gestionCategoriasVisible = !gestionCategoriasVisible"
          >
            <span class="flex items-center gap-2 text-sm font-semibold text-gray-700">
              <i class="pi pi-tags text-green-600 text-sm" />
              Categorías de criterios
              <span class="text-xs font-normal text-gray-400">({{ categorias.length }})</span>
            </span>
            <i :class="['pi text-xs text-gray-400', gestionCategoriasVisible ? 'pi-chevron-up' : 'pi-chevron-down']" />
          </button>
          <div v-if="gestionCategoriasVisible" class="border-t border-gray-100">
            <div v-if="!categorias.length" class="px-4 py-4 text-sm text-gray-400 text-center">No hay categorías.</div>
            <div v-else class="divide-y divide-gray-50">
              <div v-for="cat in categorias" :key="cat.clave" class="flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50 transition">
                <span class="inline-flex items-center justify-center w-5 h-5 rounded-full text-xs font-bold shrink-0" :class="colorCategoria(cat.clave)">
                  {{ cat.clave.charAt(0).toUpperCase() }}
                </span>
                <span class="text-xs font-mono text-gray-400 shrink-0 w-28 truncate">{{ cat.clave }}</span>
                <span class="text-sm text-gray-800 flex-1 min-w-0 truncate">{{ cat.nombre }}</span>
                <span class="text-xs font-semibold rounded-full px-2 py-0.5 shrink-0 hidden sm:block" :class="colorCategoria(cat.clave)">{{ cat.color }}</span>
                <div class="flex items-center gap-0.5 shrink-0">
                  <button class="flex items-center justify-center w-8 h-8 rounded-lg text-gray-400 hover:text-green-700 hover:bg-green-50 transition" title="Editar" @click="abrirEditarCategoria(cat)"><i class="pi pi-pencil text-xs" /></button>
                  <button class="flex items-center justify-center w-8 h-8 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition" title="Eliminar" @click="abrirEliminarCategoria(cat)"><i class="pi pi-trash text-xs" /></button>
                </div>
              </div>
            </div>
            <div class="px-4 py-3 border-t border-gray-50">
              <button class="flex items-center gap-1.5 text-sm font-semibold text-green-600 hover:text-green-800 transition" @click="abrirNuevaCategoria">
                <i class="pi pi-plus text-xs" /> Nueva categoría
              </button>
            </div>
          </div>
        </div>

        <div v-if="!plantillas.length" class="bg-white border-2 border-dashed border-gray-200 rounded-2xl px-6 py-10 text-center">
          <i class="pi pi-inbox text-4xl text-gray-300 mb-3 block" />
          <p class="text-base font-semibold text-gray-600 m-0">No hay plantillas de criterios</p>
          <p class="text-sm text-gray-400 mt-1">Crea la primera con "Nueva plantilla".</p>
        </div>

        <!-- Card por plantilla -->
        <div
          v-for="plantilla in plantillas"
          :key="plantilla.id"
          class="bg-white border-2 rounded-2xl shadow-sm overflow-hidden"
          :class="plantillaEnUsoId === plantilla.id ? 'border-emerald-400' : plantillaSeleccionada?.id === plantilla.id ? 'border-green-300' : 'border-gray-200'"
        >
          <!-- Cabecera -->
          <div class="bg-gradient-to-r from-green-50 to-emerald-50 px-5 py-4">
            <div class="flex items-start gap-3 flex-wrap">
              <div class="flex items-center justify-center w-11 h-11 bg-green-600 rounded-xl shadow shrink-0">
                <i class="pi pi-clipboard text-white text-lg" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <h2 class="text-base font-bold text-gray-900 m-0">{{ plantilla.nombre }}</h2>
                  <span v-if="plantillaEnUsoId === plantilla.id" class="flex items-center gap-1 text-xs bg-emerald-100 text-emerald-700 font-semibold rounded-full px-2.5 py-0.5">
                    <i class="pi pi-verified text-[10px]" /> En uso
                  </span>
                  <span v-if="plantillaSeleccionada?.id === plantilla.id && plantillaEnUsoId !== plantilla.id" class="flex items-center gap-1 text-xs bg-green-100 text-green-700 font-semibold rounded-full px-2.5 py-0.5">
                    <i class="pi pi-check text-[10px]" /> Seleccionada
                  </span>
                  <span v-if="!plantilla.activo" class="text-xs bg-red-100 text-red-600 font-semibold rounded-full px-2 py-0.5">Inactiva</span>
                </div>
                <p v-if="plantilla.descripcion" class="text-sm text-gray-600 m-0 mt-0.5">{{ plantilla.descripcion }}</p>
              </div>
              <div v-if="esAdmin" class="flex items-center gap-0.5 shrink-0">
                <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-green-700 hover:bg-white/70 transition" @click="abrirEditarPlantilla(plantilla, $event)">
                  <i class="pi pi-pencil text-sm" />
                </button>
                <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-red-600 hover:bg-white/70 transition" @click="abrirEliminarPlantilla(plantilla, $event)">
                  <i class="pi pi-trash text-sm" />
                </button>
              </div>
            </div>
          </div>

          <!-- Toggle ver criterios -->
          <div class="px-5 py-3 border-b border-gray-100">
            <button
              class="flex items-center gap-2 text-sm font-semibold text-gray-600 hover:text-green-700 transition"
              @click="toggleExpandir(plantilla.id)"
            >
              <i v-if="cargandoExpansion === plantilla.id" class="pi pi-spin pi-spinner text-xs" />
              <i v-else :class="['pi text-xs', expandidas.has(plantilla.id) ? 'pi-chevron-up' : 'pi-chevron-down']" />
              <template v-if="expandidas.has(plantilla.id)">
                Ocultar criterios
              </template>
              <template v-else>
                Ver criterios
                <span v-if="itemsPorPlantilla[plantilla.id]" class="text-xs font-normal text-gray-400">
                  ({{ new Set(itemsPorPlantilla[plantilla.id]!.map(i => i.criterio_id)).size }})
                </span>
              </template>
            </button>
          </div>

          <!-- Lista de criterios expandida -->
          <div v-if="expandidas.has(plantilla.id)" class="divide-y divide-gray-50">
            <div v-for="grupo in agrupar(criteriosDePlantilla(plantilla.id))" :key="grupo.categoria" class="px-5 py-3">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-xs font-bold rounded-full px-2.5 py-1" :class="colorCategoria(grupo.categoria)">
                  {{ labelCategoria(grupo.categoria) }}
                </span>
              </div>
              <div class="flex flex-col gap-1.5">
                <div
                  v-for="criterio in grupo.items"
                  :key="criterio.id"
                  class="flex items-center gap-2 bg-gray-50 rounded-xl px-3 py-2.5"
                >
                  <span class="text-xs font-bold bg-white border border-gray-200 text-gray-700 rounded-lg px-2 py-0.5 shrink-0">{{ criterio.codigo }}</span>
                  <span class="text-sm text-gray-800 flex-1 min-w-0 truncate">{{ criterio.nombre }}</span>
                  <span class="text-xs text-gray-400 hidden sm:block shrink-0">{{ LABELS_TIPO[criterio.tipo_calculo] ?? criterio.tipo_calculo }}</span>
                  <div v-if="esAdmin" class="flex items-center gap-0.5 shrink-0">
                    <button class="flex items-center justify-center w-7 h-7 rounded-lg text-gray-400 hover:text-green-700 hover:bg-green-50 transition" title="Editar criterio" @click="abrirEditarCriterio(criterio)">
                      <i class="pi pi-pencil text-xs" />
                    </button>
                    <button class="flex items-center justify-center w-7 h-7 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition" title="Quitar de esta plantilla" @click="quitarDePlantilla(plantilla.id, criterio.id)">
                      <i class="pi pi-times text-xs" />
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Sin criterios en la plantilla -->
            <div v-if="!criteriosDePlantilla(plantilla.id).length" class="px-5 py-6 text-center text-sm text-gray-400">
              Esta plantilla aún no tiene criterios.
            </div>

            <!-- Agregar criterio a la plantilla -->
            <div v-if="esAdmin" class="px-5 py-3 border-t border-gray-50">
              <button
                class="flex items-center gap-1.5 text-sm font-semibold text-green-600 hover:text-green-800 transition"
                @click="abrirAgregarTab1(plantilla.id)"
              >
                <i class="pi pi-plus text-xs" />
                Agregar criterio a esta plantilla
              </button>
            </div>
          </div>

          <!-- Pie: botón Usar -->
          <div class="px-5 py-3 border-t border-gray-100 flex items-center justify-between gap-3">
            <p class="text-xs text-gray-500 m-0">
              Selecciona esta plantilla para revisarla y aplicarla al campamento.
            </p>
            <button
              class="flex items-center gap-1.5 px-4 py-2.5 rounded-xl font-bold text-sm min-h-[44px] shadow-sm transition shrink-0"
              :class="plantillaSeleccionada?.id === plantilla.id
                ? 'bg-green-600 text-white hover:bg-green-700'
                : 'bg-white border border-green-300 text-green-700 hover:bg-green-50'"
              @click="usarPlantilla(plantilla)"
            >
              <i class="pi pi-check text-sm" v-if="plantillaSeleccionada?.id === plantilla.id" />
              <i class="pi pi-arrow-right text-sm" v-else />
              {{ plantillaSeleccionada?.id === plantilla.id ? 'Seleccionada' : 'Usar' }}
            </button>
          </div>
        </div>

      </div>
    </template>

    <!-- ════════════════════════════════════════════════════════ -->
    <!-- TAB 2: COPIA DE TRABAJO — criterios para este campamento -->
    <!-- ════════════════════════════════════════════════════════ -->
    <template v-else>

      <!-- Sin plantilla seleccionada -->
      <div v-if="!plantillaSeleccionada" class="bg-white border-2 border-dashed border-gray-200 rounded-2xl px-6 py-10 text-center">
        <i class="pi pi-clipboard text-4xl text-gray-300 mb-3 block" />
        <p class="text-base font-semibold text-gray-600 m-0">Ninguna plantilla seleccionada</p>
        <p class="text-sm text-gray-400 mt-1 mb-4">Ve a <strong>Criterio General</strong> y pulsa <strong>"Usar"</strong>.</p>
        <button class="flex items-center gap-2 px-5 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] shadow-sm transition mx-auto" @click="tabActivo = 'general'">
          <i class="pi pi-arrow-left text-xs" /> Ir a Criterio General
        </button>
      </div>

      <template v-else>

        <!-- Info plantilla base + nota de copia -->
        <div class="bg-white border border-green-200 rounded-2xl px-4 py-3 flex items-center gap-3 flex-wrap shadow-sm mb-4">
          <div class="flex items-center justify-center w-9 h-9 bg-green-600 rounded-lg shrink-0">
            <i class="pi pi-clipboard text-white text-sm" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-gray-900 m-0">{{ plantillaSeleccionada.nombre }}</p>
            <p class="text-xs text-gray-500 m-0">
              Copia de trabajo · {{ workingIds.length }} criterios ·
              <span class="text-amber-600 font-medium">Los cambios aquí no afectan la plantilla original</span>
            </p>
          </div>
          <button class="text-xs text-gray-500 hover:text-green-700 font-semibold transition px-2 py-1 shrink-0" @click="tabActivo = 'general'">
            Cambiar plantilla
          </button>
        </div>

        <!-- Lista de criterios de la copia de trabajo -->
        <div class="flex flex-col gap-3 mb-4">

          <div v-if="!workingIds.length" class="bg-white border-2 border-dashed border-gray-200 rounded-2xl px-6 py-8 text-center">
            <i class="pi pi-inbox text-3xl text-gray-300 mb-2 block" />
            <p class="text-sm font-semibold text-gray-500 m-0">No hay criterios en la copia de trabajo.</p>
            <p class="text-xs text-gray-400 mt-1">Agrega criterios con el botón de abajo.</p>
          </div>

          <!-- Grupos por categoría -->
          <div v-for="grupo in workingPorCategoria" :key="grupo.categoria" class="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm">
            <div class="flex items-center gap-2 px-4 py-2.5 bg-gray-50 border-b border-gray-100">
              <span class="text-xs font-bold rounded-full px-2.5 py-1" :class="colorCategoria(grupo.categoria)">
                {{ labelCategoria(grupo.categoria) }}
              </span>
              <span class="text-xs text-gray-400">{{ grupo.items.length }} criterio{{ grupo.items.length !== 1 ? 's' : '' }}</span>
            </div>
            <div class="divide-y divide-gray-50">
              <div
                v-for="criterio in grupo.items"
                :key="criterio.id"
                class="px-4 py-3 flex items-center gap-3 hover:bg-gray-50 transition"
                :class="{ 'opacity-50': !criterio.activo }"
              >
                <span class="text-xs font-bold bg-gray-100 text-gray-700 rounded-lg px-2 py-0.5 shrink-0">{{ criterio.codigo }}</span>
                <div class="flex-1 min-w-0">
                  <span class="text-sm font-semibold text-gray-800">{{ criterio.nombre }}</span>
                  <span class="text-xs text-gray-400 ml-2">{{ LABELS_TIPO[criterio.tipo_calculo] ?? criterio.tipo_calculo }}</span>
                </div>
                <div class="flex items-center gap-0.5 shrink-0">
                  <button class="flex items-center justify-center w-8 h-8 rounded-lg text-gray-400 hover:text-green-700 hover:bg-green-50 transition" title="Editar criterio" @click="abrirEditarCriterio(criterio)">
                    <i class="pi pi-pencil text-xs" />
                  </button>
                  <button class="flex items-center justify-center w-8 h-8 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition" title="Quitar de esta selección" @click="abrirConfirmarQuitar(criterio)">
                    <i class="pi pi-times text-xs" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Botón agregar criterio a la copia -->
          <button
            class="flex items-center justify-center gap-2 w-full py-3 bg-white border-2 border-dashed border-gray-200 hover:border-green-400 hover:bg-green-50 text-gray-500 hover:text-green-700 rounded-2xl font-semibold text-sm transition"
            @click="abrirAgregarTab2"
          >
            <i class="pi pi-plus text-sm" />
            Agregar criterio
          </button>
        </div>

        <!-- Sección aplicar -->
        <div class="bg-white border rounded-2xl px-5 py-4 shadow-sm flex flex-col gap-3"
          :class="aplicadoOk && !hayModificaciones ? 'border-emerald-300' : 'border-gray-200'">

          <div v-if="!campStore.selectedId" class="flex items-center gap-2 bg-amber-50 border border-amber-200 text-amber-800 rounded-xl px-4 py-3 text-sm">
            <i class="pi pi-info-circle shrink-0" />
            Selecciona un campamento en el menú lateral para poder aplicar.
          </div>

          <div v-if="errorAplicar" class="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
            <i class="pi pi-exclamation-triangle mt-0.5 shrink-0" />
            {{ errorAplicar }}
          </div>

          <!-- Estado: aplicado sin cambios → "En uso" -->
          <template v-if="aplicadoOk && !hayModificaciones">
            <div class="flex items-center gap-3">
              <div class="flex items-center justify-center w-10 h-10 bg-emerald-100 rounded-xl shrink-0">
                <i class="pi pi-verified text-emerald-600 text-lg" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-emerald-700 m-0">Criterios en uso</p>
                <p class="text-xs text-gray-500 m-0 mt-0.5">
                  Aplicados a <strong>{{ campStore.nombre }}</strong> · {{ workingIds.length }} criterios ·
                  Ve a <strong>Programación</strong> para asignar días y puntajes.
                </p>
              </div>
            </div>
          </template>

          <!-- Estado: hay modificaciones → mostrar botón "Aplicar cambios" -->
          <template v-else-if="aplicadoOk && hayModificaciones">
            <div class="flex items-center gap-2 bg-amber-50 border border-amber-200 text-amber-800 rounded-xl px-4 py-3 text-sm">
              <i class="pi pi-pencil shrink-0" />
              Hay modificaciones sin aplicar en la selección de criterios.
            </div>
            <div class="flex items-center justify-between gap-4 flex-wrap">
              <div>
                <p class="text-sm font-semibold text-gray-800 m-0">
                  Actualizar <span class="text-green-600">{{ campStore.nombre ?? 'este campamento' }}</span>
                </p>
                <p class="text-xs text-gray-500 m-0 mt-0.5">Se actualizarán los {{ workingIds.length }} criterios en Programación.</p>
              </div>
              <button
                class="flex items-center gap-2 px-5 py-3 bg-amber-500 hover:bg-amber-600 text-white rounded-xl font-bold text-sm min-h-[48px] shadow-sm transition disabled:opacity-50 shrink-0"
                :disabled="aplicando || !campStore.selectedId || !workingIds.length"
                @click="aplicarAlCampamento"
              >
                <i v-if="aplicando" class="pi pi-spin pi-spinner text-sm" />
                <i v-else class="pi pi-sync text-sm" />
                {{ aplicando ? 'Aplicando…' : 'Aplicar cambios' }}
              </button>
            </div>
          </template>

          <!-- Estado: nunca aplicado → botón principal -->
          <template v-else>
            <div class="flex items-center justify-between gap-4 flex-wrap">
              <div>
                <p class="text-sm font-semibold text-gray-800 m-0">
                  Aplicar a <span class="text-green-600">{{ campStore.nombre ?? 'este campamento' }}</span>
                </p>
                <p class="text-xs text-gray-500 m-0 mt-0.5">
                  Se crearán {{ workingIds.length }} criterios en Programación para configurar días y puntajes.
                </p>
              </div>
              <button
                class="flex items-center gap-2 px-5 py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-bold text-sm min-h-[48px] shadow-sm transition disabled:opacity-50 shrink-0"
                :disabled="aplicando || !campStore.selectedId || !workingIds.length"
                @click="aplicarAlCampamento"
              >
                <i v-if="aplicando" class="pi pi-spin pi-spinner text-sm" />
                <i v-else class="pi pi-send text-sm" />
                {{ aplicando ? 'Aplicando…' : 'Aplicar a este campamento' }}
              </button>
            </div>
          </template>
        </div>

      </template>
    </template>

  </div>

  <!-- ── Modal agregar criterio a plantilla (Tab 1) ── -->
  <Teleport to="body">
    <div v-if="dialogAgregarTab1" class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40" @click.self="dialogAgregarTab1 = false">
      <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-sm mt-auto sm:mt-0">
        <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>
        <div class="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900 m-0">Nuevo criterio</h2>
          <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition" @click="dialogAgregarTab1 = false"><i class="pi pi-times text-sm" /></button>
        </div>
        <div class="px-5 py-4 flex flex-col gap-4">
          <div v-if="errorAgregarTab1" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm">{{ errorAgregarTab1 }}</div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Categoría <span class="text-red-500">*</span></label>
            <select v-model="nuevaCategoria1" class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition">
              <option v-for="c in categorias" :key="c.clave" :value="c.clave">{{ c.nombre }}</option>
            </select>
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Nombre del criterio <span class="text-red-500">*</span></label>
            <input
              v-model="nuevoNombre1"
              type="text"
              placeholder="Ej: Orden y limpieza interior"
              class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition"
              @keydown.enter="confirmarAgregarTab1"
            />
          </div>
        </div>
        <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="agregandoTab1" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="dialogAgregarTab1 = false">Cancelar</button>
          <button
            :disabled="agregandoTab1 || !nuevoNombre1.trim() || !nuevaCategoria1"
            class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60"
            @click="confirmarAgregarTab1"
          >
            <i v-if="agregandoTab1" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-plus text-xs" />
            Crear y agregar
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal agregar criterio a la copia de trabajo (Tab 2) ── -->
  <Teleport to="body">
    <div v-if="dialogAgregarTab2" class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40" @click.self="dialogAgregarTab2 = false">
      <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[90vh] overflow-y-auto">
        <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>
        <div class="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100">
          <div class="flex items-center gap-2">
            <button
              v-if="pasoAgregarTab2 !== 'inicio'"
              class="flex items-center justify-center w-7 h-7 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition"
              @click="pasoAgregarTab2 = 'inicio'"
            ><i class="pi pi-arrow-left text-xs" /></button>
            <h2 class="text-base font-bold text-gray-900 m-0">
              {{ pasoAgregarTab2 === 'inicio' ? '¿Qué deseas hacer?' : pasoAgregarTab2 === 'categoria' ? 'Nueva categoría' : 'Nuevo criterio' }}
            </h2>
          </div>
          <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition" @click="dialogAgregarTab2 = false"><i class="pi pi-times text-sm" /></button>
        </div>

        <div class="px-5 py-4 flex flex-col gap-4">
          <div v-if="errorAgregarTab2" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm">{{ errorAgregarTab2 }}</div>

          <!-- Paso: inicio — elegir acción -->
          <template v-if="pasoAgregarTab2 === 'inicio'">
            <button
              class="flex items-center gap-4 px-4 py-4 rounded-2xl border-2 border-gray-200 hover:border-green-400 hover:bg-green-50 text-left transition group"
              @click="pasoAgregarTab2 = 'criterio'; errorAgregarTab2 = ''"
            >
              <div class="w-10 h-10 rounded-xl bg-green-100 text-green-700 flex items-center justify-center shrink-0 group-hover:bg-green-200 transition">
                <i class="pi pi-plus-circle" />
              </div>
              <div>
                <p class="text-sm font-bold text-gray-800 m-0">Nuevo criterio</p>
                <p class="text-xs text-gray-500 m-0">Crear un criterio de evaluación</p>
              </div>
            </button>
            <button
              class="flex items-center gap-4 px-4 py-4 rounded-2xl border-2 border-gray-200 hover:border-violet-400 hover:bg-violet-50 text-left transition group"
              @click="pasoAgregarTab2 = 'categoria'; errorAgregarTab2 = ''"
            >
              <div class="w-10 h-10 rounded-xl bg-violet-100 text-violet-700 flex items-center justify-center shrink-0 group-hover:bg-violet-200 transition">
                <i class="pi pi-tag" />
              </div>
              <div>
                <p class="text-sm font-bold text-gray-800 m-0">Nueva categoría</p>
                <p class="text-xs text-gray-500 m-0">Crear primero una categoría si no existe</p>
              </div>
            </button>
          </template>

          <!-- Paso: nueva categoría (igual al modal de Tab 1) -->
          <template v-else-if="pasoAgregarTab2 === 'categoria'">
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Nombre <span class="text-red-500">*</span></label>
              <input v-model="catNombreInline" type="text" placeholder="Ej: Armado de campamento"
                class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-violet-500 bg-gray-50 focus:bg-white transition" />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Color</label>
              <div class="flex flex-wrap gap-2">
                <button
                  v-for="op in PALETA_OPTIONS"
                  :key="op.value"
                  class="w-8 h-8 rounded-full border-2 transition"
                  :style="{ backgroundColor: op.hex }"
                  :class="catColorInline === op.value ? 'border-gray-800 scale-110' : 'border-transparent hover:border-gray-400'"
                  :title="op.label"
                  @click="catColorInline = op.value"
                />
              </div>
              <div v-if="catNombreInline" class="mt-1">
                <span class="text-xs font-bold rounded-full px-2.5 py-1" :class="PALETA_COLORES[catColorInline] ?? 'bg-gray-100 text-gray-600'">
                  {{ catNombreInline }}
                </span>
              </div>
            </div>
          </template>

          <!-- Paso: nuevo criterio (igual al modal de Tab 1) -->
          <template v-else>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Categoría <span class="text-red-500">*</span></label>
              <select v-model="nuevaCategoria2" class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition">
                <option value="">Seleccionar...</option>
                <option v-for="o in OPCIONES_CATEGORIA" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Nombre <span class="text-red-500">*</span></label>
              <input v-model="nuevoNombre2" type="text" placeholder="Nombre del criterio"
                class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition" />
            </div>
          </template>
        </div>

        <div v-if="pasoAgregarTab2 !== 'inicio'" class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="agregandoTab2" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="dialogAgregarTab2 = false">Cancelar</button>
          <button
            :disabled="agregandoTab2"
            class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60"
            @click="confirmarAgregarTab2"
          >
            <i v-if="agregandoTab2" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-check text-xs" />
            {{ pasoAgregarTab2 === 'categoria' ? 'Crear categoría' : 'Crear y agregar' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal confirmar quitar de la copia de trabajo (Tab 2) ── -->
  <Teleport to="body">
    <div v-if="confirmarQuitarVisible" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4" @click.self="confirmarQuitarVisible = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div class="flex flex-col items-center pt-8 pb-4 px-6 text-center">
          <div class="flex items-center justify-center w-14 h-14 rounded-full bg-amber-100 mb-4"><i class="pi pi-minus-circle text-2xl text-amber-600" /></div>
          <h2 class="text-base font-bold text-gray-900 mb-2 m-0">Quitar criterio</h2>
          <p class="text-sm text-gray-700 m-0 mb-1">¿Quitar <strong>{{ criterioAQuitar?.codigo }} — {{ criterioAQuitar?.nombre }}</strong> de esta selección?</p>
          <p class="text-xs text-gray-500 m-0">Solo se quita de esta copia de trabajo. La plantilla original no cambia.</p>
        </div>
        <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition" @click="confirmarQuitarVisible = false">Cancelar</button>
          <button class="flex items-center gap-1.5 px-4 py-2.5 bg-amber-500 hover:bg-amber-600 text-white rounded-xl font-semibold text-sm min-h-[44px] transition" @click="confirmarQuitar">
            <i class="pi pi-minus-circle text-xs" /> Quitar
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal editar criterio ── -->
  <Teleport to="body">
    <div v-if="dialogCriterio" class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40" @click.self="dialogCriterio = false">
      <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-lg mt-auto sm:mt-0 max-h-[90vh] overflow-y-auto">
        <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>
        <div class="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900 m-0">Editar: {{ criterioEditando?.nombre }}</h2>
          <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition" @click="dialogCriterio = false"><i class="pi pi-times text-sm" /></button>
        </div>
        <div class="px-5 py-4 flex flex-col gap-3.5">
          <div v-if="errorDialog" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2.5 text-sm">{{ errorDialog }}</div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Nombre <span class="text-red-500">*</span></label>
            <input v-model="formNombre" type="text" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition" />
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Categoría <span class="text-red-500">*</span></label>
              <select v-model="formCategoria" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition">
                <option value="">Seleccionar...</option>
                <option v-for="o in OPCIONES_CATEGORIA" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-semibold text-gray-700">Tipo de cálculo <span class="text-red-500">*</span></label>
              <select v-model="formTipo" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition">
                <option value="">Seleccionar...</option>
                <option v-for="o in OPCIONES_TIPO" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>
          </div>
          <label class="flex items-center gap-3 cursor-pointer">
            <input type="checkbox" v-model="formActivo" class="sr-only" />
            <div class="w-10 h-6 rounded-full transition" :class="formActivo ? 'bg-green-500' : 'bg-gray-300'">
              <div class="w-4 h-4 bg-white rounded-full shadow transition-transform mt-1 ml-1" :class="formActivo ? 'translate-x-4' : ''" />
            </div>
            <span class="text-sm font-semibold text-gray-700">{{ formActivo ? 'Activo' : 'Inactivo' }}</span>
          </label>
          <hr class="border-gray-200" />
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Abarca</label>
            <textarea v-model="formAbarca" rows="2" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">No abarca</label>
            <textarea v-model="formNoAbarca" rows="2" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Evidencia requerida</label>
            <textarea v-model="formEvidencia" rows="2" class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none" />
          </div>
        </div>
        <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="guardando" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="dialogCriterio = false">Cancelar</button>
          <button :disabled="guardando" class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60" @click="guardarCriterio">
            <i v-if="guardando" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-check text-xs" />
            Guardar
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal crear/editar plantilla ── -->
  <Teleport to="body">
    <div v-if="dialogPlantilla" class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40" @click.self="dialogPlantilla = false">
      <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0">
        <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>
        <div class="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900 m-0">{{ esNuevaPlantilla ? 'Nueva plantilla' : 'Editar plantilla' }}</h2>
          <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition" @click="dialogPlantilla = false"><i class="pi pi-times text-sm" /></button>
        </div>
        <div class="px-5 py-4 flex flex-col gap-4">
          <div v-if="errorP" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2.5 text-sm">{{ errorP }}</div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Nombre <span class="text-red-500">*</span></label>
            <input v-model="formPNombre" type="text" placeholder="Ej: LiderCamp 2026-II" class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Descripción <span class="font-normal text-gray-400">(opcional)</span></label>
            <textarea v-model="formPDesc" rows="2" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none" />
          </div>
          <label class="flex items-center gap-3 cursor-pointer">
            <input type="checkbox" v-model="formPActivo" class="sr-only" />
            <div class="w-10 h-6 rounded-full transition" :class="formPActivo ? 'bg-green-500' : 'bg-gray-300'">
              <div class="w-4 h-4 bg-white rounded-full shadow transition-transform mt-1 ml-1" :class="formPActivo ? 'translate-x-4' : ''" />
            </div>
            <span class="text-sm font-semibold text-gray-700">{{ formPActivo ? 'Activa' : 'Inactiva' }}</span>
          </label>
        </div>
        <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="guardandoP" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="dialogPlantilla = false">Cancelar</button>
          <button :disabled="guardandoP" class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60" @click="guardarPlantilla">
            <i v-if="guardandoP" class="pi pi-spin pi-spinner text-xs" /><i v-else-if="esNuevaPlantilla" class="pi pi-plus text-xs" /><i v-else class="pi pi-check text-xs" />
            {{ esNuevaPlantilla ? 'Crear' : 'Guardar' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal confirmar eliminar plantilla ── -->
  <Teleport to="body">
    <div v-if="confirmarElimPlantillaVisible" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4" @click.self="confirmarElimPlantillaVisible = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div class="flex flex-col items-center pt-8 pb-4 px-6 text-center">
          <div class="flex items-center justify-center w-14 h-14 rounded-full bg-red-100 mb-4"><i class="pi pi-trash text-2xl text-red-600" /></div>
          <h2 class="text-base font-bold text-gray-900 mb-2 m-0">Eliminar plantilla</h2>
          <div v-if="errorEliminP" class="w-full bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm mb-3">{{ errorEliminP }}</div>
          <p class="text-sm text-gray-700 m-0 mb-1">¿Eliminar <strong>{{ plantillaAEliminar?.nombre }}</strong>?</p>
          <p class="text-xs text-gray-500 m-0">Se eliminarán todos sus criterios asociados. Esta acción no se puede deshacer.</p>
        </div>
        <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="eliminandoP" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="confirmarElimPlantillaVisible = false">Cancelar</button>
          <button :disabled="eliminandoP" class="flex items-center gap-1.5 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60" @click="confirmarEliminarPlantilla">
            <i v-if="eliminandoP" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-trash text-xs" />
            Eliminar
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal crear/editar categoría ── -->
  <Teleport to="body">
    <div v-if="dialogCategoria" class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40" @click.self="dialogCategoria = false">
      <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0">
        <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>
        <div class="flex items-center justify-between px-5 pt-4 pb-3 border-b border-gray-100">
          <h2 class="text-base font-bold text-gray-900 m-0">{{ categoriaEditando ? 'Editar categoría' : 'Nueva categoría' }}</h2>
          <button class="flex items-center justify-center w-9 h-9 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition" @click="dialogCategoria = false"><i class="pi pi-times text-sm" /></button>
        </div>
        <div class="px-5 py-4 flex flex-col gap-4">
          <div v-if="errorCat" class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm">{{ errorCat }}</div>
          <!-- Nombre -->
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-gray-700">Nombre <span class="text-red-500">*</span></label>
            <input v-model="formCatNombre" type="text" placeholder="Ej: Armado de campamento"
              class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition" />
          </div>
          <!-- Paleta visual de colores -->
          <div class="flex flex-col gap-2">
            <label class="text-sm font-semibold text-gray-700">Color</label>
            <div class="flex flex-wrap gap-2.5">
              <button
                v-for="p in PALETA_OPTIONS"
                :key="p.value"
                type="button"
                :title="p.label"
                class="w-9 h-9 rounded-full transition-transform focus:outline-none flex items-center justify-center"
                :class="formCatColor === p.value ? 'ring-2 ring-offset-2 ring-gray-600 scale-110' : 'hover:scale-110'"
                :style="{ backgroundColor: p.hex }"
                @click="formCatColor = p.value"
              >
                <i v-if="formCatColor === p.value" class="pi pi-check text-white text-xs" style="filter:drop-shadow(0 1px 1px rgba(0,0,0,.4))" />
              </button>
            </div>
          </div>
          <!-- Orden + preview en la misma fila -->
          <div class="flex items-center gap-4">
            <div class="flex flex-col gap-1.5 w-24 shrink-0">
              <label class="text-sm font-semibold text-gray-700">Orden</label>
              <input v-model.number="formCatOrden" type="number" min="0"
                class="w-full min-h-[44px] border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-green-500 bg-gray-50 focus:bg-white transition" />
            </div>
            <div class="flex flex-col gap-1.5 flex-1">
              <label class="text-sm font-semibold text-gray-700">Vista previa</label>
              <div class="flex items-center h-[44px]">
                <span class="text-xs font-bold rounded-full px-2.5 py-1" :class="PALETA_COLORES[formCatColor] ?? 'bg-gray-100 text-gray-600'">
                  {{ formCatNombre || 'Nombre categoría' }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="flex justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="guardandoCat" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="dialogCategoria = false">Cancelar</button>
          <button :disabled="guardandoCat" class="flex items-center gap-1.5 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60" @click="guardarCategoria">
            <i v-if="guardandoCat" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-check text-xs" />
            {{ categoriaEditando ? 'Guardar' : 'Crear' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal confirmar eliminar categoría ── -->
  <Teleport to="body">
    <div v-if="confirmarElimCatVisible" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4" @click.self="confirmarElimCatVisible = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div class="flex flex-col items-center pt-8 pb-4 px-6 text-center">
          <div class="flex items-center justify-center w-14 h-14 rounded-full bg-red-100 mb-4"><i class="pi pi-trash text-2xl text-red-600" /></div>
          <h2 class="text-base font-bold text-gray-900 mb-2 m-0">Eliminar categoría</h2>
          <div v-if="errorElimCat" class="w-full bg-red-50 border border-red-200 text-red-700 rounded-lg px-3 py-2 text-sm mb-3">{{ errorElimCat }}</div>
          <p class="text-sm text-gray-700 m-0 mb-1">¿Eliminar la categoría <strong>{{ categoriaAEliminar?.nombre }}</strong>?</p>
          <p class="text-xs text-gray-500 m-0">Solo se puede eliminar si no tiene criterios asociados.</p>
        </div>
        <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button :disabled="eliminandoCat" class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition disabled:opacity-50" @click="confirmarElimCatVisible = false">Cancelar</button>
          <button :disabled="eliminandoCat" class="flex items-center gap-1.5 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl font-semibold text-sm min-h-[44px] transition disabled:opacity-60" @click="confirmarEliminarCategoria">
            <i v-if="eliminandoCat" class="pi pi-spin pi-spinner text-xs" /><i v-else class="pi pi-trash text-xs" />
            Eliminar
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- ── Modal confirmar cambiar plantilla base (Tab 1 "Usar") ── -->
  <Teleport to="body">
    <div v-if="confirmarUsarVisible" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4" @click.self="confirmarUsarVisible = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div class="flex flex-col items-center pt-8 pb-4 px-6 text-center">
          <div class="flex items-center justify-center w-14 h-14 rounded-full bg-amber-100 mb-4">
            <i class="pi pi-exclamation-triangle text-2xl text-amber-600" />
          </div>
          <h2 class="text-base font-bold text-gray-900 mb-2 m-0">Cambiar plantilla base</h2>
          <p class="text-sm text-gray-700 m-0 mb-1">
            Ya tienes una selección personalizada de criterios para <strong>{{ campStore.nombre ?? 'este campamento' }}</strong>.
          </p>
          <p class="text-xs text-gray-500 m-0">
            Si continúas, se reemplazará con los criterios de <strong>{{ plantillaPendiente?.nombre }}</strong>.
            Los criterios aplicados en Programación no se eliminarán.
          </p>
        </div>
        <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
          <button class="px-4 py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm min-h-[44px] hover:bg-gray-50 transition" @click="confirmarUsarVisible = false">
            Cancelar
          </button>
          <button class="flex items-center gap-1.5 px-4 py-2.5 bg-amber-500 hover:bg-amber-600 text-white rounded-xl font-semibold text-sm min-h-[44px] transition" @click="plantillaPendiente && _aplicarUsoPlantilla(plantillaPendiente)">
            <i class="pi pi-refresh text-xs" /> Usar esta plantilla
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
