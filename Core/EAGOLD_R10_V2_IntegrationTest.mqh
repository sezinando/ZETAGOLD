#ifndef EAGOLD_R10_V2_INTEGRATION_TEST_MQH
#define EAGOLD_R10_V2_INTEGRATION_TEST_MQH

// ETAPA 13.40 — deterministic integration gate.
// Exercises the complete authorization boolean chain without broker I/O.

bool EAGOLD_R10V2IntegrationExpect(string name,bool actual,bool expected,int &passed,int &total)
{
   total++;
   if(actual==expected){passed++;return(true);}
   Print("R10 V2 INTEGRATION FAIL: ",name,
         " actual=",actual," expected=",expected);
   return(false);
}

bool EAGOLD_R10V2RunIntegrationTest()
{
   int passed=0,total=0;
   EAGOLD_R10V2EnableMode mode=EAGOLD_R10V2_ENABLE_CONTROLLED;

   EAGOLD_R10V2IntegrationExpect("FULL_CHAIN",
      EAGOLD_R10V2ControlledExecutionAllowed(mode,true,true,true,true),
      true,passed,total);

   EAGOLD_R10V2IntegrationExpect("PREEXEC_GATE",
      EAGOLD_R10V2ControlledExecutionAllowed(mode,false,true,true,true),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("PRELIVE_GATE",
      EAGOLD_R10V2ControlledExecutionAllowed(mode,true,false,true,true),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("ELIGIBILITY_GATE",
      EAGOLD_R10V2ControlledExecutionAllowed(mode,true,true,false,true),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("ECONOMIC_GATE",
      EAGOLD_R10V2ControlledExecutionAllowed(mode,true,true,true,false),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("OFF_FAIL_CLOSED",
      EAGOLD_R10V2ControlledExecutionAllowed(EAGOLD_R10V2_ENABLE_OFF,true,true,true,true),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("SHADOW_FAIL_CLOSED",
      EAGOLD_R10V2ControlledExecutionAllowed(EAGOLD_R10V2_ENABLE_SHADOW,true,true,true,true),
      false,passed,total);

   EAGOLD_R10V2IntegrationExpect("SAFE_OFF",
      EAGOLD_R10V2ControlledModeSafe(EAGOLD_R10V2_ENABLE_OFF,false,false,false,false),
      true,passed,total);

   EAGOLD_R10V2IntegrationExpect("SAFE_SHADOW",
      EAGOLD_R10V2ControlledModeSafe(EAGOLD_R10V2_ENABLE_SHADOW,true,true,true,false),
      true,passed,total);

   EAGOLD_R10V2IntegrationExpect("SAFE_CONTROLLED",
      EAGOLD_R10V2ControlledModeSafe(mode,true,true,true,true),
      true,passed,total);

   Print("R10 V2 INTEGRATION TEST: ",passed,"/",total," PASS");
   return(passed==total);
}

#endif
