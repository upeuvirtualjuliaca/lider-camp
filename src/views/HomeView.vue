<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import { publicoService, type PublicoCampamento } from '@/modules/criterios/services/criterios.service'

// ── Campamentos activos ───────────────────────────────────────────────────────
const campamentos = ref<PublicoCampamento[]>([])
const cargando    = ref(true)

onMounted(async () => {
  try { campamentos.value = await publicoService.getCampamentosActivos() }
  catch { /* silent — page degrades gracefully */ }
  finally { cargando.value = false }
})

// ── Carrusel ─────────────────────────────────────────────────────────────────
const slides = [
  {
    img: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&w=1200&q=80',
    quote: 'Cada criterio, cada punto, cada momento cuenta.',
    tag: 'Evaluación',
  },
  {
    img: 'https://images.unsplash.com/photo-1478131143081-80a7f70f23aa?auto=format&fit=crop&w=1200&q=80',
    quote: 'El liderazgo no se declara, se demuestra día a día.',
    tag: 'Liderazgo',
  },
  {
    img: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80',
    quote: 'Trabaja en equipo, compite con honor, lidera con propósito.',
    tag: 'Comunidad',
  },
]

const currentSlide = ref(0)
let timer: ReturnType<typeof setInterval> | null = null

function goToSlide(i: number) {
  currentSlide.value = i
  resetTimer()
}
function nextSlide() { currentSlide.value = (currentSlide.value + 1) % slides.length }
function resetTimer() {
  if (timer) clearInterval(timer)
  timer = setInterval(nextSlide, 5000)
}

onMounted(resetTimer)
onUnmounted(() => { if (timer) clearInterval(timer) })

// ── Touch swipe ───────────────────────────────────────────────────────────────
let touchX = 0
function onTouchStart(e: TouchEvent) { touchX = e.touches[0]?.clientX ?? 0 }
function onTouchEnd(e: TouchEvent) {
  const diff = touchX - (e.changedTouches[0]?.clientX ?? 0)
  if (Math.abs(diff) > 40) {
    currentSlide.value = diff > 0
      ? (currentSlide.value + 1) % slides.length
      : (currentSlide.value - 1 + slides.length) % slides.length
    resetTimer()
  }
}

// ── Highlights ────────────────────────────────────────────────────────────────
const highlights = [
  { icon: 'pi pi-trophy',   label: 'Ranking',     desc: 'Posiciones en tiempo real',    to: '/ranking',    color: '#f59e0b', bg: '#fef3c7' },
  { icon: 'pi pi-calendar', label: 'Calendario',  desc: 'Criterios por día y campamento', to: '/calendario', color: '#2563eb', bg: '#dbeafe' },
  { icon: 'pi pi-book',     label: 'Reglas',      desc: 'Puntaje, medallas y deméritos', to: '/reglas',     color: '#059669', bg: '#d1fae5' },
]

const edicionParts = computed(() => {
  const ed = campamentos.value[0]?.edicion ?? ''
  const idx = ed.indexOf(' ')
  if (idx === -1) return { main: ed, rest: '' }
  return { main: ed.slice(0, idx), rest: ed.slice(idx) }
})

const stats = [
  { num: '4',    label: 'Días de campamento', icon: '🌅' },
  { num: '16+',  label: 'Criterios evaluados', icon: '📋' },
  { num: '1000', label: 'Puntos en escala',    icon: '🏆' },
  { num: '4',    label: 'Tipos de medalla',    icon: '🎖' },
]
</script>

<template>
  <div class="home">

    <!-- ══════════════════════════════════════════
         HERO
    ══════════════════════════════════════════ -->
    <section class="hero">
      <video
        class="hero__video"
        :src="'/lider-camp/videos/hero.mp4'"
        autoplay
        muted
        loop
        playsinline
      />
      <div class="hero__overlay" />
      <div class="hero__content">
        <!-- <div class="hero__tag">
          <i class="pi pi-star-fill" /> Sistema de evaluación
        </div> -->
        <h1 class="hero__title">
          <span class="hero__title-camp">🏕</span>
          LiderCamp
        </h1>
        <div v-if="campamentos[0]?.edicion" class="hero__edicion-wrap">
          <span class="hero__edicion-deco" />
          <span class="hero__edicion">
            <span class="hero__edicion-main">{{ edicionParts.main }}</span><span class="hero__edicion-rest">{{ edicionParts.rest }}</span>
          </span>
          <span class="hero__comet" aria-hidden="true" />
        </div>
        <p class="hero__sub">
          Evalúa criterios, registra liderazgo,<br>
          compite con honor y construye comunidad.
        </p>
        <div class="hero__actions">
          <RouterLink to="/ranking" class="hero__btn hero__btn--primary">
            <i class="pi pi-trophy" /> Ver Ranking
          </RouterLink>
          <RouterLink to="/reglas" class="hero__btn hero__btn--ghost">
            <i class="pi pi-book" /> Conocer Reglas
          </RouterLink>
        </div>
      </div>
      <div class="hero__scroll-hint">
        <i class="pi pi-chevron-down" />
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CAMPAMENTOS ACTIVOS
    ══════════════════════════════════════════ -->
    <section class="section section--camps">
      <div class="section__container">
        <div class="section__head">
          <span class="section__chip">En curso</span>
          <h2 class="section__title">Campamentos activos</h2>
          <p class="section__desc">Accede al ranking, calendario y reglas de cada campamento.</p>
        </div>

        <!-- Cargando -->
        <div v-if="cargando" class="camps-skeleton">
          <div class="camp-skeleton" v-for="i in 2" :key="i" />
        </div>

        <!-- Sin campamentos -->
        <div v-else-if="campamentos.length === 0" class="camps-empty">
          <span class="camps-empty__icon">🏕</span>
          <p>No hay campamentos activos en este momento.</p>
        </div>

        <!-- Cards de campamentos -->
        <div v-else class="camps-grid">
          <div v-for="c in campamentos" :key="c.id" class="camp-card">
            <div class="camp-card__header">
              <div class="camp-card__emoji">🏕</div>
              <div class="camp-card__info">
                <h3 class="camp-card__name">{{ c.nombre }}</h3>
                <span class="camp-card__ed">Edición {{ c.edicion }}</span>
              </div>
              <span class="camp-card__badge">Activo</span>
            </div>
            <div class="camp-card__links">
              <RouterLink :to="`/ranking`" class="camp-link camp-link--gold">
                <i class="pi pi-trophy" />
                <span>Ranking</span>
                <i class="pi pi-arrow-right camp-link__arrow" />
              </RouterLink>
              <RouterLink :to="`/calendario`" class="camp-link camp-link--blue">
                <i class="pi pi-calendar" />
                <span>Calendario</span>
                <i class="pi pi-arrow-right camp-link__arrow" />
              </RouterLink>
              <RouterLink :to="`/reglas`" class="camp-link camp-link--green">
                <i class="pi pi-book" />
                <span>Reglas</span>
                <i class="pi pi-arrow-right camp-link__arrow" />
              </RouterLink>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         ACCESO RÁPIDO
    ══════════════════════════════════════════ -->
    <section class="section section--features">
      <div class="section__container">
        <div class="section__head">
          <span class="section__chip">Navegación rápida</span>
          <h2 class="section__title">¿Qué quieres ver?</h2>
        </div>
        <div class="features-grid">
          <RouterLink
            v-for="h in highlights" :key="h.to"
            :to="h.to"
            class="feature-card"
            :style="{ '--fc-color': h.color, '--fc-bg': h.bg }"
          >
            <div class="feature-card__icon-wrap">
              <i :class="h.icon" class="feature-card__icon" />
            </div>
            <div class="feature-card__body">
              <h3 class="feature-card__title">{{ h.label }}</h3>
              <p class="feature-card__desc">{{ h.desc }}</p>
            </div>
            <i class="pi pi-arrow-right feature-card__arrow" />
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CARRUSEL
    ══════════════════════════════════════════ -->
    <section class="carousel-section"
      @touchstart.passive="onTouchStart"
      @touchend.passive="onTouchEnd">
      <div class="carousel-track" :style="{ transform: `translateX(-${currentSlide * 100}%)` }">
        <div
          v-for="(s, i) in slides" :key="i"
          class="carousel-slide"
          :style="{ backgroundImage: `url(${s.img})` }"
        >
          <div class="carousel-slide__overlay" />
          <div class="carousel-slide__content">
            <span class="carousel-slide__tag">{{ s.tag }}</span>
            <blockquote class="carousel-slide__quote">"{{ s.quote }}"</blockquote>
          </div>
        </div>
      </div>
      <!-- Dots -->
      <div class="carousel-dots">
        <button
          v-for="(_, i) in slides" :key="i"
          :class="['carousel-dot', i === currentSlide && 'carousel-dot--active']"
          @click="goToSlide(i)"
          :aria-label="`Slide ${i + 1}`"
        />
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         STATS
    ══════════════════════════════════════════ -->
    <section class="section section--stats">
      <div class="section__container">
        <div class="stats-grid">
          <div v-for="s in stats" :key="s.label" class="stat-card">
            <span class="stat-card__emoji">{{ s.icon }}</span>
            <span class="stat-card__num">{{ s.num }}</span>
            <span class="stat-card__label">{{ s.label }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CÓMO FUNCIONA
    ══════════════════════════════════════════ -->
    <section class="section section--how">
      <div class="section__container">
        <div class="section__head">
          <span class="section__chip">El sistema</span>
          <h2 class="section__title">¿Cómo funciona LiderCamp?</h2>
          <p class="section__desc">Un proceso transparente de evaluación durante los 4 días del campamento.</p>
        </div>
        <div class="steps-grid">
          <div class="step">
            <div class="step__num">01</div>
            <h3 class="step__title">Criterios diarios</h3>
            <p class="step__desc">Carpas, orden, cocina, ceremonias y más. Cada criterio se evalúa con una rúbrica de 0 a 100.</p>
          </div>
          <div class="step">
            <div class="step__num">02</div>
            <h3 class="step__title">Liderazgo y asistencia</h3>
            <p class="step__desc">4 indicadores de liderazgo por día y control de asistencia con fórmula del 95 %.</p>
          </div>
          <div class="step">
            <div class="step__num">03</div>
            <h3 class="step__title">Bonus y deméritos</h3>
            <p class="step__desc">Servicio extraordinario suma puntos; infracciones como ruido o uso indebido de recursos los restan.</p>
          </div>
          <div class="step">
            <div class="step__num">04</div>
            <h3 class="step__title">Ranking en vivo</h3>
            <p class="step__desc">El puntaje se convierte a escala 1-1000. Oro, Plata, Bronce o Participación según el total.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CTA LOGIN
    ══════════════════════════════════════════ -->
    <section class="cta-section">
      <div class="cta-section__inner">
        <div class="cta-section__text">
          <h2 class="cta-section__title">¿Eres evaluador o administrador?</h2>
          <p class="cta-section__sub">Ingresa al panel para registrar evaluaciones, asistencia e incidencias.</p>
        </div>
        <RouterLink to="/login" class="cta-section__btn">
          <i class="pi pi-sign-in" /> Ingresar al panel
        </RouterLink>
      </div>
    </section>

  </div>
</template>

<style scoped>
@font-face {
  font-family: 'Autography';
  src: url('/lider-camp/fonts/Autography.otf') format('opentype');
  font-weight: normal;
  font-style: normal;
}

/* ═══════════════════════════════════════════════
   BASE
═══════════════════════════════════════════════ */
.home { display: flex; flex-direction: column; }

/* ═══════════════════════════════════════════════
   HERO
═══════════════════════════════════════════════ */
.hero {
  position: relative;
  min-height: calc(100dvh - 56px);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
  overflow: hidden;
  background-color: #047857; /* fallback mientras carga el video */
}
.hero__video {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  z-index: 0;
  pointer-events: none;
}
.hero__overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    160deg,
    rgba(4, 47, 27, 0.82) 0%,
    rgba(5, 150, 105, 0.65) 60%,
    rgba(4, 120, 87, 0.80) 100%
  );
}
.hero__content {
  position: relative;
  z-index: 1;
  padding: 2rem 1.5rem;
  max-width: 680px;
  width: 100%;
}
.hero__tag {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  background: rgba(255,255,255,0.15);
  border: 1px solid rgba(255,255,255,0.25);
  color: rgba(255,255,255,0.90);
  font-size: 0.78rem;
  font-weight: 600;
  padding: 0.35rem 0.85rem;
  border-radius: 999px;
  margin-bottom: 1.25rem;
  backdrop-filter: blur(6px);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.hero__tag i { font-size: 0.7rem; color: #fbbf24; }

.hero__title {
  font-size: clamp(2.6rem, 8vw, 5rem);
  font-weight: 900;
  color: #fff;
  line-height: 1;
  margin: 0;
  letter-spacing: -0.03em;
}
.hero__title-camp { font-size: 0.7em; }

/* ── Bloque edición ──────────────────────────────────────────
   Ciclo total: 8s
   · Cometa  : delay 0.4s, duración 8s, infinite
   · Texto   : delay 2.9s (= 0.4 + 8×0.31), duración 8s, infinite
   Los dos están sincronizados: cuando el cometa llega (31 %)
   el texto empieza a revelarse; al final del ciclo el texto
   desaparece justo cuando el cometa inicia el siguiente vuelo.
────────────────────────────────────────────────────────────── */

/* 1 · Estrella fugaz — vuelo lento + estela + impacto */
@keyframes comet-travel {
  0% {
    transform: translate(320px, -190px);
    opacity: 0;
    box-shadow: 0 0 4px 2px #fde68a;
  }
  4% {
    opacity: 1;
    box-shadow:
      0 0 6px 3px #fff,
      0 0 14px 7px #fde68a,
      42px  -25px 3px -1px rgba(253,230,138,0.72),
      80px  -48px 4px -1px rgba(253,230,138,0.46),
      118px -70px 5px -1px rgba(253,230,138,0.22),
      158px -94px 6px -1px rgba(253,230,138,0.08);
  }
  /* viaje lento: llega al 31 % */
  31% {
    transform: translate(0, 0);
    opacity: 1;
    box-shadow:
      0 0 8px 4px #fff,
      0 0 18px 9px #fde68a,
      42px  -25px 3px -1px rgba(253,230,138,0.65),
      80px  -48px 4px -1px rgba(253,230,138,0.38),
      118px -70px 5px -1px rgba(253,230,138,0.15);
  }
  /* impacto: destello */
  40% {
    transform: translate(0, 0) scale(2.6);
    opacity: 1;
    box-shadow:
      0 0 24px 14px #fff,
      0 0 55px 28px #fde68a,
      0 0 90px 45px rgba(251,191,36,0.22);
  }
  /* se expande y desaparece */
  50% {
    transform: translate(0, 0) scale(5);
    opacity: 0;
    box-shadow: none;
  }
  /* regresa invisible al punto de inicio */
  51% {
    transform: translate(320px, -190px) scale(1);
    opacity: 0;
    box-shadow: none;
  }
  100% {
    transform: translate(320px, -190px) scale(1);
    opacity: 0;
    box-shadow: none;
  }
}

/* 2 · Texto: aparece con el impacto, brilla, se desvanece al final del ciclo */
@keyframes texto-ciclo {
  0% {
    opacity: 0;
    transform: scale(0.86);
    filter:
      drop-shadow(0 0 30px rgba(255,255,255,1))
      drop-shadow(0 0 20px rgba(253,230,138,1));
  }
  13% {
    opacity: 1;
    transform: scale(1);
    filter: drop-shadow(0 0 16px rgba(253,230,138,0.75));
  }
  /* parpadeo suave — estrella en el cielo */
  38% { filter: drop-shadow(0 2px 12px rgba(245,158,11,0.55)); }
  52% {
    filter:
      drop-shadow(0 0 20px rgba(253,230,138,0.95))
      drop-shadow(0 0 6px rgba(255,255,255,0.5));
  }
  66% { filter: drop-shadow(0 2px 12px rgba(245,158,11,0.55)); }
  /* fade out antes del próximo ciclo */
  82% { opacity: 1; }
  100% {
    opacity: 0;
    transform: scale(0.94);
    filter: drop-shadow(0 0 0 transparent);
  }
}

.hero__edicion-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  margin: 0.1rem 0 1.9rem;
  position: relative;
}

/* Núcleo de la estrella fugaz */
.hero__comet {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 7px;
  height: 7px;
  margin: -3.5px 0 0 -3.5px;
  border-radius: 50%;
  background: #fff;
  pointer-events: none;
  animation: comet-travel 8s cubic-bezier(0.5, 0, 0.25, 1) 0.4s infinite;
  z-index: 5;
}
/* línea izquierda que se desvanece hacia el texto */
.hero__edicion-deco {
  display: block;
  width: 48px;
  height: 1px;
  background: linear-gradient(to right, transparent, rgba(253,230,138,0.6));
  flex-shrink: 0;
  margin-right: 0.6rem;
}
.hero__edicion {
  font-family: 'Autography', cursive;
  font-size: clamp(2.2rem, 5.5vw, 3.4rem);
  font-weight: 400;
  /* gradiente con shimmer animado */
  background: linear-gradient(
    105deg,
    #f59e0b 0%,
    #fde68a 30%,
    #fffbeb 50%,
    #fde68a 70%,
    #f59e0b 100%
  );
  background-size: 200% auto;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  line-height: 1.2;
  letter-spacing: 0.04em;
  filter: drop-shadow(0 2px 12px rgba(245,158,11,0.55));
  /* delay 4.4s = 0.4 + 8×0.50 → aparece después de que el cometa desaparece */
  animation: texto-ciclo 8s ease-out 4.4s infinite;
  white-space: nowrap;
}
.hero__edicion-main {
  font-size: 1em;
}
.hero__edicion-rest {
  font-size: 0.48em;
  vertical-align: middle;
  opacity: 0.85;
  letter-spacing: 0.06em;
}

.hero__sub {
  font-size: clamp(0.95rem, 3vw, 1.15rem);
  color: rgba(255,255,255,0.80);
  line-height: 1.6;
  margin: 0 0 2rem;
}

.hero__actions {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  align-items: center;
}
.hero__btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  min-height: 52px;
  padding: 0 2rem;
  border-radius: 14px;
  font-size: 1rem;
  font-weight: 700;
  text-decoration: none;
  transition: transform 0.15s, box-shadow 0.15s;
  width: 100%;
  max-width: 280px;
}
.hero__btn--primary {
  background: #fff;
  color: #059669;
  box-shadow: 0 4px 20px rgba(0,0,0,0.2);
}
.hero__btn--primary:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(0,0,0,0.25); }
.hero__btn--ghost {
  background: rgba(255,255,255,0.12);
  border: 2px solid rgba(255,255,255,0.45);
  color: #fff;
  backdrop-filter: blur(6px);
}
.hero__btn--ghost:hover { background: rgba(255,255,255,0.22); transform: translateY(-2px); }

.hero__scroll-hint {
  position: absolute;
  bottom: 1.5rem;
  left: 50%;
  transform: translateX(-50%);
  color: rgba(255,255,255,0.5);
  font-size: 1.2rem;
  animation: bounce 2s infinite;
}
@keyframes bounce {
  0%, 100% { transform: translateX(-50%) translateY(0); }
  50%       { transform: translateX(-50%) translateY(6px); }
}

@media (min-width: 480px) {
  .hero__actions { flex-direction: row; justify-content: center; }
  .hero__btn { width: auto; }
}

/* ═══════════════════════════════════════════════
   SECTION WRAPPER
═══════════════════════════════════════════════ */
.section { padding: 3.5rem 0; }
.section--features { background: #f8fafc; }
.section--stats    { background: #059669; }
.section--how      { background: #fff; }
.section--camps    { background: #fff; }

.section__container {
  max-width: 960px;
  margin: 0 auto;
  padding: 0 1.25rem;
}
.section__head { text-align: center; margin-bottom: 2.5rem; }
.section__chip {
  display: inline-block;
  background: #d1fae5;
  color: #059669;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  padding: 0.3rem 0.9rem;
  border-radius: 999px;
  margin-bottom: 0.75rem;
}
.section__title {
  font-size: clamp(1.5rem, 4vw, 2.1rem);
  font-weight: 800;
  color: #0f172a;
  margin: 0 0 0.5rem;
  letter-spacing: -0.02em;
  line-height: 1.2;
}
.section__desc {
  font-size: 1rem;
  color: #64748b;
  margin: 0;
  line-height: 1.6;
}

/* ═══════════════════════════════════════════════
   CAMPAMENTOS
═══════════════════════════════════════════════ */
.camps-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 1.25rem;
  justify-content: center;
}
.camp-card {
  width: 100%;
  max-width: 420px;
}

.camp-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 18px;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0,0,0,0.06);
  transition: transform 0.18s, box-shadow 0.18s;
}
.camp-card:hover { transform: translateY(-3px); box-shadow: 0 8px 28px rgba(0,0,0,0.10); }

.camp-card__header {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 1.25rem 1.25rem 1rem;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
}
.camp-card__emoji { font-size: 2.2rem; line-height: 1; flex-shrink: 0; }
.camp-card__info  { flex: 1; min-width: 0; }
.camp-card__name  { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0 0 2px; line-height: 1.3; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.camp-card__ed    { font-size: 0.78rem; color: #059669; font-weight: 600; }
.camp-card__badge {
  background: #059669;
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  flex-shrink: 0;
}

.camp-card__links {
  display: flex;
  flex-direction: column;
  padding: 0.75rem;
  gap: 0.4rem;
}
.camp-link {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  font-size: 0.93rem;
  font-weight: 600;
  text-decoration: none;
  transition: background 0.14s, transform 0.12s;
}
.camp-link:hover { transform: translateX(3px); }
.camp-link__arrow { margin-left: auto; font-size: 0.72rem; opacity: 0.5; }
.camp-link i:first-child { font-size: 0.9rem; width: 18px; text-align: center; }

.camp-link--gold  { background: #fef3c7; color: #92400e; }
.camp-link--gold:hover  { background: #fde68a; }
.camp-link--blue  { background: #dbeafe; color: #1e40af; }
.camp-link--blue:hover  { background: #bfdbfe; }
.camp-link--green { background: #d1fae5; color: #065f46; }
.camp-link--green:hover { background: #a7f3d0; }

/* Skeleton */
.camps-skeleton { display: grid; grid-template-columns: 1fr; gap: 1.25rem; }
.camp-skeleton  {
  height: 220px; background: #f1f5f9; border-radius: 18px;
  animation: pulse 1.6s ease-in-out infinite;
}
@media (min-width: 600px) { .camps-skeleton { grid-template-columns: repeat(2, 1fr); } }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.55; } }

.camps-empty {
  text-align: center; padding: 3rem 1rem;
  display: flex; flex-direction: column; align-items: center; gap: 0.75rem;
  color: #94a3b8;
}
.camps-empty__icon { font-size: 3rem; }
.camps-empty p { font-size: 0.95rem; margin: 0; }

/* ═══════════════════════════════════════════════
   ACCESO RÁPIDO
═══════════════════════════════════════════════ */
.features-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}
@media (min-width: 480px) { .features-grid { grid-template-columns: repeat(3, 1fr); } }

.feature-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.25rem;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  text-decoration: none;
  transition: transform 0.16s, box-shadow 0.16s;
  box-shadow: 0 1px 6px rgba(0,0,0,0.05);
}
.feature-card:hover { transform: translateY(-3px); box-shadow: 0 8px 24px rgba(0,0,0,0.09); }

@media (min-width: 480px) {
  .feature-card {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
  .feature-card__arrow { align-self: flex-end; margin-top: auto; }
}

.feature-card__icon-wrap {
  width: 52px; height: 52px; border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
  background: var(--fc-bg); flex-shrink: 0;
}
.feature-card__icon { font-size: 1.35rem; color: var(--fc-color); }
.feature-card__body { flex: 1; min-width: 0; }
.feature-card__title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 3px; }
.feature-card__desc  { font-size: 0.82rem; color: #64748b; margin: 0; line-height: 1.4; }
.feature-card__arrow { font-size: 0.8rem; color: #cbd5e1; flex-shrink: 0; }

/* ═══════════════════════════════════════════════
   CARRUSEL
═══════════════════════════════════════════════ */
.carousel-section {
  position: relative;
  overflow: hidden;
  height: 320px;
  background: #0f2d1a;
}
@media (min-width: 640px) { .carousel-section { height: 400px; } }

.carousel-track {
  display: flex;
  height: 100%;
  transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1);
}
.carousel-slide {
  min-width: 100%; height: 100%;
  background-size: cover; background-position: center;
  position: relative;
  display: flex; align-items: center; justify-content: center;
  background-color: #047857;
}
.carousel-slide__overlay {
  position: absolute; inset: 0;
  background: linear-gradient(135deg, rgba(4,47,27,0.80) 0%, rgba(5,150,105,0.55) 100%);
}
.carousel-slide__content {
  position: relative; z-index: 1;
  text-align: center; padding: 1.5rem;
  max-width: 640px;
}
.carousel-slide__tag {
  display: inline-block;
  background: rgba(255,255,255,0.18);
  border: 1px solid rgba(255,255,255,0.30);
  color: #fff;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  padding: 0.25rem 0.75rem;
  border-radius: 999px;
  margin-bottom: 1rem;
  backdrop-filter: blur(4px);
}
.carousel-slide__quote {
  font-size: clamp(1.1rem, 4vw, 1.55rem);
  font-weight: 700;
  color: #fff;
  line-height: 1.45;
  margin: 0;
  font-style: italic;
  text-shadow: 0 2px 8px rgba(0,0,0,0.3);
}

.carousel-dots {
  position: absolute;
  bottom: 1.25rem;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 0.5rem;
  z-index: 2;
}
.carousel-dot {
  width: 8px; height: 8px; border-radius: 50%;
  background: rgba(255,255,255,0.40);
  border: none; cursor: pointer; padding: 0;
  transition: background 0.2s, transform 0.2s;
}
.carousel-dot--active { background: #fff; transform: scale(1.35); }

/* ═══════════════════════════════════════════════
   STATS
═══════════════════════════════════════════════ */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1px;
  background: rgba(255,255,255,0.12);
  border-radius: 18px;
  overflow: hidden;
}
@media (min-width: 640px) { .stats-grid { grid-template-columns: repeat(4, 1fr); } }

.stat-card {
  display: flex; flex-direction: column; align-items: center;
  padding: 2rem 1rem; gap: 0.35rem;
  background: rgba(255,255,255,0.06);
  text-align: center;
}
.stat-card__emoji { font-size: 1.8rem; line-height: 1; }
.stat-card__num   { font-size: 2.2rem; font-weight: 900; color: #fff; line-height: 1; letter-spacing: -0.04em; }
.stat-card__label { font-size: 0.8rem; color: rgba(255,255,255,0.68); font-weight: 500; line-height: 1.3; }

/* ═══════════════════════════════════════════════
   CÓMO FUNCIONA
═══════════════════════════════════════════════ */
.steps-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}
@media (min-width: 600px) { .steps-grid { grid-template-columns: repeat(2, 1fr); } }
@media (min-width: 900px) { .steps-grid { grid-template-columns: repeat(4, 1fr); } }

.step {
  padding: 1.5rem;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  background: #f8fafc;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.step:hover { border-color: #a7f3d0; box-shadow: 0 4px 16px rgba(5,150,105,0.10); }
.step__num {
  font-size: 2rem; font-weight: 900;
  color: #d1fae5; letter-spacing: -0.04em;
  line-height: 1; margin-bottom: 0.75rem;
}
.step__title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 0.5rem; }
.step__desc  { font-size: 0.87rem; color: #64748b; line-height: 1.6; margin: 0; }

/* ═══════════════════════════════════════════════
   CTA LOGIN
═══════════════════════════════════════════════ */
.cta-section {
  background: linear-gradient(135deg, #0f2d1a 0%, #059669 100%);
  padding: 3.5rem 1.25rem;
}
.cta-section__inner {
  max-width: 800px; margin: 0 auto;
  display: flex; flex-direction: column;
  align-items: center; gap: 1.5rem;
  text-align: center;
}
.cta-section__title { font-size: clamp(1.4rem, 4vw, 2rem); font-weight: 800; color: #fff; margin: 0; letter-spacing: -0.02em; }
.cta-section__sub   { font-size: 1rem; color: rgba(255,255,255,0.72); margin: 0.4rem 0 0; line-height: 1.5; }
.cta-section__text  { display: flex; flex-direction: column; }
.cta-section__btn {
  display: inline-flex; align-items: center; gap: 0.55rem;
  padding: 0 2rem; min-height: 52px; border-radius: 14px;
  background: #fff; color: #059669;
  font-size: 1rem; font-weight: 700; text-decoration: none;
  box-shadow: 0 4px 20px rgba(0,0,0,0.2);
  transition: transform 0.15s, box-shadow 0.15s;
  flex-shrink: 0;
}
.cta-section__btn:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(0,0,0,0.25); }

@media (min-width: 640px) {
  .cta-section__inner { flex-direction: row; justify-content: space-between; text-align: left; }
}
</style>
