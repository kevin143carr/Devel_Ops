# Apple IIgs Workflow Script Usage

Use `appleiigs-workflow.sh` as a generic workflow engine. Do not hard-code
project-specific filenames, disk-image paths, AppleCommander metadata, or
emulator paths in that script.

Each Apple IIgs project directory should contain its own project-local
environment file:

```text
appleiigs-project.env
```

Start a new project by copying the example from `Devel_Ops/AppleIIGS`:

```sh
cp /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-project.env.example ./appleiigs-project.env
```

Then edit the local copy for the project, especially `PROJECT_DIR`, `SOURCE`,
`OBJECT`, `PROGRAM`, and `DEST_NAME`.

Run the workflow script from the project directory:

```sh
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh build
```

Or pass an explicit environment file:

```sh
/Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh --env ./appleiigs-project.env build
```

## Required project environment

The project environment file supplies the project-specific values:

```sh
PROJECT_DIR="/absolute/path/to/project"
GOLDEN_GATE="/Library/GoldenGate"
SOURCE="program.c"
OBJECT="program.obj"
PROGRAM="program"

IMAGE="/Users/example/projects/AppleIIGS/System601HD.hdv"
IMAGE_TRANSFER_DIR="/Users/example/AppleShare/transfer"
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

`GOLDEN_GATE` is optional. When set, the workflow validates that directory,
exports it, and all `iix` compile/link/run commands use that Golden Gate root.

`EXTRA_IMPORTS` is optional. When set, it imports companion files after the
main executable. Use one entry per line:

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

Each source path is resolved from `PROJECT_DIR` because the workflow changes
into the project directory before importing.

`IMAGE_TRANSFER_DIR` is optional. When set, the explicit `transfer` stage copies
the configured `IMAGE` to that directory using the same filename.

For an example `hello` project, the environment file could be:

```text
/Users/example/projects/AppleIIGS/C/hello/appleiigs-project.env
```

## Stage behavior

- `build`: runs `iix compile "$SOURCE" keep="$OBJECT"` and
  `iix link "$OBJECT" keep="$PROGRAM"`.
- `test-iix`: runs `iix "./$PROGRAM"` interactively, so the visible program
  prompt can be answered.
- `run-iix`: runs `build`, then `test-iix`.
- `import`: deletes the existing destination file if present, imports the
  executable with:

  ```sh
  appcom -p "$IMAGE" "$DEST_NAME" "$FILE_TYPE" "$AUX_TYPE" < "$PROGRAM"
  ```

  It then imports each optional `EXTRA_IMPORTS` entry with the same delete then
  import flow.

- `transfer`: copies the configured `IMAGE` to `IMAGE_TRANSFER_DIR` using the
  image basename. This stage is explicit and is not run automatically by
  `import`, `run-gsos`, or `run-both`.
- `emulator`: launches Clemens, waits `RUN_SECONDS`, then quits Clemens.
- `run-gsos`: runs `build`, then `import`, then `emulator`.
- `run-both`: runs `build`, then `test-iix`; only if that succeeds, runs
  `import` and `emulator`.
- `verify`: shows the project directory and the current `appcom` image listing.

## Agent run-target question

Before running a demonstration or user-visible test workflow, ask this question
first and wait for the user's choice:

```text
Which run mode do you want?

1. iix only
2. GS/OS only
3. both
```

Map the answer to exactly one command:

```text
1 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-iix
2 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-gsos
3 -> /Users/example/projects/Devel_Ops/AppleIIGS/appleiigs-workflow.sh run-both
```

Each of these numbered run modes is a complete workflow for the selected
target, including a fresh `build` first.

`GS/OS only` means the workflow imports the executable into the configured HDV
image and launches the configured emulator. It does not mean the program is run
through `iix`.

Set `RUN_SECONDS` to a negative value, such as `-1`, when the emulator should
remain running after launch instead of being stopped by the workflow.

Do not default to `both` just because it is the broadest verification. If the
question helper is unavailable, ask the 1/2/3 question directly in the chat and
wait for the user to answer.

## Current known-good import metadata

For an ORCA/C program that should be double-clickable from GS/OS/Finder in this
workflow, use:

```sh
FILE_TYPE="S16"
AUX_TYPE="0"
```

Do not use `EXE` for the Finder double-click workflow unless a different
project has independently verified that requirement.
