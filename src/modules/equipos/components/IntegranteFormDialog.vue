<script setup lang="ts">
import { ref, watch } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DatePicker from 'primevue/datepicker'
import Dialog from 'primevue/dialog'
import type { Integrante } from '@/modules/equipos/services/equipos.service'

const props = defineProps<{
  visible: boolean
  integrante: Integrante | null
  equipoId: string
}>()

const emit = defineEmits<{
  'update:visible': [val: boolean]
  guardar: [datos: Partial<Integrante>]
}>()

const form = ref({
  nombres: '', apellidos: '', codigo_universitario: '', dni: '',
  fecha_inscripcion: null as Date | null, observaciones: '',
})

function toDate(val: string | null): Date | null {
  return val ? new Date(val + 'T00:00:00') : null
}

watch(() => props.visible, (v) => {
  if (v && props.integrante) {
    const i = props.integrante
    form.value = {
      nombres: i.nombres, apellidos: i.apellidos,
      codigo_universitario: i.codigo_universitario ?? '',
      dni: i.dni ?? '',
      fecha_inscripcion: toDate(i.fecha_inscripcion),
      observaciones: i.observaciones ?? '',
    }
  } else if (v) {
    form.value = { nombres: '', apellidos: '', codigo_universitario: '', dni: '', fecha_inscripcion: null, observaciones: '' }
  }
})

function cerrar() { emit('update:visible', false) }
function guardar() {
  emit('guardar', {
    equipo_id: props.equipoId,
    nombres: form.value.nombres,
    apellidos: form.value.apellidos,
    codigo_universitario: form.value.codigo_universitario || null,
    dni: form.value.dni || null,
    fecha_inscripcion: form.value.fecha_inscripcion?.toISOString().slice(0, 10) ?? '',
    observaciones: form.value.observaciones || null,
  })
}
</script>

<template>
  <Dialog
    :visible="visible"
    :header="integrante ? 'Editar integrante' : 'Nuevo integrante'"
    modal
    :style="{ width: '95vw', maxWidth: '30rem' }"
    @update:visible="cerrar"
  >
    <div class="integrante-form">
      <div class="form-grid">
        <div class="field">
          <label>Nombres</label>
          <InputText v-model="form.nombres" fluid />
        </div>
        <div class="field">
          <label>Apellidos</label>
          <InputText v-model="form.apellidos" fluid />
        </div>
        <div class="field">
          <label>Código universitario</label>
          <InputText v-model="form.codigo_universitario" fluid />
        </div>
        <div class="field">
          <label>DNI</label>
          <InputText v-model="form.dni" fluid />
        </div>
        <div class="field">
          <label>Fecha de inscripción</label>
          <DatePicker v-model="form.fecha_inscripcion" date-format="dd/mm/yy" fluid />
        </div>
      </div>
      <div class="field">
        <label>Observaciones</label>
        <InputText v-model="form.observaciones" fluid />
      </div>
    </div>

    <template #footer>
      <Button label="Cancelar" severity="secondary" text @click="cerrar" />
      <Button label="Guardar" icon="pi pi-save" @click="guardar" />
    </template>
  </Dialog>
</template>

<style scoped>
.integrante-form { display: flex; flex-direction: column; gap: 0.75rem; padding: 0.5rem 0; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.field { display: flex; flex-direction: column; gap: 0.4rem; }
.field label { font-size: 0.875rem; font-weight: 500; }
@media (max-width: 480px) { .form-grid { grid-template-columns: 1fr; } }
</style>
