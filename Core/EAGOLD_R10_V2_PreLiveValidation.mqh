#ifndef EAGOLD_R10_V2_PRELIVE_VALIDATION_MQH
#define EAGOLD_R10_V2_PRELIVE_VALIDATION_MQH

//==================================================================
// R10 v2 — ETAPA 13.36 PRE-LIVE VALIDATION
//
// Consolidated read-only readiness gate.
// No broker mutation, no capital reservation, no R11 mutation.
//
// Purpose:
//   verify that the complete R10 v2 safety chain is coherent before
//   the feature switch can be enabled.
//
// This gate does not enable execution.
//==================================================================

enum EAGOLD_R10V2PreLiveValidationReason
{
   EAGOLD_R10V2_PRELIVE_VALIDATION_OK=0,
   EAGOLD_R10V2_PRELIVE_VALIDATION_FEATURE_DISABLED,
   EAGOLD_R10V2_PRELIVE_VALIDATION_NO_OPPORTUNITY,
   EAGOLD_R10V2_PRELIVE_VALIDATION_CONTRACT_INVALID,
   EAGOLD_R10V2_PRELIVE_VALIDATION_PREEXEC_INVALID,
   EAGOLD_R10V2_PRELIVE_VALIDATION_SAFETY_INVALID,
   EAGOLD_R10V2_PRELIVE_VALIDATION_RECONCILIATION_PENDING,
   EAGOLD_R10V2_PRELIVE_VALIDATION_DUPLICATE,
   EAGOLD_R10V2_PRELIVE_VALIDATION_CAPITAL_INVALID,
   EAGOLD_R10V2_PRELIVE_VALIDATION_TARGET_INVALID
};

string EAGOLD_R10V2PreLiveValidationReasonName(
   EAGOLD_R10V2PreLiveValidationReason reason)
{
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_OK) return("OK");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_FEATURE_DISABLED) return("FEATURE_DISABLED");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_NO_OPPORTUNITY) return("NO_OPPORTUNITY");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_CONTRACT_INVALID) return("CONTRACT_INVALID");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_PREEXEC_INVALID) return("PREEXEC_INVALID");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_SAFETY_INVALID) return("SAFETY_INVALID");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_RECONCILIATION_PENDING) return("RECONCILIATION_PENDING");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_DUPLICATE) return("DUPLICATE");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_CAPITAL_INVALID) return("CAPITAL_INVALID");
   if(reason==EAGOLD_R10V2_PRELIVE_VALIDATION_TARGET_INVALID) return("TARGET_INVALID");
   return("UNKNOWN");
}

bool EAGOLD_R10V2PreLiveValidation(
   bool featureEnabled,
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2DecisionContract &contract,
   bool preExecutionOk,
   EAGOLD_R10V2ValidationReason preExecutionReason,
   bool safetyOk,
   EAGOLD_R10V2SafetyReason safetyReason,
   bool reconciliationRequired,
   bool duplicate,
   EAGOLD_R10V2PreLiveValidationReason &reason)
{
   reason=EAGOLD_R10V2_PRELIVE_VALIDATION_OK;

   if(!featureEnabled)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_FEATURE_DISABLED;
      return(false);
   }

   if(contract.opportunity==EAGOLD_R10V2_OPP_NONE)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_NO_OPPORTUNITY;
      return(false);
   }

   if(!EAGOLD_R10V2DecisionContractCanHandoff(contract))
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_CONTRACT_INVALID;
      return(false);
   }

   if(!preExecutionOk ||
      preExecutionReason!=EAGOLD_R10V2_VALIDATION_OK)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_PREEXEC_INVALID;
      return(false);
   }

   if(!safetyOk ||
      safetyReason!=EAGOLD_R10V2_SAFETY_OK)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_SAFETY_INVALID;
      return(false);
   }

   if(reconciliationRequired)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_RECONCILIATION_PENDING;
      return(false);
   }

   if(duplicate)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_DUPLICATE;
      return(false);
   }

   if(contract.capitalReservationRequired<0.0 ||
      contract.capitalCapacity<0.0 ||
      contract.r11Capacity<0.0 ||
      contract.brokerCapacity<0.0)
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_CAPITAL_INVALID;
      return(false);
   }

   if(contract.targetTicket<0 ||
      (contract.opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION &&
       contract.targetTicket2<0))
   {
      reason=EAGOLD_R10V2_PRELIVE_VALIDATION_TARGET_INVALID;
      return(false);
   }

   return(true);
}

#endif
