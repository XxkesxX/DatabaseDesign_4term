INSERT INTO addresses (user_id, label, country, city, street, house, postal_code, created_at)
SELECT
  u.id,
  'main',
  'Finland',
  'Helsinki',
  'Street ' || u.id,
  ((u.id % 200) + 1)::text,
  lpad((u.id % 100000)::text, 5, '0'),
  u.created_at
FROM users u
WHERE u.email LIKE 'user%@mail.com'
  AND NOT EXISTS (
    SELECT 1
    FROM addresses a
    WHERE a.user_id = u.id
      AND a.label = 'main'
  );

WITH params AS (
  SELECT COALESCE(NULLIF(:'seed_count', '')::integer, 50000) AS n
),
seller_users AS (
  SELECT u.id, row_number() OVER (ORDER BY u.id) AS rn
  FROM users u
  JOIN user_roles ur ON ur.user_id = u.id
  JOIN roles r ON r.id = ur.role_id
  WHERE r.code = 'seller'
  ORDER BY u.id
  LIMIT (SELECT GREATEST(n / 20, 100) FROM params)
)
INSERT INTO sellers (user_id, shop_name, legal_name, inn, created_at)
SELECT
  id,
  'Shop ' || rn,
  'Legal Shop ' || rn,
  lpad(rn::text, 12, '0'),
  now() - ((rn % 365)::text || ' days')::interval
FROM seller_users
ON CONFLICT (user_id) DO NOTHING;
