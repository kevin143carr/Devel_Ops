# AppleIIGS Development Operations

This folder contains reusable Apple IIgs development operations for projects
that are built on a modern host but need to run in Apple IIgs-oriented tooling.
The current workflow is centered on C programs built with ORCA/C through Golden
Gate `iix`, copied into a GS/OS hard-drive image with AppleCommander, and run in
the Clemens Apple IIgs emulator.

The scripts and notes here are intentionally generic. Individual Apple IIgs
projects should keep their own source files and their own
`appleiigs-project.env` file, then call the shared workflow script from this
folder.

## Current Workflow

The usual workflow has four parts:

1. Compile and link the program with ORCA/C through Golden Gate `iix`.
2. Run the resulting executable locally through `iix` as a fast text-mode test.
3. Import the tested executable into a GS/OS hard-drive image with
   AppleCommander.
4. Boot that image in the current emulator, Clemens.

For the current setup, the reusable workflow script is:

```sh
AppleIIGS/appleiigs-workflow.sh
```

From an Apple IIgs project directory, run it through the shared path and a
project-local environment file:

```sh
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh build
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-iix
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-gsos
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-both
```

To pass an explicit environment file:

```sh
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh --env ./appleiigs-project.env run-both
```

## Required Subsystems

### ORCA/C

ORCA/C is the Apple IIgs C compiler used by this workflow. It produces Apple
IIgs object files and linked executables for the 65816/GS environment. This repo
does not vendor ORCA/C; it expects ORCA/C to be installed in the Golden Gate
environment where `iix compile` and `iix link` can find it.

Useful checks:

```sh
iix man compile
iix man link
iix man cc
```

Known-good build shape:

```sh
iix compile hello.c keep=hello.obj
iix link hello.obj keep=hello
```

The compile step typically produces files such as:

```text
hello.obj.a
hello.obj.root
hello.sym
```

The link step produces the executable named by `keep=`.

### Golden Gate and `iix`

Golden Gate is the host-side compatibility layer used to run Apple IIgs shell
tools on the modern machine. The `iix` command is the command-line entry point
for invoking that compatibility layer.

This workflow uses `iix` for two purposes:

- Running ORCA/C tools:

  ```sh
  iix compile "$SOURCE" keep="$OBJECT"
  iix link "$OBJECT" keep="$PROGRAM"
  ```

- Running the built program as a quick host-side test:

  ```sh
  iix "./$PROGRAM"
  ```

Use `iix` tests for fast feedback before touching the GS/OS hard-drive image.
This confirms the program works in the ORCA/iix shell environment. It does not
prove the program has the correct GS/OS file type for Finder double-click
launch, so the disk-image import metadata still matters.

Useful checks:

```sh
iix --help
iix -V
```

Projects may set `GOLDEN_GATE` in their `appleiigs-project.env` to pin a
specific Golden Gate root. The workflow exports that value before invoking
`iix`, so compile, link, and local run stages all use the project-selected
compiler environment.

### AppleCommander

AppleCommander is the disk-image utility used by this workflow. The script uses
the `appcom` command to inspect a GS/OS hard-drive image, delete an old copy of
the destination program if present, and import the freshly linked executable.

Known-good import shape for a Finder-launchable GS/OS application:

```sh
appcom -p "/Users/example/projects/AppleIIGS/System601HD.hdv" HELLO S16 0 < ./hello
```

Known-good listing check:

```sh
appcom -ll "/Users/example/projects/AppleIIGS/System601HD.hdv"
```

For the current ORCA/C executable import flow, use:

```sh
FILE_TYPE="S16"
AUX_TYPE="0"
```

Do not use `EXE` for the Finder double-click workflow unless a specific project
has independently verified that it needs shell-application behavior instead of
GS/OS application behavior.

### GS/OS Hard-Drive Image

The current workflow imports built programs into a real GS/OS hard-drive image:

```sh
/Users/example/projects/AppleIIGS/System601HD.hdv
```

The workflow script creates a timestamped backup before its first import when a
matching backup is not already present. Normal development should use the real
project image rather than a temporary image, because emulator configuration and
GS/OS SetStart behavior depend on the configured disk image.

The current process assumes SetStart is configured inside GS/OS to launch the
target program on boot when running the emulator workflow. SetStart automation is
not part of the script yet.

### Emulator

An Apple IIgs emulator is required for the GS/OS-side run. The current emulator
is Clemens, and the script automates Clemens on macOS using `/usr/bin/open` and
AppleScript.

Example Clemens settings:

```sh
CLEMENS_APP="/Users/example/Applications/Clemens IIGS.app"
CLEMENS_NAME="Clemens IIGS"
CLEMENS_CONFIG="/Users/example/Library/Application Support/cinekine/Clemens/config.ini"
IMAGE="/Users/example/projects/AppleIIGS/System601HD.hdv"
```

The Clemens config should mount the project hard-drive image as:

```ini
gs.smart.1=/Users/example/projects/AppleIIGS/System601HD.hdv
```

The emulator stage is intentionally timed:

1. Ensure Clemens is not already running.
2. Launch Clemens.
3. Wait for `RUN_SECONDS`.
4. Quit Clemens with AppleScript.

Set `RUN_SECONDS` to a negative value, such as `-1`, to launch Clemens and
leave it running without timed shutdown.

This should not be treated as exact program-exit detection. It is a practical
host-side timed run until a stronger signal is added.

### macOS Host Utilities

For the current Clemens automation, the host must provide:

```sh
/usr/bin/open
/usr/bin/osascript
```

Those are standard macOS tools. They are only needed for emulator launch and
shutdown, not for `iix` compile/link/test stages.

## Project Environment Files

Each Apple IIgs project should have its own `appleiigs-project.env`. Start from:

```sh
cp /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-project.env.example ./appleiigs-project.env
```

Then edit the copied file for that project:

```sh
PROJECT_DIR="/absolute/path/to/project"
SOURCE="program.c"
OBJECT="program.obj"
PROGRAM="program"

IMAGE="/Users/example/projects/AppleIIGS/System601HD.hdv"
DEST_NAME="PROGRAM"
FILE_TYPE="S16"
AUX_TYPE="0"

EXTRA_IMPORTS='
'

CLEMENS_APP="/Users/example/Applications/Clemens IIGS.app"
CLEMENS_NAME="Clemens IIGS"
CLEMENS_CONFIG="/Users/example/Library/Application Support/cinekine/Clemens/config.ini"
RUN_SECONDS="60"
```

The project env file is the right place for project-specific source names,
output names, destination names, disk image path, extra imported files, emulator
path, and timed-run duration. Do not hard-code those values in
`appleiigs-workflow.sh`.

Use `EXTRA_IMPORTS` for companion files that must be copied into the GS/OS
image after the executable. It is newline-delimited, not comma-delimited, and
each line uses this pipe-separated form:

```sh
EXTRA_IMPORTS='
SOURCE|DEST_NAME|FILE_TYPE|AUX_TYPE
'
```

For example:

```sh
EXTRA_IMPORTS='
VINTANETGS.CFG|VINTANETGS.CFG|TXT|0
'
```

Each source path is resolved from `PROJECT_DIR`.

## Workflow Script Stages

`appleiigs-workflow.sh` supports these stages:

| Stage | Behavior |
| --- | --- |
| `build` | Compile and link with ORCA/C through `iix`. |
| `test-iix` | Run the already-built executable through `iix` interactively. |
| `run-iix` | Build, then run the executable through `iix`. |
| `import` | Import the executable and optional `EXTRA_IMPORTS` files into the GS/OS image with AppleCommander. |
| `transfer` | Copy the configured GS/OS image to `IMAGE_TRANSFER_DIR`. |
| `emulator` | Launch Clemens, wait `RUN_SECONDS`, then quit Clemens. |
| `run-gsos` | Build, import into the GS/OS image, then run Clemens. |
| `run-both` | Build, test with `iix`, import, then run Clemens. |
| `verify` | Show project files and the current AppleCommander image listing. |
| `all` | Build, test with `iix`, import, then run Clemens. |

Before running a demonstration or user-visible test workflow, choose the run
target intentionally:

```text
1. iix only
2. GS/OS only
3. both
```

Map those choices to:

```text
1 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-iix
2 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-gsos
3 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-both
```

## Known-Good Commands

Compile and link:

```sh
iix compile hello.c keep=hello.obj
iix link hello.obj keep=hello
```

Run locally through `iix`:

```sh
iix ./hello
```

Import into GS/OS image:

```sh
appcom -p "/Users/example/projects/AppleIIGS/System601HD.hdv" HELLO S16 0 < ./hello
```

Inspect the GS/OS image:

```sh
appcom -ll "/Users/example/projects/AppleIIGS/System601HD.hdv"
```

Launch Clemens:

```sh
/usr/bin/open "/Users/example/Applications/Clemens IIGS.app"
```

Check whether Clemens is running:

```sh
/usr/bin/osascript -e 'application "Clemens IIGS" is running'
```

Quit Clemens:

```sh
/usr/bin/osascript -e 'tell application "Clemens IIGS" to quit'
```

## Supporting Notes

- [Workflow script usage](appleiigs-workflow-usage.md)
- [ORCA/C and iix usage](iix-orcac-usage.md)
- [GS/OS image operations](gsos-image-operations.md)
- [Emulator automation](emulator-automation.md)

## External References

- [Golden Gate manual](https://goldengate.gitlab.io/manual/)
- [AppleCommander](https://applecommander.github.io/)
- [Clemens IIGS](https://github.com/samkusin/clemens_iigs)
- [ORCA/C source mirror](https://github.com/byteworksinc/ORCA-C)
