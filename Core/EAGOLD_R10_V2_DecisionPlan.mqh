#ifndef EAGOLD_R10_V2_DECISION_PLAN_MQH
#define EAGOLD_R10_V2_DECISION_PLAN_MQH

//==================================================================
// R10 v2 — DECISION PLAN BUILDER
// ETAPA 13.16
//
// Builds the single authoritative Decision Contract from the
// already-evaluated R10 v2 state.
//
// This module does NOT:
//   - execute broker operations
//   - reserve or consume real reduction capital
//   - call R11
//   - alter Recovery State / R13
//
// Authority flow:
//   Context -> Opportunity -> Target/Pair -> Capacity/Governance
//   -> Structural Projection -> Decision Contract
//
// The contract may describe AUTHORIZED intent, but executionEligible
// remains false until a future stage explicitly opens the execution
// boundary.
//==================================================================

string EAGOLD_R10V2PlanObjective(EAGOLD_R10V2Opportunity opportunity)
{
   if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return("REDUCE_GROSS_PRESERVE_NET");
   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT)
      return("IMPROVE_POSITION_STRUCTURE");
   if(opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
      return("REDUCE_DIRECTIONAL_EXPOSURE");
   return("");
}

string EAGOLD_R10V2PlanPolicy(EAGOLD_R10V2Opportunity opportunity)
{
   if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return("BALANCED");
   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT)
      return("STRUCTURAL_IMPACT");
   if(opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
      return("DIRECTIONAL");
   return("");
}

int EAGOLD_R10V2PlanDirection(const EAGOLD_R10V2Context &ctx,
                              EAGOLD_R10V2Opportunity opportunity)
{
   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT ||
      opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
   {
      if(ctx.heavyBuy)return(OP_BUY);
      if(ctx.heavySell)return(OP_SELL);
   }

   return(0);
}

EAGOLD_R10V2DecisionReason EAGOLD_R10V2PlanBlockReason(
   double desiredLots,
   double authorizedLots,
   double capitalCapacity,
   double exposureCapacity,
   double r11Capacity,
   double brokerCapacity,
   bool targetFound,
   bool structuralValid,
   bool structuralBenefit)
{
   if(!targetFound)
      return(EAGOLD_R10V2_REASON_TARGET_NOT_ELIGIBLE);

   if(!structuralValid || !structuralBenefit)
      return(EAGOLD_R10V2_REASON_NO_STRUCTURAL_BENEFIT);

   if(desiredLots<Lot)
      return(EAGOLD_R10V2_REASON_TARGET_NOT_ELIGIBLE);

   if(capitalCapacity<desiredLots && authorizedLots<Lot)
      return(EAGOLD_R10V2_REASON_NO_CAPITAL);

   if(exposureCapacity<desiredLots && authorizedLots<Lot)
      return(EAGOLD_R10V2_REASON_POLICY_BLOCK);

   if(r11Capacity<desiredLots && authorizedLots<Lot)
      return(EAGOLD_R10V2_REASON_R11_BLOCK);

   if(brokerCapacity<desiredLots && authorizedLots<Lot)
      return(EAGOLD_R10V2_REASON_BROKER_CAPACITY);

   return(EAGOLD_R10V2_REASON_POLICY_BLOCK);
}

// Single authoritative contract construction.
// All target/capacity/projection values entering this function have
// already been produced by their respective decision authorities.
void EAGOLD_R10V2DecisionPlanBuild(
   const EAGOLD_R10V2Context &ctx,
   EAGOLD_R10V2Opportunity opportunity,
   bool targetFound,
   int targetTicket,
   int targetTicket2,
   int direction,
   double candidateLots,
   double desiredLots,
   double capitalCapacity,
   double exposureCapacity,
   double r11Capacity,
   double brokerCapacity,
   double authorizedLots,
   double capitalReservationRequired,
   bool structuralValid,
   bool structuralBenefit,
   double grossAfter,
   double grossRelief,
   double netAfter,
   double netDelta,
   double recoveryLoadBefore,
   double recoveryLoadAfter,
   double recoveryLoadRelief,
   EAGOLD_R10V2DecisionContract &contract)
{
   EAGOLD_R10V2DecisionContractReset(contract);

   contract.timestamp=ctx.timestamp;
   contract.opportunity=opportunity;
   contract.targetTicket=targetTicket;
   contract.targetTicket2=targetTicket2;
   contract.direction=direction;

   contract.objective=EAGOLD_R10V2PlanObjective(opportunity);
   contract.selectionPolicy=EAGOLD_R10V2PlanPolicy(opportunity);

   contract.candidateLots=candidateLots;
   contract.desiredLots=desiredLots;
   contract.capitalCapacity=capitalCapacity;
   contract.exposureCapacity=exposureCapacity;
   contract.r11Capacity=r11Capacity;
   contract.brokerCapacity=brokerCapacity;
   contract.authorizedLots=authorizedLots;
   contract.capitalReservationRequired=capitalReservationRequired;

   contract.grossBefore=ctx.grossExposure;
   contract.grossAfter=grossAfter;
   contract.grossRelief=grossRelief;

   contract.netBefore=ctx.netExposure;
   contract.netAfter=netAfter;
   contract.netDelta=netDelta;

   contract.recoveryLoadBefore=recoveryLoadBefore;
   contract.recoveryLoadAfter=recoveryLoadAfter;
   contract.recoveryLoadRelief=recoveryLoadRelief;

   contract.action=EAGOLD_R10V2_HANDOFF_NONE;
   contract.executionEligible=false;
   contract.capitalSource="";

   if(opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      contract.state=EAGOLD_R10V2_DECISION_NO_OPPORTUNITY;
      contract.reason=EAGOLD_R10V2_REASON_NO_EXPOSURE;
      return;
   }

   if(targetFound && capitalCapacity>0.0)
      contract.capitalSource="R13_RECOVERY_CAPITAL";

   bool authorized=(authorizedLots>=Lot &&
                    targetFound &&
                    structuralValid &&
                    structuralBenefit);

   if(authorized)
   {
      contract.state=EAGOLD_R10V2_DECISION_AUTHORIZED;
      contract.reason=EAGOLD_R10V2_REASON_AUTHORIZED;
      contract.action=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE;

      // Authorization is a decision-domain result only.
      // Execution remains closed in ETAPA 13.16.
      contract.executionEligible=false;
      return;
   }

   contract.state=EAGOLD_R10V2_DECISION_BLOCKED;
   contract.reason=EAGOLD_R10V2PlanBlockReason(
      desiredLots,
      authorizedLots,
      capitalCapacity,
      exposureCapacity,
      r11Capacity,
      brokerCapacity,
      targetFound,
      structuralValid,
      structuralBenefit);
}

#endif
