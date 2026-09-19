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

//==================================================================
// ETAPA 13.32 — INVARIANT / FAILURE TESTS
//==================================================================
struct EAGOLD_R10V2ScenarioTestResult
{
   int total;
   int passed;
   int failed;
};

void EAGOLD_R10V2ScenarioAssert(
   string name,
   bool condition,
   EAGOLD_R10V2ScenarioTestResult &r)
{
   r.total++;
   if(condition)
   {
      r.passed++;
      Print(EA_NAME," R10 v2 TEST PASS: ",name);
   }
   else
   {
      r.failed++;
      Print(EA_NAME," R10 v2 TEST FAIL: ",name);
   }
}

void EAGOLD_R10V2ScenarioInvariantTests()
{
   EAGOLD_R10V2ScenarioTestResult r;
   r.total=0; r.passed=0; r.failed=0;

   EAGOLD_R10V2ScenarioState s;
   EAGOLD_R10V2ScenarioProjection p;

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=10.0; s.sellLots=8.0;
   s.grossExposure=18.0; s.netExposure=2.0;
   s.recoveryLoad=180.0;
   s.buyProfit=20.0; s.sellProfit=-60.0;

   bool balanced=EAGOLD_R10V2ScenarioProjectBalanced(s,1.0,p);
   EAGOLD_R10V2ScenarioAssert("BALANCED_VALID",balanced,r);
   EAGOLD_R10V2ScenarioAssert("BALANCED_GROSS_RELIEF",p.grossRelief>0.0,r);
   EAGOLD_R10V2ScenarioAssert("BALANCED_NET_PRESERVED",p.netInvariant,r);
   EAGOLD_R10V2ScenarioAssert("BALANCED_GROSS_AFTER_LT_BEFORE",
                              p.grossAfter<s.grossExposure,r);

   EAGOLD_R10V2ScenarioAssert("BALANCED_OVERSELL_REJECTED",
                              !EAGOLD_R10V2ScenarioProjectBalanced(s,9.0,p),r);

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=5.0; s.sellLots=0.0;
   s.grossExposure=5.0; s.netExposure=5.0;
   s.recoveryLoad=100.0; s.buyProfit=-50.0;

   EAGOLD_R10V2ScenarioAssert("DIRECTIONAL_VALID",
                              EAGOLD_R10V2ScenarioProject(s,OP_BUY,1.0,p),r);
   EAGOLD_R10V2ScenarioAssert("DIRECTIONAL_GROSS_RELIEF",
                              p.grossRelief>0.0,r);
   EAGOLD_R10V2ScenarioAssert("DIRECTIONAL_OVERREDUCE_REJECTED",
                              !EAGOLD_R10V2ScenarioProject(s,OP_BUY,6.0,p),r);
   EAGOLD_R10V2ScenarioAssert("DIRECTIONAL_INVALID_SIDE_REJECTED",
                              !EAGOLD_R10V2ScenarioProject(s,OP_SELL,1.0,p),r);
   EAGOLD_R10V2ScenarioAssert("BELOW_LOT_REJECTED",
                              !EAGOLD_R10V2ScenarioProject(s,OP_BUY,Lot*0.5,p),r);

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=-1.0; s.sellLots=2.0;
   s.grossExposure=1.0; s.netExposure=-3.0;
   EAGOLD_R10V2ScenarioAssert("NEGATIVE_VOLUME_REJECTED",
                              !EAGOLD_R10V2ScenarioProject(s,OP_SELL,1.0,p),r);

   EAGOLD_R10V2ScenarioStateReset(s);
   s.buyLots=4.0; s.sellLots=4.0;
   s.grossExposure=8.0; s.netExposure=0.0;
   s.recoveryLoad=80.0;
   EAGOLD_R10V2ScenarioAssert("BALANCED_EXACT_LIMIT",
                              EAGOLD_R10V2ScenarioProjectBalanced(s,4.0,p),r);
   EAGOLD_R10V2ScenarioAssert("BALANCED_EXACT_LIMIT_NET",
                              p.netInvariant,r);
   EAGOLD_R10V2ScenarioAssert("BALANCED_EXACT_LIMIT_GROSS",
                              p.grossRelief>0.0,r);

   Print(EA_NAME," R10 v2 INVARIANT TEST SUMMARY total=",r.total,
         " passed=",r.passed," failed=",r.failed);
}

   
//==================================================================
// ETAPA 13.33 — PAIRED TRAJECTORY HARNESS
//==================================================================
struct EAGOLD_R10V2TrajectoryStep
{
   int index;
   double buyBefore;
   double sellBefore;
   double buyAfter;
   double sellAfter;
   double grossBefore;
   double grossAfter;
   double netBefore;
   double netAfter;
   double reduction;
   double grossRelief;
   double netDelta;
   bool valid;
   bool grossInvariant;
   bool netInvariant;
   bool volumeInvariant;
};

struct EAGOLD_R10V2TrajectoryResult
{
   int totalSteps;
   int validSteps;
   int failedSteps;
   double initialGross;
   double finalGross;
   double initialNet;
   double finalNet;
   double cumulativeGrossRelief;
   double cumulativeNetDelta;
   bool grossMonotonic;
   bool balancedNetInvariant;
};

void EAGOLD_R10V2TrajectoryStepReset(EAGOLD_R10V2TrajectoryStep &t)
{
   t.index=0;
   t.buyBefore=0.0; t.sellBefore=0.0;
   t.buyAfter=0.0; t.sellAfter=0.0;
   t.grossBefore=0.0; t.grossAfter=0.0;
   t.netBefore=0.0; t.netAfter=0.0;
   t.reduction=0.0;
   t.grossRelief=0.0;
   t.netDelta=0.0;
   t.valid=false;
   t.grossInvariant=false;
   t.netInvariant=false;
   t.volumeInvariant=false;
}

bool EAGOLD_R10V2TrajectoryBalancedStep(
   double buyLots,
   double sellLots,
   double reduction,
   EAGOLD_R10V2TrajectoryStep &t)
{
   EAGOLD_R10V2TrajectoryStepReset(t);

   if(buyLots<0.0 || sellLots<0.0)
      return(false);
   if(reduction<Lot)
      return(false);
   if(reduction>buyLots || reduction>sellLots)
      return(false);

   t.buyBefore=buyLots;
   t.sellBefore=sellLots;
   t.grossBefore=buyLots+sellLots;
   t.netBefore=buyLots-sellLots;
   t.reduction=reduction;

   t.buyAfter=buyLots-reduction;
   t.sellAfter=sellLots-reduction;
   t.grossAfter=t.buyAfter+t.sellAfter;
   t.netAfter=t.buyAfter-t.sellAfter;

   t.grossRelief=t.grossBefore-t.grossAfter;
   t.netDelta=t.netAfter-t.netBefore;

   t.volumeInvariant=(t.buyAfter>=0.0 && t.sellAfter>=0.0);
   t.grossInvariant=(t.grossAfter<t.grossBefore);
   t.netInvariant=(MathAbs(t.netDelta)<=Lot*0.5);
   t.valid=(t.volumeInvariant && t.grossInvariant && t.netInvariant);

   return(t.valid);
}

void EAGOLD_R10V2TrajectoryHarnessRun()
{
   EAGOLD_R10V2TrajectoryResult r;
   r.totalSteps=0;
   r.validSteps=0;
   r.failedSteps=0;
   r.initialGross=0.0;
   r.finalGross=0.0;
   r.initialNet=0.0;
   r.finalNet=0.0;
   r.cumulativeGrossRelief=0.0;
   r.cumulativeNetDelta=0.0;
   r.grossMonotonic=true;
   r.balancedNetInvariant=true;

   double buy=10.0;
   double sell=8.0;
   r.initialGross=buy+sell;
   r.initialNet=buy-sell;

   for(int i=1;i<=4;i++)
   {
      EAGOLD_R10V2TrajectoryStep step;
      bool ok=EAGOLD_R10V2TrajectoryBalancedStep(buy,sell,1.0,step);

      r.totalSteps++;
      if(ok) r.validSteps++;
      else r.failedSteps++;

      if(step.grossAfter>=step.grossBefore)
         r.grossMonotonic=false;
      if(MathAbs(step.netDelta)>Lot*0.5)
         r.balancedNetInvariant=false;

      r.cumulativeGrossRelief+=step.grossRelief;
      r.cumulativeNetDelta+=step.netDelta;

      Print(EA_NAME," R10 v2 TRAJECTORY T",i,
            " BUY ",DoubleToString(step.buyBefore,2),"->",DoubleToString(step.buyAfter,2),
            " SELL ",DoubleToString(step.sellBefore,2),"->",DoubleToString(step.sellAfter,2),
            " GROSS ",DoubleToString(step.grossBefore,2),"->",DoubleToString(step.grossAfter,2),
            " NET ",DoubleToString(step.netBefore,2),"->",DoubleToString(step.netAfter,2),
            " REDUCE=",DoubleToString(step.reduction,2),
            " RESULT=",ok ? "PASS" : "FAIL");

      buy=step.buyAfter;
      sell=step.sellAfter;
   }

   r.finalGross=buy+sell;
   r.finalNet=buy-sell;

   Print(EA_NAME,
         " R10 v2 PAIRED TRAJECTORY SUMMARY",
         " steps=",r.totalSteps,
         " valid=",r.validSteps,
         " failed=",r.failedSteps,
         " gross ",DoubleToString(r.initialGross,2),
         "->",DoubleToString(r.finalGross,2),
         " net ",DoubleToString(r.initialNet,2),
         "->",DoubleToString(r.finalNet,2),
         " cumulativeGrossRelief=",DoubleToString(r.cumulativeGrossRelief,2),
         " cumulativeNetDelta=",DoubleToString(r.cumulativeNetDelta,2),
         " grossMonotonic=",r.grossMonotonic ? "PASS" : "FAIL",
         " balancedNetInvariant=",r.balancedNetInvariant ? "PASS" : "FAIL");
}

#endif
