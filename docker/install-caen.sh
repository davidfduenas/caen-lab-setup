#!/usr/bin/env bash
# Install the CAEN libraries into the image from files the user placed in docker/caen/.
#
# Two ways to supply them (both can be present):
#   A. The original CAEN packages (.tgz, .tar.gz, .tar.xz, .zip). Installed in the order CAENVMELib, CAENComm,
#      CAENDigitizer (lab versions: 4.1.3, 1.8.0, 2.19.0) by running the package's install_x64 script
#      (in its lib/ folder) with sh.
#   B. A tarball named caen-installed*.tgz holding the files already installed on a working machine
#      (see docker/caen/README.md). It is extracted to / inside the image.
set -euo pipefail
src="${1:-/tmp/caen}"
shopt -s nullglob

installed=("$src"/caen-installed*.tgz "$src"/caen-installed*.tar.gz)
all=("$src"/*.tgz "$src"/*.tar.gz "$src"/*.tar.xz "$src"/*.tar.bz2 "$src"/*.zip)
packages=()
for a in "${all[@]}"; do
  case "$(basename "$a")" in caen-installed*) ;; *) packages+=("$a") ;; esac
done

if (( ${#installed[@]} == 0 && ${#packages[@]} == 0 )); then
  echo "[install-caen] nothing in $src; skipping (the image will not contain the CAEN libraries)"
  exit 0
fi

# ---- B. files from a working machine
for a in "${installed[@]}"; do
  echo "[install-caen] extracting installed files from $(basename "$a")"
  tar -xzf "$a" -C /
done

# ---- A. original packages
if (( ${#packages[@]} > 0 )); then
  work="$(mktemp -d)"
  for a in "${packages[@]}"; do
    echo "[install-caen] unpacking $(basename "$a")"
    case "$a" in *.zip) unzip -q "$a" -d "$work" ;; *) tar -xf "$a" -C "$work" ;; esac
  done
  for name in CAENVMELib CAENComm CAENDigitizer; do
    pkg="$(find "$work" -maxdepth 2 -type d -iname "${name}*" | sort | head -1 || true)"
    if [[ -z "$pkg" ]]; then echo "[install-caen] no $name package found; skipping it"; continue; fi
    script="$(find "$pkg" -maxdepth 2 -type f \( -name install_x64 -o -name install_64 -o -name install.sh -o -name install \) | sort | head -1 || true)"
    if [[ -z "$script" ]]; then
      echo "[install-caen] ERROR: no install script found in $pkg:" >&2; ls -la "$pkg" >&2; exit 1
    fi
    echo "[install-caen] installing $name with $script"
    ( cd "$(dirname "$script")" && sh "./$(basename "$script")" )
  done
  rm -rf "${work:?}"
fi

ldconfig
if ! ldconfig -p | grep -q CAENDigitizer; then
  echo "[install-caen] ERROR: libCAENDigitizer is not registered after the install (check the files in docker/caen/)" >&2
  exit 1
fi
if [[ ! -f /usr/include/CAENDigitizer.h && ! -f /usr/local/include/CAENDigitizer.h ]]; then
  echo "[install-caen] ERROR: CAENDigitizer.h was not installed; the DAQ cannot be compiled" >&2
  exit 1
fi
echo "[install-caen] done"
