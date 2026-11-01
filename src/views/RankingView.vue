<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { rankingPublicoService, type PublicoRanking } from '@/modules/puntajes/services/puntajes.service'

const router    = useRouter()
const ranking   = ref<PublicoRanking[]>([])
const cargando  = ref(true)
const error     = ref('')
const modalOpen = ref(false)
const ultimaAct = ref<Date | null>(null)

async function cargar() {
  cargando.value = true
  error.value    = ''
  try {
    ranking.value = await rankingPublicoService.getAll()
    ultimaAct.value = new Date()
  } catch (e: any) {
    error.value = e.message ?? 'Error al cargar el ranking'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)

const hayResultados = computed(() => ranking.value.some((r) => (r.pts_bruto ?? 0) > 0))

const top3 = computed(() => ({
  primero: ranking.value.find((r) => r.posicion === 1) ?? null,
  segundo: ranking.value.find((r) => r.posicion === 2) ?? null,
  tercero: ranking.value.find((r) => r.posicion === 3) ?? null,
}))

const horaAct = computed(() => {
  if (!ultimaAct.value) return ''
  return ultimaAct.value.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })
})

const MEDALLA_EMOJI: Record<string, string> = {
  oro: '🥇', plata: '🥈', bronce: '🥉', participacion: '🎖',
}
const MEDALLA_LABEL: Record<string, string> = {
  oro: 'Oro', plata: 'Plata', bronce: 'Bronce', participacion: 'Participación',
}

function badgeClase(m: string | null) {
  const map: Record<string, string> = {
    oro:          'badge--oro',
    plata:        'badge--plata',
    bronce:       'badge--bronce',
    participacion:'badge--part',
  }
  return map[m ?? ''] ?? 'badge--part'
}

function podioItemClase(pos: number) {
  return `podio-item--${pos}`
}
</script>

<template>
  <div class="rk-page">

    <!-- Encabezado -->
    <div class="rk-header">
      <div class="rk-header__left">
        <i class="pi pi-trophy rk-icon" />
        <div>
          <h1 class="rk-title">Ranking LiderCamp 2026-II</h1>
          <p v-if="ultimaAct" class="rk-sub">Actualizado a las {{ horaAct }}</p>
        </div>
      </div>
      <div class="rk-header__right">
        <button
          class="btn-refresh"
          :disabled="cargando"
          title="Actualizar ranking"
          @click="cargar"
        >
          <i :class="['pi', cargando ? 'pi-spin pi-spinner' : 'pi-refresh']" />
        </button>
        <button class="btn-ayuda" title="¿Cómo funciona?" @click="modalOpen = true">
          <i class="pi pi-question-circle" />
        </button>
      </div>
    </div>

    <!-- Cargando inicial -->
    <div v-if="cargando && !ranking.length" class="rk-empty">
      <i class="pi pi-spin pi-spinner rk-empty__icon" />
      <span>Cargando ranking…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="rk-error">
      <i class="pi pi-exclamation-triangle" />
      {{ error }}
    </div>

    <template v-else>

      <!-- Sin equipos -->
      <div v-if="!ranking.length" class="rk-empty">
        <i class="pi pi-users rk-empty__icon" />
        <span>Aún no hay equipos registrados.</span>
      </div>

      <template v-else>

        <!-- Banner: sin resultados publicados -->
        <div v-if="!hayResultados" class="rk-aviso">
          <i class="pi pi-clock" />
          <div>
            <strong>Resultados pendientes</strong>
            <span>Los puntajes se mostrarán cuando el administrador publique cada día.</span>
          </div>
        </div>

        <!-- ── PODIO (solo si hay resultados) ── -->
        <div v-if="hayResultados && top3.primero" class="podio">
          <!-- 2° lugar -->
          <div
            v-if="top3.segundo"
            :class="['podio-item', podioItemClase(2)]"
            @click="router.push(`/equipo/${top3.segundo.equipo_id}`)"
          >
            <div class="podio-medalla">{{ MEDALLA_EMOJI[top3.segundo.medalla ?? 'participacion'] }}</div>
            <div
              class="podio-color"
              :style="{ background: top3.segundo.equipo_color ?? '#6b7280' }"
            />
            <div class="podio-nombre">{{ top3.segundo.equipo_nombre }}</div>
            <div class="podio-pts">{{ top3.segundo.pts_escala }}<span class="podio-pts__de">/1000</span></div>
            <div class="podio-base podio-base--2" />
          </div>

          <!-- 1° lugar -->
          <div
            :class="['podio-item', podioItemClase(1)]"
            @click="router.push(`/equipo/${top3.primero!.equipo_id}`)"
          >
            <div class="podio-corona">👑</div>
            <div class="podio-medalla podio-medalla--1">{{ MEDALLA_EMOJI[top3.primero!.medalla ?? 'participacion'] }}</div>
            <div
              class="podio-color podio-color--1"
              :style="{ background: top3.primero!.equipo_color ?? '#6b7280' }"
            />
            <div class="podio-nombre podio-nombre--1">{{ top3.primero!.equipo_nombre }}</div>
            <div class="podio-pts podio-pts--1">{{ top3.primero!.pts_escala }}<span class="podio-pts__de">/1000</span></div>
            <div class="podio-base podio-base--1" />
          </div>

          <!-- 3° lugar -->
          <div
            v-if="top3.tercero"
            :class="['podio-item', podioItemClase(3)]"
            @click="router.push(`/equipo/${top3.tercero.equipo_id}`)"
          >
            <div class="podio-medalla">{{ MEDALLA_EMOJI[top3.tercero.medalla ?? 'participacion'] }}</div>
            <div
              class="podio-color"
              :style="{ background: top3.tercero.equipo_color ?? '#6b7280' }"
            />
            <div class="podio-nombre">{{ top3.tercero.equipo_nombre }}</div>
            <div class="podio-pts">{{ top3.tercero.pts_escala }}<span class="podio-pts__de">/1000</span></div>
            <div class="podio-base podio-base--3" />
          </div>
        </div>

        <!-- ── LISTA COMPLETA ── -->
        <div class="rk-lista">
          <div
            v-for="eq in ranking"
            :key="eq.equipo_id"
            :class="['rk-card', eq.posicion === 1 && hayResultados && 'rk-card--1']"
            @click="router.push(`/equipo/${eq.equipo_id}`)"
          >
            <!-- Posición -->
            <span :class="['rk-pos', eq.posicion! <= 3 && hayResultados ? `rk-pos--${eq.posicion}` : 'rk-pos--n']">
              {{ eq.posicion }}°
            </span>

            <!-- Color dot + nombre -->
            <div class="rk-equipo">
              <span
                class="rk-dot"
                :style="{ background: eq.equipo_color ?? '#6b7280' }"
              />
              <span class="rk-nombre">{{ eq.equipo_nombre }}</span>
            </div>

            <!-- Medalla -->
            <span :class="['rk-badge', badgeClase(eq.medalla)]">
              {{ MEDALLA_EMOJI[eq.medalla ?? 'participacion'] }}
              <span class="rk-badge__label">{{ MEDALLA_LABEL[eq.medalla ?? 'participacion'] }}</span>
            </span>

            <!-- Puntaje -->
            <span class="rk-pts">
              {{ hayResultados ? eq.pts_escala : '—' }}
              <span v-if="hayResultados" class="rk-pts__de">/1000</span>
            </span>

            <i class="pi pi-angle-right rk-arrow" />
          </div>
        </div>

        <p class="rk-nota">
          <i class="pi pi-info-circle" />
          Toca un equipo para ver su ficha detallada.
        </p>

      </template>
    </template>

    <!-- ── Modal ¿Cómo funciona? ── -->
    <Teleport to="body">
      <Transition name="m-ea" @enter="(el: any) => el.style.opacity = '1'" @leave="(el: any) => el.style.opacity = '0'">
        <div v-if="modalOpen" class="m-overlay" @click.self="modalOpen = false">
          <div class="m-backdrop" @click="modalOpen = false" />
          <div class="m-panel">
            <div class="m-drag" />
            <div class="m-head">
              <div class="m-head__left">
                <div class="m-icon"><i class="pi pi-trophy" /></div>
                <h2 class="m-title">¿Cómo funciona el ranking?</h2>
              </div>
              <button class="m-close" @click="modalOpen = false">
                <i class="pi pi-times" />
              </button>
            </div>

            <div class="m-body">
              <p class="m-intro">
                El puntaje de cada equipo se calcula a partir de varios componentes evaluados
                durante los 4 días del campamento (J, V, S, D).
              </p>

              <div class="m-pasos">
                <div class="m-paso">
                  <div class="m-paso__n">1</div>
                  <div>
                    <p class="m-paso__t">Puntaje base</p>
                    <p class="m-paso__d">Inscripción + Rúbrica de observaciones diarias + Liderazgo + Asistencia a eventos.</p>
                  </div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n">2</div>
                  <div>
                    <p class="m-paso__t">Bonus y deméritos</p>
                    <p class="m-paso__d">Se suman los bonus validados (B1/B2, máx. 200 pts) y se restan los deméritos aplicados (D1–D6, sin tope).</p>
                  </div>
                </div>
                <div class="m-paso">
                  <div class="m-paso__n m-paso__n--ok">3</div>
                  <div>
                    <p class="m-paso__t">Escala 1000</p>
                    <p class="m-paso__d">El puntaje bruto se convierte a una escala de 0 a 1000 para comparar equipos de manera justa.</p>
                  </div>
                </div>
              </div>

              <div class="m-medallas">
                <p class="m-medallas__tit">Medallas</p>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥇</span>
                  <span class="m-medalla-badge badge--oro">Oro</span>
                  <span class="m-medalla-rango">Mayor puntaje</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥈</span>
                  <span class="m-medalla-badge badge--plata">Plata</span>
                  <span class="m-medalla-rango">2° y 3° lugar</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🥉</span>
                  <span class="m-medalla-badge badge--bronce">Bronce</span>
                  <span class="m-medalla-rango">Resto del podio</span>
                </div>
                <div class="m-medalla-fila">
                  <span class="m-medalla-emoji">🎖</span>
                  <span class="m-medalla-badge badge--part">Participación</span>
                  <span class="m-medalla-rango">Todos los demás</span>
                </div>
              </div>

              <div class="m-nota">
                <i class="pi pi-clock" />
                Los resultados se publican por día a medida que el administrador los activa.
              </div>
            </div>

            <div class="m-foot">
              <button class="btn btn--primary btn--full" @click="modalOpen = false">Entendido</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
/* ─── Página ─── */
.rk-page {
  max-width: 640px;
  margin: 0 auto;
  padding: 1rem 1rem 2rem;
}

/* ─── Encabezado ─── */
.rk-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}
.rk-header__left {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  flex: 1;
  min-width: 0;
}
.rk-header__right {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}
.rk-icon { font-size: 1.4rem; color: #16a34a; flex-shrink: 0; }
.rk-title { font-size: 1.15rem; font-weight: 800; margin: 0; color: #111827; line-height: 1.2; }
.rk-sub   { font-size: 0.75rem; color: #9ca3af; margin: 0.1rem 0 0; }

.btn-refresh {
  width: 36px; height: 36px;
  border-radius: 50%;
  border: 1px solid #e2e8f0;
  background: white;
  color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.9rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
}
.btn-refresh:hover:not(:disabled) { color: #16a34a; border-color: #bbf7d0; }
.btn-refresh:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-ayuda {
  width: 36px; height: 36px;
  border-radius: 50%;
  border: 1px solid #e2e8f0;
  background: white;
  color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 1rem;
  box-shadow: 0 1px 2px rgba(0,0,0,.06);
  transition: color .15s, border-color .15s;
}
.btn-ayuda:hover { color: #16a34a; border-color: #bbf7d0; }

/* ─── Aviso ─── */
.rk-aviso {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-left: 4px solid #f59e0b;
  border-radius: 10px;
  padding: 0.85rem 1rem;
  margin-bottom: 1.25rem;
  font-size: 0.85rem;
}
.rk-aviso i { color: #d97706; flex-shrink: 0; margin-top: 0.15rem; }
.rk-aviso strong { display: block; color: #92400e; font-size: 0.9rem; }
.rk-aviso span   { color: #b45309; font-size: 0.8rem; line-height: 1.4; }

/* ─── Estados vacíos ─── */
.rk-empty {
  display: flex; flex-direction: column; align-items: center; gap: 0.5rem;
  padding: 3rem 1rem; text-align: center; color: #9ca3af; font-size: 0.9rem;
}
.rk-empty__icon { font-size: 2.5rem; margin-bottom: 0.25rem; }

.rk-error {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px;
  padding: 0.85rem 1rem; color: #b91c1c; font-size: 0.88rem;
}

/* ─── PODIO ─── */
.podio {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  padding: 0 0.25rem;
}

.podio-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  max-width: 130px;
  cursor: pointer;
  transition: transform .15s;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px 12px 0 0;
  padding: 0.65rem 0.5rem 0;
  box-shadow: 0 2px 8px rgba(0,0,0,.07);
  position: relative;
  overflow: hidden;
}
.podio-item:hover { transform: translateY(-4px); box-shadow: 0 6px 16px rgba(0,0,0,.12); }

.podio-item--1 {
  order: 2;
  background: linear-gradient(160deg, #fefce8 0%, white 60%);
  border-color: #fde68a;
  padding-top: 0.4rem;
}
.podio-item--2 { order: 1; }
.podio-item--3 { order: 3; }

.podio-corona {
  font-size: 1.1rem;
  line-height: 1;
  margin-bottom: 0.1rem;
}

.podio-medalla { font-size: 1.75rem; line-height: 1; }
.podio-medalla--1 { font-size: 2.1rem; }

.podio-color {
  width: 28px; height: 28px; border-radius: 50%;
  border: 2px solid #e5e7eb; margin: 0.35rem 0 0.2rem;
  flex-shrink: 0;
}
.podio-color--1 { width: 34px; height: 34px; }

.podio-nombre {
  font-weight: 700;
  font-size: 0.78rem;
  text-align: center;
  color: #111827;
  line-height: 1.2;
  padding: 0 0.15rem;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  width: 100%;
}
.podio-nombre--1 { font-size: 0.85rem; }

.podio-pts {
  font-size: 0.9rem;
  font-weight: 800;
  color: #16a34a;
  margin: 0.15rem 0 0;
}
.podio-pts--1 { font-size: 1.1rem; }
.podio-pts__de { font-size: 0.65rem; color: #9ca3af; font-weight: 600; margin-left: 1px; }

/* Pedestal visual */
.podio-base {
  width: calc(100% + 2px);
  margin: 0.5rem -1px -1px;
  border-radius: 0;
  flex-shrink: 0;
}
.podio-base--1 { height: 40px; background: linear-gradient(180deg, #fde68a, #f59e0b); }
.podio-base--2 { height: 28px; background: linear-gradient(180deg, #e2e8f0, #94a3b8); }
.podio-base--3 { height: 20px; background: linear-gradient(180deg, #fed7aa, #f97316); }

/* ─── Lista ─── */
.rk-lista {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.rk-card {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 0.75rem 0.85rem;
  cursor: pointer;
  transition: box-shadow .15s, border-color .15s;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
  min-height: 52px;
}
.rk-card:hover { box-shadow: 0 3px 10px rgba(0,0,0,.08); border-color: #d1d5db; }
.rk-card--1 {
  border-color: #fde68a;
  background: linear-gradient(90deg, #fefce8 0%, white 60%);
}

/* Posición */
.rk-pos {
  font-weight: 800;
  font-size: 0.88rem;
  min-width: 32px;
  text-align: center;
  flex-shrink: 0;
}
.rk-pos--1 { color: #d97706; font-size: 1rem; }
.rk-pos--2 { color: #64748b; }
.rk-pos--3 { color: #f97316; }
.rk-pos--n { color: #9ca3af; }

/* Equipo */
.rk-equipo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
}
.rk-dot {
  width: 20px; height: 20px; border-radius: 50%;
  border: 1.5px solid #e5e7eb; flex-shrink: 0;
}
.rk-nombre {
  font-weight: 600;
  font-size: 0.9rem;
  color: #111827;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Badge medalla */
.rk-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.72rem;
  font-weight: 700;
  padding: 0.2rem 0.5rem;
  border-radius: 20px;
  white-space: nowrap;
  flex-shrink: 0;
}
.rk-badge__label { display: none; }
@media (min-width: 420px) {
  .rk-badge__label { display: inline; }
}

.badge--oro    { background: #fef9c3; color: #92400e; }
.badge--plata  { background: #f1f5f9; color: #475569; }
.badge--bronce { background: #ffedd5; color: #9a3412; }
.badge--part   { background: #f3f4f6; color: #6b7280; }

/* Puntaje */
.rk-pts {
  font-weight: 800;
  font-size: 0.95rem;
  color: #16a34a;
  min-width: 48px;
  text-align: right;
  flex-shrink: 0;
  white-space: nowrap;
}
.rk-pts__de { font-size: 0.65rem; color: #9ca3af; font-weight: 600; margin-left: 1px; }

.rk-arrow {
  font-size: 0.75rem;
  color: #d1d5db;
  flex-shrink: 0;
}

/* Nota final */
.rk-nota {
  text-align: center;
  font-size: 0.8rem;
  color: #9ca3af;
  margin-top: 0.85rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
}

/* ─── Modal ─── */
.m-ea-enter-active, .m-ea-leave-active { transition: opacity .2s ease; }
.m-ea-enter-from, .m-ea-leave-to { opacity: 0; }

.m-overlay {
  position: fixed; inset: 0; z-index: 200;
  display: flex; align-items: flex-end; justify-content: center;
}
@media (min-width: 640px) { .m-overlay { align-items: center; padding: 1rem; } }

.m-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.4);
  backdrop-filter: blur(4px);
}
.m-panel {
  position: relative; width: 100%; max-width: 480px;
  background: white; border-radius: 20px 20px 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,.25);
  display: flex; flex-direction: column;
  overflow: hidden; max-height: 90dvh;
}
@media (min-width: 640px) { .m-panel { border-radius: 16px; } }

.m-drag {
  width: 36px; height: 4px; border-radius: 2px;
  background: #e5e7eb; margin: 0.65rem auto 0;
  flex-shrink: 0;
}
@media (min-width: 640px) { .m-drag { display: none; } }

.m-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem 0.85rem;
  border-bottom: 1px solid #f1f5f9; flex-shrink: 0;
}
.m-head__left { display: flex; align-items: center; gap: 0.6rem; }
.m-icon {
  width: 32px; height: 32px; border-radius: 50%;
  background: #dcfce7; color: #16a34a;
  display: flex; align-items: center; justify-content: center; font-size: 0.88rem;
}
.m-title { font-size: 1rem; font-weight: 800; margin: 0; color: #1e293b; }
.m-close {
  width: 32px; height: 32px; border-radius: 8px; border: none;
  background: transparent; color: #94a3b8;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: 0.82rem; transition: background .15s;
}
.m-close:hover { background: #f1f5f9; }

.m-body { overflow-y: auto; padding: 1.1rem 1.25rem; flex: 1; }

.m-intro {
  font-size: 0.88rem; color: #475569; margin: 0 0 1rem; line-height: 1.55;
}

.m-pasos { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.25rem; }
.m-paso  { display: flex; gap: 0.75rem; align-items: flex-start; }
.m-paso__n {
  width: 28px; height: 28px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  font-weight: 800; font-size: 0.78rem;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; margin-top: 0.05rem;
}
.m-paso__n--ok { background: #16a34a; color: white; }
.m-paso__t { font-size: 0.88rem; font-weight: 700; color: #1e293b; margin: 0 0 0.1rem; }
.m-paso__d { font-size: 0.8rem; color: #64748b; margin: 0; line-height: 1.4; }

.m-medallas {
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px;
  padding: 0.85rem; margin-bottom: 1rem;
}
.m-medallas__tit {
  font-size: 0.72rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .05em; margin: 0 0 0.6rem;
}
.m-medalla-fila {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.25rem 0; font-size: 0.82rem;
  border-top: 1px solid #f1f5f9;
}
.m-medalla-fila:first-of-type { border-top: none; }
.m-medalla-emoji { font-size: 1rem; flex-shrink: 0; }
.m-medalla-badge {
  font-size: 0.7rem; font-weight: 700;
  padding: 0.15rem 0.5rem; border-radius: 20px;
  flex-shrink: 0;
}
.m-medalla-rango { font-size: 0.78rem; color: #6b7280; }

.m-nota {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.7rem 0.85rem; background: #f0fdf4;
  border: 1px solid #bbf7d0; border-radius: 8px;
  font-size: 0.78rem; color: #15803d; line-height: 1.45;
}
.m-nota i { flex-shrink: 0; margin-top: 0.1rem; }

.m-foot {
  padding: 0.9rem 1.25rem;
  border-top: 1px solid #f1f5f9; flex-shrink: 0;
}

/* ─── Botones ─── */
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 0.35rem;
  min-height: 44px; padding: 0.5rem 1.25rem;
  border-radius: 8px; border: none;
  font-size: 0.88rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.btn--primary { background: #16a34a; color: white; }
.btn--primary:hover { background: #15803d; }
.btn--full { width: 100%; }
</style>
