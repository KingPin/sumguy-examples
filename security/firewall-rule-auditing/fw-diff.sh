#!/usr/bin/env bash
set -euo pipefail
old=$1 new=$2

jq -r -n --slurpfile a "$old" --slurpfile b "$new" '
  def counts: [ .nftables[] | select(has("rule")) | .rule
      | { key: "\(.family)/\(.table)/\(.handle)",
          value: { comment: (.comment // "-"),
                   packets: ([.expr[] | objects | select(has("counter"))
                              | .counter | objects | .packets] | first) } }
      | select(.value.packets != null) ] | from_entries;
  ($a[0] | counts) as $then | ($b[0] | counts) as $now
  | $now | to_entries[]
  | [ .key, .value.comment, ($then[.key].packets // 0), .value.packets,
      (.value.packets - ($then[.key].packets // 0)) ] | @tsv' \
| awk -F'\t' -v OFS='\t' '$5 == 0 { $6 = "CANDIDATE" } 1' \
| column -t -s $'\t'
