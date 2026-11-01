<script setup lang="ts">
import { ref, watch } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Dialog from 'primevue/dialog'
import type { Equipo } from '@/modules/equipos/services/equipos.service'

const props = defineProps<{
  visible: boolean
  equipo: Equipo | null
}>()

const emit = defineEmits<{
  'update:visible': [val: boolean]
  guardar: [datos: { nombre: string; escuela_profesional: string; color: string }]
}>()

const form = ref({ nombre: '', escuela_profesional: '', color: '#3B82F6' })

watch(() => props.visible, (v) => {
  if (v) {
    form.value = props.equipo
      ? { nombre: props.equipo.nombre, escuela_profesional: props.equipo.escuela_profesional, color: props.equipo.color }
      : { nombre: '', escuela_profesional: '', color: '#3B82F6' }
  }
})

function cerrar() { emit('update:visible', false) }
function guardar() { emit('guardar', { ...form.value }) }
</script>

<template>
  <Dialog
    :visible="visible"
    :header="equipo ? 'Editar equipo' : 'Nuevo equipo'"
    modal
    :style="{ width: '95vw', maxWidth: '28rem' }"
    @update:visible="cerrar"
  >
    <div class="equipo-form">
      <div class="field">
        <label>Nombre del equipo</label>
        <InputText v-model="form.nombre" placeholder="Equipo Alfa" fluid />
      </div>
      <div class="field">
        <label>Escuela profesional</label>
        <InputText v-model="form.escuela_profesional" placeholder="Ingeniería de Sistemas" fluid />
      </div>
      <div class="field">
        <label>Color</label>
        <div class="color-row">
          <input type="color" v-model="form.color" class="color-picker" />
          <InputText v-model="form.color" placeholder="#3B82F6" fluid />
        </div>
      </div>
    </div>

    <template #footer>
      <Button label="Cancelar" severity="secondary" text @click="cerrar" />
      <Button label="Guardar" icon="pi pi-save" @click="guardar" />
    </template>
  </Dialog>
</template>

<style scoped>
.equipo-form { display: flex; flex-direction: column; gap: 1rem; padding: 0.5rem 0; }
.field { display: flex; flex-direction: column; gap: 0.4rem; }
.field label { font-size: 0.875rem; font-weight: 500; }
.color-row { display: flex; gap: 0.5rem; align-items: center; }
.color-picker { width: 2.5rem; height: 2.5rem; border: none; border-radius: 6px; cursor: pointer; padding: 2px; }
</style>
