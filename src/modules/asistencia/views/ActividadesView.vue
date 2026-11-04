<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useDiasCampamento } from '@/composables/useDiasCampamento'
import {
  actividadesService,
  criteriosEvalService,
  type ActividadConProgramacion,
  type CriterioEval,
} from '@/modules/asistencia/services/asistencia.service'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database'
import { useSessionStore } from '@/modules/auth/store'
import { useCampamentoStore } from '@/stores/campamento'

// ── Tipos ────────────────────────────────────────────────────────────────────
type ProgramacionConCriterio = Tables<'programacion'> & {
  criterios: Tables<'criterios'>
}
type CampamentoCriterioConCriterio = { criterio_id: string; criterios: Tables<'criterios'> | null }

// ── Constantes ────────────────────────────────────────────────────────────────
const { momentos, fechas, cargar: cargarCampamento, labelDia, detectarMomentoActual } = useDiasCampamento()

// ── Estado ────────────────────────────────────────────────────────────────────
const session    = useSessionStore()
const campStore  = useCampamentoStore()
const cargando = ref(true)
const error = ref('')
const guardando = ref(false)
const errorGuardado = ref('')

const momentoActivo = ref<string>('')
const momentosConProg = ref<Set<string>>(new Set())

const momentosFiltrados = computed(() =>
  momentos.value.filter((m) => momentosConProg.value.has(m)),
)

const actividades = ref<ActividadConProgramacion[]>([])
const criteriosAsistencia = ref<Tables<'criterios'>[]>([])
const tiposCalculo = ref<{ clave: string; nombre: string }[]>([])
const programacionDia = ref<{ criterio_id: string; puntaje_max: number; tipo_calculo: string }[]>([])

// ── Dialogs ───────────────────────────────────────────────────────────────────
const dialogForm = ref(false)
const esEdicion = ref(false)
const actividadEditando = ref<ActividadConProgramacion | null>(null)

// Campos del formulario
const form = ref({
  criterio_id: '',
  nombre: '',
  hora_inicio: '',
  lugar: '',
})

const dialogCancelar = ref(false)
const actividadCancelando = ref<ActividadConProgramacion | null>(null)
const motivoCancelacion = ref('')

const dialogAyuda = ref(false)

// ── Dialog criterios de evaluación ───────────────────────────────────────────
interface CriterioForm { nombre: string; puntaje: number | null }

const dialogCriterios      = ref(false)
const actividadCriterios   = ref<ActividadConProgramacion | null>(null)
const criteriosForm        = ref<CriterioForm[]>([])
const guardandoCriterios   = ref(false)
const errorCriterios       = ref('')
const criteriosGuardados   = ref<Set<string>>(new Set()) // IDs de actividades con criterios

const puntajeMaxActividad = computed(() => {
  if (!actividadCriterios.value) return 100
  const distribuido = ptsDistribuidos(actividadCriterios.value)
  if (distribuido > 0) return distribuido
  return (actividadCriterios.value.programacion as ProgramacionConCriterio)?.puntaje_max ?? 100
})

const sumaActual = computed(() =>
  criteriosForm.value.reduce((s, c) => s + (c.puntaje ?? 0), 0)
)

const sumaValida = computed(() => sumaActual.value === puntajeMaxActividad.value)

async function abrirCriterios(act: ActividadConProgramacion) {
  actividadCriterios.value = act
  errorCriterios.value     = ''
  guardandoCriterios.value = false
  dialogCriterios.value    = true

  // Cargar criterios existentes
  try {
    const existentes: CriterioEval[] = await criteriosEvalService.getPorActividad(act.id)
    criteriosForm.value = existentes.length
      ? existentes.map((c) => ({ nombre: c.nombre, puntaje: Number(c.puntaje_max) }))
      : [{ nombre: '', puntaje: null }]
  } catch {
    criteriosForm.value = [{ nombre: '', puntaje: null }]
  }
}

function agregarFilaCriterio() {
  criteriosForm.value.push({ nombre: '', puntaje: null })
}

function eliminarFilaCriterio(idx: number) {
  criteriosForm.value.splice(idx, 1)
}

function distribuirEquitativamente() {
  const n = criteriosForm.value.length
  if (!n) return
  const base  = Math.floor(puntajeMaxActividad.value / n)
  const resto = puntajeMaxActividad.value - base * n
  criteriosForm.value.forEach((c, i) => {
    c.puntaje = base + (i === 0 ? resto : 0)
  })
}

async function guardarCriterios() {
  if (!actividadCriterios.value) return
  guardandoCriterios.value = true
  errorCriterios.value     = ''
  try {
    await criteriosEvalService.guardar(
      actividadCriterios.value.id,
      criteriosForm.value.map((c, i) => ({
        nombre:      c.nombre.trim(),
        puntaje_max: c.puntaje ?? 0,
        orden:       i,
      })),
    )
    criteriosGuardados.value.add(actividadCriterios.value.id)
    dialogCriterios.value = false
  } catch (e: unknown) {
    errorCriterios.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardandoCriterios.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function fechaCompleta(momento: string): string {
  const f = fechas.value[momento]
  if (!f) return ''
  const d = new Date(f + 'T12:00:00')
  return d.toLocaleDateString('es', { weekday: 'long', day: 'numeric', month: 'long' })
}

const actividadesDelDia = computed(() =>
  actividades.value.filter(
    (a) => (a.programacion as ProgramacionConCriterio)?.momento === momentoActivo.value,
  ),
)

function nombreTipoCalculo(tipoCalculo: string | null | undefined): string {
  if (!tipoCalculo) return ''
  return tiposCalculo.value.find((t) => t.clave === tipoCalculo)?.nombre ?? tipoCalculo
}

// Distribución de puntaje — solo para Programa Estelar
const infoPuntajeDia = computed(() =>
  programacionDia.value
    .filter((prog) => prog.tipo_calculo === 'programa_estelar')
    .map((prog) => {
      const actsActivas = actividadesDelDia.value.filter(
        (a) => a.estado !== 'cancelada' && (a.programacion as any)?.criterio_id === prog.criterio_id,
      )
      const count = actsActivas.length
      const ptsPorAct = count > 0 ? Math.round(prog.puntaje_max / count) : prog.puntaje_max
      return {
        criterio_id: prog.criterio_id,
        nombre_tipo: nombreTipoCalculo(prog.tipo_calculo),
        puntaje_max: prog.puntaje_max,
        count,
        ptsPorAct,
      }
    })
)

function ptsDistribuidos(act: ActividadConProgramacion): number {
  const criterioId = (act.programacion as any)?.criterio_id
  return infoPuntajeDia.value.find((i) => i.criterio_id === criterioId)?.ptsPorAct ?? 0
}

// Opciones para el select Criterio: todos los tipos de cálculo del campamento
const opcionesCriterio = computed(() =>
  tiposCalculo.value
    .map((t) => {
      const criterio = criteriosAsistencia.value.find((c) => c.tipo_calculo === t.clave)
      return criterio ? { label: t.nombre, value: criterio.id } : null
    })
    .filter((o): o is { label: string; value: string } => o !== null)
)

// ── Carga ─────────────────────────────────────────────────────────────────────
async function cargar() {
  if (!campStore.selectedId) {
    actividades.value = []
    criteriosAsistencia.value = []
    cargando.value = false
    return
  }
  cargando.value = true
  error.value = ''
  try {
    await cargarCampamento()
    momentoActivo.value = detectarMomentoActual()
    await Promise.all([cargarActividades(), cargarCriteriosAsistencia(), cargarCriteriosGuardados(), cargarTiposCalculo(), cargarMomentosConProgramacion()])
    // Si el momento activo no tiene programación, usar el primero que sí tenga
    if (!momentosConProg.value.has(momentoActivo.value)) {
      momentoActivo.value = momentosFiltrados.value[0] ?? momentoActivo.value
    }
    await cargarProgramacionDia(momentoActivo.value)
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al cargar datos'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
watch(() => campStore.selectedId, cargar)

async function cargarActividades() {
  const campId = campStore.selectedId!
  const { data, error: err } = await supabase
    .from('actividades')
    .select('*, programacion!inner(*, criterios(*))')
    .eq('programacion.campamento_id', campId)
    .order('hora_inicio', { ascending: true, nullsFirst: true })
  if (err) throw err
  actividades.value = ((data ?? []).filter((a) => a.programacion !== null)) as ActividadConProgramacion[]
}

async function cargarCriteriosGuardados() {
  const campId = campStore.selectedId!
  const { data, error: err } = await supabase
    .from('actividad_criterios_eval')
    .select('actividad_id, actividades!inner(programacion!inner(campamento_id))')
    .eq('actividades.programacion.campamento_id', campId)
  if (err) return
  criteriosGuardados.value = new Set((data ?? []).map((r) => r.actividad_id))
}

async function cargarCriteriosAsistencia() {
  const campId = campStore.selectedId!
  const { data, error: err } = await supabase
    .from('campamento_criterios')
    .select('criterio_id, criterios(*)')
    .eq('campamento_id', campId)
  if (err) throw err
  criteriosAsistencia.value = (data as CampamentoCriterioConCriterio[] ?? [])
    .map((r) => r.criterios)
    .filter((c): c is Tables<'criterios'> => c !== null)
}

async function cargarTiposCalculo() {
  const { data, error: err } = await supabase
    .from('tipos_calculo')
    .select('clave, nombre')
    .order('orden')
  if (err) return
  tiposCalculo.value = data ?? []
}

async function cargarProgramacionDia(momento: string) {
  const campId = campStore.selectedId!
  const { data, error: err } = await supabase
    .from('programacion')
    .select('criterio_id, puntaje_max, criterios(tipo_calculo)')
    .eq('campamento_id', campId)
    .eq('momento', momento)
    .eq('estado', 'programado')
  if (err) return
  programacionDia.value = (data ?? []).map((r: any) => ({
    criterio_id: r.criterio_id,
    puntaje_max: r.puntaje_max,
    tipo_calculo: r.criterios?.tipo_calculo ?? '',
  }))
}

async function cargarMomentosConProgramacion() {
  const campId = campStore.selectedId!
  const { data, error: err } = await supabase
    .from('programacion')
    .select('momento')
    .eq('campamento_id', campId)
    .eq('estado', 'programado')
    .gt('puntaje_max', 0)
  if (err) return
  momentosConProg.value = new Set((data ?? []).map((r) => r.momento))
}

async function seleccionarMomento(m: string) {
  momentoActivo.value = m
  await cargarProgramacionDia(m)
}

// ── CRUD Actividades ──────────────────────────────────────────────────────────
const HORAS_RAPIDAS = ['07:00', '08:00', '09:00', '10:00', '14:00', '15:00', '19:00', '20:00', '21:00']

function abrirNueva() {
  esEdicion.value = false
  actividadEditando.value = null
  form.value = {
    criterio_id: opcionesCriterio.value.length === 1 ? opcionesCriterio.value[0]!.value : '',
    nombre: '',
    hora_inicio: '',
    lugar: '',
  }
  errorGuardado.value = ''
  dialogForm.value = true
}

function abrirEditar(act: ActividadConProgramacion) {
  esEdicion.value = true
  actividadEditando.value = act
  form.value = {
    criterio_id: (act.programacion as ProgramacionConCriterio)?.criterio_id ?? '',
    nombre: act.nombre,
    hora_inicio: act.hora_inicio ?? '',
    lugar: act.lugar ?? '',
  }
  errorGuardado.value = ''
  dialogForm.value = true
}

async function guardarActividad() {
  if (!form.value.nombre.trim() || !form.value.criterio_id) {
    errorGuardado.value = 'Nombre y criterio son obligatorios.'
    return
  }
  if (!momentoActivo.value) {
    errorGuardado.value = 'No hay días configurados para este campamento.'
    return
  }
  guardando.value = true
  errorGuardado.value = ''
  try {
    const campId = campStore.selectedId!

    // Buscar la programacion existente para este criterio × día (sin sobrescribir puntaje_max)
    let { data: prog, error: progErr } = await supabase
      .from('programacion')
      .select('id')
      .eq('campamento_id', campId)
      .eq('criterio_id', form.value.criterio_id)
      .eq('momento', momentoActivo.value)
      .single()

    // Si no existe, crearla con puntaje_max por defecto
    if (!prog) {
      const { data: nuevaProg, error: insertErr } = await supabase
        .from('programacion')
        .insert({
          campamento_id: campId,
          criterio_id: form.value.criterio_id,
          momento: momentoActivo.value,
          puntaje_max: 100,
          estado: 'programado',
        })
        .select('id')
        .single()
      if (insertErr) throw new Error(insertErr.message)
      prog = nuevaProg
    } else if (progErr && progErr.code !== 'PGRST116') {
      throw new Error(progErr.message)
    }

    if (esEdicion.value && actividadEditando.value) {
      const { error: updErr } = await supabase
        .from('actividades')
        .update({
          programacion_id: prog.id,
          nombre: form.value.nombre.trim(),
          hora_inicio: form.value.hora_inicio || null,
          lugar: form.value.lugar.trim() || null,
        })
        .eq('id', actividadEditando.value.id)
      if (updErr) throw new Error(updErr.message)
    } else {
      await actividadesService.crear({
        programacion_id: prog.id,
        nombre: form.value.nombre.trim(),
        hora_inicio: form.value.hora_inicio || null,
        lugar: form.value.lugar.trim() || null,
        evaluador_id: session.user!.id,
        estado: 'programada',
      })
    }
    await cargarActividades()
    dialogForm.value = false
  } catch (e: unknown) {
    errorGuardado.value = e instanceof Error ? e.message : 'Error al guardar'
  } finally {
    guardando.value = false
  }
}

async function marcarRealizada(act: ActividadConProgramacion) {
  try {
    await actividadesService.marcarRealizada(act.id)
    await cargarActividades()
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Error al actualizar'
  }
}

function abrirCancelar(act: ActividadConProgramacion) {
  actividadCancelando.value = act
  motivoCancelacion.value = ''
  dialogCancelar.value = true
}

async function confirmarCancelar() {
  if (!actividadCancelando.value) return
  guardando.value = true
  try {
    await actividadesService.cancelar(actividadCancelando.value.id, motivoCancelacion.value.trim())
    await cargarActividades()
    dialogCancelar.value = false
  } catch (e: unknown) {
    errorGuardado.value = e instanceof Error ? e.message : 'Error al cancelar'
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div class="max-w-3xl mx-auto px-3 py-4 sm:px-6">

    <!-- ── Header ─────────────────────────────────────────────────────────── -->
    <div class="flex items-start justify-between gap-3 mb-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Actividades</h1>
        <p class="mt-1 text-sm text-slate-500">Crea y gestiona las actividades del campamento por día</p>
      </div>

      <!-- Botones cabecera -->
      <div class="flex items-center gap-2 flex-shrink-0">
        <!-- Botón ayuda -->
        <button
          class="w-9 h-9 flex items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 hover:text-green-600 hover:border-green-300 shadow-sm transition-colors"
          title="¿Cómo funciona este módulo?"
          @click="dialogAyuda = true"
        >
          <i class="pi pi-question-circle text-base" />
        </button>

        <!-- Botón nueva actividad -->
        <button
          v-if="session.esAdmin"
          class="inline-flex items-center gap-2 px-4 h-10 bg-green-600 hover:bg-green-700 text-white font-semibold text-sm rounded-xl shadow-sm transition-colors"
          @click="abrirNueva"
        >
          <i class="pi pi-plus text-xs" />
          Nueva actividad
        </button>
      </div>
    </div>

    <!-- ── Sin campamento ────────────────────────────────────────────────────── -->
    <div v-if="!campStore.selectedId && !cargando" class="flex flex-col items-center justify-center py-16 text-center gap-3">
      <i class="pi pi-building text-4xl text-gray-300" />
      <p class="text-base font-semibold text-gray-500 m-0">Selecciona un campamento</p>
      <p class="text-sm text-gray-400 m-0">Elige un campamento en el menú lateral para ver sus actividades.</p>
    </div>

    <!-- ── Cargando ────────────────────────────────────────────────────────── -->
    <div v-else-if="cargando" class="flex justify-center py-12">
      <svg class="animate-spin h-8 w-8 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
    </div>

    <!-- ── Error ───────────────────────────────────────────────────────────── -->
    <div
      v-else-if="error"
      class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm"
    >
      <i class="pi pi-exclamation-circle flex-shrink-0" />
      {{ error }}
    </div>

    <template v-else>

      <!-- ── Selector de días ──────────────────────────────────────────────── -->
      <div class="flex gap-2 flex-wrap mb-2">
        <button
          v-for="m in momentosFiltrados"
          :key="m"
          class="px-3 py-2 rounded-full text-sm font-semibold border min-h-[44px] transition"
          :class="momentoActivo === m
            ? 'bg-green-600 text-white border-green-600'
            : 'bg-white text-gray-600 border-gray-200 hover:border-green-300'"
          @click="seleccionarMomento(m)"
        >
          {{ labelDia(m) }}
        </button>
      </div>

      <!-- ── Fecha completa del día activo ─────────────────────────────────── -->
      <p class="text-xs text-gray-500 mb-3 capitalize">{{ fechaCompleta(momentoActivo) }}</p>

      <!-- ── Puntajes programados del día ─────────────────────────────────── -->
      <div v-if="infoPuntajeDia.length" class="flex flex-col gap-2 mb-3">
        <div
          v-for="info in infoPuntajeDia"
          :key="info.criterio_id"
          class="flex items-center gap-3 rounded-xl px-4 py-2.5 text-sm border"
          :class="info.count === 0
            ? 'bg-amber-50 border-amber-200 text-amber-800'
            : 'bg-blue-50 border-blue-200 text-blue-800'"
        >
          <i
            class="pi flex-shrink-0"
            :class="info.count === 0 ? 'pi-exclamation-triangle text-amber-500' : 'pi-info-circle text-blue-500'"
          />
          <span class="flex-1">
            <strong>{{ info.nombre_tipo }}</strong>:
            <template v-if="info.count === 0">
              {{ info.puntaje_max }} pts programados — Crea al menos una actividad para aplicar este puntaje.
            </template>
            <template v-else>
              {{ info.puntaje_max }} pts ÷ {{ info.count }} actividad{{ info.count > 1 ? 'es' : '' }} = <strong>{{ info.ptsPorAct }} pts c/u</strong>
            </template>
          </span>
        </div>
      </div>

      <!-- ── Lista de actividades ──────────────────────────────────────────── -->
      <div v-if="actividadesDelDia.length" class="flex flex-col gap-2">
        <div
          v-for="act in actividadesDelDia"
          :key="act.id"
          class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm flex items-start justify-between gap-3"
          :class="{ 'opacity-60': act.estado === 'cancelada' }"
        >
          <!-- Left: criterio chip + meta -->
          <div class="flex items-start gap-2 flex-1 min-w-0">
            <div class="flex flex-col gap-1 flex-shrink-0 mt-0.5">
              <span class="text-xs font-bold bg-green-100 text-green-700 rounded-full px-2 py-0.5 whitespace-nowrap text-center">
                {{ (act.programacion as any)?.criterios?.codigo ?? '—' }}
              </span>
              <span
                v-if="(act.programacion as any)?.criterios?.tipo_calculo"
                class="text-xs font-semibold bg-slate-100 text-slate-600 rounded-full px-2 py-0.5 whitespace-nowrap text-center"
              >
                {{ nombreTipoCalculo((act.programacion as any)?.criterios?.tipo_calculo) }}
              </span>
            </div>

            <div class="flex flex-col gap-0.5 min-w-0">
              <span v-if="act.hora_inicio" class="text-xs text-gray-500 font-semibold">
                {{ act.hora_inicio.slice(0, 5) }}
              </span>
              <span
                class="text-sm font-semibold text-gray-800 truncate"
                :class="{ 'line-through': act.estado === 'cancelada' }"
              >
                {{ act.nombre }}
              </span>
              <span v-if="ptsDistribuidos(act) > 0" class="flex items-center gap-1 text-xs text-blue-600 font-semibold">
                <i class="pi pi-star text-xs text-amber-400" />
                {{ ptsDistribuidos(act) }} pts
              </span>
              <span v-if="act.lugar" class="flex items-center gap-1 text-xs text-gray-500">
                <i class="pi pi-map-marker text-xs" />
                {{ act.lugar }}
              </span>
            </div>
          </div>

          <!-- Right: estado badge + action buttons -->
          <div class="flex flex-col items-end gap-1.5 flex-shrink-0">
            <div class="flex items-center gap-1.5">
              <!-- Badge criterios configurados -->
              <span
                v-if="criteriosGuardados.has(act.id)"
                class="text-xs font-bold rounded-full px-2 py-0.5 bg-purple-100 text-purple-700"
                title="Criterios de evaluación configurados"
              >
                <i class="pi pi-sliders-h text-[10px]" /> Criterios ✓
              </span>
              <span
                class="text-xs font-bold rounded-full px-2 py-0.5 capitalize"
                :class="{
                  'bg-green-100 text-green-700': act.estado === 'programada',
                  'bg-emerald-100 text-emerald-700': act.estado === 'realizada',
                  'bg-red-100 text-red-600': act.estado === 'cancelada',
                }"
              >
                {{ act.estado }}
              </span>
            </div>

            <div v-if="session.esAdmin" class="flex gap-1 flex-wrap justify-end">
              <!-- Criterios de evaluación -->
              <button
                class="h-9 px-2.5 rounded-lg border border-purple-200 flex items-center gap-1 text-purple-600 hover:border-purple-400 hover:bg-purple-50 transition text-xs font-semibold"
                aria-label="Criterios de evaluación"
                title="Criterios de evaluación"
                @click="abrirCriterios(act)"
              >
                <i class="pi pi-sliders-h text-xs" />
                <span class="hidden sm:inline">Criterios</span>
              </button>
              <!-- Editar -->
              <button
                class="w-9 h-9 rounded-lg border border-gray-200 flex items-center justify-center text-gray-500 hover:border-gray-300 hover:bg-gray-50 transition"
                aria-label="Editar"
                @click="abrirEditar(act)"
              >
                <i class="pi pi-pencil text-xs" />
              </button>
              <!-- Marcar realizada -->
              <button
                v-if="act.estado === 'programada'"
                class="w-9 h-9 rounded-lg border border-green-200 flex items-center justify-center text-green-600 hover:border-green-400 hover:bg-green-50 transition"
                aria-label="Marcar realizada"
                @click="marcarRealizada(act)"
              >
                <i class="pi pi-check text-xs" />
              </button>
              <!-- Cancelar -->
              <button
                v-if="act.estado !== 'cancelada'"
                class="w-9 h-9 rounded-lg border border-red-200 flex items-center justify-center text-red-500 hover:border-red-400 hover:bg-red-50 transition"
                aria-label="Cancelar actividad"
                @click="abrirCancelar(act)"
              >
                <i class="pi pi-times text-xs" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Estado vacío ──────────────────────────────────────────────────── -->
      <p v-else class="text-center text-gray-500 text-sm py-8">
        No hay actividades para este día. Usa "Nueva actividad" para agregar.
      </p>

    </template><!-- /v-else general -->

    <!-- ── Modal crear / editar ──────────────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogForm"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogForm = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[92dvh] overflow-y-auto">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 bg-gray-200 rounded-full" /></div>

          <!-- Header con día activo -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div>
              <h2 class="text-base font-bold text-gray-800 m-0">
                {{ esEdicion ? 'Editar actividad' : 'Nueva actividad' }}
              </h2>
              <p class="text-xs text-gray-400 m-0 mt-0.5 capitalize">{{ fechaCompleta(momentoActivo) }}</p>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 transition" @click="dialogForm = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Cuerpo -->
          <div class="flex flex-col gap-4 px-5 py-5">

            <!-- Sin criterios configurados en el campamento -->
            <div
              v-if="!opcionesCriterio.length"
              class="bg-amber-50 border border-amber-200 text-amber-800 rounded-xl px-4 py-3 text-xs leading-relaxed"
            >
              <p class="font-semibold m-0 mb-1">Sin criterios disponibles</p>
              <p class="m-0">Ve a <strong>Programación</strong> y vincula criterios al campamento activo para que aparezcan aquí.</p>
            </div>

            <template v-else>
              <!-- Criterio -->
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Criterio *</label>
                <select
                  v-model="form.criterio_id"
                  class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm font-medium focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[48px] bg-gray-50 focus:bg-white transition"
                >
                  <option value="" disabled>Selecciona el tipo de cálculo...</option>
                  <option v-for="op in opcionesCriterio" :key="op.value" :value="op.value">
                    {{ op.label }}
                  </option>
                </select>
              </div>

              <!-- Nombre -->
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Nombre de la actividad *</label>
                <input
                  v-model="form.nombre"
                  type="text"
                  placeholder="Ej: Programa estelar — Noche de talentos"
                  class="w-full border border-gray-200 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[48px] bg-gray-50 focus:bg-white transition"
                />
              </div>

              <!-- Hora -->
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Hora de inicio <span class="text-gray-400 normal-case font-normal">(opcional)</span></label>
                <!-- Atajos rápidos -->
                <div class="flex flex-wrap gap-1.5">
                  <button
                    v-for="h in HORAS_RAPIDAS"
                    :key="h"
                    type="button"
                    class="px-2.5 py-1.5 rounded-lg border text-xs font-semibold transition"
                    :class="form.hora_inicio === h
                      ? 'bg-green-600 text-white border-green-600'
                      : 'bg-white text-gray-600 border-gray-200 hover:border-green-300'"
                    @click="form.hora_inicio = form.hora_inicio === h ? '' : h"
                  >{{ h }}</button>
                </div>
                <!-- Input manual -->
                <input
                  v-model="form.hora_inicio"
                  type="time"
                  class="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
                />
              </div>

              <!-- Lugar -->
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Lugar <span class="text-gray-400 normal-case font-normal">(opcional)</span></label>
                <input
                  v-model="form.lugar"
                  type="text"
                  placeholder="Ej: Auditorio principal"
                  class="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 min-h-[44px] bg-gray-50 focus:bg-white transition"
                />
              </div>
            </template>

            <!-- Error -->
            <div v-if="errorGuardado" class="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-3 py-2.5 text-xs">
              <i class="pi pi-exclamation-circle flex-shrink-0" />
              {{ errorGuardado }}
            </div>
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
            <button class="px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 min-h-[44px] transition" @click="dialogForm = false">
              Cancelar
            </button>
            <button
              class="flex items-center gap-1.5 px-5 py-2.5 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl font-semibold text-sm min-h-[44px] transition"
              :disabled="!form.nombre.trim() || !form.criterio_id || guardando || !opcionesCriterio.length"
              @click="guardarActividad"
            >
              <svg v-if="guardando" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <i v-else class="pi pi-check text-xs" />
              {{ esEdicion ? 'Guardar cambios' : 'Crear actividad' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal cancelar actividad ──────────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogCancelar"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogCancelar = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[90vh] overflow-y-auto">
          <!-- Drag handle (mobile only) -->
          <div class="flex justify-center pt-3 pb-1 sm:hidden">
            <div class="w-10 h-1 bg-gray-300 rounded-full" />
          </div>

          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <h2 class="text-base font-bold text-gray-800">Cancelar actividad</h2>
            <button
              class="w-8 h-8 flex items-center justify-center rounded-lg text-gray-400 hover:bg-gray-100 transition"
              aria-label="Cerrar"
              @click="dialogCancelar = false"
            >
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Content -->
          <div class="px-5 py-4 flex flex-col gap-3">
            <p class="text-sm text-gray-700">
              Indicar motivo de cancelación de:
              <strong class="font-semibold">{{ actividadCancelando?.nombre }}</strong>
            </p>
            <textarea
              v-model="motivoCancelacion"
              rows="3"
              placeholder="Ej: Lluvia imprevista, se reprograma para mañana..."
              autofocus
              class="w-full border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-100 bg-gray-50 focus:bg-white transition resize-none"
            />
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-gray-100">
            <button
              class="px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 min-h-[44px] transition"
              @click="dialogCancelar = false"
            >
              Cancelar
            </button>
            <button
              class="flex items-center gap-1.5 px-4 py-2.5 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl font-semibold text-sm min-h-[44px] transition"
              :disabled="guardando"
              @click="confirmarCancelar"
            >
              <svg v-if="guardando" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <i v-else class="pi pi-times text-xs" />
              Confirmar cancelación
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal criterios de evaluación ───────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogCriterios"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogCriterios = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-lg mt-auto sm:mt-0 max-h-[94dvh] flex flex-col">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 bg-gray-200 rounded-full" /></div>

          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100 flex-shrink-0">
            <div>
              <h2 class="text-base font-bold text-gray-800 m-0">Criterios de evaluación</h2>
              <p class="text-xs text-gray-400 m-0 mt-0.5 truncate max-w-xs">{{ actividadCriterios?.nombre }}</p>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 transition" @click="dialogCriterios = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Barra de puntaje total -->
          <div class="px-5 pt-4 flex-shrink-0">
            <div class="bg-slate-50 border rounded-xl px-4 py-3 flex items-center justify-between gap-3">
              <div class="flex flex-col gap-0.5">
                <span class="text-xs font-semibold text-slate-500 uppercase tracking-wide">Puntaje total de la actividad</span>
                <span class="text-sm text-slate-700">Distribuye <strong class="text-slate-900">{{ puntajeMaxActividad }} pts</strong> entre los criterios</span>
              </div>
              <!-- Indicador suma -->
              <div
                class="flex flex-col items-center px-3 py-1.5 rounded-lg text-xs font-bold min-w-[64px] text-center transition-colors"
                :class="sumaValida
                  ? 'bg-green-100 text-green-700'
                  : sumaActual > puntajeMaxActividad
                    ? 'bg-red-100 text-red-600'
                    : 'bg-amber-100 text-amber-700'"
              >
                <span class="text-lg font-black leading-tight">{{ sumaActual }}</span>
                <span>/ {{ puntajeMaxActividad }}</span>
              </div>
            </div>

            <!-- Barra de progreso visual -->
            <div class="mt-2 h-2 bg-slate-100 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-300"
                :class="sumaActual > puntajeMaxActividad ? 'bg-red-500' : sumaValida ? 'bg-green-500' : 'bg-amber-400'"
                :style="{ width: Math.min(100, (sumaActual / puntajeMaxActividad) * 100) + '%' }"
              />
            </div>
          </div>

          <!-- Lista de criterios -->
          <div class="flex-1 overflow-y-auto px-5 py-4 flex flex-col gap-2">
            <div
              v-for="(c, idx) in criteriosForm"
              :key="idx"
              class="flex items-center gap-2"
            >
              <!-- Número -->
              <span class="w-6 h-6 rounded-full bg-purple-100 text-purple-700 text-xs font-bold flex items-center justify-center flex-shrink-0">
                {{ idx + 1 }}
              </span>

              <!-- Nombre -->
              <input
                v-model="c.nombre"
                type="text"
                placeholder="Nombre del criterio…"
                class="flex-1 min-w-0 border border-gray-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:border-purple-400 focus:ring-2 focus:ring-purple-100 bg-gray-50 focus:bg-white transition min-h-[44px]"
              />

              <!-- Puntaje -->
              <input
                v-model.number="c.puntaje"
                type="number"
                min="0"
                :max="puntajeMaxActividad"
                placeholder="Pts"
                class="w-20 border border-gray-200 rounded-lg px-3 py-2.5 text-sm text-center font-bold focus:outline-none focus:border-purple-400 focus:ring-2 focus:ring-purple-100 bg-gray-50 focus:bg-white transition min-h-[44px]"
              />

              <!-- Eliminar fila -->
              <button
                class="w-9 h-9 flex-shrink-0 flex items-center justify-center rounded-lg border border-red-100 text-red-400 hover:bg-red-50 hover:border-red-300 transition"
                :disabled="criteriosForm.length === 1"
                @click="eliminarFilaCriterio(idx)"
              >
                <i class="pi pi-trash text-xs" />
              </button>
            </div>

            <!-- Agregar fila -->
            <button
              class="mt-1 flex items-center gap-2 px-3 py-2.5 rounded-xl border border-dashed border-purple-300 text-purple-600 hover:bg-purple-50 text-sm font-semibold transition w-full justify-center min-h-[44px]"
              @click="agregarFilaCriterio"
            >
              <i class="pi pi-plus text-xs" /> Agregar criterio
            </button>
          </div>

          <!-- Error -->
          <div v-if="errorCriterios" class="mx-5 mb-2 flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 rounded-xl px-3 py-2.5 text-xs flex-shrink-0">
            <i class="pi pi-exclamation-circle flex-shrink-0" /> {{ errorCriterios }}
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-between gap-2 px-5 py-4 border-t border-gray-100 flex-shrink-0">
            <!-- Distribuir equitativamente -->
            <button
              class="flex items-center gap-1.5 px-3 py-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 text-xs font-semibold transition min-h-[44px]"
              @click="distribuirEquitativamente"
            >
              <i class="pi pi-arrows-h text-xs" /> Distribuir
            </button>

            <div class="flex gap-2">
              <button
                class="px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-600 hover:bg-gray-50 min-h-[44px] transition"
                @click="dialogCriterios = false"
              >
                Cancelar
              </button>
              <button
                class="flex items-center gap-1.5 px-5 py-2.5 rounded-xl font-semibold text-sm min-h-[44px] transition"
                :class="sumaValida && criteriosForm.every(c => c.nombre.trim()) && !guardandoCriterios
                  ? 'bg-purple-600 hover:bg-purple-700 text-white'
                  : 'bg-slate-100 text-slate-400 cursor-not-allowed'"
                :disabled="!sumaValida || criteriosForm.some(c => !c.nombre.trim()) || guardandoCriterios"
                @click="guardarCriterios"
              >
                <svg v-if="guardandoCriterios" class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                <i v-else class="pi pi-check text-xs" />
                {{ guardandoCriterios ? 'Guardando…' : 'Guardar criterios' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Modal ayuda ──────────────────────────────────────────────────────── -->
    <Teleport to="body">
      <div
        v-if="dialogAyuda"
        class="fixed inset-0 z-50 flex flex-col sm:items-center sm:justify-center bg-black/40"
        @click.self="dialogAyuda = false"
      >
        <div class="bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl w-full sm:max-w-md mt-auto sm:mt-0 max-h-[80vh] overflow-y-auto">
          <div class="flex justify-center pt-3 sm:hidden"><div class="w-10 h-1 rounded-full bg-gray-200" /></div>

          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                <i class="pi pi-calendar-clock text-green-600 text-sm" />
              </div>
              <h2 class="font-bold text-gray-800">Actividades — ¿cómo funciona?</h2>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-400" @click="dialogAyuda = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Contenido -->
          <div class="px-5 py-4 space-y-4 text-sm text-gray-700">
            <div>
              <p class="font-semibold text-gray-800 mb-1"><i class="pi pi-info-circle mr-1.5 text-green-600" />¿Qué es?</p>
              <p class="text-xs text-gray-600 leading-relaxed">Gestiona las actividades del campamento (programa estelar, eventos, ceremonias) y registra quién asistió. El puntaje se calcula automáticamente por equipo.</p>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-2"><i class="pi pi-list mr-1.5 text-green-600" />Flujo de uso</p>
              <ul class="text-xs text-gray-600 space-y-1.5">
                <li><strong>1. Crear actividad</strong> — Vincula a un criterio de tipo <em>asistencia</em>, ponle nombre, hora y lugar.</li>
                <li><strong>2. Marcar realizada</strong> — Cuando se ejecute, confirma con el botón ✓.</li>
                <li><strong>3. Registrar asistencia</strong> — En el menú <em>Asistencia</em>, marca Presente / Ausente / Justificado por integrante.</li>
              </ul>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-1"><i class="pi pi-calculator mr-1.5 text-green-600" />Fórmula de puntaje</p>
              <code class="block text-xs bg-green-50 border border-green-200 rounded-lg px-3 py-2 text-green-800 font-mono">
                min(100, presentes / convocados / 0.95 × 100)
              </code>
              <p class="text-xs text-gray-500 mt-1.5">Convocados = elegibles − justificados documentados. Llegar al 95 % da 100 pts.</p>
            </div>
            <div>
              <p class="font-semibold text-gray-800 mb-2"><i class="pi pi-tag mr-1.5 text-green-600" />Estados</p>
              <div class="text-xs text-gray-600 space-y-1">
                <div class="flex items-center gap-2"><span class="bg-green-100 text-green-700 font-bold px-2 py-0.5 rounded-full">Programada</span> pendiente de realizarse</div>
                <div class="flex items-center gap-2"><span class="bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">Realizada</span> completada, puntaje confirmado</div>
                <div class="flex items-center gap-2"><span class="bg-red-100 text-red-600 font-bold px-2 py-0.5 rounded-full">Cancelada</span> no descuenta puntos a nadie</div>
              </div>
            </div>
          </div>

          <div class="px-5 pb-5">
            <button class="w-full py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold text-sm transition" @click="dialogAyuda = false">Entendido</button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

