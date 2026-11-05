/**
 * localCache — caché de lectura en localStorage.
 *
 * Patrón:
 *   - Online  → llama a Supabase, guarda resultado en localStorage, retorna resultado
 *   - Offline → lee localStorage; si hay datos los retorna; si no, lanza error descriptivo
 */

const PREFIX  = 'lc_'
const TTL_7D  = 60 * 60 * 24 * 7   // 7 días en segundos
const TTL_1H  = 60 * 60             // 1 hora (para datos más dinámicos)

interface Entry<T> { d: T; ts: number; ttl: number }

export function cacheSet<T>(key: string, data: T, ttl = TTL_7D): void {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify({ d: data, ts: Date.now(), ttl }))
  } catch { /* storage lleno, ignorar */ }
}

export function cacheGet<T>(key: string): T | null {
  try {
    const raw = localStorage.getItem(PREFIX + key)
    if (!raw) return null
    const e = JSON.parse(raw) as Entry<T>
    if (Date.now() - e.ts > e.ttl * 1000) { localStorage.removeItem(PREFIX + key); return null }
    return e.d
  } catch { return null }
}

const NETWORK_TIMEOUT_MS = 7000  // 7 s — máximo espera antes de usar caché

/**
 * Envuelve cualquier llamada a Supabase con caché offline.
 *
 * Comportamiento:
 *  - Offline real (navigator.onLine=false)  → lee caché al instante
 *  - Online pero lento / sin internet real  → intenta red 7 s; si falla, usa caché
 *  - Online y rápido                        → va a red, actualiza caché, retorna
 *
 * @param key   Clave única de caché (ej. `equipos_<campId>`)
 * @param fn    Función async que va a Supabase
 * @param ttl   Tiempo de vida en segundos (defecto: 7 días)
 */
export async function cachedFetch<T>(
  key: string,
  fn: () => Promise<T>,
  ttl = TTL_7D,
): Promise<T> {
  // 1. Sin red local → caché inmediata
  if (!navigator.onLine) {
    const cached = cacheGet<T>(key)
    if (cached !== null) return cached
    throw new Error(`Sin conexión y sin datos guardados para "${key}". Conéctate al menos una vez para usar este módulo offline.`)
  }

  // 2. Aparentemente online → intentar red con timeout; caché como fallback
  try {
    let timeoutId: ReturnType<typeof setTimeout>
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutId = setTimeout(() => reject(new Error('timeout')), NETWORK_TIMEOUT_MS)
    })
    const result = await Promise.race([fn(), timeoutPromise])
    clearTimeout(timeoutId!)
    cacheSet(key, result, ttl)
    return result
  } catch {
    const cached = cacheGet<T>(key)
    if (cached !== null) return cached
    throw new Error(`Sin conexión estable y sin datos previos para "${key}". Conéctate para continuar.`)
  }
}

export { TTL_7D, TTL_1H }
