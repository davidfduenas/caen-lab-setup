# caen-lab-setup

One place to install and run a CAEN HV power supply (DT5471P) and a CAEN DT5730S digitizer. There are two ways to use it: a native install on Debian/Ubuntu (`install.sh`), or Docker. Both need the CAEN libraries, which you get from CAEN. It bundles three repositories as git submodules:

| Submodule | Fork of | Purpose |
|---|---|---|
| [DAQ_Caen](https://github.com/davidfduenas/DAQ_Caen) | [BrunoGelli/DAQ_Caen](https://github.com/BrunoGelli/DAQ_Caen) | Digitizer DAQ, temperature monitor, waveform viewer |
| [caen-dt5471p-monitor](https://github.com/davidfduenas/caen-dt5471p-monitor) | [BrunoGelli/caen-dt5533e-monitor](https://github.com/BrunoGelli/caen-dt5533e-monitor) | HV supply control and InfluxDB logging |
| [tmuxsessions](https://github.com/davidfduenas/tmuxsessions) | none (original) | tmux startup scripts for both |

## Credit

The DAQ code, utilities and HV monitor were written by **Bruno P. Gelli**. The DAQ and monitor repos here are forks of his, with small lab-specific changes on the `lab-setup` branches. Please credit his original repositories when using or citing this work.

## Quick start (native install)

1. Clone, then put your CAEN files in `docker/caen/` (see "What you must do yourself" below).
2. Run the installer:
```bash
git clone --recursive https://github.com/davidfduenas/caen-lab-setup.git
cd caen-lab-setup
# put your CAEN files in docker/caen/
./install.sh
```
For Docker instead, see "Run everything in Docker" below.

`./install.sh --dry-run` prints every command without running anything. Other options: `--install-root`, `--skip-influx-grafana`, `--udev`, `--no-udev`, `--build-only` (see `./install.sh --help`).

## What the installer does

1. Installs system packages (`tmux`, `g++`, python3 with tk/numpy/matplotlib, libcurl, X11 dev libraries).
2. Creates the HV monitor's Python environment and installs its requirements (`influxdb`, `pyserial`, `pyusb`).
3. Installs InfluxDB v1 and Grafana from their apt repositories, starts them and creates the database `NOvA_DTG_CAEN`.
4. Finds ROOT. With `--install-root` it downloads ROOT 6.32.04 on Ubuntu 22.04 or 24.04.
5. Installs the CAEN libraries system-wide from the files in `docker/caen/` (or `--caen-dir`), unless they are already installed.
6. Compiles `daq_threshold_v1.0.0` and `read_temp_influx`.
7. Adds you to the `dialout` group and, if you agree, creates the udev rule that names the HV supply `/dev/ttyDT5471P0`.
8. Writes `lab-env.sh` for the launchers in `bin/`.

## What you must do yourself

- **Provide the CAEN libraries.** They are CAEN's files and are not in this repository. Put them in `docker/caen/` (git ignores that folder): either `caen-installed.tgz` made on a machine where they work (`tar -czf ~/caen-installed.tgz /usr/lib/libCAEN* /usr/include/CAEN*`), or the original CAENVME, CAENComm and CAENDigitizer packages from CAEN's website. The lab uses CAENVME v4.1.3, CAENComm v1.8.0 and CAENDigitizer v2.19.0; see [DAQ_Caen/SETUP.md](https://github.com/davidfduenas/DAQ_Caen/blob/lab-setup/SETUP.md), section 2. If the libraries are already installed on the machine, `install.sh` detects them and this is not needed.
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

To leave a tmux window without stopping it, press `Ctrl-b`, then `d`.

Operating procedure (HV ramping, DAQ commands and options): [DAQ_Caen/SETUP.md](https://github.com/davidfduenas/DAQ_Caen/blob/lab-setup/SETUP.md), section 8. It is based on the lab's original [Operating Instructions](https://docs.google.com/document/d/1mQslpxoBDvs9HkDt69Xr__bFLzD0LlA4ytbHnuLEeo8/edit?tab=t.0) (Google Doc, may require access).

## Updating

```bash
git pull
git submodule update --init --recursive
```

## Run everything in Docker

The whole setup (InfluxDB, Grafana, and a container with ROOT, the CAEN libraries, the DAQ programs and the HV tools) can run in Docker. In short:

1. On the machine where the CAEN libraries are installed, pack them: `tar -czf ~/caen-installed.tgz /usr/lib/libCAEN* /usr/include/CAEN*`.
2. Put `caen-installed.tgz` in `docker/caen/` (git ignores it; do not publish it).
3. `docker compose build`, then `docker compose -f docker-compose.yml -f docker-compose.hardware.yml up -d`.
4. `docker compose exec daq hv-session` (or `daq-session`, or `scope`).

Details, requirements and testing status: [DOCKER.md](DOCKER.md).

## Testing status

Tested (clean Ubuntu 24.04 container, and Docker on an ARM Mac with emulated x86-64 images):
- `install.sh`: the package, Python environment and InfluxDB/Grafana steps.
- Docker: the image builds with the lab's real CAEN libraries (VME v4.1.3, Comm v1.8.0, Digitizer v2.19.0), and both DAQ programs compile and run. Without hardware, the DAQ fails cleanly when it tries to open the digitizer. InfluxDB, Grafana and the data source also work.

Not tested:
- `install.sh`: the ROOT download, the DAQ compilation, the udev step.
- Any operation with the real devices attached, including USB access from Docker.

> **Warning:** these instructions and `install.sh` were generated by Claude (an AI assistant made by Anthropic). They have not been tested on every system. Review each step, especially commands that use `sudo`, before running it.
