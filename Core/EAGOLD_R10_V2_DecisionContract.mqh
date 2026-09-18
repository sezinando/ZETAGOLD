#ifndef EAGOLD_R10_V2_DECISION_CONTRACT_MQH
#define EAGOLD_R10_V2_DECISION_CONTRACT_MQH

//==================================================================
// R10 v2 — DECISION CONTRACT / ACTION HANDOFF
// ETAPA 13.8
//
// Defines the immutable handoff boundary between the R10 v2
// decision domain and the execution domain.
//
// This module does NOT:
//   - execute broker operations
//   - call OrderClose / OrderSend / OrderDelete
//   - reserve or consume real reduction capital
//   - call R11
//   - replace operational R10
//
// AUTHORITY FLOW:
//   R10 v2 Decision -> Contract -> Action Contract -> Execution Core
//                                             -> Reconciliation
//
// A contract may describe an AUTHORIZED plan, but AUTHORIZED does
// not mean EXECUTED. Executed volume exists only after broker result
// and reconciliation.
//==================================================================

enum EAGOLD_R10V2DecisionState
{
   EAGOLD_R10V2_DECISION_NO_OPPORTUNITY = 0,
   EAGOLD_R10V2_DECISION_BLOCKED        = 1,
   EAGOLD_R10V2_DECISION_CANDIDATE      = 2,
   EAGOLD_R10V2_DECISION_AUTHORIZED     = 3
};

string EAGOLD_R10V2DecisionStateName(EAGOLD_R10V2DecisionState state)
{
   if(state==EAGOLD_R10V2_DECISION_BLOCKED)   return("BLOCKED");
   if(state==EAGOLD_R10V2_DECISION_CANDIDATE) return("CANDIDATE");
   if(state==EAGOLD_R10V2_DECISION_AUTHORIZED)return("AUTHORIZED");
   return("NO_OPPORTUNITY");
}

enum EAGOLD_R10V2DecisionReason
{
   EAGOLD_R10V2_REASON_NONE = 0,
   EAGOLD_R10V2_REASON_NO_EXPOSURE,
   EAGOLD_R10V2_REASON_NO_CAPITAL,
   EAGOLD_R10V2_REASON_NO_STRUCTURAL_BENEFIT,
   EAGOLD_R10V2_REASON_TARGET_NOT_ELIGIBLE,
   EAGOLD_R10V2_REASON_R11_BLOCK,
   EAGOLD_R10V2_REASON_BROKER_CAPACITY,
   EAGOLD_R10V2_REASON_COOLDOWN,
   EAGOLD_R10V2_REASON_RECONCILIATION_REQUIRED,
   EAGOLD_R10V2_REASON_POLICY_BLOCK,
   EAGOLD_R10V2_REASON_AUTHORIZED
};

string EAGOLD_R10V2DecisionReasonName(EAGOLD_R10V2DecisionReason reason)
{
   if(reason==EAGOLD_R10V2_REASON_NO_EXPOSURE) return("NO_EXPOSURE");
   if(reason==EAGOLD_R10V2_REASON_NO_CAPITAL) return("NO_CAPITAL");
   if(reason==EAGOLD_R10V2_REASON_NO_STRUCTURAL_BENEFIT) return("NO_STRUCTURAL_BENEFIT");
   if(reason==EAGOLD_R10V2_REASON_TARGET_NOT_ELIGIBLE) return("TARGET_NOT_ELIGIBLE");
   if(reason==EAGOLD_R10V2_REASON_R11_BLOCK) return("R11_BLOCK");
   if(reason==EAGOLD_R10V2_REASON_BROKER_CAPACITY) return("BROKER_CAPACITY");
   if(reason==EAGOLD_R10V2_REASON_COOLDOWN) return("COOLDOWN");
   if(reason==EAGOLD_R10V2_REASON_RECONCILIATION_REQUIRED) return("RECONCILIATION_REQUIRED");
   if(reason==EAGOLD_R10V2_REASON_POLICY_BLOCK) return("POLICY_BLOCK");
   if(reason==EAGOLD_R10V2_REASON_AUTHORIZED) return("AUTHORIZED");
   return("NONE");
}

enum EAGOLD_R10V2HandoffAction
{
   EAGOLD_R10V2_HANDOFF_NONE = 0,
   EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE = 1
};

struct EAGOLD_R10V2DecisionContract
{
   datetime timestamp;
   int      cycleId;

   EAGOLD_R10V2Opportunity opportunity;
   EAGOLD_R10V2DecisionState state;
   EAGOLD_R10V2DecisionReason reason;
   EAGOLD_R10V2HandoffAction action;

   int      direction;
   int      targetTicket;
   int      targetTicket2;

   string   objective;
   string   selectionPolicy;
   string   capitalSource;

   double   candidateLots;
   double   desiredLots;
   double   authorizedLots;

   double   capitalCapacity;
   double   exposureCapacity;
   double   r11Capacity;
   double   brokerCapacity;
   double   capitalReservationRequired;

   double   grossBefore;
   double   grossAfter;
   double   grossRelief;

   double   netBefore;
   double   netAfter;
   double   netDelta;

   double   recoveryLoadBefore;
   double   recoveryLoadAfter;
   double   recoveryLoadRelief;

   bool     executionEligible;
};

void EAGOLD_R10V2DecisionContractReset(EAGOLD_R10V2DecisionContract &contract)
{
   contract.timestamp=0;
   contract.cycleId=0;

   contract.opportunity=EAGOLD_R10V2_OPP_NONE;
   contract.state=EAGOLD_R10V2_DECISION_NO_OPPORTUNITY;
   contract.reason=EAGOLD_R10V2_REASON_NONE;
   contract.action=EAGOLD_R10V2_HANDOFF_NONE;

   contract.direction=0;
   contract.targetTicket=-1;
   contract.targetTicket2=-1;

   contract.objective="";
   contract.selectionPolicy="";
   contract.capitalSource="";

   contract.candidateLots=0.0;
   contract.desiredLots=0.0;
   contract.authorizedLots=0.0;

   contract.capitalCapacity=0.0;
   contract.exposureCapacity=0.0;
   contract.r11Capacity=0.0;
   contract.brokerCapacity=0.0;
   contract.capitalReservationRequired=0.0;

   contract.grossBefore=0.0;
   contract.grossAfter=0.0;
   contract.grossRelief=0.0;

   contract.netBefore=0.0;
   contract.netAfter=0.0;
   contract.netDelta=0.0;

   contract.recoveryLoadBefore=0.0;
   contract.recoveryLoadAfter=0.0;
   contract.recoveryLoadRelief=0.0;

   contract.executionEligible=false;
}

// Contract validation is deliberately structural.
// It does not execute and does not grant broker authority.
bool EAGOLD_R10V2DecisionContractCanHandoff(const EAGOLD_R10V2DecisionContract &contract)
{
   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED)
      return(false);

   if(contract.action==EAGOLD_R10V2_HANDOFF_NONE)
      return(false);

   if(contract.targetTicket<0)
      return(false);

   if(contract.authorizedLots<=0.0)
      return(false);

   if(contract.direction!=OP_BUY && contract.direction!=OP_SELL)
      return(false);

   if(!contract.executionEligible)
      return(false);

   return(true);
}

#endif
