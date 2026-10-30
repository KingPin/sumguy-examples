CREATE TABLE cart_items (
  user_id    bigint NOT NULL,
  product_id bigint NOT NULL,
  qty        int    NOT NULL CHECK (qty > 0),
  PRIMARY KEY (user_id, product_id)
);
