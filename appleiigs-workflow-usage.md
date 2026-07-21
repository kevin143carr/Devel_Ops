# Apple IIgs Workflow Script Usage

Use `appleiigs-workflow.sh` as a generic workflow engine. Do not hard-code
project-specific filenames, disk-image paths, AppleCommander metadata, or
emulator paths in that script.

Each Apple IIgs project directory should contain its own project-local
environment file:

```text
appleiigs-project.env
```

Start a new project by copying the example from `devel_ops`:

```sh
cp ../devel_ops/appleiigs-project.env.example ./appleiigs-project.env
```

Then edit the local copy for the project, especially `PROJECT_DIR`, `SOURCE`,
`OBJECT`, `PROGRAM`, and `DEST_NAME`.

Run the workflow script from the project directory:

```sh
../devel_ops/appleiigs-workflow.sh build
```

Or pass an explicit environment file:

```sh
../devel_ops/appleiigs-workflow.sh --env ./appleiigs-project.env build
```

## Required project environment

The project environment file supplies the project-specific values:

```sh
PROJECT_DIR="/absolute/path/to/project"
SOURCE="program.c"
OBJECT="program.obj"
PROGRAM="program"

IMAGE="$HOME/projects/AppleIIGS/System601HD.hdv"
DEST_NAME="PROGRAM"
FILE_TYPE="S16"
AUX_TYPE="0"

CLEMENS_APP="/Users/kevincarr/bin/Clemens IIGS.app"
CLEMENS_NAME="Clemens IIGS"
CLEMENS_CONFIG="$HOME/Library/Application Support/cinekine/Clemens/config.ini"
RUN_SECONDS="60"
```

For the current `hello` project, the environment file is:

```text
/Users/kevincarr/projects/AppleIIGS/C/hello/appleiigs-project.env
```

## Stage behavior

- `build`: runs `iix compile "$SOURCE" keep="$OBJECT"` and
  `iix link "$OBJECT" keep="$PROGRAM"`.
- `test-iix`: runs `iix "./$PROGRAM"` interactively, so the visible program
  prompt can be answered.
- `run-iix`: runs `build`, then `test-iix`.
- `import`: deletes the existing destination file if present, then imports the
  executable with:

  ```sh
  appcom -p "$IMAGE" "$DEST_NAME" "$FILE_TYPE" "$AUX_TYPE" < "$PROGRAM"
  ```

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
1 -> ../devel_ops/appleiigs-workflow.sh run-iix
2 -> ../devel_ops/appleiigs-workflow.sh run-gsos
3 -> ../devel_ops/appleiigs-workflow.sh run-both
```

Each of these numbered run modes is a complete workflow for the selected
target, including a fresh `build` first.

`GS/OS only` means the workflow imports the executable into the configured HDV
image and launches the configured emulator. It does not mean the program is run
through `iix`.

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
