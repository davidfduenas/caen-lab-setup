# Running everything in Docker

Docker Compose starts three containers:

| Service | What it is |
|---|---|
| `influxdb` | InfluxDB 1.8, database `NOvA_DTG_CAEN` created automatically |
| `grafana` | Grafana, with the InfluxDB data source already configured |
| `daq` | ROOT, the CAEN libraries, the compiled DAQ programs, the HV monitor, tmux and the launchers |

## Requirements

- A **Linux x86-64** machine with Docker and Docker Compose, for real hardware. The CAEN libraries and the ROOT base image are x86-64 only. On macOS, Windows or ARM you can build and test the software side, but USB devices cannot be passed through in the usual way.
- The **CAEN libraries** (CAENVME v4.1.3, CAENComm v1.8.0, CAENDigitizer v2.19.0) are included in the repository as `docker/caen/caen-installed.tgz`. They are CAEN's files: read [docker/caen/NOTICE.md](docker/caen/NOTICE.md). To use other versions, see [docker/caen/README.md](docker/caen/README.md).
- On the host, the udev rule that names the HV supply `/dev/ttyDT5471P0` (see `DAQ_Caen/SETUP.md`, section 6). The overlay in step 3 fails to start without it.

## Steps

**1. Clone and build.**
```bash
git clone --recursive https://github.com/davidfduenas/caen-lab-setup.git
cd caen-lab-setup
docker compose build
```
The first build downloads the ROOT base image (a few GB), so allow some minutes. The build installs the CAEN libraries from `docker/caen/caen-installed.tgz`, compiles `daq_threshold_v1.0.0` and `read_temp_influx`, and sets up the HV monitor's Python environment. It stops with an error if the Digitizer library or its header is not installed afterwards, or if `docker/caen/` has no CAEN files (for example if the tarball was deleted).

To build a software-only image without the CAEN libraries (for example to test InfluxDB and Grafana only), use `ALLOW_NO_CAEN=1 docker compose build`. That image has no DAQ programs, and the file `/opt/lab/NO_CAEN_LIBRARIES` exists in the container.

**2. Plug in the devices and name the HV supply** (host udev rule, see above).

**3. Start.**
```bash
docker compose -f docker-compose.yml -f docker-compose.hardware.yml up -d
```
The overlay passes the USB bus, the HV serial port and your display into the `daq` container. Without hardware (to test only the software), use `docker compose up -d`.

**4. Use.**
```bash
docker compose exec daq hv-session      # HV supply: three tmux panes (monitor, voltage, current)
docker compose exec daq daq-session     # digitizer: temperature monitor plus two panes for runs
docker compose exec daq scope           # live waveform viewer (needs the overlay and `xhost +local:docker` on the host)
```
There is only one `daq` container. To use the HV and the digitizer at the same time, open **two terminal windows or tabs** and run one command in each. Each one opens its own tmux session in its terminal, filling the window with one wide pane on top and two below. With a single terminal, start a session, press `Ctrl-b` then `d` to leave it (it keeps running), then start the other. Running a command again re-attaches to the existing session.

Without the devices attached (for example on a laptop test) the panes start but cannot reach the hardware: the HV panes end with `could not open port /dev/ttyDT5471P0`, and the digitizer's temperature pane reports that it cannot open the digitizer. This is expected.
Take runs in a `daq-session` pane as described in `DAQ_Caen/SETUP.md`, section 8. The `daq` container starts in `/opt/lab/DAQ_Caen`, so `./daq_threshold_v1.0.0 -n 100 -m sw -c 0 -r 1500 --txt data/test.txt` works as written.

- **Data and logs** are written to `./data` and `./logs` next to `docker-compose.yml`. The container runs as root, so these files are owned by root on the host.
- **Grafana:** <http://localhost:3000>, login `admin` / `admin` (change it at first login). The InfluxDB data source is already set up.
- **InfluxDB:** `localhost:8086`, reachable from the host only.
- Detach from tmux with `Ctrl-b d`. The session keeps running while the container runs.

**5. Stop.**
```bash
docker compose down        # stops the containers, keeps the InfluxDB and Grafana data
docker compose down -v     # also deletes the InfluxDB and Grafana data
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `docker compose build` stops with "no CAEN libraries in the image" | `docker/caen/` has no CAEN files. Put `caen-installed.tgz` there and build again. |
| `exec ./daq_threshold_v1.0.0: no such file or directory` | The running image was built without the CAEN libraries (an older build, or `ALLOW_NO_CAEN=1`). Check that `docker/caen/` has the file, then `docker compose build daq` and `docker compose up -d`. |
| `docker compose exec daq ldconfig -p \| grep -i caen` prints nothing | Same cause as the line above. |
| `hv-session` or `daq-session` shows the wrong number of panes, or `size missing` | An old copy of the launchers (before the tmux 3.4 layout fix). Run `git pull`, `git submodule update --init --recursive`, then `docker compose build`. |
| The hardware overlay fails to start | `/dev/ttyDT5471P0` does not exist on the host. Name the HV supply first (udev rule). |

## Changing settings

Add variables to the `environment:` block of the `daq` service in `docker-compose.yml` (for example `HV_SERIAL_PORT` or `TEMP_INTERVAL`). All variables are listed in the `tmuxsessions` README. If you change the Influx database name, also change `INFLUXDB_DB` in the `influxdb` service and `database:` in `docker/grafana/provisioning/datasources/influxdb.yml`.

## What was and was not tested

Tested, on an ARM Mac with the x86-64 images emulated, using the lab's real CAEN files (the tarball included in `docker/caen/`):
- the image builds, the CAEN libraries register (`ldconfig` shows the same six entries as the lab machine), and both DAQ programs compile and link with no missing libraries
- both programs run and print their usage; the DAQ calls the CAEN library and fails cleanly when no digitizer is attached
- all three services start; the database is created and the Grafana data source is provisioned
- a point written from the `daq` container is read back through Grafana
- both tmux sessions start inside the container with the three-pane layout (tmux 3.4); the monitor panes then fail with the expected missing-port error, because no devices are attached
- the HV Python dependencies and the scope viewer's dependencies import
- installing from original CAEN packages instead of the tarball: tested with dummy packages only, not the real ones

Not tested:
- USB access from the container to the real digitizer and HV supply, including whether the CAEN USB library needs a driver on the host
- the live viewer through X11

## Credit

The DAQ code, utilities and HV monitor were written by **Bruno P. Gelli** ([DAQ_Caen](https://github.com/BrunoGelli/DAQ_Caen), [caen-dt5533e-monitor](https://github.com/BrunoGelli/caen-dt5533e-monitor)). Please credit the original repositories when using this work.

> **Warning:** these instructions and the container files were generated by Claude (an AI assistant made by Anthropic). They have not been tested on every system, and the hardware steps have not been verified. Review each step before running it.
