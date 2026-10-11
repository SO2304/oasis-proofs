#!/usr/bin/env bash
# fw_upload.sh <dev> <image.bin> <manifest.hex|-> <log>
# Phase 1.3: write the image into the node's DFU partition (`@U<offset><256 B>`
# lines), then stage the manifest (`@C`, `@Q` chunks) and ask for the install (`@M`).
# One process holds the port (Windows COM ports are exclusive): it writes and drains
# the replies. LF-only log. `-` as manifest: upload only (no install).
dev="$1"; img="$2"; man="$3"; log="$4"
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
exec 3<>"$dev"
: > "$log"
drain() { while IFS= read -r -t "${1:-0.01}" -u 3 line; do printf '%s\n' "${line%$'\r'}" >> "$log"; done; }
hex=$(xxd -p "$img" | tr -d '\n')
n=${#hex}
echo "# upload $(( n / 2 )) bytes from $(basename "$img") at $(date -u +%FT%TZ)" >> "$log"
t0=$SECONDS
for (( i=0; i<n; i+=512 )); do
  printf '@U%08x%s\n' $(( i / 2 )) "${hex:i:512}" >&3
  drain "${GAP:-0.005}"  # GAP=0.1: ~2 min upload (T6 power-cut window)
done
drain 2
echo "# upload sent in $(( SECONDS - t0 )) s" >> "$log"
if [ "$man" != "-" ]; then
  mh=$(tr -d ' \r\n' < "$man")
  printf '@C\n' >&3
  for (( i=0; i<${#mh}; i+=560 )); do printf '@Q%s\n' "${mh:i:560}" >&3; drain 0.05; done
  printf '@M\n' >&3
  drain 1
  end=$((SECONDS + 6))
  while [ "$SECONDS" -lt "$end" ]; do drain 1 2>/dev/null || break; done
fi
exec 3<&- 3>&- 2>/dev/null
exit 0
