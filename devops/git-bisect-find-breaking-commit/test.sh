#!/usr/bin/env bash
# Run from inside the repo being bisected. Keep this file OUTSIDE the repo.
# exit 0 = good, 1 = bad, 125 = cannot test (skip)
bash -n app.sh 2>/dev/null || exit 125   # does not parse: skip

source ./app.sh
[ "$(total 3 4)" = "12" ]                # exit status of this test is the verdict
