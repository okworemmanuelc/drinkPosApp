// Caller resolution for invite Edge Functions.
//
// Resolves auth.uid → email → profiles row → matching public.users row.
// The users row is needed for `created_by` on inserts.
//
// All Edge Functions that require a caller (everything except the anon
// branch of accept-invite) call loadCaller; if it returns null the caller
// gets `unauthenticated`.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export interface CallerContext {
  authUserId: string;
  email: string;
  businessId: string;
  roleTier: number;
  callerUserId: string; // public.users.id, for invite.created_by
  callerName: string;
}

export async function loadCaller(
  callerClient: SupabaseClient,
  serviceClient: SupabaseClient,
): Promise<CallerContext | null> {
  const { data: userResp, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userResp?.user) return null;
  const u = userResp.user;
  if (!u.email) return null;

  // profiles is keyed on auth.uid(); RLS allows the caller to read their
  // own row, but using service avoids a second JWT round-trip.
  const { data: profile, error: profErr } = await serviceClient
    .from("profiles")
    .select("business_id, role_tier")
    .eq("id", u.id)
    .maybeSingle();
  if (profErr || !profile) return null;

  // The matching public.users row inside this business. There is exactly
  // one (UNIQUE on business_id, email; auth_user_id pins it). If it's
  // missing, the account is in an inconsistent state — refuse rather than
  // synthesise a UUID for created_by.
  const { data: usrRow } = await serviceClient
    .from("users")
    .select("id, name")
    .eq("auth_user_id", u.id)
    .eq("business_id", profile.business_id)
    .maybeSingle();
  if (!usrRow) return null;

  return {
    authUserId: u.id,
    email: u.email.toLowerCase(),
    businessId: profile.business_id,
    roleTier: profile.role_tier ?? 1,
    callerUserId: usrRow.id,
    callerName: usrRow.name ?? "",
  };
}
