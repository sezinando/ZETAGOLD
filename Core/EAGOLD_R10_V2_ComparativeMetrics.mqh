#ifndef EAGOLD_R10_V2_COMPARATIVE_METRICS_MQH
#define EAGOLD_R10_V2_COMPARATIVE_METRICS_MQH

//==================================================================
// R10 v2 — COMPARATIVE BACKTEST METRICS
// ETAPA 13.22
//
// In-memory / Journal-only measurement boundary.
// No CSV telemetry and no broker mutation.
//
// Purpose:
//   compare the observed ZETAGOLD path with the R10 v2 decision
//   projection generated from the same real broker-visible state.
//
// The module does not claim counterfactual P/L. It records only
// quantities actually available from the current decision contract.
//==================================================================

struct EAGOLD_R10V2ComparativeMetrics
{
   long   evaluations;
   long   opportunities;
   long   candidates;
   long   authorized;
   long   blocked;
   long   completed;
   long   partial;
   long   failed;

   long   shadowAuthorizedReal;
   long   shadowBlockedReal;
   long   shadowPartialReal;
   long   shadowCompletedReal;
   long   shadowFailedReal;
   long   shadowNoExecution;
   long   shadowExecutionDivergence;

   double candidateLots;
   double desiredLots;
   double authorizedLots;
   double grossReliefProjected;
   double netDeltaProjected;
   double recoveryLoadReliefProjected;
   double capitalRequiredProjected;
   double capitalCapacityLots;
   double r11CapacityLots;

   double baselineGrossExposure;
   double baselineNetExposure;
   double minimumGrossExposure;
   double maximumGrossExposure;

   // Same-trajectory comparison: baseline is the broker-visible state
   // actually observed; v2 is the deterministic projection of the contract.
   double baselineGrossCumulative;
   double v2ProjectedGrossCumulative;
   double baselineNetCumulative;
   double v2ProjectedNetCumulative;
   double grossReliefCumulative;
   double recoveryLoadReliefCumulative;
   double capitalRequiredCumulative;

   datetime firstTimestamp;
   datetime lastTimestamp;
};

EAGOLD_R10V2ComparativeMetrics g_r10V2ComparativeMetrics;

void EAGOLD_R10V2ComparativeReset()
{
   g_r10V2ComparativeMetrics.evaluations=0;
   g_r10V2ComparativeMetrics.opportunities=0;
   g_r10V2ComparativeMetrics.candidates=0;
   g_r10V2ComparativeMetrics.authorized=0;
   g_r10V2ComparativeMetrics.blocked=0;
   g_r10V2ComparativeMetrics.completed=0;
   g_r10V2ComparativeMetrics.partial=0;
   g_r10V2ComparativeMetrics.failed=0;
   g_r10V2ComparativeMetrics.shadowAuthorizedReal=0;
   g_r10V2ComparativeMetrics.shadowBlockedReal=0;
   g_r10V2ComparativeMetrics.shadowPartialReal=0;
   g_r10V2ComparativeMetrics.shadowCompletedReal=0;
   g_r10V2ComparativeMetrics.shadowFailedReal=0;
   g_r10V2ComparativeMetrics.shadowNoExecution=0;
   g_r10V2ComparativeMetrics.shadowExecutionDivergence=0;
   g_r10V2ComparativeMetrics.candidateLots=0.0;
   g_r10V2ComparativeMetrics.desiredLots=0.0;
   g_r10V2ComparativeMetrics.authorizedLots=0.0;
   g_r10V2ComparativeMetrics.grossReliefProjected=0.0;
   g_r10V2ComparativeMetrics.netDeltaProjected=0.0;
   g_r10V2ComparativeMetrics.recoveryLoadReliefProjected=0.0;
   g_r10V2ComparativeMetrics.capitalRequiredProjected=0.0;
   g_r10V2ComparativeMetrics.capitalCapacityLots=0.0;
   g_r10V2ComparativeMetrics.r11CapacityLots=0.0;
   g_r10V2ComparativeMetrics.baselineGrossExposure=0.0;
   g_r10V2ComparativeMetrics.baselineNetExposure=0.0;
   g_r10V2ComparativeMetrics.minimumGrossExposure=0.0;
   g_r10V2ComparativeMetrics.maximumGrossExposure=0.0;
   g_r10V2ComparativeMetrics.baselineGrossCumulative=0.0;
   g_r10V2ComparativeMetrics.v2ProjectedGrossCumulative=0.0;
   g_r10V2ComparativeMetrics.baselineNetCumulative=0.0;
   g_r10V2ComparativeMetrics.v2ProjectedNetCumulative=0.0;
   g_r10V2ComparativeMetrics.grossReliefCumulative=0.0;
   g_r10V2ComparativeMetrics.recoveryLoadReliefCumulative=0.0;
   g_r10V2ComparativeMetrics.capitalRequiredCumulative=0.0;
   g_r10V2ComparativeMetrics.firstTimestamp=0;
   g_r10V2ComparativeMetrics.lastTimestamp=0;
}

void EAGOLD_R10V2ComparativeObserve(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2DecisionContract &contract)
{
   datetime now=ctx.timestamp;
   g_r10V2ComparativeMetrics.evaluations++;

   if(g_r10V2ComparativeMetrics.firstTimestamp==0)
      g_r10V2ComparativeMetrics.firstTimestamp=now;
   g_r10V2ComparativeMetrics.lastTimestamp=now;

   g_r10V2ComparativeMetrics.baselineGrossExposure=ctx.grossExposure;
   g_r10V2ComparativeMetrics.baselineNetExposure=ctx.netExposure;
   g_r10V2ComparativeMetrics.baselineGrossCumulative+=ctx.grossExposure;
   g_r10V2ComparativeMetrics.baselineNetCumulative+=ctx.netExposure;
   g_r10V2ComparativeMetrics.v2ProjectedGrossCumulative+=
      (contract.state==EAGOLD_R10V2_DECISION_AUTHORIZED ? contract.grossAfter : ctx.grossExposure);
   g_r10V2ComparativeMetrics.v2ProjectedNetCumulative+=
      (contract.state==EAGOLD_R10V2_DECISION_AUTHORIZED ? contract.netAfter : ctx.netExposure);

   if(g_r10V2ComparativeMetrics.minimumGrossExposure<=0.0 ||
      ctx.grossExposure<g_r10V2ComparativeMetrics.minimumGrossExposure)
      g_r10V2ComparativeMetrics.minimumGrossExposure=ctx.grossExposure;

   if(ctx.grossExposure>g_r10V2ComparativeMetrics.maximumGrossExposure)
      g_r10V2ComparativeMetrics.maximumGrossExposure=ctx.grossExposure;

   if(contract.opportunity!=EAGOLD_R10V2_OPP_NONE)
      g_r10V2ComparativeMetrics.opportunities++;

   if(contract.candidateLots>=Lot)
      g_r10V2ComparativeMetrics.candidates++;

   if(contract.state==EAGOLD_R10V2_DECISION_AUTHORIZED)
      g_r10V2ComparativeMetrics.authorized++;
   else if(contract.state==EAGOLD_R10V2_DECISION_BLOCKED)
      g_r10V2ComparativeMetrics.blocked++;

   g_r10V2ComparativeMetrics.candidateLots+=MathMax(0.0,contract.candidateLots);
   g_r10V2ComparativeMetrics.desiredLots+=MathMax(0.0,contract.desiredLots);
   g_r10V2ComparativeMetrics.authorizedLots+=MathMax(0.0,contract.authorizedLots);
   g_r10V2ComparativeMetrics.grossReliefProjected+=MathMax(0.0,contract.grossRelief);
   g_r10V2ComparativeMetrics.netDeltaProjected+=contract.netDelta;
   g_r10V2ComparativeMetrics.recoveryLoadReliefProjected+=MathMax(0.0,contract.recoveryLoadRelief);
   g_r10V2ComparativeMetrics.capitalRequiredProjected+=MathMax(0.0,contract.capitalReservationRequired);
   g_r10V2ComparativeMetrics.grossReliefCumulative+=MathMax(0.0,contract.grossRelief);
   g_r10V2ComparativeMetrics.recoveryLoadReliefCumulative+=MathMax(0.0,contract.recoveryLoadRelief);
   g_r10V2ComparativeMetrics.capitalRequiredCumulative+=MathMax(0.0,contract.capitalReservationRequired);
   g_r10V2ComparativeMetrics.capitalCapacityLots+=MathMax(0.0,contract.capitalCapacity);
   g_r10V2ComparativeMetrics.r11CapacityLots+=MathMax(0.0,contract.r11Capacity);
}

void EAGOLD_R10V2ComparativeRecordDecisionVsExecution(
   EAGOLD_R10V2DecisionState decisionState,
   bool executionAttempted,
   EAGOLD_ActionResult result)
{
   if(decisionState==EAGOLD_R10V2_DECISION_AUTHORIZED)
   {
      if(!executionAttempted)
      {
         g_r10V2ComparativeMetrics.shadowAuthorizedReal++;
         g_r10V2ComparativeMetrics.shadowNoExecution++;
         return;
      }

      g_r10V2ComparativeMetrics.shadowAuthorizedReal++;
      if(result==EAGOLD_ACTION_PARTIAL)
         g_r10V2ComparativeMetrics.shadowPartialReal++;
      else if(result==EAGOLD_ACTION_COMPLETED)
         g_r10V2ComparativeMetrics.shadowCompletedReal++;
      else if(result==EAGOLD_ACTION_FAILED)
         g_r10V2ComparativeMetrics.shadowFailedReal++;
      else if(result==EAGOLD_ACTION_BLOCKED)
         g_r10V2ComparativeMetrics.shadowBlockedReal++;

      if(result==EAGOLD_ACTION_BLOCKED || result==EAGOLD_ACTION_FAILED)
         g_r10V2ComparativeMetrics.shadowExecutionDivergence++;
   }
   else if(decisionState==EAGOLD_R10V2_DECISION_BLOCKED)
   {
      g_r10V2ComparativeMetrics.shadowBlockedReal++;
   }
}

void EAGOLD_R10V2ComparativeRecordExecution(EAGOLD_ActionResult result)
{
   if(result==EAGOLD_ACTION_COMPLETED)
      g_r10V2ComparativeMetrics.completed++;
   else if(result==EAGOLD_ACTION_PARTIAL)
      g_r10V2ComparativeMetrics.partial++;
   else if(result==EAGOLD_ACTION_FAILED)
      g_r10V2ComparativeMetrics.failed++;
}


void EAGOLD_R10V2ComparativeRecordTrajectory(
   double baselineGross,
   double baselineNet,
   double projectedGross,
   double projectedNet,
   double projectedGrossRelief,
   double projectedRecoveryLoadRelief,
   double projectedCapitalRequired)
{
   g_r10V2ComparativeMetrics.baselineGrossExposure=baselineGross;
   g_r10V2ComparativeMetrics.baselineNetExposure=baselineNet;

   g_r10V2ComparativeMetrics.baselineGrossCumulative+=baselineGross;
   g_r10V2ComparativeMetrics.baselineNetCumulative+=baselineNet;
   g_r10V2ComparativeMetrics.v2ProjectedGrossCumulative+=projectedGross;
   g_r10V2ComparativeMetrics.v2ProjectedNetCumulative+=projectedNet;

   g_r10V2ComparativeMetrics.grossReliefCumulative+=MathMax(0.0,projectedGrossRelief);
   g_r10V2ComparativeMetrics.recoveryLoadReliefCumulative+=MathMax(0.0,projectedRecoveryLoadRelief);
   g_r10V2ComparativeMetrics.capitalRequiredCumulative+=MathMax(0.0,projectedCapitalRequired);

   if(g_r10V2ComparativeMetrics.minimumGrossExposure<=0.0 ||
      baselineGross<g_r10V2ComparativeMetrics.minimumGrossExposure)
      g_r10V2ComparativeMetrics.minimumGrossExposure=baselineGross;

   if(baselineGross>g_r10V2ComparativeMetrics.maximumGrossExposure)
      g_r10V2ComparativeMetrics.maximumGrossExposure=baselineGross;
}

void EAGOLD_R10V2ComparativeJournalSummary()
{
   Print(EA_NAME,
      " R10 V2 COMPARATIVE SUMMARY evaluations=",g_r10V2ComparativeMetrics.evaluations,
      " opportunities=",g_r10V2ComparativeMetrics.opportunities,
      " candidates=",g_r10V2ComparativeMetrics.candidates,
      " authorized=",g_r10V2ComparativeMetrics.authorized,
      " blocked=",g_r10V2ComparativeMetrics.blocked,
      " candidateLots=",DoubleToString(g_r10V2ComparativeMetrics.candidateLots,DigitsLots),
      " desiredLots=",DoubleToString(g_r10V2ComparativeMetrics.desiredLots,DigitsLots),
      " authorizedLots=",DoubleToString(g_r10V2ComparativeMetrics.authorizedLots,DigitsLots),
      " grossReliefProjected=",DoubleToString(g_r10V2ComparativeMetrics.grossReliefProjected,DigitsLots),
      " recoveryLoadReliefProjected=",DoubleToString(g_r10V2ComparativeMetrics.recoveryLoadReliefProjected,2),
      " capitalRequiredProjected=",DoubleToString(g_r10V2ComparativeMetrics.capitalRequiredProjected,2),
      " baselineGrossCum=",DoubleToString(g_r10V2ComparativeMetrics.baselineGrossCumulative,2),
      " v2GrossCum=",DoubleToString(g_r10V2ComparativeMetrics.v2ProjectedGrossCumulative,2),
      " baselineNetCum=",DoubleToString(g_r10V2ComparativeMetrics.baselineNetCumulative,2),
      " v2NetCum=",DoubleToString(g_r10V2ComparativeMetrics.v2ProjectedNetCumulative,2),
      " completed=",g_r10V2ComparativeMetrics.completed,
      " partial=",g_r10V2ComparativeMetrics.partial,
      " failed=",g_r10V2ComparativeMetrics.failed,
      " shadowAuthorized=",g_r10V2ComparativeMetrics.shadowAuthorizedReal,
      " shadowBlocked=",g_r10V2ComparativeMetrics.shadowBlockedReal,
      " shadowPartial=",g_r10V2ComparativeMetrics.shadowPartialReal,
      " shadowCompleted=",g_r10V2ComparativeMetrics.shadowCompletedReal,
      " shadowFailed=",g_r10V2ComparativeMetrics.shadowFailedReal,
      " shadowNoExecution=",g_r10V2ComparativeMetrics.shadowNoExecution,
      " shadowDivergence=",g_r10V2ComparativeMetrics.shadowExecutionDivergence);
}

#endif
