# Página pública (estudiantes): Inicio y Ranking oficial — web, tablet y celular

Rutas públicas sin login: `/` (inicio) y `/ranking`. Las demás públicas (`/calendario`, `/reglas`, `/equipo/:id`) siguen este mismo estilo.
Estilo general: `docs/diseno/guia-estilo-movil.md`. Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Archivo | Contenido |
|---|---|
| `InicioPublicoWeb.dc.html` | Inicio público fluido (web ≥ 1024 px y tablet 768–1023 px: el mismo diseño se reacomoda con flex-wrap y grids auto-fit) |
| `InicioPublicoMovil.dc.html` | Inicio público en celular (< 768 px) |
| `RankingPublicoWeb.dc.html` | Ranking oficial fluido (web y tablet) |
| `RankingPublicoMovil.dc.html` | Ranking oficial en celular |
En tablet: mismo diseño que web; el héroe pasa a una columna (texto arriba, tarjeta Top 3 debajo a lo ancho), "Hoy" y "Próxima actividad" se apilan, pasos en 2 columnas y medallas en 2 columnas.

## Colores extra (solo públicas)
- Fondo oscuro de héroe y pie: `#10261D`.
- Acento dorado "Edición Victoria" y 1.er puesto: texto `#F2C14E` (sobre oscuro), fondo `#F6E3A3`, borde `#C99A1E`, texto oscuro `#6B4E0A`.
- Medallas: Oro `#F6E3A3`/`#C99A1E`, Plata `#E6E9EC`/`#9AA3AB`, Bronce `#F1D2B8`/`#B06A35`, Participación `#E1F3EA`/`#5FAF8A`.

## Inicio público — estructura
1. **Encabezado blanco fijo**: logo + "LiderCamp 2026-II" · enlaces Ranking, Calendario, Reglas · botón "Ingresar" en contorno (secundario). En celular: logo, "Ingresar" y menú hamburguesa.
2. **Héroe**: video/foto aérea con **overlay NEGRO al ~55 %** (no verde; el verde actual lava la imagen). Texto alineado a la izquierda:
   - píldora de estado "En curso · Día 2 de 4 · Viernes 6 de noviembre" (antes del campamento: "Faltan X días"; después: "Campamento finalizado").
   - sobretítulo "Edición Victoria" en dorado (reemplaza la tipografía manuscrita, difícil de leer).
   - título grande "Creados para grandes hazañas".
   - texto corto + botones "Ver ranking" (blanco) y "¿Qué se evalúa hoy?" (contorno).
   - a la derecha (web), **tarjeta Top 3** con lo publicado ("Publicado hasta el jueves") y "Ver las 12 escuelas". Si aún no hay nada publicado: "Los resultados se publicarán durante el campamento".
3. **Hoy en el campamento**: chips de criterios que se evalúan hoy (de `publico_calendario`) + tarjeta "Próxima actividad" (hora, nombre, lugar). Fuera de los días del campamento, ocultar esta sección.
4. **¿Cómo se gana LiderCamp?**: 4 pasos numerados (Criterios diarios · Liderazgo y asistencia · Bonus y deméritos · Ranking y medallas).
5. **Medallas al cierre**: 4 tarjetas con los umbrales reales de `configuracion_medallas` + enlace "Leer todas las reglas".
6. Franja "¿Eres evaluador o administrador?" + "Ingresar al panel".
7. Pie oscuro con "LiderCamp 2026-II · Formación Cristiana II" y logo UPeU.

## Qué se elimina
- La sección "Campamentos activos" (duplicaba los mismos 3 enlaces de "¿Qué quieres ver?"). Si en el futuro hay varios campamentos activos a la vez, se vuelve a mostrar como selector.
- La sección "¿Qué quieres ver?" (los enlaces ya están en el encabezado y en el héroe).
- El carrusel de frases y la franja de estadísticas con emojis ("16+ criterios", "1000 puntos"...).

## Ranking oficial (público)
- Título "Ranking oficial" + "Resultados publicados hasta el <día> · actualizado HH:mm".
- Pestañas segmentadas: Total · <días publicados>.
- **Total bloqueado**: tarjeta "El ganador se revela al cierre" con explicación y botón "Ver el <último día publicado>" (no un candado suelto).
- **Día**: podio de 3 (1.er puesto con acento dorado, no barras de colores), luego lista de las 12 escuelas con posición, iniciales en el color del equipo, nombre COMPLETO (sin cortar) y puntos. Toca una escuela → su ficha pública.
- Empates comparten posición y se marcan con "=" (ej. "3° =").
- Nota: "Toca una escuela para ver su ficha. Los empates comparten posición (=). Solo se muestran resultados validados y publicados."

## ⚠ Revisar en la lógica (no es solo diseño)
En el ranking público actual aparece **1026 pts** cuando la escala es de 1000 (el inicio dice "1000 puntos en escala"). O el ranking muestra puntos brutos, o falta aplicar el tope `min(1000, …)`. Revísalo y dime cuál es antes de cambiar nada.
