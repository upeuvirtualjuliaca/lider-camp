import { supabase } from '@/lib/supabase'
import type { Tables, TablesInsert, TablesUpdate } from '@/types/database'

export type Criterio = Tables<'criterios'>
export type Programacion = Tables<'programacion'>
export type ResumenProgramacion = Tables<'v_resumen_programacion'>
export type PublicoCalendario  = Tables<'publico_calendario'>
export type PublicoCampamento  = Tables<'publico_campamento'>
export type PublicoCriterio = Tables<'publico_criterios'>
export type Plantilla = Tables<'plantillas_criterios'>
export type PlantillaItem = Tables<'plantilla_items'>
export type CategoriaCriterio = Tables<'categorias_criterios'>
export type TipoCalculo = Tables<'tipos_calculo'>

export const criteriosService = {
  async getTodos(): Promise<Criterio[]> {
    const { data, error } = await supabase
      .from('criterios')
      .select('*')
      .order('orden')
    if (error) throw error
    return data
  },

  async crear(datos: TablesInsert<'criterios'>): Promise<Criterio> {
    const { data, error } = await supabase
      .from('criterios')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'criterios'>): Promise<Criterio> {
    const { data, error } = await supabase
      .from('criterios')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(id: string): Promise<void> {
    // Eliminar programación asociada primero (FK constraint)
    const { error: errProg } = await supabase
      .from('programacion')
      .delete()
      .eq('criterio_id', id)
    if (errProg) throw errProg
    const { error } = await supabase
      .from('criterios')
      .delete()
      .eq('id', id)
    if (error) throw error
  },
}

export const programacionService = {
  async getTodos(campamentoId?: string | null): Promise<Programacion[]> {
    let query = supabase.from('programacion').select('*')
    if (campamentoId) query = query.eq('campamento_id', campamentoId)
    const { data, error } = await query
    if (error) throw error
    return data
  },

  async getResumen(campamentoId?: string | null): Promise<ResumenProgramacion[]> {
    let query = supabase.from('v_resumen_programacion').select('*')
    if (campamentoId) query = query.eq('campamento_id', campamentoId)
    const { data, error } = await query
    if (error) throw error
    return data
  },

  async inicializar(campamentoId: string, sourceCampamentoId?: string): Promise<number> {
    const { data, error } = await supabase.rpc('inicializar_programacion_campamento', {
      p_campamento_id: campamentoId,
      p_source_campamento_id: sourceCampamentoId ?? undefined,
    })
    if (error) throw error
    return data as number
  },

  async crear(datos: TablesInsert<'programacion'>): Promise<Programacion> {
    const { data, error } = await supabase
      .from('programacion')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'programacion'>): Promise<Programacion> {
    const { data, error } = await supabase
      .from('programacion')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(id: string): Promise<void> {
    const { error } = await supabase
      .from('programacion')
      .delete()
      .eq('id', id)
    if (error) throw error
  },
}

export type PlantillaItemInput = {
  criterio_id: string
  momento: string
  puntaje_max: number
  estado: string
}

export const plantillasService = {
  async getTodas(): Promise<Plantilla[]> {
    const { data, error } = await supabase
      .from('plantillas_criterios')
      .select('*')
      .order('created_at')
    if (error) throw error
    return data
  },

  async crear(datos: TablesInsert<'plantillas_criterios'>): Promise<Plantilla> {
    const { data, error } = await supabase
      .from('plantillas_criterios')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(id: string, datos: TablesUpdate<'plantillas_criterios'>): Promise<Plantilla> {
    const { data, error } = await supabase
      .from('plantillas_criterios')
      .update(datos)
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(id: string): Promise<void> {
    const { error } = await supabase
      .from('plantillas_criterios')
      .delete()
      .eq('id', id)
    if (error) throw error
  },

  async getItems(plantillaId: string): Promise<PlantillaItem[]> {
    const { data, error } = await supabase
      .from('plantilla_items')
      .select('*')
      .eq('plantilla_id', plantillaId)
    if (error) throw error
    return data
  },

  async upsertItems(plantillaId: string, items: PlantillaItemInput[]): Promise<void> {
    // Eliminar todos los items existentes y reemplazar
    const { error: del } = await supabase
      .from('plantilla_items')
      .delete()
      .eq('plantilla_id', plantillaId)
    if (del) throw del
    if (items.length === 0) return
    const { error: ins } = await supabase
      .from('plantilla_items')
      .insert(items.map((i) => ({ ...i, plantilla_id: plantillaId })))
    if (ins) throw ins
  },

  async aplicarACampamento(campamentoId: string, items: PlantillaItemInput[]): Promise<number> {
    const { data, error } = await supabase.rpc('aplicar_plantilla_a_campamento', {
      p_campamento_id: campamentoId,
      p_items: items,
    })
    if (error) throw error
    return data as number
  },

  async agregarCriterio(plantillaId: string, criterioId: string): Promise<void> {
    // Inserta un item UNICO como placeholder; los días se configuran en Programación
    const { error } = await supabase
      .from('plantilla_items')
      .upsert(
        { plantilla_id: plantillaId, criterio_id: criterioId, momento: 'UNICO', puntaje_max: 100, estado: 'programado' },
        { onConflict: 'plantilla_id,criterio_id,momento' },
      )
    if (error) throw error
  },

  async quitarCriterio(plantillaId: string, criterioId: string): Promise<void> {
    const { error } = await supabase
      .from('plantilla_items')
      .delete()
      .eq('plantilla_id', plantillaId)
      .eq('criterio_id', criterioId)
    if (error) throw error
  },
}

export const categoriasService = {
  async getTodas(): Promise<CategoriaCriterio[]> {
    const { data, error } = await supabase
      .from('categorias_criterios')
      .select('*')
      .order('orden')
    if (error) throw error
    return data
  },

  async crear(datos: { clave: string; nombre: string; color: string; orden: number }): Promise<CategoriaCriterio> {
    const { data, error } = await supabase
      .from('categorias_criterios')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async actualizar(clave: string, datos: { nombre?: string; color?: string; orden?: number }): Promise<CategoriaCriterio> {
    const { data, error } = await supabase
      .from('categorias_criterios')
      .update(datos)
      .eq('clave', clave)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async eliminar(clave: string): Promise<void> {
    const { error } = await supabase
      .from('categorias_criterios')
      .delete()
      .eq('clave', clave)
    if (error) throw error
  },
}

export const campamentoCriteriosService = {
  async getCriterioIds(campamentoId: string): Promise<string[]> {
    const { data, error } = await supabase
      .from('campamento_criterios')
      .select('criterio_id')
      .eq('campamento_id', campamentoId)
    if (error) throw error
    return data.map((r) => r.criterio_id)
  },
}

export const tiposCalculoService = {
  async getTodos(): Promise<TipoCalculo[]> {
    const { data, error } = await supabase
      .from('tipos_calculo')
      .select('*')
      .order('orden')
    if (error) throw error
    return data as TipoCalculo[]
  },

  async crear(datos: Omit<TipoCalculo, 'created_at' | 'updated_at'>): Promise<TipoCalculo> {
    const { data, error } = await supabase
      .from('tipos_calculo')
      .insert(datos)
      .select()
      .single()
    if (error) throw error
    return data as TipoCalculo
  },

  async actualizar(clave: string, datos: Partial<Omit<TipoCalculo, 'clave' | 'created_at' | 'updated_at'>>): Promise<TipoCalculo> {
    const { data, error } = await supabase
      .from('tipos_calculo')
      .update(datos)
      .eq('clave', clave)
      .select()
      .single()
    if (error) throw error
    return data as TipoCalculo
  },

  async eliminar(clave: string): Promise<void> {
    const { error } = await supabase
      .from('tipos_calculo')
      .delete()
      .eq('clave', clave)
    if (error) throw error
  },
}

export const publicoService = {
  async getCalendario(): Promise<PublicoCalendario[]> {
    const { data, error } = await supabase
      .from('publico_calendario')
      .select('*')
      .order('orden')
    if (error) throw error
    return data
  },

  async getCalendarioCampamento(campamentoId: string): Promise<PublicoCalendario[]> {
    const { data, error } = await supabase
      .from('publico_calendario')
      .select('*')
      .eq('campamento_id', campamentoId)
      .order('orden')
    if (error) throw error
    return data
  },

  async getCriterios(): Promise<PublicoCriterio[]> {
    const { data, error } = await supabase
      .from('publico_criterios')
      .select('*')
      .order('orden')
    if (error) throw error
    return data
  },

  async getCampamentosActivos(): Promise<PublicoCampamento[]> {
    const { data, error } = await supabase
      .from('publico_campamento')
      .select('*')
      .order('edicion', { ascending: false })
    if (error) throw error
    return data ?? []
  },

  async getCampamentoActivo(): Promise<PublicoCampamento | null> {
    const { data, error } = await supabase
      .from('publico_campamento')
      .select('*')
      .order('edicion', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (error) throw error
    return data
  },
}
