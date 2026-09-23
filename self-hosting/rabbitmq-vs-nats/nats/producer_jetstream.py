import asyncio
import nats

async def main():
    nc = await nats.connect("nats://localhost:4222")
    js = nc.jetstream()

    await js.add_stream(name="ORDERS", subjects=["orders.*"])
    await js.publish("orders.created", b'{"order_id": 4821}')
    await nc.close()

asyncio.run(main())
