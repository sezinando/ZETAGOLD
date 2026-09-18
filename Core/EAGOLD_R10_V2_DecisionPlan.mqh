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
   double recoveryLoadRelief)
{
   EAGOLD_R10V2DecisionContractReset(g_r10V2DecisionContract);

   g_r10V2DecisionContract.timestamp=ctx.timestamp;
   g_r10V2DecisionContract.opportunity=opportunity;
   g_r10V2DecisionContract.targetTicket=targetTicket;
   g_r10V2DecisionContract.targetTicket2=targetTicket2;
   g_r10V2DecisionContract.direction=direction;

   g_r10V2DecisionContract.objective=EAGOLD_R10V2PlanObjective(opportunity);
   g_r10V2DecisionContract.selectionPolicy=EAGOLD_R10V2PlanPolicy(opportunity);

   g_r10V2DecisionContract.candidateLots=candidateLots;
   g_r10V2DecisionContract.desiredLots=desiredLots;
   g_r10V2DecisionContract.capitalCapacity=capitalCapacity;
   g_r10V2DecisionContract.exposureCapacity=exposureCapacity;
   g_r10V2DecisionContract.r11Capacity=r11Capacity;
   g_r10V2DecisionContract.brokerCapacity=brokerCapacity;
   g_r10V2DecisionContract.authorizedLots=authorizedLots;
   g_r10V2DecisionContract.capitalReservationRequired=capitalReservationRequired;

   g_r10V2DecisionContract.grossBefore=ctx.grossExposure;
   g_r10V2DecisionContract.grossAfter=grossAfter;
   g_r10V2DecisionContract.grossRelief=grossRelief;

   g_r10V2DecisionContract.netBefore=ctx.netExposure;
   g_r10V2DecisionContract.netAfter=netAfter;
   g_r10V2DecisionContract.netDelta=netDelta;

   g_r10V2DecisionContract.recoveryLoadBefore=recoveryLoadBefore;
   g_r10V2DecisionContract.recoveryLoadAfter=recoveryLoadAfter;
   g_r10V2DecisionContract.recoveryLoadRelief=recoveryLoadRelief;

   g_r10V2DecisionContract.action=EAGOLD_R10V2_HANDOFF_NONE;
   g_r10V2DecisionContract.executionEligible=false;
   g_r10V2DecisionContract.capitalSource="";

   if(opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      g_r10V2DecisionContract.state=EAGOLD_R10V2_DECISION_NO_OPPORTUNITY;
      g_r10V2DecisionContract.reason=EAGOLD_R10V2_REASON_NO_EXPOSURE;
      return;
   }

   if(targetFound && capitalCapacity>0.0)
      g_r10V2DecisionContract.capitalSource="R13_RECOVERY_CAPITAL";

   bool authorized=(authorizedLots>=Lot &&
                    targetFound &&
                    structuralValid &&
                    structuralBenefit);

   if(authorized)
   {
      g_r10V2DecisionContract.state=EAGOLD_R10V2_DECISION_AUTHORIZED;
      g_r10V2DecisionContract.reason=EAGOLD_R10V2_REASON_AUTHORIZED;
      g_r10V2DecisionContract.action=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE;

      // Authorization is a decision-domain result only.
      // Execution remains closed in ETAPA 13.16.
      g_r10V2DecisionContract.executionEligible=false;
      return;
   }

   g_r10V2DecisionContract.state=EAGOLD_R10V2_DECISION_BLOCKED;
   g_r10V2DecisionContract.reason=EAGOLD_R10V2PlanBlockReason(
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
