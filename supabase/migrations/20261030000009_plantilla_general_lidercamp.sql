-- =================================================================
-- Plantilla oficial: "LiderCamp — Criterio General"
-- Refleja exactamente los días y puntajes de la documentación.
-- Idempotente: usa ON CONFLICT DO NOTHING
-- =================================================================

DO $$
DECLARE
  v_plantilla uuid;
  v_ins uuid; v_car uuid; v_cer uuid; v_bas uuid; v_ten uuid;
  v_por uuid; v_oli uuid; v_ole uuid; v_coo uuid; v_col uuid;
  v_com uuid; v_cou uuid; v_iza uuid; v_bam uuid; v_ban uuid;
  v_est uuid; v_eve uuid; v_lid uuid;
BEGIN

  -- ── Crear plantilla (solo si no existe ya) ────────────────────────────────
  INSERT INTO public.plantillas_criterios (nombre, descripcion, activo)
  VALUES (
    'LiderCamp — Criterio General',
    'Plantilla oficial con todos los criterios y días programados según la guía del campamento universitario LiderCamp.',
    true
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_plantilla;

  -- Si ya existía, obtener su id
  IF v_plantilla IS NULL THEN
    SELECT id INTO v_plantilla
    FROM public.plantillas_criterios
    WHERE nombre = 'LiderCamp — Criterio General'
    LIMIT 1;
  END IF;

  -- Si la plantilla ya tiene items, no volver a insertarlos
  IF EXISTS (SELECT 1 FROM public.plantilla_items WHERE plantilla_id = v_plantilla) THEN
    RAISE NOTICE 'Plantilla general ya tiene items. Se omite la inserción.';
    RETURN;
  END IF;

  -- ── Obtener IDs de criterios ──────────────────────────────────────────────
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

  -- ── Insertar items de la plantilla ────────────────────────────────────────
  -- Solo se incluyen los días con estado 'programado'.
  -- COU (Cocina y uniforme) queda sin días hasta confirmar la documentación.
  INSERT INTO public.plantilla_items (plantilla_id, criterio_id, momento, puntaje_max, estado)
  VALUES

    -- INS — Inscripción (fila única)
    (v_plantilla, v_ins, 'UNICO', 100, 'programado'),

    -- CAR — Carpas: J V S
    (v_plantilla, v_car, 'J', 100, 'programado'),
    (v_plantilla, v_car, 'V', 100, 'programado'),
    (v_plantilla, v_car, 'S', 100, 'programado'),

    -- CER — Cerco: J V S D
    (v_plantilla, v_cer, 'J', 100, 'programado'),
    (v_plantilla, v_cer, 'V', 100, 'programado'),
    (v_plantilla, v_cer, 'S', 100, 'programado'),
    (v_plantilla, v_cer, 'D', 100, 'programado'),

    -- BAS — Basurero: J V S D
    (v_plantilla, v_bas, 'J', 100, 'programado'),
    (v_plantilla, v_bas, 'V', 100, 'programado'),
    (v_plantilla, v_bas, 'S', 100, 'programado'),
    (v_plantilla, v_bas, 'D', 100, 'programado'),

    -- TEN — Tendedero: J V S
    (v_plantilla, v_ten, 'J', 100, 'programado'),
    (v_plantilla, v_ten, 'V', 100, 'programado'),
    (v_plantilla, v_ten, 'S', 100, 'programado'),

    -- POR — Portada: V S
    (v_plantilla, v_por, 'V', 100, 'programado'),
    (v_plantilla, v_por, 'S', 100, 'programado'),

    -- OLI — Orden y limpieza interior: J V S D
    (v_plantilla, v_oli, 'J', 100, 'programado'),
    (v_plantilla, v_oli, 'V', 100, 'programado'),
    (v_plantilla, v_oli, 'S', 100, 'programado'),
    (v_plantilla, v_oli, 'D', 100, 'programado'),

    -- OLE — Orden y limpieza exterior: J V S D
    (v_plantilla, v_ole, 'J', 100, 'programado'),
    (v_plantilla, v_ole, 'V', 100, 'programado'),
    (v_plantilla, v_ole, 'S', 100, 'programado'),
    (v_plantilla, v_ole, 'D', 100, 'programado'),

    -- COO — Cocina y orden: J V S D
    (v_plantilla, v_coo, 'J', 100, 'programado'),
    (v_plantilla, v_coo, 'V', 100, 'programado'),
    (v_plantilla, v_coo, 'S', 100, 'programado'),
    (v_plantilla, v_coo, 'D', 100, 'programado'),

    -- COL — Cocina y limpieza: J V S
    (v_plantilla, v_col, 'J', 100, 'programado'),
    (v_plantilla, v_col, 'V', 100, 'programado'),
    (v_plantilla, v_col, 'S', 100, 'programado'),

    -- COM — Cocina y menú: J V S
    (v_plantilla, v_com, 'J', 100, 'programado'),
    (v_plantilla, v_com, 'V', 100, 'programado'),
    (v_plantilla, v_com, 'S', 100, 'programado'),

    -- COU — Cocina y uniforme: días PENDIENTES de confirmar en la guía
    -- (no se insertan filas hasta tener confirmación)

    -- IZA — Izamiento: V S
    (v_plantilla, v_iza, 'V', 100, 'programado'),
    (v_plantilla, v_iza, 'S', 100, 'programado'),

    -- BAM — Barras de la mañana: J V S D
    (v_plantilla, v_bam, 'J', 100, 'programado'),
    (v_plantilla, v_bam, 'V', 100, 'programado'),
    (v_plantilla, v_bam, 'S', 100, 'programado'),
    (v_plantilla, v_bam, 'D', 100, 'programado'),

    -- BAN — Barras de la noche: J V S
    (v_plantilla, v_ban, 'J', 100, 'programado'),
    (v_plantilla, v_ban, 'V', 100, 'programado'),
    (v_plantilla, v_ban, 'S', 100, 'programado'),

    -- EST — Programa estelar: J V S D
    (v_plantilla, v_est, 'J', 100, 'programado'),
    (v_plantilla, v_est, 'V', 100, 'programado'),
    (v_plantilla, v_est, 'S', 100, 'programado'),
    (v_plantilla, v_est, 'D', 100, 'programado'),

    -- EVE — Participación en eventos: J V S
    (v_plantilla, v_eve, 'J', 100, 'programado'),
    (v_plantilla, v_eve, 'V', 100, 'programado'),
    (v_plantilla, v_eve, 'S', 100, 'programado'),

    -- LID — Liderazgo de servicio: J V S D
    (v_plantilla, v_lid, 'J', 100, 'programado'),
    (v_plantilla, v_lid, 'V', 100, 'programado'),
    (v_plantilla, v_lid, 'S', 100, 'programado'),
    (v_plantilla, v_lid, 'D', 100, 'programado')

  ON CONFLICT (plantilla_id, criterio_id, momento) DO NOTHING;

  RAISE NOTICE 'Plantilla general LiderCamp insertada con % items.',
    (SELECT COUNT(*) FROM public.plantilla_items WHERE plantilla_id = v_plantilla);

END;
$$;
