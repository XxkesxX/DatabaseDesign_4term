CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  address_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (address_id) REFERENCES addresses(id)
);

CREATE TABLE seller_orders (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL,
  seller_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(order_id, seller_id),
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (seller_id) REFERENCES sellers(id)
);

CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,
  seller_order_id BIGINT NOT NULL,
  sku_id BIGINT NOT NULL,
  qty INTEGER NOT NULL,
  unit_price NUMERIC(12,2) NOT NULL,
  UNIQUE(seller_order_id, sku_id),
  FOREIGN KEY (seller_order_id) REFERENCES seller_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (sku_id) REFERENCES skus(id)
);

CREATE TABLE order_statuses (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE seller_order_status_history (
  id BIGSERIAL PRIMARY KEY,
  seller_order_id BIGINT NOT NULL,
  status_id SMALLINT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by_user_id BIGINT,
  FOREIGN KEY (seller_order_id) REFERENCES seller_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (status_id) REFERENCES order_statuses(id),
  FOREIGN KEY (changed_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE payment_methods (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE payment_statuses (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE payments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL,
  method_id SMALLINT NOT NULL,
  status_id SMALLINT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  provider VARCHAR,
  provider_payment_id VARCHAR,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at TIMESTAMPTZ,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (method_id) REFERENCES payment_methods(id),
  FOREIGN KEY (status_id) REFERENCES payment_statuses(id)
);

CREATE TABLE delivery_services (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE shipments (
  id BIGSERIAL PRIMARY KEY,
  seller_order_id BIGINT NOT NULL,
  delivery_service_id SMALLINT NOT NULL,
  tracking_number VARCHAR,
  shipping_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  FOREIGN KEY (seller_order_id) REFERENCES seller_orders(id),
  FOREIGN KEY (delivery_service_id) REFERENCES delivery_services(id)
);

CREATE TABLE shipment_statuses (
  id SMALLSERIAL PRIMARY KEY,
  code VARCHAR NOT NULL UNIQUE,
  name VARCHAR NOT NULL
);

CREATE TABLE shipment_status_history (
  id BIGSERIAL PRIMARY KEY,
  shipment_id BIGINT NOT NULL,
  status_id SMALLINT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
  FOREIGN KEY (status_id) REFERENCES shipment_statuses(id)
);