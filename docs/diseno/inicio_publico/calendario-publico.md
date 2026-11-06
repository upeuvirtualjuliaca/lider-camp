# Calendario público (/calendario) — web, tablet y celular

Mismo encabezado y pie públicos que Inicio y Ranking (`../inicio-publico.md`). Estilo: `docs/diseno/guia-estilo-movil.md`.
Copia estructura y estilos; NO el JavaScript ni las etiquetas especiales (x-dc, sc-for, sc-if, helmet). Los datos son de ejemplo (las actividades y sus horas deben salir de la tabla `actividades`, solo las no canceladas).

## Maquetas (en esta carpeta)
| Archivo | Uso |
|---|---|
| `CalendarioPublicoWeb.dc.html` | web y tablet (fluido). Interactivo: "Por día" / "Semana completa" y selección de día |
| `CalendarioPublicoMovil.dc.html` | celular: solo vista por día, con la barra de días fija arriba |

## Estructura
1. Título "Calendario" + "Qué se evalúa y qué actividades hay cada día del campamento."
2. Selector de vista (web/tablet): **Por día** (predeterminada) · **Semana completa**. En celular solo "Por día".
3. **Por día**:
   - Tarjetas de día (Jue 5, Vie 6, Sáb 7) con "Hoy" + nº de criterios + nº de actividades. Se abre en el día de hoy (o el primero si el campamento no empezó).
   - "Se evalúa el <día>": criterios agrupados por categoría como chips (sin códigos internos). Al final: "No se evalúan este día: …".
   - "Actividades": hora destacada, nombre y lugar. Mensaje sobre la meta del 95 % de asistencia. En celular las actividades van primero.
4. **Semana completa**: matriz criterios × días agrupada por categoría, con la columna de HOY resaltada en verde claro.
   - Se evalúa = punto verde lleno; no se evalúa = círculo vacío gris; cancelado = cuadro rojo.
   - Leyenda debajo (Se evalúa · No se evalúa · Cancelado · Hoy).
5. Tarjeta de notas: "Inscripción: se califica una sola vez…" y "Domingo 8: clausura y medallas; sin criterios evaluados."

## Cambios respecto a la versión actual
- Quitar las columnas **"Dom"** y **"Único"** (estaban vacías salvo Inscripción). Inscripción y el domingo pasan a la tarjeta de notas. Si algún día tiene criterios, su columna se muestra automáticamente.
- Quitar los códigos internos (CAR, CER, LDD…).
- Reemplazar ✓ y — por puntos (más limpios y fáciles de escanear).
- Agregar las **actividades del día** (hoy el calendario solo muestra criterios).
- Resaltar el día de hoy.
- Revisar el nombre "Polos" del criterio IZA (en la maqueta figura como "Izamiento").
