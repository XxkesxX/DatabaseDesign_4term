ALTER TABLE seller_orders
  ADD COLUMN priority SMALLINT,
  ADD COLUMN last_status_changed_at TIMESTAMPTZ,
  ADD COLUMN total_amount NUMERIC(12,2);

CREATE TABLE seller_order_feedback (
  id BIGSERIAL PRIMARY KEY,
  seller_order_id BIGINT NOT NULL,
  rating SMALLINT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (seller_order_id) REFERENCES seller_orders(id) ON DELETE CASCADE
);
