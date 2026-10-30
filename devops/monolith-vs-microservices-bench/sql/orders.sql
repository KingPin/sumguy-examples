CREATE TABLE orders (
  id          bigserial   PRIMARY KEY,
  user_id     bigint      NOT NULL,
  total_cents bigint      NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE order_items (
  order_id    bigint NOT NULL REFERENCES orders (id),
  product_id  bigint NOT NULL,
  qty         int    NOT NULL,
  price_cents bigint NOT NULL,
  PRIMARY KEY (order_id, product_id)
);
