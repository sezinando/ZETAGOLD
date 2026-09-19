#ifndef EAGOLD_R10_V2_EXECUTION_ADAPTER_MQH
#define EAGOLD_R10_V2_EXECUTION_ADAPTER_MQH

//==================================================================
// R10 v2 — EXECUTION ADAPTER
// ETAPA 13.19 / 13.20
//
// R10 v2 is bridged to the broker only through Execution Core.
// Balanced execution is bilateral but NOT atomic: each OrderClose
// is an independent broker mutation and the result of leg 1 is
// recorded before leg 2 is attempted.
//
// Reconciliation remains the authority for the broker-visible state
// after any partial bilateral result.
//==================================================================

// Re-entry guard. It is deliberately local to the execution adapter:
// once a broker mutation occurs, the same contract cannot be submitted
// again until the next broker census/reconciliation boundary.
bool g_r10V2ExecutionAwaitingReconciliation=false;
datetime g_r10V2LastExecutionTimestamp=0;
int g_r10V2LastExecutionTicket=-1;
int g_r10V2LastExecutionTicket2=-1;
double g_r10V2LastExecutionLots=0.0;

void EAGOLD_R10V2ExecutionResetAfterReconciliation()
{
   g_r10V2ExecutionAwaitingReconciliation=false;
}

bool EAGOLD_R10V2ExecutionDuplicate(const EAGOLD_R10V2DecisionContract &contract)
{
   if(g_r10V2ExecutionAwaitingReconciliation)
      return(true);

   if(contract.timestamp!=g_r10V2LastExecutionTimestamp)
      return(false);
   if(contract.targetTicket!=g_r10V2LastExecutionTicket)
      return(false);
   if(contract.targetTicket2!=g_r10V2LastExecutionTicket2)
      return(false);
   if(MathAbs(contract.authorizedLots-g_r10V2LastExecutionLots)>Lot*0.5)
      return(false);

   return(true);
}

void EAGOLD_R10V2ExecutionMark(
   const EAGOLD_R10V2DecisionContract &contract,
   bool requiresReconciliation)
{
   g_r10V2LastExecutionTimestamp=contract.timestamp;
   g_r10V2LastExecutionTicket=contract.targetTicket;
   g_r10V2LastExecutionTicket2=contract.targetTicket2;
   g_r10V2LastExecutionLots=contract.authorizedLots;
   g_r10V2ExecutionAwaitingReconciliation=requiresReconciliation;
}

EAGOLD_ActionResult EAGOLD_R10V2ExecuteSingle(
   const EAGOLD_R10V2DecisionContract &contract,
   bool preExecutionGate)
{
   if(!preExecutionGate || !contract.executionEligible)
      return(EAGOLD_ACTION_BLOCKED);
   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED ||
      contract.action!=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE)
      return(EAGOLD_ACTION_BLOCKED);

   if(EAGOLD_R10V2ExecutionDuplicate(contract))
      return(EAGOLD_ACTION_BLOCKED);
   if(contract.opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return(EAGOLD_ACTION_BLOCKED);
   if(contract.targetTicket<0 ||
      (contract.direction!=OP_BUY && contract.direction!=OP_SELL) ||
      contract.targetTicket2>=0 ||
      contract.authorizedLots<Lot)
      return(EAGOLD_ACTION_BLOCKED);

   if(!OrderSelect(contract.targetTicket,SELECT_BY_TICKET,MODE_TRADES))
      return(EAGOLD_ACTION_BLOCKED);
   if(!IsEAGOLDOrder() || OrderSymbol()!=Symbol() ||
      OrderMagicNumber()!=MagicNumber || OrderType()!=contract.direction ||
      OrderLots()+Lot*0.5<contract.authorizedLots)
      return(EAGOLD_ACTION_BLOCKED);

   bool reservationCreated=false;
   if(contract.capitalReservationRequired>0.0 &&
      !EAGOLD_R10V2CapitalReservationActive())
   {
      if(!EAGOLD_R10V2CapitalReserveTransaction(
            contract.capitalReservationRequired,
            contract.targetTicket,
            contract.targetTicket2,
            contract.timestamp))
         return(EAGOLD_ACTION_BLOCKED);
      reservationCreated=true;
   }

   if(contract.capitalReservationRequired>0.0 &&
      !EAGOLD_R10V2CapitalReservationMatches(
         contract.targetTicket,
         contract.targetTicket2,
         contract.capitalReservationRequired))
   {
      if(reservationCreated)
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_BLOCKED);
   }

   double realized=0.0;
   if(!CloseMarketOrderLots(contract.targetTicket,contract.authorizedLots,realized))
   {
      if(EAGOLD_R10V2CapitalReservationActive())
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_FAILED);
   }

   if(EAGOLD_R10V2CapitalReservationActive())
   {
      double consumed=MathMax(0.0,-realized);
      if(consumed>0.0)
         EAGOLD_R10V2CapitalConsumeReservation(consumed);
      else
         EAGOLD_R10V2CapitalReleaseTransaction();
   }

   EAGOLD_R10V2ExecutionMark(contract,true);
   return(EAGOLD_ACTION_PARTIAL);
}

// ETAPA 13.20 — Balanced bilateral execution.
//
// No atomicity is assumed. Leg 2 is attempted only after leg 1 has
// returned from the broker. Any one-leg result is PARTIAL and therefore
// forces the existing reconciliation boundary.
EAGOLD_ActionResult EAGOLD_R10V2ExecuteBalanced(
   const EAGOLD_R10V2DecisionContract &contract,
   bool preExecutionGate)
{
   if(!preExecutionGate || !contract.executionEligible)
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED ||
      contract.action!=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE ||
      contract.opportunity!=EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return(EAGOLD_ACTION_BLOCKED);

   if(EAGOLD_R10V2ExecutionDuplicate(contract))
      return(EAGOLD_ACTION_BLOCKED);

   if(contract.targetTicket<0 || contract.targetTicket2<0 ||
      contract.targetTicket==contract.targetTicket2 ||
      contract.direction!=OP_BUY ||
      contract.authorizedLots<Lot)
      return(EAGOLD_ACTION_BLOCKED);

   bool reservationCreated=false;
   if(contract.capitalReservationRequired>0.0 &&
      !EAGOLD_R10V2CapitalReservationActive())
   {
      if(!EAGOLD_R10V2CapitalReserveTransaction(
            contract.capitalReservationRequired,
            contract.targetTicket,
            contract.targetTicket2,
            contract.timestamp))
         return(EAGOLD_ACTION_BLOCKED);
      reservationCreated=true;
   }

   if(contract.capitalReservationRequired>0.0 &&
      !EAGOLD_R10V2CapitalReservationMatches(
         contract.targetTicket,
         contract.targetTicket2,
         contract.capitalReservationRequired))
   {
      if(reservationCreated)
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_BLOCKED);
   }

   // Revalidate BUY immediately before leg 1.
   if(!OrderSelect(contract.targetTicket,SELECT_BY_TICKET,MODE_TRADES))
      return(EAGOLD_ACTION_BLOCKED);
   if(!IsEAGOLDOrder() || OrderSymbol()!=Symbol() ||
      OrderMagicNumber()!=MagicNumber || OrderType()!=OP_BUY ||
      OrderLots()+Lot*0.5<contract.authorizedLots)
   {
      if(reservationCreated)
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_BLOCKED);
   }

   // Leg 1: BUY. Execution Core is authoritative.
   double realizedBuy=0.0;
   bool buyOk=CloseMarketOrderLots(
      contract.targetTicket,
      contract.authorizedLots,
      realizedBuy);

   if(!buyOk)
   {
      if(EAGOLD_R10V2CapitalReservationActive())
         EAGOLD_R10V2CapitalReleaseTransaction();
      return(EAGOLD_ACTION_FAILED);
   }

   // The first broker mutation succeeded. Re-read the second ticket
   // before attempting leg 2; never assume it is still executable.
   bool sellValid=false;
   if(OrderSelect(contract.targetTicket2,SELECT_BY_TICKET,MODE_TRADES))
   {
      if(IsEAGOLDOrder() &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber &&
         OrderType()==OP_SELL &&
         OrderLots()+Lot*0.5>=contract.authorizedLots)
         sellValid=true;
   }

   double realizedSell=0.0;
   bool sellOk=false;
   if(sellValid)
      sellOk=CloseMarketOrderLots(
         contract.targetTicket2,
         contract.authorizedLots,
         realizedSell);

   if(!sellOk)
   {
      // The BUY leg exists in broker state, while SELL does not.
      // Do not fabricate symmetry. The reconciliation engine receives
      // the PARTIAL boundary and rebuilds the real state on next tick.
      if(EAGOLD_R10V2CapitalReservationActive())
      {
         double consumed=MathMax(0.0,-realizedBuy);
         if(consumed>0.0)
            EAGOLD_R10V2CapitalConsumeReservation(consumed);
         else
            EAGOLD_R10V2CapitalReleaseTransaction();
      }
      EAGOLD_R10V2ExecutionMark(contract,true);
      return(EAGOLD_ACTION_PARTIAL);
   }

   // Both legs executed. Capital is reconciled from the combined
   // realized result. Any unused reservation is released.
   if(EAGOLD_R10V2CapitalReservationActive())
   {
      double combinedRealized=realizedBuy+realizedSell;
      double consumed=MathMax(0.0,-combinedRealized);
      if(consumed>0.0)
         EAGOLD_R10V2CapitalConsumeReservation(consumed);
      else
         EAGOLD_R10V2CapitalReleaseTransaction();
   }

   // Even with both legs successful, the action changed broker state.
   // Returning COMPLETED consumes the current economic tick.
   EAGOLD_R10V2ExecutionMark(contract,false);
   return(EAGOLD_ACTION_COMPLETED);
}

#endif
