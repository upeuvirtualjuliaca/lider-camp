import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  campamentoService,
  type Campamento,
} from '@/modules/equipos/services/campamento.service'

const LS_KEY = 'lidercamp_campamento_id'

/**
 * Store global del campamento seleccionado por el usuario.
 *
 * Con multi-campamento pueden coexistir varios activos; el usuario elige
 * cuál administrar. La selección persiste en localStorage entre sesiones.
 *
 * Todos los servicios que necesiten filtrar por campamento deben leer
 * `useCampamentoStore().selectedId` en lugar de asumir un único activo.
 */
export const useCampamentoStore = defineStore('campamento', () => {
  const campamentos = ref<Campamento[]>([])
  const selectedId  = ref<string | null>(localStorage.getItem(LS_KEY))
  const cargando    = ref(false)

  /** Campamento seleccionado actualmente. */
  const campamento = computed<Campamento | null>(() =>
    campamentos.value.find((c) => c.id === selectedId.value) ?? null,
  )

  /** true si el campamento seleccionado está cerrado. */
  const cerrado = computed(() => campamento.value?.cerrado ?? false)

  /** true si el campamento seleccionado está activo. */
  const activo = computed(() => campamento.value?.activo ?? false)

  /** Nombre del campamento seleccionado, o cadena vacía. */
  const nombre = computed(() => campamento.value?.nombre ?? '')

  /**
   * Carga todos los campamentos desde la BD y garantiza que haya
   * una selección válida.
   * – Si la selección guardada en localStorage todavía existe → se mantiene.
   * – Si no hay selección o el campamento ya no existe → auto-selecciona
   *   el primer campamento activo (o el más reciente si ninguno está activo).
   */
  async function cargar(): Promise<void> {
    cargando.value = true
    try {
      campamentos.value = await campamentoService.getAll()

      const existe = campamentos.value.find((c) => c.id === selectedId.value)
      if (!existe) {
        const primero = campamentos.value[0]
        selectedId.value = primero?.id ?? null
        if (selectedId.value) {
          localStorage.setItem(LS_KEY, selectedId.value)
        } else {
          localStorage.removeItem(LS_KEY)
        }
      }
    } finally {
      cargando.value = false
    }
  }

  /** Cambia el campamento seleccionado y persiste la elección. */
  function seleccionar(id: string): void {
    selectedId.value = id
    localStorage.setItem(LS_KEY, id)
  }

  return {
    campamentos,
    selectedId,
    campamento,
    cerrado,
    activo,
    nombre,
    cargando,
    cargar,
    seleccionar,
  }
})
