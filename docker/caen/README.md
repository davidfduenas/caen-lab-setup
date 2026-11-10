# CAEN libraries (supplied by you)

The CAEN libraries are proprietary and are **not** included in this repository or in any published image.
Download them from CAEN's website (registration required) and place the packages in this folder before
building the image. Use the same versions as the lab machine where the DAQ works:

| Library | Version |
|---|---|
| CAENVME (CAENVMELib) | v4.1.3 |
| CAENComm | v1.8.0 |
| CAENDigitizer | v2.19.0 |

Use the **Linux x86-64** packages (`.tgz`, `.tar.gz`, `.tar.xz` or `.zip`). The files you put here are ignored by git.

During `docker compose build` each package is unpacked and its `install_x64` script (in the package's `lib` folder)
is run, in the order VME, Comm, Digitizer. The build then compiles the DAQ programs against them. `caen_felib` and
`caen_dig2` are not needed for the DT5730S and are not installed.
