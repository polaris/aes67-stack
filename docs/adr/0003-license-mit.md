# 0003: MIT license

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

The repository is public. Without a license, nobody may legally use, copy or
modify the code, which defeats the purpose of a showcase project. The plan
named two candidates that are both common for embedded code:

- **MIT:** very short, permissive, widely understood.
- **Apache-2.0:** permissive, longer, with an explicit patent grant and a
  `NOTICE` mechanism.

## Decision

MIT. The full text is in `LICENSE` at the repository root.

## Consequences

- Anyone can use the code, including in closed-source products, as long as
  the copyright notice is kept.
- There is no explicit patent grant. For a learning and showcase project
  without patent claims this is acceptable.
- Third-party code keeps its own license. Unity (fetched at configure time,
  test-only) is MIT as well; it is not part of the shipped library.
