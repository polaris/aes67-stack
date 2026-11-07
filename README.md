# aes67-stack

[![CI](https://github.com/polaris/aes67-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/polaris/aes67-stack/actions/workflows/ci.yml)

A small, portable AES67 implementation in C11, written as a learning and
showcase project. The goal is to receive and send AES67 audio streams on an
embedded Linux board, interoperating with Dante devices in AES67 mode, with a
core that also builds for Cortex-M microcontrollers.

> **Status:** Phase 1 – project scaffold. Nothing usable yet.
> See [docs/plan.md](docs/plan.md) for the roadmap.

## What it covers

| Area | Content | Phase |
| --- | --- | --- |
| Discovery | SAP announcements (RFC 2974), SDP parsing and writing (RFC 8866) | 2, 6 |
| Transport | RTP header parsing, loss/reorder/jitter statistics (RFC 3550) | 3 |
| Audio | L24 PCM conversion, WAV capture | 4 |
| Timing | Mapping between PTP time and RTP timestamps, packet latency | 5 |
| Sending | 1 kHz test tone as an AES67 stream, received by a Dante AVIO | 6 |

## Design

- **Portable core** (`src/core/`): no OS calls, no dynamic memory, no global
  state. Fixed-size buffers provided by the caller.
- **Platform layer** (`port/`): POSIX for Linux now, Zephyr later.
- **Command-line apps** (`apps/`): `aes67-sapdump`, `aes67-rx`, `aes67-tx`.

Details: [docs/api-design.md](docs/api-design.md). Decisions:
[docs/adr/](docs/adr/).

## Test setup

| Device | Role |
| --- | --- |
| BeagleBone Black (TI AM335x, Yocto 6.0) | Linux target, PTP follower with hardware timestamps |
| 2 × Dante AVIO USB (AES67 mode) | Reference sender/receiver and PTP grandmaster |
| Cisco SG250-08 | Managed switch: DSCP QoS, IGMP snooping, port mirroring |
| NUCLEO-H753ZI + Pmod I2S2 | Future microcontroller target (Cortex-M7) |

The Yocto layer and lab setup live in a separate repository:
[bbb-aes67-lab](https://github.com/polaris/bbb-aes67-lab).
Measured PTP sync against the AVIO: 20–50 ns RMS offset.

## Building

Requirements: CMake ≥ 3.25, Ninja, GCC, Clang (with compiler-rt),
`arm-none-eabi-gcc` for the microcontroller check.

```bash
cmake --workflow --preset host-debug   # GCC: configure, build, unit tests
cmake --workflow --preset host-asan    # Clang with AddressSanitizer + UBSan
cmake --workflow --preset mcu-check    # core only, Cortex-M7
```

BeagleBone (Yocto SDK):

```bash
source ~/sdk/bbb/environment-setup-cortexa8hf-neon-poky-linux-gnueabi
cmake --preset bbb && cmake --build --preset bbb
```

Fuzzing the parsers (Clang/libFuzzer):

```bash
cmake --preset host-fuzz && cmake --build --preset host-fuzz
```

## Results

Write-ups with measurements per phase: [docs/results/](docs/results/).

## License

TBD (MIT or Apache-2.0).
