INSERT INTO order_statuses (code, name)
VALUES
('new', 'Новый'),
('paid', 'Оплачен'),
('shipped', 'Отправлен'),
('cancelled', 'Отменен')
ON CONFLICT (code) DO NOTHING;

INSERT INTO payment_methods (code, name)
VALUES
('card', 'Карта'),
('cash', 'Наличные'),
('sbp', 'СБП')
ON CONFLICT (code) DO NOTHING;

INSERT INTO payment_statuses (code, name)
VALUES
('pending', 'В ожидании'),
('paid', 'Оплачен'),
('failed', 'Ошибка')
ON CONFLICT (code) DO NOTHING;

INSERT INTO delivery_services (code, name)
VALUES
('dhl', 'DHL'),
('post', 'Почта'),
('pickup', 'Пункт выдачи')
ON CONFLICT (code) DO NOTHING;

INSERT INTO shipment_statuses (code, name)
VALUES
('created', 'Создан'),
('shipped', 'Отправлен'),
('delivered', 'Доставлен')
ON CONFLICT (code) DO NOTHING;

WITH params AS (
  SELECT COALESCE(NULLIF(:'seed_count', '')::integer, 50000) AS n
),
user_bounds AS (
  SELECT min(u.id) AS min_id, count(*) AS cnt
  FROM users u
  WHERE u.email LIKE 'user%@mail.com'
)
INSERT INTO orders (user_id, address_id, created_at)
SELECT
  u.id,
  a.id,
  now()
    - ((i % 365)::text || ' days')::interval
    - ((i % 86400)::text || ' seconds')::interval
FROM params p
JOIN user_bounds ub ON ub.cnt > 0
JOIN generate_series(1, p.n * 2) AS g(i) ON true
JOIN users u ON u.id = (ub.min_id + ((g.i - 1) % ub.cnt))::bigint
JOIN addresses a ON a.user_id = u.id AND a.label = 'main';

WITH seller_bounds AS (
  SELECT min(id) AS min_id, count(*) AS cnt
  FROM sellers
)
INSERT INTO seller_orders (order_id, seller_id, created_at)
SELECT
  o.id,
  (sb.min_id + ((o.id + g.n) % sb.cnt))::bigint,
  o.created_at + ((g.n % 4)::text || ' hours')::interval
FROM orders o
JOIN seller_bounds sb ON sb.cnt > 0
JOIN generate_series(0, 1) AS g(n) ON true
ON CONFLICT DO NOTHING;

WITH sku_bounds AS (
  SELECT min(id) AS min_id, count(*) AS cnt
  FROM skus
)
INSERT INTO order_items (seller_order_id, sku_id, qty, unit_price)
SELECT
  so.id,
  sk.id,
  ((so.id + g.n) % 4 + 1)::integer,
  sk.price
FROM seller_orders so
JOIN sku_bounds sb ON sb.cnt > 0
JOIN generate_series(0, 1) AS g(n) ON true
JOIN skus sk ON sk.id = (sb.min_id + ((so.id * 13 + g.n) % sb.cnt))::bigint
ON CONFLICT DO NOTHING;

INSERT INTO seller_order_status_history (seller_order_id, status_id, changed_at, changed_by_user_id)
SELECT
  so.id,
  os.id,
  so.created_at + ((g.n * 8)::text || ' hours')::interval,
  o.user_id
FROM seller_orders so
JOIN orders o ON o.id = so.order_id
JOIN generate_series(0, 2) AS g(n) ON true
JOIN order_statuses os ON os.code = CASE g.n
  WHEN 0 THEN 'new'
  WHEN 1 THEN 'paid'
  ELSE 'shipped'
END;

INSERT INTO payments (order_id, method_id, status_id, amount, provider, provider_payment_id, created_at, paid_at)
SELECT
  o.id,
  pm.id,
  ps.id,
  coalesce(sum(oi.qty * oi.unit_price), 0)::numeric(12,2),
  'internal',
  'payment_' || o.id,
  o.created_at + interval '5 minutes',
  o.created_at + interval '15 minutes'
FROM orders o
JOIN seller_orders so ON so.order_id = o.id
JOIN order_items oi ON oi.seller_order_id = so.id
JOIN payment_methods pm ON pm.code = CASE WHEN o.id % 3 = 0 THEN 'sbp' ELSE 'card' END
JOIN payment_statuses ps ON ps.code = CASE WHEN o.id % 17 = 0 THEN 'failed' ELSE 'paid' END
GROUP BY o.id, pm.id, ps.id, o.created_at
ON CONFLICT DO NOTHING;

INSERT INTO shipments (seller_order_id, delivery_service_id, tracking_number, shipping_cost, created_at, shipped_at, delivered_at)
SELECT
  so.id,
  ds.id,
  'TRK' || so.id,
  ((so.id % 500) / 10.0)::numeric(12,2),
  so.created_at + interval '30 minutes',
  so.created_at + interval '12 hours',
  so.created_at + interval '72 hours'
FROM seller_orders so
JOIN delivery_services ds ON ds.code = CASE
  WHEN so.id % 5 = 0 THEN 'pickup'
  WHEN so.id % 2 = 0 THEN 'post'
  ELSE 'dhl'
END
ON CONFLICT DO NOTHING;

INSERT INTO shipment_status_history (shipment_id, status_id, changed_at)
SELECT
  sh.id,
  ss.id,
  sh.created_at + ((g.n * 24)::text || ' hours')::interval
FROM shipments sh
JOIN generate_series(0, 2) AS g(n) ON true
JOIN shipment_statuses ss ON ss.code = CASE g.n
  WHEN 0 THEN 'created'
  WHEN 1 THEN 'shipped'
  ELSE 'delivered'
END;
