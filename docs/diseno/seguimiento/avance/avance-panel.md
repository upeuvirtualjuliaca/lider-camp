# Módulo: Avance (menú Seguimiento > Avance) — web, tablet y celular

Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral blanco / rail / barra inferior): el mismo de los módulos anteriores.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Tamaño | Archivo | Contenido |
|---|---|---|
| Web ≥ 1280 px | `AvanceWeb.dc.html` | resumen + estado del día + matriz agrupada criterios × equipos |
| Tablet 768–1279 px | `AvanceTablet.dc.html` | encabezado compacto + matriz con iniciales (12 equipos caben sin scroll) |
| Celular < 768 px | `AvanceMovil.dc.html` | resumen + pestañas Por criterio (tiras de 12 casillas) / Por equipo |

## Cambios respecto a la versión actual
1. Barra superior: "Seguimiento / Avance de evaluación" (hoy dice "Inicio").
2. Días en la barra superior (Jue 5 · Hoy, Vie 6, Sáb 7, Dom 8), botones compactos como en los demás módulos.
3. Resumen: anillo con %, "X de Y" y "N pendientes". El 0 % NO va en rojo (no es un error).
4. Estado del día: etiqueta "Abierto · se puede calificar" (o "Cerrado") + botón **Cerrar día** con contorno oscuro (no naranja) y texto de ayuda "Al cerrar, los evaluadores ya no podrán editar…". Si hay pendientes, la confirmación debe decir cuántos quedan. Cuando está cerrado: botón "Reabrir día" y etiqueta gris con candado. Quitar el botón suelto "Día abierto".
5. **Matriz agrupada por categoría** (Armado, Orden y cocina, Ceremonias y conducta, Liderazgo, Actividades, Ajustes validados), cada grupo con encabezado plegable que muestra "X de Y" y una barra de progreso.
6. Encabezado de columnas: iniciales del equipo en su color (nombre completo en `title`/tooltip) + % de avance del equipo debajo. Así no se cortan los nombres ("Administ…").
7. Primera columna fija (sticky) con el nombre del criterio y "máx. N"; última columna "Avance" con "X/12".
8. Celdas:
   - Calificado: la NOTA en verde sobre `bg-ok-bg` (hoy la celda solo se pinta, sin número).
   - Pendiente: celda ámbar claro vacía.
   - No se evalúa hoy: "—" en gris claro; el criterio muestra "no se evalúa hoy" (en vez de toda la fila con guiones sin explicación).
   - Cancelado: "×" sobre `bg-bad-bg`.
9. Actividades: una fila por actividad con el **subtotal del equipo** (ej. 260 de 400), no guiones.
10. Ajustes validados: filas Bonus (+N verde) y Deméritos (−N rojo).
11. Fila "Total del día" en gris claro (`bg-segment`), texto oscuro en negrita (no la barra azul oscura actual).
12. Quitar los números de fila (1, 2, 3…).

## Celular
- Pestañas "Por criterio" / "Por equipo".
- Por criterio: grupos con título; cada criterio con "X/12" y una tira de 12 casillas (verde calificado, ámbar pendiente, gris no aplica). Leyenda al final.
- Por equipo: lista de equipos con iniciales, "X/Y calificados · N pts" y anillo de %. Tocar un equipo puede llevar a Evaluar › Por equipo de ese equipo.
- Botón "Cerrar día" fijo abajo (solo admin).

## Permisos y estados
- Solo admin ve "Cerrar día / Reabrir día". El evaluador ve el avance en solo lectura (si hoy tiene acceso).
- Cargando: esqueletos de la matriz. Día sin criterios: "No hay criterios programados este día".
