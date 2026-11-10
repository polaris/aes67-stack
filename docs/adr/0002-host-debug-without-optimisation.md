# 0002: `host-debug` stays at `-O0`

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Some GCC warnings only work when the optimiser runs, because they depend on
its data-flow analysis. The clearest case in our warning set is
`-Wnull-dereference`: the GCC manual ties it to
`-fdelete-null-pointer-checks`, which is enabled by optimisation.

`host-debug` uses `CMAKE_BUILD_TYPE=Debug`, which means `-O0` with GCC. The
idea was to switch to `-Og` ("optimise for debugging") to get these warnings
in the everyday build.

Test with GCC 15.2 and `int *p = 0; return *p;`:

| Level | Warning |
| --- | --- |
| `-O0` | no |
| `-Og` | no |
| `-O1`, `-O2`, `-Os` | yes |

A slightly less obvious case (`if (!p) c = 1; return *p + c;`) produced no
warning at any level.

## Decision

`host-debug` keeps `-O0`. Warnings that need optimisation are covered by the
other presets:

- `mcu-check` builds the core with `-Os` and `-Werror` (`MinSizeRel`).
- `bbb` and `host-fuzz` build with `RelWithDebInfo` (`-O2`).

## Consequences

- Debugging in `host-debug` stays exact: no optimised-out variables, the
  debugger steps line by line.
- A warning like `-Wnull-dereference` can show up in `mcu-check` or CI
  without showing up in `host-debug`. Running `mcu-check` locally before a
  commit is therefore part of the routine (see `CLAUDE.md`).
- `-Wnull-dereference` is only a coarse net, even with optimisation. Null
  pointers are caught by explicit checks in the code, unit tests, the
  sanitizers and fuzzing, not by this warning.
