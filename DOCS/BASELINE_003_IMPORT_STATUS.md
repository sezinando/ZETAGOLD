# BASELINE-003 — EAGOLD v0.116 source import status

## Reference

Golden Reference repository: `sezinando/modularizedEA`
Reference tree: `f8fac2d39d4139570ebbb6503a1a6a42d31efb09`
Reference EA: `EA/EAGOLD.mq4`
Reference EA blob: `6814c5e0c8bb8b517c4120d7140ad53de7f8ea02`

## Import policy

The V0.116 source must be imported without behavioral modification before any ZETAGOLD refactoring.

The Git data API required for an atomic tree import is available, but source blobs belong to the reference repository and cannot be reused directly in the target repository. They must first be materialized as target-repository blobs. The repository therefore remains at the clean BASELINE-002 control point until the complete source tree can be transferred without leaving a partial executable state.

## Verified source areas

- `EA/EAGOLD.mq4`
- `Core/`
- `Engines/`
- `Persistence/`
- `UI/`
- `Tests/`
- `DOCS/`

## Critical parity rule

Do not implement ZETAGOLD logic by approximation. Preserve the V0.116 execution sequence and transactional semantics first. In particular, R7, R10 reconciliation, independent BUY/SELL machines, lifecycle recovery, BRX realization, and the action-contract tick policy are part of the reference behavior.

## Next operation

Complete source-tree transfer, then perform a file-by-file SHA/content parity audit before beginning `BASELINE-004`.
