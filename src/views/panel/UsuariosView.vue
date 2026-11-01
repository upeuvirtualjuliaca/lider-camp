<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useToast } from 'primevue/usetoast'
import { perfilesService, type Perfil, type CrearUsuarioPayload } from '@/modules/auth/services/perfiles.service'

const toast = useToast()

// ── Estado ───────────────────────────────────────────────────────────────────
const perfiles = ref<Perfil[]>([])
const cargando = ref(true)
const busqueda = ref('')

// ── Formulario nuevo usuario ─────────────────────────────────────────────────
const mostrarFormNuevo = ref(false)
const guardandoNuevo   = ref(false)
const verPwNuevo       = ref(false)
const formNuevo = ref<CrearUsuarioPayload>({
  nombre_completo: '',
  email:           '',
  password:        '',
  rol:             'evaluador',
})

// ── Reset contraseña ─────────────────────────────────────────────────────────
const perfilReset    = ref<Perfil | null>(null)
const enviandoReset  = ref(false)

// ── Filtro ───────────────────────────────────────────────────────────────────
const perfilesFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  if (!q) return perfiles.value
  return perfiles.value.filter(
    (p) => p.nombre_completo.toLowerCase().includes(q) || p.email.toLowerCase().includes(q)
  )
})

const totalActivos = computed(() => perfiles.value.filter((p) => p.activo).length)

// ── Cargar ───────────────────────────────────────────────────────────────────
async function cargar() {
  cargando.value = true
  try { perfiles.value = await perfilesService.getTodos() }
  catch { toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudieron cargar los usuarios.', life: 4000 }) }
  finally { cargando.value = false }
}

// ── Crear usuario ─────────────────────────────────────────────────────────────
function abrirFormNuevo() {
  formNuevo.value = { nombre_completo: '', email: '', password: '', rol: 'evaluador' }
  verPwNuevo.value = false
  mostrarFormNuevo.value = true
}

async function crearUsuario() {
  const f = formNuevo.value
  if (!f.nombre_completo.trim() || !f.email.trim() || !f.password.trim()) {
    toast.add({ severity: 'warn', summary: 'Campos requeridos', detail: 'Completa nombre, email y contraseña.', life: 4000 })
    return
  }
  if (f.password.length < 6) {
    toast.add({ severity: 'warn', summary: 'Contraseña corta', detail: 'Mínimo 6 caracteres.', life: 4000 })
    return
  }
  guardandoNuevo.value = true
  try {
    await perfilesService.crearUsuario(f)
    toast.add({ severity: 'success', summary: 'Usuario creado', detail: `${f.nombre_completo} fue creado correctamente.`, life: 4000 })
    mostrarFormNuevo.value = false
    await cargar()
  } catch (e: unknown) {
    toast.add({ severity: 'error', summary: 'Error', detail: e instanceof Error ? e.message : 'Error al crear usuario', life: 5000 })
  } finally {
    guardandoNuevo.value = false
  }
}

// ── Cambiar rol ───────────────────────────────────────────────────────────────
async function cambiarRol(perfil: Perfil, nuevoRol: string) {
  try {
    const actualizado = await perfilesService.actualizar(perfil.id, { rol: nuevoRol })
    const idx = perfiles.value.findIndex((p) => p.id === perfil.id)
    if (idx !== -1) perfiles.value[idx] = actualizado
    toast.add({ severity: 'success', summary: 'Guardado', detail: 'Rol actualizado.', life: 3000 })
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cambiar el rol.', life: 4000 })
    await cargar()
  }
}

// ── Cambiar activo ────────────────────────────────────────────────────────────
async function cambiarActivo(perfil: Perfil, valor: boolean) {
  try {
    const actualizado = await perfilesService.actualizar(perfil.id, { activo: valor })
    const idx = perfiles.value.findIndex((p) => p.id === perfil.id)
    if (idx !== -1) perfiles.value[idx] = actualizado
    toast.add({ severity: valor ? 'success' : 'warn', summary: 'Guardado', detail: `Usuario ${valor ? 'activado' : 'desactivado'}.`, life: 3000 })
  } catch {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo cambiar el estado.', life: 4000 })
    await cargar()
  }
}

// ── Reset contraseña ──────────────────────────────────────────────────────────
async function enviarReset(perfil: Perfil) {
  perfilReset.value  = perfil
  enviandoReset.value = true
  try {
    await perfilesService.enviarResetPassword(perfil.email)
    toast.add({ severity: 'success', summary: 'Email enviado', detail: `Se envió el link de recuperación a ${perfil.email}.`, life: 5000 })
  } catch (e: unknown) {
    toast.add({ severity: 'error', summary: 'Error', detail: e instanceof Error ? e.message : 'Error al enviar email', life: 5000 })
  } finally {
    enviandoReset.value = false
    perfilReset.value   = null
  }
}

// ── Utilidades ────────────────────────────────────────────────────────────────
function iniciales(nombre: string) {
  return nombre.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase()
}

const avatarColors: Record<string, string> = {
  A:'bg-violet-100 text-violet-700', B:'bg-sky-100 text-sky-700',
  C:'bg-amber-100 text-amber-700',   D:'bg-rose-100 text-rose-700',
  E:'bg-teal-100 text-teal-700',     F:'bg-indigo-100 text-indigo-700',
  G:'bg-orange-100 text-orange-700', H:'bg-pink-100 text-pink-700',
  I:'bg-cyan-100 text-cyan-700',     J:'bg-lime-100 text-lime-700',
  K:'bg-purple-100 text-purple-700', L:'bg-emerald-100 text-emerald-700',
  M:'bg-blue-100 text-blue-700',     N:'bg-yellow-100 text-yellow-700',
  O:'bg-red-100 text-red-700',       P:'bg-fuchsia-100 text-fuchsia-700',
  Q:'bg-green-100 text-green-700',   R:'bg-sky-100 text-sky-700',
  S:'bg-teal-100 text-teal-700',     T:'bg-violet-100 text-violet-700',
  U:'bg-amber-100 text-amber-700',   V:'bg-emerald-100 text-emerald-700',
  W:'bg-indigo-100 text-indigo-700', X:'bg-rose-100 text-rose-700',
  Y:'bg-cyan-100 text-cyan-700',     Z:'bg-purple-100 text-purple-700',
}
function avatarColor(nombre: string) {
  const l = nombre[0]?.toUpperCase() ?? 'A'
  return avatarColors[l] ?? 'bg-green-100 text-green-700'
}

onMounted(cargar)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-4xl mx-auto px-4 py-6 sm:px-6 sm:py-8">

      <!-- ─── Cabecera ─── -->
      <div class="flex flex-col gap-4 mb-6 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Gestión de usuarios</h1>
          <p class="mt-1 text-sm text-slate-500">
            <span class="font-semibold text-green-700">{{ totalActivos }}</span> activos ·
            <span class="font-semibold text-slate-600">{{ perfiles.length }}</span> en total
          </p>
        </div>
        <button
          class="inline-flex items-center justify-center gap-2 px-5 h-11 bg-green-600 hover:bg-green-700 active:bg-green-800 text-white font-semibold rounded-xl shadow-sm transition-colors duration-150 cursor-pointer"
          @click="abrirFormNuevo"
        >
          <i class="pi pi-user-plus text-sm" />
          Nuevo usuario
        </button>
      </div>

      <!-- ─── Buscador ─── -->
      <div class="relative mb-5">
        <i class="pi pi-search absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none" />
        <input
          v-model="busqueda"
          type="search"
          placeholder="Buscar por nombre o correo electrónico…"
          class="w-full h-11 pl-10 pr-4 bg-white border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 shadow-sm focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
        />
      </div>

      <!-- ─── Cargando ─── -->
      <div v-if="cargando" class="flex items-center justify-center gap-3 py-16 text-slate-400">
        <i class="pi pi-spin pi-spinner text-xl" />
        <span class="text-sm">Cargando usuarios…</span>
      </div>

      <!-- ─── Sin resultados ─── -->
      <div v-else-if="perfilesFiltrados.length === 0" class="flex flex-col items-center gap-3 py-16 text-slate-400">
        <div class="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center">
          <i class="pi pi-users text-2xl text-slate-300" />
        </div>
        <p class="text-sm">{{ busqueda ? `Sin resultados para "${busqueda}"` : 'No hay usuarios registrados.' }}</p>
      </div>

      <!-- ─── Grid de cards ─── -->
      <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div
          v-for="perfil in perfilesFiltrados"
          :key="perfil.id"
          class="bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md hover:border-green-100 transition-all duration-200 overflow-hidden"
        >
          <!-- Franja de color superior -->
          <div class="h-1.5 w-full" :class="perfil.activo ? 'bg-green-500' : 'bg-slate-200'" />

          <div class="p-4 flex flex-col gap-3">

            <!-- Avatar + info + badge -->
            <div class="flex items-start gap-3">
              <div
                class="flex-shrink-0 w-11 h-11 rounded-full flex items-center justify-center font-bold text-sm"
                :class="avatarColor(perfil.nombre_completo)"
              >
                {{ iniciales(perfil.nombre_completo) }}
              </div>
              <div class="flex-1 min-w-0 pt-0.5">
                <p class="font-semibold text-slate-800 text-sm leading-snug truncate">{{ perfil.nombre_completo }}</p>
                <p class="text-xs text-slate-400 truncate mt-0.5">{{ perfil.email }}</p>
              </div>
              <!-- Badge estado -->
              <span
                class="flex-shrink-0 inline-flex items-center gap-1.5 text-[11px] font-semibold px-2.5 py-1 rounded-full"
                :class="perfil.activo
                  ? 'bg-green-50 text-green-700 ring-1 ring-green-200'
                  : 'bg-slate-100 text-slate-500 ring-1 ring-slate-200'"
              >
                <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :class="perfil.activo ? 'bg-green-500' : 'bg-slate-400'" />
                {{ perfil.activo ? 'Activo' : 'Inactivo' }}
              </span>
            </div>

            <!-- Separador -->
            <div class="border-t border-slate-50" />

            <!-- Controles -->
            <div class="flex items-center gap-2">

              <!-- Selector de rol -->
              <div class="flex-1">
                <label class="block text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Rol</label>
                <select
                  class="w-full h-9 px-3 bg-slate-50 border border-slate-200 rounded-lg text-xs font-semibold text-slate-700 cursor-pointer focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                  :value="perfil.rol"
                  @change="(e) => cambiarRol(perfil, (e.target as HTMLSelectElement).value)"
                >
                  <option value="evaluador">Evaluador</option>
                  <option value="admin">Admin</option>
                </select>
              </div>

              <!-- Toggle activo — implementado con <label>+<input> para fiabilidad cross-browser -->
              <div class="flex flex-col items-center gap-1">
                <label class="block text-[10px] font-bold text-slate-400 uppercase tracking-widest">Estado</label>
                <label class="toggle-wrap cursor-pointer" :title="perfil.activo ? 'Desactivar' : 'Activar'">
                  <input
                    type="checkbox"
                    class="sr-only"
                    :checked="perfil.activo"
                    @change="cambiarActivo(perfil, !perfil.activo)"
                  />
                  <span
                    class="toggle-track"
                    :class="perfil.activo ? 'bg-green-500' : 'bg-slate-300'"
                  >
                    <span
                      class="toggle-thumb"
                      :class="perfil.activo ? 'translate-x-5' : 'translate-x-0'"
                    />
                  </span>
                </label>
              </div>

              <!-- Botón reset contraseña -->
              <button
                class="flex items-center gap-1.5 h-9 px-3 rounded-lg border border-slate-200 bg-slate-50 text-slate-600 text-xs font-semibold hover:bg-green-50 hover:border-green-200 hover:text-green-700 transition-colors duration-150 cursor-pointer ml-auto"
                :disabled="enviandoReset && perfilReset?.id === perfil.id"
                :title="`Enviar email de recuperación a ${perfil.email}`"
                @click="enviarReset(perfil)"
              >
                <i class="pi pi-key text-xs" />
                <span>Reset pw</span>
              </button>

            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ══════════════════════════════════════════════════════
         MODAL: Nuevo usuario
    ═══════════════════════════════════════════════════════ -->
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div v-if="mostrarFormNuevo" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:p-4">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="mostrarFormNuevo = false" />

        <div class="relative w-full sm:max-w-md bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90dvh]">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
            <div>
              <h2 class="text-base font-bold text-slate-800">Nuevo usuario</h2>
              <p class="text-xs text-slate-400 mt-0.5">Completa los datos para crear la cuenta</p>
            </div>
            <button class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 transition-colors" @click="mostrarFormNuevo = false">
              <i class="pi pi-times text-sm" />
            </button>
          </div>

          <!-- Body -->
          <div class="overflow-y-auto px-6 py-5 flex flex-col gap-4">

            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nombre completo</label>
              <input
                v-model="formNuevo.nombre_completo"
                type="text"
                placeholder="Ej. Juan Pérez"
                class="w-full h-11 px-3.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                autocomplete="off"
              />
            </div>

            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Correo electrónico</label>
              <input
                v-model="formNuevo.email"
                type="email"
                placeholder="juan@ejemplo.com"
                class="w-full h-11 px-3.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                autocomplete="off"
              />
            </div>

            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Contraseña inicial</label>
              <div class="relative">
                <input
                  v-model="formNuevo.password"
                  :type="verPwNuevo ? 'text' : 'password'"
                  placeholder="Mínimo 6 caracteres"
                  class="w-full h-11 pl-3.5 pr-11 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition"
                  autocomplete="new-password"
                />
                <button
                  type="button"
                  class="absolute right-0 top-0 h-full w-11 flex items-center justify-center text-slate-400 hover:text-slate-600 transition-colors"
                  @click="verPwNuevo = !verPwNuevo"
                >
                  <i :class="verPwNuevo ? 'pi pi-eye-slash' : 'pi pi-eye'" class="text-sm" />
                </button>
              </div>
            </div>

            <!-- Selector de rol visual -->
            <div class="flex flex-col gap-2">
              <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Rol</label>
              <div class="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  class="flex flex-col items-center gap-1.5 py-3.5 rounded-xl border-2 transition-all duration-150 cursor-pointer"
                  :class="formNuevo.rol === 'evaluador'
                    ? 'border-green-500 bg-green-50 text-green-700'
                    : 'border-slate-200 bg-white text-slate-500 hover:border-slate-300'"
                  @click="formNuevo.rol = 'evaluador'"
                >
                  <i class="pi pi-star text-xl" />
                  <span class="text-xs font-semibold">Evaluador</span>
                  <span class="text-[10px] text-center leading-tight px-2 opacity-70">Registra observaciones</span>
                </button>
                <button
                  type="button"
                  class="flex flex-col items-center gap-1.5 py-3.5 rounded-xl border-2 transition-all duration-150 cursor-pointer"
                  :class="formNuevo.rol === 'admin'
                    ? 'border-green-500 bg-green-50 text-green-700'
                    : 'border-slate-200 bg-white text-slate-500 hover:border-slate-300'"
                  @click="formNuevo.rol = 'admin'"
                >
                  <i class="pi pi-shield text-xl" />
                  <span class="text-xs font-semibold">Administrador</span>
                  <span class="text-[10px] text-center leading-tight px-2 opacity-70">Acceso completo</span>
                </button>
              </div>
            </div>

          </div>

          <!-- Footer -->
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3">
            <button
              class="flex-1 h-11 rounded-xl border border-slate-200 text-slate-500 font-semibold text-sm hover:bg-slate-50 transition-colors"
              @click="mostrarFormNuevo = false"
            >
              Cancelar
            </button>
            <button
              class="flex-[2] h-11 rounded-xl bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold text-sm flex items-center justify-center gap-2 transition-colors"
              :disabled="guardandoNuevo"
              @click="crearUsuario"
            >
              <i v-if="guardandoNuevo" class="pi pi-spin pi-spinner" />
              <i v-else class="pi pi-check" />
              {{ guardandoNuevo ? 'Creando…' : 'Crear usuario' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<style scoped>
/* Toggle switch — label+checkbox para compatibilidad cross-browser */
.toggle-wrap { display: inline-flex; align-items: center; }

.toggle-track {
  display: block;
  width: 44px;
  height: 24px;
  border-radius: 999px;
  padding: 2px;
  transition: background-color 0.2s;
}

.toggle-thumb {
  display: block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: white;
  box-shadow: 0 1px 4px rgba(0,0,0,0.25);
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}
</style>
