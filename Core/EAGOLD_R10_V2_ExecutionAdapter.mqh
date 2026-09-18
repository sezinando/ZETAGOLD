#ifndef EAGOLD_R10_V2_EXECUTION_ADAPTER_MQH
#define EAGOLD_R10_V2_EXECUTION_ADAPTER_MQH

//==================================================================
// R10 v2 — EXECUTION ADAPTER
// ETAPA 13.19
//
// Converts a validated, execution-eligible R10 v2 contract into an
// Execution Core operation.
//
// This is the ONLY R10 v2 layer allowed to bridge the decision
// contract to broker mutation.
//
// ETAPA 13.19 intentionally supports SINGLE-TARGET partial close.
// Balanced bilateral execution is reserved for ETAPA 13.20 so that
// two-leg partial execution can be reconciled explicitly.
//
// This module does NOT:
//   - choose the opportunity
//   - choose the target
//   - calculate capacity
//   - call R11
//   - alter Recovery State / R13
//==================================================================

EAGOLD_ActionResult EAGOLD_R10V2ExecuteSingle(
   const EAGOLD_R10V2DecisionContract &contract,
   bool preExecutionGate)
{
   if(!preExecutionGate)
      return(EAGOLD_ACTION_BLOCKED);

   if(!contract.executionEligible)
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED)
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.action!=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE)
      return(EAGOLD_ACTION_BLOCKED);

   // Balanced execution is deliberately held for the bilateral
   // adapter/reconciliation stage.
   if(contract.opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.targetTicket<0 ||
      (contract.direction!=OP_BUY && contract.direction!=OP_SELL))
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.authorizedLots<Lot)
      return(EAGOLD_ACTION_BLOCKED);

   // Capital is reserved immediately before broker mutation.
   // Zero projected loss requires no capital reservation.
   if(contract.capitalReservationRequired>0.0 &&
      !EAGOLD_R10V2CapitalReservationActive())
   {
      if(!EAGOLD_R10V2CapitalReserveTransaction(
            contract.capitalReservationRequired,
            contract.targetTicket,
            contract.targetTicket2,
            contract.timestamp))
         return(EAGOLD_ACTION_BLOCKED);
   }

   double realized=0.0;
   if(!CloseMarketOrderLots(contract.targetTicket,contract.authorizedLots,realized))
   {
      if(EAGOLD_R10V2CapitalReservationActive())
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_FAILED);
   }

   // The broker result is authoritative. Consume only the realized
   // loss funded by the reservation; release any unused reservation.
   if(EAGOLD_R10V2CapitalReservationActive())
   {
      double consumed=MathMax(0.0,-realized);
      if(consumed>0.0)
         EAGOLD_R10V2CapitalConsumeReservation(consumed);
      else
         EAGOLD_R10V2CapitalReleaseTransaction();
   }

   // A partial close is always reconciled by the existing R10
   // reconciliation boundary before another economic action.
   return(EAGOLD_ACTION_PARTIAL);
}

#endif
