#ifndef EAGOLD_R10_V2_RELEASE_READINESS_MQH
#define EAGOLD_R10_V2_RELEASE_READINESS_MQH

// ETAPA 13.42/13.43 — release readiness and invariant snapshot.
// Read-only. This does not switch execution on.

bool EAGOLD_R10V2ReleaseReadinessSnapshot()
{
   bool modeSafe=EAGOLD_R10V2ControlledModeSafe(
      EAGOLD_R10V2ControlledEnableMode(),
      g_r10V2PreExecutionGate,
      g_r10V2PreLiveGate,
      g_r10V2DecisionContract.executionEligible,
      EAGOLD_EconomicExecutionAllowed());

   bool safetyOk=(EAGOLD_R10V2SafetyReasonName(EAGOLD_R10V2_SAFETY_OK)=="OK");

   Print(EA_NAME,
         " R10 V2 READINESS | mode=",
         EAGOLD_R10V2EnableModeName(EAGOLD_R10V2ControlledEnableMode()),
         " modeSafe=",modeSafe?"PASS":"FAIL",
         " feature=",EAGOLD_R10V2PreLiveFeatureEnabled()?"ON":"OFF",
         " executionEligible=",g_r10V2DecisionContract.executionEligible?"YES":"NO",
         " controlledAllowed=NO (master mode remains OFF)",
         " capitalRemaining=",
         DoubleToString(EAGOLD_R10V2CapitalAvailable(),2),
         " reconciliation=",
         EAGOLD_R10ReconciliationRequired()?"PENDING":"CLEAR");

   return(modeSafe && safetyOk);
}

#endif
