// resend-invite — revoke the existing pending invite and issue a fresh one.
//
// Authenticated; caller must be in the same business as the original
// invite and have role_tier ≥ 4.
//
// Uses the same shared issuance pipeline as send-invite, with two checks
// suppressed: invite_pending (we just revoked the pending row, so its
// own ghost is gone) and already_member (was false at original send and
// can't have flipped without an unrelated action).
//
// Why a separate endpoint instead of `send-invite` with a flag: the
// modal calls check-invite-email first; on `invite_pending` it shows
// a "Resend?" CTA. Tapping that CTA must not re-trigger the same check
// (which would just return invite_pending again). Routing to a dedicated
// endpoint keeps the client flow linear.

import { handlePreflight } from "../_shared/cors.ts";
import { errorResponse, okResponse } from "../_shared/errors.ts";
import { getCallerClient, getServiceClient } from "../_shared/db.ts";
import { loadCaller } from "../_shared/auth.ts";
import { issueInvite } from "../_shared/issue.ts";
import { isUuid } from "../_shared/validation.ts";

interface RequestBody {
  invite_id?: string;
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

  if (!isUuid(body.invite_id)) return errorResponse("invalid_payload");

  const service = getServiceClient();
  const caller = getCallerClient(req);
  const ctx = await loadCaller(caller, service);
  if (!ctx) return errorResponse("unauthenticated");
  if (ctx.roleTier < 4) return errorResponse("forbidden");

  // Load the existing row. Must belong to the caller's business.
  const { data: existing, error: loadErr } = await service
    .from("invites")
    .select("id, business_id, email, role, warehouse_id, status")
    .eq("id", body.invite_id)
    .maybeSingle();
  if (loadErr) return errorResponse("internal");
  if (!existing) return errorResponse("invalid_token");
  if (existing.business_id !== ctx.businessId) {
    // Don't leak which businesses have which invites — refuse generically.
    return errorResponse("forbidden");
  }

  // Flip pending→revoked. Already-revoked or already-accepted rows are
  // left alone; we still issue a fresh invite for the same email.
  if (existing.status === "pending") {
    const { error: revErr } = await service
      .from("invites")
      .update({ status: "revoked", last_updated_at: new Date().toISOString() })
      .eq("id", existing.id);
    if (revErr) return errorResponse("internal");
  }

  const result = await issueInvite(service, ctx, {
    email: existing.email,
    role: existing.role,
    warehouseId: existing.warehouse_id,
    skipPendingCheck: true,
    skipMemberCheck: true,
  });

  if (!result.ok) return errorResponse(result.error, result.details);

  return okResponse({
    invite_id: result.inviteId,
    code: result.code,
    url: result.url,
    expires_at: result.expiresAt,
  });
});
