#property strict
#property version   "1.116"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Operational State + Isolated R1 Admission Control + R13 Recovery Satellite + R12 M5 Observer + Excursion Telemetry + Counterfactual Path Telemetry + Adaptive Profit Guard + Trading Window + Spread Guard"
#include "../Core/EAGOLD_Config.mqh"
#include "../Core/EAGOLD_ActionContract.mqh"
#include "../Core/EAGOLD_Orders.mqh"
#include "../Core/EAGOLD_R10_V2_Context.mqh"
#include "../Core/EAGOLD_R10_V2_Opportunity.mqh"
#include "../Core/EAGOLD_R10_V2_DecisionContract.mqh"
#include "../Core/EAGOLD_R10_V2_DecisionPlan.mqh"
#include "../Core/EAGOLD_R10_V2_ContractValidation.mqh"
#include "../Core/EAGOLD_R10_V2_ExecutionAdapter.mqh"
#include "../Core/EAGOLD_R10_V2_TargetSelection.mqh"
#include "../Core/EAGOLD_R10_V2_BalancedPair.mqh"
#include "../Core/EAGOLD_R10_V2_ReductionCapacity.mqh"
#include "../Core/EAGOLD_R10_V2_CapitalLedger.mqh"
#include "../Core/EAGOLD_R10_V2_R11Governor.mqh"
#include "../Core/EAGOLD_R10_V2_StructuralProjection.mqh"
#include "../Core/EAGOLD_R10_V2_ComparativeMetrics.mqh"
bool IsR13Order();
bool IsR13OwnershipConfigurationValid();
bool EAGOLDValidateOwnershipConfiguration();
#include "../Core/EAGOLD_R12_RegimeObserver.mqh"
#include "../Core/EAGOLD_ExcursionTracker.mqh"
#include "../Core/EAGOLD_CounterfactualPathTelemetry.mqh"
#include "../Core/EAGOLD_AdaptiveProfitGuard.mqh"
#include "../Core/EAGOLD_TradingGuards.mqh"
#include "../Core/EAGOLD_Execution.mqh"
string EA_NAME="EAGOLD";string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";string STATE_PREFIX="EAGOLD_STATE_";bool g_r9HedgeActive=false;EAGOLD_R10V2Context g_r10V2Context;EAGOLD_R10V2Opportunity g_r10V2Opportunity=EAGOLD_R10V2_OPP_NONE;EAGOLD_R10V2DecisionContract g_r10V2DecisionContract;EAGOLD_R10V2Target g_r10V2Target;double g_r10V2CandidateLots=0.0;double g_r10V2DesiredLots=0.0;double g_r10V2CapitalCapacity=0.0;double g_r10V2ExposureCapacity=0.0;double g_r10V2R11Capacity=0.0;double g_r10V2BrokerCapacity=0.0;double g_r10V2AuthorizedLots=0.0;EAGOLD_R10V2R11ReductionCapacity g_r10V2R11ReductionCapacity;EAGOLD_R10V2StructuralProjection g_r10V2StructuralProjection;EAGOLD_R10V2BalancedPair g_r10V2BalancedPair;EAGOLD_R10V2BalancedProjection g_r10V2BalancedProjection;bool g_r10V2PreExecutionGate=false;EAGOLD_R10V2ValidationReason g_r10V2PreExecutionReason=EAGOLD_R10V2_VALIDATION_NO_OPPORTUNITY;int g_r9ProcessedTickets[];datetime g_r10LastAction=0;string g_r1LastDecision="DISABLED";string g_r1LastReason="";datetime g_r1LastDecisionTime=0;bool g_r10RecoveryCycleActive=false;double g_r10RecoveryStartEquity=0.0;double g_r10RecoveryWorstEquity=0.0;EAGOLD_TickPolicy g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;
#include "../Engines/EAGOLD_R10_Reconciliation.mqh"
#include "../Engines/EAGOLD_R1_Admission_v0116.mqh"
#include "../Engines/EAGOLD_Engine1_LifecycleRecovery_v0116.mqh"
#include "../Engines/EAGOLD_Engine2_Exposure_v0116.mqh"
#include "../Core/EAGOLD_R1_AtomicAdmission.mqh"
#include "../Core/EAGOLD_R7_KeepAlive.mqh"
double PointsToPrice(double points){return(points*Point);}double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}
void EAGOLD_ResetTickTransaction(){g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;}
bool EAGOLD_EconomicExecutionAllowed(){return(g_eagoldTickPolicy==EAGOLD_TICK_CONTINUE);}
void EAGOLD_ApplyActionResult(EAGOLD_ActionResult result,string engine,string action,int direction,double lots){EAGOLD_TickPolicy policy=EAGOLD_PolicyForResult(result);Print(EA_NAME," ACTION CONTRACT engine=",engine," action=",action," result=",EAGOLD_ActionResultName(result)," policy=",EAGOLD_TickPolicyName(policy)," direction=",(direction==OP_BUY?"BUY":"SELL")," lots=",DoubleToString(lots,DigitsLots));EAGOLD_ExcursionTrackerNoteRealization(engine,action,result);if(result==EAGOLD_ACTION_PARTIAL)EAGOLD_R10RequestReconciliation();if(policy==EAGOLD_TICK_HALT_FOR_RECONCILIATION)g_eagoldTickPolicy=EAGOLD_TICK_HALT_FOR_RECONCILIATION;else if(policy==EAGOLD_TICK_CONSUME&&g_eagoldTickPolicy==EAGOLD_TICK_CONTINUE)g_eagoldTickPolicy=EAGOLD_TICK_CONSUME;if(result==EAGOLD_ACTION_COMPLETED&&CountEAGOLDOrders()==0)EAGOLD_ExcursionTrackerFinalize();}
#include "../UI/EAGOLD_RealizationCascade.mqh"
#include "../Engines/EAGOLD_R13_Satellite.mqh"
#include "../Core/EAGOLD_Persistence.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"
#include "../UI/EAGOLD_ChartBasketGuides.mqh"
R13ObserverState g_r13Observer;
double EngineMarkerPipsToPrice(double pips){double pipSize=Point;if(Digits==3||Digits==5)pipSize=Point*10.0;return(pips*pipSize);}int EngineMarkerStackLevel(string engine){if(engine=="R1")return(0);if(engine=="R1.1")return(1);if(engine=="R4")return(2);if(engine=="R5"||engine=="BRX")return(3);if(engine=="R7")return(4);if(engine=="R10")return(5);if(engine=="R13")return(6);return(7);}string ResolveEngineMarkerFont(){return("Arial");}
void CreateEngineActionMarker(string engine,string action,int direction,double lots){if(!EnableEngineActionMarkers||Bars<1)return;RefreshRates();datetime stamp=Time[0];double price=NormalizePrice(direction==OP_BUY?Low[0]:High[0]);color markerColor=CascadeEngineColor(engine);string name=ENGINE_MARKER_PREFIX+IntegerToString((int)stamp)+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());if(ObjectCreate(0,name,OBJ_ARROW,0,stamp,price)){ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,name,OBJPROP_WIDTH,2);ObjectSetInteger(0,name,OBJPROP_COLOR,markerColor);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);ObjectSetInteger(0,name,OBJPROP_BACK,false);ObjectSetInteger(0,name,OBJPROP_ZORDER,5);}EAGOLD_ActionCascadeAdd(engine);ChartRedraw(0);}
int OnInit(){ObjectsDeleteAll(0,ENGINE_MARKER_PREFIX);ObjectsDeleteAll(0,R10_MARKER_PREFIX);ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_r10LastAction=0;g_r10RecoveryCycleActive=false;g_r10RecoveryStartEquity=0.0;g_r10RecoveryWorstEquity=0.0;g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;if(!EAGOLDValidateOwnershipConfiguration()||!IsR13OwnershipConfigurationValid()){Print(EA_NAME," INIT BLOCKED: unsafe order ownership configuration. EAGOLD will not trade this chart.");return(INIT_FAILED);}EAGOLD_R12Reset(g_r12State);EAGOLD_R12ResetHistory();EAGOLD_ExcursionTrackerReset();EAGOLD_AdaptiveProfitGuardReset();EAGOLD_R10V2ContextReset(g_r10V2Context);g_r10V2Opportunity=EAGOLD_R10V2_OPP_NONE;EAGOLD_R10V2DecisionContractReset(g_r10V2DecisionContract);g_r10V2Target.found=false;g_r10V2Target.ticket=-1;g_r10V2CandidateLots=0.0;g_r10V2DesiredLots=0.0;g_r10V2CapitalCapacity=0.0;g_r10V2ExposureCapacity=0.0;g_r10V2R11Capacity=0.0;g_r10V2BrokerCapacity=0.0;g_r10V2AuthorizedLots=0.0;EAGOLD_R10V2R11ReductionCapacityReset(g_r10V2R11ReductionCapacity);EAGOLD_R10V2StructuralProjectionReset(g_r10V2StructuralProjection);EAGOLD_R10V2BalancedPairReset(g_r10V2BalancedPair);EAGOLD_R10V2BalancedProjectionReset(g_r10V2BalancedProjection);g_r10V2PreExecutionGate=false;g_r10V2PreExecutionReason=EAGOLD_R10V2_VALIDATION_NO_OPPORTUNITY;EAGOLD_R10V2CapitalLedgerReset();EAGOLD_R10V2ComparativeReset();if(EAGOLD_PersistenceEnabled())LoadPersistedStrategicState();else{g_modPanelMinProfit=0.0;g_modPanelMaxLots=0.0;g_modPanelInitialized=true;g_panelMinProfit=0.0;g_panelMaxLots=0.0;g_panelInitialized=true;}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R13ResetObserverState(g_r13Observer);R9SeedExistingPositions();R10RecoveryUpdateState();EAGOLD_R12Update(g_r12State);R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);EAGOLD_CreateFirstOrdersAtomic();EAGOLD_ExcursionTrackerObserve();EAGOLD_AdaptiveProfitGuardObserve();R10RecoveryUpdateState();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){EAGOLD_R10V2ComparativeJournalSummary();if(EAGOLD_PersistenceEnabled())PersistAllState(true);EAGOLD_RealizationCascadeDelete();EAGOLD_ChartBasketGuidesDelete();EAGOLD_ModPanelDelete();}
void OnTick(){EAGOLD_ResetTickTransaction();EAGOLD_R12Update(g_r12State);EAGOLD_ExcursionTrackerObserve();EAGOLD_AdaptiveProfitGuardObserve();EAGOLD_SuspendInvalidPendingEntries();bool reconciliationRequiredBefore=EAGOLD_R10ReconciliationRequired();bool reconciliationOk=EAGOLD_R10ReconcileIfRequired();if(!reconciliationOk){g_eagoldTickPolicy=EAGOLD_TICK_HALT_FOR_RECONCILIATION;}else if(reconciliationRequiredBefore){EAGOLD_R10V2ExecutionResetAfterReconciliation();}R10RecoveryUpdateState();EAGOLD_R10V2ContextBuild(g_r10V2Context);g_r10V2Opportunity=EAGOLD_R10V2EvaluateOpportunity(g_r10V2Context);EAGOLD_R10V2SelectTarget(g_r10V2Context,g_r10V2Opportunity,g_r10V2Target);EAGOLD_R10V2BalancedPairReset(g_r10V2BalancedPair);EAGOLD_R10V2BalancedProjectionReset(g_r10V2BalancedProjection);EAGOLD_R10V2CapitalLedgerSync();if(g_r10V2Opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION){EAGOLD_R10V2SelectBalancedPair(g_r10V2Context,g_r10V2BalancedPair);if(g_r10V2BalancedPair.found){g_r10V2Target.found=true;g_r10V2Target.ticket=g_r10V2BalancedPair.buy.ticket;g_r10V2Target.direction=OP_BUY;g_r10V2Target.candidateLots=g_r10V2BalancedPair.buy.lots;g_r10V2Target.floatingProfit=g_r10V2BalancedPair.buy.floatingProfit;g_r10V2Target.lossPerLot=g_r10V2BalancedPair.buy.lossPerLot;g_r10V2Target.distanceToMarket=g_r10V2BalancedPair.buy.distanceToMarket;g_r10V2Target.recoveryLoad=g_r10V2BalancedPair.buy.recoveryLoad;g_r10V2Target.relativeVolume=g_r10V2BalancedPair.buy.relativeVolume;g_r10V2Target.structuralPosition=g_r10V2BalancedPair.buy.structuralPosition;g_r10V2Target.policy=EAGOLD_R10V2_POLICY_BALANCED;g_r10V2CandidateLots=g_r10V2BalancedPair.commonCandidateLots;g_r10V2DesiredLots=g_r10V2BalancedPair.commonDesiredLots;g_r10V2ExposureCapacity=MathMax(0.0,MathMin(g_r10V2Context.buyLots,g_r10V2Context.sellLots)-Lot);EAGOLD_R10V2Target balancedBuyTarget;EAGOLD_R10V2Target balancedSellTarget;balancedBuyTarget.found=true;balancedBuyTarget.ticket=g_r10V2BalancedPair.buy.ticket;balancedBuyTarget.direction=OP_BUY;balancedBuyTarget.candidateLots=g_r10V2BalancedPair.buy.lots;balancedBuyTarget.floatingProfit=g_r10V2BalancedPair.buy.floatingProfit;balancedBuyTarget.lossPerLot=g_r10V2BalancedPair.buy.lossPerLot;balancedBuyTarget.distanceToMarket=g_r10V2BalancedPair.buy.distanceToMarket;balancedBuyTarget.recoveryLoad=g_r10V2BalancedPair.buy.recoveryLoad;balancedBuyTarget.relativeVolume=g_r10V2BalancedPair.buy.relativeVolume;balancedBuyTarget.structuralPosition=g_r10V2BalancedPair.buy.structuralPosition;balancedBuyTarget.policy=EAGOLD_R10V2_POLICY_BALANCED;balancedSellTarget.found=true;balancedSellTarget.ticket=g_r10V2BalancedPair.sell.ticket;balancedSellTarget.direction=OP_SELL;balancedSellTarget.candidateLots=g_r10V2BalancedPair.sell.lots;balancedSellTarget.floatingProfit=g_r10V2BalancedPair.sell.floatingProfit;balancedSellTarget.lossPerLot=g_r10V2BalancedPair.sell.lossPerLot;balancedSellTarget.distanceToMarket=g_r10V2BalancedPair.sell.distanceToMarket;balancedSellTarget.recoveryLoad=g_r10V2BalancedPair.sell.recoveryLoad;balancedSellTarget.relativeVolume=g_r10V2BalancedPair.sell.relativeVolume;balancedSellTarget.structuralPosition=g_r10V2BalancedPair.sell.structuralPosition;balancedSellTarget.policy=EAGOLD_R10V2_POLICY_BALANCED;g_r10V2BrokerCapacity=MathMin(EAGOLD_R10V2BrokerCapacity(balancedBuyTarget),EAGOLD_R10V2BrokerCapacity(balancedSellTarget));double buyR11Desired=g_r10V2DesiredLots;double sellR11Desired=g_r10V2DesiredLots;EAGOLD_R10V2R11ReductionCapacity buyR11;EAGOLD_R10V2R11ReductionCapacity sellR11;EAGOLD_R10V2R11ReductionCapacityBuild(g_r10V2Context,balancedBuyTarget,buyR11Desired,buyR11);EAGOLD_R10V2R11ReductionCapacityBuild(g_r10V2Context,balancedSellTarget,sellR11Desired,sellR11);g_r10V2R11Capacity=MathMin(buyR11.capacityLots,sellR11.capacityLots);g_r10V2CapitalCapacity=g_r10V2BalancedPair.commonDesiredLots;if(g_r10V2BalancedPair.commonDesiredLots>=Lot){double buyPerLot=g_r10V2BalancedPair.buy.floatingProfit/g_r10V2BalancedPair.buy.lots;double sellPerLot=g_r10V2BalancedPair.sell.floatingProfit/g_r10V2BalancedPair.sell.lots;double lossPerCommonLot=MathMax(0.0,-(buyPerLot+sellPerLot));if(lossPerCommonLot>0.0)g_r10V2CapitalCapacity=EAGOLD_R10V2CapitalCapacityLots(lossPerCommonLot,g_r10V2DesiredLots);}g_r10V2AuthorizedLots=0.0;if(!EAGOLD_R10V2BalancedAuthorizationIntegrity(g_r10V2Context,g_r10V2BalancedPair.buy.ticket,g_r10V2BalancedPair.sell.ticket,g_r10V2BalancedPair.commonCandidateLots,g_r10V2DesiredLots,g_r10V2CapitalCapacity,g_r10V2ExposureCapacity,g_r10V2R11Capacity,g_r10V2BrokerCapacity,g_r10V2BalancedProjection,g_r10V2AuthorizedLots))g_r10V2AuthorizedLots=0.0;}else{g_r10V2CandidateLots=0.0;g_r10V2DesiredLots=0.0;g_r10V2CapitalCapacity=0.0;g_r10V2ExposureCapacity=0.0;g_r10V2R11Capacity=0.0;g_r10V2BrokerCapacity=0.0;g_r10V2AuthorizedLots=0.0;}}else{EAGOLD_R10V2R11ReductionCapacityBuild(g_r10V2Context,g_r10V2Target,g_r10V2DesiredLots,g_r10V2R11ReductionCapacity);g_r10V2R11Capacity=g_r10V2R11ReductionCapacity.capacityLots;EAGOLD_R10V2ReductionCapacityBuild(g_r10V2Context,g_r10V2Target,g_r10V2CandidateLots,g_r10V2DesiredLots,g_r10V2CapitalCapacity,g_r10V2ExposureCapacity,g_r10V2R11Capacity,g_r10V2BrokerCapacity,g_r10V2AuthorizedLots);if(!EAGOLD_R10V2AuthorizationIntegrity(g_r10V2Context,g_r10V2Target,g_r10V2DesiredLots,g_r10V2CapitalCapacity,g_r10V2ExposureCapacity,g_r10V2R11Capacity,g_r10V2BrokerCapacity,g_r10V2StructuralProjection,g_r10V2AuthorizedLots))g_r10V2AuthorizedLots=0.0;}double decisionGrossAfter=g_r10V2Context.grossExposure;
double decisionGrossRelief=0.0;
double decisionNetAfter=g_r10V2Context.netExposure;
double decisionNetDelta=0.0;
double decisionRecoveryLoadBefore=0.0;
double decisionRecoveryLoadAfter=0.0;
double decisionRecoveryLoadRelief=0.0;
bool decisionTargetFound=false;
int decisionTargetTicket=-1;
int decisionTargetTicket2=-1;
int decisionDirection=0;
bool decisionStructuralValid=false;
bool decisionStructuralBenefit=false;

if(g_r10V2BalancedPair.found)
{
   decisionTargetFound=true;
   decisionTargetTicket=g_r10V2BalancedPair.buy.ticket;
   decisionTargetTicket2=g_r10V2BalancedPair.sell.ticket;
   decisionDirection=OP_BUY;
   decisionStructuralValid=g_r10V2BalancedProjection.valid;
   decisionStructuralBenefit=g_r10V2BalancedProjection.structuralBenefit;
   decisionGrossAfter=g_r10V2BalancedProjection.grossAfter;
   decisionGrossRelief=g_r10V2BalancedProjection.grossRelief;
   decisionNetAfter=g_r10V2BalancedProjection.netAfter;
   decisionNetDelta=g_r10V2BalancedProjection.netDelta;
   decisionRecoveryLoadBefore=g_r10V2BalancedProjection.recoveryLoadBefore;
   decisionRecoveryLoadAfter=g_r10V2BalancedProjection.recoveryLoadAfter;
   decisionRecoveryLoadRelief=g_r10V2BalancedProjection.recoveryLoadRelief;
}
else if(g_r10V2Target.found)
{
   decisionTargetFound=true;
   decisionTargetTicket=g_r10V2Target.ticket;
   decisionDirection=g_r10V2Target.direction;
   decisionStructuralValid=g_r10V2StructuralProjection.valid;
   decisionStructuralBenefit=g_r10V2StructuralProjection.structuralBenefit;
   decisionGrossAfter=g_r10V2StructuralProjection.grossAfter;
   decisionGrossRelief=g_r10V2StructuralProjection.grossRelief;
   decisionNetAfter=g_r10V2StructuralProjection.netAfter;
   decisionNetDelta=g_r10V2StructuralProjection.netDelta;
   decisionRecoveryLoadBefore=g_r10V2StructuralProjection.recoveryLoadBefore;
   decisionRecoveryLoadAfter=g_r10V2StructuralProjection.recoveryLoadAfter;
   decisionRecoveryLoadRelief=g_r10V2StructuralProjection.recoveryLoadRelief;
}

double decisionCapitalReservation=0.0;
if(g_r10V2BalancedPair.found && g_r10V2AuthorizedLots>=Lot)
{
   double buyPerLot=(g_r10V2BalancedPair.buy.lots>0.0?g_r10V2BalancedPair.buy.floatingProfit/g_r10V2BalancedPair.buy.lots:0.0);
   double sellPerLot=(g_r10V2BalancedPair.sell.lots>0.0?g_r10V2BalancedPair.sell.floatingProfit/g_r10V2BalancedPair.sell.lots:0.0);
   decisionCapitalReservation=MathMax(0.0,-g_r10V2AuthorizedLots*(buyPerLot+sellPerLot));
}
g_r10V2BalancedPair.capitalRequired=decisionCapitalReservation;

EAGOLD_R10V2DecisionPlanBuild(
   g_r10V2Context,
   g_r10V2Opportunity,
   decisionTargetFound,
   decisionTargetTicket,
   decisionTargetTicket2,
   decisionDirection,
   g_r10V2CandidateLots,
   g_r10V2DesiredLots,
   g_r10V2CapitalCapacity,
   g_r10V2ExposureCapacity,
   g_r10V2R11Capacity,
   g_r10V2BrokerCapacity,
   g_r10V2AuthorizedLots,
   decisionCapitalReservation,
   decisionStructuralValid,
   decisionStructuralBenefit,
   decisionGrossAfter,
   decisionGrossRelief,
   decisionNetAfter,
   decisionNetDelta,
   decisionRecoveryLoadBefore,
   decisionRecoveryLoadAfter,
   decisionRecoveryLoadRelief,
   g_r10V2DecisionContract);

// ETAPA 13.17 — structural pre-execution gate. This validates the
// contract only; executionEligible remains false and no broker/capital
// mutation is performed here.
g_r10V2PreExecutionGate=EAGOLD_R10V2ValidatePreExecution(g_r10V2DecisionContract,g_r10V2Context,g_r10V2PreExecutionReason);
if(g_r10V2DecisionContract.state==EAGOLD_R10V2_DECISION_AUTHORIZED && !g_r10V2PreExecutionGate)
   Print(EA_NAME," R10 v2 PRE-EXECUTION GATE BLOCKED: ",EAGOLD_R10V2ValidationReasonName(g_r10V2PreExecutionReason));

// ETAPA 13.22 — journal-only comparative measurement. This is observational;
// it does not mutate broker state or capital and does not enable execution.
EAGOLD_R10V2ComparativeObserve(g_r10V2Context,g_r10V2DecisionContract);

// ETAPA 13.19 — execution adapter is wired but remains dormant while
// executionEligible=false. Balanced remains reserved for ETAPA 13.20.
if(EAGOLD_EconomicExecutionAllowed() &&
   g_r10V2DecisionContract.state==EAGOLD_R10V2_DECISION_AUTHORIZED &&
   g_r10V2PreExecutionGate &&
   g_r10V2DecisionContract.executionEligible)
{
   EAGOLD_ActionResult r10V2Result=EAGOLD_ACTION_BLOCKED;
   if(g_r10V2DecisionContract.opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      r10V2Result=EAGOLD_R10V2ExecuteBalanced(g_r10V2DecisionContract,g_r10V2PreExecutionGate);
   else
      r10V2Result=EAGOLD_R10V2ExecuteSingle(g_r10V2DecisionContract,g_r10V2PreExecutionGate);
   EAGOLD_R10V2ComparativeRecordDecisionVsExecution(g_r10V2DecisionContract.state,true,r10V2Result);
   if(r10V2Result!=EAGOLD_ACTION_BLOCKED)
   {
      EAGOLD_R10V2ComparativeRecordExecution(r10V2Result);
      EAGOLD_ApplyActionResult(r10V2Result,"R10V2","PARTIAL_CLOSE",g_r10V2DecisionContract.direction,g_r10V2DecisionContract.authorizedLots);
   }
}

// ETAPA 13.18 — reservation boundary is armed only when the execution
// boundary is explicitly open. ETAPA 13.17 keeps executionEligible=false,
// so the live/demo path cannot strand real capital before an executor exists.
if(g_r10V2DecisionContract.state==EAGOLD_R10V2_DECISION_AUTHORIZED &&
   g_r10V2PreExecutionGate &&
   g_r10V2DecisionContract.executionEligible &&
   !EAGOLD_R10V2CapitalReservationActive())
{
   EAGOLD_R10V2CapitalReserveTransaction(
      g_r10V2DecisionContract.capitalReservationRequired,
      g_r10V2DecisionContract.targetTicket,
      g_r10V2DecisionContract.targetTicket2,
      g_r10V2DecisionContract.timestamp);
}

if(EAGOLD_EconomicExecutionAllowed()){EAGOLD_ActionResult r9Result=Rule9DetectActivatedOrdersTransactional();if(r9Result!=EAGOLD_ACTION_BLOCKED)EAGOLD_ApplyActionResult(r9Result,"R9","HEDGE",HeavyDirection(),0.0);}if(EAGOLD_EconomicExecutionAllowed()){EAGOLD_ActionResult r7Result=EAGOLD_R7EnsureMissingDirectionTransactional();if(r7Result!=EAGOLD_ACTION_BLOCKED)EAGOLD_ApplyActionResult(r7Result,"R7","KEEP_ALIVE",HeavyDirection(),Lot);}if(EAGOLD_EconomicExecutionAllowed())BuyMachine();if(EAGOLD_EconomicExecutionAllowed())SellMachine();if(EAGOLD_EconomicExecutionAllowed()){EAGOLD_ActionResult r1Result=EAGOLD_CreateFirstOrdersAtomic();if(r1Result!=EAGOLD_ACTION_BLOCKED)EAGOLD_ApplyActionResult(r1Result,"R1","FIRST_SEED",HeavyDirection(),Lot);}if(EAGOLD_EconomicExecutionAllowed())TrailAllStopOrders();if(EAGOLD_EconomicExecutionAllowed())R13Observe(g_r13Observer);EAGOLD_ExcursionTrackerObserve();ObjectsDeleteAll(0,R10_MARKER_PREFIX);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(false);}
