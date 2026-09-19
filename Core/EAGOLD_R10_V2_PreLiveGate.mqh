#ifndef EAGOLD_R10_V2_PRELIVE_GATE_MQH
#define EAGOLD_R10_V2_PRELIVE_GATE_MQH

//==================================================================
// R10 v2 — PRE-LIVE GATE
// ETAPA 13.29
//
// Final explicit boundary before R10 v2 execution can be enabled.
//
// This gate does NOT enable execution automatically.
// It returns TRUE only when every required authority is coherent.
//==================================================================

enum EAGOLD_R10V2PreLiveReason
{
   EAGOLD_R10V2_PRELIVE_OK=0,
   EAGOLD_R10V2_PRELIVE_FEATURE_DISABLED,
   EAGOLD_R10V2_PRELIVE_NO_OPPORTUNITY,
   EAGOLD_R10V2_PRELIVE_CONTRACT_INVALID,
   EAGOLD_R10V2_PRELIVE_VALIDATION_FAILED,
   EAGOLD_R10V2_PRELIVE_SAFETY_FAILED,
   EAGOLD_R10V2_PRELIVE_RECONCILIATION_REQUIRED,
   EAGOLD_R10V2_PRELIVE_DUPLICATE_GUARD,
   EAGOLD_R10V2_PRELIVE_CAPITAL_INVALID
};

string EAGOLD_R10V2PreLiveReasonName(EAGOLD_R10V2PreLiveReason reason)
{
   if(reason==EAGOLD_R10V2_PRELIVE_FEATURE_DISABLED)return("FEATURE_DISABLED");
   if(reason==EAGOLD_R10V2_PRELIVE_NO_OPPORTUNITY)return("NO_OPPORTUNITY");
   if(reason==EAGOLD_R10V2_PRELIVE_CONTRACT_INVALID)return("CONTRACT_INVALID");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_FAILED)return("VALIDATION_FAILED");
   if(reason==EAGOLD_R10V2_PRELIVE_SAFETY_FAILED)return("SAFETY_FAILED");
   if(reason==EAGOLD_R10V2_PRELIVE_RECONCILIATION_REQUIRED)return("RECONCILIATION_REQUIRED");
   if(reason==EAGOLD_R10V2_PRELIVE_DUPLICATE_GUARD)return("DUPLICATE_GUARD");
   if(reason==EAGOLD_R10V2_PRELIVE_CAPITAL_INVALID)return("CAPITAL_INVALID");
   return("OK");
}

// Explicit execution switch. Kept separate from the historical
// backtest/simulation switch. Default is OFF.
bool EAGOLD_R10V2PreLiveFeatureEnabled()
{
   return(P09_12_R10V2PreLiveEnable);
}

bool EAGOLD_R10V2PreLiveGate(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2DecisionContract &contract,
   bool preExecutionValidationOk,
   EAGOLD_R10V2ValidationReason validationReason,
   EAGOLD_R10V2SafetyReason safetyReason,
   EAGOLD_R10V2PreLiveReason &reason)
{
   reason=EAGOLD_R10V2_PRELIVE_OK;

   if(!EAGOLD_R10V2PreLiveFeatureEnabled())
   {
      reason=EAGOLD_R10V2_PRELIVE_FEATURE_DISABLED;
      return(false);
   }

   if(contract.opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      reason=EAGOLD_R10V2_PRELIVE_NO_OPPORTUNITY;
      return(false);
   }

   if(!EAGOLD_R10V2DecisionContractCanHandoff(contract))
   {
      reason=EAGOLD_R10V2_PRELIVE_CONTRACT_INVALID;
      return(false);
   }

   if(!preExecutionValidationOk ||
      validationReason!=EAGOLD_R10V2_VALIDATION_OK)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_FAILED;
      return(false);
   }

   if(safetyReason!=EAGOLD_R10V2_SAFETY_OK)
   {
      reason=EAGOLD_R10V2_PRELIVE_SAFETY_FAILED;
      return(false);
   }

   if(EAGOLD_R10ReconciliationRequired())
   {
      reason=EAGOLD_R10V2_PRELIVE_RECONCILIATION_REQUIRED;
      return(false);
   }

   if(EAGOLD_R10V2ExecutionDuplicate(contract))
   {
      reason=EAGOLD_R10V2_PRELIVE_DUPLICATE_GUARD;
      return(false);
   }

   if(contract.capitalReservationRequired<0.0 ||
      contract.capitalCapacity<0.0)
   {
      reason=EAGOLD_R10V2_PRELIVE_CAPITAL_INVALID;
      return(false);
   }

   return(true);
}

#endif
