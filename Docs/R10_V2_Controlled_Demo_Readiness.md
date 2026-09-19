# R10 v2 — Controlled Demo Readiness

## Purpose

This document defines the boundary for a controlled MT4 demo validation. It does not authorize production use.

## Required explicit switches

- P09_11_R10V2EnableMode = 2 (CONTROLLED)
- P09_12_R10V2PreLiveEnable = true

Both remain OFF by default in the repository.

## Mandatory gates

1. Decision Contract = AUTHORIZED
2. PreExecution = PASS
3. Safety Audit = PASS
4. PreLive Gate = PASS
5. PreLive Validation = PASS
6. Reconciliation = CLEAR
7. Duplicate guard = CLEAR
8. Capital capacity >= authorized reduction
9. R11 capacity >= authorized reduction
10. Broker capacity >= authorized reduction
11. Controlled execution boundary arms executionEligible=true
12. Execution proceeds only through the existing Execution Adapter / Execution Core

## Operational restriction

The repository does not automatically switch to CONTROLLED. A demo run requires an explicit parameter change in MT4 and an independent compile/runtime verification.

## Stop conditions

Any execution failure, partial bilateral execution, reconciliation requirement, ownership breach, capital reservation inconsistency, or safety audit failure must keep the tick halted/blocked according to the existing Action Contract and reconciliation policy.

## Production status

NOT APPROVED BY THIS DOCUMENT. Demo validation is a separate empirical stage; production deployment requires a later review of observed behavior and telemetry.