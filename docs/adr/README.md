# Architecture decision records

Short records of decisions someone else might question. One file per
decision, numbered, never renumbered. A decision that is replaced keeps its
file; its status changes to *Superseded by NNNN*.

Format per record: **Status**, **Context**, **Decision**, **Consequences**.

| No. | Decision | Status |
| --- | --- | --- |
| [0001](0001-version-single-source.md) | `version.h` is the single source of the version number | Accepted |
| [0002](0002-host-debug-without-optimisation.md) | `host-debug` stays at `-O0`; optimisation-dependent warnings come from `mcu-check` | Accepted |
| [0003](0003-license-mit.md) | MIT license | Accepted |
