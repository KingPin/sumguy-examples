#!/usr/bin/env bash
# Print the facts you need first when a container is in a restart loop.
# Usage: ./restart-triage.sh <container-name-or-id> [log-lines]
set -euo pipefail

c="${1:?usage: $0 <container> [log-lines]}"
lines="${2:-50}"

fmt() { docker inspect --format "$1" "$c"; }

echo "== $c =="
echo "status:         $(fmt '{{.State.Status}} (restarting={{.State.Restarting}})')"
echo "restart count:  $(fmt '{{.RestartCount}}')"
echo "restart policy: $(fmt '{{.HostConfig.RestartPolicy.Name}} max={{.HostConfig.RestartPolicy.MaximumRetryCount}}')"
echo "exit code:      $(fmt '{{.State.ExitCode}}')"
echo "OOMKilled:      $(fmt '{{.State.OOMKilled}}')"
echo "error:          $(fmt '{{.State.Error}}')"
echo "started at:     $(fmt '{{.State.StartedAt}}')"
echo "finished at:    $(fmt '{{.State.FinishedAt}}')"
echo "memory limit:   $(fmt '{{.HostConfig.Memory}}') bytes (0 = none)"

echo
echo "== last $lines log lines (timestamps, all runs interleaved) =="
docker logs --timestamps --tail "$lines" "$c" 2>&1 || true

echo
echo "== last die events (past 10 minutes) =="
# --until makes docker events return instead of streaming forever
docker events --since 10m --until "$(date +%s)" \
  --filter "container=$c" --filter event=die \
  --format '{{.Time}} exitCode={{.Actor.Attributes.exitCode}}' | tail -n 5 |
  while read -r t rest; do
    echo "$(date -d "@$t" '+%F %T' 2>/dev/null || date -r "$t" '+%F %T') $rest"
  done
