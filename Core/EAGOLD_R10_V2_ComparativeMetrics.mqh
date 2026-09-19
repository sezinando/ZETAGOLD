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
   g_r10V2ComparativeMetrics.capitalCapacityLots+=MathMax(0.0,contract.capitalCapacity);
   g_r10V2ComparativeMetrics.r11CapacityLots+=MathMax(0.0,contract.r11Capacity);
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
      " completed=",g_r10V2ComparativeMetrics.completed,
      " partial=",g_r10V2ComparativeMetrics.partial,
      " failed=",g_r10V2ComparativeMetrics.failed);
}

#endif
