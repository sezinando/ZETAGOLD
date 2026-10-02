#ifndef EAGOLD_PERSISTENCE_MQH
#define EAGOLD_PERSISTENCE_MQH

// Persistence policy aligned with EAGOLD v0.116 Golden Reference.
// Inputs remain configuration; only non-reconstructible operational state and
// historical extrema are persisted. Strategy Tester never uses terminal
// Global Variables, preventing cross-test contamination.

bool EAGOLD_PersistenceEnabled(){return(!IsTesting());}
string StateKey(string metric){return(STATE_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}
double PersistMonotonicMin(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue<stored?currentValue:stored);}
double PersistMonotonicMax(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue>stored?currentValue:stored);}

void PersistAllState(bool force=false){PersistStrategicState(force);}

#endif
