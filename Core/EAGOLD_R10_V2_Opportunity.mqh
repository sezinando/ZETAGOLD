#ifndef EAGOLD_R10_V2_OPPORTUNITY_MQH
#define EAGOLD_R10_V2_OPPORTUNITY_MQH

enum EAGOLD_R10V2Opportunity
{
   EAGOLD_R10V2_OPP_NONE=0,
   EAGOLD_R10V2_OPP_BALANCED_REDUCTION=1,
   EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT=2,
   EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION=3
};

string EAGOLD_R10V2OpportunityName(EAGOLD_R10V2Opportunity opportunity)
{
   if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)return("BALANCED_REDUCTION");
   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT)return("POSITION_ADJUSTMENT");
   if(opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)return("DIRECTIONAL_REDUCTION");
   return("NO_OPPORTUNITY");
}

bool EAGOLD_R10V2OpportunityEligible(const EAGOLD_R10V2Context &ctx)
{
   if(!EnableR10Reduce)return(false);
   if(R10MinExposureLots<=0.0)return(false);
   if(ctx.grossExposure<Lot)return(false);
   return(true);
}

EAGOLD_R10V2Opportunity EAGOLD_R10V2EvaluateOpportunity(const EAGOLD_R10V2Context &ctx)
{
   if(!EAGOLD_R10V2OpportunityEligible(ctx))return(EAGOLD_R10V2_OPP_NONE);

   // Balanced is evaluated first because it can reduce GROSS while
   // preserving NET, subject to later target/capital/governor checks.
   if(R10V2EnableBalancedReduction && ctx.hasBothDirections)
      return(EAGOLD_R10V2_OPP_BALANCED_REDUCTION);

   // Position adjustment is only an opportunity classification.
   // Ticket selection is intentionally deferred to ETAPA 13.3.
   if(R10V2EnablePositionAdjustment)
   {
      if((ctx.heavyBuy && ctx.buyProfit<0.0) ||
         (ctx.heavySell && ctx.sellProfit<0.0))
         return(EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT);
   }

   if(R10V2EnableDirectionalReduction &&
      (ctx.heavyBuy || ctx.heavySell))
      return(EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION);

   return(EAGOLD_R10V2_OPP_NONE);
}

#endif