# Módulo: Ranking interno (menú Seguimiento > Ranking) — web, tablet y celular

Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral blanco / rail / barra inferior): el mismo de los módulos anteriores.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Tamaño | Archivo | Contenido |
|---|---|---|
| Web ≥ 1280 px | `RankingWeb.dc.html` | pestañas Total / días · podio de 3 · tabla con barra de composición |
| Tablet 768–1279 px | `RankingTablet.dc.html` | podio en fila · tabla con Rúbrica, Actividades, Ajustes, Total |
| Celular < 768 px | `RankingMovil.dc.html` | podio compacto · lista con detalle desplegable por equipo |
Las 3 maquetas son interactivas: la pestaña "Total" muestra el estado bloqueado, "Jue 5" muestra datos y Vie–Dom el estado vacío.

## Cambios respecto a la versión actual
1. Barra superior: "Seguimiento / Ranking interno" (hoy dice "Inicio") + etiqueta "No visible para estudiantes" (deja claro que es interno; el público ve solo lo publicado).
2. Pestañas: Total · Jue 5 · Hoy · Vie 6 · Sáb 7 · Dom 8 + botón actualizar con la hora de la última actualización.
3. **Total bloqueado**: en vez de un candado suelto en una pantalla vacía, una tarjeta con explicación ("El ranking total se calcula al cerrar el campamento"), progreso "Días cerrados: X de 4" (barra de 4 segmentos) y botón "Ver ranking del <día>" que lleva al último día con datos. Mantén la lógica actual que bloquea el total.
4. **Podio** de los 3 primeros (web: 2°–1°–3° con el 1° más alto y resaltado; tablet: en fila; celular: 3 tarjetas pequeñas).
5. **Tabla compacta** en lugar de una tarjeta enorme por equipo: Pos. · Equipo (iniciales con color) · Composición (barra apilada rúbrica/actividades/bonus, solo web) · Rúbrica · Actividades · Bonus · Deméritos · Total. En tablet "Ajustes" = bonus − deméritos. En celular: fila con posición, equipo y total; al tocar se despliegan 4 mini-tarjetas (Rúbrica, Actividades, Bonus, Deméritos).
6. **Empates**: comparten posición (RANK de SQL) y se marcan con "=" (ej. "5° ="). Hoy aparecen 1°, 2°, 3°… con 0 pts todos.
7. **Sin puntajes todavía**: si todos tienen 0 o no hay notas del día, mostrar el estado vacío "Aún no hay puntajes para este día" en lugar de un ranking de ceros.
8. Bonus en verde (+25), deméritos en rojo (−10), ceros en gris.
9. Nota al pie: "Los empates comparten posición. Total = rúbrica + actividades + bonus − deméritos (solo validados)."

## ⚠ Revisar en la lógica (no es solo diseño)
En la captura actual, Educación tiene "+ Bonus 25" pero su total es **0 pts**: parece que el total del día no está sumando los bonus validados. Antes de aplicar el diseño, verifica el cálculo del total y avísame si es un error.

## Estados
- Cargando: esqueletos del podio y de la tabla.
- Total bloqueado / día sin datos: los descritos arriba.
