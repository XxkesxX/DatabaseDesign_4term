CREATE TABLE workload_events (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR NOT NULL,
  seller_order_id BIGINT,
  user_id BIGINT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (seller_order_id) REFERENCES seller_orders(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
