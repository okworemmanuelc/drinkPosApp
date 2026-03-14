-- Onafia POS — Supabase Initial Schema
-- Run this in the Supabase SQL Editor after creating your project.
-- All tables mirror the local SQLite schema.

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Warehouses ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouses (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  location    TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

-- ── Suppliers ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS suppliers (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  crate_group       TEXT,
  track_inventory   BOOLEAN NOT NULL DEFAULT TRUE,
  contact_details   TEXT,
  amount_paid       NUMERIC NOT NULL DEFAULT 0,
  supplier_wallet   NUMERIC NOT NULL DEFAULT 0,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

-- ── Inventory Items ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inventory_items (
  id                    TEXT PRIMARY KEY,
  product_name          TEXT NOT NULL,
  subtitle              TEXT NOT NULL,
  supplier_id           TEXT REFERENCES suppliers(id),
  crate_group_name      TEXT,
  needs_empty_crate     BOOLEAN NOT NULL DEFAULT FALSE,
  icon_name             TEXT NOT NULL,
  color_hex             TEXT NOT NULL,
  low_stock_threshold   NUMERIC NOT NULL DEFAULT 5,
  selling_price         NUMERIC,
  buying_price          NUMERIC,
  retail_price          NUMERIC,
  bulk_breaker_price    NUMERIC,
  distributor_price     NUMERIC,
  category              TEXT,
  paired_crate_item_id  TEXT,
  image_path            TEXT,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

-- ── Warehouse Stock ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_stock (
  item_id       TEXT NOT NULL REFERENCES inventory_items(id),
  warehouse_id  TEXT NOT NULL REFERENCES warehouses(id),
  qty           NUMERIC NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (item_id, warehouse_id)
);

-- ── Crate Stocks ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crate_stocks (
  crate_group   TEXT PRIMARY KEY,
  available     NUMERIC NOT NULL DEFAULT 0,
  custom_label  TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

-- ── Customers ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id                    TEXT PRIMARY KEY,
  name                  TEXT NOT NULL,
  address_text          TEXT NOT NULL,
  google_maps_location  TEXT NOT NULL,
  phone                 TEXT,
  customer_wallet       NUMERIC NOT NULL DEFAULT 0,
  wallet_limit          NUMERIC NOT NULL DEFAULT 0,
  customer_group        TEXT NOT NULL DEFAULT 'retailer',
  is_walk_in            BOOLEAN NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

-- ── Customer Payments ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_payments (
  id           TEXT PRIMARY KEY,
  customer_id  TEXT NOT NULL REFERENCES customers(id),
  amount       NUMERIC NOT NULL,
  timestamp    TIMESTAMPTZ NOT NULL,
  note         TEXT,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

-- ── Customer Crate Balances ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_crate_balances (
  customer_id   TEXT NOT NULL REFERENCES customers(id),
  crate_group   TEXT NOT NULL,
  qty           INTEGER NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, crate_group)
);

-- ── Orders ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id               TEXT PRIMARY KEY,
  customer_id      TEXT REFERENCES customers(id),
  customer_name    TEXT NOT NULL,
  customer_address TEXT NOT NULL DEFAULT '',
  customer_phone   TEXT NOT NULL DEFAULT '',
  subtotal         NUMERIC NOT NULL DEFAULT 0,
  crate_deposit    NUMERIC NOT NULL DEFAULT 0,
  total_amount     NUMERIC NOT NULL,
  amount_paid      NUMERIC NOT NULL,
  customer_wallet  NUMERIC NOT NULL DEFAULT 0,
  payment_method   TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ,
  status           TEXT NOT NULL DEFAULT 'pending',
  rider_name       TEXT NOT NULL DEFAULT 'Pick-up Order',
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

-- ── Order Items ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
  id                 TEXT PRIMARY KEY,
  order_id           TEXT NOT NULL REFERENCES orders(id),
  product_name       TEXT NOT NULL,
  subtitle           TEXT,
  price              NUMERIC NOT NULL,
  qty                NUMERIC NOT NULL,
  category           TEXT,
  crate_group_name   TEXT,
  needs_empty_crate  BOOLEAN NOT NULL DEFAULT FALSE
);

-- ── Order Reprints ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_reprints (
  id           TEXT PRIMARY KEY,
  order_id     TEXT NOT NULL REFERENCES orders(id),
  reprinted_at TIMESTAMPTZ NOT NULL
);

-- ── Expenses ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expenses (
  id              TEXT PRIMARY KEY,
  category        TEXT NOT NULL,
  amount          NUMERIC NOT NULL,
  payment_method  TEXT NOT NULL,
  description     TEXT,
  date            TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  recorded_by     TEXT NOT NULL,
  reference       TEXT,
  receipt_path    TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

-- ── Deliveries ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deliveries (
  id             TEXT PRIMARY KEY,
  supplier_name  TEXT NOT NULL,
  delivered_at   TIMESTAMPTZ NOT NULL,
  total_value    NUMERIC NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'pending',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);

-- ── Delivery Items ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_items (
  id                TEXT PRIMARY KEY,
  delivery_id       TEXT NOT NULL REFERENCES deliveries(id),
  product_id        TEXT NOT NULL DEFAULT '',
  product_name      TEXT NOT NULL,
  supplier_name     TEXT NOT NULL,
  crate_group_label TEXT,
  unit_price        NUMERIC NOT NULL,
  quantity          NUMERIC NOT NULL
);

-- ── Delivery Receipts ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_receipts (
  id                  TEXT PRIMARY KEY,
  order_id            TEXT NOT NULL REFERENCES orders(id),
  reference_number    TEXT NOT NULL,
  rider_name          TEXT NOT NULL,
  outstanding_amount  NUMERIC NOT NULL DEFAULT 0,
  paid_amount         NUMERIC NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

-- ── Supplier Payments ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS supplier_payments (
  id                TEXT PRIMARY KEY,
  supplier_id       TEXT REFERENCES suppliers(id),
  supplier_name     TEXT NOT NULL,
  amount            NUMERIC NOT NULL,
  payment_method    TEXT NOT NULL,
  reference_number  TEXT,
  notes             TEXT,
  delivery_id       TEXT REFERENCES deliveries(id),
  date              TIMESTAMPTZ NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

-- ── Inventory Logs ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inventory_logs (
  id              TEXT PRIMARY KEY,
  timestamp       TIMESTAMPTZ NOT NULL,
  "user"          TEXT NOT NULL,
  item_id         TEXT NOT NULL,
  item_name       TEXT NOT NULL,
  action          TEXT NOT NULL,
  previous_value  NUMERIC NOT NULL,
  new_value       NUMERIC NOT NULL,
  note            TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

-- ── Activity Logs ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_logs (
  id                    TEXT PRIMARY KEY,
  action                TEXT NOT NULL,
  description           TEXT NOT NULL,
  timestamp             TIMESTAMPTZ NOT NULL,
  related_entity_id     TEXT,
  related_entity_type   TEXT,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

-- ── Notifications ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id               TEXT PRIMARY KEY,
  type             TEXT NOT NULL,
  message          TEXT NOT NULL,
  timestamp        TIMESTAMPTZ NOT NULL,
  is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  linked_record_id TEXT,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

-- ── Staff ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  role       TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- ── Row Level Security ────────────────────────────────────────────────────────
-- Enable RLS on all tables and allow all operations for authenticated/anon users.
-- Tighten these policies when you add user authentication.

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'warehouses','suppliers','inventory_items','warehouse_stock','crate_stocks',
    'customers','customer_payments','customer_crate_balances',
    'orders','order_items','order_reprints',
    'expenses','deliveries','delivery_items','delivery_receipts',
    'supplier_payments','inventory_logs','activity_logs','notifications','staff'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY "allow_all_%s" ON %I FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)',
      t, t
    );
  END LOOP;
END $$;
