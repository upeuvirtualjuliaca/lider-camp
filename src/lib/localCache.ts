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

/**
 * Envuelve cualquier llamada a Supabase con caché offline.
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
  if (!navigator.onLine) {
    const cached = cacheGet<T>(key)
    if (cached !== null) return cached
    throw new Error(`Sin conexión y sin datos guardados para "${key}". Conéctate al menos una vez para usar este módulo offline.`)
  }
  const result = await fn()
  cacheSet(key, result, ttl)
  return result
}

export { TTL_7D, TTL_1H }
