import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Cliente admin (service_role) — solo existe server-side en Edge Functions
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Verificar que el llamante es admin
    const authorization = req.headers.get('Authorization') ?? ''
    const token = authorization.replace('Bearer ', '')

    const { data: { user: caller }, error: authErr } = await supabaseAdmin.auth.getUser(token)
    if (authErr || !caller) {
      return new Response(JSON.stringify({ error: 'No autenticado' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: callerPerfil } = await supabaseAdmin
      .from('perfiles')
      .select('rol')
      .eq('id', caller.id)
      .single()

    if (callerPerfil?.rol !== 'admin') {
      return new Response(JSON.stringify({ error: 'Solo el administrador puede gestionar usuarios' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const { action } = body

    // ── Crear usuario ──────────────────────────────────────────────────────────
    if (action === 'crear') {
      const { nombre_completo, email, password, rol } = body

      if (!nombre_completo || !email || !password) {
        return new Response(JSON.stringify({ error: 'Faltan campos obligatorios' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const { data, error } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,                    // confirmar email automáticamente
        user_metadata: { nombre_completo },
      })

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      // El trigger tr_crear_perfil inserta con rol='evaluador'.
      // Si el admin eligió 'admin', actualizamos.
      if (rol === 'admin' && data.user) {
        await supabaseAdmin
          .from('perfiles')
          .update({ rol: 'admin' })
          .eq('id', data.user.id)
      }

      return new Response(JSON.stringify({ ok: true, user_id: data.user?.id }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ── Cambiar contraseña ─────────────────────────────────────────────────────
    if (action === 'cambiar_password') {
      const { user_id, password } = body

      if (!user_id || !password) {
        return new Response(JSON.stringify({ error: 'Faltan campos obligatorios' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      if (password.length < 6) {
        return new Response(JSON.stringify({ error: 'La contraseña debe tener al menos 6 caracteres' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const { error } = await supabaseAdmin.auth.admin.updateUserById(user_id, { password })

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      return new Response(JSON.stringify({ ok: true }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ error: 'Acción no reconocida' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
