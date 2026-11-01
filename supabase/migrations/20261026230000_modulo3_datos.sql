-- Módulo 3: Datos iniciales de criterios y programación
-- Idempotente: usa ON CONFLICT DO NOTHING

DO $$
DECLARE
  v_ins uuid; v_car uuid; v_cer uuid; v_bas uuid; v_ten uuid;
  v_por uuid; v_oli uuid; v_ole uuid; v_coo uuid; v_col uuid;
  v_com uuid; v_cou uuid; v_iza uuid; v_bam uuid; v_ban uuid;
  v_est uuid; v_eve uuid; v_lid uuid;
BEGIN

  -- ── Criterios ─────────────────────────────────────────────────────────────
  INSERT INTO public.criterios (codigo, nombre, categoria, tipo_calculo, orden,
                                abarca, no_abarca, evidencia)
  VALUES
    -- Inscripción
    ('INS', 'Inscripción', 'inscripcion', 'inscripcion', 10,
     'Integrantes inscritos hasta el 19 de octubre (100 pts c/u) o entre el 20-21 de octubre (50 pts c/u).',
     'Inscripciones posteriores al 21 de octubre.',
     'Registro de fecha de inscripción de cada integrante en el sistema.'),

    -- Armado de campamento
    ('CAR', 'Carpas', 'armado', 'rubrica', 21,
     'Estado y organización de las carpas del equipo: montaje correcto, orden interno y presentación.',
     'Equipo de cocina ni área exterior al cerco.',
     'Inspección visual directa por el evaluador.'),

    ('CER', 'Cerco', 'armado', 'rubrica', 22,
     'Presencia y correcta delimitación del cerco del campamento del equipo.',
     'Decoraciones internas ni equipamiento dentro del cerco.',
     'Inspección visual directa por el evaluador.'),

    ('BAS', 'Basurero', 'armado', 'rubrica', 23,
     'Presencia de depósito de basura diferenciado, limpio y correctamente ubicado dentro del cerco.',
     'Contenedores de áreas comunes o de otros equipos.',
     'Inspección visual directa por el evaluador.'),

    ('TEN', 'Tendedero', 'armado', 'rubrica', 24,
     'Tendedero ordenado, con ropa doblada o colgada correctamente, sin obstruir el paso.',
     'Ropa o tendederos en zonas comunes.',
     'Inspección visual directa por el evaluador.'),

    ('POR', 'Portada', 'armado', 'rubrica', 25,
     'Portada creativa, resistente, con nombre del equipo visible y acorde a la temática del campamento.',
     'Decoraciones internas de la zona de carpas.',
     'Inspección visual directa por el evaluador y fotografía de evidencia.'),

    -- Orden y cocina
    ('OLI', 'Orden y limpieza interior', 'orden_cocina', 'rubrica', 30,
     'Limpieza y organización interna de carpas, maletas ordenadas, ropa guardada y piso limpio.',
     'Área exterior al cerco del equipo.',
     'Inspección visual directa de carpas por el evaluador.'),

    ('OLE', 'Orden y limpieza exterior', 'orden_cocina', 'rubrica', 31,
     'Limpieza del área exterior dentro del cerco: suelo libre de papeles, suciedad y objetos dispersos.',
     'Zonas comunes del campamento.',
     'Inspección visual directa del perímetro exterior por el evaluador.'),

    ('COO', 'Cocina y orden', 'orden_cocina', 'rubrica', 32,
     'Organización del área de cocina: utensilios limpios y guardados, mesa ordenada, insumos clasificados.',
     'Calidad de los alimentos preparados.',
     'Inspección visual del área de cocina por el evaluador.'),

    ('COL', 'Cocina y limpieza', 'orden_cocina', 'rubrica', 33,
     'Estado de limpieza de utensilios, superficies de cocina y área de preparación después de cada comida.',
     'Vestimenta del equipo de cocina.',
     'Inspección visual del área de cocina por el evaluador.'),

    ('COM', 'Cocina y menú', 'orden_cocina', 'rubrica', 34,
     'Preparación de menú ovo-lacto-vegetariano variado, nutritivo y en cantidad suficiente para el equipo.',
     'Alimentos traídos de fuera del campamento sin preparación.',
     'Inspección visual del menú servido y ficha de menú presentada al evaluador.'),

    ('COU', 'Cocina y uniforme', 'orden_cocina', 'rubrica', 35,
     'Uso correcto del uniforme de cocina (delantal, cubrecabeza, guantes) por todos los integrantes del equipo de cocina.',
     'Uniforme de actividades fuera del área de cocina.',
     'Inspección visual durante la preparación de alimentos.'),

    -- Ceremonias y participación
    ('IZA', 'Izamiento', 'ceremonias_participacion', 'rubrica', 40,
     'Participación ordenada y completa del equipo en el acto de izamiento de bandera: formación, cantos y actitud.',
     'Calidad musical individual.',
     'Observación directa por el evaluador durante el acto de izamiento.'),

    ('BAM', 'Barras de la mañana', 'ceremonias_participacion', 'rubrica', 41,
     'Participación activa y ordenada del equipo en las barras matutinas: energía, coreografía y cohesión grupal.',
     'Barras de otros equipos.',
     'Observación directa por el evaluador durante la actividad.'),

    ('BAN', 'Barras de la noche', 'ceremonias_participacion', 'rubrica', 42,
     'Participación activa y ordenada del equipo en las barras nocturnas: energía, creatividad y cohesión grupal.',
     'Barras de otros equipos.',
     'Observación directa por el evaluador durante la actividad.'),

    ('EST', 'Programa estelar', 'ceremonias_participacion', 'asistencia', 43,
     'Asistencia del equipo al programa estelar nocturno: puntualidad y participación activa.',
     'Calidad artística de las actuaciones.',
     'Control de asistencia por el evaluador al inicio del programa.'),

    ('EVE', 'Participación en eventos', 'ceremonias_participacion', 'asistencia', 44,
     'Asistencia y participación activa del equipo en las actividades y eventos programados durante el día.',
     'Eventos no programados o de carácter opcional.',
     'Control de asistencia por el evaluador al inicio de cada evento.'),

    -- Liderazgo
    ('LID', 'Liderazgo de servicio', 'liderazgo', 'liderazgo', 50,
     'Actitud de servicio, iniciativa, trabajo en equipo y liderazgo positivo demostrado por los integrantes durante el campamento.',
     'Liderazgo fuera del contexto del campamento.',
     'Observación continua por el evaluador; se registra al final de cada día.')

  ON CONFLICT (codigo) DO NOTHING;

  -- ── Obtener IDs ────────────────────────────────────────────────────────────
  SELECT id INTO v_ins FROM public.criterios WHERE codigo = 'INS';
  SELECT id INTO v_car FROM public.criterios WHERE codigo = 'CAR';
  SELECT id INTO v_cer FROM public.criterios WHERE codigo = 'CER';
  SELECT id INTO v_bas FROM public.criterios WHERE codigo = 'BAS';
  SELECT id INTO v_ten FROM public.criterios WHERE codigo = 'TEN';
  SELECT id INTO v_por FROM public.criterios WHERE codigo = 'POR';
  SELECT id INTO v_oli FROM public.criterios WHERE codigo = 'OLI';
  SELECT id INTO v_ole FROM public.criterios WHERE codigo = 'OLE';
  SELECT id INTO v_coo FROM public.criterios WHERE codigo = 'COO';
  SELECT id INTO v_col FROM public.criterios WHERE codigo = 'COL';
  SELECT id INTO v_com FROM public.criterios WHERE codigo = 'COM';
  SELECT id INTO v_cou FROM public.criterios WHERE codigo = 'COU';
  SELECT id INTO v_iza FROM public.criterios WHERE codigo = 'IZA';
  SELECT id INTO v_bam FROM public.criterios WHERE codigo = 'BAM';
  SELECT id INTO v_ban FROM public.criterios WHERE codigo = 'BAN';
  SELECT id INTO v_est FROM public.criterios WHERE codigo = 'EST';
  SELECT id INTO v_eve FROM public.criterios WHERE codigo = 'EVE';
  SELECT id INTO v_lid FROM public.criterios WHERE codigo = 'LID';

  -- ── Programación ──────────────────────────────────────────────────────────
  --  programado    → cuenta en el total
  --  no_programado → no aplica ese día
  --  Total programado: 5200 pts (COU pendiente de confirmar días)
  INSERT INTO public.programacion (criterio_id, momento, puntaje_max, estado) VALUES

    -- INS — Inscripción (fila única)
    (v_ins, 'UNICO', 100, 'programado'),

    -- CAR — Carpas: J V S   (D no aplica)
    (v_car, 'J', 100, 'programado'),
    (v_car, 'V', 100, 'programado'),
    (v_car, 'S', 100, 'programado'),
    (v_car, 'D', 100, 'no_programado'),

    -- CER — Cerco: J V S D
    (v_cer, 'J', 100, 'programado'),
    (v_cer, 'V', 100, 'programado'),
    (v_cer, 'S', 100, 'programado'),
    (v_cer, 'D', 100, 'programado'),

    -- BAS — Basurero: J V S D
    (v_bas, 'J', 100, 'programado'),
    (v_bas, 'V', 100, 'programado'),
    (v_bas, 'S', 100, 'programado'),
    (v_bas, 'D', 100, 'programado'),

    -- TEN — Tendedero: J V S   (D no aplica)
    (v_ten, 'J', 100, 'programado'),
    (v_ten, 'V', 100, 'programado'),
    (v_ten, 'S', 100, 'programado'),
    (v_ten, 'D', 100, 'no_programado'),

    -- POR — Portada: V S   (J D no aplican)
    (v_por, 'J', 100, 'no_programado'),
    (v_por, 'V', 100, 'programado'),
    (v_por, 'S', 100, 'programado'),
    (v_por, 'D', 100, 'no_programado'),

    -- OLI — Orden y limpieza interior: J V S D
    (v_oli, 'J', 100, 'programado'),
    (v_oli, 'V', 100, 'programado'),
    (v_oli, 'S', 100, 'programado'),
    (v_oli, 'D', 100, 'programado'),

    -- OLE — Orden y limpieza exterior: J V S D
    (v_ole, 'J', 100, 'programado'),
    (v_ole, 'V', 100, 'programado'),
    (v_ole, 'S', 100, 'programado'),
    (v_ole, 'D', 100, 'programado'),

    -- COO — Cocina y orden: J V S D
    (v_coo, 'J', 100, 'programado'),
    (v_coo, 'V', 100, 'programado'),
    (v_coo, 'S', 100, 'programado'),
    (v_coo, 'D', 100, 'programado'),

    -- COL — Cocina y limpieza: J V S   (D no aplica)
    (v_col, 'J', 100, 'programado'),
    (v_col, 'V', 100, 'programado'),
    (v_col, 'S', 100, 'programado'),
    (v_col, 'D', 100, 'no_programado'),

    -- COM — Cocina y menú: J V S   (D no aplica)
    (v_com, 'J', 100, 'programado'),
    (v_com, 'V', 100, 'programado'),
    (v_com, 'S', 100, 'programado'),
    (v_com, 'D', 100, 'no_programado'),

    -- COU — Cocina y uniforme: todos no_programado hasta confirmar días
    (v_cou, 'J', 100, 'no_programado'),
    (v_cou, 'V', 100, 'no_programado'),
    (v_cou, 'S', 100, 'no_programado'),
    (v_cou, 'D', 100, 'no_programado'),

    -- IZA — Izamiento: V S   (J D no aplican)
    (v_iza, 'J', 100, 'no_programado'),
    (v_iza, 'V', 100, 'programado'),
    (v_iza, 'S', 100, 'programado'),
    (v_iza, 'D', 100, 'no_programado'),

    -- BAM — Barras de la mañana: J V S D
    (v_bam, 'J', 100, 'programado'),
    (v_bam, 'V', 100, 'programado'),
    (v_bam, 'S', 100, 'programado'),
    (v_bam, 'D', 100, 'programado'),

    -- BAN — Barras de la noche: J V S   (D no aplica)
    (v_ban, 'J', 100, 'programado'),
    (v_ban, 'V', 100, 'programado'),
    (v_ban, 'S', 100, 'programado'),
    (v_ban, 'D', 100, 'no_programado'),

    -- EST — Programa estelar: J V S D
    (v_est, 'J', 100, 'programado'),
    (v_est, 'V', 100, 'programado'),
    (v_est, 'S', 100, 'programado'),
    (v_est, 'D', 100, 'programado'),

    -- EVE — Participación en eventos: J V S   (D no aplica)
    (v_eve, 'J', 100, 'programado'),
    (v_eve, 'V', 100, 'programado'),
    (v_eve, 'S', 100, 'programado'),
    (v_eve, 'D', 100, 'no_programado'),

    -- LID — Liderazgo de servicio: J V S D
    (v_lid, 'J', 100, 'programado'),
    (v_lid, 'V', 100, 'programado'),
    (v_lid, 'S', 100, 'programado'),
    (v_lid, 'D', 100, 'programado')

  ON CONFLICT (criterio_id, momento) DO NOTHING;

  RAISE NOTICE 'Módulo 3: criterios y programación insertados.';
END;
$$;
