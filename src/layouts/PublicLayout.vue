<script setup lang="ts">
import { RouterLink, RouterView, useRoute } from 'vue-router'

const route = useRoute()
</script>

<template>
  <div class="pub-layout">

    <header class="pub-header">
      <RouterLink to="/" class="pub-header__brand">
        <span class="pub-header__icon">🏕</span>
        <span class="pub-header__name">LiderCamp</span>
        <span class="pub-header__ed">2026-II</span>
      </RouterLink>

      <nav class="pub-header__nav">
        <RouterLink to="/ranking"    class="pub-nav-link" :class="{ active: route.path === '/ranking' }">
          <i class="pi pi-trophy" /> Ranking
        </RouterLink>
        <RouterLink to="/calendario" class="pub-nav-link" :class="{ active: route.path === '/calendario' }">
          <i class="pi pi-calendar" /> Calendario
        </RouterLink>
        <RouterLink to="/reglas"     class="pub-nav-link" :class="{ active: route.path === '/reglas' }">
          <i class="pi pi-book" /> Reglas
        </RouterLink>
      </nav>

      <RouterLink to="/login" class="pub-header__login">
        <i class="pi pi-sign-in" />
        <span>Ingresar</span>
      </RouterLink>
    </header>

    <main class="pub-main">
      <RouterView />
    </main>

    <footer class="pub-footer">
      <div class="pub-footer__inner">
        <span class="pub-footer__brand">🏕 LiderCamp 2026-II</span>
        <nav class="pub-footer__links">
          <RouterLink to="/ranking">Ranking</RouterLink>
          <RouterLink to="/calendario">Calendario</RouterLink>
          <RouterLink to="/reglas">Reglas</RouterLink>
        </nav>
        <span class="pub-footer__copy">Sistema de evaluación universitaria</span>
      </div>
    </footer>

  </div>
</template>

<style scoped>
.pub-layout {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  background: #f8fafc;
}

/* ─── Header ─── */
.pub-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  padding: 0 1.25rem;
  background: #059669;
  color: #fff;
  position: sticky;
  top: 0;
  z-index: 200;
  gap: 1rem;
  box-shadow: 0 2px 8px rgba(5,150,105,0.35);
}

.pub-header__brand {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  text-decoration: none;
  flex-shrink: 0;
}
.pub-header__icon { font-size: 1.3rem; line-height: 1; }
.pub-header__name {
  font-size: 1.05rem;
  font-weight: 800;
  color: #fff;
  letter-spacing: -0.02em;
}
.pub-header__ed {
  font-size: 0.68rem;
  color: rgba(255,255,255,0.6);
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  margin-top: 1px;
  display: none;
}

.pub-header__nav {
  display: none;
  align-items: center;
  gap: 0.25rem;
  flex: 1;
  justify-content: center;
}
.pub-nav-link {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.45rem 0.85rem;
  border-radius: 8px;
  font-size: 0.88rem;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
  text-decoration: none;
  transition: background 0.15s, color 0.15s;
  white-space: nowrap;
}
.pub-nav-link i { font-size: 0.82rem; }
.pub-nav-link:hover { background: rgba(255,255,255,0.15); color: #fff; }
.pub-nav-link.active { background: rgba(255,255,255,0.20); color: #fff; }

.pub-header__login {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0 1rem;
  height: 36px;
  border-radius: 8px;
  background: #fff;
  color: #059669;
  font-size: 0.88rem;
  font-weight: 700;
  text-decoration: none;
  transition: background 0.15s, transform 0.12s;
  flex-shrink: 0;
  white-space: nowrap;
}
.pub-header__login i { font-size: 0.85rem; }
.pub-header__login:hover { background: #ecfdf5; transform: translateY(-1px); }

/* ─── Main ─── */
.pub-main { flex: 1; }

/* ─── Footer ─── */
.pub-footer {
  background: #047857;
  padding: 1.5rem 1.25rem;
}
.pub-footer__inner {
  max-width: 960px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  text-align: center;
}
.pub-footer__brand {
  font-size: 0.95rem;
  font-weight: 700;
  color: #fff;
}
.pub-footer__links {
  display: flex;
  gap: 1rem;
}
.pub-footer__links a {
  font-size: 0.82rem;
  color: rgba(255,255,255,0.65);
  text-decoration: none;
  transition: color 0.14s;
}
.pub-footer__links a:hover { color: #fff; }
.pub-footer__copy {
  font-size: 0.75rem;
  color: rgba(255,255,255,0.40);
}

/* ─── Tablet + ─── */
@media (min-width: 640px) {
  .pub-header__nav { display: flex; }
  .pub-header__ed  { display: inline; }
  .pub-footer__inner { flex-direction: row; justify-content: space-between; text-align: left; }
}
</style>
