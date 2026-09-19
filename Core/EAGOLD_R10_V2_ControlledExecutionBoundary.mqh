#ifndef EAGOLD_R10_V2_CONTROLLED_EXECUTION_BOUNDARY_MQH
#define EAGOLD_R10_V2_CONTROLLED_EXECUTION_BOUNDARY_MQH

// ETAPA 13.44 — explicit controlled execution boundary.
// This is the ONLY place that may arm executionEligible.
// Defaults remain OFF + PreLive OFF, therefore no live execution
// is possible unless both explicit switches are changed.

bool EAGOLD_R10V2ArmControlledExecution(
   EAGOLD_R10V2EnableMode mode,
   bool preExecutionOk,
   bool preLiveOk,
   bool safetyOk,
   bool reconciliationRequired,
   bool duplicate,
   EAGOLD_R10V2DecisionContract &contract)
{
   contract.executionEligible=false;

   if(mode!=EAGOLD_R10V2_ENABLE_CONTROLLED)
      return(false);
   if(!EAGOLD_R10V2PreLiveFeatureEnabled())
      return(false);
   if(!preExecutionOk || !preLiveOk || !safetyOk)
      return(false);
   if(reconciliationRequired || duplicate)
      return(false);
   if(contract.state!=EAGOLD_R10V2_DECISION_AUTHORIZED)
      return(false);
   if(contract.action!=EAGOLD_R10V2_HANDOFF_PARTIAL_CLOSE)
      return(false);
   if(contract.authorizedLots<Lot)
      return(false);
   if(contract.capitalCapacity<0.0 ||
      contract.exposureCapacity<0.0 ||
      contract.r11Capacity<0.0 ||
      contract.brokerCapacity<0.0)
      return(false);

   contract.executionEligible=true;
   return(true);
}

#endif
