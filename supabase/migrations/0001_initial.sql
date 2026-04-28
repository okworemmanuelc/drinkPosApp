-- =============================================================================
-- 0001_initial.sql — Wipe and recreate the public schema with the final design.
--
-- This migration is destructive: it drops every object in the public schema
-- and rebuilds from scratch. Take a `pg_dump` of the database before running.
--
-- Conventions baked in (per the Phase 1 plan):
--   • Every PK is uuid. Server-side inserts use gen_random_uuid().
--     Client-side inserts pass UUIDv7 from the app.
--   • Every tenant table has business_id uuid NOT NULL. The `businesses`
--     table is the only top-level table and uses its own id as the tenant key.
--   • Every synced table has last_updated_at timestamptz NOT NULL DEFAULT now()
--     plus a BEFORE UPDATE trigger that bumps it.
--   • Composite index (business_id, last_updated_at) on every synced tenant
--     table for the incremental-pull cursor.
--   • Soft-deletable tables carry is_deleted; ledger (append-only) tables
--     carry voided_at/voided_by/void_reason and never is_deleted.
--   • Append-only tables get an immutability trigger that rejects any UPDATE
--     touching non-void columns, plus a BEFORE DELETE trigger that always
--     raises.
--   • CHECK constraints on every status/role/type column.
--   • No nullable business_id, no sentinel business_id, no polymorphic
--     (reference_id, type) FKs, no JSON-blob columns where a structured
--     table fits.
--
-- RLS is configured separately in 0002_rls.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Wipe
-- -----------------------------------------------------------------------------

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL   ON SCHEMA public TO postgres;

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- -----------------------------------------------------------------------------
-- 1. Reusable trigger functions
-- -----------------------------------------------------------------------------

-- Bump last_updated_at on every UPDATE. Attached per-table at the end.
CREATE OR REPLACE FUNCTION public.bump_last_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_updated_at := now();
  RETURN NEW;
END $$;

-- Increment products.version on every UPDATE (cart staleness detection).
CREATE OR REPLACE FUNCTION public.bump_products_version()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.version := COALESCE(OLD.version, 0) + 1;
  RETURN NEW;
END $$;

-- Append-only enforcement: only the void columns and last_updated_at may
-- change on an UPDATE. Every other column must equal its OLD value. The
-- list of immutable columns is provided via TG_ARGV so this single function
-- serves every ledger table.
CREATE OR REPLACE FUNCTION public.enforce_append_only()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  col text;
  old_val text;
  new_val text;
BEGIN
  FOREACH col IN ARRAY TG_ARGV LOOP
    EXECUTE format('SELECT ($1).%I::text, ($2).%I::text', col, col)
      INTO old_val, new_val USING OLD, NEW;
    IF old_val IS DISTINCT FROM new_val THEN
      RAISE EXCEPTION
        'append-only table %: column % is immutable (only voided_at/voided_by/void_reason may change)',
        TG_TABLE_NAME, col;
    END IF;
  END LOOP;
  RETURN NEW;
END $$;

-- Append-only DELETE block: ledgers may never lose rows. Voiding is the
-- only legitimate "removal".
CREATE OR REPLACE FUNCTION public.forbid_delete()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'append-only table %: DELETE is forbidden — void the row instead',
    TG_TABLE_NAME;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Top-level: businesses
--    No business_id column — the row's own id is the tenant key.
-- -----------------------------------------------------------------------------

CREATE TABLE public.businesses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  type            text,
  phone           text,
  email           text,
  logo_url        text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_businesses_last_updated_at ON public.businesses (last_updated_at);

-- -----------------------------------------------------------------------------
-- 3. Identity: profiles, users, sessions, invites
--    profiles is the auth ↔ tenant join. id = auth.users.id.
-- -----------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id              uuid PRIMARY KEY,  -- equals auth.users.id; not auto-generated
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  role            text NOT NULL CHECK (role IN ('admin','staff','ceo','manager')),
  role_tier       int  NOT NULL DEFAULT 1 CHECK (role_tier IN (1,4,5)),
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_business_lua ON public.profiles (business_id, last_updated_at);

CREATE TABLE public.users (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  auth_user_id        uuid UNIQUE,  -- nullable: invited staff exist before accepting
  name                text NOT NULL,
  email               text,
  role                text NOT NULL CHECK (role IN ('admin','staff','ceo','manager')),
  role_tier           int  NOT NULL DEFAULT 1 CHECK (role_tier IN (1,4,5)),
  avatar_color        text NOT NULL DEFAULT '#3B82F6',
  biometric_enabled   boolean NOT NULL DEFAULT false,
  warehouse_id        uuid,  -- FK added after warehouses is created
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_notification_sent_at timestamptz,
  is_deleted          boolean NOT NULL DEFAULT false,
  last_updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, email)
);

CREATE INDEX idx_users_business_lua     ON public.users (business_id, last_updated_at);
CREATE INDEX idx_users_business_deleted ON public.users (business_id, is_deleted);

CREATE TABLE public.sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token           text,
  expires_at      timestamptz NOT NULL,
  revoked_at      timestamptz,
  user_agent      text,
  ip_address      inet,
  device_id       text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_sessions_business_lua ON public.sessions (business_id, last_updated_at);
CREATE INDEX idx_sessions_user_active  ON public.sessions (user_id, revoked_at, expires_at);

CREATE TABLE public.invites (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  email           text NOT NULL,
  code            text NOT NULL,                                          -- 8-char, case-insensitive
  role            text NOT NULL CHECK (role IN ('admin','staff','ceo','manager')),
  warehouse_id    uuid,                                                   -- FK added below
  created_by      uuid NOT NULL REFERENCES public.users(id),
  invitee_name    text NOT NULL,
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','accepted','expired','revoked')),
  expires_at      timestamptz NOT NULL,
  used_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

-- §3.2: code only needs to be unique while pending. Once consumed/expired
-- the same 8-char value can be reissued.
CREATE UNIQUE INDEX uq_invites_pending_code ON public.invites (code) WHERE status = 'pending';
CREATE INDEX idx_invites_business_lua ON public.invites (business_id, last_updated_at);

-- -----------------------------------------------------------------------------
-- 4. Catalog
-- -----------------------------------------------------------------------------

CREATE TABLE public.warehouses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  location        text,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_warehouses_business_lua     ON public.warehouses (business_id, last_updated_at);
CREATE INDEX idx_warehouses_business_deleted ON public.warehouses (business_id, is_deleted);

ALTER TABLE public.users   ADD CONSTRAINT users_warehouse_fk   FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id);
ALTER TABLE public.invites ADD CONSTRAINT invites_warehouse_fk FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id);

CREATE TABLE public.manufacturers (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id              uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name                     text NOT NULL,
  empty_crate_stock        int  NOT NULL DEFAULT 0,
  deposit_amount_kobo      int  NOT NULL DEFAULT 0,
  is_deleted               boolean NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now(),
  last_updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_manufacturers_business_lua     ON public.manufacturers (business_id, last_updated_at);
CREATE INDEX idx_manufacturers_business_deleted ON public.manufacturers (business_id, is_deleted);

CREATE TABLE public.crate_groups (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id              uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name                     text NOT NULL,
  size                     int  NOT NULL CHECK (size IN (12,20,24)),  -- 12=big, 20=medium, 24=small
  empty_crate_stock        int  NOT NULL DEFAULT 0,
  deposit_amount_kobo      int  NOT NULL DEFAULT 0,
  is_deleted               boolean NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now(),
  last_updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_crate_groups_business_lua     ON public.crate_groups (business_id, last_updated_at);
CREATE INDEX idx_crate_groups_business_deleted ON public.crate_groups (business_id, is_deleted);

CREATE TABLE public.categories (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_categories_business_lua     ON public.categories (business_id, last_updated_at);
CREATE INDEX idx_categories_business_deleted ON public.categories (business_id, is_deleted);

CREATE TABLE public.suppliers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  phone           text,
  email           text,
  address         text,
  crate_group_id  uuid REFERENCES public.crate_groups(id),  -- §5.7: FK only, no text duplicate
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_suppliers_business_lua     ON public.suppliers (business_id, last_updated_at);
CREATE INDEX idx_suppliers_business_deleted ON public.suppliers (business_id, is_deleted);

CREATE TABLE public.products (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id                 uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  category_id                 uuid REFERENCES public.categories(id),
  crate_group_id              uuid REFERENCES public.crate_groups(id),
  manufacturer_id             uuid REFERENCES public.manufacturers(id),  -- §5.7: FK only
  supplier_id                 uuid REFERENCES public.suppliers(id),
  name                        text NOT NULL,
  subtitle                    text,
  sku                         text,
  size                        text CHECK (size IS NULL OR size IN ('big','medium','small')),
  unit                        text NOT NULL DEFAULT 'Bottle'
                              CHECK (unit IN ('Bottle','Crate','Pack','Carton','Piece','Bag','Other')),
  retail_price_kobo           int  NOT NULL DEFAULT 0,
  bulk_breaker_price_kobo     int,
  distributor_price_kobo      int,
  selling_price_kobo          int  NOT NULL DEFAULT 0,
  buying_price_kobo           int  NOT NULL DEFAULT 0,
  icon_code_point             int,
  color_hex                   text,
  is_available                boolean NOT NULL DEFAULT true,
  is_deleted                  boolean NOT NULL DEFAULT false,
  low_stock_threshold         int  NOT NULL DEFAULT 5,
  avg_daily_sales             real NOT NULL DEFAULT 0.0,
  lead_time_days              int  NOT NULL DEFAULT 0,
  safety_stock_qty            int  NOT NULL DEFAULT 0,
  monthly_target_units        int  NOT NULL DEFAULT 0,
  empty_crate_value_kobo      int  NOT NULL DEFAULT 0,
  track_empties               boolean NOT NULL DEFAULT false,
  image_path                  text,
  version                     int  NOT NULL DEFAULT 1,  -- §5.5: cart staleness
  created_at                  timestamptz NOT NULL DEFAULT now(),
  last_updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_business_lua     ON public.products (business_id, last_updated_at);
CREATE INDEX idx_products_business_deleted ON public.products (business_id, is_deleted);
CREATE INDEX idx_products_category         ON public.products (category_id);
CREATE INDEX idx_products_name             ON public.products (business_id, name);

CREATE TABLE public.price_lists (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  price_kobo      int  NOT NULL,
  effective_from  timestamptz NOT NULL DEFAULT now(),
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_price_lists_business_lua     ON public.price_lists (business_id, last_updated_at);
CREATE INDEX idx_price_lists_business_deleted ON public.price_lists (business_id, is_deleted);
CREATE INDEX idx_price_lists_product          ON public.price_lists (product_id, effective_from);

-- -----------------------------------------------------------------------------
-- 5. Customers / wallets / crate balances
-- -----------------------------------------------------------------------------

CREATE TABLE public.customers (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id           uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  warehouse_id          uuid REFERENCES public.warehouses(id),
  name                  text NOT NULL,
  phone                 text,
  email                 text,
  address               text,
  google_maps_location  text,
  customer_group        text NOT NULL DEFAULT 'retailer'
                        CHECK (customer_group IN ('retailer','wholesaler','distributor','walk_in')),
  wallet_limit_kobo     int  NOT NULL DEFAULT 0,
  -- §5.8: no cached wallet_balance_kobo. Compute from wallet_transactions.
  is_deleted            boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  last_updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_customers_business_lua     ON public.customers (business_id, last_updated_at);
CREATE INDEX idx_customers_business_deleted ON public.customers (business_id, is_deleted);
CREATE INDEX idx_customers_business_phone   ON public.customers (business_id, phone);

CREATE TABLE public.customer_wallets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id     uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  currency        text NOT NULL DEFAULT 'NGN',
  is_active       boolean NOT NULL DEFAULT true,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, customer_id)
);

CREATE INDEX idx_customer_wallets_business_lua     ON public.customer_wallets (business_id, last_updated_at);
CREATE INDEX idx_customer_wallets_business_deleted ON public.customer_wallets (business_id, is_deleted);

CREATE TABLE public.wallet_transactions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id        uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  wallet_id          uuid NOT NULL REFERENCES public.customer_wallets(id),
  customer_id        uuid NOT NULL REFERENCES public.customers(id),  -- denormalized for hot-path index
  type               text NOT NULL CHECK (type IN ('credit','debit')),
  amount_kobo        int  NOT NULL CHECK (amount_kobo >= 0),
  signed_amount_kobo int  NOT NULL,  -- credit = +amount, debit = -amount; the sum is the balance
  reference_type     text NOT NULL CHECK (reference_type IN
                       ('topup_cash','topup_transfer','order_payment','refund','reward','fee','adjustment')),
  -- §5.2: typed nullable FK instead of polymorphic (reference_id, type).
  -- FK to orders added below the orders CREATE TABLE (forward reference).
  order_id           uuid,
  performed_by       uuid REFERENCES public.users(id),
  customer_verified  boolean NOT NULL DEFAULT false,
  voided_at          timestamptz,
  voided_by          uuid REFERENCES public.users(id),
  void_reason        text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  last_updated_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (signed_amount_kobo > 0 AND type = 'credit') OR
    (signed_amount_kobo < 0 AND type = 'debit')  OR
    (signed_amount_kobo = 0)
  )
);

CREATE INDEX idx_wallet_txn_business_lua       ON public.wallet_transactions (business_id, last_updated_at);
CREATE INDEX idx_wallet_txn_business_cust_time ON public.wallet_transactions (business_id, customer_id, created_at);

CREATE TABLE public.customer_crate_balances (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id     uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  crate_group_id  uuid NOT NULL REFERENCES public.crate_groups(id),
  balance         int  NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, customer_id, crate_group_id)
);

CREATE INDEX idx_ccb_business_lua ON public.customer_crate_balances (business_id, last_updated_at);

CREATE TABLE public.manufacturer_crate_balances (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  manufacturer_id uuid NOT NULL REFERENCES public.manufacturers(id) ON DELETE CASCADE,
  crate_group_id  uuid NOT NULL REFERENCES public.crate_groups(id),
  balance         int  NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, manufacturer_id, crate_group_id)
);

CREATE INDEX idx_mcb_business_lua ON public.manufacturer_crate_balances (business_id, last_updated_at);

-- crate_ledger: append-only source of truth. The two *_crate_balances tables
-- above are caches reconcilable via SUM(quantity_delta) per (business, owner,
-- crate_group). Exactly one of customer_id / manufacturer_id is set.
CREATE TABLE public.crate_ledger (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id         uuid REFERENCES public.customers(id),
  manufacturer_id     uuid REFERENCES public.manufacturers(id),
  crate_group_id      uuid NOT NULL REFERENCES public.crate_groups(id),
  quantity_delta      int  NOT NULL,  -- + = received from owner, − = issued to owner
  movement_type       text NOT NULL CHECK (movement_type IN
                        ('issued','returned','damaged','adjusted','transferred_in','transferred_out')),
  reference_order_id  uuid,  -- FK added after orders is created
  reference_return_id uuid,  -- FK added after pending_crate_returns is created
  performed_by        uuid REFERENCES public.users(id),
  voided_at           timestamptz,
  voided_by           uuid REFERENCES public.users(id),
  void_reason         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK ((customer_id IS NOT NULL)::int + (manufacturer_id IS NOT NULL)::int = 1)
);

CREATE INDEX idx_crate_ledger_business_lua    ON public.crate_ledger (business_id, last_updated_at);
CREATE INDEX idx_crate_ledger_owner_group     ON public.crate_ledger (business_id, customer_id, manufacturer_id, crate_group_id, created_at);

-- -----------------------------------------------------------------------------
-- 6. Inventory / stock movements
-- -----------------------------------------------------------------------------

CREATE TABLE public.inventory (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  warehouse_id    uuid NOT NULL REFERENCES public.warehouses(id),
  quantity        int  NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, product_id, warehouse_id)
);

CREATE INDEX idx_inventory_business_lua     ON public.inventory (business_id, last_updated_at);
CREATE INDEX idx_inventory_business_pw      ON public.inventory (business_id, product_id, warehouse_id);

CREATE TABLE public.crates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  total_crates    int  NOT NULL,
  empty_returned  int  NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_crates_business_lua ON public.crates (business_id, last_updated_at);

CREATE TABLE public.stock_transfers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  from_location_id    uuid NOT NULL REFERENCES public.warehouses(id),
  to_location_id      uuid NOT NULL REFERENCES public.warehouses(id),
  product_id          uuid NOT NULL REFERENCES public.products(id),
  quantity            int  NOT NULL,
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','in_transit','received','cancelled')),
  initiated_by        uuid NOT NULL REFERENCES public.users(id),
  received_by         uuid REFERENCES public.users(id),
  initiated_at        timestamptz NOT NULL DEFAULT now(),
  received_at         timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_transfers_business_lua ON public.stock_transfers (business_id, last_updated_at);

CREATE TABLE public.stock_adjustments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  warehouse_id    uuid NOT NULL REFERENCES public.warehouses(id),
  quantity_diff   int  NOT NULL,
  reason          text NOT NULL,
  performed_by    uuid REFERENCES public.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_adj_business_lua ON public.stock_adjustments (business_id, last_updated_at);

-- stock_transactions: append-only ledger. Source of truth for all stock
-- movements. Inventory rows are caches.
CREATE TABLE public.stock_transactions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  location_id     uuid NOT NULL REFERENCES public.warehouses(id),
  quantity_delta  int  NOT NULL,
  movement_type   text NOT NULL CHECK (movement_type IN
                    ('sale','return','damage','transfer_out','transfer_in','purchase_received','adjustment')),
  -- §5.2: typed nullable FKs (instead of polymorphic reference_id text)
  order_id            uuid,  -- FK added after orders
  transfer_id         uuid REFERENCES public.stock_transfers(id),
  adjustment_id       uuid REFERENCES public.stock_adjustments(id),
  purchase_id         uuid,  -- FK added after purchases
  performed_by        uuid NOT NULL REFERENCES public.users(id),
  voided_at           timestamptz,
  voided_by           uuid REFERENCES public.users(id),
  void_reason         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (order_id      IS NOT NULL)::int +
    (transfer_id   IS NOT NULL)::int +
    (adjustment_id IS NOT NULL)::int +
    (purchase_id   IS NOT NULL)::int = 1
  )
);

CREATE INDEX idx_stock_txn_business_lua ON public.stock_transactions (business_id, last_updated_at);
CREATE INDEX idx_stock_txn_prod_loc_time ON public.stock_transactions (product_id, location_id, created_at);

-- -----------------------------------------------------------------------------
-- 7. Sales / purchasing
-- -----------------------------------------------------------------------------

CREATE TABLE public.orders (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id              uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  order_number             text NOT NULL,
  customer_id              uuid REFERENCES public.customers(id),
  total_amount_kobo        int  NOT NULL,
  discount_kobo            int  NOT NULL DEFAULT 0,
  net_amount_kobo          int  NOT NULL,
  amount_paid_kobo         int  NOT NULL DEFAULT 0,
  payment_type             text NOT NULL CHECK (payment_type IN
                             ('cash','transfer','card','wallet','credit','mixed')),
  status                   text NOT NULL CHECK (status IN
                             ('pending','completed','cancelled','refunded')),
  rider_name               text NOT NULL DEFAULT 'Pick-up Order',
  cancellation_reason      text,
  barcode                  text,
  staff_id                 uuid REFERENCES public.users(id),
  warehouse_id             uuid REFERENCES public.warehouses(id),
  crate_deposit_paid_kobo  int  NOT NULL DEFAULT 0,
  completed_at             timestamptz,
  cancelled_at             timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  last_updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, order_number)
);

CREATE INDEX idx_orders_business_lua    ON public.orders (business_id, last_updated_at);
CREATE INDEX idx_orders_business_time   ON public.orders (business_id, created_at);
CREATE INDEX idx_orders_business_status ON public.orders (business_id, status);

-- Resolve forward FKs from earlier tables
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_txn_order_fk
  FOREIGN KEY (order_id) REFERENCES public.orders(id);
ALTER TABLE public.crate_ledger ADD CONSTRAINT crate_ledger_order_fk
  FOREIGN KEY (reference_order_id) REFERENCES public.orders(id);
ALTER TABLE public.stock_transactions ADD CONSTRAINT stock_txn_order_fk
  FOREIGN KEY (order_id) REFERENCES public.orders(id);

CREATE TABLE public.order_items (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id       uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  order_id          uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id        uuid NOT NULL REFERENCES public.products(id),
  warehouse_id      uuid NOT NULL REFERENCES public.warehouses(id),
  quantity          int  NOT NULL CHECK (quantity > 0),
  unit_price_kobo   int  NOT NULL,
  buying_price_kobo int  NOT NULL DEFAULT 0,
  total_kobo        int  NOT NULL,
  price_snapshot    jsonb,  -- §4.2: jsonb typing replaces text + json_valid CHECK
  created_at        timestamptz NOT NULL DEFAULT now(),
  last_updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_order_items_business_lua ON public.order_items (business_id, last_updated_at);
CREATE INDEX idx_order_items_order        ON public.order_items (order_id);
CREATE INDEX idx_order_items_product      ON public.order_items (product_id);

CREATE TABLE public.purchases (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id       uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  supplier_id       uuid NOT NULL REFERENCES public.suppliers(id),
  total_amount_kobo int  NOT NULL,
  status            text NOT NULL CHECK (status IN ('pending','received','cancelled')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  last_updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchases_business_lua ON public.purchases (business_id, last_updated_at);

ALTER TABLE public.stock_transactions ADD CONSTRAINT stock_txn_purchase_fk
  FOREIGN KEY (purchase_id) REFERENCES public.purchases(id);

CREATE TABLE public.purchase_items (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  purchase_id     uuid NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  product_id      uuid NOT NULL REFERENCES public.products(id),
  quantity        int  NOT NULL CHECK (quantity > 0),
  unit_price_kobo int  NOT NULL,
  total_kobo      int  NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchase_items_business_lua ON public.purchase_items (business_id, last_updated_at);
CREATE INDEX idx_purchase_items_purchase     ON public.purchase_items (purchase_id);

CREATE TABLE public.drivers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  license_number  text,
  phone           text,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_drivers_business_lua     ON public.drivers (business_id, last_updated_at);
CREATE INDEX idx_drivers_business_deleted ON public.drivers (business_id, is_deleted);

CREATE TABLE public.delivery_receipts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  order_id        uuid REFERENCES public.orders(id),
  driver_id       uuid NOT NULL REFERENCES public.drivers(id),
  status          text NOT NULL CHECK (status IN ('pending','dispatched','delivered','failed','returned')),
  delivered_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_delivery_receipts_business_lua ON public.delivery_receipts (business_id, last_updated_at);

CREATE TABLE public.saved_carts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  customer_id     uuid REFERENCES public.customers(id),
  cart_data       jsonb NOT NULL,  -- §4.2: jsonb
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_saved_carts_business_lua ON public.saved_carts (business_id, last_updated_at);

-- pending_crate_returns: §5.10 — flattened. One row per (return, crate_group).
-- Multiple rows can share a single submission if the staff returns crates from
-- multiple groups in one go. Group them by (customer_id, submitted_at,
-- submitted_by) at read time.
CREATE TABLE public.pending_crate_returns (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  order_id            uuid REFERENCES public.orders(id),
  customer_id         uuid NOT NULL REFERENCES public.customers(id),
  crate_group_id      uuid NOT NULL REFERENCES public.crate_groups(id),
  quantity            int  NOT NULL CHECK (quantity > 0),
  submitted_by        uuid NOT NULL REFERENCES public.users(id),
  submitted_at        timestamptz NOT NULL DEFAULT now(),
  approved_by         uuid REFERENCES public.users(id),
  approved_at         timestamptz,
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','approved','rejected')),
  rejection_reason    text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pcr_business_lua    ON public.pending_crate_returns (business_id, last_updated_at);
CREATE INDEX idx_pcr_business_status ON public.pending_crate_returns (business_id, status);

ALTER TABLE public.crate_ledger ADD CONSTRAINT crate_ledger_return_fk
  FOREIGN KEY (reference_return_id) REFERENCES public.pending_crate_returns(id);

-- payment_transactions: append-only. §5.2: typed nullable FKs.
CREATE TABLE public.payment_transactions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  amount_kobo         int  NOT NULL,
  method              text NOT NULL CHECK (method IN ('cash','transfer','card','wallet','pos','other')),
  type                text NOT NULL CHECK (type IN ('sale','purchase','expense','refund','wallet_topup')),
  -- typed FKs: exactly one of order_id / purchase_id / expense_id / wallet_txn_id / delivery_id is set
  order_id            uuid REFERENCES public.orders(id),
  purchase_id         uuid REFERENCES public.purchases(id),
  expense_id          uuid,  -- FK added after expenses
  wallet_txn_id       uuid REFERENCES public.wallet_transactions(id),
  delivery_id         uuid REFERENCES public.delivery_receipts(id),
  performed_by        uuid REFERENCES public.users(id),
  voided_at           timestamptz,
  voided_by           uuid REFERENCES public.users(id),
  void_reason         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  last_updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (order_id      IS NOT NULL)::int +
    (purchase_id   IS NOT NULL)::int +
    (expense_id    IS NOT NULL)::int +
    (wallet_txn_id IS NOT NULL)::int +
    (delivery_id   IS NOT NULL)::int = 1
  )
);

CREATE INDEX idx_payment_txn_business_lua  ON public.payment_transactions (business_id, last_updated_at);
CREATE INDEX idx_payment_txn_business_type ON public.payment_transactions (business_id, type, created_at);

-- -----------------------------------------------------------------------------
-- 8. Operational
-- -----------------------------------------------------------------------------

CREATE TABLE public.expense_categories (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name            text NOT NULL,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, name)
);

CREATE INDEX idx_expense_categories_business_lua     ON public.expense_categories (business_id, last_updated_at);
CREATE INDEX idx_expense_categories_business_deleted ON public.expense_categories (business_id, is_deleted);

CREATE TABLE public.expenses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  category_id     uuid REFERENCES public.expense_categories(id),  -- §5.7: FK only
  amount_kobo     int  NOT NULL CHECK (amount_kobo > 0),
  description     text NOT NULL,
  payment_method  text CHECK (payment_method IS NULL OR payment_method IN
                    ('cash','transfer','card','pos','other')),
  recorded_by     uuid REFERENCES public.users(id),
  reference       text,
  warehouse_id    uuid REFERENCES public.warehouses(id),
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_expenses_business_lua     ON public.expenses (business_id, last_updated_at);
CREATE INDEX idx_expenses_business_deleted ON public.expenses (business_id, is_deleted);
CREATE INDEX idx_expenses_business_time    ON public.expenses (business_id, created_at);

ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_txn_expense_fk
  FOREIGN KEY (expense_id) REFERENCES public.expenses(id);

-- activity_logs: append-only. §5.2/§5.3 — typed FKs, warehouse_id is uuid.
CREATE TABLE public.activity_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES public.users(id),
  action          text NOT NULL,
  description     text NOT NULL,
  -- typed nullable FKs: zero or one may be non-null (logs may reference no entity)
  order_id        uuid REFERENCES public.orders(id),
  product_id      uuid REFERENCES public.products(id),
  customer_id     uuid REFERENCES public.customers(id),
  expense_id      uuid REFERENCES public.expenses(id),
  delivery_id     uuid REFERENCES public.delivery_receipts(id),
  wallet_txn_id   uuid REFERENCES public.wallet_transactions(id),
  warehouse_id    uuid REFERENCES public.warehouses(id),  -- §5.3: uuid, not text
  voided_at       timestamptz,
  voided_by       uuid REFERENCES public.users(id),
  void_reason     text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (order_id      IS NOT NULL)::int +
    (product_id    IS NOT NULL)::int +
    (customer_id   IS NOT NULL)::int +
    (expense_id    IS NOT NULL)::int +
    (delivery_id   IS NOT NULL)::int +
    (wallet_txn_id IS NOT NULL)::int <= 1
  )
);

CREATE INDEX idx_activity_logs_business_lua  ON public.activity_logs (business_id, last_updated_at);
CREATE INDEX idx_activity_logs_business_time ON public.activity_logs (business_id, created_at);

CREATE TABLE public.notifications (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id      uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  type             text NOT NULL,
  message          text NOT NULL,
  is_read          boolean NOT NULL DEFAULT false,
  linked_record_id uuid,  -- intentionally untyped; notifications can reference any entity
  created_at       timestamptz NOT NULL DEFAULT now(),
  last_updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_business_lua ON public.notifications (business_id, last_updated_at);

-- settings: per-business only. No sentinel, no global rows. Genuinely global
-- config goes in system_config (below) under service_role-only RLS.
CREATE TABLE public.settings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  key             text NOT NULL,
  value           text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, key)
);

CREATE INDEX idx_settings_business_lua ON public.settings (business_id, last_updated_at);

-- system_config: top-level, RLS in 0002 grants SELECT to authenticated and
-- write only to service_role. Use this for feature flags / global defaults.
CREATE TABLE public.system_config (
  key             text PRIMARY KEY,
  value           jsonb NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 9. Triggers
-- -----------------------------------------------------------------------------

-- bump_last_updated_at on every synced table.
DO $$
DECLARE
  t text;
  synced_tables text[] := ARRAY[
    'businesses','profiles','users','sessions','invites',
    'warehouses','manufacturers','crate_groups','categories','suppliers',
    'products','price_lists',
    'customers','customer_wallets','wallet_transactions',
    'customer_crate_balances','manufacturer_crate_balances','crate_ledger',
    'inventory','crates','stock_transfers','stock_adjustments','stock_transactions',
    'orders','order_items','purchases','purchase_items',
    'drivers','delivery_receipts','saved_carts','pending_crate_returns',
    'payment_transactions',
    'expense_categories','expenses','activity_logs','notifications',
    'settings','system_config'
  ];
BEGIN
  FOREACH t IN ARRAY synced_tables LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%I_bump_lua BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.bump_last_updated_at()',
      t, t
    );
  END LOOP;
END $$;

-- products.version bump on every UPDATE.
CREATE TRIGGER trg_products_bump_version
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.bump_products_version();

-- Append-only enforcement: only the void columns and last_updated_at may
-- change. Pass the immutable column list as TG_ARGV.
DO $$
DECLARE
  rec record;
  ledger_tables text[] := ARRAY[
    'stock_transactions','wallet_transactions','payment_transactions',
    'activity_logs','crate_ledger'
  ];
  t text;
  cols text;
BEGIN
  FOREACH t IN ARRAY ledger_tables LOOP
    SELECT string_agg(quote_literal(column_name), ',')
      INTO cols
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = t
        AND column_name NOT IN ('voided_at','voided_by','void_reason','last_updated_at');
    EXECUTE format(
      'CREATE TRIGGER trg_%I_append_only BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.enforce_append_only(%s)',
      t, t, cols
    );
    EXECUTE format(
      'CREATE TRIGGER trg_%I_no_delete BEFORE DELETE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.forbid_delete()',
      t, t
    );
  END LOOP;
END $$;

-- =============================================================================
-- End of 0001_initial.sql. RLS is configured in 0002_rls.sql.
-- =============================================================================
