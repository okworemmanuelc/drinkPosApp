// Single source of truth for the invite error-code catalog.
// Every Edge Function returns one of these codes; the Flutter client
// (InviteApiService) mirrors this enum so error-handling stays type-safe
// across the wire.

import { corsHeaders } from "./cors.ts";

export type InviteErrorCode =
  | "unauthenticated"
  | "forbidden"
  | "invalid_payload"
  | "invalid_email"
  | "disposable_email"
  | "self_invite"
  | "already_member"
  | "invite_pending"
  | "other_business_owner"
  | "invalid_warehouse"
  | "forbidden_role"
  | "rate_limited"
  | "invalid_token"
  | "expired"
  | "revoked"
  | "already_used"
  | "email_mismatch"
  | "internal";

const messages: Record<InviteErrorCode, string> = {
  unauthenticated: "Please sign in again.",
  forbidden: "Only managers and owners can send invitations.",
  invalid_payload: "Some details are missing. Please try again.",
  invalid_email: "Enter a valid email address.",
  disposable_email: "Disposable email addresses aren't allowed.",
  self_invite: "You can't invite yourself.",
  already_member: "This person is already on your team.",
  invite_pending: "An invite to this email is already pending.",
  other_business_owner:
    "This email belongs to the owner of another business.",
  invalid_warehouse: "Pick a warehouse from your business.",
  forbidden_role: "You can't invite someone as CEO.",
  rate_limited: "Too many invites today. Try again tomorrow.",
  invalid_token: "This invite link is invalid.",
  expired: "This invite has expired. Ask your manager for a new one.",
  revoked: "This invite has been cancelled.",
  already_used: "This invite has already been used.",
  email_mismatch: "This invite was sent to a different email.",
  internal: "Something went wrong. Please try again.",
};

const httpStatus: Record<InviteErrorCode, number> = {
  unauthenticated: 401,
  forbidden: 403,
  invalid_payload: 400,
  invalid_email: 400,
  disposable_email: 400,
  self_invite: 400,
  already_member: 409,
  invite_pending: 409,
  other_business_owner: 409,
  invalid_warehouse: 400,
  forbidden_role: 400,
  rate_limited: 429,
  invalid_token: 404,
  expired: 410,
  revoked: 410,
  already_used: 409,
  email_mismatch: 403,
  internal: 500,
};

export function errorResponse(
  code: InviteErrorCode,
  details?: Record<string, unknown>,
): Response {
  const body: Record<string, unknown> = {
    ok: false,
    error: code,
    message: messages[code],
  };
  if (details) body.details = details;
  return new Response(JSON.stringify(body), {
    status: httpStatus[code],
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}

export function okResponse(payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ ok: true, ...payload }), {
    status: 200,
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}

// Map a SECURITY DEFINER RPC's jsonb response onto a Response. The RPCs
// return `{ ok: true, ... }` or `{ ok: false, error: <code> }`; just
// forward.
export function rpcJsonResponse(rpcResult: unknown): Response {
  if (
    rpcResult &&
    typeof rpcResult === "object" &&
    "ok" in rpcResult &&
    (rpcResult as { ok: unknown }).ok === false &&
    "error" in rpcResult
  ) {
    return errorResponse(
      (rpcResult as { error: InviteErrorCode }).error,
    );
  }
  return new Response(JSON.stringify(rpcResult), {
    status: 200,
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}
