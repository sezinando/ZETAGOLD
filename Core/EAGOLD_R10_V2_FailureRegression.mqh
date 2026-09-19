#ifndef EAGOLD_R10_V2_FAILURE_REGRESSION_MQH
#define EAGOLD_R10_V2_FAILURE_REGRESSION_MQH

// ETAPA 13.42 — failure semantics regression.
// Simulates only Action Contract outcomes in memory.

bool EAGOLD_R10V2RunFailureRegression()
{
   int total=0,passed=0;

   total++; if(EAGOLD_R10V2TestResultSafe(
      EAGOLD_R10V2_TEST_PARTIAL,EAGOLD_ACTION_PARTIAL,
      EAGOLD_TICK_HALT_FOR_RECONCILIATION,true)) passed++;

   total++; if(EAGOLD_R10V2TestResultSafe(
      EAGOLD_R10V2_TEST_SELL_FAILURE,EAGOLD_ACTION_PARTIAL,
      EAGOLD_TICK_HALT_FOR_RECONCILIATION,true)) passed++;

   total++; if(EAGOLD_R10V2TestResultSafe(
      EAGOLD_R10V2_TEST_BUY_FAILURE,EAGOLD_ACTION_FAILED,
      EAGOLD_TICK_CONTINUE,false)) passed++;

   total++; if(EAGOLD_R10V2TestResultSafe(
      EAGOLD_R10V2_TEST_DUPLICATE,EAGOLD_ACTION_BLOCKED,
      EAGOLD_TICK_CONTINUE,false)) passed++;

   total++; if(EAGOLD_R10V2TestResultSafe(
      EAGOLD_R10V2_TEST_RECONCILIATION,EAGOLD_ACTION_BLOCKED,
      EAGOLD_TICK_HALT_FOR_RECONCILIATION,true)) passed++;

   Print(EA_NAME," R10 V2 FAILURE REGRESSION: ",
         passed,"/",total," PASS");
   return(passed==total);
}

#endif
