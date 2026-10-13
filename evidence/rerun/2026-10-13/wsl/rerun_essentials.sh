#!/usr/bin/env bash
# rerun_essentials.sh <git-ref> — re-run inside WSL the tests behind OASIS's essential claims
# (decision gate, mesh v0B/v0C, crypto vectors, journal, revocation, authority, Modbus gateway,
# pilot campaign against the shipped binaries). Same pattern as kani_sweep.sh: the existing
# clone at $HOME/oasis-kani is moved to the ref with git fetch/checkout — no rsync, no --delete.
#
# Writes only inside $HOME/oasis-kani and $HOME/rerun-essentials.
set -u
source "$HOME/.cargo/env"

D="$HOME/oasis-kani"
OUT="$HOME/rerun-essentials"
REF="${1:?usage: rerun_essentials.sh <branch> <expected-short-sha>}"
EXPECT="${2:?usage: rerun_essentials.sh <branch> <expected-short-sha>}"
case "$D"   in "$HOME"/oasis-kani) ;;        *) echo "refus: D=$D";     exit 3;; esac
case "$OUT" in "$HOME"/rerun-essentials) ;;  *) echo "refus: OUT=$OUT"; exit 3;; esac
[ -n "$HOME" ] && [ "$HOME" != "/" ] || { echo "refus: HOME=$HOME"; exit 3; }
[ -d "$D/.git" ] || { echo "pas de clone a $D"; exit 3; }

rm -rf "$OUT"; mkdir -p "$OUT"
# A failed fetch must stop everything: the first run of this script went on after
# "couldn't find remote ref" and tested whatever commit the clone already held.
# The clone is a disposable build copy; cargo rewrites lockfiles in it, and a previous
# run's leftovers must not leak into this one.
git -C "$D" reset -q --hard
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF" || { echo "refus: fetch $REF a echoue"; exit 3; }
git -C "$D" checkout -q --detach FETCH_HEAD || { echo "refus: checkout a echoue"; exit 3; }
git -C "$D" clean -qfd -e target
GOT="$(git -C "$D" rev-parse --short=7 HEAD)"
[ "$GOT" = "$EXPECT" ] || { echo "refus: clone a $GOT, attendu $EXPECT"; exit 3; }
echo "clone a $GOT"
cd "$D"

{
  echo "commit          = $(git rev-parse HEAD)"
  echo "tracked_changes = $(git status --porcelain --untracked-files=no | wc -l)"
  echo "date_utc        = $(date -u +%FT%TZ)"
  echo "kernel          = $(uname -srm)"
  echo "distro          = $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-inconnu}")"
  echo "rustc           = $(rustc --version)"
  echo "cargo           = $(cargo --version)"
  echo "python3         = $(python3 --version 2>&1)"
  echo "cpu             = $(nproc) threads, $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
  echo "mem_mb          = $(free -m | awk '/Mem:/{print $2}')"
} > "$OUT/env.txt"

: > "$OUT/exit_codes.txt"
step() { printf '%s exit=%s\n' "$1" "$2" | tee -a "$OUT/exit_codes.txt"; }

echo "== workspace tests"
cargo test --workspace --release > "$OUT/workspace_tests.txt" 2>&1; step workspace_tests $?

echo "== lora transport, full suite"
( cd oasis-lora-transport && cargo test --release --features std ) > "$OUT/lora_tests_std.txt" 2>&1; step lora_tests_std $?

echo "== shipped binaries"
cargo build --release --workspace --bins > "$OUT/build_bins.txt" 2>&1; step build_bins $?

echo "== pilot campaign against the shipped binaries"
bash tools/pilot_campaign.sh "$OUT/pilot" > "$OUT/pilot_stdout.txt" 2>&1; step pilot_campaign $?

# What the run itself changed in tracked files (cargo may refresh a lockfile).
git status --porcelain --untracked-files=no > "$OUT/tracked_changes_after_run.txt"
echo "fini: $OUT"
