#!/usr/bin/env bash
# px4_build.sh — build px4_sitl_default with the sudo-free toolchain in $HOME/px4-venv.
# Writes only inside $HOME/PX4-Autopilot/build and $HOME/px4-build.log.
set -u
V="$HOME/px4-venv"
D="$HOME/PX4-Autopilot"
LOG="$HOME/px4-build.log"

case "$D" in "$HOME"/*) ;; *) echo "refus: D=$D"; exit 3;; esac
[ -x "$V/bin/cmake" ] || { echo "cmake absent du venv"; exit 2; }
[ -d "$D" ] || { echo "absent: $D"; exit 1; }

export PATH="$V/bin:$PATH"
export VIRTUAL_ENV="$V"
export PYTHON_EXECUTABLE="$V/bin/python"
export MAKEFLAGS="-j4"

echo "cmake   : $(command -v cmake) $(cmake --version | head -1)"
echo "ninja   : $(command -v ninja) $(ninja --version)"
echo "python3 : $(command -v python3) $(python3 --version 2>&1)"
echo "debut   : $(date -u +%FT%TZ)"
echo

cd "$D"
# A fresh configure+build. PX4 picks ninja when it is on PATH.
make px4_sitl_default > "$LOG" 2>&1
rc=$?
echo "fin     : $(date -u +%FT%TZ), rc=$rc"
echo
if [ -x "$D/build/px4_sitl_default/bin/px4" ]; then
  echo "BINAIRE OK : $(ls -l "$D/build/px4_sitl_default/bin/px4" | awk '{print $5" octets"}')"
else
  echo "PAS DE BINAIRE. 40 dernieres lignes du log :"
  tail -40 "$LOG"
fi
exit $rc
