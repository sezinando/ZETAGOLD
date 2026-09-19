#ifndef EAGOLD_DUAL_CYCLE_MANAGER_MQH
#define EAGOLD_DUAL_CYCLE_MANAGER_MQH

// ENGINE — DUAL CYCLE MANAGER v1
//
// Purpose:
//   Allow a controlled second directional cycle when Intelligence flips against
//   an already-active cycle. The original cycle remains untouched.
//
// V1 scope:
//   - one secondary cycle per Intelligence regime flip;
//   - opposite direction only;
//   - no action when both directions are already active;
//   - gross exposure ceiling is enforced;
//   - R9 hedge-lock blocks a new secondary cycle;
//   - shadow mode can measure candidates without sending orders.
//
// Important:
//   This module does not replace R1, R9, R10 or R11. It is an additional
//   admission layer for a SECOND seed while an existing directional cycle
//   remains active.

int g_eagoldDualCycleLatchedDirection=ZG_DIR_WAIT;

void EAGOLD_DualCycleReset()
{
   g_eagoldDualCycleLatchedDirection=ZG_DIR_WAIT;
}

string EAGOLD_DualCycleDirectionName(int direction)
{
   if(direction==ZG_DIR_BUY) return("BUY");
   if(direction==ZG_DIR_SELL) return("SELL");
   return("WAIT");
}

bool EAGOLD_DualCycleOpposite(int intelligenceDirection,int activeDirection)
{
   return((activeDirection==OP_BUY && intelligenceDirection==ZG_DIR_SELL) ||
          (activeDirection==OP_SELL && intelligenceDirection==ZG_DIR_BUY));
}

bool EAGOLD_DualCycleCanConsider(int &selectedDirection,string &reason)
{
   selectedDirection=-1;
   reason="BLOCKED";

   if(!P11_01_EnableDualCycle)
   {
      reason="FEATURE_OFF";
      return(false);
   }

   if(!ZG_DirectionFilterEnabled())
   {
      reason="DIRECTION_FILTER_OFF";
      return(false);
   }

   int intelligenceDirection=g_zgIntelligenceDecision.Direction;
   if(intelligenceDirection!=ZG_DIR_BUY && intelligenceDirection!=ZG_DIR_SELL)
   {
      reason="INTELLIGENCE_WAIT";
      return(false);
   }

   int buyPositions=CountDirectionPositions(OP_BUY);
   int sellPositions=CountDirectionPositions(OP_SELL);

   // The module only creates a SECOND cycle. It never creates the first
   // cycle and never intervenes when both directions are already active.
   if(buyPositions<=0 && sellPositions<=0)
   {
      g_eagoldDualCycleLatchedDirection=ZG_DIR_WAIT;
      reason="NO_ACTIVE_CYCLE";
      return(false);
   }

   if(buyPositions>0 && sellPositions>0)
   {
      reason="BOTH_DIRECTIONS_ACTIVE";
      return(false);
   }

   int activeDirection=(buyPositions>0?OP_BUY:OP_SELL);

   if(!EAGOLD_DualCycleOpposite(intelligenceDirection,activeDirection))
   {
      reason="NOT_OPPOSITE_REGIME";
      return(false);
   }

   // One secondary cycle per regime flip. The latch resets only when the
   // Intelligence regime changes or the complete broker basket becomes flat.
   if(g_eagoldDualCycleLatchedDirection==intelligenceDirection)
   {
      reason="REGIME_ALREADY_LATCHED";
      return(false);
   }

   if(g_r9HedgeActive)
   {
      reason="R9_HEDGE_LOCK";
      return(false);
   }

   double grossBefore=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   if(P11_04_DualCycleMaxGrossExposureLots>0.0 &&
      grossBefore+Lot>P11_04_DualCycleMaxGrossExposureLots+0.0000001)
   {
      reason="DUAL_GROSS_LIMIT";
      return(false);
   }

   if(CountDirectionPending(intelligenceDirection==ZG_DIR_BUY?OP_BUY:OP_SELL)>0)
   {
      reason="OPPOSITE_PENDING_EXISTS";
      return(false);
   }

   if(!EAGOLD_NewOrderAdmissionAllowed())
   {
      reason="ENTRY_GUARD";
      return(false);
   }

   selectedDirection=(intelligenceDirection==ZG_DIR_BUY?OP_BUY:OP_SELL);
   reason="CANDIDATE";
   return(true);
}

void EAGOLD_DualCycleObserve()
{
   if(!P11_01_EnableDualCycle)
      return;

   int selectedDirection=-1;
   string reason="";

   bool candidate=EAGOLD_DualCycleCanConsider(selectedDirection,reason);

   if(!candidate)
   {
      // Regime changes invalidate the previous secondary-cycle latch.
      if(g_zgIntelligenceDecision.Direction!=ZG_DIR_WAIT &&
         g_zgIntelligenceDecision.Direction!=g_eagoldDualCycleLatchedDirection)
      {
         if(g_eagoldDualCycleLatchedDirection!=ZG_DIR_WAIT)
         {
            Print(EA_NAME,
                  " DUAL CYCLE: regime changed from ",
                  EAGOLD_DualCycleDirectionName(g_eagoldDualCycleLatchedDirection),
                  " to ",
                  EAGOLD_DualCycleDirectionName(g_zgIntelligenceDecision.Direction),
                  ". Secondary-cycle latch released.");
         }
         g_eagoldDualCycleLatchedDirection=ZG_DIR_WAIT;
      }

      if(P11_02_DualCycleShadowMode && reason!="FEATURE_OFF")
      {
         Print(EA_NAME,
               " DUAL CYCLE SHADOW: candidate=NO reason=",reason,
               " intelligence=",EAGOLD_DualCycleDirectionName(g_zgIntelligenceDecision.Direction),
               " buyLots=",DoubleToString(DirectionLots(OP_BUY),DigitsLots),
               " sellLots=",DoubleToString(DirectionLots(OP_SELL),DigitsLots),
               " gross=",DoubleToString(DirectionLots(OP_BUY)+DirectionLots(OP_SELL),DigitsLots));
      }
      return;
   }

   double grossBefore=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   double netBefore=DirectionLots(OP_BUY)-DirectionLots(OP_SELL);

   RefreshRates();
   bool isBuy=(selectedDirection==OP_BUY);
   double price=NormalizePrice(isBuy?
      Ask+PointsToPrice(FirstStep):
      Bid-PointsToPrice(FirstStep));

   double grossAfter=grossBefore+Lot;
   double netAfter=netBefore+(isBuy?Lot:-Lot);

   Print(EA_NAME,
         " DUAL CYCLE CANDIDATE: direction=",EAGOLD_DualCycleDirectionName(g_zgIntelligenceDecision.Direction),
         " edge=",DoubleToString(g_zgIntelligenceDecision.Edge,2),
         " confidence=",DoubleToString(g_zgIntelligenceDecision.Confidence,2),
         " price=",DoubleToString(price,Digits),
         " lot=",DoubleToString(Lot,DigitsLots),
         " grossBefore=",DoubleToString(grossBefore,DigitsLots),
         " grossAfter=",DoubleToString(grossAfter,DigitsLots),
         " netBefore=",DoubleToString(netBefore,DigitsLots),
         " netAfter=",DoubleToString(netAfter,DigitsLots),
         " mode=",(P11_02_DualCycleShadowMode?"SHADOW":"EXECUTION"));

   if(P11_02_DualCycleShadowMode)
      return;

   if(!EAGOLD_EconomicExecutionAllowed())
      return;

   string admissionReason="PASS";
   if(P11_03_DualCycleUseR1AdmissionGates &&
      !R1AdmissionAllowed(selectedDirection,Lot,price,admissionReason))
   {
      Print(EA_NAME,
            " DUAL CYCLE BLOCKED: R1 gate reason=",admissionReason);
      return;
   }

   int ticket=SendPending(
      isBuy?OP_BUYSTOP:OP_SELLSTOP,
      price,
      Lot,
      isBuy?"EAGOLD DUAL BUY":"EAGOLD DUAL SELL");

   if(ticket<=0)
   {
      Print(EA_NAME,
            " DUAL CYCLE FAILED: direction=",EAGOLD_DualCycleDirectionName(g_zgIntelligenceDecision.Direction),
            " error=",GetLastError());
      EAGOLD_R10RequestReconciliation();
      return;
   }

   g_eagoldDualCycleLatchedDirection=g_zgIntelligenceDecision.Direction;

   Print(EA_NAME,
         " DUAL CYCLE CREATED: direction=",EAGOLD_DualCycleDirectionName(g_zgIntelligenceDecision.Direction),
         " ticket=",ticket,
         " edge=",DoubleToString(g_zgIntelligenceDecision.Edge,2),
         " confidence=",DoubleToString(g_zgIntelligenceDecision.Confidence,2),
         " grossAfter=",DoubleToString(grossAfter,DigitsLots));

   CreateEngineActionMarker("DUAL","SEED",selectedDirection,Lot);
}

#endif
