// Copia este archivo como config.js y agrega valores del panel de Supabase.
// La publishable key puede estar en el navegador. Nunca pongas aquí la service_role key.
const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_TU_CLAVE_PUBLICABLE';

if (!SUPABASE_URL.includes('TU-PROYECTO') && !SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')) {
  window.pcmatchSupabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
}
