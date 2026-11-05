# MS-DOS Development Operations

This folder contains reusable MS-DOS development operations for projects that
are edited on a modern host but built and tested inside DOSBox-X with a DOS
compiler toolchain.

The workflow is intentionally local-first. It provides scripts, checks, and
documentation that can be shared on GitHub, while each developer supplies their
own emulator and licensed DOS tools.

## Current Workflow

Use `msdos-workflow.sh` from an MS-DOS project directory with a project-local
environment file:

```sh
/Users/example/projects/Devel_Ops/MSDOS/msdos-workflow.sh check
/Users/example/projects/Devel_Ops/MSDOS/msdos-workflow.sh build
/Users/example/projects/Devel_Ops/MSDOS/msdos-workflow.sh run
/Users/example/projects/Devel_Ops/MSDOS/msdos-workflow.sh package
```

To pass an explicit environment file:

```sh
/Users/example/projects/Devel_Ops/MSDOS/msdos-workflow.sh --env ./msdos-project.env build
```

The script generates a temporary DOSBox-X config for each build or run. It does
not edit project `.conf` files.

## Required Local Layout

The workflow expects a host-side DOS C drive tree containing Borland C++ 3.1:

```text
C_DRIVE/
  BC/
    BIN/
      BCC.EXE
      MAKE.EXE
      TLINK.EXE
    INCLUDE/
      DOS.H
    LIB/
      C0L.OBJ
      CL.LIB
      EMU.LIB
      MATHL.LIB
```

This repository does not vendor Borland C++ 3.1, DOSBox-X, DOS system files, or
other proprietary third-party DOS tools. Install or copy those locally according
to their license terms, then point the project environment file at them.

For source projects, the script mounts:

```text
C: = DOS_C_DRIVE
D: = DOS_SOURCE_ROOT
```

If a project lives at:

```text
/Users/example/projects/MSDOS/C/VINTANET
```

then use:

```sh
DOS_SOURCE_ROOT="/Users/example/projects/MSDOS/C"
DOS_PROJECT_DIR="VINTANET"
```

Inside DOSBox, the project is available as:

```dos
D:\VINTANET
```

Sibling libraries such as `TEXTUI` should live under the same source root:

```text
/Users/example/projects/MSDOS/C/TEXTUI
/Users/example/projects/MSDOS/C/VINTANET
```

## Project Environment

Start from:

```sh
cp /Users/example/projects/Devel_Ops/MSDOS/msdos-project.env.example ./msdos-project.env
```

Then edit the copied file for the project and host machine:

```sh
PROJECT_DIR="/Users/example/projects/MSDOS/C/VINTANET"
DOS_C_DRIVE="/Users/example/projects/MSDOS/C_DRIVE"
DOS_SOURCE_ROOT="/Users/example/projects/MSDOS/C"
DOSBOX_BIN="/Applications/dosbox-x.app/Contents/MacOS/dosbox-x"

DOS_PROJECT_DIR="VINTANET"
BUILD_COMMAND="CALL build.bat"
RUN_COMMAND="VINTANET.EXE VINTANET.CFG"
SIBLING_DEPS="TEXTUI"

PACKAGE_NAME="vintanet"
PACKAGE_FILES="VINTANET.EXE VNKEYMON.EXE VNKEYTSR.EXE VINTANET.CFG README.md LICENSE VERSION run_admin.bat run_slave.bat testcap.bat VNKEYTSR.BAT UPDATEVN.BAT"
PACKAGE_DIRS="samples SCRIPTS"
TRANSFER_DIR=""
```

Keep `msdos-project.env` out of public repositories if it contains personal
absolute paths.

## Stages

`check` validates the host-side setup before DOSBox launches. It verifies the
emulator path, the DOS C drive, required Borland compiler files, the project
directory, and configured sibling dependencies.

`build` runs the configured build command inside DOSBox-X. The generated config
adds `C:\BC\BIN` to `PATH`, mounts `C:` and `D:`, changes to the configured DOS
project directory, runs `BUILD_COMMAND`, then exits.

`run` launches the configured program command inside DOSBox-X interactively.
Use `DOSBOX_EXTRA_CONFIG` for project-specific sections such as nullmodem
serial port settings.

`package` runs `build`, copies `PACKAGE_FILES` and `PACKAGE_DIRS` into
`dist/test/<package>/`, writes `BUILDINFO.TXT`, and creates
`dist/test/<package>.zip`. If `TRANSFER_DIR` is set and exists, the package is
also copied there for hardware testing.

## GitHub Sharing Model

Public projects should commit:

- source code
- makefiles and DOS batch files
- sample configs
- `msdos-project.env.example` or project-specific setup notes

Public projects should not commit:

- copied DOS C drive contents
- Borland compiler binaries, headers, or libraries
- generated `.OBJ`, `.EXE`, `.LIB`, `BUILD.CFG`, or `BUILD.LOG` files
- personal absolute-path env files
