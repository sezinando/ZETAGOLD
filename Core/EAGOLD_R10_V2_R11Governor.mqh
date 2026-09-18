#ifndef EAGOLD_R10_V2_R11_GOVERNOR_MQH
#define EAGOLD_R10_V2_R11_GOVERNOR_MQH

//==================================================================
// R10 v2 — R11 REDUCTION GOVERNOR
// ETAPA 13.12
//
// R10 decides WHAT economic opportunity exists.
// R11 decides HOW MUCH reduction capacity its recovery/exposure
// governance currently permits.
//
// R11 does NOT:
//   - choose the target ticket
//   - choose the opportunity
//   - execute broker operations
//   - reserve/consume capital
//
// IMPORTANT:
// Existing R11 recovery-addition controls are intentionally NOT
// reused as REDUCE authorization. Reduction is exposure-decreasing
// and therefore has a distinct governance path.
//==================================================================

struct EAGOLD_R10V2R11ReductionCapacity
{
   bool   allowed;
   double desiredLots;
   double perActionCapacity;
   double directionCapacity;
   double structureCapacity;
   double recoveryPolicyCapacity;
   double capacityLots;
   string policy;
   string blockReason;
};

void EAGOLD_R10V2R11ReductionCapacityReset(
   EAGOLD_R10V2R11ReductionCapacity &g)
{
   g.allowed=false;
   g.desiredLots=0.0;
   g.perActionCapacity=0.0;
   g.directionCapacity=0.0;
   g.structureCapacity=0.0;
   g.recoveryPolicyCapacity=0.0;
   g.capacityLots=0.0;
   g.policy="";
   g.blockReason="";
}

void EAGOLD_R10V2R11ReductionCapacityBuild(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2Target &target,
   double desiredLots,
   EAGOLD_R10V2R11ReductionCapacity &g)
{
   EAGOLD_R10V2R11ReductionCapacityReset(g);
   g.desiredLots=desiredLots;

   if(!target.found)
   {
      g.blockReason="TARGET_NOT_ELIGIBLE";
      return;
   }

   if(desiredLots<Lot)
   {
      g.blockReason="NO_DESIRED_REDUCTION";
      return;
   }

   // R11 governance can be disabled without manufacturing capacity.
   if(!EnableR11ExposureGovernor)
   {
      g.allowed=true;
      g.policy="R11_GOVERNOR_DISABLED";
      g.perActionCapacity=desiredLots;
      g.directionCapacity=desiredLots;
      g.structureCapacity=desiredLots;
      g.recoveryPolicyCapacity=desiredLots;
      g.capacityLots=desiredLots;
      return;
   }

   // Per-action capacity starts from the requested reduction.
   g.perActionCapacity=desiredLots;

   // A reduction cannot exceed the selected direction's current
   // position volume. The final broker capacity is downstream.
   if(target.direction==OP_BUY)
      g.directionCapacity=ctx.buyLots;
   else if(target.direction==OP_SELL)
      g.directionCapacity=ctx.sellLots;
   else
      g.directionCapacity=0.0;

   // Preserve at least one base lot in the selected direction.
   g.structureCapacity=MathMax(0.0,g.directionCapacity-Lot);

   // Recovery policy currently imposes no additional reduction
   // restriction. This is explicit rather than inferred from the
   // recovery-addition governor.
   g.recoveryPolicyCapacity=g.directionCapacity;

   g.capacityLots=MathMin(g.perActionCapacity,g.directionCapacity);
   g.capacityLots=MathMin(g.capacityLots,g.structureCapacity);
   g.capacityLots=MathMin(g.capacityLots,g.recoveryPolicyCapacity);
   g.capacityLots=EAGOLD_R10V2NormalizeCapacityLots(g.capacityLots);

   if(g.capacityLots<Lot)
   {
      g.allowed=false;
      g.blockReason="R11_STRUCTURE_BLOCK";
      return;
   }

   // High gross exposure is not a reason to block reduction.
   // The governor remains permissive for exposure-decreasing actions.
   g.allowed=true;
   g.policy="REDUCTION_EXPOSURE_RELIEF";
}

#endif
