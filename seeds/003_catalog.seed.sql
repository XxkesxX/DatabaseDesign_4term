INSERT INTO products (seller_id, title, description)
SELECT 
  s.id,
  'Product ' || s.id || '_' || i,
  'Description'
FROM sellers s,
generate_series(1, 3) i
ON CONFLICT DO NOTHING;

INSERT INTO skus (product_id, sku_code, price)
SELECT 
  p.id,
  'SKU_' || p.id,
  (random() * 100 + 10)::numeric(12,2)
FROM products p
ON CONFLICT (sku_code) DO NOTHING;

INSERT INTO attributes (code, name)
VALUES 
('color', 'Цвет'),
('size', 'Размер')
ON CONFLICT (code) DO NOTHING;

INSERT INTO attribute_values (attribute_id, value)
SELECT a.id, v.val
FROM attributes a
JOIN (VALUES 
  ('color', 'red'),
  ('color', 'blue'),
  ('size', 'M'),
  ('size', 'L')
) v(code, val) ON v.code = a.code
ON CONFLICT DO NOTHING;

INSERT INTO sku_attribute_values (sku_id, attribute_id, attribute_value_id)
SELECT 
  s.id,
  av.attribute_id,
  av.id
FROM skus s
JOIN attribute_values av ON TRUE
ON CONFLICT DO NOTHING;