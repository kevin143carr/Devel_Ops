# iix ORCA/C Usage

This file records user-verified `iix` and ORCA/C operations for this project.
Check this before changing compiler commands, output names, or test flow.

For repeatable project work, use the generic workflow script plus a
project-local `appleiigs-project.env` file documented in
`../devel_ops/appleiigs-workflow-usage.md`.

## Known-good: compile, link, and test `hello.c`

Purpose: build a simple ORCA/C text-mode program and verify it runs under
`iix` before copying it into a GS/OS hard-drive image.

Source file:

```text
hello.c
```

Compile command:

```sh
iix compile hello.c keep=hello.obj
```

Expected compile outputs:

```text
hello.obj.a
hello.obj.root
hello.sym
```

Link command:

```sh
iix link hello.obj keep=hello
```

Expected final local executable:

```text
hello
```

Test command:

```sh
iix ./hello
```

For programs that use `getchar()`, run the test interactively and supply
Return. A successful test for the current `hello.c` shows:

```text
Hello, World!
Build: Jul 20 2026 06:37:02
Press Return to exit.
```

The program must remain running at that prompt until Return is supplied, then
exit with status 0.

## Useful local help

Show available `iix` options and built-ins:

```sh
iix --help
```

Show ORCA/C compile syntax:

```sh
iix man compile
```

Show ORCA linker syntax:

```sh
iix man link
```

Confirm ORCA/C language selector:

```sh
iix man cc
```

## Important boundary

The `iix ./hello` test proves the local ORCA-built program runs under the
ORCA/iix execution environment. It does not determine the file type to use
inside a GS/OS hard-drive image.

For the known-good GS/OS/Finder double-click import command, use
`../devel_ops/gsos-image-operations.md`.
