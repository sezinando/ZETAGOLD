#ifndef EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH
#define EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH

//==================================================================
// ENGINE 1 — LIFECYCLE & RECOVERY
// ZETAGOLD / EAGOLD v0.116 parity composition layer.
//
// This file establishes ownership without redesigning economic rules.
// The underlying v0.116 implementations remain authoritative:
//   - R1 admission / atomic first seed
//   - R4 single realization
//   - R5 / BRX basket realization
//   - R7 keep-alive
//   - Recovery / R10.2 accounting
//   - R11 dynamic recovery step
//   - global pending trailing
//   - BUY/SELL lifecycle orchestration
//
// Core broker mutation primitives remain in Core/Execution.
// Action Contract and Reconciliation remain cross-cutting infrastructure.
//==================================================================

// R1 admission predicates are consumed by the atomic first-seed transaction.
#include "EAGOLD_R1_Admission.mqh"

// Recovery contains R10.2 recovery state and the dynamic recovery step (R11).
#include "EAGOLD_Recovery.mqh"

// Lifecycle contains R4/R5/BRX realization, global pending trailing,
// compatibility lifecycle helpers, and BUY/SELL machine orchestration.
#include "EAGOLD_Lifecycle.mqh"

// Atomic R1 is the sole flat-cycle first-seed authority in v0.116.
#include "../Core/EAGOLD_R1_AtomicAdmission.mqh"

// R7 is the transactional missing-direction restart authority.
#include "../Core/EAGOLD_R7_KeepAlive.mqh"

#endif
