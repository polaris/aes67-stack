# API design

> **Status: skeleton.** Sections marked *TODO (phase 1B)* are drafted by
> Claude Code in a single session and then reviewed and approved by Jan.
> Approved parts may only change with an ADR in `docs/adr/`.

## 1. Scope

This document is the binding contract for the public headers in
`include/aes67/`. It defines conventions, buffer rules and the module
structure. `CLAUDE.md` summarises the rules; this document explains them.

## 2. Conventions

### 2.1 Naming

- Functions and types: `aes67_<module>_<verb>`, `snake_case`
  (e.g. `aes67_rtp_parse`, `aes67_sdp_write`).
- Macros and enum constants: `AES67_<NAME>`.
- Header guards: `AES67_<FILE>_H`.

### 2.2 Types

- Fixed-width integer types for all protocol fields.
- `size_t` for buffer lengths and counts.
- `bool` from `<stdbool.h>` for flags.

### 2.3 Error handling

- Every fallible function returns `aes67_err`; `AES67_OK` is 0.
- Results are returned through output parameters. On error, output
  parameters are left unchanged unless documented otherwise.
- Planned error codes (final list: *TODO (phase 1B)*):

| Code | Meaning |
| --- | --- |
| `AES67_OK` | Success |
| `AES67_ERR_INVALID_ARG` | NULL pointer or invalid argument |
| `AES67_ERR_TRUNCATED` | Input shorter than the protocol requires |
| `AES67_ERR_INVALID` | Input is malformed or violates the protocol |
| `AES67_ERR_UNSUPPORTED` | Valid, but not supported (e.g. other version) |
| `AES67_ERR_NO_SPACE` | Output buffer too small |
| `AES67_ERR_NOT_IMPLEMENTED` | Stub, not implemented yet |

## 3. Buffer and memory rules

- The core never allocates. The caller provides all memory.
- Every input is passed as pointer **and** length; every length is checked
  before access.
- Network data is read and written byte by byte with `bytes.h`; buffers are
  never cast to structs.
- Parsers may return pointers into the caller's input buffer (zero copy).
  These pointers are valid only as long as that buffer. Each such function
  documents this.
- Writers fill a caller buffer and return the number of bytes written through
  an output parameter; on `AES67_ERR_NO_SPACE` nothing is guaranteed about the
  buffer contents.

*TODO (phase 1B): exact rules for strings in SDP (length-bounded views vs.
copied fixed-size fields).*

## 4. Context structs

- State lives in structs allocated by the caller (stack or static storage).
- Each context has `aes67_<module>_init()`; no other initialisation is valid.
- Struct members are visible in the header (needed for caller allocation) but
  are not part of the API unless documented.

## 5. Platform interface

The core does not call the platform. The platform layer (`port/`) and the
apps call the core. `include/aes67/platform.h` defines what a port must
provide to the apps (sockets, clock).

*TODO (phase 1B): function list of `platform.h` (socket open/join/send/recv,
PTP time, receive timestamps).*

## 6. Modules

| Module | Header | Purpose | Phase | Status |
| --- | --- | --- | --- | --- |
| errors | `err.h` | `aes67_err` enum | 1 | TODO |
| bytes | `bytes.h` | Big-endian read/write helpers | 1 | TODO |
| sap | `sap.h` | Parse and write SAP messages | 2 / 6 | TODO |
| sdp | `sdp.h` | Parse and write AES67 SDP | 2 / 6 | TODO |
| rtp | `rtp.h` | Parse and write RTP headers, stream statistics | 3 / 6 | TODO |
| pcm | `pcm.h` | L24 ↔ int32 conversion | 4 | TODO |
| mediaclock | `mediaclock.h` | PTP time ↔ RTP timestamp | 5 | Draft later |
| platform | `platform.h` | Interface for ports | 2 | TODO |

Dependencies: *TODO (phase 1B), as a short diagram or list.*

## 7. Module specifications

*TODO (phase 1B): one subsection per module with types, functions, error
cases and invariants.*

## 8. Proposed test cases

*TODO (phase 1B): per module, a list of test cases including edge cases
(truncated input, wrong version, overflow, wrap-around, maximum sizes).*

## 9. Open questions

- Which PTP time scale do the Dante AVIOs use for RTP timestamps (TAI vs.
  UTC)? To be measured in phase 5.
- Dante writes `a=recvonly` for a sending flow. The SDP parser must not rely
  on the direction attribute.
