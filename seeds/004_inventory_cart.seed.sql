INSERT INTO warehouses (seller_id, name)
SELECT 
  id,
  'Warehouse ' || id
FROM sellers
ON CONFLICT DO NOTHING;

INSERT INTO inventory (warehouse_id, sku_id, qty)
SELECT 
  w.id,
  s.id,
  (random() * 50)::int
FROM warehouses w
JOIN skus s ON TRUE
ON CONFLICT DO NOTHING;

INSERT INTO carts (user_id)
SELECT id FROM users
ON CONFLICT DO NOTHING;

INSERT INTO cart_items (cart_id, sku_id, qty)
SELECT 
  c.id,
  s.id,
  1
FROM carts c
JOIN skus s ON TRUE
LIMIT 20
ON CONFLICT DO NOTHING;