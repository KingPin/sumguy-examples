import asyncio

from temporalio.client import Client
from temporalio.worker import Worker

from activities import compress, notify, snapshot, upload, verify
from workflows import NightlyBackup

TASK_QUEUE = "homelab"


async def main() -> None:
    client = await Client.connect("localhost:7233")
    worker = Worker(
        client,
        task_queue=TASK_QUEUE,
        workflows=[NightlyBackup],
        activities=[snapshot, compress, upload, verify, notify],
    )
    print("worker up, waiting for tasks")
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
