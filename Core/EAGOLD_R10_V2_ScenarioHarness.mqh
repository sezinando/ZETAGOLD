#ifndef EAGOLD_R10_V2_SCENARIO_HARNESS_MQH
#define EAGOLD_R10_V2_SCENARIO_HARNESS_MQH

//==================================================================
// R10 v2 — PAIRED SCENARIO HARNESS
// ETAPA 13.31
//
// Deterministic, in-memory scenario laboratory.
// No OrderSend / OrderClose / OrderDelete.
// No capital reservation.
// No R11 mutation.
// No CSV.
//==================================================================

struct EAGOLD_R10V2ScenarioState
{
   double buyLots;
   double sellLots;
   double buyAverage;
   double sellAverage;
   double buyProfit;
   double sellProfit;
   double grossExposure;
   double netExposure;
   double recoveryLoad;
   double capitalAvailable;
};

struct EAGOLD_R10V2ScenarioProjection
{
   bool   valid;
   double buyLotsAfter;
   double sellLotsAfter;
   double grossAfter;
   double netAfter;
   double grossRelief;
   double netDelta;
   double recoveryLoadAfter;
   double recoveryLoadRelief;
   double capitalRequired;
   bool   netInvariant;
   bool   grossReliefInvariant;
};

void EAGOLD_R10V2ScenarioStateReset(EAGOLD_R10V2ScenarioState &s)
{
   s.buyLots=0.0;
   s.sellLots=0.0;
   s.buyAverage=0.0;
   s.sellAverage=0.0;
   s.buyProfit=0.0;
   s.sellProfit=0.0;
   s.grossExposure=0.0;
   s.netExposure=0.0;
   s.recoveryLoad=0.0;
   s.capitalAvailable=0.0;
}

void EAGOLD_R10V2ScenarioProjectionReset(EAGOLD_R10V2ScenarioProjection &p)
{
   p.valid=false;
   p.buyLotsAfter=0.0;
   p.sellLotsAfter=0.0;
   p.grossAfter=0.0;
   p.netAfter=0.0;
   p.grossRelief=0.0;
   p.netDelta=0.0;
   p.recoveryLoadAfter=0.0;
   p.recoveryLoadRelief=0.0;
   p.capitalRequired=0.0;
   p.netInvariant=false;
   p.grossReliefInvariant=false;
}

// Project an in-memory reduction. The scenario deliberately uses
// aggregate directional volume and recovery load; broker state is
// never read or modified.
bool EAGOLD_R10V2ScenarioProject(
   const EAGOLD_R10V2ScenarioState &s,
   int direction,
   double reductionLots,
   EAGOLD_R10V2ScenarioProjection &p)
{
   EAGOLD_R10V2ScenarioProjectionReset(p);

   if(reductionLots<Lot)
      return(false);

   if(direction!=OP_BUY && direction!=OP_SELL)
      return(false);

   if(direction==OP_BUY && reductionLots>s.buyLots+Lot*0.5)
      return(false);

   if(direction==OP_SELL && reductionLots>s.sellLots+Lot*0.5)
      return(false);

   p.buyLotsAfter=s.buyLots;
   p.sellLotsAfter=s.sellLots;

   if(direction==OP_BUY)
      p.buyLotsAfter-=reductionLots;
   else
      p.sellLotsAfter-=reductionLots;

   p.grossAfter=p.buyLotsAfter+p.sellLotsAfter;
   p.netAfter=p.buyLotsAfter-p.sellLotsAfter;
   p.grossRelief=s.grossExposure-p.grossAfter;
   p.netDelta=p.netAfter-s.netExposure;

   double proportionalRecovery=0.0;
   if(s.grossExposure>0.0)
      proportionalRecovery=s.recoveryLoad*(p.grossAfter/s.grossExposure);

   p.recoveryLoadAfter=MathMax(0.0,proportionalRecovery);
   p.recoveryLoadRelief=MathMax(0.0,s.recoveryLoad-p.recoveryLoadAfter);

   double buyPerLot=(s.buyLots>0.0?s.buyProfit/s.buyLots:0.0);
   double sellPerLot=(s.sellLots>0.0?s.sellProfit/s.sellLots:0.0);
   if(direction==OP_BUY)
      p.capitalRequired=MathMax(0.0,-reductionLots*buyPerLot);
   else
      p.capitalRequired=MathMax(0.0,-reductionLots*sellPerLot);

   p.netInvariant=(MathAbs(p.netDelta)<=Lot*0.5);
   p.grossReliefInvariant=(p.grossRelief>0.0);
   p.valid=p.grossReliefInvariant;

   return(p.valid);
}

bool EAGOLD_R10V2ScenarioProjectBalanced(
   const EAGOLD_R10V2ScenarioState &s,
   double commonReductionLots,
   EAGOLD_R10V2ScenarioProjection &p)
{
   EAGOLD_R10V2ScenarioProjectionReset(p);

   if(commonReductionLots<Lot)
      return(false);

   if(commonReductionLots>s.buyLots+Lot*0.5 ||
      commonReductionLots>s.sellLots+Lot*0.5)
      return(false);

   p.buyLotsAfter=s.buyLots-commonReductionLots;
   p.sellLotsAfter=s.sellLots-commonReductionLots;
   p.grossAfter=p.buyLotsAfter+p.sellLotsAfter;
   p.netAfter=p.buyLotsAfter-p.sellLotsAfter;
   p.grossRelief=s.grossExposure-p.grossAfter;
   p.netDelta=p.netAfter-s.netExposure;

   double proportionalRecovery=0.0;
   if(s.grossExposure>0.0)
      proportionalRecovery=s.recoveryLoad*(p.grossAfter/s.grossExposure);
   p.recoveryLoadAfter=MathMax(0.0,proportionalRecovery);
   p.recoveryLoadRelief=MathMax(0.0,s.recoveryLoad-p.recoveryLoadAfter);

   double buyPerLot=(s.buyLots>0.0?s.buyProfit/s.buyLots:0.0);
   double sellPerLot=(s.sellLots>0.0?s.sellProfit/s.sellLots:0.0);
   p.capitalRequired=MathMax(0.0,-commonReductionLots*(buyPerLot+sellPerLot));

   p.netInvariant=(MathAbs(p.netDelta)<=Lot*0.5);
   p.grossReliefInvariant=(p.grossRelief>0.0);
   p.valid=(p.netInvariant && p.grossReliefInvariant);
   return(p.valid);
}

// Built-in deterministic smoke scenarios. These are arithmetic only.
void EAGOLD_R10V2ScenarioHarnessRun()
{
   EAGOLD_R10V2ScenarioState s;
   EAGOLD_R10V2ScenarioProjection p;

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=10.0;
   s.sellLots=8.0;
   s.grossExposure=18.0;
   s.netExposure=2.0;
   s.recoveryLoad=180.0;
   s.buyProfit=20.0;
   s.sellProfit=-60.0;
   s.capitalAvailable=100.0;

   if(EAGOLD_R10V2ScenarioProjectBalanced(s,1.0,p))
      Print(EA_NAME," R10 v2 SCENARIO BALANCED 10/8 -> ",
            DoubleToString(p.buyLotsAfter,DigitsLots),"/",
            DoubleToString(p.sellLotsAfter,DigitsLots),
            " grossRelief=",DoubleToString(p.grossRelief,DigitsLots),
            " netDelta=",DoubleToString(p.netDelta,DigitsLots),
            " capital=",DoubleToString(p.capitalRequired,2));

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=5.0;
   s.sellLots=0.0;
   s.grossExposure=5.0;
   s.netExposure=5.0;
   s.recoveryLoad=100.0;
   s.buyProfit=-50.0;

   if(EAGOLD_R10V2ScenarioProject(s,OP_BUY,1.0,p))
      Print(EA_NAME," R10 v2 SCENARIO DIRECTIONAL 5/0 -> ",
            DoubleToString(p.buyLotsAfter,DigitsLots),
            " grossRelief=",DoubleToString(p.grossRelief,DigitsLots),
            " capital=",DoubleToString(p.capitalRequired,2));

   Print(EA_NAME," R10 v2 SCENARIO HARNESS READY");
}

#endif
