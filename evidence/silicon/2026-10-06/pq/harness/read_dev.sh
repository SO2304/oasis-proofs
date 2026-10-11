#!/usr/bin/env bash
# read_dev.sh <dev> <seconds> : stream lines from a serial dev for N seconds to stdout, LF only
dev="$1"; secs="$2"
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
exec 3<>"$dev"
end=$((SECONDS + secs))
while [ "$SECONDS" -lt "$end" ]; do
  if IFS= read -r -t 1 -u 3 line; then
    line="${line%$'\r'}"
    printf '%s\n' "$line"
  fi
done
exit 0
