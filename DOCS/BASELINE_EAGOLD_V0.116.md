# ZETAGOLD — EAGOLD v0.116 Golden Reference Baseline

## Reference

- Repository: `sezinando/modularizedEA`
- Reference branch: `main`
- Reference root tree: `f8fac2d39d4139570ebbb6503a1a6a42d31efb09`
- Reference EA: `EA/EAGOLD.mq4`
- Reference EA blob: `6814c5e0c8bb8b517c4120d7140ad53de7f8ea02`
- Version: `0.116`

## Rule

EAGOLD v0.116 is the behavioral Golden Reference for ZETAGOLD.

The first reconstruction phase must preserve behavior. No optimization, strategy change, guard insertion, engine aggregation, or semantic rename is permitted until parity has been established.

## Reference structure

```text
Core/
Engines/
Persistence/
EA/
Tests/
UI/
DOCS/
README.md
```

## Economic execution sequence

The V0.116 economic path is preserved in this order:

1. R12 regime observer update
2. excursion / telemetry observers
3. suspend invalid pending entries
4. R10 reconciliation when required
5. R10 recovery state update
6. R9 activated-order transactional detection
7. R7 directional keep-alive
8. BuyMachine()
9. SellMachine()
10. first-order atomic creation
11. trailing of pending stop orders
12. R13 observation / telemetry / UI / persistence

## Critical parity constraints

- R7 directional keep-alive must not require a global market position.
- Directional basket checks use lots where the reference uses `DirectionLots()`.
- Buy and Sell machines remain independently evaluated.
- Transaction outcomes and tick policies must be preserved.
- R10 reconciliation precedes recovery and downstream economic actions.
- First-order creation remains atomic and uses the V0.116 entry distances.

## Next phase

Import the complete source tree from the reference repository into ZETAGOLD without behavioral modification. After the source snapshot is established, perform a compile/parity audit before beginning the ZETAGOLD engine renaming/refactoring phase.
