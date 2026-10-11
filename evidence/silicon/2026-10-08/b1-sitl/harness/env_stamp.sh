#!/usr/bin/env bash
# env_stamp.sh — record exactly what produced the B1 SITL evidence.
# No $ substitutions in an inline wsl.exe string: those are expanded by the Windows shell,
# which is how `git describe` once reported the OASIS commit for the PX4 tree.
set -u
PX4D="$HOME/PX4-Autopilot"
V="$HOME/px4-venv"
BIN="$HOME/oasis-kani/target/release/px4_order_arm"

echo "date_utc        = $(date -u +%FT%TZ)"
echo "kernel          = $(uname -srm)"
echo "distro          = $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-inconnu}")"
echo "ram_mb          = $(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
echo "cores           = $(nproc)"
echo
echo "px4_path        = $PX4D"
echo "px4_head        = $(git -C "$PX4D" rev-parse --short HEAD 2>&1)"
echo "px4_describe    = $(git -C "$PX4D" describe --tags --always 2>&1)"
echo "px4_submodules  = $(git -C "$PX4D" submodule status 2>/dev/null | wc -l) declares"
echo "px4_binary      = $(stat -c '%s octets, %y' "$PX4D/build/px4_sitl_default/bin/px4" 2>&1)"
echo "px4_airframe    = 10040_sihsim_quadx (SIH: physique dans PX4, ni Java ni Gazebo)"
echo
echo "cmake           = $("$V/bin/cmake" --version 2>&1 | head -1)"
echo "ninja           = $("$V/bin/ninja" --version 2>&1)"
echo "python          = $("$V/bin/python" --version 2>&1)"
echo "pip             = $("$V/bin/python" -m pip --version 2>&1 | cut -d' ' -f1-2)"
echo "sudo_utilise    = non (venv + roues pip, aucun apt)"
echo
echo "oasis_bin       = $BIN"
echo "oasis_bin_size  = $(stat -c %s "$BIN" 2>&1) octets"
echo "oasis_commit    = $(git -C "$HOME/oasis-kani" rev-parse --short HEAD 2>&1)"
echo "rustc           = $(. "$HOME/.cargo/env" 2>/dev/null; rustc --version 2>&1)"
