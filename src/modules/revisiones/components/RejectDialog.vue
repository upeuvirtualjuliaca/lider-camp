<script setup lang="ts">
import { ref, watch } from 'vue'

const props = defineProps<{ open: boolean; accionando: boolean }>()
const emit  = defineEmits<{ confirm: [motivo: string]; cancel: [] }>()

const motivo = ref('')
const error  = ref('')

watch(() => props.open, (v) => { if (v) { motivo.value = ''; error.value = '' } })

function confirmar() {
  if (!motivo.value.trim()) { error.value = 'El motivo es obligatorio'; return }
  error.value = ''
  emit('confirm', motivo.value.trim())
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      leave-active-class="transition-opacity duration-150"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 z-[200] bg-black/40 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click.self="emit('cancel')"
      >
        <div class="w-full sm:max-w-md bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl flex flex-col overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between px-5 pt-5 pb-3">
            <span class="text-[17px] font-bold">Rechazar incidencia</span>
            <button class="w-8 h-8 flex items-center justify-center rounded-lg text-[#5B6660] hover:bg-[#F4F6F4]" @click="emit('cancel')" aria-label="Cerrar">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
          </div>

          <!-- Body -->
          <div class="px-5 pb-2 flex flex-col gap-3">
            <p class="text-[14px] text-[#5B6660] m-0">Explica el motivo del rechazo. Quedará visible para el equipo evaluador.</p>
            <label class="flex flex-col gap-1.5">
              <span class="text-[13px] font-semibold text-[#16201B]">Motivo <span class="text-[#A3261F]">*</span></span>
              <textarea
                v-model="motivo"
                rows="3"
                placeholder="Describe el motivo del rechazo…"
                class="border border-[#DCE1DD] rounded-xl px-3 py-2.5 text-[15px] resize-y bg-white outline-none focus:border-[#A3261F] focus:ring-2 focus:ring-[#A3261F]/20"
                style="font-family: inherit"
                :disabled="accionando"
              />
            </label>
            <p v-if="error" class="text-[13px] text-[#A3261F] -mt-2">{{ error }}</p>
          </div>

          <!-- Footer -->
          <div class="flex gap-2.5 px-5 py-4">
            <button
              class="flex-1 h-12 rounded-[14px] border border-[#DCE1DD] bg-white text-[15px] font-semibold text-[#16201B] hover:bg-[#F4F6F4] transition-colors"
              @click="emit('cancel')"
              :disabled="accionando"
            >Cancelar</button>
            <button
              class="flex-[2] h-12 rounded-[14px] bg-[#A3261F] hover:bg-[#8B1E1A] text-white text-[15px] font-semibold transition-colors disabled:opacity-50"
              :disabled="accionando"
              @click="confirmar"
            >{{ accionando ? 'Guardando…' : 'Confirmar rechazo' }}</button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
