#ifndef EAGOLD_R10_V2_DECISION_PLAN_MQH
#define EAGOLD_R10_V2_DECISION_PLAN_MQH

//==================================================================
// R10 v2 — DECISION PLAN BUILDER
// ETAPA 13.9
//
// Builds a deterministic, read-only decision plan from the current
// Context + Opportunity and emits the Decision Contract.
//
// This stage intentionally does NOT:
//   - select broker execution through OrderClose/OrderSend
//   - reserve or consume real reduction capital
//   - call R11
//   - alter Recovery State / R13
//   - replace operational R10
//
// ETAPA 13.3-13.7 inputs that are not yet authoritative are kept
// explicit as zero/unavailable capacities. Therefore this builder
// cannot manufacture AUTHORIZED execution.
//==================================================================

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

void EAGOLD_R10V2DecisionPlanBuild(const EAGOLD_R10V2Context &ctx,
                                   EAGOLD_R10V2Opportunity opportunity,
                                   EAGOLD_R10V2DecisionContract &contract)
{
   EAGOLD_R10V2DecisionContractReset(contract);

   contract.timestamp=ctx.timestamp;
   contract.opportunity=opportunity;
   contract.grossBefore=ctx.grossExposure;
   contract.netBefore=ctx.netExposure;

   if(opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      contract.state=EAGOLD_R10V2_DECISION_NO_OPPORTUNITY;
      contract.reason=EAGOLD_R10V2_REASON_NO_EXPOSURE;
      return;
   }

   contract.state=EAGOLD_R10V2_DECISION_CANDIDATE;
   contract.reason=EAGOLD_R10V2_REASON_TARGET_NOT_ELIGIBLE;
   contract.action=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE;

   if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
   {
      contract.objective="REDUCE_GROSS_PRESERVE_NET";
      contract.selectionPolicy="BALANCED";
      contract.direction=0;
   }
   else if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT)
   {
      contract.objective="IMPROVE_POSITION_STRUCTURE";
      contract.selectionPolicy="STRUCTURAL_IMPACT";
      contract.direction=EAGOLD_R10V2PlanDirection(ctx,opportunity);
   }
   else if(opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
   {
      contract.objective="REDUCE_DIRECTIONAL_EXPOSURE";
      contract.selectionPolicy="DIRECTIONAL";
      contract.direction=EAGOLD_R10V2PlanDirection(ctx,opportunity);
   }

   // ETAPA 13.3 has not yet established an authoritative ticket.
   // ETAPA 13.4 has not yet established authorized capacity.
   // Therefore the plan remains CANDIDATE and cannot cross the
   // execution handoff boundary.
   contract.candidateLots=0.0;
   contract.desiredLots=0.0;
   contract.authorizedLots=0.0;

   contract.capitalCapacity=0.0;
   contract.exposureCapacity=0.0;
   contract.r11Capacity=0.0;
   contract.brokerCapacity=0.0;

   contract.grossAfter=contract.grossBefore;
   contract.netAfter=contract.netBefore;
   contract.grossRelief=0.0;
   contract.netDelta=0.0;

   contract.executionEligible=false;
}

#endif
