UPDATE seller_orders so
SET
  priority = ((so.id % 3) + 1)::smallint,
  last_status_changed_at = h.changed_at,
  total_amount = t.total_amount
FROM (
  SELECT seller_order_id, max(changed_at) AS changed_at
  FROM seller_order_status_history
  GROUP BY seller_order_id
) h
JOIN (
  SELECT seller_order_id, sum(qty * unit_price)::numeric(12,2) AS total_amount
  FROM order_items
  GROUP BY seller_order_id
) t ON t.seller_order_id = h.seller_order_id
WHERE so.id = h.seller_order_id;

INSERT INTO seller_order_feedback (seller_order_id, rating, comment, created_at)
SELECT
  so.id,
  ((so.id % 5) + 1)::smallint,
  'feedback ' || so.id,
  so.created_at + interval '7 days'
FROM seller_orders so
WHERE so.id % 4 = 0;

WITH params AS (
  SELECT COALESCE(NULLIF(:'seed_count', '')::integer, 50000) AS n
)
INSERT INTO workload_events (event_type, seller_order_id, user_id, payload, created_at)
SELECT
  CASE WHEN g.n % 2 = 0 THEN 'status_changed' ELSE 'cart_changed' END,
  so.id,
  o.user_id,
  jsonb_build_object('source', 'seed', 'seq', g.n),
  so.created_at + ((g.n % 3600)::text || ' seconds')::interval
FROM params p
JOIN seller_orders so ON true
JOIN orders o ON o.id = so.order_id
JOIN generate_series(1, 2) AS g(n) ON true
LIMIT (SELECT n * 4 FROM params);
