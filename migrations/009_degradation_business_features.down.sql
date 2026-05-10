DROP TABLE IF EXISTS seller_order_feedback;

ALTER TABLE seller_orders
  DROP COLUMN IF EXISTS total_amount,
  DROP COLUMN IF EXISTS last_status_changed_at,
  DROP COLUMN IF EXISTS priority;
