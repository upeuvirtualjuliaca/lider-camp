# Módulo: Incidencias (menú Evaluación > Incidencias) — web, tablet y celular

Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral blanco / rail / barra inferior): el mismo de Inicio, Evaluar y Actividades.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Tamaño | Archivo | Contenido |
|---|---|---|
| Web ≥ 1280 px | `IncidenciasWeb.dc.html` | resumen + lista + panel de detalle con validar/rechazar |
| Web ≥ 1280 px | `IncidenciaNuevaWeb.dc.html` | registrar en UNA página (4 secciones) + resumen lateral |
| Tablet 768–1279 px | `IncidenciasTablet.dc.html` | lista (460 px) + detalle |
| Celular < 768 px | `IncidenciasMovil.dc.html` | resumen, filtros, lista y botón flotante "Registrar" |
| Celular | `IncidenciaNuevaMovil.dc.html` | asistente de 4 pasos (Tipo y código → Equipo → Detalles → Confirmar) |

## Colores propios de este módulo (añadir al tema)
- Demérito / rechazada: `--color-bad-bg: #FDECEC; --color-bad: #A3261F;`
- Aviso "Por validar": fondo `#FFF8EA`, borde `#F3DDAE`, texto `#7A4F00` (warn).
- Bonus: los verdes `ok` ya existentes.

## Lista
- Barra superior web: "Evaluación / Incidencias" (hoy dice "Inicio") + días (Todos, Jue 5 · Hoy, Vie 6, Sáb 7, Dom 8) + botón "Registrar incidencia".
- Días: solo los del campamento (quitar "Mié 4"). "Todos" muestra todo el campamento.
- Resumen: 3 tarjetas → **Bonus validados** (+N, "X de Y registrados"), **Deméritos validados** (−N), **Por validar** (ámbar; para evaluadores puede decir "Mis pendientes").
  Los totales cuentan SOLO incidencias validadas (hoy "3 bonus +25 pts" confunde).
- Filtros: chips Todas · Bonus · Deméritos · Por validar (con contador) + selector de equipo.
- Fila: cuadro del código (B1 verde / D1 rojo) · equipo + hora (HH:mm, no ISO) · hecho (2 líneas máx.) · etiqueta de estado · puntos (+25 verde, −10 rojo; gris si rechazada).
- Estados: Registrada (gris) · En descargo (ámbar) · Validada (verde) · Rechazada (rojo). Sin borde lateral de color en las tarjetas.
- Web y tablet: lista + detalle; el seleccionado con fondo verde claro. Celular: tocar la fila abre el detalle en otra pantalla (mismo contenido que el panel web).

## Detalle
- Código + nombre del código + estado; datos en mini-tarjetas: Equipo, Puntos, Fecha y hora, Registró.
- Hecho, evidencia (foto en miniatura, se abre grande), campo "Descargo del equipo".
- Solo admin: botones **Rechazar** (pide motivo) y **Validar incidencia**, con la lista de verificación del Módulo 7 antes de validar. Texto de ayuda: "Solo el administrador valida o rechaza. Antes de validar, escucha al equipo."
- Evaluador: el detalle en solo lectura (puede editar mientras esté Registrada o En descargo).

## Registrar
- **Web**: una sola página con 4 secciones numeradas (1 Tipo y código · 2 Equipo · 3 ¿Qué pasó?) y un **resumen fijo a la derecha** con los puntos y el botón "Registrar incidencia". No usar el asistente centrado con mucho espacio vacío.
- **Celular**: asistente de 4 pasos con barra de progreso de 4 segmentos, "Paso N de 4 · Nombre", botón cerrar (X) y pie fijo Anterior / Siguiente (en el paso 4: "Registrar incidencia").
- **Paso Tipo y código**: dos tarjetas grandes Bonus / Demérito y debajo la lista de códigos (B1, B2 o D1–D6) con nombre, ayuda y puntos. Mostrar cuántos B1/B2 lleva usados el equipo ("Usados 1 de 2").
- **Equipo**: cuadrícula de equipos con iniciales y color (no un `<select>`).
- **Detalles**: "Descripción del hecho" (no "Nombre / Tipo de incidencia"), fecha y hora (con valor actual), evidencia con botón de cámara. Campos extra según el código: B2 → equipo apoyado; D1 → advertencia previa; D6 → personas involucradas.
- **Puntos**: los fija el código y se muestran en solo lectura ("Puntos según el código B1: +25"). Quitar los botones 12.5 / 25 / 50 si la regla del Módulo 7 sigue vigente (los puntos los calcula el trigger). Si la coordinación decidió permitir elegir puntos, conservar el control actual con el mismo estilo de botones neutros.
- **Confirmar**: lista de datos con separadores y la etiqueta "Quedará Registrada, pendiente de validación".

## Estados
- Cargando: esqueletos. Lista vacía: "No hay incidencias este día". Error al guardar: mensaje bajo el botón y conservar lo escrito.
- Día cerrado: botón Registrar deshabilitado para evaluadores con aviso.
