INSERT INTO warehouses (seller_id, name, address_text, created_at)
SELECT
  s.id,
  'Warehouse ' || s.id || '_' || g.n,
  'Warehouse address ' || s.id || '_' || g.n,
  s.created_at + ((g.n % 24)::text || ' hours')::interval
FROM sellers s
JOIN generate_series(1, 2) AS g(n) ON true
WHERE NOT EXISTS (
  SELECT 1
  FROM warehouses w
  WHERE w.seller_id = s.id
    AND w.name = 'Warehouse ' || s.id || '_' || g.n
);

INSERT INTO inventory (warehouse_id, sku_id, qty, updated_at)
SELECT
  w.id,
  sk.id,
  ((w.id + sk.id) % 250)::integer,
  now() - (((w.id + sk.id) % 168)::text || ' hours')::interval
FROM warehouses w
JOIN products p ON p.seller_id = w.seller_id
JOIN skus sk ON sk.product_id = p.id
ON CONFLICT DO NOTHING;

INSERT INTO carts (user_id, status, created_at, updated_at)
SELECT
  u.id,
  'active',
  u.created_at + interval '1 hour',
  u.created_at + interval '2 hours'
FROM users u
WHERE u.email LIKE 'user%@mail.com'
  AND NOT EXISTS (
    SELECT 1
    FROM carts c
    WHERE c.user_id = u.id
      AND c.status = 'active'
  );

WITH sku_bounds AS (
  SELECT min(id) AS min_id, count(*) AS cnt
  FROM skus
)
INSERT INTO cart_items (cart_id, sku_id, qty, added_at)
SELECT
  c.id,
  (sb.min_id + ((c.user_id * 17 + g.n) % sb.cnt))::bigint,
  (g.n % 3) + 1,
  c.created_at + ((g.n % 24)::text || ' hours')::interval
FROM carts c
JOIN sku_bounds sb ON sb.cnt > 0
JOIN generate_series(0, 2) AS g(n) ON true
ON CONFLICT DO NOTHING;
