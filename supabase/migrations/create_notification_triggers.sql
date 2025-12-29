-- SQL for SCM App Notification Triggers
-- This script sets up the automated triggers to call the 'notify' Edge Function
-- Requirements: pg_net extension must be enabled in your Supabase project

-- 1. Enable the pg_net extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the trigger handler function
-- Replace YOUR_PROJECT_REF with: scyueiggtjvwiqsintjr
-- Replace YOUR_ANON_KEY with your project's service_role key (available in Dashboard -> Settings -> API)
-- Note: It is safer to use the service_role key here because these are triggered by the DB system.

CREATE OR REPLACE FUNCTION public.handle_db_notification()
RETURNS TRIGGER AS $$
DECLARE
  payload JSONB;
  event_type TEXT;
  target_roles TEXT[] := '{}';
  target_users BIGINT[] := '{}';
  notify_title TEXT;
  notify_body TEXT;
BEGIN
  event_type := TG_ARGV[0];

  -- Define logic based on event type
  IF event_type = 'new_order' THEN
    notify_title := '📦 New Order Created';
    notify_body := 'Order #' || NEW.order_number || ' has been placed.';
    target_roles := ARRAY['admin', 'accounts', 'production'];
    payload := jsonb_build_object('order_id', NEW.id, 'order_number', NEW.order_number);

  ELSIF event_type = 'production_completed' THEN
    IF OLD.production_status IS DISTINCT FROM NEW.production_status AND NEW.production_status = 'completed' THEN
      notify_title := '⚙️ Production Completed';
      notify_body := 'Production for Order #' || NEW.order_number || ' is complete.';
      target_roles := ARRAY['admin', 'production'];
      payload := jsonb_build_object('order_id', NEW.id, 'order_number', NEW.order_number);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'order_ready' THEN
    -- Triggered when status moves to 'ready' (check your production_batches status)
    notify_title := '✅ Production Batch Completed';
    IF NEW.order_id IS NOT NULL THEN
      notify_body := 'Batch for Order #' || (SELECT order_number FROM orders WHERE id = NEW.order_id) || ' is completed and moved to inventory.';
    ELSE
      notify_body := 'Production Batch ' || NEW.batch_no || ' is completed and moved to inventory.';
    END IF;
    target_roles := ARRAY['admin', 'accounts', 'production'];
    payload := jsonb_build_object('order_id', NEW.order_id, 'batch_no', NEW.batch_no);

  ELSIF event_type = 'order_dispatched' THEN
    IF OLD.order_status IS DISTINCT FROM NEW.order_status AND NEW.order_status = 'dispatched' THEN
      notify_title := '🚚 Order Dispatched';
      notify_body := 'Order #' || NEW.order_number || ' has been dispatched.';
      target_roles := ARRAY['admin', 'accounts'];
      payload := jsonb_build_object('order_id', NEW.id, 'order_number', NEW.order_number);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'inventory_update' THEN
    notify_title := '📦 Inventory Updated';
    notify_body := NEW.name || ' quantity updated to ' || NEW.quantity;
    target_roles := ARRAY['admin', 'production'];
    payload := jsonb_build_object('item_id', NEW.id, 'item_name', NEW.name);

  ELSIF event_type = 'lab_test_completed' THEN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'completed' THEN
      notify_title := '🧪 Lab Test Completed';
      notify_body := 'Test "' || NEW.test_name || '" has been completed.';
      target_roles := ARRAY['admin', 'lab_testing'];
      payload := jsonb_build_object('test_id', NEW.id, 'status', NEW.status);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'location_updated' THEN
    IF OLD.location IS DISTINCT FROM NEW.location THEN
      notify_title := '📍 Shipment Location Updated';
      notify_body := 'Order #' || (SELECT order_number FROM orders WHERE id = NEW.order_id) || ' is currently at ' || NEW.location;
      target_roles := ARRAY['admin', 'accounts'];
      payload := jsonb_build_object('order_id', NEW.order_id, 'location', NEW.location);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'order_delivered' THEN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'delivered' THEN
      notify_title := '🏁 Order Delivered';
      notify_body := 'Order #' || (SELECT order_number FROM orders WHERE id = NEW.order_id) || ' has been delivered.';
      target_roles := ARRAY['admin', 'accounts'];
      payload := jsonb_build_object('order_id', NEW.order_id);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'todo_allotted' THEN
    notify_title := '📝 New Task Assigned';
    notify_body := NEW.title || ' has been assigned to you.';
    target_roles := ARRAY['admin']; -- Always notify admin
    -- Try to find the assignee user_id
    SELECT ARRAY_AGG(id) INTO target_users FROM users WHERE username = NEW.assignee;
    payload := jsonb_build_object('task_id', NEW.id);

  ELSIF event_type = 'todo_completed' THEN
    IF OLD.is_completed IS DISTINCT FROM NEW.is_completed AND NEW.is_completed = true THEN
      notify_title := '✅ Task Completed';
      notify_body := NEW.title || ' has been marked as complete.';
      target_roles := ARRAY['admin'];
      -- Notify assigner if they are different from admin
      SELECT ARRAY_AGG(id) INTO target_users FROM users WHERE username = NEW.assigned_by OR username = NEW.assignee;
      payload := jsonb_build_object('task_id', NEW.id);
    ELSE
      RETURN NEW;
    END IF;

  ELSIF event_type = 'payment_update' THEN
    notify_title := '💰 Payment Received';
    notify_body := 'Amount of ' || NEW.amount || ' recorded for Order #' || (SELECT order_number FROM orders WHERE id = NEW.order_id);
    target_roles := ARRAY['admin', 'accounts'];
    payload := jsonb_build_object('order_id', NEW.order_id);

  END IF;

  -- Call the Edge Function via pg_net
  -- Note: We use net.http_post for asynchronous calls so we don't slow down the database transaction
  PERFORM net.http_post(
    url := 'https://scyueiggtjvwiqsintjr.supabase.co/functions/v1/notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjeXVlaWdndGp2d2lxc2ludGpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTQ3Njk4MCwiZXhwIjoyMDc1MDUyOTgwfQ.GXEE49kwf6lBxGFvmvOnqdr1Iz6zWN2x694J_Y0c2Dg' -- Replace YOUR_SERVICE_ROLE_KEY with actual key
    ),
    body := jsonb_build_object(
      'title', notify_title,
      'body', notify_body,
      'event_type', event_type,
      'recipient_roles', target_roles,
      'recipient_user_ids', target_users,
      'data', payload
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the Triggers

-- New Order
DROP TRIGGER IF EXISTS tr_order_created ON orders;
CREATE TRIGGER tr_order_created
AFTER INSERT ON orders
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('new_order');

-- Production Completed
DROP TRIGGER IF EXISTS tr_production_completed ON orders;
CREATE TRIGGER tr_production_completed
AFTER UPDATE OF production_status ON orders
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('production_completed');

-- Order Ready (on production_batches)
DROP TRIGGER IF EXISTS tr_order_ready ON production_batches;
CREATE TRIGGER tr_order_ready
AFTER UPDATE OF status ON production_batches
FOR EACH ROW 
WHEN (NEW.status = 'ready')
EXECUTE FUNCTION handle_db_notification('order_ready');

-- Order Dispatched
DROP TRIGGER IF EXISTS tr_order_dispatched ON orders;
CREATE TRIGGER tr_order_dispatched
AFTER UPDATE OF order_status ON orders
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('order_dispatched');

-- Inventory Update
DROP TRIGGER IF EXISTS tr_inventory_update ON inventory_items;
CREATE TRIGGER tr_inventory_update
AFTER UPDATE OF quantity ON inventory_items
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('inventory_update');

-- Lab Test Completed
DROP TRIGGER IF EXISTS tr_lab_test_completed ON lab_tests;
CREATE TRIGGER tr_lab_test_completed
AFTER UPDATE OF status ON lab_tests
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('lab_test_completed');

-- Location Updated
DROP TRIGGER IF EXISTS tr_shipment_location ON shipments;
CREATE TRIGGER tr_shipment_location
AFTER UPDATE OF location ON shipments
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('location_updated');

-- Order Delivered
DROP TRIGGER IF EXISTS tr_order_delivered ON shipments;
CREATE TRIGGER tr_order_delivered
AFTER UPDATE OF status ON shipments
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('order_delivered');

-- Todo Allotted
DROP TRIGGER IF EXISTS tr_todo_allotted ON calendar_tasks;
CREATE TRIGGER tr_todo_allotted
AFTER INSERT ON calendar_tasks
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('todo_allotted');

-- Todo Completed
DROP TRIGGER IF EXISTS tr_todo_completed ON calendar_tasks;
CREATE TRIGGER tr_todo_completed
AFTER UPDATE OF is_completed ON calendar_tasks
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('todo_completed');

-- Payment Update
DROP TRIGGER IF EXISTS tr_payment_update ON payments;
CREATE TRIGGER tr_payment_update
AFTER INSERT ON payments
FOR EACH ROW EXECUTE FUNCTION handle_db_notification('payment_update');
