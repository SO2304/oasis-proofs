#!/usr/bin/env bash
# port_watch.sh <dev> <out> <seconds>: log every presence transition of <dev> with a UTC ms timestamp.
dev="$1"; out="$2"; secs="$3"; prev=x; end=$((SECONDS + secs))
while [ "$SECONDS" -lt "$end" ]; do
  now=$([ -e "$dev" ] && echo present || echo absent)
  [ "$now" != "$prev" ] && { echo "$(date -u +%FT%T.%3NZ) $dev $now" >> "$out"; prev=$now; }
  sleep 0.1
done
