INSERT INTO roles (code, name)
VALUES
('buyer', 'Покупатель'),
('seller', 'Продавец'),
('admin', 'Администратор')
ON CONFLICT (code) DO NOTHING;

WITH params AS (
  SELECT COALESCE(NULLIF(:'seed_count', '')::integer, 50000) AS n
)
INSERT INTO users (email, phone, password_hash, created_at)
SELECT
  'user' || i || '@mail.com',
  '+7' || lpad(i::text, 10, '0'),
  md5(i::text),
  now() - ((i % 720)::text || ' hours')::interval
FROM params
JOIN generate_series(1, params.n) AS s(i) ON true
ON CONFLICT (email) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'buyer'
WHERE u.email LIKE 'user%@mail.com'
ON CONFLICT DO NOTHING;

WITH params AS (
  SELECT COALESCE(NULLIF(:'seed_count', '')::integer, 50000) AS n
),
seller_users AS (
  SELECT id
  FROM users
  WHERE email LIKE 'user%@mail.com'
  ORDER BY id
  LIMIT (SELECT GREATEST(n / 20, 100) FROM params)
)
INSERT INTO user_roles (user_id, role_id)
SELECT su.id, r.id
FROM seller_users su
JOIN roles r ON r.code = 'seller'
ON CONFLICT DO NOTHING;
