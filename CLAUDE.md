# CLAUDE.md

Guidance for Claude Code in this repository. Read this file, `docs/plan.md`
and (once it exists) `docs/api-design.md` at the start of every session.

## Project

`aes67-stack` is a portable AES67 implementation in C11: SAP/SDP discovery,
RTP send/receive, L24 PCM conversion and the mapping between PTP time and
RTP timestamps. It is a **learning and showcase project**, developed in public.
Readable code, tests, documentation and measured results matter more than
feature completeness.

Targets:

- **Host** (Linux/WSL2): development, unit tests, sanitizers, fuzzing.
- **BeagleBone Black** (Yocto, Cortex-A8, Linux): POSIX port and apps.
- **NUCLEO-H753ZI** (Cortex-M7, later with Zephyr): the core must build
  for this target at all times (`mcu-check` preset).

## How we work together

The owner (Jan) wants to improve his skills in C. Respect this split of work:

1. **Claude Code drafts headers** in `include/aes67/` and proposes test
   cases (including edge cases). Jan reviews and approves. Do not change an
   approved header without asking; changes need an ADR in `docs/adr/`.
2. **Jan writes tests and implementation** for everything in `src/core/`.
   Do **not** write core implementation or core tests unless Jan explicitly
   asks for it in the current session.
3. **Claude Code reviews** Jan's tests and implementation against this file
   and `docs/api-design.md`, runs all presets and reports findings. Explain C
   details Jan may not know (undefined behaviour, integer promotion,
   aliasing, alignment, portability).
4. **Jan commits** to Git. Do **not** commit to Git unless Jan explicitly
   asks for it in the current session.

Claude Code may write without asking: CMake files, CI, Python helpers in
`tools/`, command-line apps in `apps/`, documentation drafts.

Commit rule: every commit is green in all presets. Locally, red tests are
fine (test first, then code). Tests committed before their implementation
use `TEST_IGNORE()`. One module per commit, messages in English.

## Code rules

### Language and layout

- C11 (`-std=c11`, no GNU extensions). No C17/C23 features.
- All code, comments, identifiers and commit messages in English.
- `src/core/`: portable core. **No** `malloc`/`free`, **no** OS calls,
  **no** `printf`/stdio, **no** global or static mutable state.
  Only `<stdint.h>`, `<stdbool.h>`, `<stddef.h>`, `<string.h>` (mem*/str* on
  caller buffers) and `<limits.h>`.
- `port/`: platform code (POSIX now, Zephyr later). The core talks to it
  only through `include/aes67/platform.h`.
- `apps/`: command-line programs for POSIX; may use stdio and the OS.

### Naming

- Public functions and types: `aes67_` prefix, `snake_case`.
- Macros and enum constants: `AES67_` prefix, `UPPER_CASE`.
- Header guards: `AES67_<FILE>_H`.

### API conventions

- Fixed-width integer types for all protocol data (`uint8_t`, `uint16_t`,
  `uint32_t`, `uint64_t`, `int32_t`). No plain `int` for wire data.
- Every function that can fail returns `aes67_err` (`AES67_OK`, …).
  Results go through output parameters.
- Every function that reads external data takes a pointer **and** a length
  and checks every length before access.
- Never cast network buffers to structs. Read and write fields byte by byte
  with the helpers from `bytes.h` (big-endian).
- State lives in context structs allocated by the caller
  (`aes67_rx_ctx` etc.), initialised by an `_init` function.
- Pointers into a caller's receive buffer stay valid only as long as that
  buffer; document this in the header.
- No VLAs, no recursion, no floating point in time-critical paths.
- Every public function has a Doxygen comment: purpose, parameters,
  return values, error cases.

### Integer pitfalls to watch in reviews

- Signed overflow is undefined behaviour; prefer unsigned arithmetic for
  wrap-around (RTP sequence numbers and timestamps).
- Right-shifting negative values and converting out-of-range unsigned
  values to signed types are implementation-defined. Use the portable
  patterns in `docs/plan.md` (L24 sign extension).
- Watch implicit integer promotion of `uint8_t`/`uint16_t` to `int`
  before shifts (`(uint32_t)b << 24`, not `b << 24`).

## Build and test

Presets (see `CMakePresets.json`):

| Preset       | Purpose                                         |
| ------------ | ----------------------------------------------- |
| `host-debug` | GCC, debug, all unit tests                      |
| `host-asan`  | Clang, AddressSanitizer + UBSan, all unit tests |
| `host-fuzz`  | Clang, libFuzzer targets for the parsers        |
| `bbb`        | Yocto SDK, apps for the BeagleBone (source SDK env first) |
| `mcu-check`  | `arm-none-eabi-gcc`, core only, Cortex-M7       |

```bash
cmake --workflow --preset host-debug     # configure, build, test
cmake --workflow --preset host-asan
cmake --preset mcu-check && cmake --build --preset mcu-check
# BeagleBone:
source ~/sdk/bbb/environment-setup-cortexa8hf-neon-poky-linux-gnueabi
cmake --preset bbb && cmake --build --preset bbb
```

Static analysis and formatting:

```bash
clang-format -i $(git ls-files '*.c' '*.h')
clang-tidy -p build/host-debug src/core/*.c
```

Before reporting a review as done: run `host-debug`, `host-asan` and
`mcu-check` (if `arm-none-eabi-gcc` is installed) and clang-tidy, and list
any warnings.

## Repository map

- `include/aes67/` public headers · `src/core/` portable core
- `port/posix/`, `port/zephyr/` platform layers · `apps/` CLI programs
- `tests/unit/` Unity tests · `tests/fuzz/` libFuzzer targets
- `tests/data/` SDP samples and pcap captures from a Dante AVIO
- `tools/` Python helpers · `docs/` plan, API design, ADRs, results
