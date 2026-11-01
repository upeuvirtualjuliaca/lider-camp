-- =================================================================
-- Tipos de cálculo — tabla dinámica (análogo a categorias_criterios)
-- Gestiona cómo se calcula el puntaje de cada tipo de criterio.
-- =================================================================

-- 1. Tabla
CREATE TABLE IF NOT EXISTS public.tipos_calculo (
  clave       text        PRIMARY KEY,
  nombre      text        NOT NULL,
  descripcion text,
  formula     text,
  orden       int         NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 2. Trigger updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at_tipos_calculo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_tipos_calculo_updated_at
  BEFORE UPDATE ON public.tipos_calculo
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_tipos_calculo();

-- 3. RLS
ALTER TABLE public.tipos_calculo ENABLE ROW LEVEL SECURITY;

CREATE POLICY "todos pueden leer tipos_calculo"
  ON public.tipos_calculo FOR SELECT USING (true);

CREATE POLICY "admin puede insertar tipos_calculo"
  ON public.tipos_calculo FOR INSERT WITH CHECK (public.es_admin());

CREATE POLICY "admin puede actualizar tipos_calculo"
  ON public.tipos_calculo FOR UPDATE USING (public.es_admin());

CREATE POLICY "admin puede eliminar tipos_calculo"
  ON public.tipos_calculo FOR DELETE USING (public.es_admin());

-- 4. Seed de los 4 tipos con descripción y fórmulas completas
INSERT INTO public.tipos_calculo (clave, nombre, descripcion, formula, orden) VALUES

  ('inscripcion', 'Inscripción',
   E'Mide el compromiso del equipo según la fecha en que cada integrante completó su inscripción. Se considera inscripción completa (100 pts) hasta la fecha límite oficial, inscripción parcial (50 pts) durante los dos días siguientes, e inscripción tardía (0 pts) después de ese plazo. El puntaje se pondera sobre la nómina total del equipo. Máximo: 100 pts.',
   E'( inscritos_completos \u00d7 100 + inscritos_parciales \u00d7 50 ) / nomina_total\n\nReglas:\n  \u2022 inscritos_completos  \u2192 inscritos hasta fecha_limite_inscripcion_completa (inclusive)\n  \u2022 inscritos_parciales  \u2192 inscritos entre limite_completa+1 y fecha_limite_parcial (inclusive)\n  \u2022 inscritos_tardios    \u2192 inscritos despues de fecha_limite_parcial, aportan 0 pts\n  \u2022 nomina_total         \u2192 total de integrantes del equipo (completos + parciales + tardios)\n  \u2022 Resultado se multiplica por puntaje_max del criterio de inscripcion',
   1),

  ('rubrica', 'Rúbrica',
   E'Evaluación cualitativa diaria por criterio. El evaluador observa el estado del equipo y asigna un valor de la escala fija. Solo se admiten los cinco valores de la escala; no se aceptan valores intermedios. El puntaje obtenido es directo: no hay formula adicional. Máximo por día: puntaje_max del criterio (generalmente 100 pts).',
   E'puntaje = valor_observacion   (valor en { 0, 25, 50, 75, 100 })\n\nEscala de referencia:\n  100 \u2192 Excelente  - cumple todos los requisitos con detalle\n   75 \u2192 Bueno      - cumple la mayoria de requisitos\n   50 \u2192 Regular    - cumple parcialmente\n   25 \u2192 Deficiente - incumplimiento notable\n    0 \u2192 Nulo       - no se realizo o es inaceptable\n\nReglas:\n  \u2022 Un solo registro por equipo x criterio x dia\n  \u2022 El evaluador puede corregir hasta que se cierre el dia\n  \u2022 Toda corrección queda registrada en auditoria',
   2),

  ('asistencia', 'Asistencia',
   E'Mide el porcentaje de integrantes del equipo que asistieron a una actividad programada. Se aplica la regla del 95%: alcanzar ese umbral otorga el puntaje máximo. Las ausencias justificadas y documentadas se excluyen del denominador. Si hay varias actividades en un mismo dia para el mismo criterio, se calcula el promedio simple de los puntajes diarios. Máximo por actividad: 100 pts.',
   E'puntaje = min( 100, presentes / convocados_elegibles / 0.95 \u00d7 100 )\n\nDonde:\n  presentes            \u2192 integrantes marcados Presente en la actividad\n  convocados_elegibles \u2192 nomina - ausencias_justificadas_documentadas\n  0.95                 \u2192 umbral del 95%: llegar a ese nivel otorga 100 pts\n\nReglas:\n  \u2022 Ausencia justificada: debe tener documentacion registrada en el sistema\n  \u2022 Varias actividades en el dia \u2192 puntaje del dia = promedio simple\n  \u2022 Actividad cancelada \u2192 no afecta el puntaje de ningun equipo',
   3),

  ('liderazgo', 'Liderazgo',
   E'Evalua el liderazgo colectivo del equipo a traves de 4 indicadores medidos cada dia del campamento. Cada indicador vale hasta 25 puntos por dia, sumando un maximo de 100 pts/dia y 400 pts en los 4 dias del evento. El evaluador asigna el puntaje indicador por indicador al final de cada jornada.',
   E'puntaje_dia   = L1 + L2 + L3 + L4   (max. 100 pts/dia)\npuntaje_total = suma puntaje_dia por cada dia programado   (max. 400 pts)\n\nIndicadores (25 pts c/u por dia):\n  L1 \u2192 (por definir con la organización)\n  L2 \u2192 (por definir con la organización)\n  L3 \u2192 (por definir con la organización)\n  L4 \u2192 (por definir con la organización)\n\nReglas:\n  \u2022 Dias evaluados: los 4 dias del campamento (J, V, S, D)\n  \u2022 Un registro por equipo x indicador x dia\n  \u2022 Los indicadores L1-L4 son provisionales hasta confirmacion oficial',
   4)

ON CONFLICT (clave) DO UPDATE SET
  nombre      = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  formula     = EXCLUDED.formula,
  orden       = EXCLUDED.orden,
  updated_at  = now();

-- 5. FK desde criterios (ON UPDATE CASCADE, ON DELETE RESTRICT)
--    Quitar el CHECK si quedó alguno anterior
ALTER TABLE public.criterios
  DROP CONSTRAINT IF EXISTS criterios_tipo_calculo_check;

ALTER TABLE public.criterios
  ADD CONSTRAINT criterios_tipo_calculo_fk
  FOREIGN KEY (tipo_calculo) REFERENCES public.tipos_calculo(clave)
  ON UPDATE CASCADE ON DELETE RESTRICT;
