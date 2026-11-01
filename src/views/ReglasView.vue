<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  publicoService,
  type PublicoCalendario,
} from '@/modules/criterios/services/criterios.service'
import {
  publicoLiderazgoService,
  type PublicoLiderazgoIndicador,
} from '@/modules/liderazgo/services/liderazgo.service'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database'

type IncidenciaCodigo = Tables<'incidencia_codigos'>

// ── Estado ───────────────────────────────────────────────────────────────────
const campamento     = ref<{ id: string; nombre: string; edicion: string } | null>(null)
const calendario     = ref<PublicoCalendario[]>([])
const indicadoresLid = ref<PublicoLiderazgoIndicador[]>([])
const codigos        = ref<IncidenciaCodigo[]>([])
const cargando       = ref(true)
const error          = ref('')

// ── Carga ────────────────────────────────────────────────────────────────────
function mensajeError(e: unknown): string {
  if (e instanceof Error) return e.message
  if (e && typeof e === 'object' && 'message' in e) return String((e as any).message)
  return String(e)
}

onMounted(async () => {
  try {
    const camp = await publicoService.getCampamentoActivo()
    campamento.value = camp

    const calData = camp
      ? await publicoService.getCalendarioCampamento(camp.id)
      : []

    const { data: lidRaw, error: lidErr } = await supabase
      .from('publico_liderazgo_indicadores')
      .select('*')
    if (lidErr) throw lidErr

    const { data: codigosRaw, error: codigosErr } = await supabase
      .from('incidencia_codigos')
      .select('*')
      .eq('activo', true)
      .order('orden')
    if (codigosErr) throw codigosErr

    calendario.value     = calData
    indicadoresLid.value = (lidRaw ?? []) as PublicoLiderazgoIndicador[]
    codigos.value        = (codigosRaw ?? []) as IncidenciaCodigo[]
  } catch (e: unknown) {
    console.error('[ReglasView] Error al cargar:', e)
    error.value = mensajeError(e)
  } finally {
    cargando.value = false
  }
})

// ── Constantes hardcoded ─────────────────────────────────────────────────────
const RUBRICA = [
  { puntaje: 100, nivel: 'Excelente',  desc: 'Cumplimiento total, sin observaciones.' },
  { puntaje:  75, nivel: 'Bueno',      desc: 'Cumplimiento mayoritario con observaciones menores.' },
  { puntaje:  50, nivel: 'Regular',    desc: 'Cumplimiento parcial con observaciones significativas.' },
  { puntaje:  25, nivel: 'Deficiente', desc: 'Cumplimiento mínimo, múltiples observaciones.' },
  { puntaje:   0, nivel: 'No cumple',  desc: 'Ausencia total o incumplimiento grave.' },
]

const MEDALLAS = [
  { emoji: '🥇', nombre: 'Oro',          rango: '> 5000 pts brutos',     cls: 'medalla--oro' },
  { emoji: '🥈', nombre: 'Plata',        rango: '4000 – 4999 pts brutos', cls: 'medalla--plata' },
  { emoji: '🥉', nombre: 'Bronce',       rango: '3000 – 3999 pts brutos', cls: 'medalla--bronce' },
  { emoji: '🎖',  nombre: 'Participación', rango: '0 – 2999 pts brutos',   cls: 'medalla--part' },
]

const LABELS_CATEGORIA: Record<string, string> = {
  inscripcion:              'Inscripción',
  armado:                   'Armado de campamento',
  orden_cocina:             'Orden y cocina',
  ceremonias_participacion: 'Ceremonias y participación',
  liderazgo:                'Liderazgo',
}

const ORDEN_CATEGORIAS = [
  'inscripcion',
  'armado',
  'orden_cocina',
  'ceremonias_participacion',
  'liderazgo',
]

const MOMENTOS_LABEL: Record<string, string> = { J: 'J', V: 'V', S: 'S', D: 'D' }

// ── Computed ─────────────────────────────────────────────────────────────────

/** Bonus del catálogo (tipo = bonus) */
const bonus = computed(() => codigos.value.filter((c) => c.tipo === 'bonus'))

/** Deméritos del catálogo */
const demeritos = computed(() => codigos.value.filter((c) => c.tipo === 'demerito'))

/** Criterios agrupados por categoría con sus días */
interface CriterioConDias {
  codigo:     string
  nombre:     string
  categoria:  string
  tipo_calculo: string | null
  abarca:     string | null
  no_abarca:  string | null
  evidencia:  string | null
  orden:      number | null
  dias: Array<{ momento: string; puntaje_max: number; estado: string }>
}

const grupos = computed(() => {
  const mapa = new Map<string, CriterioConDias>()

  for (const fila of calendario.value) {
    if (!mapa.has(fila.codigo!)) {
      mapa.set(fila.codigo!, {
        codigo:       fila.codigo!,
        nombre:       fila.nombre!,
        categoria:    fila.categoria!,
        tipo_calculo: fila.tipo_calculo,
        abarca:       fila.abarca ?? null,
        no_abarca:    fila.no_abarca ?? null,
        evidencia:    fila.evidencia ?? null,
        orden:        fila.orden,
        dias: [],
      })
    }
    mapa.get(fila.codigo!)!.dias.push({
      momento:    fila.momento!,
      puntaje_max: fila.puntaje_max!,
      estado:     fila.estado!,
    })
  }

  // Ordenar días dentro de cada criterio: J → V → S → D
  const ORDEN_DIA: Record<string, number> = { J: 0, V: 1, S: 2, D: 3 }
  for (const c of mapa.values()) {
    c.dias.sort((a, b) => (ORDEN_DIA[a.momento] ?? 9) - (ORDEN_DIA[b.momento] ?? 9))
  }

  // Agrupar por categoría en el orden predefinido
  const porCat = new Map<string, CriterioConDias[]>()
  for (const c of mapa.values()) {
    if (!porCat.has(c.categoria)) porCat.set(c.categoria, [])
    porCat.get(c.categoria)!.push(c)
  }

  return ORDEN_CATEGORIAS
    .filter((cat) => porCat.has(cat))
    .map((cat) => ({
      categoria: cat,
      label:     LABELS_CATEGORIA[cat] ?? cat,
      items:     (porCat.get(cat) ?? []).sort((a, b) => (a.orden ?? 0) - (b.orden ?? 0)),
    }))
})

/** Puntaje máximo total calculado desde la programación */
const ptsTotalCalendario = computed(() => {
  const set = new Set<string>()
  let total = 0
  for (const fila of calendario.value) {
    if (fila.estado === 'programado') {
      const key = `${fila.codigo}-${fila.momento}`
      if (!set.has(key)) {
        set.add(key)
        total += fila.puntaje_max ?? 0
      }
    }
  }
  return total
})
</script>

<template>
  <div class="rg-page">

    <!-- Encabezado -->
    <div class="rg-header">
      <i class="pi pi-book rg-header__icon" />
      <div>
        <h1 class="rg-header__titulo">Reglamento de evaluación</h1>
        <p v-if="campamento" class="rg-header__sub">
          {{ campamento.nombre }}
          <span v-if="campamento.edicion" class="rg-header__edicion">— {{ campamento.edicion }}</span>
        </p>
      </div>
    </div>

    <!-- Cargando -->
    <div v-if="cargando" class="rg-empty">
      <i class="pi pi-spin pi-spinner rg-empty__icon" />
      <span>Cargando reglas…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="rg-error">
      <i class="pi pi-exclamation-triangle" />
      {{ error }}
    </div>

    <template v-else>

      <!-- Sin campamento activo -->
      <div v-if="!campamento" class="rg-aviso">
        <i class="pi pi-clock" />
        <div>
          <strong>Sin campamento activo</strong>
          <span>Las reglas se publicarán cuando el administrador active un campamento.</span>
        </div>
      </div>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 1: Rúbrica
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">1</span>
          Rúbrica de evaluación
        </h2>
        <p class="rg-seccion__desc">
          Cada criterio se califica exclusivamente con uno de estos cinco valores:
        </p>
        <div class="rubrica-lista">
          <div
            v-for="fila in RUBRICA"
            :key="fila.puntaje"
            class="rubrica-fila"
          >
            <span :class="['rubrica-pts', `rubrica-pts--${fila.puntaje}`]">{{ fila.puntaje }}</span>
            <div class="rubrica-fila__texto">
              <strong class="rubrica-nivel">{{ fila.nivel }}</strong>
              <span class="rubrica-desc">{{ fila.desc }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 2: Criterios de evaluación (dinámico)
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">2</span>
          Criterios de evaluación
          <span v-if="ptsTotalCalendario" class="rg-seccion__pts">
            {{ ptsTotalCalendario }} pts máx.
          </span>
        </h2>

        <div v-if="!grupos.length" class="rg-aviso rg-aviso--info">
          <i class="pi pi-info-circle" />
          <span>La programación de criterios se publicará próximamente.</span>
        </div>

        <div v-else class="criterios-grupos">
          <div
            v-for="grupo in grupos"
            :key="grupo.categoria"
            class="criterios-grupo"
          >
            <div class="criterios-grupo__titulo">{{ grupo.label }}</div>

            <div class="criterios-lista">
              <div
                v-for="crit in grupo.items"
                :key="crit.codigo"
                class="crit-card"
              >
                <!-- Cabecera: código + nombre + días -->
                <div class="crit-card__top">
                  <div class="crit-card__left">
                    <span class="crit-codigo">{{ crit.codigo }}</span>
                    <span class="crit-nombre">{{ crit.nombre }}</span>
                  </div>
                  <div class="crit-dias">
                    <span
                      v-for="dia in crit.dias"
                      :key="dia.momento"
                      :class="['dia-pill', dia.estado === 'cancelado' ? 'dia-pill--canc' : 'dia-pill--ok']"
                      :title="dia.estado === 'cancelado' ? 'Cancelado' : `${dia.puntaje_max} pts`"
                    >
                      {{ MOMENTOS_LABEL[dia.momento] ?? dia.momento }}
                    </span>
                  </div>
                </div>

                <!-- Detalle (abarca / no abarca / evidencia) -->
                <template v-if="crit.abarca || crit.no_abarca || crit.evidencia">
                  <div class="crit-card__detalle">
                    <p v-if="crit.abarca" class="crit-campo">
                      <span class="crit-campo__lbl">Abarca</span>
                      {{ crit.abarca }}
                    </p>
                    <p v-if="crit.no_abarca" class="crit-campo crit-campo--no">
                      <span class="crit-campo__lbl">No abarca</span>
                      {{ crit.no_abarca }}
                    </p>
                    <p v-if="crit.evidencia" class="crit-campo">
                      <span class="crit-campo__lbl">Evidencia</span>
                      {{ crit.evidencia }}
                    </p>
                  </div>
                </template>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 3: Liderazgo (dinámico)
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">3</span>
          Liderazgo de servicio
          <span class="rg-seccion__prov">(provisional)</span>
        </h2>
        <p class="rg-seccion__desc">
          4 indicadores evaluados por día · Escala: 0 / 6.25 / 12.5 / 18.75 / 25 pts ·
          Máximo <strong>100 pts/día × 4 días = 400 pts</strong>
        </p>

        <div v-if="!indicadoresLid.length" class="rg-aviso rg-aviso--info">
          <i class="pi pi-info-circle" />
          <span>Los indicadores se publicarán próximamente.</span>
        </div>

        <div v-else class="criterios-lista">
          <div
            v-for="ind in indicadoresLid"
            :key="ind.codigo"
            class="crit-card crit-card--lid"
          >
            <div class="crit-card__top">
              <span class="crit-codigo crit-codigo--lid">{{ ind.codigo }}</span>
              <span class="crit-nombre">{{ ind.nombre }}</span>
            </div>
            <div class="crit-card__detalle">
              <p class="crit-campo">
                <span class="crit-campo__lbl">Descripción</span>
                {{ ind.descripcion }}
              </p>
              <p v-if="ind.evidencia" class="crit-campo">
                <span class="crit-campo__lbl">Evidencia</span>
                {{ ind.evidencia }}
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 4: Bonus (dinámico desde DB)
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">4</span>
          Bonus
        </h2>
        <p class="rg-seccion__desc">
          Solo cuentan cuando son <strong>validados</strong> por el administrador.
          Tope global: <strong>200 pts</strong>.
        </p>

        <div class="inc-lista">
          <div
            v-for="b in bonus"
            :key="b.codigo"
            class="inc-card inc-card--bonus"
          >
            <div class="inc-card__top">
              <span class="inc-codigo inc-codigo--bonus">{{ b.codigo }}</span>
              <span class="inc-nombre">{{ b.nombre }}</span>
              <span class="inc-pts inc-pts--bonus">+{{ b.puntos }} pts</span>
            </div>
            <div class="inc-card__detalle">
              <p v-if="b.abarca" class="crit-campo">
                <span class="crit-campo__lbl">Abarca</span>{{ b.abarca }}
              </p>
              <p v-if="b.excluye" class="crit-campo crit-campo--no">
                <span class="crit-campo__lbl">No aplica si</span>{{ b.excluye }}
              </p>
              <p v-if="b.tope_equipo" class="inc-tope">
                Tope por equipo: {{ b.tope_equipo }} pts
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 5: Deméritos (dinámico desde DB)
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">5</span>
          Deméritos
        </h2>
        <p class="rg-seccion__desc">
          Se restan al puntaje sin tope. Un solo demérito por episodio; nunca se descuenta dos veces el mismo hecho.
        </p>

        <div class="inc-lista">
          <div
            v-for="d in demeritos"
            :key="d.codigo"
            class="inc-card inc-card--demerito"
          >
            <div class="inc-card__top">
              <span class="inc-codigo inc-codigo--demerito">{{ d.codigo }}</span>
              <span class="inc-nombre">{{ d.nombre }}</span>
              <span class="inc-pts inc-pts--demerito">−{{ d.puntos }} pts<span v-if="d.por_persona"> / persona</span></span>
            </div>
            <div v-if="d.abarca || d.excluye" class="inc-card__detalle">
              <p v-if="d.abarca" class="crit-campo">
                <span class="crit-campo__lbl">Aplica cuando</span>{{ d.abarca }}
              </p>
              <p v-if="d.excluye" class="crit-campo crit-campo--no">
                <span class="crit-campo__lbl">No aplica si</span>{{ d.excluye }}
              </p>
              <p v-if="d.requiere_advertencia" class="inc-tope">
                <i class="pi pi-info-circle" /> Requiere advertencia previa documentada.
              </p>
              <p v-if="d.codigo === 'D6'" class="inc-expulsion">
                <i class="pi pi-user-minus" /> Conlleva expulsión inmediata del campamento.
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 6: Medallas
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">6</span>
          Medallas
          <span class="rg-seccion__prov">(provisional)</span>
        </h2>
        <p class="rg-seccion__desc">
          Asignadas según el puntaje bruto (base 5200 pts).
          El puntaje final se convierte a escala <strong>0 – 1000</strong> para el ranking.
        </p>
        <div class="medallas-lista">
          <div
            v-for="m in MEDALLAS"
            :key="m.nombre"
            :class="['medalla-card', m.cls]"
          >
            <span class="medalla-emoji">{{ m.emoji }}</span>
            <div class="medalla-info">
              <span class="medalla-nombre">{{ m.nombre }}</span>
              <span class="medalla-rango">{{ m.rango }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- ══════════════════════════════════════════════════════
           SECCIÓN 7: Hito previo
      ═══════════════════════════════════════════════════════ -->
      <section class="rg-seccion">
        <h2 class="rg-seccion__titulo">
          <span class="rg-seccion__num">7</span>
          Hito previo al campamento
        </h2>
        <div class="hito-card">
          <div class="hito-card__icon"><i class="pi pi-check-circle" /></div>
          <div>
            <strong class="hito-titulo">Armado al 80 %</strong>
            <p class="hito-desc">
              El jueves antes del inicio de evaluación, todos los equipos deben tener su campamento
              armado al 80 %. No suma puntos pero es requisito para participar en la evaluación del día.
            </p>
          </div>
        </div>
      </section>

    </template>
  </div>
</template>

<style scoped>
/* ─── Página ─── */
.rg-page {
  max-width: 680px;
  margin: 0 auto;
  padding: 0 0 2rem;
}

/* ─── Encabezado ─── */
.rg-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}
.rg-header__icon { font-size: 1.5rem; color: #16a34a; flex-shrink: 0; }
.rg-header__titulo {
  font-size: 1.2rem; font-weight: 800; margin: 0; color: #111827; line-height: 1.2;
}
.rg-header__sub {
  font-size: 0.8rem; color: #6b7280; margin: 0.1rem 0 0;
}
.rg-header__edicion { color: #9ca3af; }

/* ─── Estados ─── */
.rg-empty {
  display: flex; flex-direction: column; align-items: center;
  gap: 0.5rem; padding: 3rem 1rem; color: #9ca3af; font-size: 0.9rem; text-align: center;
}
.rg-empty__icon { font-size: 2rem; }

.rg-error {
  display: flex; align-items: center; gap: 0.5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px;
  padding: 0.85rem 1rem; color: #b91c1c; font-size: 0.88rem;
}

.rg-aviso {
  display: flex; align-items: flex-start; gap: 0.65rem;
  background: #fffbeb; border: 1px solid #fde68a;
  border-left: 4px solid #f59e0b; border-radius: 10px;
  padding: 0.85rem 1rem; margin-bottom: 1.25rem; font-size: 0.85rem;
}
.rg-aviso i { color: #d97706; flex-shrink: 0; margin-top: 0.15rem; }
.rg-aviso strong { display: block; color: #92400e; font-size: 0.9rem; }
.rg-aviso span   { color: #b45309; font-size: 0.8rem; line-height: 1.4; }
.rg-aviso--info {
  background: #f0fdf4; border-color: #bbf7d0; border-left-color: #16a34a;
}
.rg-aviso--info i    { color: #16a34a; }
.rg-aviso--info span { color: #15803d; }

/* ─── Sección ─── */
.rg-seccion {
  margin-bottom: 2rem;
}
.rg-seccion__titulo {
  display: flex; align-items: center; gap: 0.5rem;
  font-size: 1rem; font-weight: 800; color: #111827;
  border-bottom: 2px solid #dcfce7; padding-bottom: 0.4rem; margin: 0 0 0.85rem;
  flex-wrap: wrap;
}
.rg-seccion__num {
  width: 22px; height: 22px; border-radius: 50%;
  background: #16a34a; color: white;
  font-size: 0.72rem; font-weight: 800;
  display: inline-flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.rg-seccion__pts {
  font-size: 0.72rem; font-weight: 600;
  background: #dcfce7; color: #15803d;
  padding: 0.15rem 0.5rem; border-radius: 20px; margin-left: auto;
}
.rg-seccion__prov {
  font-size: 0.7rem; font-weight: 400; color: #9ca3af; margin-left: 0.25rem;
}
.rg-seccion__desc {
  font-size: 0.88rem; color: #6b7280; margin: 0 0 0.85rem; line-height: 1.5;
}

/* ─── Rúbrica ─── */
.rubrica-lista {
  display: flex; flex-direction: column; gap: 0.35rem;
}
.rubrica-fila {
  display: flex; align-items: flex-start; gap: 0.75rem;
  background: white; border: 1px solid #e5e7eb; border-radius: 8px;
  padding: 0.65rem 0.85rem;
}
.rubrica-pts {
  min-width: 42px; text-align: center; font-weight: 800; font-size: 0.95rem;
  padding: 0.15rem 0.4rem; border-radius: 6px; flex-shrink: 0;
}
.rubrica-pts--100 { background: #dcfce7; color: #15803d; }
.rubrica-pts--75  { background: #d1fae5; color: #065f46; }
.rubrica-pts--50  { background: #fef9c3; color: #854d0e; }
.rubrica-pts--25  { background: #ffedd5; color: #9a3412; }
.rubrica-pts--0   { background: #fee2e2; color: #991b1b; }
.rubrica-fila__texto { display: flex; flex-direction: column; gap: 0.1rem; }
.rubrica-nivel { font-size: 0.88rem; font-weight: 700; color: #111827; }
.rubrica-desc  { font-size: 0.8rem; color: #6b7280; }

/* ─── Criterios ─── */
.criterios-grupos { display: flex; flex-direction: column; gap: 1.1rem; }
.criterios-grupo__titulo {
  font-size: 0.82rem; font-weight: 700; color: #374151;
  background: #f0fdf4; padding: 0.35rem 0.75rem; border-radius: 6px;
  border-left: 3px solid #16a34a; margin-bottom: 0.5rem;
  text-transform: uppercase; letter-spacing: 0.03em;
}
.criterios-lista { display: flex; flex-direction: column; gap: 0.4rem; }

.crit-card {
  background: white; border: 1px solid #e5e7eb; border-left: 3px solid #16a34a;
  border-radius: 10px; padding: 0.75rem 0.9rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.crit-card--lid { border-left-color: #16a34a; }
.crit-card__top {
  display: flex; align-items: flex-start; gap: 0.5rem; flex-wrap: wrap;
}
.crit-codigo {
  font-size: 0.68rem; font-weight: 800;
  background: #dcfce7; color: #166534;
  border-radius: 20px; padding: 0.1rem 0.45rem;
  white-space: nowrap; flex-shrink: 0; margin-top: 0.1rem;
}
.crit-codigo--lid { background: #dcfce7; color: #166534; }
.crit-nombre {
  font-size: 0.9rem; font-weight: 600; color: #111827; flex: 1; min-width: 0;
}

/* Días pill */
.crit-dias {
  display: flex; gap: 0.2rem; flex-shrink: 0; flex-wrap: wrap; margin-left: auto;
}
.dia-pill {
  font-size: 0.65rem; font-weight: 800;
  padding: 0.15rem 0.4rem; border-radius: 20px;
  white-space: nowrap;
}
.dia-pill--ok   { background: #dcfce7; color: #166534; }
.dia-pill--canc { background: #fee2e2; color: #991b1b; text-decoration: line-through; }

/* Detalle criterio */
.crit-card__detalle {
  margin-top: 0.5rem; padding-top: 0.45rem; border-top: 1px solid #f3f4f6;
  display: flex; flex-direction: column; gap: 0.25rem;
}
.crit-campo {
  font-size: 0.8rem; color: #374151; margin: 0; line-height: 1.4;
}
.crit-campo--no { color: #dc2626; }
.crit-campo__lbl {
  font-weight: 700; font-size: 0.7rem; color: #9ca3af;
  text-transform: uppercase; letter-spacing: .03em; margin-right: 0.35rem;
}

/* ─── Incidencias (bonus / deméritos) ─── */
.inc-lista { display: flex; flex-direction: column; gap: 0.5rem; }
.inc-card {
  background: white; border: 1px solid #e5e7eb;
  border-left: 3px solid; border-radius: 10px;
  padding: 0.75rem 0.9rem; box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
.inc-card--bonus   { border-left-color: #16a34a; }
.inc-card--demerito{ border-left-color: #dc2626; }

.inc-card__top {
  display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;
}
.inc-codigo {
  font-size: 0.68rem; font-weight: 800;
  border-radius: 20px; padding: 0.1rem 0.45rem;
  white-space: nowrap; flex-shrink: 0;
}
.inc-codigo--bonus   { background: #dcfce7; color: #166534; }
.inc-codigo--demerito{ background: #fee2e2; color: #991b1b; }
.inc-nombre { font-size: 0.9rem; font-weight: 600; color: #111827; flex: 1; }
.inc-pts {
  font-size: 0.82rem; font-weight: 700; white-space: nowrap; flex-shrink: 0;
}
.inc-pts--bonus   { color: #15803d; }
.inc-pts--demerito{ color: #dc2626; }

.inc-card__detalle {
  margin-top: 0.5rem; padding-top: 0.45rem; border-top: 1px solid #f3f4f6;
  display: flex; flex-direction: column; gap: 0.25rem;
}
.inc-tope {
  font-size: 0.78rem; color: #15803d; font-weight: 600;
  background: #f0fdf4; border-radius: 6px; padding: 0.25rem 0.5rem; margin: 0;
  display: flex; align-items: center; gap: 0.3rem;
}
.inc-expulsion {
  font-size: 0.78rem; color: #dc2626; font-weight: 600;
  background: #fef2f2; border-radius: 6px; padding: 0.25rem 0.5rem; margin: 0;
  display: flex; align-items: center; gap: 0.3rem;
}

/* ─── Medallas ─── */
.medallas-lista {
  display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem;
}
@media (min-width: 480px) {
  .medallas-lista { grid-template-columns: repeat(4, 1fr); }
}
.medalla-card {
  background: white; border: 1px solid #e5e7eb;
  border-left: 4px solid; border-radius: 10px;
  padding: 0.75rem; display: flex; align-items: center; gap: 0.6rem;
  box-shadow: 0 1px 3px rgba(0,0,0,.05);
}
@media (min-width: 480px) {
  .medalla-card { flex-direction: column; align-items: flex-start; gap: 0.3rem; }
}
.medalla--oro    { border-left-color: #d97706; }
.medalla--plata  { border-left-color: #64748b; }
.medalla--bronce { border-left-color: #92400e; }
.medalla--part   { border-left-color: #6b7280; }
.medalla-emoji   { font-size: 1.4rem; flex-shrink: 0; }
.medalla-info    { display: flex; flex-direction: column; gap: 0.1rem; }
.medalla-nombre  { font-weight: 700; font-size: 0.88rem; color: #111827; }
.medalla-rango   { font-size: 0.75rem; color: #6b7280; }

/* ─── Hito ─── */
.hito-card {
  display: flex; align-items: flex-start; gap: 0.75rem;
  background: #fff7ed; border: 1px solid #fed7aa;
  border-left: 4px solid #fb923c; border-radius: 10px;
  padding: 1rem;
}
.hito-card__icon { color: #ea580c; font-size: 1.1rem; flex-shrink: 0; margin-top: 0.1rem; }
.hito-titulo { display: block; font-weight: 700; font-size: 0.9rem; color: #111827; margin-bottom: 0.3rem; }
.hito-desc   { font-size: 0.85rem; color: #374151; line-height: 1.5; margin: 0; }
</style>
