#ifndef EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH
#define EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH

//==================================================================
// ENGINE 1 — LIFECYCLE & RECOVERY
// ZETAGOLD / EAGOLD v0.116 parity composition layer.
//
// This file establishes ownership without redesigning economic rules.
// The underlying consolidated lifecycle/recovery implementation remains
// authoritative for the v0.116-compatible behavior:
//   - R1 admission support
//   - R4 single realization
//   - R5 / BRX basket realization
//   - R7 lifecycle/keep-alive compatibility
//   - Recovery / R10.2 accounting
//   - R11 dynamic recovery step
//   - global pending trailing
//   - BUY/SELL lifecycle orchestration
//
// Core broker mutation primitives remain in Core/Execution.
// Action Contract and Reconciliation remain cross-cutting infrastructure.
//
// The implementation is included directly to avoid a compatibility-shim
// cycle (R1/Recovery/Lifecycle -> Engine1 -> R1/Recovery/Lifecycle).
// Transactional v0.116 R1 and R7 authorities are layered explicitly below.
//==================================================================

#include "EAGOLD_Engine1_LifecycleRecovery.mqh"
#include "../Core/EAGOLD_R1_AtomicAdmission.mqh"
#include "../Core/EAGOLD_R7_KeepAlive.mqh"

#endif
