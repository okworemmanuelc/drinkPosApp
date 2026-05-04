// accept-invite — anon-callable preview of an invite, by token OR by code.
//
// Wraps the SECURITY DEFINER RPCs accept_invite_preview /
// accept_invite_preview_by_code. Used by:
//   • InviteLandingScreen (deep link → token)
//   • InviteCodeScreen   (manual fallback → code)
//
// Returns business name, role, warehouse name, inviter name, expires_at,
// and the email the invite was issued to. Used to render the "You've been
// invited to {Business}" preview before the invitee signs in.

import { handlePreflight } from "../_shared/cors.ts";
import { errorResponse, rpcJsonResponse } from "../_shared/errors.ts";
import { getServiceClient } from "../_shared/db.ts";

interface RequestBody {
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

  // Exactly one of token/code must be provided.
  const hasToken = typeof body.token === "string" && body.token.length > 0;
  const hasCode = typeof body.code === "string" && body.code.length > 0;
  if (hasToken === hasCode) return errorResponse("invalid_payload");

  const service = getServiceClient();

  if (hasToken) {
    const { data, error } = await service.rpc("accept_invite_preview", {
      p_token: body.token,
    });
    if (error) return errorResponse("internal");
    return rpcJsonResponse(data);
  }

  const { data, error } = await service.rpc(
    "accept_invite_preview_by_code",
    { p_code: body.code },
  );
  if (error) return errorResponse("internal");
  return rpcJsonResponse(data);
});
