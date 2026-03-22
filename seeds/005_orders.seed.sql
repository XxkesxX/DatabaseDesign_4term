INSERT INTO order_statuses (code, name)
VALUES 
('new', 'Новый'),
('paid', 'Оплачен'),
('shipped', 'Отправлен')
ON CONFLICT (code) DO NOTHING;

INSERT INTO payment_methods (code, name)
VALUES 
('card', 'Карта'),
('cash', 'Наличные')
ON CONFLICT (code) DO NOTHING;

INSERT INTO payment_statuses (code, name)
VALUES 
('pending', 'В ожидании'),
('paid', 'Оплачен')
ON CONFLICT (code) DO NOTHING;

INSERT INTO delivery_services (code, name)
VALUES 
('dhl', 'DHL'),
('post', 'Почта')
ON CONFLICT (code) DO NOTHING;

INSERT INTO shipment_statuses (code, name)
VALUES 
('created', 'Создан'),
('delivered', 'Доставлен')
ON CONFLICT (code) DO NOTHING;

INSERT INTO orders (user_id, address_id)
SELECT 
  u.id,
  a.id
FROM users u
JOIN addresses a ON a.user_id = u.id
LIMIT 5
ON CONFLICT DO NOTHING;

INSERT INTO seller_orders (order_id, seller_id)
SELECT 
  o.id,
  s.id
FROM orders o
JOIN sellers s ON TRUE
LIMIT 5
ON CONFLICT DO NOTHING;

INSERT INTO order_items (seller_order_id, sku_id, qty, unit_price)
SELECT 
  so.id,
  s.id,
  1,
  s.price
FROM seller_orders so
JOIN skus s ON TRUE
LIMIT 10
ON CONFLICT DO NOTHING;

INSERT INTO payments (order_id, method_id, status_id, amount)
SELECT 
  o.id,
  pm.id,
  ps.id,
  100
FROM orders o
JOIN payment_methods pm ON pm.code = 'card'
JOIN payment_statuses ps ON ps.code = 'paid'
ON CONFLICT DO NOTHING;

INSERT INTO shipments (seller_order_id, delivery_service_id, shipping_cost)
SELECT 
  so.id,
  ds.id,
  10
FROM seller_orders so
JOIN delivery_services ds ON ds.code = 'dhl'
ON CONFLICT DO NOTHING;

INSERT INTO shipment_status_history (shipment_id, status_id)
SELECT 
  s.id,
  ss.id
FROM shipments s
JOIN shipment_statuses ss ON ss.code = 'created'
ON CONFLICT DO NOTHING;