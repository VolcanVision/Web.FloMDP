-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.advances (
  id bigint NOT NULL DEFAULT nextval('advances_id_seq'::regclass),
  order_id bigint NOT NULL,
  amount numeric NOT NULL,
  paid_at date NOT NULL DEFAULT CURRENT_DATE,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT advances_pkey PRIMARY KEY (id),
  CONSTRAINT advances_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.alerts (
  id bigint NOT NULL DEFAULT nextval('alerts_id_seq'::regclass),
  title text NOT NULL,
  message text,
  alert_type text,
  is_read boolean NOT NULL DEFAULT false,
  target_user_id bigint,
  related_order_id bigint,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT alerts_pkey PRIMARY KEY (id),
  CONSTRAINT alerts_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id),
  CONSTRAINT alerts_related_order_id_fkey FOREIGN KEY (related_order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.calendar_tasks (
  id bigint NOT NULL DEFAULT nextval('calendar_tasks_id_seq'::regclass),
  title text NOT NULL,
  description text,
  task_date date NOT NULL,
  category text NOT NULL CHECK (category = ANY (ARRAY['admin'::text, 'production'::text, 'accounts'::text])),
  is_completed boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  assigned_by text,
  assignee text,
  is_recurring boolean DEFAULT false,
  recurrence_type text CHECK (recurrence_type IS NULL OR (recurrence_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text]))),
  recurrence_interval integer DEFAULT 1,
  recurrence_end_date date,
  parent_task_id bigint,
  CONSTRAINT calendar_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT calendar_tasks_parent_task_id_fkey FOREIGN KEY (parent_task_id) REFERENCES public.calendar_tasks(id)
);
CREATE TABLE public.fcm_tokens (
  id bigint NOT NULL DEFAULT nextval('fcm_tokens_id_seq'::regclass),
  user_id bigint NOT NULL,
  fcm_token text NOT NULL,
  device_info text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT fcm_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT fcm_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.inventory_additions (
  id bigint NOT NULL DEFAULT nextval('inventory_additions_id_seq'::regclass),
  inventory_item_id bigint NOT NULL,
  item_name text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  addition_date date NOT NULL DEFAULT CURRENT_DATE,
  supplier text,
  notes text,
  added_by text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT inventory_additions_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_additions_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id)
);
CREATE TABLE public.inventory_consumptions (
  id bigint NOT NULL DEFAULT nextval('inventory_consumptions_id_seq'::regclass),
  inventory_item_id bigint NOT NULL,
  item_name text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  consumption_date date NOT NULL DEFAULT CURRENT_DATE,
  purpose text,
  batch_no text,
  notes text,
  consumed_by text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT inventory_consumptions_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_consumptions_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id)
);
CREATE TABLE public.inventory_items (
  id bigint NOT NULL DEFAULT nextval('inventory_items_id_seq'::regclass),
  name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['fresh'::text, 'recycled'::text, 'finished'::text, 'spare'::text, 'raw'::text, 'processed'::text])),
  quantity numeric NOT NULL DEFAULT 0,
  category text NOT NULL CHECK (category = ANY (ARRAY['Raw Materials'::text, 'Finished Goods'::text, 'Additives'::text, 'Spare Parts'::text])),
  min_quantity integer,
  required_quantity numeric NOT NULL DEFAULT 0,
  CONSTRAINT inventory_items_pkey PRIMARY KEY (id)
);
CREATE TABLE public.lab_tests (
  id bigint NOT NULL DEFAULT nextval('lab_tests_id_seq'::regclass),
  test_name text NOT NULL,
  result text,
  passed boolean,
  notes text,
  tested_at date DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  material_name text,
  composition text,
  status text DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'completed'::text, 'pending'::text])),
  test_date date,
  completed_at timestamp with time zone,
  deleted_at timestamp with time zone,
  CONSTRAINT lab_tests_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notification_logs (
  id bigint NOT NULL DEFAULT nextval('notification_logs_id_seq'::regclass),
  user_id bigint NOT NULL,
  notification_type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb,
  related_order_id bigint,
  related_task_id bigint,
  related_purchase_id bigint,
  is_sent boolean NOT NULL DEFAULT false,
  is_read boolean NOT NULL DEFAULT false,
  sent_at timestamp with time zone,
  read_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_logs_pkey PRIMARY KEY (id),
  CONSTRAINT notification_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT notification_logs_related_order_id_fkey FOREIGN KEY (related_order_id) REFERENCES public.orders(id),
  CONSTRAINT notification_logs_related_task_id_fkey FOREIGN KEY (related_task_id) REFERENCES public.calendar_tasks(id),
  CONSTRAINT notification_logs_related_purchase_id_fkey FOREIGN KEY (related_purchase_id) REFERENCES public.purchases(id)
);
CREATE TABLE public.order_installments (
  id bigint NOT NULL DEFAULT nextval('order_installments_id_seq'::regclass),
  order_id bigint NOT NULL,
  installment_number integer NOT NULL,
  amount numeric NOT NULL,
  due_date date NOT NULL,
  is_paid boolean NOT NULL DEFAULT false,
  paid_date date,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_installments_pkey PRIMARY KEY (id),
  CONSTRAINT order_installments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.order_items (
  id bigint NOT NULL DEFAULT nextval('order_items_id_seq'::regclass),
  order_id bigint NOT NULL,
  product_name text NOT NULL,
  quantity numeric DEFAULT 1,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.orders (
  id bigint NOT NULL DEFAULT nextval('orders_id_seq'::regclass),
  order_number text NOT NULL UNIQUE,
  advance_paid numeric NOT NULL DEFAULT 0.00,
  due_date date,
  is_advance_paid boolean NOT NULL DEFAULT false,
  after_dispatch_days integer DEFAULT 0,
  final_due_date date,
  order_date date,
  created_by bigint,
  paid_amount numeric NOT NULL DEFAULT 0.00,
  payment_status text NOT NULL DEFAULT 'unpaid'::text CHECK (payment_status = ANY (ARRAY['paid'::text, 'partial'::text, 'unpaid'::text, 'overdue'::text])),
  order_status text NOT NULL DEFAULT 'new'::text CHECK (order_status = ANY (ARRAY['new'::text, 'pending_approval'::text, 'confirmed'::text, 'dispatched'::text, 'completed'::text, 'cancelled'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  client_company text,
  client_person text,
  client_phone text,
  client_email text,
  client_address text,
  production_status text DEFAULT 'created'::text,
  dispatch_date date,
  final_payment_date date,
  client_name text,
  advance_payment_date date,
  total_amount numeric NOT NULL DEFAULT 0.00,
  total_cost numeric DEFAULT 0,
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.payments (
  id bigint NOT NULL DEFAULT nextval('payments_id_seq'::regclass),
  order_id bigint NOT NULL,
  amount numeric NOT NULL,
  paid_at date NOT NULL,
  method text,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.production_batches (
  id bigint NOT NULL DEFAULT nextval('production_batches_id_seq'::regclass),
  order_id bigint,
  batch_no text NOT NULL,
  details text,
  status text DEFAULT 'in_production'::text CHECK (status = ANY (ARRAY['queued'::text, 'in_progress'::text, 'paused'::text, 'completed'::text, 'ready'::text, 'in_production'::text, 'dispatched'::text, 'shipped'::text])),
  started_at timestamp with time zone DEFAULT now(),
  ready_at timestamp with time zone,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  moved_to_inventory boolean DEFAULT false,
  position integer DEFAULT 0,
  progress numeric DEFAULT 0 CHECK (progress >= 0::numeric AND progress <= 100::numeric),
  queued_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT production_batches_pkey PRIMARY KEY (id),
  CONSTRAINT production_batches_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.production_losses (
  id bigint NOT NULL DEFAULT nextval('production_losses_id_seq'::regclass),
  quantity numeric,
  occurred_at date DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  shift text CHECK (shift = ANY (ARRAY['day'::text, 'night'::text])),
  supervisor text,
  operator text,
  grade_name text,
  CONSTRAINT production_losses_pkey PRIMARY KEY (id)
);
CREATE TABLE public.purchase_payments (
  id bigint NOT NULL DEFAULT nextval('purchase_payments_id_seq'::regclass),
  purchase_id bigint NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  paid_at date NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT purchase_payments_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_payments_purchase_id_fkey FOREIGN KEY (purchase_id) REFERENCES public.purchases(id)
);
CREATE TABLE public.purchases (
  id bigint NOT NULL DEFAULT nextval('purchases_id_seq'::regclass),
  company_name text NOT NULL,
  material text NOT NULL,
  quantity numeric CHECK (quantity IS NULL OR quantity >= 0::numeric),
  cost numeric CHECK (cost IS NULL OR cost >= 0::numeric),
  total_amount numeric DEFAULT (COALESCE(quantity, (0)::numeric) * COALESCE(cost, (0)::numeric)),
  purchase_date date DEFAULT CURRENT_DATE,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  payment_status text CHECK (payment_status = ANY (ARRAY['unpaid'::text, 'partial'::text, 'paid'::text, 'overdue'::text])),
  payment_due_date date,
  CONSTRAINT purchases_pkey PRIMARY KEY (id)
);
CREATE TABLE public.shipments (
  id bigint NOT NULL DEFAULT nextval('shipments_id_seq'::regclass),
  order_id bigint NOT NULL UNIQUE,
  shipment_name text,
  shipped_at date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  status text NOT NULL DEFAULT 'in_transit'::text CHECK (status = ANY (ARRAY['pending'::text, 'in_transit'::text, 'delivered'::text, 'cancelled'::text])),
  delivered_at timestamp with time zone,
  shipment_incharge text,
  shipping_company text,
  vehicle_details text,
  driver_contact_number text,
  location text,
  CONSTRAINT shipments_pkey PRIMARY KEY (id),
  CONSTRAINT shipments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id)
);
CREATE TABLE public.sub_tests (
  id bigint NOT NULL DEFAULT nextval('sub_tests_id_seq'::regclass),
  lab_test_id bigint NOT NULL,
  test_name text NOT NULL,
  test_date date,
  result text,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT sub_tests_pkey PRIMARY KEY (id),
  CONSTRAINT sub_tests_lab_test_id_fkey FOREIGN KEY (lab_test_id) REFERENCES public.lab_tests(id)
);
CREATE TABLE public.users (
  id bigint NOT NULL DEFAULT nextval('users_id_seq'::regclass),
  username text NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['admin'::text, 'production'::text, 'accounts'::text, 'lab_testing'::text])),
  first_name text,
  last_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  auth_id uuid UNIQUE,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_auth_id_fkey FOREIGN KEY (auth_id) REFERENCES auth.users(id)
);
CREATE TABLE public.inventory_additions (
  id bigint NOT NULL DEFAULT nextval('inventory_additions_id_seq'::regclass),
  inventory_item_id bigint NOT NULL,
  item_name text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  addition_date date NOT NULL DEFAULT CURRENT_DATE,
  supplier text,
  notes text,
  added_by text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT inventory_additions_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_additions_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id) ON DELETE CASCADE
);
CREATE TABLE public.inventory_consumptions (
  id bigint NOT NULL DEFAULT nextval('inventory_consumptions_id_seq'::regclass),
  inventory_item_id bigint NOT NULL,
  item_name text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  consumption_date date NOT NULL DEFAULT CURRENT_DATE,
  purpose text,
  batch_no text,
  notes text,
  consumed_by text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT inventory_consumptions_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_consumptions_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES public.inventory_items(id) ON DELETE CASCADE
);