import asyncio
import gzip
import shutil
from pathlib import Path

from temporalio import activity

WORK = Path("/tmp/temporal-homelab")


@activity.defn
async def snapshot(target: str) -> str:
    """Pretend to snapshot a dataset by writing a file."""
    WORK.mkdir(exist_ok=True)
    path = WORK / f"{target}.snap"
    path.write_text("pretend this is 500 GB of photos\n" * 1000)
    await asyncio.sleep(2)
    activity.logger.info("snapshot done: %s", path)
    return str(path)


@activity.defn
async def compress(snap: str) -> str:
    out = snap + ".gz"
    with open(snap, "rb") as src, gzip.open(out, "wb") as dst:
        shutil.copyfileobj(src, dst)
    await asyncio.sleep(2)
    return out


@activity.defn
async def upload(archive: str) -> str:
    """Fake upload. Fails on attempts 1 and 2 to show retries."""
    attempt = activity.info().attempt
    await asyncio.sleep(1)
    if attempt < 3:
        raise ConnectionError(f"remote host unreachable (attempt {attempt})")
    remote = WORK / "remote" / Path(archive).name
    remote.parent.mkdir(exist_ok=True)
    shutil.copy(archive, remote)
    return str(remote)


@activity.defn
async def verify(remote: str) -> None:
    with gzip.open(remote, "rb") as f:
        if not f.read(16).startswith(b"pretend"):
            raise ValueError("archive content is wrong")


@activity.defn
async def notify(message: str) -> None:
    print(f"NOTIFY: {message}", flush=True)
