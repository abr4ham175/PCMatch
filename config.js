// Configuración pública. Reemplaza estos valores con los de Settings > API en Supabase.
// La clave publicable es segura para usar en el navegador cuando las políticas RLS están activas.
// Nunca pegues aquí la clave service_role ni el Client Secret de Google.
const SUPABASE_URL = 'https://cfvdhsgilluppwmfzaet.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_XajkimHh2FU6Lx6HMimfjA_HWCi7E9Q';

if (!SUPABASE_URL.includes('TU-PROYECTO') && !SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')) {
  window.pcmatchSupabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
}

