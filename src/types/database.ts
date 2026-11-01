export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "actividades": {
                  Row: {
                    "created_at": string,"descripcion": string | null,"estado": string,"evaluador_id": string,"hora_inicio": string | null,"id": string,"lugar": string | null,"motivo_cancelacion": string | null,"nombre": string,"programacion_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"descripcion"?: string | null,"estado"?: string,"evaluador_id"?: string,"hora_inicio"?: string | null,"id"?: string,"lugar"?: string | null,"motivo_cancelacion"?: string | null,"nombre": string,"programacion_id": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"descripcion"?: string | null,"estado"?: string,"evaluador_id"?: string,"hora_inicio"?: string | null,"id"?: string,"lugar"?: string | null,"motivo_cancelacion"?: string | null,"nombre"?: string,"programacion_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "actividades_evaluador_id_fkey"
      columns: ["evaluador_id"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "actividades_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "programacion"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "actividades_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["programacion_id"]
    }
                  ]
                },"asistencia_registros": {
                  Row: {
                    "actividad_id": string,"created_at": string,"documentado": boolean,"estado": string,"evaluador_id": string,"id": string,"integrante_id": string,"motivo_justificacion": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actividad_id": string,"created_at"?: string,"documentado"?: boolean,"estado": string,"evaluador_id"?: string,"id"?: string,"integrante_id": string,"motivo_justificacion"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "actividad_id"?: string,"created_at"?: string,"documentado"?: boolean,"estado"?: string,"evaluador_id"?: string,"id"?: string,"integrante_id"?: string,"motivo_justificacion"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "asistencia_registros_actividad_id_fkey"
      columns: ["actividad_id"]
isOneToOne: false
      referencedRelation: "actividades"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "asistencia_registros_actividad_id_fkey"
      columns: ["actividad_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["actividad_id"]
    },{
      foreignKeyName: "asistencia_registros_evaluador_id_fkey"
      columns: ["evaluador_id"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "asistencia_registros_integrante_id_fkey"
      columns: ["integrante_id"]
isOneToOne: false
      referencedRelation: "integrantes"
      referencedColumns: ["id"]
    }
                  ]
                },"auditoria": {
                  Row: {
                    "accion": string,"created_at": string,"datos_anteriores": Json | null,"datos_nuevos": Json | null,"id": string,"registro_id": string,"tabla": string,"usuario_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accion": string,"created_at"?: string,"datos_anteriores"?: Json | null,"datos_nuevos"?: Json | null,"id"?: string,"registro_id": string,"tabla": string,"usuario_id"?: string | null
                  }
                  Update: {
                    "accion"?: string,"created_at"?: string,"datos_anteriores"?: Json | null,"datos_nuevos"?: Json | null,"id"?: string,"registro_id"?: string,"tabla"?: string,"usuario_id"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"campamento": {
                  Row: {
                    "activo": boolean,"cerrado": boolean,"cerrado_at": string | null,"cerrado_por": string | null,"created_at": string,"edicion": string,"fecha_limite_inscripcion_completa": string,"fecha_limite_inscripcion_parcial": string,"id": string,"motivo_cierre": string | null,"nombre": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"cerrado"?: boolean,"cerrado_at"?: string | null,"cerrado_por"?: string | null,"created_at"?: string,"edicion": string,"fecha_limite_inscripcion_completa"?: string,"fecha_limite_inscripcion_parcial"?: string,"id"?: string,"motivo_cierre"?: string | null,"nombre": string,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"cerrado"?: boolean,"cerrado_at"?: string | null,"cerrado_por"?: string | null,"created_at"?: string,"edicion"?: string,"fecha_limite_inscripcion_completa"?: string,"fecha_limite_inscripcion_parcial"?: string,"id"?: string,"motivo_cierre"?: string | null,"nombre"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"campamento_criterios": {
                  Row: {
                    "campamento_id": string,"criterio_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "campamento_id": string,"criterio_id": string
                  }
                  Update: {
                    "campamento_id"?: string,"criterio_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "campamento_criterios_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "campamento_criterios_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "campamento_criterios_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "criterios"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "campamento_criterios_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "publico_calendario"
      referencedColumns: ["id"]
    }
                  ]
                },"categorias_criterios": {
                  Row: {
                    "clave": string,"color": string,"created_at": string,"nombre": string,"orden": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "clave": string,"color"?: string,"created_at"?: string,"nombre": string,"orden"?: number,"updated_at"?: string
                  }
                  Update: {
                    "clave"?: string,"color"?: string,"created_at"?: string,"nombre"?: string,"orden"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"criterios": {
                  Row: {
                    "abarca": string | null,"activo": boolean,"categoria": string,"codigo": string,"created_at": string,"evidencia": string | null,"id": string,"no_abarca": string | null,"nombre": string,"orden": number,"tipo_calculo": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "abarca"?: string | null,"activo"?: boolean,"categoria": string,"codigo": string,"created_at"?: string,"evidencia"?: string | null,"id"?: string,"no_abarca"?: string | null,"nombre": string,"orden"?: number,"tipo_calculo": string,"updated_at"?: string
                  }
                  Update: {
                    "abarca"?: string | null,"activo"?: boolean,"categoria"?: string,"codigo"?: string,"created_at"?: string,"evidencia"?: string | null,"id"?: string,"no_abarca"?: string | null,"nombre"?: string,"orden"?: number,"tipo_calculo"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "criterios_categoria_fk"
      columns: ["categoria"]
isOneToOne: false
      referencedRelation: "categorias_criterios"
      referencedColumns: ["clave"]
    },{
      foreignKeyName: "criterios_tipo_calculo_fk"
      columns: ["tipo_calculo"]
isOneToOne: false
      referencedRelation: "tipos_calculo"
      referencedColumns: ["clave"]
    }
                  ]
                },"dias_campamento": {
                  Row: {
                    "campamento_id": string,"codigo": string,"created_at": string,"fecha": string,"id": string,"nombre": string,"orden": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "campamento_id": string,"codigo": string,"created_at"?: string,"fecha": string,"id"?: string,"nombre": string,"orden"?: number,"updated_at"?: string
                  }
                  Update: {
                    "campamento_id"?: string,"codigo"?: string,"created_at"?: string,"fecha"?: string,"id"?: string,"nombre"?: string,"orden"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "dias_campamento_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dias_campamento_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"dias_evaluacion": {
                  Row: {
                    "campamento_id": string,"cerrado": boolean,"cerrado_at": string | null,"cerrado_por": string | null,"created_at": string,"momento": string,"publicado": boolean,"publicado_at": string | null,"publicado_por": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "campamento_id": string,"cerrado"?: boolean,"cerrado_at"?: string | null,"cerrado_por"?: string | null,"created_at"?: string,"momento": string,"publicado"?: boolean,"publicado_at"?: string | null,"publicado_por"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "campamento_id"?: string,"cerrado"?: boolean,"cerrado_at"?: string | null,"cerrado_por"?: string | null,"created_at"?: string,"momento"?: string,"publicado"?: boolean,"publicado_at"?: string | null,"publicado_por"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "dias_evaluacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dias_evaluacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dias_evaluacion_cerrado_por_fkey"
      columns: ["cerrado_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dias_evaluacion_publicado_por_fkey"
      columns: ["publicado_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    }
                  ]
                },"equipos": {
                  Row: {
                    "activo": boolean,"campamento_id": string,"color": string,"created_at": string,"escuela_profesional": string,"id": string,"nombre": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"campamento_id": string,"color"?: string,"created_at"?: string,"escuela_profesional": string,"id"?: string,"nombre": string,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"campamento_id"?: string,"color"?: string,"created_at"?: string,"escuela_profesional"?: string,"id"?: string,"nombre"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"incidencia_codigos": {
                  Row: {
                    "abarca": string | null,"activo": boolean,"codigo": string,"created_at": string,"excluye": string | null,"id": string,"max_acciones": number | null,"nombre": string,"orden": number,"por_persona": boolean,"puntos": number,"requiere_advertencia": boolean,"requiere_equipo_apoyado": boolean,"tipo": string,"tope_equipo": number | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "abarca"?: string | null,"activo"?: boolean,"codigo": string,"created_at"?: string,"excluye"?: string | null,"id"?: string,"max_acciones"?: number | null,"nombre": string,"orden"?: number,"por_persona"?: boolean,"puntos": number,"requiere_advertencia"?: boolean,"requiere_equipo_apoyado"?: boolean,"tipo": string,"tope_equipo"?: number | null,"updated_at"?: string
                  }
                  Update: {
                    "abarca"?: string | null,"activo"?: boolean,"codigo"?: string,"created_at"?: string,"excluye"?: string | null,"id"?: string,"max_acciones"?: number | null,"nombre"?: string,"orden"?: number,"por_persona"?: boolean,"puntos"?: number,"requiere_advertencia"?: boolean,"requiere_equipo_apoyado"?: boolean,"tipo"?: string,"tope_equipo"?: number | null,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"incidencia_evidencias": {
                  Row: {
                    "created_at": string,"id": string,"incidencia_id": string,"nombre_original": string | null,"ruta_archivo": string,"subido_por": string,"tipo_archivo": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"incidencia_id": string,"nombre_original"?: string | null,"ruta_archivo": string,"subido_por": string,"tipo_archivo": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"incidencia_id"?: string,"nombre_original"?: string | null,"ruta_archivo"?: string,"subido_por"?: string,"tipo_archivo"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "incidencia_evidencias_incidencia_id_fkey"
      columns: ["incidencia_id"]
isOneToOne: false
      referencedRelation: "incidencias"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencia_evidencias_incidencia_id_fkey"
      columns: ["incidencia_id"]
isOneToOne: false
      referencedRelation: "v_incidencias_pendientes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencia_evidencias_subido_por_fkey"
      columns: ["subido_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    }
                  ]
                },"incidencia_integrantes": {
                  Row: {
                    "created_at": string,"id": string,"incidencia_id": string,"integrante_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"incidencia_id": string,"integrante_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"incidencia_id"?: string,"integrante_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "incidencia_integrantes_incidencia_id_fkey"
      columns: ["incidencia_id"]
isOneToOne: false
      referencedRelation: "incidencias"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencia_integrantes_incidencia_id_fkey"
      columns: ["incidencia_id"]
isOneToOne: false
      referencedRelation: "v_incidencias_pendientes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencia_integrantes_integrante_id_fkey"
      columns: ["integrante_id"]
isOneToOne: false
      referencedRelation: "integrantes"
      referencedColumns: ["id"]
    }
                  ]
                },"incidencias": {
                  Row: {
                    "advertencia_referencia": string | null,"alcance": string,"cantidad_personas": number,"codigo": string,"confirmado_por_equipo_apoyado": boolean,"created_at": string,"descargo_equipo": string | null,"equipo_apoyado_id": string | null,"equipo_id": string,"estado": string,"fecha": string,"hecho": string,"hora": string,"id": string,"justificacion_grupal": string | null,"momento": string | null,"motivo_resolucion": string | null,"puntos": number,"registrado_por": string,"updated_at": string,"validado_at": string | null,"validado_por": string | null,"valorado_en_otro_item": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "advertencia_referencia"?: string | null,"alcance"?: string,"cantidad_personas"?: number,"codigo": string,"confirmado_por_equipo_apoyado"?: boolean,"created_at"?: string,"descargo_equipo"?: string | null,"equipo_apoyado_id"?: string | null,"equipo_id": string,"estado"?: string,"fecha": string,"hecho": string,"hora": string,"id"?: string,"justificacion_grupal"?: string | null,"momento"?: string | null,"motivo_resolucion"?: string | null,"puntos"?: number,"registrado_por": string,"updated_at"?: string,"validado_at"?: string | null,"validado_por"?: string | null,"valorado_en_otro_item"?: string | null
                  }
                  Update: {
                    "advertencia_referencia"?: string | null,"alcance"?: string,"cantidad_personas"?: number,"codigo"?: string,"confirmado_por_equipo_apoyado"?: boolean,"created_at"?: string,"descargo_equipo"?: string | null,"equipo_apoyado_id"?: string | null,"equipo_id"?: string,"estado"?: string,"fecha"?: string,"hecho"?: string,"hora"?: string,"id"?: string,"justificacion_grupal"?: string | null,"momento"?: string | null,"motivo_resolucion"?: string | null,"puntos"?: number,"registrado_por"?: string,"updated_at"?: string,"validado_at"?: string | null,"validado_por"?: string | null,"valorado_en_otro_item"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "incidencia_codigos"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_bonus_equipo"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_demeritos_equipo"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_apoyado_id_fkey"
      columns: ["equipo_apoyado_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_registrado_por_fkey"
      columns: ["registrado_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_validado_por_fkey"
      columns: ["validado_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    }
                  ]
                },"integrantes": {
                  Row: {
                    "activo": boolean,"apellidos": string,"codigo_universitario": string | null,"created_at": string,"dni": string | null,"elegible": boolean,"equipo_id": string,"expulsado": boolean,"fecha_expulsion": string | null,"fecha_inscripcion": string,"id": string,"motivo_expulsion": string | null,"nombres": string,"observaciones": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"apellidos": string,"codigo_universitario"?: string | null,"created_at"?: string,"dni"?: string | null,"elegible"?: boolean,"equipo_id": string,"expulsado"?: boolean,"fecha_expulsion"?: string | null,"fecha_inscripcion": string,"id"?: string,"motivo_expulsion"?: string | null,"nombres": string,"observaciones"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"apellidos"?: string,"codigo_universitario"?: string | null,"created_at"?: string,"dni"?: string | null,"elegible"?: boolean,"equipo_id"?: string,"expulsado"?: boolean,"fecha_expulsion"?: string | null,"fecha_inscripcion"?: string,"id"?: string,"motivo_expulsion"?: string | null,"nombres"?: string,"observaciones"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "integrantes_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    }
                  ]
                },"liderazgo_evaluaciones": {
                  Row: {
                    "comentario": string | null,"created_at": string,"equipo_id": string,"evaluador_id": string,"id": string,"indicador_id": string,"motivo_cambio": string | null,"nivel": number,"programacion_id": string,"puntos": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "comentario"?: string | null,"created_at"?: string,"equipo_id": string,"evaluador_id"?: string,"id"?: string,"indicador_id": string,"motivo_cambio"?: string | null,"nivel": number,"programacion_id": string,"puntos"?: number,"updated_at"?: string
                  }
                  Update: {
                    "comentario"?: string | null,"created_at"?: string,"equipo_id"?: string,"evaluador_id"?: string,"id"?: string,"indicador_id"?: string,"motivo_cambio"?: string | null,"nivel"?: number,"programacion_id"?: string,"puntos"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_evaluador_id_fkey"
      columns: ["evaluador_id"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_indicador_id_fkey"
      columns: ["indicador_id"]
isOneToOne: false
      referencedRelation: "liderazgo_indicadores"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "programacion"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "liderazgo_evaluaciones_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["programacion_id"]
    }
                  ]
                },"liderazgo_indicadores": {
                  Row: {
                    "activo": boolean,"codigo": string,"created_at": string,"descripcion": string,"evidencia": string,"id": string,"nombre": string,"orden": number,"puntaje_max": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"codigo": string,"created_at"?: string,"descripcion": string,"evidencia": string,"id"?: string,"nombre": string,"orden"?: number,"puntaje_max"?: number,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"codigo"?: string,"created_at"?: string,"descripcion"?: string,"evidencia"?: string,"id"?: string,"nombre"?: string,"orden"?: number,"puntaje_max"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"observaciones": {
                  Row: {
                    "comentario": string | null,"created_at": string,"equipo_id": string,"evaluador_id": string,"id": string,"motivo_cambio": string | null,"programacion_id": string,"puntaje": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "comentario"?: string | null,"created_at"?: string,"equipo_id": string,"evaluador_id"?: string,"id"?: string,"motivo_cambio"?: string | null,"programacion_id": string,"puntaje": number,"updated_at"?: string
                  }
                  Update: {
                    "comentario"?: string | null,"created_at"?: string,"equipo_id"?: string,"evaluador_id"?: string,"id"?: string,"motivo_cambio"?: string | null,"programacion_id"?: string,"puntaje"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "observaciones_evaluador_id_fkey"
      columns: ["evaluador_id"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "observaciones_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "programacion"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "observaciones_programacion_id_fkey"
      columns: ["programacion_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["programacion_id"]
    }
                  ]
                },"perfiles": {
                  Row: {
                    "activo": boolean,"created_at": string,"email": string,"id": string,"nombre_completo": string,"rol": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"created_at"?: string,"email": string,"id": string,"nombre_completo": string,"rol"?: string,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"created_at"?: string,"email"?: string,"id"?: string,"nombre_completo"?: string,"rol"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"plantilla_items": {
                  Row: {
                    "created_at": string,"criterio_id": string,"estado": string,"id": string,"momento": string,"plantilla_id": string,"puntaje_max": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"criterio_id": string,"estado"?: string,"id"?: string,"momento": string,"plantilla_id": string,"puntaje_max"?: number
                  }
                  Update: {
                    "created_at"?: string,"criterio_id"?: string,"estado"?: string,"id"?: string,"momento"?: string,"plantilla_id"?: string,"puntaje_max"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "plantilla_items_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "criterios"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "plantilla_items_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "publico_calendario"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "plantilla_items_plantilla_id_fkey"
      columns: ["plantilla_id"]
isOneToOne: false
      referencedRelation: "plantillas_criterios"
      referencedColumns: ["id"]
    }
                  ]
                },"plantillas_criterios": {
                  Row: {
                    "activo": boolean,"created_at": string,"descripcion": string | null,"id": string,"nombre": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activo"?: boolean,"created_at"?: string,"descripcion"?: string | null,"id"?: string,"nombre": string,"updated_at"?: string
                  }
                  Update: {
                    "activo"?: boolean,"created_at"?: string,"descripcion"?: string | null,"id"?: string,"nombre"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"programacion": {
                  Row: {
                    "campamento_id": string,"created_at": string,"criterio_id": string,"estado": string,"id": string,"momento": string,"motivo": string | null,"puntaje_max": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "campamento_id": string,"created_at"?: string,"criterio_id": string,"estado"?: string,"id"?: string,"momento": string,"motivo"?: string | null,"puntaje_max"?: number,"updated_at"?: string
                  }
                  Update: {
                    "campamento_id"?: string,"created_at"?: string,"criterio_id"?: string,"estado"?: string,"id"?: string,"momento"?: string,"motivo"?: string | null,"puntaje_max"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "criterios"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "publico_calendario"
      referencedColumns: ["id"]
    }
                  ]
                },"solicitudes_revision": {
                  Row: {
                    "campamento_id": string,"created_at": string,"descripcion": string,"estado": string,"id": string,"registro_id": string | null,"respuesta": string | null,"resuelto_at": string | null,"resuelto_por": string | null,"solicitante_id": string,"tabla": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "campamento_id": string,"created_at"?: string,"descripcion": string,"estado"?: string,"id"?: string,"registro_id"?: string | null,"respuesta"?: string | null,"resuelto_at"?: string | null,"resuelto_por"?: string | null,"solicitante_id": string,"tabla": string,"updated_at"?: string
                  }
                  Update: {
                    "campamento_id"?: string,"created_at"?: string,"descripcion"?: string,"estado"?: string,"id"?: string,"registro_id"?: string | null,"respuesta"?: string | null,"resuelto_at"?: string | null,"resuelto_por"?: string | null,"solicitante_id"?: string,"tabla"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "solicitudes_revision_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "solicitudes_revision_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"tipos_calculo": {
                  Row: {
                    "clave": string,"created_at": string,"descripcion": string | null,"formula": string | null,"nombre": string,"orden": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "clave": string,"created_at"?: string,"descripcion"?: string | null,"formula"?: string | null,"nombre": string,"orden"?: number,"updated_at"?: string
                  }
                  Update: {
                    "clave"?: string,"created_at"?: string,"descripcion"?: string | null,"formula"?: string | null,"nombre"?: string,"orden"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                }
          }
          Views: {
            "publico_calendario": {
                  Row: {
                    "abarca": string | null,"campamento_id": string,"categoria": string,"codigo": string,"estado": string,"evidencia": string | null,"id": string,"momento": string,"no_abarca": string | null,"nombre": string,"orden": number,"puntaje_max": number,"tipo_calculo": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "criterios_categoria_fk"
      columns: ["categoria"]
isOneToOne: false
      referencedRelation: "categorias_criterios"
      referencedColumns: ["clave"]
    },{
      foreignKeyName: "criterios_tipo_calculo_fk"
      columns: ["tipo_calculo"]
isOneToOne: false
      referencedRelation: "tipos_calculo"
      referencedColumns: ["clave"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"publico_campamento": {
                  Row: {
                    "activo": boolean,"edicion": string,"id": string,"nombre": string
                  }
                  ComputedFields: never
                  Insert: {
                           "activo"?: boolean | null,"edicion"?: string | null,"id"?: string | null,"nombre"?: string | null
                         }
                        Update: {
                           "activo"?: boolean | null,"edicion"?: string | null,"id"?: string | null,"nombre"?: string | null
                         }
                        Relationships: [
                    
                  ]
                },"publico_criterios": {
                  Row: {
                    "abarca": string | null,"categoria": string,"codigo": string,"evidencia": string | null,"no_abarca": string | null,"nombre": string,"orden": number,"tipo_calculo": string
                  }
                  ComputedFields: never
                  Insert: {
                           "abarca"?: string | null,"categoria"?: string | null,"codigo"?: string | null,"evidencia"?: string | null,"no_abarca"?: string | null,"nombre"?: string | null,"orden"?: number | null,"tipo_calculo"?: string | null
                         }
                        Update: {
                           "abarca"?: string | null,"categoria"?: string | null,"codigo"?: string | null,"evidencia"?: string | null,"no_abarca"?: string | null,"nombre"?: string | null,"orden"?: number | null,"tipo_calculo"?: string | null
                         }
                        Relationships: [
                    {
      foreignKeyName: "criterios_categoria_fk"
      columns: ["categoria"]
isOneToOne: false
      referencedRelation: "categorias_criterios"
      referencedColumns: ["clave"]
    },{
      foreignKeyName: "criterios_tipo_calculo_fk"
      columns: ["tipo_calculo"]
isOneToOne: false
      referencedRelation: "tipos_calculo"
      referencedColumns: ["clave"]
    }
                  ]
                },"publico_equipos": {
                  Row: {
                    "campamento_id": string,"color": string,"escuela_profesional": string,"id": string,"nombre": string
                  }
                  ComputedFields: never
                  Insert: {
                           "campamento_id"?: string | null,"color"?: string | null,"escuela_profesional"?: string | null,"id"?: string | null,"nombre"?: string | null
                         }
                        Update: {
                           "campamento_id"?: string | null,"color"?: string | null,"escuela_profesional"?: string | null,"id"?: string | null,"nombre"?: string | null
                         }
                        Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"publico_ficha_equipo": {
                  Row: {
                    "campamento_id": string | null,"criterio_categoria": string | null,"criterio_nombre": string | null,"equipo_id": string | null,"maximo_posible": number | null,"momento": string | null,"puntaje_obtenido": number | null,"tipo_fila": string | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"publico_incidencias_resumen": {
                  Row: {
                    "codigo": string,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"fecha": string,"momento": string | null,"puntos": number,"tipo": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "incidencia_codigos"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_bonus_equipo"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_demeritos_equipo"
      referencedColumns: ["codigo"]
    }
                  ]
                },"publico_liderazgo_indicadores": {
                  Row: {
                    "codigo": string,"descripcion": string,"evidencia": string,"nombre": string
                  }
                  ComputedFields: never
                  Insert: {
                           "codigo"?: string | null,"descripcion"?: string | null,"evidencia"?: string | null,"nombre"?: string | null
                         }
                        Update: {
                           "codigo"?: string | null,"descripcion"?: string | null,"evidencia"?: string | null,"nombre"?: string | null
                         }
                        Relationships: [
                    
                  ]
                },"publico_ranking": {
                  Row: {
                    "campamento_id": string,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"medalla": string | null,"posicion": number | null,"pts_asistencia": number | null,"pts_bonus": number | null,"pts_bruto": number | null,"pts_demeritos": number | null,"pts_escala": number | null,"pts_inscripcion": number | null,"pts_liderazgo": number | null,"pts_rubrica": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_asistencia_equipo_actividad": {
                  Row: {
                    "actividad_estado": string,"actividad_id": string,"actividad_nombre": string,"ausentes": number | null,"convocados_elegibles": number | null,"criterio_id": string,"elegibles": number | null,"equipo_id": string,"equipo_nombre": string,"justificados": number | null,"momento": string,"presentes": number | null,"provisional": boolean | null,"puntaje": number | null,"sin_registro": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "criterios"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "publico_calendario"
      referencedColumns: ["id"]
    }
                  ]
                },"v_asistencia_equipo_dia": {
                  Row: {
                    "actividades_con_puntaje": number | null,"criterio_id": string,"equipo_id": string,"equipo_nombre": string,"momento": string,"num_actividades": number | null,"provisional": boolean | null,"puntaje_promedio": number | null,"reprogramar": boolean | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "criterios"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_criterio_id_fkey"
      columns: ["criterio_id"]
isOneToOne: false
      referencedRelation: "publico_calendario"
      referencedColumns: ["id"]
    }
                  ]
                },"v_auditoria_legible": {
                  Row: {
                    "accion": string,"cambios": Json | null,"created_at": string,"datos_anteriores": Json | null,"datos_nuevos": Json | null,"evaluador_nombre": string | null,"evaluador_rol": string | null,"id": string,"registro_id": string,"tabla": string,"usuario_id": string | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"v_bonus_equipo": {
                  Row: {
                    "acciones_validadas": number | null,"bonus_codigo": number | null,"bonus_total": number | null,"campamento_id": string,"codigo": string,"codigo_nombre": string,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"puntos_por_accion": number
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    }
                  ]
                },"v_demeritos_equipo": {
                  Row: {
                    "campamento_id": string,"codigo": string,"codigo_nombre": string,"demeritos_codigo": number | null,"demeritos_total": number | null,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"incidencias_validadas": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    }
                  ]
                },"v_incidencias_pendientes": {
                  Row: {
                    "alcance": string,"campamento_id": string,"codigo": string,"codigo_nombre": string,"created_at": string,"descargo_equipo": string | null,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"estado": string,"fecha": string,"hecho": string,"hora": string,"id": string,"momento": string | null,"puntos": number,"registrado_por": string,"registrado_por_nombre": string,"tipo": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "incidencia_codigos"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_bonus_equipo"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_codigo_fkey"
      columns: ["codigo"]
isOneToOne: false
      referencedRelation: "v_demeritos_equipo"
      referencedColumns: ["codigo"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_equipos"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_incidencias_resumen"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "publico_ranking"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_actividad"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_asistencia_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_inscripcion_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_liderazgo_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_equipo"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_equipo_id_fkey"
      columns: ["equipo_id"]
isOneToOne: false
      referencedRelation: "v_puntaje_rubrica_equipo_dia"
      referencedColumns: ["equipo_id"]
    },{
      foreignKeyName: "incidencias_registrado_por_fkey"
      columns: ["registrado_por"]
isOneToOne: false
      referencedRelation: "perfiles"
      referencedColumns: ["id"]
    }
                  ]
                },"v_inscripcion_equipo": {
                  Row: {
                    "campamento_id": string,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"inscritos_completos": number | null,"inscritos_parciales": number | null,"inscritos_tardios": number | null,"nomina": number | null,"puntaje_inscripcion": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_liderazgo_equipo_dia": {
                  Row: {
                    "campamento_id": string,"completo": boolean | null,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"indicadores_calificados": number | null,"momento": string,"programacion_id": string,"puntos_max": number | null,"puntos_obtenidos": number | null,"total_indicadores": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_pendientes_publicacion": {
                  Row: {
                    "campamento_id": string,"cerrado": boolean,"equipos_activos": number | null,"equipos_liderazgo": number | null,"equipos_rubrica": number | null,"momento": string,"publicado": boolean,"tiene_asistencia": boolean | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "dias_evaluacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dias_evaluacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_progreso_evaluacion": {
                  Row: {
                    "campamento_id": string,"momento": string,"observaciones_esperadas": number | null,"observaciones_registradas": number | null,"porcentaje": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_puntaje_equipo": {
                  Row: {
                    "campamento_id": string,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"medalla": string | null,"posicion": number | null,"pts_asistencia": number | null,"pts_base": number | null,"pts_bonus": number | null,"pts_bruto": number | null,"pts_demeritos": number | null,"pts_escala": number | null,"pts_inscripcion": number | null,"pts_liderazgo": number | null,"pts_rubrica": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_puntaje_rubrica_equipo_dia": {
                  Row: {
                    "campamento_id": string,"criterios_calificados": number | null,"criterios_pendientes": number | null,"equipo_color": string,"equipo_id": string,"equipo_nombre": string,"maximo_posible": number | null,"momento": string,"suma_puntaje": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "equipos_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_resumen_programacion": {
                  Row: {
                    "campamento_id": string | null,"cancelados": number | null,"categoria": string | null,"maximo_programado": number | null,"momento": string | null,"total_filas": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "criterios_categoria_fk"
      columns: ["categoria"]
isOneToOne: false
      referencedRelation: "categorias_criterios"
      referencedColumns: ["clave"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "campamento"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "programacion_campamento_id_fkey"
      columns: ["campamento_id"]
isOneToOne: false
      referencedRelation: "publico_campamento"
      referencedColumns: ["id"]
    }
                  ]
                },"v_validacion_indicadores": {
                  Row: {
                    "ok": boolean | null,"puntaje_total_activos": number | null,"total_activos": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                }
          }
          Functions: {
            "activar_campamento":
{ Args: { "p_id": string }; Returns: undefined
                           },
"aplicar_plantilla_a_campamento":
{ Args: { "p_campamento_id": string,"p_items": Json }; Returns: number
                           },
"cerrar_campamento":
{ Args: { "p_campamento_id": string,"p_forzar"?: boolean,"p_motivo": string }; Returns: undefined
                           } |
{ Args: { "p_forzar"?: boolean,"p_motivo": string }; Returns: undefined
                           },
"desactivar_campamento":
{ Args: { "p_id": string }; Returns: undefined
                           },
"es_admin":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"fn_campamento_cerrado_check":
{ Args: Record<PropertyKey, never>; Returns: undefined
                           } |
{ Args: { "p_campamento_id": string }; Returns: undefined
                           },
"fn_diff_jsonb":
{ Args: { "antes": Json,"despues": Json }; Returns: Json
                           },
"historial_registro":
{ Args: { "p_id": string,"p_tabla": string }; Returns: {
              "accion": string,"cambios": Json,"created_at": string,"datos_anteriores": Json,"datos_nuevos": Json,"evaluador_nombre": string,"evaluador_rol": string,"id": string
            }[]
                           },
"inicializar_programacion_campamento":
{ Args: { "p_campamento_id": string,"p_source_campamento_id"?: string }; Returns: number
                           },
"obtener_rol":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"reabrir_campamento":
{ Args: { "p_campamento_id": string,"p_motivo": string }; Returns: undefined
                           } |
{ Args: { "p_motivo": string }; Returns: undefined
                           },
"resolver_solicitud":
{ Args: { "p_decision": string,"p_id": string,"p_respuesta"?: string }; Returns: undefined
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            
          }
        }
} as const
