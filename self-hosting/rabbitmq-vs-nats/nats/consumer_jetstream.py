import asyncio
import nats
from nats.errors import TimeoutError as NatsTimeout

async def main():
    nc = await nats.connect("nats://localhost:4222")
    js = nc.jetstream()

    sub = await js.pull_subscribe("orders.*", durable="receipts-worker")
    while True:
        try:
            msgs = await sub.fetch(10, timeout=5)
        except NatsTimeout:
            continue  # nothing arrived in 5s; poll again
        for msg in msgs:
            print(f"processing: {msg.data.decode()}")
            await msg.ack()

asyncio.run(main())
