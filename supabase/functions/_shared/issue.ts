// Shared invite-issuance pipeline used by send-invite and resend-invite.
//
// Runs the full pre-check ladder, generates code + token, and inserts the
// invites row via the service client (bypassing the RLS chokepoint that
// blocks authenticated INSERT).
//
// The raw token is built here, included once in the returned `url`, and
// never logged. Only its SHA-256 hash is persisted (`token_hash`).

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import type { CallerContext } from "./auth.ts";
import {
  generateCode,
  generateToken,
  isDisposableEmail,
  isUuid,
  isValidEmail,
  isValidGranularRole,
  sha256Hex,
} from "./validation.ts";
import type { InviteErrorCode } from "./errors.ts";

const DAILY_LIMIT = parseInt(
  Deno.env.get("INVITE_DAILY_LIMIT_PER_BUSINESS") ?? "50",
  10,
);
const TTL_HOURS = parseInt(Deno.env.get("INVITE_TTL_HOURS") ?? "48", 10);
const DEEP_LINK_BASE = Deno.env.get("INVITE_DEEP_LINK_BASE") ??
  "reebaplus://invite";

export interface IssueInviteInput {
  email: string;
  role: string;
  warehouseId: string | null;
  // Skips for the resend path: we just revoked the prior pending invite,
  // so an invite_pending check would return our own ghost. already_member
  // was false at the original send and can't have flipped to true without
  // a separate action.
  skipPendingCheck?: boolean;
  skipMemberCheck?: boolean;
}

export type IssueResult =
  | {
    ok: true;
    inviteId: string;
    code: string;
    url: string;
    expiresAt: string;
  }
  | {
    ok: false;
    error: InviteErrorCode;
    details?: Record<string, unknown>;
  };

export async function issueInvite(
  service: SupabaseClient,
  ctx: CallerContext,
  input: IssueInviteInput,
): Promise<IssueResult> {
  const email = (input.email ?? "").trim().toLowerCase();

  // --- cheap pre-checks (no DB) ----------------------------------------
  if (!isValidEmail(email)) return { ok: false, error: "invalid_email" };
  if (isDisposableEmail(email)) {
    return { ok: false, error: "disposable_email" };
  }
  if (email === ctx.email) return { ok: false, error: "self_invite" };
  if (!isValidGranularRole(input.role)) {
    return { ok: false, error: "invalid_payload" };
  }
  if (input.role === "ceo") return { ok: false, error: "forbidden_role" };
  if (input.warehouseId !== null && !isUuid(input.warehouseId)) {
    return { ok: false, error: "invalid_payload" };
  }

  // --- DB pre-checks ---------------------------------------------------
  if (!input.skipMemberCheck) {
    const { data: isMember, error: memErr } = await service.rpc(
      "is_business_member_email",
      { p_business_id: ctx.businessId, p_email: email },
    );
    if (memErr) return { ok: false, error: "internal" };
    if (isMember === true) return { ok: false, error: "already_member" };
  }

  const { data: isOwner, error: ownErr } = await service.rpc(
    "is_other_business_owner",
    { p_email: email, p_exclude_business_id: ctx.businessId },
  );
  if (ownErr) return { ok: false, error: "internal" };
  if (isOwner === true) return { ok: false, error: "other_business_owner" };

  if (!input.skipPendingCheck) {
    const { data: pending } = await service
      .from("invites")
      .select("id, expires_at")
      .eq("business_id", ctx.businessId)
      .ilike("email", email)
      .eq("status", "pending")
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (pending) {
      return {
        ok: false,
        error: "invite_pending",
        details: {
          invite_id: pending.id,
          expires_at: pending.expires_at,
        },
      };
    }
  }

  if (input.warehouseId) {
    const { data: wh } = await service
      .from("warehouses")
      .select("id")
      .eq("id", input.warehouseId)
      .eq("business_id", ctx.businessId)
      .maybeSingle();
    if (!wh) return { ok: false, error: "invalid_warehouse" };
  }

  // Atomic rate limit derived from the invites table itself — always
  // consistent, no separate counter to drift, no read-modify-write race.
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);
  const { count, error: cntErr } = await service
    .from("invites")
    .select("id", { count: "exact", head: true })
    .eq("business_id", ctx.businessId)
    .gte("created_at", startOfDay.toISOString());
  if (cntErr) return { ok: false, error: "internal" };
  if ((count ?? 0) >= DAILY_LIMIT) return { ok: false, error: "rate_limited" };

  // --- write the row ---------------------------------------------------
  // Retry up to 3 times on code/token uniqueness collisions (23505).
  const expiresAt = new Date(Date.now() + TTL_HOURS * 3600 * 1000)
    .toISOString();
  for (let attempt = 0; attempt < 3; attempt++) {
    const code = generateCode();
    const token = generateToken();
    const tokenHash = await sha256Hex(token);

    const { data, error } = await service
      .from("invites")
      .insert({
        business_id: ctx.businessId,
        email,
        code,
        role: input.role,
        warehouse_id: input.warehouseId,
        created_by: ctx.callerUserId,
        // invitee_name is legacy NOT NULL on the original schema; the
        // invitee provides their actual name during onboarding (lands on
        // users.name via redeem_invite). Pass an empty string to satisfy
        // the constraint.
        invitee_name: "",
        status: "pending",
        expires_at: expiresAt,
        token_hash: tokenHash,
      })
      .select("id, code, expires_at")
      .single();

    if (error) {
      if ((error as { code?: string }).code === "23505") continue;
      return { ok: false, error: "internal" };
    }

    return {
      ok: true,
      inviteId: data.id,
      code: data.code,
      url: `${DEEP_LINK_BASE}?token=${token}`,
      expiresAt: data.expires_at,
    };
  }

  return { ok: false, error: "internal" };
}
