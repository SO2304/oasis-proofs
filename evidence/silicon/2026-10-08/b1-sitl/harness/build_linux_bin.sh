#!/usr/bin/env bash
# build_linux_bin.sh — build px4_order_arm for Linux inside WSL, from the existing clone
# at $HOME/oasis-kani. Writes only inside that clone. No rsync, no --delete.
set -euo pipefail
source "$HOME/.cargo/env"

D="$HOME/oasis-kani"
REF="${1:?usage: build_linux_bin.sh <git-ref>}"
case "$D" in "$HOME"/*) ;; *) echo "refus: D=$D"; exit 3;; esac
[ -d "$D/.git" ] || { echo "pas de clone a $D"; exit 3; }

git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
echo "clone a $(git -C "$D" rev-parse --short HEAD)"

cd "$D"
cargo build --release -p oasis-rt --bin px4_order_arm 2>&1 | tail -5
ls -l "$D/target/release/px4_order_arm"
