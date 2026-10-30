CREATE TABLE products (
  id          bigint PRIMARY KEY,
  name        text   NOT NULL,
  description text   NOT NULL,
  price_cents bigint NOT NULL CHECK (price_cents > 0),
  stock       int    NOT NULL
);
INSERT INTO products
SELECT i, 'Product ' || i, rpad('Item ' || i || ' ', 200, 'x'), 100 + (i * 37) % 9900, 100
FROM generate_series(1, 10000) AS i;
ANALYZE products;
