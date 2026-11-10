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

1. Clone the repository. The CAEN libraries are included (`docker/caen/caen-installed.tgz`).
2. Run the installer:
```bash
git clone --recursive https://github.com/davidfduenas/caen-lab-setup.git
cd caen-lab-setup
./install.sh
```
For Docker instead, see "Run everything in Docker" below.

`./install.sh --dry-run` prints every command without running anything. Other options: `--install-root`, `--skip-influx-grafana`, `--udev`, `--no-udev`, `--build-only` (see `./install.sh --help`).

## What the installer does

1. Installs system packages (`tmux`, `g++`, python3 with tk/numpy/matplotlib, libcurl, X11 dev libraries).
2. Creates the HV monitor's Python environment and installs its requirements (`influxdb`, `pyserial`, `pyusb`).
3. Installs InfluxDB v1 and Grafana from their apt repositories, starts them and creates the database `NOvA_DTG_CAEN`.
4. Finds ROOT. With `--install-root` it downloads ROOT 6.32.04 on Ubuntu 22.04 or 24.04.
5. Installs the CAEN libraries system-wide from `docker/caen/` (or `--caen-dir`), unless they are already installed.
6. Compiles `daq_threshold_v1.0.0` and `read_temp_influx`.
7. Adds you to the `dialout` group and, if you agree, creates the udev rule that names the HV supply `/dev/ttyDT5471P0`.
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

## Run everything in Docker

> **Status:** the Docker setup has been tested, apart from one thing. The software side works: the image builds, the CAEN libraries install, the DAQ programs compile, and InfluxDB, Grafana and the tmux sessions start. What we do **not** know yet is whether **USB access from Docker** to the real digitizer and HV supply works. That needs the devices on a native Linux machine, and it is the only open worry. If USB does not work from the container, use the native install (`./install.sh`), which does not depend on it.

The whole setup (InfluxDB, Grafana, and a container with ROOT, the CAEN libraries, the DAQ programs and the HV tools) can run in Docker. In short:

1. The CAEN libraries are included (`docker/caen/caen-installed.tgz`; see [docker/caen/NOTICE.md](docker/caen/NOTICE.md)).
2. `docker compose build`, then `docker compose -f docker-compose.yml -f docker-compose.hardware.yml up -d`.
3. Open one terminal per tool: `docker compose exec daq hv-session` in one, `docker compose exec daq daq-session` in another, and (optionally) `docker compose exec daq scope` in a third. It is a single container; you open several terminals into it.

Details, requirements and testing status: [DOCKER.md](DOCKER.md).

## Testing status

Tested, with the lab's real CAEN libraries (VME v4.1.3, Comm v1.8.0, Digitizer v2.19.0), in clean x86-64 Ubuntu 24.04 containers on an ARM Mac (emulated):
- **`install.sh` (native):** system packages, the HV monitor's Python environment, the ROOT 6.32.04 download (`--install-root`), the system-wide CAEN install from `docker/caen/caen-installed.tgz`, and compiling `daq_threshold_v1.0.0` and `read_temp_influx`. Afterwards the libraries are registered, `lab-env.sh` is written, the DAQ prints its usage, and without a device it fails cleanly when opening the digitizer. The InfluxDB and Grafana apt installation was tested earlier (on ARM Ubuntu 24.04; `systemctl` does not exist in containers, so starting the services was not tested).
- **Docker:** a fresh `git clone --recursive` followed by `docker compose build` and `docker compose up -d`: the CAEN libraries install, both DAQ programs compile and run, InfluxDB creates the database, Grafana has the data source, and both tmux sessions start with three panes.

Not tested:
- Anything with the real devices attached, including USB access from Docker.
- The udev step of `install.sh`, and the `scope` viewer through X11 from Docker.
- An optional alternative route: installing from the official CAEN packages downloaded from CAEN's website, instead of the included `caen-installed.tgz`. We do not have those packages, so that route was only tested with stand-in files. The standard setup uses the included tarball, which holds the real libraries from the lab machine, and that is fully tested.

> **Warning:** these instructions and `install.sh` were generated by Claude (an AI assistant made by Anthropic). They have not been tested on every system. Review each step, especially commands that use `sudo`, before running it.
