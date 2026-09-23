import asyncio
import nats

async def main():
    nc = await nats.connect("nats://localhost:4222")

    async def handler(msg):
        print(f"received on {msg.subject}: {msg.data.decode()}")

    await nc.subscribe("orders.*", cb=handler)
    await asyncio.sleep(3600)

asyncio.run(main())
