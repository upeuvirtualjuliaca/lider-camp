<script setup lang="ts">
import { ref } from 'vue'
import type { IncidenciaDetalle } from '../services/incidencias.service'

const props = defineProps<{
  inc: IncidenciaDetalle
  equipoNombre: string
  esAdmin: boolean
  evidenciaUrls: Record<string, string>
  cargandoValidacion?: boolean
}>()

const emit = defineEmits<{
  validar: [motivo: string]
  rechazar: [motivo: string]
  close: []
}>()

const ESTADO: Record<string, { label: string; cls: string }> = {
  registrado: { label: 'Registrada',  cls: 'bg-[#EEF0EE] text-[#4A544F]' },
  descargo:   { label: 'En descargo', cls: 'bg-[#FFF1D6] text-[#7A4F00]' },
  validado:   { label: 'Validada',    cls: 'bg-[#E1F3EA] text-[#0B6B4B]' },
  rechazado:  { label: 'Rechazada',   cls: 'bg-[#FDECEC] text-[#A3261F]' },
}

function estadoLabel(e: string) { return ESTADO[e]?.label ?? e }
function estadoCls(e: string)   { return ESTADO[e]?.cls ?? 'bg-[#EEF0EE] text-[#4A544F]' }

const esBonus = () => props.inc.codigo_info?.tipo === 'bonus'

const mostrarRechazar = ref(false)
const motivoRechazo   = ref('')

function confirmarRechazo() {
  if (!motivoRechazo.value.trim()) return
  emit('rechazar', motivoRechazo.value.trim())
  mostrarRechazar.value = false
  motivoRechazo.value = ''
}
</script>

<template>
  <div class="flex flex-col h-full overflow-y-auto" style="font-family: Inter, system-ui, sans-serif">
    <!-- Header -->
    <div class="flex items-start justify-between gap-3 px-5 pt-5 pb-4 border-b border-[#E3E7E4] flex-shrink-0">
      <div class="flex items-center gap-2 flex-wrap">
        <span
          class="w-10 h-10 rounded-[10px] flex items-center justify-center text-[13px] font-bold flex-shrink-0"
          :class="esBonus() ? 'bg-[#E1F3EA] text-[#0B6B4B]' : 'bg-[#FDECEC] text-[#A3261F]'"
        >{{ inc.codigo }}</span>
        <div class="flex flex-col gap-0.5">
          <span class="text-[15px] font-bold text-[#16201B] leading-tight">{{ inc.codigo_info?.nombre ?? inc.codigo }}</span>
          <span class="text-[11px] font-semibold px-2 py-0.5 rounded-[6px] self-start" :class="estadoCls(inc.estado)">{{ estadoLabel(inc.estado) }}</span>
        </div>
      </div>
      <button
        class="md:hidden w-8 h-8 flex items-center justify-center rounded-lg text-[#5B6660] hover:bg-[#F4F6F4]"
        @click="emit('close')"
        aria-label="Cerrar"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
      </button>
    </div>

    <!-- Mini-cards 2×2 -->
    <div class="grid grid-cols-2 gap-2 px-5 pt-4">
      <div class="bg-[#F4F6F4] rounded-xl p-[10px_12px]">
        <span class="text-[11px] text-[#5B6660] block mb-0.5">Equipo</span>
        <span class="text-[13px] font-semibold text-[#16201B]">{{ equipoNombre }}</span>
      </div>
      <div class="bg-[#F4F6F4] rounded-xl p-[10px_12px]">
        <span class="text-[11px] text-[#5B6660] block mb-0.5">Puntos</span>
        <span class="text-[13px] font-semibold" :class="esBonus() ? 'text-[#0B6B4B]' : 'text-[#A3261F]'">
          {{ esBonus() ? '+' : '−' }}{{ inc.puntos }}
        </span>
      </div>
      <div class="bg-[#F4F6F4] rounded-xl p-[10px_12px]">
        <span class="text-[11px] text-[#5B6660] block mb-0.5">Fecha y hora</span>
        <span class="text-[13px] font-semibold text-[#16201B]">{{ inc.fecha }} {{ (inc.hora ?? '').slice(0,5) }}</span>
      </div>
      <div class="bg-[#F4F6F4] rounded-xl p-[10px_12px]">
        <span class="text-[11px] text-[#5B6660] block mb-0.5">Registró</span>
        <span class="text-[13px] font-semibold text-[#16201B] truncate block">{{ inc.registrado_por?.slice(0,8) ?? '—' }}</span>
      </div>
    </div>

    <!-- Hecho -->
    <div class="px-5 pt-4">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Hecho</span>
      <p class="text-[14px] text-[#16201B] leading-relaxed m-0">{{ inc.hecho }}</p>
    </div>

    <!-- Advertencia previa (D1) -->
    <div v-if="inc.advertencia_referencia" class="px-5 pt-3">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Advertencia previa</span>
      <p class="text-[13px] text-[#3A4540] leading-relaxed m-0">{{ inc.advertencia_referencia }}</p>
    </div>

    <!-- Equipo apoyado (B2) -->
    <div v-if="inc.equipo_apoyado_id" class="px-5 pt-3">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Equipo apoyado</span>
      <p class="text-[13px] text-[#3A4540] m-0">{{ inc.equipo_apoyado_id }}</p>
    </div>

    <!-- Personas involucradas (D6) -->
    <div v-if="(inc.cantidad_personas ?? 1) > 1" class="px-5 pt-3">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Personas involucradas</span>
      <p class="text-[13px] text-[#3A4540] m-0">{{ inc.cantidad_personas }}</p>
    </div>

    <!-- Evidencias -->
    <div class="px-5 pt-4">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-2">Evidencia</span>
      <div v-if="inc.evidencias.length" class="flex flex-wrap gap-2">
        <a
          v-for="ev in inc.evidencias"
          :key="ev.id"
          :href="evidenciaUrls[ev.id] ?? '#'"
          target="_blank"
          class="w-16 h-16 rounded-xl overflow-hidden border border-[#E3E7E4] block flex-shrink-0"
        >
          <img
            v-if="ev.tipo_archivo?.startsWith('image')"
            :src="evidenciaUrls[ev.id]"
            :alt="ev.nombre_original ?? 'evidencia'"
            class="w-full h-full object-cover"
          />
          <div v-else class="w-full h-full flex items-center justify-center bg-[#F4F6F4] text-[#5B6660] text-[11px] text-center px-1">
            <i class="pi pi-file-pdf text-lg"></i>
          </div>
        </a>
      </div>
      <p v-else class="text-[13px] text-[#8A948E] m-0">Sin archivos adjuntos.</p>
    </div>

    <!-- Descargo del equipo -->
    <div class="px-5 pt-4">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Descargo del equipo</span>
      <p v-if="inc.justificacion_grupal" class="text-[13px] text-[#3A4540] leading-relaxed m-0">{{ inc.justificacion_grupal }}</p>
      <p v-else class="text-[13px] text-[#8A948E] m-0">Sin descargo registrado.</p>
    </div>

    <!-- Motivo de resolución -->
    <div v-if="inc.motivo_resolucion" class="px-5 pt-3">
      <span class="text-[11px] font-semibold text-[#5B6660] uppercase tracking-wide block mb-1.5">Motivo de resolución</span>
      <p class="text-[13px] text-[#3A4540] leading-relaxed m-0">{{ inc.motivo_resolucion }}</p>
    </div>

    <!-- Admin: validar / rechazar -->
    <div v-if="esAdmin && (inc.estado === 'registrado' || inc.estado === 'descargo')" class="px-5 pt-5 pb-5 mt-auto flex-shrink-0">
      <div class="bg-[#FFF8EA] border border-[#F3DDAE] rounded-xl p-3 mb-4">
        <p class="text-[12px] text-[#7A4F00] m-0 leading-relaxed">
          Solo el administrador valida o rechaza. Antes de validar, escucha al equipo.
        </p>
      </div>

      <!-- Inline rechazar form -->
      <div v-if="mostrarRechazar" class="flex flex-col gap-2 mb-3">
        <label class="text-[12px] font-semibold text-[#5B6660]">Motivo del rechazo <span class="text-[#A3261F]">*</span></label>
        <textarea
          v-model="motivoRechazo"
          rows="3"
          placeholder="Explica por qué se rechaza esta incidencia…"
          class="w-full px-3 py-2 text-[14px] border border-[#DCE1DD] rounded-xl resize-none focus:outline-none focus:border-[#0E7C59] focus:ring-2 focus:ring-[#E1F3EA] font-[inherit]"
        />
        <div class="flex gap-2">
          <button
            class="flex-1 h-10 rounded-xl border border-[#DCE1DD] text-[14px] font-semibold text-[#5B6660] bg-white font-[inherit]"
            @click="mostrarRechazar = false; motivoRechazo = ''"
          >Cancelar</button>
          <button
            class="flex-1 h-10 rounded-xl text-[14px] font-semibold text-white bg-[#A3261F] disabled:opacity-50 font-[inherit]"
            :disabled="!motivoRechazo.trim() || cargandoValidacion"
            @click="confirmarRechazo"
          >Rechazar</button>
        </div>
      </div>

      <div v-else class="flex gap-3">
        <button
          class="flex-1 h-11 rounded-xl border border-[#A3261F] text-[14px] font-semibold text-[#A3261F] bg-white hover:bg-[#FDECEC] transition-colors font-[inherit]"
          :disabled="cargandoValidacion"
          @click="mostrarRechazar = true"
        >Rechazar</button>
        <button
          class="flex-1 h-11 rounded-xl text-[14px] font-semibold text-white bg-[#0E7C59] hover:bg-[#0B6B4B] transition-colors font-[inherit] disabled:opacity-50"
          :disabled="cargandoValidacion"
          @click="emit('validar', '')"
        >Validar incidencia</button>
      </div>
    </div>

    <!-- Spacer for non-admin -->
    <div v-else class="pb-6" />
  </div>
</template>
