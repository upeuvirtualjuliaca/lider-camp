# Vista: Evaluar (/panel/evaluar) — web, tablet y celular

Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral / rail / barra inferior): el mismo que ya se aplicó en Inicio (`docs/diseno/inicio-panel.md`).
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas
| Tamaño | Por equipo | Por criterio |
|---|---|---|
| Web ≥ 1280 px | `EvaluarWebEquipo.dc.html` | `EvaluarWebCriterio.dc.html` |
| Tablet 768–1279 px | `TabletEquipo.dc.html` | `TabletCriterio.dc.html` |
| Celular < 768 px — lista | `Main.dc.html` | `Criterios.dc.html` |
| Celular < 768 px — calificar | `Calificar.dc.html` | `CalificarCriterio.dc.html` |

## Estructura
- **Web**: menú lateral blanco (Evaluar activo) + barra superior con "Evaluación / Evaluar", selector de días (J, V, S, D con "Hoy" y % de avance) y pestaña segmentada Por equipo / Por criterio, todo en UNA fila. Debajo: panel de lista (320–360 px, tarjeta blanca) + panel de detalle. Tarjetas de calificación en `grid-template-columns: repeat(auto-fill, minmax(300px, 1fr))` (2–3 columnas según ancho).
- **Tablet**: rail de 88 px + encabezado de 72 px con días y pestaña segmentada; lista de 340 px + detalle con tarjetas en 2 columnas.
- **Celular**: encabezado con título **"Evaluar"** (hoy dice "Inicio" por error), días en 3 columnas, pestañas con subrayado; navegación lista → pantalla de calificar con botón volver; barra inferior.
- Web y tablet son lista + detalle: seleccionar en la lista cambia el detalle sin cambiar de pantalla. Guarda el día, modo e ítem seleccionado en la URL (`?dia=J&modo=criterio&id=...`).

## Cambios respecto a la versión actual
1. Quitar el rótulo "DÍA A EVALUAR" y el título repetido del día ("Jue 5 nov").
2. Quitar el borde lateral amarillo de las tarjetas y la barra de progreso casi invisible: usar etiqueta de estado (Completo / En curso / Sin empezar) + anillo de progreso.
3. Por criterio: agrupar por categoría con un título por grupo; NO repetir la etiqueta "ARMADO" en cada fila.
4. Criterios no programados ese día (hoy aparecen grises con "N/A"): sacarlos de la lista y mostrarlos al final en un bloque plegable "No se evalúan hoy · N" (`<details>`).
5. Botones de nota: 5 niveles desde `puntaje_max` (0 · 12,5 · 25 · 37,5 · 50 para máx. 50), todos neutros y el elegido en verde. Quitar los colores rojo/naranja/amarillo/azul/verde por nota. Descriptor de la rúbrica debajo.
6. Estado por tarjeta: "Guardado" (verde) / "Pendiente" (gris) en lugar del punto amarillo.
7. "Comentario": botón de ícono (web/tablet) o texto con ícono (celular) que abre el comentario existente.
8. Navegación: "Anterior" / "Siguiente: <equipo>" (Por equipo) y "Siguiente criterio: <nombre>" (Por criterio).
9. Calificar un criterio: mostrar "Máx. N", progreso "X de 12 equipos" y abarca / no abarca (desplegable en celular, siempre visible en web/tablet).
10. Liderazgo (Módulo 6) usa las mismas tarjetas con sus 4 indicadores; asistencia sigue en su propia pantalla.

## Estados
- Día cerrado: aviso arriba "Este día está cerrado: solo lectura" y botones de nota deshabilitados (`opacity-60`, sin cursor).
- Cargando: esqueletos con la forma de las filas y tarjetas.
- Error al guardar: la etiqueta de la tarjeta cambia a "Error · Reintentar" (`bg-warn-bg text-warn`) y es un botón.
