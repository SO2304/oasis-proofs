#!/usr/bin/env bash
# px4_bootstrap2.sh — bootstrap pip into the venv with get-pip.py (ensurepip is in a
# separate apt package on Ubuntu), then cmake, ninja and the build-time python deps.
# No sudo, no apt. Writes only inside $HOME/px4-venv and $HOME/px4-dl.
set -u
V="$HOME/px4-venv"
DL="$HOME/px4-dl"
case "$V"  in "$HOME"/*) ;; *) echo "refus: V=$V";   exit 3;; esac
case "$DL" in "$HOME"/*) ;; *) echo "refus: DL=$DL"; exit 3;; esac
mkdir -p "$DL"

echo "== amorcage de pip =="
if ! "$V/bin/python" -m pip --version >/dev/null 2>&1; then
  if [ ! -s "$DL/get-pip.py" ]; then
    curl -fsSL -A oasis-research-script -o "$DL/get-pip.py" \
      https://bootstrap.pypa.io/get-pip.py || { echo "telechargement get-pip KO"; exit 2; }
  fi
  echo "  get-pip.py : $(wc -c < "$DL/get-pip.py") octets"
  "$V/bin/python" "$DL/get-pip.py" --quiet 2>&1 | tail -5
fi
"$V/bin/python" -m pip --version 2>&1 | head -1 || { echo "pip toujours absent"; exit 2; }

echo
echo "== cmake + ninja =="
"$V/bin/python" -m pip install --quiet cmake ninja 2>&1 | tail -5
printf '  cmake : %s\n' "$("$V/bin/cmake" --version 2>&1 | head -1)"
printf '  ninja : %s\n' "$("$V/bin/ninja" --version 2>&1 | head -1)"

echo
echo "== deps python du build, une par une pour voir qui casse =="
for d in "empy>=3.3,<4" "jinja2>=2.8" jsonschema kconfiglib lark nunavut packaging \
         pyros-genmsg toml numpy pyyaml future lxml pymavlink; do
  if "$V/bin/python" -m pip install --quiet "$d" >/dev/null 2>&1; then
    printf '  %-22s ok\n' "$d"
  else
    printf '  %-22s ECHEC\n' "$d"
  fi
done

echo
echo "== verification des imports =="
"$V/bin/python" - <<'PY'
import importlib
need = ("em", "jinja2", "jsonschema", "kconfiglib", "lark", "nunavut", "packaging",
        "pyros_genmsg", "toml", "numpy", "yaml", "future", "lxml", "pymavlink")
bad = [m for m in need if not _import(m)] if False else []
for m in need:
    try:
        importlib.import_module(m); print("  %-13s ok" % m)
    except Exception as e:
        print("  %-13s ABSENT (%s)" % (m, type(e).__name__)); bad.append(m)
print("manquants:", ", ".join(bad) if bad else "aucun")
PY
