#ifndef EAGOLD_R10_V2_TEST_MATRIX_MQH
#define EAGOLD_R10_V2_TEST_MATRIX_MQH

//==================================================================
// R10 v2 — TEST MATRIX / FAILURE INJECTION
// ETAPA 13.30
//
// Journal-only validation inventory. This module does not execute
// broker mutations and does not alter live decision authority.
//==================================================================

enum EAGOLD_R10V2TestCase
{
   EAGOLD_R10V2_TEST_NO_OPPORTUNITY=0,
   EAGOLD_R10V2_TEST_BLOCKED,
   EAGOLD_R10V2_TEST_AUTHORIZED,
   EAGOLD_R10V2_TEST_CAPITAL_INSUFFICIENT,
   EAGOLD_R10V2_TEST_R11_BLOCK,
   EAGOLD_R10V2_TEST_BROKER_CAPACITY,
   EAGOLD_R10V2_TEST_TARGET_INVALID,
   EAGOLD_R10V2_TEST_PREFLIGHT_FAILURE,
   EAGOLD_R10V2_TEST_BUY_FAILURE,
   EAGOLD_R10V2_TEST_SELL_FAILURE,
   EAGOLD_R10V2_TEST_PARTIAL,
   EAGOLD_R10V2_TEST_DUPLICATE,
   EAGOLD_R10V2_TEST_RECONCILIATION
};

string EAGOLD_R10V2TestCaseName(EAGOLD_R10V2TestCase tc)
{
   if(tc==EAGOLD_R10V2_TEST_BLOCKED)return("BLOCKED");
   if(tc==EAGOLD_R10V2_TEST_AUTHORIZED)return("AUTHORIZED");
   if(tc==EAGOLD_R10V2_TEST_CAPITAL_INSUFFICIENT)return("CAPITAL_INSUFFICIENT");
   if(tc==EAGOLD_R10V2_TEST_R11_BLOCK)return("R11_BLOCK");
   if(tc==EAGOLD_R10V2_TEST_BROKER_CAPACITY)return("BROKER_CAPACITY");
   if(tc==EAGOLD_R10V2_TEST_TARGET_INVALID)return("TARGET_INVALID");
   if(tc==EAGOLD_R10V2_TEST_PREFLIGHT_FAILURE)return("PREFLIGHT_FAILURE");
   if(tc==EAGOLD_R10V2_TEST_BUY_FAILURE)return("BUY_FAILURE");
   if(tc==EAGOLD_R10V2_TEST_SELL_FAILURE)return("SELL_FAILURE");
   if(tc==EAGOLD_R10V2_TEST_PARTIAL)return("PARTIAL");
   if(tc==EAGOLD_R10V2_TEST_DUPLICATE)return("DUPLICATE");
   if(tc==EAGOLD_R10V2_TEST_RECONCILIATION)return("RECONCILIATION_REQUIRED");
   return("NO_OPPORTUNITY");
}

struct EAGOLD_R10V2TestExpectation
{
   EAGOLD_R10V2TestCase testCase;
   EAGOLD_TickPolicy expectedTickPolicy;
   bool expectedBrokerMutation;
   bool expectedReconciliation;
   bool expectedCapitalMutation;
};

void EAGOLD_R10V2TestExpectationBuild(
   EAGOLD_R10V2TestCase testCase,
   EAGOLD_R10V2TestExpectation &e)
{
   e.testCase=testCase;
   e.expectedTickPolicy=EAGOLD_TICK_CONTINUE;
   e.expectedBrokerMutation=false;
   e.expectedReconciliation=false;
   e.expectedCapitalMutation=false;

   if(testCase==EAGOLD_R10V2_TEST_AUTHORIZED)
   {
      // Authorization alone is not execution.
      e.expectedTickPolicy=EAGOLD_TICK_CONTINUE;
      return;
   }

   if(testCase==EAGOLD_R10V2_TEST_PARTIAL ||
      testCase==EAGOLD_R10V2_TEST_SELL_FAILURE ||
      testCase==EAGOLD_R10V2_TEST_RECONCILIATION)
   {
      e.expectedTickPolicy=EAGOLD_TICK_HALT_FOR_RECONCILIATION;
      e.expectedReconciliation=true;
      return;
   }
}

// Validate the safety consequence of an observed Action Contract
// result against the expected failure semantics.
bool EAGOLD_R10V2TestResultSafe(
   EAGOLD_R10V2TestCase testCase,
   EAGOLD_ActionResult result,
   EAGOLD_TickPolicy observedPolicy,
   bool reconciliationRequired)
{
   if(testCase==EAGOLD_R10V2_TEST_PARTIAL ||
      testCase==EAGOLD_R10V2_TEST_SELL_FAILURE)
   {
      return(result==EAGOLD_ACTION_PARTIAL &&
             observedPolicy==EAGOLD_TICK_HALT_FOR_RECONCILIATION &&
             reconciliationRequired);
   }

   if(testCase==EAGOLD_R10V2_TEST_BUY_FAILURE)
      return(result==EAGOLD_ACTION_FAILED &&
             observedPolicy==EAGOLD_TICK_CONTINUE);

   if(testCase==EAGOLD_R10V2_TEST_DUPLICATE)
      return(result==EAGOLD_ACTION_BLOCKED &&
             observedPolicy==EAGOLD_TICK_CONTINUE);

   if(testCase==EAGOLD_R10V2_TEST_RECONCILIATION)
      return(observedPolicy==EAGOLD_TICK_HALT_FOR_RECONCILIATION &&
             reconciliationRequired);

   return(true);
}

#endif
