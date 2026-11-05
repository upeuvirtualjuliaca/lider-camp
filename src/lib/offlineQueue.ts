/**
 * offlineQueue — cola IndexedDB para operaciones de escritura offline.
 * Se sincroniza automáticamente al recuperar conexión.
 */
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'

// ── Tipos ──────────────────────────────────────────────────────────────────
export interface QueueItem {
  id: string
  table: string
  operation: 'upsert' | 'insert'
  payload: Record<string, unknown>
  conflictFields?: string
  /** IDs de integrantes para incidencias creadas offline */
  integrante_ids?: string[]
  createdAt: number
}

// ── IndexedDB helpers ──────────────────────────────────────────────────────
const DB_NAME  = 'lider-camp-offline'
const STORE    = 'queue'
const DB_VER   = 1

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VER)
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: 'id' })
    req.onsuccess = () => resolve(req.result)
    req.onerror   = () => reject(req.error)
  })
}

async function dbGetAll(): Promise<QueueItem[]> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const req = db.transaction(STORE, 'readonly').objectStore(STORE).getAll()
    req.onsuccess = () => resolve((req.result as QueueItem[]).sort((a, b) => a.createdAt - b.createdAt))
    req.onerror   = () => reject(req.error)
  })
}

async function dbPut(item: QueueItem): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite')
    tx.objectStore(STORE).put(item)
    tx.oncomplete = () => resolve()
    tx.onerror    = () => reject(tx.error)
  })
}

async function dbDelete(id: string): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite')
    tx.objectStore(STORE).delete(id)
    tx.oncomplete = () => resolve()
    tx.onerror    = () => reject(tx.error)
  })
}

// ── Estado reactivo global (singleton) ────────────────────────────────────
export const pendingCount = ref(0)
let _initialized = false
let _syncing = false

export async function refreshCount(): Promise<void> {
  const items = await dbGetAll()
  pendingCount.value = items.length
}

export async function sync(): Promise<void> {
  if (_syncing || !navigator.onLine) return
  _syncing = true
  try {
    const items = await dbGetAll()
    for (const item of items) {
      try {
        let syncError: unknown = null

        if (item.operation === 'upsert') {
          const { error } = await (supabase as any)
            .from(item.table)
            .upsert(item.payload, item.conflictFields ? { onConflict: item.conflictFields } : undefined)
          syncError = error
        } else {
          const { data, error } = await (supabase as any)
            .from(item.table)
            .insert(item.payload)
            .select()
            .single()
          syncError = error
          // Sincronizar integrantes de incidencia creada offline
          if (!syncError && item.table === 'incidencias' && item.integrante_ids?.length) {
            const incidencia_id = (data?.id ?? item.payload.id) as string
            if (incidencia_id) {
              const rows = item.integrante_ids.map((iid) => ({
                incidencia_id,
                integrante_id: iid,
              }))
              await (supabase as any).from('incidencia_integrantes').insert(rows)
            }
          }
        }

        if (!syncError) {
          await dbDelete(item.id)
          pendingCount.value = Math.max(0, pendingCount.value - 1)
        }
      } catch {
        // Intentar el siguiente elemento
      }
    }
  } finally {
    _syncing = false
    await refreshCount()
  }
}

export async function enqueue(item: Omit<QueueItem, 'id' | 'createdAt'>): Promise<void> {
  const qItem: QueueItem = {
    ...item,
    id: crypto.randomUUID(),
    createdAt: Date.now(),
  }
  await dbPut(qItem)
  pendingCount.value++
}

export function initOfflineQueue(): void {
  if (_initialized) return
  _initialized = true
  refreshCount()
  window.addEventListener('online', sync)
}
