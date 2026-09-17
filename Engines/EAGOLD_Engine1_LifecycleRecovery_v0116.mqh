#ifndef EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH
#define EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_V0116_MQH

// ENGINE 1 — LIFECYCLE & RECOVERY — v0.116 parity composition.
// Economic ownership is kept here; Core remains broker infrastructure.
//
// R1 atomic admission and R7 keep-alive are cross-cutting transactional
// authorities owned by Core. Engine 1 retains the lifecycle decision surface
// and legacy compatibility functions, but does not include those Core
// authorities here. This prevents duplicate admission/restart authorities.

#include "EAGOLD_Recovery_v0116.mqh"
#include "EAGOLD_Lifecycle_v0116.mqh"
#include "EAGOLD_BRX.mqh"

#endif
