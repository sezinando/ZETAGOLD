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

int R13PersistenceCommittedSlot(){string key=StateKey("R13_CAP_COMMIT_SLOT");if(!GlobalVariableCheck(key))return(-1);double stored=GlobalVariableGet(key);if(stored<0.0||stored>1.0)return(-1);return((int)MathRound(stored));}
void LoadPersistedR13State(){if(!EAGOLD_PersistenceEnabled())return;int slot=R13PersistenceCommittedSlot();if(slot<0)return;string suffix=IntegerToString(slot);string versionKey=StateKey("R13_CAP_VERSION_"+suffix);string availableKey=StateKey("R13_CAP_AVAILABLE_"+suffix);string usedKey=StateKey("R13_CAP_USED_"+suffix);string entryKey=StateKey("R13_LAST_ENTRY_"+suffix);if(!GlobalVariableCheck(versionKey)||MathAbs(GlobalVariableGet(versionKey)-1.0)>0.0000001)return;if(!GlobalVariableCheck(availableKey)||!GlobalVariableCheck(usedKey)||!GlobalVariableCheck(entryKey))return;double available=GlobalVariableGet(availableKey),used=GlobalVariableGet(usedKey);datetime lastEntry=(datetime)GlobalVariableGet(entryKey);if(available<0.0||used<0.0)return;g_r13RecoveryCapitalAvailable=available;g_r13RecoveryCapitalUsed=used;g_r13LastEntry=lastEntry;}
void PersistR13State(bool force=false){if(!EAGOLD_PersistenceEnabled())return;static bool initialized=false;static double lastAvailable=-1.0,lastUsed=-1.0,lastEntry=0.0;if(!force&&initialized&&MathAbs(lastAvailable-g_r13RecoveryCapitalAvailable)<0.0000001&&MathAbs(lastUsed-g_r13RecoveryCapitalUsed)<0.0000001&&lastEntry==(double)g_r13LastEntry)return;int committed=R13PersistenceCommittedSlot();int target=(committed==0?1:0);string suffix=IntegerToString(target);GlobalVariableSet(StateKey("R13_CAP_VERSION_"+suffix),1.0);GlobalVariableSet(StateKey("R13_CAP_AVAILABLE_"+suffix),MathMax(0.0,g_r13RecoveryCapitalAvailable));GlobalVariableSet(StateKey("R13_CAP_USED_"+suffix),MathMax(0.0,g_r13RecoveryCapitalUsed));GlobalVariableSet(StateKey("R13_LAST_ENTRY_"+suffix),(double)g_r13LastEntry);GlobalVariableSet(StateKey("R13_CAP_COMMIT_SLOT"),(double)target);initialized=true;lastAvailable=g_r13RecoveryCapitalAvailable;lastUsed=g_r13RecoveryCapitalUsed;lastEntry=(double)g_r13LastEntry;if(force)GlobalVariablesFlush();}
void PersistPanelExtrema(double currentProfit,double currentLots,double currentMaxProfit){if(!EAGOLD_PersistenceEnabled())return;string minKey=StateKey("PANEL_MIN_PROFIT"),maxProfitKey=StateKey("PANEL_MAX_PROFIT"),maxLotsKey=StateKey("MAX_ACCUM_LOTS");double persistedMin=PersistMonotonicMin(minKey,currentProfit),persistedMaxProfit=PersistMonotonicMax(maxProfitKey,currentMaxProfit),persistedMaxLots=PersistMonotonicMax(maxLotsKey,currentLots);if(!GlobalVariableCheck(minKey)||MathAbs(GlobalVariableGet(minKey)-persistedMin)>0.0000001)GlobalVariableSet(minKey,persistedMin);if(!GlobalVariableCheck(maxProfitKey)||MathAbs(GlobalVariableGet(maxProfitKey)-persistedMaxProfit)>0.0000001)GlobalVariableSet(maxProfitKey,persistedMaxProfit);if(!GlobalVariableCheck(maxLotsKey)||MathAbs(GlobalVariableGet(maxLotsKey)-persistedMaxLots)>0.0000001)GlobalVariableSet(maxLotsKey,persistedMaxLots);}
void LoadPersistedStrategicState(){if(!EAGOLD_PersistenceEnabled())return;if(GlobalVariableCheck(StateKey("g_r9HedgeActive")))g_r9HedgeActive=(GlobalVariableGet(StateKey("g_r9HedgeActive"))>0.5);if(GlobalVariableCheck(StateKey("PANEL_MIN_PROFIT")))g_panelMinProfit=GlobalVariableGet(StateKey("PANEL_MIN_PROFIT"));if(GlobalVariableCheck(StateKey("PANEL_MAX_PROFIT")))g_panelMaxProfit=GlobalVariableGet(StateKey("PANEL_MAX_PROFIT"));if(GlobalVariableCheck(StateKey("MAX_ACCUM_LOTS")))g_panelMaxLots=GlobalVariableGet(StateKey("MAX_ACCUM_LOTS"));LoadPersistedR13State();}
void PersistStrategicState(bool force=false)
{
   if(!EAGOLD_PersistenceEnabled())return;
   static bool initialized=false;
   static double lastHedge=0.0;
   double hedge=g_r9HedgeActive?1.0:0.0;
   bool hedgeChanged=MathAbs(lastHedge-hedge)>0.0000001;
   bool r13Changed=force||!initialized;
   bool changed=force||!initialized||hedgeChanged||r13Changed;
   if(!changed)return;
   GlobalVariableSet(StateKey("g_r9HedgeActive"),hedge);
   PersistR13State(force);
   GlobalVariableSet(StateKey("R13_LAST_AVAILABLE_CACHE"),g_r13RecoveryCapitalAvailable);
   GlobalVariableSet(StateKey("R13_LAST_USED_CACHE"),g_r13RecoveryCapitalUsed);
   GlobalVariableSet(StateKey("R13_LAST_ENTRY_CACHE"),(double)g_r13LastEntry);
   initialized=true;
   lastHedge=hedge;
   if(force)GlobalVariablesFlush();
}
void PersistAllState(bool force=false){PersistStrategicState(force);}

#endif
