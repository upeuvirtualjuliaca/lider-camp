# LiderCamp 2026-II — Contexto permanente del proyecto

App web que reemplaza la ficha Excel de evaluación del campamento universitario LiderCamp.
Los evaluadores registran observaciones diarias por equipo (jueves a domingo), asistencias,
liderazgo, bonus y deméritos. El sistema calcula el puntaje de cada equipo, lo convierte a
escala 1-1000, asigna medalla y publica un ranking en tiempo real.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Vue 3 + Composition API + `<script setup lang="ts">`, Vite, TypeScript |
| Estado | Pinia |
| Rutas | Vue Router |
| Backend / DB | Supabase: Postgres, Auth, RLS, Storage (evidencias), Realtime (ranking) |
| Cliente Supabase | `@supabase/supabase-js` v2 |
| UI | PrimeVue, diseño mobile-first (evaluadores usan celular en campo) |
| Variables de entorno | `.env.local` — `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (nunca a git) |

## Comandos CLI de Supabase

```bash
# Aplicar migraciones (el --linked da 403 en free tier, usar --db-url)
npx supabase db push --db-url "postgresql://postgres.arnxtzamayflzptlkwxy:PASSWORD@aws-0-us-east-2.pooler.supabase.com:5432/postgres"

# Regenerar tipos TypeScript
npx supabase gen types typescript --db-url "postgresql://postgres.arnxtzamayflzptlkwxy:PASSWORD@aws-0-us-east-2.pooler.supabase.com:5432/postgres" > src/types/database.ts
```

---

## Estructura de directorios

```
src/
  lib/
    supabase.ts          ← cliente único de Supabase
  types/
    database.ts          ← tipos generados con `supabase gen types typescript`
  modules/
    <modulo>/
      views/
      components/
      composables/
      services/
      store.ts
  components/
    ui/                  ← componentes compartidos
  router/
supabase/
  migrations/            ← un .sql por cambio: YYYYMMDDHHMM_descripcion.sql
  seed.sql
docs/
  Guia_Lidercamp_2026-II.docx   ← guía oficial del campamento
```

---

## Reglas de trabajo

1. **Módulo por módulo.** No adelantar módulos que no se han pedido.
2. **Flujo por módulo:**
   - (a) Proponer tablas, columnas, relaciones y políticas RLS → **esperar aprobación**
   - (b) Escribir la migración SQL
   - (c) Regenerar tipos con `supabase gen types`
   - (d) Services → composables/store → componentes → vistas → rutas
   - (e) Explicar cómo probarlo
3. **Las reglas de puntaje viven en la base de datos** (CHECK, funciones y vistas SQL), no en el frontend.
4. Toda tabla con **RLS activado**. Nunca usar `service_role` key en el frontend.
5. Tablas y columnas en **español, snake_case, sin tildes**. PK `uuid` con `gen_random_uuid()`, `created_at` y `updated_at`.
6. Toda tabla con puntajes guarda `evaluador_id` y tiene **auditoría por trigger** (alterar registros es un demérito D5).
7. **Componentes nunca llaman a Supabase directamente**: siempre a través de services.
8. Interfaz en español. **No instalar dependencias sin decirle al usuario para qué sirven.**
9. Si una regla de negocio no está clara, **preguntar; no inventar**.

---

## Roles y acceso

### Usuarios con login (email + contraseña)

El admin crea los usuarios desde el **dashboard de Supabase** y les entrega las credenciales.
No hay pantalla de registro público.

| Rol | Permisos |
|-----|---------|
| `admin` | Configura equipos, criterios y programación; valida incidencias; publica resultados; gestiona usuarios |
| `evaluador` | Registra observaciones, asistencias, liderazgo e incidencias; no valida |

### Sección pública (estudiantes — rol `anon`, sin login)

Los estudiantes NO tienen cuenta. Acceden a rutas públicas sin autenticación.

**Pueden ver:**
- Ranking: posición, equipo, puntaje escala 1000, medalla
- Ficha de su equipo: puntaje por criterio y día, totales de bonus y deméritos
- Calendario de evaluación
- Reglas: rúbrica, medallas, bonus y deméritos
- Avisos publicados por el admin

**No pueden ver:**
- Descripción ni evidencia de deméritos (solo código y puntos)
- Incidencias no validadas
- Nombre de evaluadores
- Comentarios internos
- Auditoría
- Resultados no publicados por el admin

**Reglas de implementación pública:**
- El rol `anon` nunca consulta tablas directamente: solo vistas o funciones SQL de solo lectura con `GRANT SELECT` a `anon`
- Las vistas públicas devuelven únicamente datos validados y publicados
- El admin controla la publicación de resultados por día (campo `publicado` en la programación)

### Estructura de rutas

| Tipo | Rutas |
|------|-------|
| Públicas (anon) | `/`, `/ranking`, `/equipo/:id`, `/calendario`, `/reglas` |
| Login | `/login` |
| Privadas (admin + evaluador) | `/panel` y subrutas |

---

## Reglas de negocio

### Días del campamento
J (jueves), V (viernes), S (sábado), D (domingo).
Días no programados = N/A → no cuentan en el máximo.

### Puntaje base máximo: 5200
- Inscripción: 100 pts
- Criterios del calendario: 4700 pts (ver tabla de criterios)
- Liderazgo: 400 pts (4 indicadores × 25 × 4 días)

> **PENDIENTE:** Los días listados suman ~5000, no 4700. Falta el calendario oficial.

### Criterios y días programados

| Criterio | Días |
|----------|------|
| Carpas | J, V, S |
| Cerco | J, V, S, D |
| Basurero | J, V, S, D |
| Tendedero | J, V, S |
| Portada | V, S |
| Orden y limpieza interior | J, V, S, D |
| Orden y limpieza exterior | J, V, S, D |
| Cocina y orden | J, V, S, D (máx. 5 personas a la vez) |
| Cocina y limpieza | J, V, S |
| Cocina y menú | J, V, S (ovo-lacto-vegetariano) |
| Cocina y uniforme | **PENDIENTE** — días por definir |
| Izamiento | V, S |
| Barras de la mañana | J, V, S, D |
| Barras de la noche | J, V, S |
| Programa estelar | J, V, S, D |
| Participación en eventos | J, V, S |

### Rúbrica de observaciones
Solo valores: `0, 25, 50, 75, 100`.

### Inscripción (100 pts máx.)
```
(inscritos_hasta_19oct × 100 + inscritos_20_21oct × 50) / nomina
```
Inscripción posterior al 21 oct aporta 0.

### Asistencia a estelar y eventos
```
min(100, asistentes / convocados_elegibles / 0.95 × 100)
```
`convocados_elegibles` excluye ausencias **justificadas y documentadas**.
Varias actividades en un día → promedio simple diario.

### Liderazgo
4 indicadores de hasta 25 pts por día = 100 pts/día × 4 días = 400 pts máx.
> **PENDIENTE:** Los otros 3 indicadores de liderazgo (solo se conoce 1).

### Actividad cancelada
Ningún equipo pierde puntos. Se reprograma o se ajusta el máximo para todos.

### Bonus (solo cuentan si `validado = true`)

| Código | Descripción | Pts por acción | Tope individual |
|--------|-------------|---------------|-----------------|
| B1 | Servicio extraordinario | 25 | 50 |
| B2 | Cooperación entre equipos | 25 | 50 |

Tope global de bonus: **200 pts**.

### Deméritos (se registran positivos y se restan; sin tope; resultado ≥ 0)

| Código | Descripción | Pts |
|--------|-------------|-----|
| D1 | Ruido tras advertencia | 10 |
| D2 | Usar recursos de otro equipo | 20 |
| D3 | Burla, insulto o exclusión | 30 |
| D4 | Incumplir instrucción de seguridad | 50 |
| D5 | Alterar evidencias o puntajes | 100 |
| D6 | Alcohol | 500 por persona + expulsión |

Un solo demérito por episodio; no descontar dos veces el mismo hecho.

### Campos obligatorios en incidencias
`fecha`, `hora`, `tipo` (bonus/demérito), `codigo`, `hecho`, `evidencia`, `puntos`, `evaluador_id`, `validado` (bool).

### Puntaje final (escala 1000)
```sql
max(0, min(1000, (base_obtenida + bonus - demeritos) / 5200.0 * 1000))
```

### Medallas
> **PENDIENTE:** Confirmar si usan puntos brutos (base 5200) o la escala 1000.

| Medalla | Rango (provisional — escala bruta) |
|---------|-----------------------------------|
| Oro | > 5000 |
| Plata | 4000 – 4999 |
| Bronce | 3000 – 3999 |
| Participación | 0 – 2999 |

---

## Pendientes por confirmar (no asumir)

- [ ] El calendario oficial con los puntos exactos por criterio (actuales suman ~5000, no 4700).
- [ ] Días programados para "Cocina y uniforme".
- [ ] Los 3 indicadores de liderazgo restantes.
- [ ] Si la app debe funcionar offline (PWA con cola de sincronización).
- [ ] Si las medallas usan puntos brutos (5200) o la escala 1000.

---

## Convención de seeders

- Datos de prueba en `supabase/seed.sql` (excluido de git).
- Cada módulo agrega sus integrantes/datos al bloque correspondiente en `seed.sql`.
- Las migraciones **no insertan datos de prueba**; solo crean schema y datos de configuración obligatorios (como campamento).
- Aplicar con: `npx supabase db push --include-seed --db-url "..."`
- El seed es idempotente vía `ON CONFLICT ... DO NOTHING` en todas las tablas.

---

## Plan de módulos

| # | Módulo | Estado |
|---|--------|--------|
| 1 | **Base y autenticación** — cliente Supabase, login, perfiles, roles, guard de rutas, layout | **Completado** |
| 2 | **Equipos e inscripción** — equipos, integrantes, cálculo de inscripción | **Completado** |
| 3 | **Criterios y programación** — criterios y programación (criterio × día × máximo × estado) | **Completado** |
| 4 | **Observaciones diarias** — pantalla rápida de evaluación en celular | **Completado** |
| 5 | **Asistencia y participación** — actividades, asistencias y fórmula del 95 % | **Completado** |
| 6 | **Liderazgo** — 4 indicadores por día | **Completado** (indicadores provisionales L1–L4) |
| 7 | **Incidencias** — bonus y deméritos, evidencia en Storage, bandeja de validación | **Completado** |
| 8 | **Puntajes y ranking** — vistas SQL de cálculo, ficha por equipo, ranking en vivo con medallas | **Completado** (medallas provisionales base 5200) |
| 9 | **Auditoría y reportes** — historial de cambios, exportar a Excel y PDF | **Completado** |
