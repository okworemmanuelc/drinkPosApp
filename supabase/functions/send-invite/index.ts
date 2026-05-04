// send-invite — issue a fresh invitation for {email, role, warehouse_id}.
//
// Authenticated; caller must have role_tier ≥ 4. Runs the full pre-check
// ladder (defense in depth — check-invite-email is a UX shortcut, not a
// security gate), generates code + 32-byte URL token, inserts the
// invites row via service_role, and returns the deep-link URL to the
// admin's client. The client opens the OS share sheet with that URL.
//
// The raw token is in the response body once and never logged. Only its
// SHA-256 hash is persisted on the row (`token_hash`).

import { handlePreflight } from "../_shared/cors.ts";
import { errorResponse, okResponse } from "../_shared/errors.ts";
import { getCallerClient, getServiceClient } from "../_shared/db.ts";
import { loadCaller } from "../_shared/auth.ts";
import { issueInvite } from "../_shared/issue.ts";

interface RequestBody {
  email?: string;
  role?: string;
  warehouse_id?: string | null;
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

  const service = getServiceClient();
  const caller = getCallerClient(req);
  const ctx = await loadCaller(caller, service);
  if (!ctx) return errorResponse("unauthenticated");
  if (ctx.roleTier < 4) return errorResponse("forbidden");

  const result = await issueInvite(service, ctx, {
    email: body.email ?? "",
    role: body.role ?? "",
    warehouseId: body.warehouse_id ?? null,
  });

  if (!result.ok) {
    return errorResponse(result.error, result.details);
  }

  return okResponse({
    invite_id: result.inviteId,
    code: result.code,
    url: result.url,
    expires_at: result.expiresAt,
  });
});
