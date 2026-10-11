#!/usr/bin/env bash
# send_read.sh <dev> <byte> <seconds> : open dev once, send <byte>, stream lines for N seconds, LF only
dev="$1"; byte="$2"; secs="$3"
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
exec 3<>"$dev"
printf '%s' "$byte" >&3
end=$((SECONDS + secs))
while [ "$SECONDS" -lt "$end" ]; do
  if IFS= read -r -t 1 -u 3 line; then
    line="${line%$'\r'}"
    printf '%s\n' "$line"
  fi
done
exec 3<&- 3>&-
exit 0
