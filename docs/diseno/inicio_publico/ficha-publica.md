# Ficha pública del equipo por día (/equipo/:id?dia=J) — web, tablet y celular

Se abre al tocar una escuela en el Ranking oficial. Mismo encabezado y pie públicos que Inicio y Ranking (`inicio-publico.md`).
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos son de ejemplo.

## Maquetas (en esta carpeta)
| Archivo | Uso |
|---|---|
| `FichaPublicaWeb.dc.html` | web y tablet (fluido; en tablet las 4 tarjetas pasan a 2 columnas) |
| `FichaPublicaMovil.dc.html` | celular (grupos plegables) |

## Estructura
1. Enlace de regreso con contexto: "← Ranking del jueves" (vuelve al ranking con el mismo día seleccionado).
2. **Encabezado del equipo**: cuadro de 64 px con iniciales sobre el color del equipo (no un círculo de color sin texto), nombre, insignia de posición "1° del jueves" (dorada para el 1°, gris para el resto) + "de 12 escuelas", y a la derecha el total grande "1026" con "de 1350 pts posibles · 76 %".
3. Barra apilada de composición (criterios verde, actividades azul) sobre el máximo.
4. Pestañas de día: solo los días publicados son seleccionables; los no publicados aparecen deshabilitados con borde punteado "Viernes · aún no publicado". Si el total está publicado, añadir pestaña "Total".
5. **4 tarjetas de resumen**: Criterios del día (N / máx), Actividades (N / máx, con aviso si hay alguna pendiente de publicar), Bonus, Deméritos.
   - Cero se muestra como "0" en gris + texto "Sin bonus/deméritos este día" (hoy dice "Ninguno" en verde y en rojo, lo que parece positivo/negativo).
   - Con valores: bonus "+25" verde y deméritos "−10" rojo, y debajo la lista por código ("B1 · +25"), sin hechos ni nombres.
6. **Detalle por criterio SIEMPRE visible** (hoy hay que tocar "Rúbrica ▼" para verlo), agrupado por categoría (Armado, Orden y cocina, Ceremonias y conducta, Liderazgo, Actividades) con subtotal "N / máx" por grupo.
   - Fila: nombre del criterio · barra de avance · "obtenido / máx". Barra verde al 100 %, verde claro ≥ 50 %, ámbar < 50 %.
   - Quitar los códigos internos (CAR, CER, OLI...): no aportan al estudiante.
   - Criterio no publicado o sin nota: "Pendiente" en ámbar.
   - Actividades: cada actividad con su subtotal (no "0" si aún no se calificó: "Pendiente").
7. Celular: grupos plegables (abiertos por defecto salvo los completos al 100 %), tarjetas de resumen en 2×2.
8. Nota al pie: "Solo se muestran resultados validados y publicados."

## Revisar en los datos
- En la captura actual el criterio con código IZA se llama "Polos": verifica el nombre del criterio de Izamiento en la tabla `criterios`.
- "Actividades 0" mientras el programa estelar no se publica: mostrar "Pendiente", no 0.
