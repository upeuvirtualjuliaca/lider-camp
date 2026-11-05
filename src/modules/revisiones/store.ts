import { defineStore } from 'pinia'
import { ref } from 'vue'
import { incidenciasService } from '@/modules/incidencias/services/incidencias.service'

export const useRevisionesStore = defineStore('revisiones', () => {
  const cntPendiente = ref(0)

  async function cargarConteo(campamentoId?: string | null) {
    try {
      const inc = await incidenciasService.getAll({ campamento_id: campamentoId ?? undefined })
      cntPendiente.value = inc.filter(
        (i) => i.estado === 'registrado' || i.estado === 'descargo',
      ).length
    } catch {
      // silencioso – no bloquear la UI
    }
  }

  return { cntPendiente, cargarConteo }
})
