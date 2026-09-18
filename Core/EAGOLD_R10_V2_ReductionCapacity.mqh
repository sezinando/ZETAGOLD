#ifndef EAGOLD_R10_V2_REDUCTION_CAPACITY_MQH
#define EAGOLD_R10_V2_REDUCTION_CAPACITY_MQH

//==================================================================
// R10 v2 — REDUCTION CAPACITY ENGINE
// ETAPA 13.11
//
// Separates desired reduction from authorized reduction.
//
// QUANTO GOSTARÍAMOS? -> DesiredLots
// QUANTO PODEMOS?      -> Capacity
//
// This stage does NOT:
//   - execute broker operations
//   - reserve/consume real capital
//   - call R11
//   - alter Recovery/R13
//
// Capital capacity remains ZERO until the authoritative Reduction
// Capital Ledger is implemented. This is intentional: no floating
// profit, balance or free margin is silently converted into spending
// authority.
//==================================================================

double EAGOLD_R10V2NormalizeCapacityLots(double lots)
{
   if(lots<=0.0)return(0.0);
   double normalized=NormalizeLot(lots);
   if(normalized>MaxOpenLot && MaxOpenLot>0.0)
      normalized=MaxOpenLot;
   return(normalized);
}

double EAGOLD_R10V2CandidateReductionLots(const EAGOLD_R10V2Target &target)
{
   if(!target.found || target.candidateLots<Lot)return(0.0);

   double ratio=R10V2ReduceRatio;
   if(ratio<=0.0)ratio=0.0;

   double desired=target.candidateLots*ratio;

   if(R10V2MaxReductionLots>0.0)
      desired=MathMin(desired,R10V2MaxReductionLots);

   return(EAGOLD_R10V2NormalizeCapacityLots(desired));
}

double EAGOLD_R10V2ExposureCapacity(const EAGOLD_R10V2Context &ctx,
                                     const EAGOLD_R10V2Target &target)
{
   if(!target.found)return(0.0);

   double capacity=target.candidateLots;

   if(target.direction==OP_BUY)
      capacity=MathMin(capacity,ctx.buyLots);
   else if(target.direction==OP_SELL)
      capacity=MathMin(capacity,ctx.sellLots);

   return(EAGOLD_R10V2NormalizeCapacityLots(capacity));
}

double EAGOLD_R10V2BrokerCapacity(const EAGOLD_R10V2Target &target)
{
   if(!target.found)return(0.0);

   // The actual broker constraint is applied again by Execution Core.
   // Here we only normalize against the EA's lot granularity.
   return(EAGOLD_R10V2NormalizeCapacityLots(target.candidateLots));
}

void EAGOLD_R10V2ReductionCapacityBuild(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2Target &target,
   double &candidateLots,
   double &desiredLots,
   double &capitalCapacity,
   double &exposureCapacity,
   double &r11Capacity,
   double &brokerCapacity,
   double &authorizedLots)
{
   candidateLots=0.0;
   desiredLots=0.0;
   capitalCapacity=0.0;
   exposureCapacity=0.0;
   r11Capacity=0.0;
   brokerCapacity=0.0;
   authorizedLots=0.0;

   if(!target.found)return;

   candidateLots=target.candidateLots;
   desiredLots=EAGOLD_R10V2CandidateReductionLots(target);

   exposureCapacity=EAGOLD_R10V2ExposureCapacity(ctx,target);
   brokerCapacity=EAGOLD_R10V2BrokerCapacity(target);

   // R11 is not yet the REDUCE governor. Zero means unavailable,
   // not permission to execute.
   r11Capacity=0.0;

   // Reduction Capital Ledger is intentionally not approximated by
   // AccountBalance/Equity/FreeMargin or floating profit.
   capitalCapacity=0.0;

   authorizedLots=MathMin(desiredLots,capitalCapacity);
   authorizedLots=MathMin(authorizedLots,exposureCapacity);
   authorizedLots=MathMin(authorizedLots,r11Capacity);
   authorizedLots=MathMin(authorizedLots,brokerCapacity);
   authorizedLots=EAGOLD_R10V2NormalizeCapacityLots(authorizedLots);
}

#endif
