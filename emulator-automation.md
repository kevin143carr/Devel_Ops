# Emulator Automation

This file records the current known-good approach for launching Apple IIgs
programs in an emulator. Keep the generic workflow separate from any
emulator-specific implementation so the project can switch emulators later.

## Generic workflow

Use this shape for any emulator:

1. Build and test the program locally with `iix`.
2. Import the tested executable into the GS/OS hard-drive image with the
   known-good Finder-launchable format.
3. Configure GS/OS SetStart to launch the target program on boot.
4. Boot the emulator from the configured hard-drive image.
5. End the emulator session after the program has had time to run, unless a
   stronger program-completion signal has been verified.

Related known-good notes:

- Generic workflow script and project-local environment files:
  `../devel_ops/appleiigs-workflow-usage.md`
- ORCA/C build and `iix` test usage: `../devel_ops/iix-orcac-usage.md`
- GS/OS image import command: `../devel_ops/gsos-image-operations.md`

For the current `HELLO` workflow, the image import command is:

```sh
appcom -p "$HOME/projects/AppleIIGS/System601HD.hdv" HELLO S16 0 < ./hello
```

The hard-drive image listing should show root-level `HELLO` with type `S16`.

## Mac/Clemens implementation

Current locally verified paths and names:

```sh
CLEMENS_APP="/Users/kevincarr/bin/Clemens IIGS.app"
CLEMENS_NAME="Clemens IIGS"
CLEMENS_CONFIG="$HOME/Library/Application Support/cinekine/Clemens/config.ini"
IMAGE="$HOME/projects/AppleIIGS/System601HD.hdv"
```

The current Clemens config mounts the project hard-drive image as:

```ini
gs.smart.1=/Users/kevincarr/projects/AppleIIGS/System601HD.hdv
```

Launch Clemens:

```sh
/usr/bin/open "$CLEMENS_APP"
```

Check whether Clemens is running:

```sh
/usr/bin/osascript -e "application \"$CLEMENS_NAME\" is running"
```

Quit Clemens:

```sh
/usr/bin/osascript -e "tell application \"$CLEMENS_NAME\" to quit"
```

## Workflow script mode

Use the generic workflow script from a project directory that contains a local
`appleiigs-project.env` file:

```sh
../devel_ops/appleiigs-workflow.sh emulator
```

For the current `hello` project, the project-local environment file is
`appleiigs-project.env`. It contains the project-specific source, output name,
disk image, import metadata, Clemens paths, and `RUN_SECONDS=60`.

## Important boundaries

- This is a timed host-side quit workflow: launch Clemens, wait `RUN_SECONDS`,
  then quit Clemens with AppleScript.
- Do not describe this as exact detection of program exit until a program-side
  signal, emulator hook, or host-detectable completion condition is verified.
- Do not automate SetStart configuration yet. Configure SetStart inside GS/OS
  and treat that as a prerequisite for this workflow.
- Do not use temporary images for the normal workflow. The project image is
  `$HOME/projects/AppleIIGS/System601HD.hdv`.
