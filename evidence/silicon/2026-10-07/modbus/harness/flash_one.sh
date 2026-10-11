#!/usr/bin/env bash
# flash_one.sh <ttyS> <uf2> : reboot that board to BOOTSEL ('b'), wait for exactly one
# RPI-RP2 volume (checked via INFO_UF2.TXT), copy the UF2, wait for the port to return.
dev="$1"; uf2="$2"
vols() { powershell.exe -NoProfile -Command "(Get-Volume | Where-Object FileSystemLabel -eq 'RPI-RP2').DriveLetter" | tr -d '\r' | grep -E '^[A-Z]$'; }
[ -n "$(vols)" ] && { echo "ABORT: an RPI-RP2 volume is already present"; exit 2; }
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
printf 'b' > "$dev"
for i in $(seq 1 30); do v=$(vols); [ -n "$v" ] && break; sleep 0.5; done
n=$(printf '%s\n' "$v" | grep -c .)
[ "$n" != 1 ] && { echo "ABORT: expected 1 RPI-RP2 volume, got $n ($v)"; exit 3; }
grep -q "RP2" "/$(echo $v | tr A-Z a-z)/INFO_UF2.TXT" || { echo "ABORT: $v: no RP2 INFO_UF2.TXT"; exit 4; }
echo "flashing $uf2 -> $v: ($(head -2 /$(echo $v | tr A-Z a-z)/INFO_UF2.TXT | tr -d '\r' | tr '\n' ' '))"
cp "$uf2" "/$(echo $v | tr A-Z a-z)/" || { echo "copy failed"; exit 5; }
for i in $(seq 1 40); do [ -e "$dev" ] && [ -z "$(vols)" ] && break; sleep 0.5; done
sleep 2
echo "done: $dev back=$([ -e $dev ] && echo yes || echo no)"
