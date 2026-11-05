<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<template>
  <RouterView />
  <Toast position="bottom-center" />
</template>

<style>
@import "tailwindcss";

@theme {
  --color-bad:    #A3261F;
  --color-bad-bg: #FDECEC;
}

/* ── Variables globales LiderCamp ─────────────────────────────── */
:root {
  /* Verde principal */
  --lc-green-50:  #f0fdf4;
  --lc-green-100: #dcfce7;
  --lc-green-200: #bbf7d0;
  --lc-green-300: #86efac;
  --lc-green-400: #4ade80;
  --lc-green-500: #22c55e;
  --lc-green-600: #16a34a;
  --lc-green-700: #15803d;
  --lc-green-800: #166534;
  --lc-green-900: #14532d;

  /* Alias semánticos */
  --lc-primary:       var(--lc-green-600);
  --lc-primary-light: var(--lc-green-100);
  --lc-primary-dark:  var(--lc-green-700);
  --lc-primary-hover: var(--lc-green-700);
  --lc-accent:        var(--lc-green-500);

  /* Neutros */
  --lc-bg:         #f8fafc;
  --lc-surface:    #ffffff;
  --lc-border:     #e2e8f0;
  --lc-text:       #1e293b;
  --lc-text-muted: #64748b;
  --lc-text-light: #94a3b8;

  /* Feedback */
  --lc-success: var(--lc-green-600);
  --lc-warning: #d97706;
  --lc-danger:  #dc2626;
  --lc-info:    #2563eb;

  /* Tamaños mobile-first */
  --lc-touch:    44px;
  --lc-radius:   10px;
  --lc-radius-sm: 6px;
  --lc-shadow:   0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.04);
  --lc-shadow-md: 0 4px 6px -1px rgba(0,0,0,.07), 0 2px 4px -1px rgba(0,0,0,.04);
}

/* ── Reset base ───────────────────────────────────────────────── */
*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  -webkit-text-size-adjust: 100%;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  -webkit-font-smoothing: antialiased;
  font-size: 16px;
  color: var(--lc-text);
  background: var(--lc-bg);
}

a {
  text-decoration: none;
  color: inherit;
}

/* ── Utilitarios globales ─────────────────────────────────────── */
.lc-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: .02em;
}
.lc-badge--green  { background: var(--lc-green-100); color: var(--lc-green-700); }
.lc-badge--red    { background: #fee2e2; color: #b91c1c; }
.lc-badge--yellow { background: #fef9c3; color: #92400e; }
.lc-badge--gray   { background: #f1f5f9; color: #475569; }
.lc-badge--blue   { background: #dbeafe; color: #1d4ed8; }

/* Tarjeta base */
.lc-card {
  background: var(--lc-surface);
  border: 1px solid var(--lc-border);
  border-radius: var(--lc-radius);
  box-shadow: var(--lc-shadow);
}

/* Botón primario verde */
.lc-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: var(--lc-touch);
  padding: 0 18px;
  border: none;
  border-radius: var(--lc-radius-sm);
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  transition: background .15s, opacity .15s;
}
.lc-btn--primary { background: var(--lc-primary); color: #fff; }
.lc-btn--primary:hover { background: var(--lc-primary-hover); }
.lc-btn--ghost   { background: transparent; color: var(--lc-primary); border: 1.5px solid var(--lc-primary); }
.lc-btn--ghost:hover { background: var(--lc-primary-light); }
.lc-btn--danger  { background: var(--lc-danger); color: #fff; }
.lc-btn--danger:hover { background: #b91c1c; }
.lc-btn--sm      { min-height: 36px; padding: 0 12px; font-size: 0.85rem; }
.lc-btn:disabled { opacity: .5; cursor: not-allowed; }

/* Input base */
.lc-input {
  width: 100%;
  min-height: var(--lc-touch);
  padding: 0 12px;
  border: 1.5px solid var(--lc-border);
  border-radius: var(--lc-radius-sm);
  font-size: 0.95rem;
  color: var(--lc-text);
  background: var(--lc-surface);
  transition: border-color .15s;
  -webkit-appearance: none;
}
.lc-input:focus {
  outline: none;
  border-color: var(--lc-primary);
  box-shadow: 0 0 0 3px var(--lc-green-100);
}

/* Label */
.lc-label {
  display: block;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--lc-text-muted);
  margin-bottom: 5px;
  text-transform: uppercase;
  letter-spacing: .04em;
}

/* Separador de sección */
.lc-section-title {
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--lc-text-light);
  padding: 0 0 8px;
  border-bottom: 1px solid var(--lc-border);
  margin-bottom: 14px;
}

/* Vista vacía */
.lc-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 48px 24px;
  color: var(--lc-text-muted);
  text-align: center;
}
.lc-empty i { font-size: 2.2rem; color: var(--lc-text-light); }
.lc-empty p { margin: 0; font-size: 0.92rem; }

/* Scrollbar thin */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--lc-border); border-radius: 3px; }
</style>
