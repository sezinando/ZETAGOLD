# ZETAGOLD — Static Symbol / Dependency Audit — 2026-09-17

Branch: `refactor/v0.116-engine12-parity`
Reference: `sezinando/modularizedEA` EAGOLD v0.116

## Audit result

The static audit identified a concrete dependency-integrity gap in the refactor branch: `EA/EAGOLD.mq4` referenced three v0.116 files that were not present in the branch tree at the time of inspection:

- `Engines/EAGOLD_R13_Satellite.mqh`
- `UI/EAGOLD_RealizationCascade.mqh`
- `UI/EAGOLD_ChartBasketGuides.mqh`

These were restored from the v0.116 Golden Reference into the refactor branch. The main branch was left without these files; accidental temporary creations on `main` were explicitly removed during cleanup.

## Dependency topology checked

`EA/EAGOLD.mq4` currently composes Core infrastructure, R10 Reconciliation, Engine 1, Engine 2, R13, Persistence and UI. The Engine 1 composition is direct over v0.116 Recovery, Lifecycle and BRX components; Engine 2 is direct over the consolidated v0.116 exposure implementation. Compatibility shims point toward the active engine composition and do not create a reverse include cycle.

## Broker primitive audit

`Core/EAGOLD_Execution.mqh` contains the broker entry/close/delete primitives used by the transactional R1/R7/R9/R10/R13 paths. `Engines/EAGOLD_Engine2_Exposure.mqh` contains no direct `OrderSend`, `OrderClose`, `OrderDelete` or `OrderModify` calls in the inspected implementation. `Engines/EAGOLD_R13_Satellite.mqh` delegates market mutation to Core execution.

One intentional v0.116 parity exception remains in `Engines/EAGOLD_Lifecycle_v0116.mqh`: `TrailAllStopOrders()` calls `OrderModify()` directly. This is preserved because the Golden Reference contains the same trailing implementation; it is not treated as a refactor-time behavior change.

## Action Contract audit

R10 and BRX transactional paths already apply the Action Contract at their authoritative orchestration points. `BuyRecovery()` / `SellRecovery()` apply their own returned result internally and their callers do not apply the same recovery result again. R13 applies the contract to its transactional funding, close and entry paths.

## R1 / R7 authority audit

R1 atomic first admission remains owned by `Core/EAGOLD_R1_AtomicAdmission.mqh`. Engine 1 retains admission policy/lifecycle composition without importing a second atomic transactional authority.

R7 transactional keep-alive remains owned by `Core/EAGOLD_R7_KeepAlive.mqh`. Legacy lifecycle restart helpers remain as parity-compatible lifecycle surface, but Core Execution rejects unauthorized `EAGOLD R7 RESTART` submissions. A completed basket consumes the current tick, so flat re-admission is deferred to the atomic R1 path on a subsequent tick.

## Current gate status

- Static dependency integrity: **CORRECTED** for the missing v0.116 R13/UI files identified in this audit.
- Engine 1 composition: **ALIGNED**.
- Engine 2 composition: **ALIGNED**.
- Core Execution v0.116 parity: **ALIGNED**.
- Compatibility cycles: **NO ACTIVE CYCLE IDENTIFIED** in the inspected engine/shim topology.
- Direct broker mutation: **NO UNEXPECTED ENTRY/CLOSE PATH IDENTIFIED**; trailing `OrderModify()` remains an intentional Golden Reference parity exception.
- MetaEditor compilation: **PENDING** — not executable in this environment.
- Behavioral backtest: **PENDING**.

## Commits from this audit

- R13 Satellite restored on refactor branch: `1a2fcc1da6d02e5026ff9489924a3f7b561ae52e`.
- Realization Cascade UI restored on refactor branch: `f05de4d66abd7245236b825ea74963479740eb3a`.
- Chart Basket Guides UI restored on refactor branch: `ccb64b362ce79644130bc0052d1062bcf67003fd`.
- Temporary accidental files created on `main` were removed in cleanup commits `488be2239cf579d847259d113dbdc32096cbe32a`, `f39d69ac136288bbc2da36faf5be37f8a394d9d7`, and `14e7d70011d255f481e603385508a758c343c6da`.

## Next gate

Proceed to the MetaEditor strict compilation gate. Do not treat the refactor as runtime-validated until `EA/EAGOLD.mq4` compiles cleanly and the v0.116 behavioral regression/backtest comparison is executed.
