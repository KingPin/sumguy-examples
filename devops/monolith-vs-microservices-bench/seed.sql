-- psql -v micro=0 -f seed.sql   monolith: one database "shop"
-- psql -v micro=1 -f seed.sql   microservices: databases catalog, cart, orders, one role each
-- Run as the postgres superuser over TCP with PGPASSWORD=bench (every role uses that password).
\set ON_ERROR_STOP on
\if :micro
CREATE ROLE catalog LOGIN PASSWORD 'bench';
CREATE DATABASE catalog OWNER catalog;
CREATE ROLE cart LOGIN PASSWORD 'bench';
CREATE DATABASE cart OWNER cart;
CREATE ROLE orders LOGIN PASSWORD 'bench';
CREATE DATABASE orders OWNER orders;
\connect catalog catalog
\ir sql/catalog.sql
\connect cart cart
\ir sql/cart.sql
\connect orders orders
\ir sql/orders.sql
\else
CREATE ROLE shop LOGIN PASSWORD 'bench';
CREATE DATABASE shop OWNER shop;
\connect shop shop
\ir sql/catalog.sql
\ir sql/cart.sql
\ir sql/orders.sql
\endif
