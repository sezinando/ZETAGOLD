#ifndef EAGOLD_R10_V2_REGRESSION_SUITE_MQH
#define EAGOLD_R10_V2_REGRESSION_SUITE_MQH

// ETAPA 13.41 — deterministic regression suite.
// Delegates to existing arithmetic scenario/invariant laboratories.

void EAGOLD_R10V2RegressionSuiteRun()
{
   Print(EA_NAME," R10 v2 REGRESSION SUITE BEGIN");
   EAGOLD_R10V2ScenarioHarnessRun();
   EAGOLD_R10V2ScenarioInvariantTests();
   EAGOLD_R10V2TrajectoryHarnessRun();
   EAGOLD_R10V2CalibrationRun();
   Print(EA_NAME," R10 v2 REGRESSION SUITE END");
}

#endif
