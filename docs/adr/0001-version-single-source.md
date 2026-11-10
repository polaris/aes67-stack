# 0001: `version.h` is the single source of the version number

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

The version number was maintained in three places: `project(VERSION …)` in
the root `CMakeLists.txt`, the `AES67_VERSION_*` macros in
`include/aes67/version.h`, and hard-coded values in `tests/unit/test_version.c`.
Three copies drift apart sooner or later.

Two ways to reduce this to one source:

- **A: CMake is the source.** `project(VERSION …)` holds the number,
  `configure_file()` generates `version.h` into the build directory.
- **B: The header is the source.** `version.h` is a normal checked-in file;
  CMake reads the macros before `project()`.

The core is meant to become a Zephyr module later (`zephyr/module.yml`,
`zephyr_library()`). A Zephyr build includes the module's own
`zephyr/CMakeLists.txt` and never runs this project's root `CMakeLists.txt`.

## Decision

Option B. `include/aes67/version.h` is the only place where the version is
written. `cmake/aes67-version.cmake` provides `aes67_read_version()`, which
reads `AES67_VERSION_MAJOR/MINOR/PATCH` with `file(STRINGS)` and a regex
before `project()` and stops with a clear error if a macro is missing or not
numeric. The header is added to `CMAKE_CONFIGURE_DEPENDS`, so editing it
triggers a re-configure.

`test_version.c` no longer contains literal numbers; it unpacks the value
returned by `aes67_version()` and compares each part with the macros.

## Consequences

- Any build system that only sees the source tree (Zephyr, a plain Makefile,
  an IDE) gets the correct version from the header without running CMake
  first. Option A would have needed a second generation step for Zephyr.
- The header must keep the simple `#define AES67_VERSION_X <number>` form;
  the regex in `aes67-version.cmake` depends on it.
- Changing the version is a one-line edit in `version.h`.
