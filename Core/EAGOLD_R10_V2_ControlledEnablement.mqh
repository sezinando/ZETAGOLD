#ifndef EAGOLD_R10_V2_CONTROLLED_ENABLEMENT_MQH
#define EAGOLD_R10_V2_CONTROLLED_ENABLEMENT_MQH

//==================================================================
// R10 v2 — ETAPA 13.37 CONTROLLED ENABLEMENT
//
// Explicit execution-authorization boundary.
// No parameter optimization and no automatic enablement.
//
// Modes:
//   OFF    = feature cannot execute.
//   SHADOW = decision/projection only.
//   CONTROLLED = execution may proceed only through the existing
//                PreExecution + PreLive + executionEligible chain.
//
// This module does not bypass any existing safety authority.
//==================================================================

enum EAGOLD_R10V2EnableMode
{
   EAGOLD_R10V2_ENABLE_OFF=0,
   EAGOLD_R10V2_ENABLE_SHADOW=1,
   EAGOLD_R10V2_ENABLE_CONTROLLED=2
};

string EAGOLD_R10V2EnableModeName(EAGOLD_R10V2EnableMode mode)
{
   if(mode==EAGOLD_R10V2_ENABLE_OFF) return("OFF");
   if(mode==EAGOLD_R10V2_ENABLE_SHADOW) return("SHADOW");
   if(mode==EAGOLD_R10V2_ENABLE_CONTROLLED) return("CONTROLLED");
   return("UNKNOWN");
}

// Explicit master mode. Kept OFF by default.
// Controlled mode does not itself authorize a broker mutation.
EAGOLD_R10V2EnableMode EAGOLD_R10V2ControlledEnableMode()
{
   return(EAGOLD_R10V2_ENABLE_OFF);
}

bool EAGOLD_R10V2ControlledExecutionAllowed(
   EAGOLD_R10V2EnableMode mode,
   bool preExecutionOk,
   bool preLiveOk,
   bool executionEligible,
   bool economicExecutionAllowed)
{
   if(mode!=EAGOLD_R10V2_ENABLE_CONTROLLED)
      return(false);

   if(!preExecutionOk ||
      !preLiveOk ||
      !executionEligible ||
      !economicExecutionAllowed)
      return(false);

   return(true);
}

bool EAGOLD_R10V2ControlledModeSafe(
   EAGOLD_R10V2EnableMode mode,
   bool preExecutionOk,
   bool preLiveOk,
   bool executionEligible,
   bool economicExecutionAllowed)
{
   if(mode==EAGOLD_R10V2_ENABLE_OFF)
      return(true);

   if(mode==EAGOLD_R10V2_ENABLE_SHADOW)
      return(!economicExecutionAllowed);

   return(EAGOLD_R10V2ControlledExecutionAllowed(
      mode,
      preExecutionOk,
      preLiveOk,
      executionEligible,
      economicExecutionAllowed));
}

#endif
