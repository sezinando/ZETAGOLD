#ifndef EAGOLD_R10_V2_ENABLEMENT_TEST_MATRIX_MQH
#define EAGOLD_R10_V2_ENABLEMENT_TEST_MATRIX_MQH

//==================================================================
// R10 v2 — ETAPA 13.38 ENABLEMENT TEST MATRIX
//
// Pure in-memory gate validation. No broker calls.
// Verifies that OFF/SHADOW/CONTROLLED cannot bypass the
// authorization chain.
//==================================================================

struct EAGOLD_R10V2EnablementTestResult
{
   string name;
   bool passed;
};

bool EAGOLD_R10V2EnablementExpect(
   string name,
   bool actual,
   bool expected,
   EAGOLD_R10V2EnablementTestResult &result)
{
   result.name=name;
   result.passed=(actual==expected);
   if(!result.passed)
      Print("R10 v2 ENABLEMENT TEST FAIL: ",name,
            " actual=",actual," expected=",expected);
   return(result.passed);
}

bool EAGOLD_R10V2RunEnablementTestMatrix()
{
   EAGOLD_R10V2EnablementTestResult r;
   int total=0;
   int passed=0;

   // OFF must always fail closed.
   total++; if(EAGOLD_R10V2EnablementExpect("OFF_ALL_OK",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_OFF,true,true,true,true),
      false,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("OFF_ALL_BLOCKED",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_OFF,false,false,false,false),
      false,r)) passed++;

   // SHADOW must never authorize execution.
   total++; if(EAGOLD_R10V2EnablementExpect("SHADOW_ALL_OK",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_SHADOW,true,true,true,true),
      false,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("SHADOW_ECONOMIC_BLOCKED",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_SHADOW,true,true,true,false),
      false,r)) passed++;

   // CONTROLLED: every gate is mandatory.
   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_ALL_OK",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,true,true,true),
      true,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_PREEXEC_FAIL",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,false,true,true,true),
      false,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_PRELIVE_FAIL",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,false,true,true),
      false,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_EXECUTION_ELIGIBLE_FAIL",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,true,false,true),
      false,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_ECONOMIC_EXECUTION_FAIL",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,true,true,false),
      false,r)) passed++;

   // Any single failed gate must block.
   total++; if(EAGOLD_R10V2EnablementExpect("CONTROLLED_TWO_GATES_FAIL",
      EAGOLD_R10V2ControlledExecutionAllowed(
         EAGOLD_R10V2_ENABLE_CONTROLLED,false,false,true,true),
      false,r)) passed++;

   // Invariant helper: OFF/SHADOW are safe because they cannot execute.
   total++; if(EAGOLD_R10V2EnablementExpect("INVARIANT_OFF",
      EAGOLD_R10V2ControlledModeSafe(
         EAGOLD_R10V2_ENABLE_OFF,true,true,true,true),
      true,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("INVARIANT_SHADOW",
      EAGOLD_R10V2ControlledModeSafe(
         EAGOLD_R10V2_ENABLE_SHADOW,true,true,true,true),
      true,r)) passed++;

   // Controlled safe only when its full chain is valid.
   total++; if(EAGOLD_R10V2EnablementExpect("INVARIANT_CONTROLLED_OK",
      EAGOLD_R10V2ControlledModeSafe(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,true,true,true),
      true,r)) passed++;

   total++; if(EAGOLD_R10V2EnablementExpect("INVARIANT_CONTROLLED_BLOCK",
      EAGOLD_R10V2ControlledModeSafe(
         EAGOLD_R10V2_ENABLE_CONTROLLED,true,false,true,true),
      false,r)) passed++;

   Print("R10 v2 ENABLEMENT TEST MATRIX: ",
         passed,"/",total," PASS");
   return(passed==total);
}

#endif
