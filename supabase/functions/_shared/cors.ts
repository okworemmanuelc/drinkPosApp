// Standard CORS headers for the invite Edge Functions.
// All five functions are POST-only and accept JSON; the headers below cover
// the preflight and actual-request needs without granting anything beyond
// what supabase-js already requires.

export const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function handlePreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
