import { ref, computed } from 'vue'
import { useCampamentoStore } from '@/stores/campamento'
import {
  diasCampamentoService,
  type DiaCampamento,
} from '@/modules/equipos/services/campamento.service'

/**
 * Composable compartido para los días del campamento.
 *
 * Los días son completamente configurables por el admin (tabla dias_campamento).
 * Ya no están fijos a Jue/Vie/Sáb/Dom.
 *
 * - `momentos`       → lista ordenada de códigos, e.g. ['X','J','V']
 * - `labelDia('J')`  → "Jue 23 oct"  (o el código si no hay datos)
 * - `labelDia('UNICO')` → "Único"
 * - `detectarMomentoActual()` → código del día que coincide con hoy
 * - `fechas`         → Record<codigo, fecha> para compatibilidad con vistas existentes
 */
export function useDiasCampamento() {
  const dias = ref<DiaCampamento[]>([])

  // Lista ordenada de códigos de días
  const momentos = computed<string[]>(() => dias.value.map((d) => d.codigo))

  // Record codigo → fecha (compatibilidad con ActividadesView)
  const fechas = computed<Record<string, string>>(() =>
    Object.fromEntries(dias.value.map((d) => [d.codigo, d.fecha])),
  )

  async function cargar(): Promise<void> {
    const store = useCampamentoStore()
    if (store.selectedId) {
      dias.value = await diasCampamentoService.getPorCampamento(store.selectedId)
    }
  }

  function labelDia(codigo: string): string {
    if (codigo === 'UNICO') return 'Único'
    const dia = dias.value.find((d) => d.codigo === codigo)
    if (!dia) return codigo
    const d = new Date(dia.fecha + 'T12:00:00')
    const abrev = dia.nombre.length > 3 ? dia.nombre.slice(0, 3) : dia.nombre
    return `${abrev} ${d.getDate()} ${d.toLocaleString('es', { month: 'short' })}`
  }

  function detectarMomentoActual(): string {
    const d = new Date()
    const hoy = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
    return dias.value.find((d) => d.fecha === hoy)?.codigo ?? (momentos.value[0] ?? '')
  }

  return { dias, momentos, fechas, cargar, labelDia, detectarMomentoActual }
}
