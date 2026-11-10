# Container for the CAEN DT5730S DAQ and DT5471P HV tools.
# Build context is the repository root (see docker-compose.yml).
# Base: official ROOT image (x86-64 only, like the CAEN libraries).
FROM --platform=linux/amd64 rootproject/root:6.32.04-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        tmux usbutils unzip ca-certificates libcurl4-openssl-dev \
        python3-venv python3-pip python3-tk python3-numpy python3-matplotlib \
    && rm -rf /var/lib/apt/lists/*

# CAEN libraries: NOT part of this repository. Place your own downloads in docker/caen/
# (see docker/caen/README.md). Without them the image still builds, but the DAQ programs are not compiled.
COPY docker/caen/ /tmp/caen/
COPY docker/install-caen.sh /usr/local/bin/install-caen.sh
RUN chmod +x /usr/local/bin/install-caen.sh && install-caen.sh /tmp/caen && rm -rf /tmp/caen

COPY DAQ_Caen /opt/lab/DAQ_Caen
COPY caen-dt5471p-monitor /opt/lab/caen-dt5471p-monitor
COPY tmuxsessions /opt/lab/tmuxsessions
COPY docker/bin/ /usr/local/bin/

# HV monitor Python environment
RUN python3 -m venv /opt/lab/caen-dt5471p-monitor/.venv \
    && /opt/lab/caen-dt5471p-monitor/.venv/bin/pip install --no-cache-dir -r /opt/lab/caen-dt5471p-monitor/requirements.txt

# DAQ programs (need ROOT and the CAEN libraries)
RUN cd /opt/lab/DAQ_Caen && mkdir -p data logs && \
    if ldconfig -p | grep -q CAENDigitizer; then \
        g++ -O2 -std=c++17 daq_threshold_v1.0.0.cpp -o daq_threshold_v1.0.0 $(root-config --cflags --libs) -lCAENDigitizer && \
        g++ -O2 -std=c++17 utils/read_temp_influx.cpp -o utils/read_temp_influx -lCAENDigitizer -lcurl ; \
    else \
        echo "WARNING: CAEN libraries not found - DAQ programs were NOT built. See docker/caen/README.md." ; \
        touch /opt/lab/NO_CAEN_LIBRARIES ; \
    fi

ENV DAQ_DIR=/opt/lab/DAQ_Caen \
    HV_DIR=/opt/lab/caen-dt5471p-monitor \
    ROOT_SETUP=/opt/root/bin/thisroot.sh \
    DAQ_DATA_DIR=/opt/lab/DAQ_Caen/data \
    INFLUX_HOST=influxdb \
    TERM=xterm-256color
WORKDIR /opt/lab/DAQ_Caen
CMD ["sleep", "infinity"]
