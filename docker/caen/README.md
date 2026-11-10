# CAEN libraries

This folder holds the CAEN libraries used by both the Docker build (`docker compose build`) and the native installer (`./install.sh`, which installs the files system-wide with sudo; `--caen-dir DIR` reads them from another folder).

**`caen-installed.tgz` is already included**: CAENVME v4.1.3, CAENComm v1.8.0 and CAENDigitizer v2.19.0, the versions of the lab machine where the DAQ works. They are CAEN's files; see [NOTICE.md](NOTICE.md) for what they are and under what terms they are included. Nothing else is needed for the standard setup.

## Using other versions

Replace `caen-installed.tgz`, or add other files here (these are ignored by git):

- **Original CAEN packages** (download from CAEN, registration required): CAENVMELib, CAENComm and CAENDigitizer as `.tgz`, `.tar.gz`, `.tar.xz` or `.zip`, **Linux x86-64**. Each package's `install_x64` script (in its `lib` folder) is run in the order VME, Comm, Digitizer.
- **Files from a machine where the libraries already work**, packed with:
  ```bash
  tar -czf ~/caen-installed.tgz /usr/lib/libCAEN* /usr/include/CAEN*
  ```
  Keep a file name starting with `caen-installed`.

`caen_felib` and `caen_dig2` are not needed for the DT5730S and are not installed.
