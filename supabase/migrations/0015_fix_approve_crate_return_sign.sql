-- =============================================================================
-- 0015_fix_approve_crate_return_sign.sql — fix the sign convention in
-- pos_approve_crate_return so it matches the rest of the codebase.
--
-- 0011's original body stored `+v_pending.quantity` in both crate_ledger
-- and the customer_crate_balances cache delta. That contradicts the
-- semantic used everywhere else:
--
--   - customer_crate_balances.balance > 0 means "customer owes us crates"
--     (see lib/features/customers/screens/customer_detail_screen.dart
--     where balance > 0 renders as "X crates owed").
--   - The sister RPC pos_record_crate_return takes a signed
--     p_quantity_delta and uses it as-is; the client passes
--     `delta = -quantity` for returns
--     (lib/core/database/daos.dart CrateLedgerDao.recordCrateReturnByCustomer).
--   - The v1 CrateReturnApprovalService.approve also computes
--     `delta = -pending.quantity`.
--
-- With the buggy sign, approving a return of 5 crates against a balance
-- of 10 left the cache at 15 ("more owed") instead of 5. This migration
-- negates the delta in both writes so a return reduces what's owed.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_approve_crate_return(
  p_business_id        uuid,
  p_actor_id           uuid,
  p_pending_return_id  uuid,
  p_ledger_id          uuid   -- idempotency key for crate_ledger row
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_pending       record;
  v_already       bool;
  v_balance_row   record;
  v_ledger_row    jsonb;
  v_pending_row   jsonb;
  v_balance_jsonb jsonb;
  v_delta         int;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  SELECT * INTO v_pending FROM public.pending_crate_returns
   WHERE id = p_pending_return_id AND business_id = p_business_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'pending_return_not_found' USING ERRCODE = 'P0001';
  END IF;

  -- Replay path.
  SELECT EXISTS(SELECT 1 FROM public.crate_ledger WHERE id = p_ledger_id) INTO v_already;
  IF v_already AND v_pending.status = 'approved' THEN
    SELECT to_jsonb(pcr.*) INTO v_pending_row FROM public.pending_crate_returns pcr WHERE pcr.id = p_pending_return_id;
    SELECT to_jsonb(cl.*)  INTO v_ledger_row  FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;
    SELECT to_jsonb(ccb.*) INTO v_balance_jsonb
      FROM public.customer_crate_balances ccb
      WHERE ccb.business_id = p_business_id
        AND ccb.customer_id = v_pending.customer_id
        AND ccb.crate_group_id = v_pending.crate_group_id;
    RETURN jsonb_build_object(
      'pending_return',    v_pending_row,
      'crate_ledger_row',  v_ledger_row,
      'balance_row',       v_balance_jsonb,
      'replayed',          true
    );
  END IF;

  IF v_pending.status <> 'pending' THEN
    RAISE EXCEPTION 'cannot_approve_status_%', v_pending.status USING ERRCODE = 'P0001';
  END IF;

  -- Returns reduce what the customer owes. pending.quantity is positive
  -- (CHECK quantity > 0); negate for the ledger + balance increment.
  v_delta := -v_pending.quantity;

  UPDATE public.pending_crate_returns
     SET status      = 'approved',
         approved_by = p_actor_id,
         approved_at = v_now
   WHERE id = p_pending_return_id;

  INSERT INTO public.crate_ledger (
    id, business_id, customer_id, manufacturer_id, crate_group_id,
    quantity_delta, movement_type, reference_order_id, reference_return_id,
    performed_by, created_at, last_updated_at
  )
  VALUES (
    p_ledger_id, p_business_id, v_pending.customer_id, NULL, v_pending.crate_group_id,
    v_delta, 'returned', NULL, p_pending_return_id,
    p_actor_id, v_now, v_now
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.customer_crate_balances (
    id, business_id, customer_id, crate_group_id, balance, created_at, last_updated_at
  )
  VALUES (
    gen_random_uuid(), p_business_id, v_pending.customer_id, v_pending.crate_group_id,
    v_delta, v_now, v_now
  )
  ON CONFLICT (business_id, customer_id, crate_group_id)
    DO UPDATE SET balance = public.customer_crate_balances.balance + EXCLUDED.balance,
                  last_updated_at = v_now
  RETURNING * INTO v_balance_row;

  SELECT to_jsonb(pcr.*) INTO v_pending_row FROM public.pending_crate_returns pcr WHERE pcr.id = p_pending_return_id;
  SELECT to_jsonb(cl.*)  INTO v_ledger_row  FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;

  RETURN jsonb_build_object(
    'pending_return',   v_pending_row,
    'crate_ledger_row', v_ledger_row,
    'balance_row',      to_jsonb(v_balance_row),
    'replayed',         false
  );
END;
$$;
