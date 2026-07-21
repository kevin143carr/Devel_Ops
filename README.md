# Devel_Ops

`Devel_Ops` is a shared operations repository for retro and cross-platform
development workflows. It is meant to hold reusable build scripts, emulator
launch automation, disk-image handling notes, environment-file templates, and
known-good command sequences that can be shared by individual projects without
copying the same operational glue into every project directory.

The repo is organized by target platform:

- [AppleIIGS](AppleIIGS/README.md): Apple IIgs C development workflow using
  ORCA/C, Golden Gate `iix`, AppleCommander, GS/OS disk images, and Clemens.
- [MSDOS](MSDOS/README.md): placeholder for MS-DOS tooling, emulator setup,
  build scripts, and workflow notes.

Platform folders should stay focused on reusable development operations. Actual
application source code should live in the application repositories or project
directories that consume these scripts and notes.

## Repository Goals

- Keep platform-specific setup steps documented in one place.
- Record commands that have already been verified locally.
- Provide generic scripts that can be driven by project-local configuration.
- Keep emulator and disk-image assumptions explicit.
- Make it easy to add additional platform folders later without mixing tools
  for unrelated systems.

## Current Platforms

| Platform | Status | Notes |
| --- | --- | --- |
| Apple IIgs | Active | Current workflow supports ORCA/C builds, local `iix` tests, imports into a GS/OS hard-drive image, and timed Clemens runs. |
| MS-DOS | Placeholder | Folder exists so MS-DOS development operations can be added without changing the top-level layout later. |

