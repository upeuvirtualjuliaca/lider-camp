/**
 * precalentarCache — carga todos los datos críticos para uso offline
 * en segundo plano cuando hay conexión a internet.
 *
 * Se llama desde PanelLayout al montar. Si no hay internet, no hace nada
 * (el caché ya debería estar listo de una sesión anterior).
 */
import { equiposService }         from '@/modules/equipos/services/equipos.service'
import { campamentoService, diasCampamentoService } from '@/modules/equipos/services/campamento.service'
import {
  diasService,
  programacionRubricaService,
} from '@/modules/observaciones/services/observaciones.service'
import { actividadesService, integrantesAsistenciaService } from '@/modules/asistencia/services/asistencia.service'

export async function precalentarCache(campamentoId: string): Promise<void> {
  if (!navigator.onLine) return

  try {
    // 1. Campamentos y días del campamento
    await Promise.allSettled([
      campamentoService.getAll(),
      diasCampamentoService.getPorCampamento(campamentoId),
    ])

    // 2. Equipos del campamento
    const equipos = await equiposService.getTodos(campamentoId).catch(() => [])

    // 3. Días de evaluación y momentos con programación rúbrica (en paralelo)
    const [diasEval, momentos] = await Promise.all([
      diasService.getTodos(campamentoId).catch(() => []),
      programacionRubricaService.getMomentosConProgramacion(campamentoId).catch(() => []),
    ])

    // 4. Programación rúbrica por cada momento disponible
    await Promise.allSettled(
      momentos.map((m) => programacionRubricaService.getPorDia(m, campamentoId)),
    )

    // 5. Actividades por cada momento
    await Promise.allSettled(
      (diasEval.map((d: any) => d.momento) as string[]).map((m) =>
        actividadesService.getPorDia(m).catch(() => []),
      ),
    )

    // 6. Integrantes de cada equipo (necesario para marcar asistencia offline)
    await Promise.allSettled(
      equipos.map((e) => integrantesAsistenciaService.getPorEquipo(e.id)),
    )
  } catch {
    // Error silencioso — no bloquea el arranque
  }
}
