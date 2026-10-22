import pathlib
import tempfile
import time

with tempfile.NamedTemporaryFile(dir="/tmp") as scratch:
    scratch.write(b"scratch data")
    scratch.flush()
    pathlib.Path("/tmp/alive").write_text("ok")
    print("worker running, scratch file:", scratch.name, flush=True)
    while True:
        time.sleep(60)
