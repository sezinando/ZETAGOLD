#ifndef EAGOLD_PERSISTENCE_MQH
#define EAGOLD_PERSISTENCE_MQH

// Persistence policy aligned with EAGOLD v0.116 Golden Reference.
// Only non-reconstructible operational state and historical extrema are persisted.
// Strategy Tester never uses terminal Global Variables, preventing cross-test contamination.

bool EAGOLD_PersistenceEnabled(){return(!IsTesting());}
string StateKey(string metric){return(STATE_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}
double PersistMonotonicMin(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue<stored?currentValue:stored);}
double PersistMonotonicMax(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue>stored?currentValue:stored);}

void PersistPanelExtrema(double currentProfit,double currentLots,double currentMaxProfit)
{
   if(!EAGOLD_PersistenceEnabled())return;
   string minKey=StateKey("PANEL_MIN_PROFIT");
   string maxProfitKey=StateKey("PANEL_MAX_PROFIT");
   string maxLotsKey=StateKey("MAX_ACCUM_LOTS");
   double persistedMin=PersistMonotonicMin(minKey,currentProfit);
   double persistedMaxProfit=PersistMonotonicMax(maxProfitKey,currentMaxProfit);
   double persistedMaxLots=PersistMonotonicMax(maxLotsKey,currentLots);
   if(!GlobalVariableCheck(minKey)||MathAbs(GlobalVariableGet(minKey)-persistedMin)>0.0000001)GlobalVariableSet(minKey,persistedMin);
   if(!GlobalVariableCheck(maxProfitKey)||MathAbs(GlobalVariableGet(maxProfitKey)-persistedMaxProfit)>0.0000001)GlobalVariableSet(maxProfitKey,persistedMaxProfit);
   if(!GlobalVariableCheck(maxLotsKey)||MathAbs(GlobalVariableGet(maxLotsKey)-persistedMaxLots)>0.0000001)GlobalVariableSet(maxLotsKey,persistedMaxLots);
}

void LoadPersistedStrategicState()
{
   if(!EAGOLD_PersistenceEnabled())return;
   if(GlobalVariableCheck(StateKey("g_r9HedgeActive")))
      g_r9HedgeActive=(GlobalVariableGet(StateKey("g_r9HedgeActive"))>0.5);
   if(GlobalVariableCheck(StateKey("PANEL_MIN_PROFIT")))
      g_panelMinProfit=GlobalVariableGet(StateKey("PANEL_MIN_PROFIT"));
   if(GlobalVariableCheck(StateKey("PANEL_MAX_PROFIT")))
      g_panelMaxProfit=GlobalVariableGet(StateKey("PANEL_MAX_PROFIT"));
   if(GlobalVariableCheck(StateKey("MAX_ACCUM_LOTS")))
      g_panelMaxLots=GlobalVariableGet(StateKey("MAX_ACCUM_LOTS"));
}

void PersistStrategicState(bool force=false)
{
   if(!EAGOLD_PersistenceEnabled())return;
   static bool initialized=false;
   static double lastHedge=0.0;
   double hedge=g_r9HedgeActive?1.0:0.0;
   bool hedgeChanged=MathAbs(lastHedge-hedge)>0.0000001;
   bool changed=force||!initialized||hedgeChanged;
   if(!changed)return;
   GlobalVariableSet(StateKey("g_r9HedgeActive"),hedge);
   initialized=true;
   lastHedge=hedge;
   if(force)GlobalVariablesFlush();
}

void PersistAllState(bool force=false){PersistStrategicState(force);}

#endif
