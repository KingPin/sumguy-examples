import asyncio
import nats

async def main():
    nc = await nats.connect("nats://localhost:4222")
    await nc.publish("orders.created", b'{"order_id": 4821}')
    await nc.flush()
    await nc.close()

asyncio.run(main())
