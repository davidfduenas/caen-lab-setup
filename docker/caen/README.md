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

## Option B: files from a machine where they already work

If you do not have the original packages but have a machine where the libraries are installed (as on the lab machine),
make a tarball of the installed files there and put it in this folder:

```bash
tar -czf ~/caen-installed.tgz /usr/lib/libCAEN* /usr/include/CAEN*
```

On the lab machine this packs `libCAENVME`, `libCAENComm` and `libCAENDigitizer` (versions 4.1.3, 1.8.0 and 2.19.0) and the six
header files (`CAENComm.h`, `CAENDigitizer.h`, `CAENDigitizerType.h`, `CAENVMElib.h`, `CAENVMEoslib.h`, `CAENVMEtypes.h`).
Copy `caen-installed.tgz` into `docker/caen/` (keep a name starting with `caen-installed`). The build extracts it into the image.
The file is ignored by git. Keep it for your own use: these files are CAEN's.

Optional check on the working machine, to see which other system libraries they use:
```bash
ldd /usr/lib/libCAENVME.so /usr/lib/libCAENComm.so /usr/lib/libCAENDigitizer.so
```

