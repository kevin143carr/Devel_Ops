# GS/OS Image Operations

This file records user-verified Apple IIgs development operations for this
project. Treat these entries as the local source of truth before trying
alternate tools or metadata experiments.

For repeatable project work, use the generic workflow script plus a
project-local `appleiigs-project.env` file documented in
`../devel_ops/appleiigs-workflow-usage.md`.

## Known-good: Import a Finder-launchable GS/OS program

Purpose: put the local ORCA-built `hello` program into the GS/OS hard-drive
image so it can be launched manually from GS/OS/Finder.

Exact command:

```sh
appcom -p "$HOME/projects/AppleIIGS/System601HD.hdv" HELLO S16 0 < ./hello
```

Use this when:

- The program has already been built and tested through `iix`.
- The destination is the real project image:
  `$HOME/projects/AppleIIGS/System601HD.hdv`.
- The desired result is a root-level `HELLO` file that can be double-clicked
  from GS/OS/Finder.

Do not substitute:

- Do not use `EXE` when the goal is GS/OS/Finder double-click launch.
- Do not import into a `/tmp` image unless explicitly doing a disposable test.
- Do not switch to another disk utility unless explicitly requested.
- Do not omit the file type and auxiliary type arguments after `HELLO`.

Verification:

```sh
appcom -ll "$HOME/projects/AppleIIGS/System601HD.hdv"
```

The listing must show root-level `HELLO` with type `S16`.
