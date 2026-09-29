import asyncio
import sys
import time

from temporalio.client import Client

from workflows import BackupInput, NightlyBackup


async def main() -> None:
    target = sys.argv[1] if len(sys.argv) > 1 else "photos"
    client = await Client.connect("localhost:7233")
    result = await client.execute_workflow(
        NightlyBackup.run,
        BackupInput(target=target),
        id=f"nightly-backup-{target}-{int(time.time())}",
        task_queue="homelab",
    )
    print(f"result: {result}")


if __name__ == "__main__":
    asyncio.run(main())
