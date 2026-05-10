CREATE INDEX idx_orders_created_at_id ON orders (created_at, id);

CREATE INDEX idx_seller_order_status_history_order_changed_at ON seller_order_status_history (seller_order_id, changed_at DESC);

CREATE INDEX idx_seller_order_feedback_order_created_at ON seller_order_feedback (seller_order_id, created_at DESC);

CREATE INDEX idx_workload_events_created_at ON workload_events (created_at);

CREATE INDEX idx_carts_user_status_id ON carts (user_id, status, id DESC);
