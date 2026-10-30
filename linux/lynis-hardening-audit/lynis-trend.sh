#!/usr/bin/env bash
# Run a Lynis audit and append one CSV row: date, hardening index, warnings, suggestions.
# Usage: sudo ./lynis-trend.sh
# Override with env vars: LYNIS=/opt/lynis/lynis  REPORT=/var/log/lynis-report.dat  CSV=/var/lib/lynis-trend/history.csv
set -euo pipefail

LYNIS="${LYNIS:-lynis}"
REPORT="${REPORT:-/var/log/lynis-report.dat}"
CSV="${CSV:-/var/lib/lynis-trend/history.csv}"

mkdir -p "$(dirname "$CSV")"
[ -s "$CSV" ] || echo "date,hardening_index,warnings,suggestions,lynis_version" > "$CSV"

# A git checkout or tarball must run from its own directory, or Lynis exits with
# "can't find include directory". A packaged lynis on PATH has no slash and skips this.
if [[ "$LYNIS" == */* ]]; then
  cd "$(dirname "$LYNIS")"
  LYNIS="./$(basename "$LYNIS")"
fi

"$LYNIS" audit system --cronjob > /dev/null

# One pass over the report. Every line is key=value; warning[] and suggestion[] repeat.
row=$(awk -F= '
  /^hardening_index=/ { idx = $2 }
  /^lynis_version=/   { ver = $2 }
  /^warning\[\]=/     { w++ }
  /^suggestion\[\]=/  { s++ }
  END { if (idx == "") exit 1; printf "%s,%d,%d,%s", idx, w, s, ver }
' "$REPORT") || { echo "no hardening_index in $REPORT" >&2; exit 1; }

echo "$(date +%F),$row" >> "$CSV"
tail -n 1 "$CSV"
