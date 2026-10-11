#!/usr/bin/env bash
# px4_bootstrap.sh — try to get a PX4 SITL build toolchain WITHOUT sudo:
# a venv in $HOME, then cmake + ninja + the minimal build-time python deps as wheels.
# Writes only inside $HOME/px4-venv. No apt, no root, nothing outside $HOME.
set -u
V="$HOME/px4-venv"
D="$HOME/PX4-Autopilot"

case "$V" in "$HOME"/*) ;; *) echo "refus: V=$V"; exit 3;; esac
[ -d "$D" ] || { echo "absent: $D"; exit 1; }

echo "== submodules =="
tot=$(git -C "$D" submodule status 2>/dev/null | wc -l)
init=$(git -C "$D" submodule status 2>/dev/null | grep -c '^ ' || true)
uninit=$(git -C "$D" submodule status 2>/dev/null | grep -c '^-' || true)
echo "  $tot declares, $init initialises, $uninit non initialises"

echo
echo "== venv =="
if [ ! -x "$V/bin/python" ]; then
  python3 -m venv "$V" 2>&1 | tail -3 || { echo "venv KO"; exit 2; }
fi
"$V/bin/python" -m pip --version 2>&1 | head -1 || { echo "pip KO dans le venv"; exit 2; }
"$V/bin/python" -m pip install --quiet --upgrade pip wheel 2>&1 | tail -2

echo
echo "== cmake + ninja (roues, pas apt) =="
"$V/bin/python" -m pip install --quiet cmake ninja 2>&1 | tail -4
printf '  cmake : %s\n' "$("$V/bin/cmake" --version 2>&1 | head -1)"
printf '  ninja : %s\n' "$("$V/bin/ninja" --version 2>&1 | head -1)"

echo
echo "== deps python du BUILD seulement (pas les outils d analyse) =="
# What message generation and the cmake build actually import. matplotlib, pandas and
# friends are for log analysis and are not needed to produce px4_sitl_default.
BUILD_DEPS="empy>=3.3,<4 jinja2>=2.8 jsonschema kconfiglib lark nunavut packaging pyros-genmsg toml numpy pyyaml future lxml pymavlink"
"$V/bin/python" -m pip install --quiet $BUILD_DEPS 2>&1 | tail -12

echo
echo "== verification =="
"$V/bin/python" - <<'PY'
import importlib
need = ("em", "jinja2", "jsonschema", "kconfiglib", "lark", "nunavut", "packaging",
        "pyros_genmsg", "toml", "numpy", "yaml", "future", "lxml", "pymavlink")
bad = []
for m in need:
    try:
        importlib.import_module(m)
        print("  %-13s ok" % m)
    except Exception as e:
        print("  %-13s ABSENT (%s)" % (m, type(e).__name__))
        bad.append(m)
print("manquants:", ", ".join(bad) if bad else "aucun")
PY
