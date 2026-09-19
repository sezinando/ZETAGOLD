#ifndef EAGOLD_R10_V2_RUNTIME_DIAGNOSTIC_MQH
#define EAGOLD_R10_V2_RUNTIME_DIAGNOSTIC_MQH

// ETAPA 13.39 — Runtime diagnostic. Read-only; never enables execution.

void EAGOLD_R10V2RuntimeDiagnostic(
   EAGOLD_R10V2EnableMode mode,
   bool preExecutionOk,
   EAGOLD_R10V2ValidationReason preExecutionReason,
   bool preLiveOk,
   EAGOLD_R10V2PreLiveValidationReason preLiveReason,
   EAGOLD_R10V2SafetyReason safetyReason,
   bool reconciliationRequired,
   bool executionEligible,
   bool economicExecutionAllowed,
   double capitalAvailable,
   double r11Capacity,
   bool controlledAllowed)
{
   Print("R10 V2 RUNTIME GATE | mode=",EAGOLD_R10V2EnableModeName(mode),
         " opportunity=",IntegerToString((int)g_r10V2Opportunity),
         " state=",IntegerToString((int)g_r10V2DecisionContract.state),
         " preexec=",preExecutionOk?"PASS":"FAIL",
         " reason=",EAGOLD_R10V2ValidationReasonName(preExecutionReason),
         " prelive=",preLiveOk?"PASS":"FAIL",
         " reason=",EAGOLD_R10V2PreLiveValidationReasonName(preLiveReason),
         " safety=",EAGOLD_R10V2SafetyReasonName(safetyReason),
         " recon=",reconciliationRequired?"PENDING":"CLEAR",
         " eligible=",executionEligible?"YES":"NO",
         " economic=",economicExecutionAllowed?"YES":"NO",
         " capital=",DoubleToString(capitalAvailable,DigitsLots),
         " r11=",DoubleToString(r11Capacity,DigitsLots),
         " controlled=",controlledAllowed?"YES":"NO",
         " execution=DISABLED");
}

#endif
