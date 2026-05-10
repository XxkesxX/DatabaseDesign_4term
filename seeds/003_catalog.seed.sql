INSERT INTO products (seller_id, title, description, brand, is_active, created_at)
SELECT
  s.id,
  'Product ' || s.id || '_' || g.n,
  'Description ' || g.n,
  'Brand ' || ((s.id + g.n) % 25),
  true,
  s.created_at + ((g.n % 24)::text || ' hours')::interval
FROM sellers s
JOIN generate_series(1, 5) AS g(n) ON true
WHERE NOT EXISTS (
  SELECT 1
  FROM products p
  WHERE p.seller_id = s.id
    AND p.title = 'Product ' || s.id || '_' || g.n
);

INSERT INTO skus (product_id, sku_code, price, created_at)
SELECT
  p.id,
  'SKU_' || p.id || '_' || g.n,
  (100 + ((p.id * 7 + g.n * 13) % 9000) / 10.0)::numeric(12,2),
  p.created_at + ((g.n % 12)::text || ' hours')::interval
FROM products p
JOIN generate_series(1, 2) AS g(n) ON true
WHERE NOT EXISTS (
  SELECT 1
  FROM skus s
  WHERE s.sku_code = 'SKU_' || p.id || '_' || g.n
);

INSERT INTO attributes (code, name)
VALUES
('color', 'Цвет'),
('size', 'Размер')
ON CONFLICT (code) DO NOTHING;

INSERT INTO attribute_values (attribute_id, value)
SELECT a.id, v.val
FROM attributes a
JOIN (
  VALUES
  ('color', 'red'),
  ('color', 'blue'),
  ('color', 'green'),
  ('color', 'black'),
  ('color', 'white'),
  ('size', 'XS'),
  ('size', 'S'),
  ('size', 'M'),
  ('size', 'L'),
  ('size', 'XL')
) AS v(code, val) ON v.code = a.code
ON CONFLICT DO NOTHING;

WITH color_attribute AS (
  SELECT id
  FROM attributes
  WHERE code = 'color'
),
color_values AS (
  SELECT id, row_number() OVER (ORDER BY id) AS rn, count(*) OVER () AS cnt
  FROM attribute_values
  WHERE attribute_id = (SELECT id FROM color_attribute)
)
INSERT INTO sku_attribute_values (sku_id, attribute_id, attribute_value_id)
SELECT
  s.id,
  ca.id,
  cv.id
FROM skus s
JOIN color_attribute ca ON true
JOIN color_values cv ON cv.rn = ((s.id % cv.cnt) + 1)
ON CONFLICT DO NOTHING;

WITH size_attribute AS (
  SELECT id
  FROM attributes
  WHERE code = 'size'
),
size_values AS (
  SELECT id, row_number() OVER (ORDER BY id) AS rn, count(*) OVER () AS cnt
  FROM attribute_values
  WHERE attribute_id = (SELECT id FROM size_attribute)
)
INSERT INTO sku_attribute_values (sku_id, attribute_id, attribute_value_id)
SELECT
  s.id,
  sa.id,
  sv.id
FROM skus s
JOIN size_attribute sa ON true
JOIN size_values sv ON sv.rn = (((s.id / 2) % sv.cnt) + 1)
ON CONFLICT DO NOTHING;
