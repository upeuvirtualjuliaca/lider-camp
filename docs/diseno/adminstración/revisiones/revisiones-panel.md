# Módulo: Revisiones (menú Administración > Revisiones) — web, tablet y celular

Bandeja del administrador para validar o rechazar incidencias (bonus y deméritos).
Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral blanco / rail / barra inferior): el mismo de los módulos anteriores.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Tamaño | Archivo | Contenido |
|---|---|---|
| Web ≥ 1280 px | `RevisionesWeb.dc.html` | pestañas con contador · filtros · bandeja + panel de revisión al lado |
| Tablet 768–1279 px | `RevisionesTablet.dc.html` | bandeja (420 px) + panel de revisión |
| Celular < 768 px | `RevisionesMovil.dc.html` | pestañas subrayadas · lista |
| Celular | `RevisionDetalleMovil.dc.html` | pantalla completa de revisión con acciones fijas abajo |
Las maquetas son interactivas: cambia de pestaña, selecciona incidencias y marca las verificaciones.

## Cambios respecto a la versión actual
1. Barra superior: "Administración / Revisiones" (hoy dice "Inicio").
2. Pestañas segmentadas (celular: subrayadas) con contador en TODAS, incluida Pendientes; el contador de Pendientes en verde sólido cuando hay pendientes. El mismo número aparece como insignia junto a "Revisiones" en el menú lateral.
3. Filtros: Día, Equipo y Tipo (bonus / deméritos).
4. Fila: código (B verde / D rojo) · equipo · día y hora "Jue 5 · 09:13" (no ISO) · hecho · etiqueta de estado · puntos. Sin borde lateral de color.
5. **Puntos de una incidencia rechazada**: en gris y tachados (hoy salen "+25 pts" en verde como si sumaran).
6. **Panel de revisión al lado** (web/tablet) en lugar de un modal; en celular, pantalla completa.
7. Panel para pendientes (Registrada / En descargo):
   - código + nombre del código + estado; mini-tarjetas Puntos, Alcance, Registró; hecho y miniatura de evidencia (se amplía al tocar).
   - campo "Descargo del equipo".
   - **Lista de verificación** (4 casillas): Se escuchó al equipo · Es un solo código por episodio · No se descontó antes en otro ítem · Es atribuible al equipo. "Validar incidencia" queda deshabilitado hasta marcar las 4 (texto de ayuda: "Verificaciones: X de 4").
   - "Rechazar…" abre un diálogo que pide el motivo (obligatorio).
8. Panel para resueltas: caja verde "Validada · suma al puntaje" o roja "Rechazada · no suma puntos" con el motivo, quién y cuándo resolvió, y botón "Reabrir revisión (con motivo)" (queda en auditoría).
9. Estado vacío de Pendientes: "Todo al día · No hay incidencias esperando revisión."
10. Celular: acciones Rechazar / Validar fijas en el pie; encabezado "Revisar incidencia · 1 de 2 pendientes"; al validar o rechazar, pasar automáticamente a la siguiente pendiente.

## Permisos y estados
- Solo admin accede a este módulo.
- Cargando: esqueletos de lista y panel. Error al validar: mensaje bajo los botones y no perder lo escrito.
