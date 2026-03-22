INSERT INTO addresses (user_id, country, city, street, house)
SELECT 
  id,
  'Finland',
  'Helsinki',
  'Street ' || id,
  id::text
FROM users
ON CONFLICT DO NOTHING;

INSERT INTO sellers (user_id, shop_name)
SELECT 
  id,
  'Shop ' || id
FROM users
WHERE id <= 3
ON CONFLICT (user_id) DO NOTHING;