# Módulo: Actividades (menú Evaluación > Actividades) — web, tablet y celular

Estilo general: `docs/diseno/guia-estilo-movil.md`. Layout (menú lateral blanco / rail / barra inferior): el mismo de Inicio y Evaluar.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos de las maquetas son de ejemplo.

## Maquetas (en esta carpeta)
| Tamaño | Archivo | Contenido |
|---|---|---|
| Web ≥ 1280 px | `ActividadesWeb.dc.html` | 3 columnas: actividades del día · equipos (o criterios) · calificación |
| Tablet 768–1279 px | `ActividadesTablet.dc.html` | encabezado con días + selector de actividad + modo; equipos · calificación |
| Celular < 768 px | `ActividadesMovil.dc.html` | días + tarjetas de actividades del día |
| Celular | `ActividadEquiposMovil.dc.html` | actividad elegida: pestañas Por equipo / Por criterio con listas |
| Celular | `ActividadCalificarMovil.dc.html` | calificar un equipo: 5 criterios con selector de puntaje |

## Flujo (se mantiene el actual)
Día → actividad → modo (Por equipo / Por criterio) → calificar.
- Web: todo en una pantalla (3 columnas). Elegir actividad actualiza la columna de equipos; elegir equipo actualiza la calificación.
- Tablet: la actividad se elige en un botón-selector bajo los días (abre un menú/hoja con las actividades del día); 2 columnas.
- Celular: navegación por pantallas con botón volver.
- Guarda en la URL: `?dia=&actividad=&modo=&id=`. Si el día tiene UNA sola actividad, ábrela directamente (sin la pantalla "Selecciona un día" ni la lista de una sola tarjeta).

## Cambios respecto a la versión actual
1. Barra superior web: "Evaluación / Actividades" (hoy dice "Inicio").
2. Quitar la pantalla vacía "Selecciona un día": por defecto se abre el día de hoy (o el primero con actividades).
3. Días compactos: "Jue 5 · Hoy · 1 act." en vez de tarjetas grandes con letra gigante y fecha ISO (2026-11-05). Días sin actividades: deshabilitados con "Sin act.".
4. Tarjeta de actividad: hora destacada, nombre, lugar · tipo, etiqueta de estado (Realizada verde / En curso ámbar / Programada gris / Cancelada gris tachado) y progreso "X de Y notas". Sin borde lateral de color.
5. Listas de equipos y criterios: igual que en Evaluar (iniciales con color del equipo, etiqueta de estado, "X/5 criterios · N pts", anillo de progreso). Sin borde lateral de color ni barra casi invisible.
6. **Selector de puntaje (reemplaza los 17 botones de colores 0–80)**: tarjeta por criterio con
   - valor grande en el centro "60 / 80" (o "—" si no hay nota),
   - botones − y + (paso 5, ≥ 48 px) a los lados,
   - fila de 5 valores rápidos: 0 · 20 · 40 · 60 · 80 (= 0, 25, 50, 75, 100 % del máximo), el elegido en verde,
   - etiqueta Guardado / Pendiente.
   El paso (5) y el máximo (80) salen de los datos del criterio; los valores rápidos son `[0, .25, .5, .75, 1] × máximo`. Guardar con el mismo evento que ya existe (con un pequeño debounce al usar − / +).
7. Encabezado de calificar: equipo, actividad, "X de 5 criterios" y **subtotal "N / 400"** (suma de los 5 criterios del equipo en esta actividad).
8. Navegación "Anterior" / "Siguiente: <equipo>" (y "Siguiente criterio: <nombre>" en modo Por criterio).
9. Modo Por criterio: lista de criterios con "X/12 equipos · máx. 80"; al elegir uno, una tarjeta por equipo con el mismo selector de puntaje.

## Estados
- Actividad cancelada: tarjeta en gris con el motivo; no se puede calificar.
- Día cerrado: aviso "Este día está cerrado: solo lectura"; selector deshabilitado.
- Cargando: esqueletos. Error al guardar: etiqueta "Error · Reintentar".
