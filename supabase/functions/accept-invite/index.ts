// accept-invite — anon-callable preview of an invite by 8-char human_code.
//
// Wraps a direct query against the invites table (service client → bypass
// RLS) and returns the InvitePreview shape the Flutter client consumes
// before showing the signup wizard. Used by:
//   • InviteCodeScreen — manual entry → preview before wizard.
//
// Rev 3 simplifications vs rev 2:
//   • Token branch removed — no producer ships URL tokens to recipients
//     anymore (no email/SMS dispatch).
//   • 8-char `code` (legacy) branch removed — only human_code is used now.

import { handlePreflight } from "../_shared/cors.ts";
import { errorResponse, okResponse } from "../_shared/errors.ts";
import { getServiceClient } from "../_shared/db.ts";

interface RequestBody {
  human_code?: string;
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

  const hc = (body.human_code ?? "").trim().toUpperCase();
  if (hc.length === 0) return errorResponse("invalid_payload");

  const service = getServiceClient();

  const { data: inv, error: invErr } = await service
    .from("invites")
    .select(
      "id, business_id, role, warehouse_id, email, expires_at, status, created_by",
    )
    .eq("human_code", hc)
    .eq("status", "pending")
    .maybeSingle();
  if (invErr) return errorResponse("internal");
  if (!inv) return errorResponse("invalid_token");
  if (new Date(inv.expires_at).getTime() < Date.now()) {
    return errorResponse("expired");
  }

  const [{ data: biz }, { data: wh }, { data: inviter }] = await Promise.all([
    service.from("businesses").select("name").eq("id", inv.business_id)
      .maybeSingle(),
    inv.warehouse_id
      ? service.from("warehouses").select("name").eq("id", inv.warehouse_id)
        .maybeSingle()
      : Promise.resolve({ data: null }),
    service.from("users").select("name").eq("id", inv.created_by).maybeSingle(),
  ]);

  return okResponse({
    invite_id: inv.id,
    business_id: inv.business_id,
    business_name: biz?.name ?? "Unknown Business",
    role: inv.role,
    warehouse_id: inv.warehouse_id,
    warehouse_name: wh?.name ?? null,
    email: inv.email,
    expires_at: inv.expires_at,
    inviter_name: inviter?.name ?? "your manager",
  });
});
