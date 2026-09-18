#ifndef EAGOLD_R10_V2_CONTRACT_VALIDATION_MQH
#define EAGOLD_R10_V2_CONTRACT_VALIDATION_MQH

//==================================================================
// R10 v2 — DECISION CONTRACT VALIDATION / PRE-EXECUTION GATE
// ETAPA 13.17
//
// Validates the complete decision contract before any future
// execution handoff. This module is a gate, not an executor.
//
// It does NOT:
//   - call OrderClose / OrderSend / OrderDelete
//   - reserve or consume capital
//   - call R11
//   - alter Recovery State / R13
//   - set executionEligible
//
// The gate validates coherence only. A valid contract remains
// execution-disabled until a later stage explicitly opens the
// execution boundary.
//==================================================================

enum EAGOLD_R10V2ValidationReason
{
   EAGOLD_R10V2_VALIDATION_OK = 0,
   EAGOLD_R10V2_VALIDATION_NO_OPPORTUNITY,
   EAGOLD_R10V2_VALIDATION_STATE_MISMATCH,
   EAGOLD_R10V2_VALIDATION_ACTION_MISMATCH,
   EAGOLD_R10V2_VALIDATION_TARGET_INVALID,
   EAGOLD_R10V2_VALIDATION_OPPORTUNITY_MISMATCH,
   EAGOLD_R10V2_VALIDATION_LOTS_INCOHERENT,
   EAGOLD_R10V2_VALIDATION_CAPACITY_BREACH,
   EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH,
   EAGOLD_R10V2_VALIDATION_BALANCED_NET_BREACH,
   EAGOLD_R10V2_VALIDATION_CAPITAL_INVALID
};

string EAGOLD_R10V2ValidationReasonName(EAGOLD_R10V2ValidationReason reason)
{
   if(reason==EAGOLD_R10V2_VALIDATION_NO_OPPORTUNITY) return("NO_OPPORTUNITY");
   if(reason==EAGOLD_R10V2_VALIDATION_STATE_MISMATCH) return("STATE_MISMATCH");
   if(reason==EAGOLD_R10V2_VALIDATION_ACTION_MISMATCH) return("ACTION_MISMATCH");
   if(reason==EAGOLD_R10V2_VALIDATION_TARGET_INVALID) return("TARGET_INVALID");
   if(reason==EAGOLD_R10V2_VALIDATION_OPPORTUNITY_MISMATCH) return("OPPORTUNITY_MISMATCH");
   if(reason==EAGOLD_R10V2_VALIDATION_LOTS_INCOHERENT) return("LOTS_INCOHERENT");
   if(reason==EAGOLD_R10V2_VALIDATION_CAPACITY_BREACH) return("CAPACITY_BREACH");
   if(reason==EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH) return("PROJECTION_MISMATCH");
   if(reason==EAGOLD_R10V2_VALIDATION_BALANCED_NET_BREACH) return("BALANCED_NET_BREACH");
   if(reason==EAGOLD_R10V2_VALIDATION_CAPITAL_INVALID) return("CAPITAL_INVALID");
   return("OK");
}

bool EAGOLD_R10V2ValidationNear(double a,double b,double tolerance)
{
   return(MathAbs(a-b)<=tolerance);
}

bool EAGOLD_R10V2ValidationOwnedTicket(int ticket,int expectedDirection)
{
   if(ticket<0)return(false);
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(OrderSymbol()!=Symbol())return(false);
   if(OrderMagicNumber()!=Magic)return(false);
   if(OrderType()!=expectedDirection)return(false);
   if(OrderLots()<Lot)return(false);
   return(true);
}

// Structural pre-execution validation.
// A TRUE result means the contract is coherent enough for a future
// execution adapter; it does NOT authorize broker mutation here.
bool EAGOLD_R10V2ValidatePreExecution(
   const EAGOLD_R10V2DecisionContract &contract,
   const EAGOLD_R10V2Context &ctx,
   EAGOLD_R10V2ValidationReason &reason)
{
   reason=EAGOLD_R10V2_VALIDATION_OK;

   if(contract.opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      if(contract.state!=EAGOLD_R10V2_DECISION_NO_OPPORTUNITY ||
         contract.action!=EAGOLD_R10V2_HANDOFF_NONE ||
         contract.authorizedLots>0.0)
      {
         reason=EAGOLD_R10V2_VALIDATION_STATE_MISMATCH;
         return(false);
      }
      reason=EAGOLD_R10V2_VALIDATION_NO_OPPORTUNITY;
      return(true);
   }

   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED)
      return(true);

   if(contract.action!=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE)
   {
      reason=EAGOLD_R10V2_VALIDATION_ACTION_MISMATCH;
      return(false);
   }

   if(contract.targetTicket<0)
   {
      reason=EAGOLD_R10V2_VALIDATION_TARGET_INVALID;
      return(false);
   }

   if(contract.candidateLots<Lot ||
      contract.desiredLots<Lot ||
      contract.authorizedLots<Lot)
   {
      reason=EAGOLD_R10V2_VALIDATION_LOTS_INCOHERENT;
      return(false);
   }

   if(contract.desiredLots>contract.candidateLots+Lot*0.5 ||
      contract.authorizedLots>contract.desiredLots+Lot*0.5)
   {
      reason=EAGOLD_R10V2_VALIDATION_LOTS_INCOHERENT;
      return(false);
   }

   if(contract.capitalCapacity+Lot*0.5<contract.authorizedLots ||
      contract.exposureCapacity+Lot*0.5<contract.authorizedLots ||
      contract.r11Capacity+Lot*0.5<contract.authorizedLots ||
      contract.brokerCapacity+Lot*0.5<contract.authorizedLots)
   {
      reason=EAGOLD_R10V2_VALIDATION_CAPACITY_BREACH;
      return(false);
   }

   if(contract.capitalReservationRequired<0.0)
   {
      reason=EAGOLD_R10V2_VALIDATION_CAPITAL_INVALID;
      return(false);
   }

   if(!EAGOLD_R10V2ValidationOwnedTicket(contract.targetTicket,contract.direction))
   {
      reason=EAGOLD_R10V2_VALIDATION_TARGET_INVALID;
      return(false);
   }

   if(contract.opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
   {
      if(contract.targetTicket2<0 || contract.targetTicket2==contract.targetTicket)
      {
         reason=EAGOLD_R10V2_VALIDATION_TARGET_INVALID;
         return(false);
      }

      if(contract.direction!=OP_BUY)
      {
         reason=EAGOLD_R10V2_VALIDATION_OPPORTUNITY_MISMATCH;
         return(false);
      }

      if(!EAGOLD_R10V2ValidationOwnedTicket(contract.targetTicket2,OP_SELL))
      {
         reason=EAGOLD_R10V2_VALIDATION_TARGET_INVALID;
         return(false);
      }

      // Balanced reduction must preserve NET. The contract projection
      // is authoritative; tolerance follows the configured lot floor.
      if(!EAGOLD_R10V2ValidationNear(contract.netDelta,0.0,Lot*0.5))
      {
         reason=EAGOLD_R10V2_VALIDATION_BALANCED_NET_BREACH;
         return(false);
      }

      if(contract.grossRelief<=0.0 ||
         contract.recoveryLoadRelief<0.0)
      {
         reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
         return(false);
      }

      if(contract.authorizedLots>MathMin(OrderLots(),ctx.sellLots)+Lot*0.5)
      {
         reason=EAGOLD_R10V2_VALIDATION_LOTS_INCOHERENT;
         return(false);
      }
   }
   else
   {
      if(contract.targetTicket2>=0)
      {
         reason=EAGOLD_R10V2_VALIDATION_TARGET_INVALID;
         return(false);
      }

      if(contract.grossRelief<=0.0)
      {
         reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
         return(false);
      }

      if(contract.recoveryLoadRelief<0.0)
      {
         reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
         return(false);
      }
   }

   if(contract.grossAfter>contract.grossBefore+Lot*0.5)
   {
      reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
      return(false);
   }

   if(contract.grossRelief<=0.0)
   {
      reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
      return(false);
   }

   if(contract.netAfter-contract.netBefore-contract.netDelta>Lot*0.5 ||
      contract.netAfter-contract.netBefore-contract.netDelta<-Lot*0.5)
   {
      reason=EAGOLD_R10V2_VALIDATION_PROJECTION_MISMATCH;
      return(false);
   }

   return(true);
}

#endif
