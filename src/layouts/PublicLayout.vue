<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink, RouterView } from 'vue-router'

const menuAbierto = ref(false)

const navLinks = [
  { to: '/ranking',    label: 'Ranking' },
  { to: '/calendario', label: 'Calendario' },
  { to: '/reglas',     label: 'Reglas' },
]
</script>

<template>
  <div class="min-h-dvh flex flex-col" style="background:#F4F6F4">

    <!-- ══ Header ════════════════════════════════════════════════════════ -->
    <header class="bg-white border-b border-[#E3E7E4] sticky top-0 z-50">
      <div class="max-w-[1200px] mx-auto px-4 md:px-6 h-16 flex items-center gap-3 md:gap-6">

        <!-- Logo -->
        <RouterLink to="/" class="flex items-center gap-2.5 mr-auto">
          <span
            class="w-[34px] h-[34px] rounded-[10px] flex items-center justify-center flex-shrink-0"
            style="background:#0E7C59" aria-hidden="true"
          >
            <svg width="19" height="19" viewBox="0 0 24 24" fill="none"
              stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 20h18L12 4 3 20z"/><path d="M10 20l2-4 2 4"/>
            </svg>
          </span>
          <span class="text-[17px] font-extrabold text-[#16201B]">
            LiderCamp&nbsp;<span class="font-medium text-[#5B6660]">2026-II</span>
          </span>
        </RouterLink>

        <!-- Nav desktop/tablet -->
        <nav aria-label="Secciones" class="hidden md:flex gap-1">
          <RouterLink
            v-for="link in navLinks" :key="link.to"
            :to="link.to"
            class="h-10 px-3.5 rounded-[10px] flex items-center text-sm font-semibold text-[#16201B] hover:bg-[#F4F6F4] transition-colors"
            exact-active-class="!bg-[#E1F3EA] !text-[#0B6B4B]"
          >{{ link.label }}</RouterLink>
        </nav>

        <!-- Botón ingresar -->
        <RouterLink
          to="/login"
          class="h-10 px-3.5 rounded-[10px] border border-[#DCE1DD] flex items-center text-sm font-semibold text-[#16201B] hover:bg-[#F4F6F4] transition-colors flex-shrink-0"
        >Ingresar</RouterLink>

        <!-- Hamburger mobile -->
        <button
          class="md:hidden w-11 h-11 flex items-center justify-center bg-transparent border-0 cursor-pointer text-[#16201B]"
          aria-label="Abrir menú"
          @click="menuAbierto = !menuAbierto"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <path d="M4 7h16M4 12h16M4 17h16"/>
          </svg>
        </button>
      </div>

      <!-- Drawer mobile -->
      <Transition name="slide">
        <div
          v-if="menuAbierto"
          class="md:hidden border-t border-[#E3E7E4] bg-white px-4 py-2 flex flex-col gap-1"
        >
          <RouterLink
            v-for="link in navLinks" :key="link.to"
            :to="link.to"
            class="h-11 px-3 rounded-[10px] flex items-center text-[15px] font-semibold text-[#16201B]"
            exact-active-class="!bg-[#E1F3EA] !text-[#0B6B4B]"
            @click="menuAbierto = false"
          >{{ link.label }}</RouterLink>
        </div>
      </Transition>
    </header>

    <!-- ══ Contenido ═════════════════════════════════════════════════════ -->
    <main class="flex-1">
      <RouterView />
    </main>

    <!-- ══ Footer ════════════════════════════════════════════════════════ -->
    <footer style="background:#10261D">
      <div class="max-w-[1200px] mx-auto px-4 md:px-6 py-6 flex justify-between items-center text-[13px]">
        <span class="font-bold text-white">LiderCamp 2026-II</span>
        <img
          :src="'/lider-camp/images/logo-upeu.svg'"
          alt="UPeU"
          class="h-9 w-auto opacity-75 brightness-0 invert"
        />
      </div>
    </footer>

  </div>
</template>

<style scoped>
.slide-enter-active,
.slide-leave-active {
  transition: max-height .2s ease, opacity .2s ease;
  overflow: hidden;
  max-height: 220px;
}
.slide-enter-from,
.slide-leave-to {
  max-height: 0;
  opacity: 0;
}
</style>
