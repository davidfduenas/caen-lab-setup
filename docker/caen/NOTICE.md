# Notice: CAEN libraries in `caen-installed.tgz`

`caen-installed.tgz` contains software that belongs to **CAEN S.p.A.** (Viareggio, Italy). It is included here only so that the lab setup works after a single `git clone`. It is not our work.

## Contents

Copied unmodified from a lab machine where the DT5730S DAQ works (`/usr/lib` and `/usr/include`):

| File | Version |
|---|---|
| `libCAENVME.so` (symlink to `libCAENVME.so.v4.1.3`) | CAENVME 4.1.3 |
| `libCAENComm.so` (symlink to `libCAENComm.so.v1.8.0`) | CAENComm 1.8.0 |
| `libCAENDigitizer.so` (symlink to `libCAENDigitizer.so.v2.19.0`) | CAENDigitizer 2.19.0 |
| `CAENVMElib.h`, `CAENVMEoslib.h`, `CAENVMEtypes.h` | CAENVME headers |
| `CAENComm.h` | CAENComm header |
| `CAENDigitizer.h`, `CAENDigitizerType.h` | CAENDigitizer headers |

SHA-256 of the tarball: `166386359cd5a16deeacdd985a93c36cd81937e8957431fe965530a015da680b`

## Terms

- `CAENDigitizerType.h` carries this notice from CAEN: *"TERMS OF USE: This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation."*
- The other headers show only CAEN's copyright and author lines, and the compiled libraries contain no licence text. We have not confirmed CAEN's terms for CAENVME and CAENComm, or for the compiled libraries.
- All rights in these files remain with CAEN S.p.A. The original packages are available from <https://www.caen.it> (registration required). For questions about the terms, contact CAEN (the headers list support.computing@caen.it).
- If CAEN or its representatives ask for these files to be removed, they will be removed from this repository.

## Using other versions

To use other CAEN versions or the original packages, replace the tarball or put the packages in this folder (see `README.md` in this folder). Other archives placed here are ignored by git.
