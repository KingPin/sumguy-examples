from dataclasses import dataclass
from datetime import timedelta

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from activities import compress, notify, snapshot, upload, verify


@dataclass
class BackupInput:
    target: str = "photos"
    settle_seconds: int = 10


@workflow.defn
class NightlyBackup:
    @workflow.run
    async def run(self, inp: BackupInput) -> str:
        snap = await workflow.execute_activity(
            snapshot, inp.target, start_to_close_timeout=timedelta(minutes=5)
        )
        archive = await workflow.execute_activity(
            compress, snap, start_to_close_timeout=timedelta(minutes=30)
        )
        # Flaky network step: retry with backoff, give up after 5 tries.
        remote = await workflow.execute_activity(
            upload,
            archive,
            start_to_close_timeout=timedelta(minutes=10),
            retry_policy=RetryPolicy(
                initial_interval=timedelta(seconds=2),
                backoff_coefficient=2.0,
                maximum_attempts=5,
            ),
        )
        # Durable timer: survives worker restarts and server restarts.
        await workflow.sleep(timedelta(seconds=inp.settle_seconds))
        await workflow.execute_activity(
            verify, remote, start_to_close_timeout=timedelta(minutes=10)
        )
        msg = f"backup of {inp.target} verified at {remote}"
        await workflow.execute_activity(
            notify, msg, start_to_close_timeout=timedelta(seconds=30)
        )
        return msg
