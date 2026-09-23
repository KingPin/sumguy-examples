# RabbitMQ vs NATS: Two Message Buses Side by Side

Single-node Docker Compose stacks for RabbitMQ and NATS (with JetStream), plus
minimal Python producers and consumers for each.

This is the working version of the code from
[RabbitMQ vs NATS: Pick a Message Bus](https://sumguy.com/rabbitmq-vs-nats/).

## What it does

- `rabbitmq/`: RabbitMQ with the management UI, a durable `receipts` queue, a
  producer that publishes a persistent message, and a consumer that acks each
  message with `prefetch_count=1`.
- `nats/`: NATS with JetStream and the monitoring endpoint on 8222. Core
  pub/sub scripts (fire-and-forget) and JetStream scripts (an `ORDERS` stream
  plus a durable pull consumer named `receipts-worker`).

Two gotchas are baked in on purpose:

- The NATS stack uses `nats:2.15-alpine`. The plain `nats:2.15` image is
  scratch-based and has no `wget`, so the healthcheck would fail forever.
- `consumer_jetstream.py` catches `nats.errors.TimeoutError` around `fetch()`.
  nats-py raises it when no message arrives inside the timeout, so a worker
  without the `try` crashes the first time the stream goes idle.

## Prerequisites

Tested on:

- Docker 29.8 with Compose 5.5
- RabbitMQ 4.3 (`rabbitmq:4.3-management`)
- NATS Server 2.15 (`nats:2.15-alpine`)
- Python 3.14, pika 1.4.4, nats-py 2.16.0

## How to run

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
```

RabbitMQ:

```bash
cd rabbitmq
docker compose up -d --wait
python producer.py
python consumer.py        # prints the receipt, Ctrl+C to stop
docker compose down -v
```

The management UI is at http://localhost:15672 (login `appuser` / `change-me`).
Change the password before this leaves your laptop.

NATS:

```bash
cd nats
docker compose up -d --wait
python producer_jetstream.py
python consumer_jetstream.py   # prints the order, Ctrl+C to stop
docker compose down -v
```

For core pub/sub, start `subscriber_core.py` first, then run
`publisher_core.py`. Core NATS drops messages that nobody is subscribed to.
