# Install directly on the computer (Debian/Ubuntu)

This guide installs everything directly on your computer with a script (`install.sh`). It does not use Docker. (For Docker, see [DOCKER.md](DOCKER.md); the two guides are independent.)

## Quick start

Open a terminal and run these three commands:

```bash
git clone --recursive https://github.com/davidfduenas/caen-lab-setup.git
cd caen-lab-setup
./install.sh
```

The CAEN libraries are included in the repository, so there is nothing else to download. The installer asks for your password (it uses `sudo`) and may ask whether to create the udev rule for the HV supply.

### Installer options (optional)

You normally run `./install.sh` with no options. To change what it does, add one of these after it, for example `./install.sh --dry-run`:

| Option | What it does |
|---|---|
| `--dry-run` | Prints everything the installer would do, without doing any of it. A safe preview. |
| `--install-root` | Also downloads ROOT (a large download; Ubuntu 22.04 and 24.04 only). |
| `--skip-influx-grafana` | Does not install InfluxDB and Grafana, for when you already have them. |
| `--udev` or `--no-udev` | Creates, or skips, the rule that gives the HV supply its fixed name. Without either option, the installer asks you. |
| `--build-only` | Only compiles the DAQ programs and writes the settings file. |
| `--caen-dir FOLDER` | Reads the CAEN files from another folder instead of `docker/caen`. |

`./install.sh --help` shows the same list.

## What the installer does

1. Installs system packages (`tmux`, `g++`, python3 with tk/numpy/matplotlib, libcurl, X11 dev libraries).
2. Creates the HV monitor's Python environment and installs its requirements (`influxdb`, `pyserial`, `pyusb`).
3. Installs InfluxDB v1 and Grafana from their apt repositories, starts them and creates the database `NOvA_DTG_CAEN`.
4. Finds ROOT. With `--install-root` it downloads ROOT 6.32.04 on Ubuntu 22.04 or 24.04.
5. Installs the CAEN libraries system-wide from `docker/caen/` (or `--caen-dir`), unless they are already installed.
6. Compiles `daq_threshold_v1.0.0` and `read_temp_influx`.
7. Adds you to the `dialout` group and, if you agree, creates the udev rule that names the HV supply `/dev/ttyDT5471P0`. For this the installer asks you to **unplug** the HV supply, press Enter, then **plug it in** and press Enter again. It compares the USB devices before and after, and proposes the new device's ID (`vendor:product`, for example `21e1:0006`); you confirm with Enter. If it cannot tell, it shows the USB device list and asks you to type the supply's ID, or you press Enter to skip. You can run this step later with `./install.sh --udev`.
8. Writes `lab-env.sh` for the launchers in `bin/`.

## What you must do yourself

- **Nothing for the CAEN libraries in the standard case.** CAENVME v4.1.3, CAENComm v1.8.0 and CAENDigitizer v2.19.0 (the lab's versions) are included as `docker/caen/caen-installed.tgz`. They are CAEN's files; read [docker/caen/NOTICE.md](docker/caen/NOTICE.md). To use other versions, see [docker/caen/README.md](docker/caen/README.md).
- **Install ROOT yourself** on any system other than Ubuntu 22.04/24.04, from <https://root.cern/install/>.
- **Set up Grafana**: add an InfluxDB data source (`http://localhost:8086`, database `NOvA_DTG_CAEN`) and build or import dashboards.
- Adapt site-specific settings (serial device, database name, trigger thresholds). They are listed in section 1 of [DAQ_Caen/SETUP.md](https://github.com/davidfduenas/DAQ_Caen/blob/lab-setup/SETUP.md).

## Running

There is one command per device, plus a viewer. Run them from the `caen-lab-setup` folder, after `./install.sh` has finished. Each of the first two opens one terminal window split into three panes (this is tmux).

**1. HV power supply: `bin/hv-session`**

All three panes are connected to the supply. You use them for different jobs:

| Pane | What you do there |
|---|---|
| Top | type `start` to begin logging voltage and current to Grafana |
| Bottom left | set the voltage: `set vset 200`, then `on`, then ramp up in steps |
| Bottom right | set the current limit: `set iset 200` |

**2. Digitizer: `bin/daq-session`**

| Pane | What you do there |
|---|---|
| Top | nothing: the temperature monitor starts by itself |
| Bottom left and right | type the DAQ run commands (see `DAQ_Caen/SETUP.md`, section 8) |

**3. Live waveform viewer: `bin/scope`**

Open it in a separate terminal while a run is writing data. It shows the latest waveforms from the newest `.txt` file in `DAQ_Caen/data`, so it only has something to show once a run started with `--txt` is under way.

**One session per terminal.** Each of `bin/hv-session` and `bin/daq-session` fills the terminal window you start it in. To use both at once, open two terminal windows or tabs and start one in each. They are separate tmux sessions and do not interfere with each other. With one terminal, start a session, press `Ctrl-b` then `d` to leave it (it keeps running in the background), then start the other. Running a launcher again re-attaches to the existing session. The layout is one wide pane on top and two panes below it.

**Without devices attached** (for example when testing on a laptop) the panes start but cannot reach the hardware: the HV panes end with `could not open port /dev/ttyDT5471P0`, and the digitizer's temperature pane reports that it cannot open the digitizer. This is expected until the devices are connected.

Operating procedure (HV ramping, DAQ commands and options): [DAQ_Caen/SETUP.md](https://github.com/davidfduenas/DAQ_Caen/blob/lab-setup/SETUP.md), section 8. It is based on the lab's original [Operating Instructions](https://docs.google.com/document/d/1mQslpxoBDvs9HkDt69Xr__bFLzD0LlA4ytbHnuLEeo8/edit?tab=t.0) (Google Doc, may require access).

## Updating

```bash
git pull
git submodule update --init --recursive
```

## Testing status

Tested with the lab's real CAEN libraries (CAENVME v4.1.3, CAENComm v1.8.0, CAENDigitizer v2.19.0) in a clean x86-64 Ubuntu 24.04 container on an ARM Mac (emulated):
- `install.sh`: system packages, the HV monitor's Python environment, the ROOT 6.32.04 download (`--install-root`), the system-wide CAEN install from `docker/caen/caen-installed.tgz`, and compiling `daq_threshold_v1.0.0` and `read_temp_influx`.
- Afterwards the libraries are registered, `lab-env.sh` is written, the DAQ prints its usage, and without a device it fails cleanly when opening the digitizer.
- The InfluxDB and Grafana apt installation was tested earlier (on ARM Ubuntu 24.04). A container has no `systemctl`, so starting those services was not tested.
- Both tmux sessions start with three panes (tmux 3.4).

Not tested:
- Anything with the real devices attached.
- The udev step of `install.sh`.
- An optional alternative: installing from the official CAEN packages downloaded from CAEN's website, instead of the included `caen-installed.tgz`. We do not have those packages, so that route was only tested with stand-in files. The standard setup uses the included tarball, which holds the real libraries from the lab machine, and that is fully tested.

## Credit

The DAQ code, utilities and HV monitor were written by **Bruno P. Gelli** ([DAQ_Caen](https://github.com/BrunoGelli/DAQ_Caen), [caen-dt5533e-monitor](https://github.com/BrunoGelli/caen-dt5533e-monitor)). Please credit the original repositories when using this work.

> **Warning:** these instructions and `install.sh` were generated by Claude (an AI assistant made by Anthropic). They have not been tested on every system. Review each step, especially commands that use `sudo`, before running it.
