// Supabase client factories.
//   getServiceClient — uses SUPABASE_SERVICE_ROLE_KEY; bypasses RLS. The only
//                      writer of new invites rows in the redesigned model.
//   getCallerClient  — forwards the caller's JWT; used only to resolve the
//                      authenticated user (auth.getUser). Reads of business
//                      data go through the service client + RPCs that take
//                      the resolved business_id explicitly, so RLS plumbing
//                      stays out of the function bodies.

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.45.4";

export function getServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function getCallerClient(req: Request): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authHeader } },
  });
}
