-- customers: has a primary key, id comes from a bigserial sequence
CREATE TABLE customers (
  id         bigserial PRIMARY KEY,
  email      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- events: no primary key, so no replica identity by default
CREATE TABLE events (
  customer_id bigint NOT NULL,
  kind        text NOT NULL,
  at          timestamptz NOT NULL DEFAULT now()
);

INSERT INTO customers (email)
  SELECT 'user' || g || '@example.com' FROM generate_series(1, 500000) g;
INSERT INTO events (customer_id, kind)
  SELECT (g % 500000) + 1, 'seed' FROM generate_series(1, 3000000) g;
ANALYZE;
