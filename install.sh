#!/usr/bin/env bash
# install.sh - set up the CAEN HV supply + DT5730S digitizer environment on Debian/Ubuntu.
#
# Based on BrunoGelli/DAQ_Caen and BrunoGelli/caen-dt5533e-monitor (see README.md).
# Safe to re-run. Use --dry-run to print what would be done without changing anything.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAQ_DIR="$REPO_DIR/DAQ_Caen"
HV_DIR="$REPO_DIR/caen-dt5471p-monitor"
ROOT_VERSION="${ROOT_VERSION:-6.32.04}"
ROOT_PREFIX="${ROOT_PREFIX:-$HOME/root}"      # must end in /root (the ROOT tarball unpacks to a folder named root)
INFLUX_DB="${INFLUX_DB:-NOvA_DTG_CAEN}"

CAEN_DIR="$REPO_DIR/docker/caen"              # folder with your CAEN files (see docker/caen/README.md)
DRY=0; SKIP_DB=0; INSTALL_ROOT=0; BUILD_ONLY=0; DO_UDEV=ask

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run               print the commands instead of running them
  --skip-influx-grafana   do not install InfluxDB v1 / Grafana (you already have them)
  --install-root          download ROOT automatically (Ubuntu 22.04 / 24.04 only)
  --udev | --no-udev      create / skip the udev rule for the HV supply (default: ask)
  --caen-dir DIR          folder with your CAEN files: caen-installed.tgz and/or the original
                          CAEN packages (default: docker/caen). They are installed system-wide.
  --build-only            only compile the DAQ programs and write lab-env.sh
                          (use after installing the CAEN libraries or ROOT by hand)
  -h, --help              show this help
EOF
}

while (( $# )); do
  case "$1" in
    --dry-run) DRY=1 ;;
    --skip-influx-grafana) SKIP_DB=1 ;;
    --install-root) INSTALL_ROOT=1 ;;
    --udev) DO_UDEV=yes ;;
    --no-udev) DO_UDEV=no ;;
    --build-only) BUILD_ONLY=1 ;;
    --caen-dir) [[ $# -ge 2 ]] || { echo "--caen-dir needs a folder" >&2; exit 2; }; CAEN_DIR="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }
run()  { if (( DRY )); then printf '[dry-run] %s\n' "$*"; else "$@"; fi; }

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# ---------------------------------------------------------------- OS check
ID=""; ID_LIKE=""; VERSION_ID=""
if [[ -r /etc/os-release ]]; then . /etc/os-release; fi
case "${ID}:${ID_LIKE}" in
  *debian*|*ubuntu*) ;;
  *)
    if (( DRY )); then warn "not Debian/Ubuntu (detected '${ID:-unknown}'); continuing because of --dry-run"
    else die "this installer supports Debian/Ubuntu only (detected '${ID:-unknown}'). See DAQ_Caen/SETUP.md for the manual steps."; fi ;;
esac

# ---------------------------------------------------------------- submodules
if [[ ! -f "$DAQ_DIR/daq_threshold_v1.0.0.cpp" || ! -f "$HV_DIR/caen_shell_v3.py" || ! -f "$REPO_DIR/tmuxsessions/start_hvcaen.sh" ]]; then
  say "Fetching the three repositories (git submodules)"
  run git -C "$REPO_DIR" submodule update --init --recursive
fi

ROOT_SETUP=""

if (( ! BUILD_ONLY )); then
  # -------------------------------------------------------------- apt packages
  say "Installing system packages"
  PKGS=(tmux git g++ curl gnupg usbutils unzip
        python3 python3-venv python3-pip python3-tk python3-numpy python3-matplotlib
        libcurl4-openssl-dev libssl-dev libx11-dev libxpm-dev libxft-dev libxext-dev
        build-essential libusb-1.0-0-dev)
  run $SUDO apt-get update
  run $SUDO apt-get install -y "${PKGS[@]}"

  # -------------------------------------------------------------- HV monitor venv
  say "Python environment for the HV monitor"
  run python3 -m venv "$HV_DIR/.venv"
  run "$HV_DIR/.venv/bin/pip" install -r "$HV_DIR/requirements.txt"

  # -------------------------------------------------------------- InfluxDB v1 + Grafana
  if (( ! SKIP_DB )); then
    say "Installing InfluxDB v1 and Grafana"
    run $SUDO mkdir -p /etc/apt/keyrings
    run bash -c "curl -fsSL https://repos.influxdata.com/influxdata-archive.key | gpg --dearmor | $SUDO tee /etc/apt/keyrings/influxdata-archive.gpg >/dev/null"
    run bash -c "echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' | $SUDO tee /etc/apt/sources.list.d/influxdata.list >/dev/null"
    run bash -c "curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor | $SUDO tee /etc/apt/keyrings/grafana.gpg >/dev/null"
    run bash -c "echo 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main' | $SUDO tee /etc/apt/sources.list.d/grafana.list >/dev/null"
    run $SUDO apt-get update
    run $SUDO apt-get install -y influxdb grafana
    run $SUDO systemctl enable --now influxdb grafana-server || warn "could not start services with systemctl; start influxdb and grafana-server manually"
    if (( DRY )); then
      echo "[dry-run] influx -execute 'CREATE DATABASE \"$INFLUX_DB\"'"
    else
      created=0
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        if influx -execute "CREATE DATABASE \"$INFLUX_DB\"" 2>/dev/null; then created=1; break; fi
        sleep 2
      done
      (( created )) || warn "could not create database '$INFLUX_DB'; once InfluxDB is running: influx -execute 'CREATE DATABASE $INFLUX_DB'"
    fi
  fi
fi

# ---------------------------------------------------------------- ROOT
find_root_setup() {
  local f
  for f in "$ROOT_PREFIX/bin/thisroot.sh" /usr/local/bin/thisroot.sh /usr/bin/thisroot.sh; do
    if [[ -f "$f" ]]; then echo "$f"; return 0; fi
  done
  return 1
}

install_root() {
  local flavor=""
  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]]; then flavor="ubuntu22.04-x86_64-gcc11.4"
  elif [[ "$ID" == "ubuntu" && "$VERSION_ID" == "24.04" ]]; then flavor="ubuntu24.04-x86_64-gcc13.2"
  else
    warn "automatic ROOT download is only supported on Ubuntu 22.04 / 24.04 (this is '${ID} ${VERSION_ID}')."
    warn "Install ROOT from https://root.cern/install/ into $ROOT_PREFIX, then run: ./install.sh --build-only"
    return 1
  fi
  [[ "$(basename "$ROOT_PREFIX")" == "root" ]] || { warn "ROOT_PREFIX must end in /root"; return 1; }
  local url="https://root.cern/download/root_v${ROOT_VERSION}.Linux-${flavor}.tar.gz"
  say "Downloading ROOT ${ROOT_VERSION} (large download)"
  run mkdir -p "$(dirname "$ROOT_PREFIX")"
  run bash -c "curl -fL '$url' | tar -xz -C '$(dirname "$ROOT_PREFIX")'"
}

say "ROOT"
if ROOT_SETUP="$(find_root_setup)"; then
  echo "found: $ROOT_SETUP"
elif command -v root-config >/dev/null 2>&1; then
  ROOT_SETUP="/dev/null"      # ROOT is already on PATH; nothing to source
  echo "found: root-config on PATH"
elif (( INSTALL_ROOT )) && install_root; then
  ROOT_SETUP="$ROOT_PREFIX/bin/thisroot.sh"
else
  ROOT_SETUP=""
  warn "ROOT not found. Install it from https://root.cern/install/ into $ROOT_PREFIX (or re-run with --install-root on Ubuntu 22.04/24.04), then run: ./install.sh --build-only"
fi

# ---------------------------------------------------------------- CAEN libraries
have_caen() {
  [[ -f /usr/include/CAENDigitizer.h || -f /usr/local/include/CAENDigitizer.h ]] \
    && ldconfig -p 2>/dev/null | grep -q CAENDigitizer
}

caen_files_present() {
  compgen -G "$CAEN_DIR/*.tgz" >/dev/null || compgen -G "$CAEN_DIR/*.tar.gz" >/dev/null || \
  compgen -G "$CAEN_DIR/*.tar.xz" >/dev/null || compgen -G "$CAEN_DIR/*.tar.bz2" >/dev/null || \
  compgen -G "$CAEN_DIR/*.zip" >/dev/null
}

say "CAEN libraries"
CAEN_OK=0
if have_caen; then
  CAEN_OK=1; echo "found: CAENDigitizer"
elif caen_files_present; then
  echo "installing the CAEN libraries from $CAEN_DIR (system-wide, needs sudo)"
  run $SUDO bash "$REPO_DIR/docker/install-caen.sh" "$CAEN_DIR"
  if (( DRY )) || have_caen; then CAEN_OK=1; else warn "the CAEN libraries are still not registered after the install"; fi
else
  warn "CAENDigitizer library not found, and no CAEN files in $CAEN_DIR."
  warn "Put your CAEN files there (caen-installed.tgz from a working machine, or the original CAENVME / CAENComm / CAENDigitizer packages;"
  warn "see docker/caen/README.md and DAQ_Caen/SETUP.md, section 2), then run: ./install.sh --build-only"
fi

# ---------------------------------------------------------------- build
say "Building the DAQ programs"
if [[ -n "$ROOT_SETUP" && ( $CAEN_OK -eq 1 || $DRY -eq 1 ) ]]; then
  run bash -c 'set +u; source "$1"; cd "$2" &&
    g++ -O2 -std=c++17 daq_threshold_v1.0.0.cpp -o daq_threshold_v1.0.0 $(root-config --cflags --libs) -lCAENDigitizer &&
    g++ -O2 -std=c++17 utils/read_temp_influx.cpp -o utils/read_temp_influx -lCAENDigitizer -lcurl' _ "$ROOT_SETUP" "$DAQ_DIR"
else
  warn "skipping the build (needs both ROOT and the CAEN libraries)"
fi
run mkdir -p "$DAQ_DIR/data" "$DAQ_DIR/logs"

# ---------------------------------------------------------------- environment file used by bin/ wrappers
emit_env() {
  cat <<EOF
# generated by install.sh - read by bin/hv-session, bin/daq-session and bin/scope
export DAQ_DIR="$DAQ_DIR"
export HV_DIR="$HV_DIR"
export ROOT_SETUP="${ROOT_SETUP:-\$HOME/root/bin/thisroot.sh}"
export DAQ_DATA_DIR="$DAQ_DIR/data"
export INFLUX_DB="\${INFLUX_DB:-$INFLUX_DB}"
EOF
}
say "Writing lab-env.sh"
if (( DRY )); then emit_env | sed 's/^/[dry-run]   /'; else emit_env > "$REPO_DIR/lab-env.sh"; fi
run chmod +x "$REPO_DIR"/bin/* "$REPO_DIR"/tmuxsessions/*.sh

# ---------------------------------------------------------------- serial access and udev rule
if (( ! BUILD_ONLY )); then
  say "Serial port access"
  run $SUDO usermod -aG dialout "$TARGET_USER"
  echo "(log out and back in for the group change to take effect)"

  setup_udev() {
    command -v lsusb >/dev/null 2>&1 || { warn "lsusb not available; skipping udev rule"; return; }
    echo "Plug in the HV supply and press Enter."; read -r _
    lsusb
    local id=""
    read -rp "Enter the supply's USB ID (vendor:product, e.g. 21e1:0006): " id
    [[ "$id" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]] || { warn "not a valid ID; skipping udev rule"; return; }
    local rule="SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"${id%%:*}\", ATTRS{idProduct}==\"${id##*:}\", SYMLINK+=\"ttyDT5471P0\", MODE=\"0666\", ENV{ID_MM_DEVICE_IGNORE}=\"1\""
    echo "$rule" | $SUDO tee /etc/udev/rules.d/99-caen.rules >/dev/null
    $SUDO udevadm control --reload-rules && $SUDO udevadm trigger
    echo "Unplug and replug the supply, then check: ls -l /dev/ttyDT5471P0"
  }

  say "udev rule for the HV supply (/dev/ttyDT5471P0)"
  case "$DO_UDEV" in
    yes) if (( DRY )); then echo "[dry-run] would ask for the supply's USB ID and write /etc/udev/rules.d/99-caen.rules"; else setup_udev; fi ;;
    no)  echo "skipped" ;;
    *)
      if (( DRY )); then echo "[dry-run] would ask whether to create the udev rule"
      elif [[ -t 0 ]]; then
        read -rp "Create the udev rule now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy] ]]; then setup_udev; else echo "skipped (see DAQ_Caen/SETUP.md, section 6)"; fi
      else
        echo "non-interactive: skipped (see DAQ_Caen/SETUP.md, section 6)"
      fi ;;
  esac
fi

say "Done"
cat <<EOF
Start the HV session:        $REPO_DIR/bin/hv-session
Start the digitizer session: $REPO_DIR/bin/daq-session
Live waveform viewer:        $REPO_DIR/bin/scope

Grafana: http://localhost:3000  (add an InfluxDB data source: http://localhost:8086, database $INFLUX_DB)
Operating instructions: DAQ_Caen/SETUP.md, section 8.
EOF
