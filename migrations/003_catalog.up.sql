CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  seller_id BIGINT NOT NULL,
  title VARCHAR NOT NULL,
  description TEXT,
  brand VARCHAR,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (seller_id) REFERENCES sellers(id) ON DELETE CASCADE
);

CREATE TABLE skus (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL,
  sku_code VARCHAR NOT NULL UNIQUE,
  price NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE attributes (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE attribute_values (
  id BIGSERIAL PRIMARY KEY,
  attribute_id SMALLINT NOT NULL,
  value VARCHAR NOT NULL,
  UNIQUE(attribute_id, value),
  FOREIGN KEY (attribute_id) REFERENCES attributes(id) ON DELETE CASCADE
);

CREATE TABLE sku_attribute_values (
  sku_id BIGINT NOT NULL,
  attribute_id SMALLINT NOT NULL,
  attribute_value_id BIGINT NOT NULL,
  UNIQUE(sku_id, attribute_id),
  UNIQUE(sku_id, attribute_value_id),
  FOREIGN KEY (sku_id) REFERENCES skus(id) ON DELETE CASCADE,
  FOREIGN KEY (attribute_id) REFERENCES attributes(id),
  FOREIGN KEY (attribute_value_id) REFERENCES attribute_values(id)
);