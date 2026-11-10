#!/usr/bin/env bash
# Install the CAEN libraries from archives the user placed in docker/caen/.
# Order: CAENVMELib, CAENComm, CAENDigitizer (the versions used in the lab: 4.1.3, 1.8.0, 2.19.0).
# Each package ships an install script (install_x64) in its lib/ folder; it is run with sh.
set -euo pipefail
src="${1:-/tmp/caen}"
shopt -s nullglob
archives=("$src"/*.tgz "$src"/*.tar.gz "$src"/*.tar.xz "$src"/*.tar.bz2 "$src"/*.zip)
if (( ${#archives[@]} == 0 )); then
  echo "[install-caen] no archives in $src; skipping (the image will not contain the CAEN libraries)"
  exit 0
fi
work="$(mktemp -d)"
for a in "${archives[@]}"; do
  echo "[install-caen] unpacking $(basename "$a")"
  case "$a" in *.zip) unzip -q "$a" -d "$work" ;; *) tar -xf "$a" -C "$work" ;; esac
done
for name in CAENVMELib CAENComm CAENDigitizer; do
  pkg="$(find "$work" -maxdepth 3 -type d -iname "${name}*" | sort | head -1 || true)"
  if [[ -z "$pkg" ]]; then echo "[install-caen] no $name package found; skipping it"; continue; fi
  script="$(find "$pkg" -maxdepth 2 -type f \( -name install_64 -o -name install_x64 -o -name install.sh -o -name install \) | sort | head -1 || true)"
  if [[ -z "$script" ]]; then
    echo "[install-caen] ERROR: no install script found in $pkg:" >&2; ls -la "$pkg" >&2; exit 1
  fi
  echo "[install-caen] installing $name with $script"
  ( cd "$(dirname "$script")" && sh "./$(basename "$script")" )
done
ldconfig
if ! ldconfig -p | grep -q CAENDigitizer; then
  echo "[install-caen] ERROR: libCAENDigitizer is not registered after the install (check the packages in docker/caen/)" >&2; exit 1
fi
rm -rf "${work:?}"
echo "[install-caen] done"
