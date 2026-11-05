# Vista: Inicio del panel (/panel) — web, tablet y celular

Maquetas: `docs/diseno/InicioWeb.dc.html` (≥ 1280 px), `docs/diseno/InicioTablet.dc.html` (768–1279 px), `docs/diseno/InicioMovil.dc.html` (< 768 px).
Estilo general: `docs/diseno/guia-estilo-movil.md` (colores, tipografía, radios, etiquetas, anillo de progreso).
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los números de las maquetas son de ejemplo.

## Layout por tamaño
- **Web ≥ 1280 px**: menú lateral BLANCO de 264 px (reemplaza el lateral verde). Logo verde + "LiderCamp / 2026-II"; ítem activo `bg-ok-bg text-ok`; títulos de grupo (EVALUACIÓN, SEGUIMIENTO, DATOS) en 11px mayúsculas; tarjeta de usuario abajo con borde, avatar, nombre, rol y botón cerrar sesión. Barra superior blanca de 64 px: migas ("Inicio") a la izquierda; fecha y estado de conexión ("En línea" en píldora verde) a la derecha. Contenido centrado `max-w-[1120px] p-8`.
- **Tablet 768–1279 px**: menú lateral compacto (rail) de 88 px con íconos + texto de 11px, avatar abajo. Sin barra superior; el saludo va arriba del contenido. Resumen en 3 columnas y abajo 2 columnas (Pendientes | Actividades).
- **Celular < 768 px**: encabezado blanco (menú · "Inicio" · avatar), tarjeta verde de avance con el botón blanco "Continuar evaluando", 2 tarjetas pequeñas (mis notas, mis incidencias), lista de 3 pendientes, "Próxima actividad" y barra de navegación inferior (Inicio, Evaluar, Actividades, Incidencias según rol).
- Los grupos del menú se mantienen según el rol actual (admin ve más ítems).

## Bloques y de dónde salen los datos (todo ya existe en la BD)
1. **Saludo**: "Buenos días / Buenas tardes / Buenas noches, <primer nombre>" según la hora; sobretítulo "Día N de 4 · Campamento en curso" calculado con las fechas de `campamento` (antes del jueves: "Faltan X días"; después del domingo: "Campamento finalizado"). Subtítulo: "Tienes X notas pendientes hoy" (desde `v_progreso_evaluacion` del día actual). Si el campamento está cerrado o el día está cerrado, mostrar ese aviso en lugar del subtítulo.
2. **Botón "Continuar evaluando"** → `/panel/evaluar` con el día actual seleccionado.
3. **Avance del día**: anillo con % y "X de Y" (`v_progreso_evaluacion`).
4. **Mis notas de hoy**: cantidad de observaciones + liderazgo con `evaluador_id = yo` del día actual; línea "Última: <criterio> · <equipo>, hace N min".
5. **Mis incidencias**: incidencias con `registrado_por = yo`; línea con cuántas están en descargo o registradas.
6. **Pendientes de hoy**: criterios de rúbrica/liderazgo programados hoy con equipos sin nota, ordenados por más pendientes; máximo 5 (3 en celular); cada fila lleva a calificar ese criterio. "Ver todo" → Evaluar en modo Por criterio.
7. **Actividades de hoy** (web y tablet) / **Próxima actividad** (celular): tabla `actividades` del día, ordenadas por hora, con estado Realizada (verde) / En curso o próxima (ámbar, hora en verde) / Programada (gris) / Cancelada (tachado gris).
8. **Días del campamento** (solo web): 4 casillas J–D con su estado de `dias_evaluacion`: Abierto (borde y fondo verde claro) / Cerrado / Publicado / Próximo.
- Para admin: mismos bloques; "Mis notas" puede cambiarse por "Incidencias por validar" (bandeja) — usa el mismo diseño de tarjeta.

## Estados vacíos y carga
- Cargando: esqueletos grises (`bg-idle-bg animate-pulse`) con la misma forma de cada tarjeta.
- Sin pendientes: tarjeta con check verde "¡Todo calificado por hoy!".
- Sin actividades: "No hay actividades programadas hoy".
- Quitar el aviso "Módulos en construcción".
