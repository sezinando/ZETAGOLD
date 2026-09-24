#ifndef EAGOLD_R10_V2_SAFETY_AUDIT_MQH
#define EAGOLD_R10_V2_SAFETY_AUDIT_MQH

//==================================================================
// R10 v2 — SAFETY INVARIANT AUDIT
// ETAPA 13.28
//
// Runtime read-only audit. It never executes, reserves, consumes,
// repairs, or changes broker state.
//==================================================================

enum EAGOLD_R10V2SafetyReason
{
   EAGOLD_R10V2_SAFETY_OK=0,
   EAGOLD_R10V2_SAFETY_OWNERSHIP_BREACH,
   EAGOLD_R10V2_SAFETY_EXPOSURE_BREACH,
   EAGOLD_R10V2_SAFETY_CONTRACT_BREACH,
   EAGOLD_R10V2_SAFETY_CAPITAL_BREACH,
   EAGOLD_R10V2_SAFETY_RESERVATION_BREACH,
   EAGOLD_R10V2_SAFETY_RECONCILIATION_BREACH
};

string EAGOLD_R10V2SafetyReasonName(EAGOLD_R10V2SafetyReason reason)
{
   if(reason==EAGOLD_R10V2_SAFETY_OWNERSHIP_BREACH)return("OWNERSHIP_BREACH");
   if(reason==EAGOLD_R10V2_SAFETY_EXPOSURE_BREACH)return("EXPOSURE_BREACH");
   if(reason==EAGOLD_R10V2_SAFETY_CONTRACT_BREACH)return("CONTRACT_BREACH");
   if(reason==EAGOLD_R10V2_SAFETY_CAPITAL_BREACH)return("CAPITAL_BREACH");
   if(reason==EAGOLD_R10V2_SAFETY_RESERVATION_BREACH)return("RESERVATION_BREACH");
   if(reason==EAGOLD_R10V2_SAFETY_RECONCILIATION_BREACH)return("RECONCILIATION_BREACH");
   return("OK");
}

bool EAGOLD_R10V2SafetyAudit(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2DecisionContract &contract,
   EAGOLD_R10V2SafetyReason &reason)
{
   reason=EAGOLD_R10V2_SAFETY_OK;

   if(ctx.buyLots<0.0 || ctx.sellLots<0.0 ||
      ctx.grossExposure<0.0)
   {
      reason=EAGOLD_R10V2_SAFETY_EXPOSURE_BREACH;
      return(false);
   }

   double expectedGross=ctx.buyLots+ctx.sellLots;
   if(MathAbs(ctx.grossExposure-expectedGross)>Lot*0.5)
   {
      reason=EAGOLD_R10V2_SAFETY_EXPOSURE_BREACH;
      return(false);
   }

   double expectedNet=MathAbs(ctx.buyLots-ctx.sellLots);
   if(MathAbs(ctx.netExposure-expectedNet)>Lot*0.5)
   {
      reason=EAGOLD_R10V2_SAFETY_EXPOSURE_BREACH;
      return(false);
   }

   if(contract.authorizedLots<0.0 ||
      contract.desiredLots<0.0 ||
      contract.candidateLots<0.0)
   {
      reason=EAGOLD_R10V2_SAFETY_CONTRACT_BREACH;
      return(false);
   }

   if(contract.authorizedLots>contract.desiredLots+Lot*0.5 ||
      contract.desiredLots>contract.candidateLots+Lot*0.5)
   {
      reason=EAGOLD_R10V2_SAFETY_CONTRACT_BREACH;
      return(false);
   }

   if(contract.capitalCapacity<0.0 ||
      contract.exposureCapacity<0.0 ||
      contract.r11Capacity<0.0 ||
      contract.brokerCapacity<0.0)
   {
      reason=EAGOLD_R10V2_SAFETY_CAPITAL_BREACH;
      return(false);
   }

   if(contract.authorizedLots>contract.capitalCapacity+Lot*0.5 ||
      contract.authorizedLots>contract.exposureCapacity+Lot*0.5 ||
      contract.authorizedLots>contract.r11Capacity+Lot*0.5 ||
      contract.authorizedLots>contract.brokerCapacity+Lot*0.5)
   {
      reason=EAGOLD_R10V2_SAFETY_CAPITAL_BREACH;
      return(false);
   }

   if(g_r10V2CapitalLedger.capitalReserved<0.0 ||
      g_r10V2CapitalLedger.capitalConsumed<0.0 ||
      g_r10V2CapitalLedger.capitalRemaining<0.0)
   {
      reason=EAGOLD_R10V2_SAFETY_RESERVATION_BREACH;
      return(false);
   }

   if(g_r10V2CapitalLedger.reservationActive &&
      g_r10V2CapitalLedger.reservationAmount<=0.0)
   {
      reason=EAGOLD_R10V2_SAFETY_RESERVATION_BREACH;
      return(false);
   }

   if(EAGOLD_R10ReconciliationRequired() &&
      g_eagoldTickPolicy!=EAGOLD_TICK_HALT_FOR_RECONCILIATION)
   {
      reason=EAGOLD_R10V2_SAFETY_RECONCILIATION_BREACH;
      return(false);
   }

   return(true);
}

#endif
