// redeem-invite — finalise the invitee's join, by token OR by code.
//
// Authenticated; the invitee just signed in via OTP. Calls the SECURITY
// DEFINER RPC redeem_invite / redeem_invite_by_code which atomically:
//   • verifies token + status + expiry + email match
//   • inserts public.profiles for auth.uid()  (the gate that unlocks
//     public.business_id() for subsequent queries)
//   • upserts public.users with the granular role / collapsed tier
//   • marks the invite accepted
//
// All inside one transaction with SELECT … FOR UPDATE on the invite row,
// so two devices clicking the same link race to the lock and the loser
// sees `already_used`.

import { handlePreflight } from "../_shared/cors.ts";
import { errorResponse, rpcJsonResponse } from "../_shared/errors.ts";
import { getCallerClient } from "../_shared/db.ts";

interface RequestBody {
  user_name?: string;
  token?: string;
  code?: string;
}

Deno.serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;

  if (req.method !== "POST") return errorResponse("invalid_payload");

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_payload");
  }

  const userName = (body.user_name ?? "").trim();
  if (userName.length === 0) return errorResponse("invalid_payload");

  const hasToken = typeof body.token === "string" && body.token.length > 0;
  const hasCode = typeof body.code === "string" && body.code.length > 0;
  if (hasToken === hasCode) return errorResponse("invalid_payload");

  // Use the caller client so the RPC sees auth.uid() / auth.jwt().email.
  // The RPC is SECURITY DEFINER so RLS is bypassed inside it; we only
  // need the JWT for identity, not for RLS access.
  const caller = getCallerClient(req);

  // Cheap unauthenticated check up-front.
  const { data: userResp } = await caller.auth.getUser();
  if (!userResp?.user) return errorResponse("unauthenticated");

  if (hasToken) {
    const { data, error } = await caller.rpc("redeem_invite", {
      p_token: body.token,
      p_user_name: userName,
    });
    if (error) return errorResponse("internal");
    return rpcJsonResponse(data);
  }

  const { data, error } = await caller.rpc("redeem_invite_by_code", {
    p_code: body.code,
    p_user_name: userName,
  });
  if (error) return errorResponse("internal");
  return rpcJsonResponse(data);
});
