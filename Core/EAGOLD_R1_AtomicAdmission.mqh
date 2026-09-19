#ifndef EAGOLD_R1_ATOMIC_ADMISSION_MQH
#define EAGOLD_R1_ATOMIC_ADMISSION_MQH

// R1 atomic first-seed transaction.
// A flat EAGOLD basket must end the admission attempt with either BOTH
// directional seed pendings present or NONE. A one-sided seed is never
// accepted as a successful first cycle.
//
// Cycle latch:
//   ARMED -> R1 EXECUTED -> BASKET ACTIVE -> BASKET FLAT -> ARMED
// A cycle becomes ACTIVE only after at least one master market position has
// actually been opened. Pending orders alone do not re-arm the cycle. This is
// critical when a spread/time guard removes pending entries before activation:
// the deleted pending must not cause R1 to immediately create a new cycle.
bool g_eagoldR1CycleArmed=true;
bool g_eagoldR1BasketWasActive=false;

void EAGOLD_R1ResetCycleLatch()
{
   g_eagoldR1CycleArmed=true;
   g_eagoldR1BasketWasActive=false;
   ZG_AdmissionDirectionReset();
}

bool EAGOLD_R1ReconcilePendingWithIntelligence()
{
   if(!ZG_DirectionFilterEnabled())
      return(true);

   if(CountDirectionPositions(OP_BUY)>0 || CountDirectionPositions(OP_SELL)>0)
      return(true);

   int intelligenceDirection=g_zgIntelligenceDecision.Direction;
   if(intelligenceDirection!=ZG_DIR_BUY && intelligenceDirection!=ZG_DIR_SELL)
      return(true);

   int latchedDirection=ZG_EconomicCreationDirection();
   if(latchedDirection!=ZG_DIR_BUY && latchedDirection!=ZG_DIR_SELL)
      return(true);

   if(latchedDirection==intelligenceDirection)
      return(true);

   int currentPendingDirection=-1;
   if(CountDirectionPending(OP_BUY)>0 && CountDirectionPending(OP_SELL)==0)
      currentPendingDirection=ZG_DIR_BUY;
   else if(CountDirectionPending(OP_SELL)>0 && CountDirectionPending(OP_BUY)==0)
      currentPendingDirection=ZG_DIR_SELL;
   else
      return(true);

   if(currentPendingDirection==intelligenceDirection)
      return(true);

   if(!IsTradeAllowed() || IsTradeContextBusy())
   {
      Print(EA_NAME," R1 REGIME FLIP: trade context unavailable. pending direction remains unchanged.");
      return(false);
   }

   Print(EA_NAME," R1 REGIME FLIP: pending direction invalidated. latched=",
         (latchedDirection==ZG_DIR_BUY?"BUY":"SELL"),
         " intelligence=",(intelligenceDirection==ZG_DIR_BUY?"BUY":"SELL"),
         " -> replacing unactivated pending.");

   bool deletedAll=true;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(!IsEAGOLDOrder())
         continue;
      int type=OrderType();
      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP)
         continue;

      int ticket=OrderTicket();
      ResetLastError();
      if(!OrderDelete(ticket,clrNONE))
      {
         int err=GetLastError();
         Print(EA_NAME," R1 REGIME FLIP: failed to delete pending ticket=",ticket,
               " err=",err);
         deletedAll=false;
      }
      else
         Print(EA_NAME," R1 REGIME FLIP: deleted obsolete pending ticket=",ticket);
   }

   if(!deletedAll)
   {
      EAGOLD_R10RequestReconciliation();
      return(false);
   }

   RefreshRates();
   bool intelligenceBuy=(intelligenceDirection==ZG_DIR_BUY);
   double price=NormalizePrice(intelligenceBuy?
      Ask+PointsToPrice(FirstStep):
      Bid-PointsToPrice(FirstStep));

   int ticket=SendPending(
      intelligenceBuy?OP_BUYSTOP:OP_SELLSTOP,
      price,
      Lot,
      intelligenceBuy?"EAGOLD ZG FIRST BUY":"EAGOLD ZG FIRST SELL");

   if(ticket<=0)
   {
      Print(EA_NAME," R1 REGIME FLIP: replacement seed failed. direction=",
            (intelligenceBuy?"BUY":"SELL"),
            " lastError=",GetLastError());
      g_eagoldR1CycleArmed=true;
      ZG_AdmissionDirectionReset();
      return(false);
   }

   ZG_AdmissionDirectionLatch(intelligenceDirection);
   g_eagoldR1CycleArmed=false;

   Print(EA_NAME," R1 REGIME FLIP: replacement seed created direction=",
         (intelligenceBuy?"BUY":"SELL"),
         " ticket=",ticket,
         " edge=",DoubleToString(g_zgIntelligenceDecision.Edge,2),
         " confidence=",DoubleToString(g_zgIntelligenceDecision.Confidence,2));
   CreateEngineActionMarker("R1","REGIME_FLIP",intelligenceBuy?OP_BUY:OP_SELL,Lot);
   return(true);
}

bool EAGOLD_R1RepairFlatPendingAnomaly(const EAGOLD_BrokerIntegrity &c)
{
   if(!c.valid || c.positions>0)
      return(true);

   int expectedPending=2;
   int expectedDirection=ZG_DirectionFilterEnabled()?ZG_EconomicCreationDirection():ZG_DIR_WAIT;
   if(ZG_DirectionFilterEnabled())
      expectedPending=(expectedDirection==ZG_DIR_BUY || expectedDirection==ZG_DIR_SELL)?1:0;

   int actualPending=c.buyPending+c.sellPending;
   bool shapeOk=(actualPending==expectedPending);

   if(shapeOk && ZG_DirectionFilterEnabled())
   {
      if(expectedDirection==ZG_DIR_BUY && c.sellPending>0)
         shapeOk=false;
      if(expectedDirection==ZG_DIR_SELL && c.buyPending>0)
         shapeOk=false;
      if(expectedDirection==ZG_DIR_WAIT && actualPending>0)
         shapeOk=false;
   }

   if(shapeOk)
      return(true);

   if(actualPending<=0)
      return(true);

   if(!IsTradeAllowed() || IsTradeContextBusy())
   {
      Print(EA_NAME," RULE 1 DOUBLE CHECK: pending anomaly detected but trade context is not available.");
      return(false);
   }

   Print(EA_NAME," RULE 1 DOUBLE CHECK: FLAT/PENDING ANOMALY. expected=",expectedPending,
         " actual=",actualPending," buyPending=",c.buyPending," sellPending=",c.sellPending,
         " -> deleting orphan pending orders before re-admission.");

   bool allDeleted=true;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(!IsEAGOLDOrder())
         continue;
      int type=OrderType();
      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP)
         continue;

      int ticket=OrderTicket();
      ResetLastError();
      if(!OrderDelete(ticket,clrNONE))
      {
         int err=GetLastError();
         Print(EA_NAME," RULE 1 DOUBLE CHECK: failed to delete orphan pending ticket=",ticket," err=",err);
         allDeleted=false;
      }
      else
         Print(EA_NAME," RULE 1 DOUBLE CHECK: orphan pending deleted ticket=",ticket);
   }

   if(!allDeleted)
   {
      EAGOLD_R10RequestReconciliation();
      return(false);
   }

   EAGOLD_R1RearmFromBrokerFlat();
   return(true);
}

void EAGOLD_R1RearmFromBrokerFlat()
{
   // Broker census is authoritative: if no EAGOLD order exists, a stale
   // in-memory cycle latch must never prevent a fresh admission.
   if(CountEAGOLDOrders()!=0)
      return;

   if(!g_eagoldR1CycleArmed || g_eagoldR1BasketWasActive)
      Print(EA_NAME," RULE 1 CYCLE: BROKER_FLAT -> R1_REARM (double check).");

   g_eagoldR1CycleArmed=true;
   g_eagoldR1BasketWasActive=false;
   ZG_AdmissionDirectionReset();
}

void EAGOLD_R1ObserveCycle()
{
   int livePositions=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);

   // Only a real market position activates the current basket cycle. Pending
   // seeds are deliberately excluded so guard-driven pending suspension does
   // not manufacture a false BASKET_ACTIVE state.
   if(livePositions>0)
   {
      g_eagoldR1BasketWasActive=true;
      return;
   }

   // A previously active basket has now become flat. This is the only event
   // that legitimately re-arms R1 for a new basket cycle.
   if(g_eagoldR1BasketWasActive)
   {
      if(!g_eagoldR1CycleArmed)
      {
         g_eagoldR1CycleArmed=true;
         Print(EA_NAME," RULE 1 CYCLE: BASKET_FLAT -> R1_REARM.");
      }
      g_eagoldR1BasketWasActive=false;
   }
}

EAGOLD_ActionResult EAGOLD_CreateFirstOrdersAtomic()
{
   EAGOLD_R1ObserveCycle();

   if(EAGOLD_EntrySuspendedThisTick())
      return(EAGOLD_ACTION_BLOCKED);

   if(!g_eagoldR1CycleArmed)
      return(EAGOLD_ACTION_BLOCKED);

   if(CountEAGOLDOrders()>0)
      return(EAGOLD_ACTION_BLOCKED);

   RefreshRates();

   // Intelligence-controlled admission: when the Direction Filter is enabled,
   // R1 becomes one-sided. The selected side is chosen from the last closed
   // H1 intelligence state; WAIT leaves the cycle flat.
   if(ZG_DirectionFilterEnabled())
   {
      int selectedDirection=g_zgIntelligenceDecision.Direction;
      if(selectedDirection!=ZG_DIR_BUY&&selectedDirection!=ZG_DIR_SELL)
      {
         R1Decision("BLOCK","INTELLIGENCE_WAIT");
         Print(EA_NAME," RULE 1: intelligence filter WAIT. No new cycle admitted.");
         return(EAGOLD_ACTION_BLOCKED);
      }

      // Intelligence direction uses ZG_DIR_* values:
      // BUY=+1 / SELL=-1. MT4 OP_BUY/OP_SELL use different values
      // (0/1), so never compare the Intelligence enum directly with OP_*.
      bool intelligenceBuy=(selectedDirection==ZG_DIR_BUY);
      double selectedPrice=(intelligenceBuy?
         NormalizePrice(Ask+PointsToPrice(FirstStep)):
         NormalizePrice(Bid-PointsToPrice(FirstStep)));
      Print(EA_NAME," R1 INTELLIGENCE ADMISSION: direction=",
            (intelligenceBuy?"BUY":"SELL"),
            " price=",DoubleToString(selectedPrice,Digits),
            " lot=",DoubleToString(Lot,DigitsLots),
            " cycleArmed=",g_eagoldR1CycleArmed,
            " entrySuspended=",EAGOLD_EntrySuspendedThisTick(),
            " tradeAllowed=",EAGOLD_TradingAllowed(),
            " windowOpen=",EAGOLD_TradingWindowOpen(),
            " spreadPoints=",DoubleToString((Ask-Bid)/Point,1));
      int selectedTicket=SendPending(
         intelligenceBuy?OP_BUYSTOP:OP_SELLSTOP,
         selectedPrice,Lot,
         intelligenceBuy?"EAGOLD ZG FIRST BUY":"EAGOLD ZG FIRST SELL");
      if(selectedTicket<=0)
      {
         Print(EA_NAME," RULE 1 INTELLIGENCE: selected seed failed. Direction=",
               (intelligenceBuy?"BUY":"SELL"),
               " lastError=",GetLastError());
         return(EAGOLD_ACTION_FAILED);
      }

      g_eagoldR1CycleArmed=false;
      ZG_AdmissionDirectionLatch(intelligenceBuy?ZG_DIR_BUY:ZG_DIR_SELL);
      R1Decision("PASS",intelligenceBuy?"INTELLIGENCE_BUY":"INTELLIGENCE_SELL");
      Print(EA_NAME," RULE 1 INTELLIGENCE: one-sided seed created. Direction=",
            (intelligenceBuy?"BUY":"SELL")," ticket=",selectedTicket,
            " edge=",DoubleToString(g_zgIntelligenceDecision.Edge,2),
            " confidence=",DoubleToString(g_zgIntelligenceDecision.Confidence,2));
      CreateEngineActionMarker("R1","ZG_SEED",intelligenceBuy?OP_BUY:OP_SELL,Lot);
      return(EAGOLD_ACTION_COMPLETED);
   }

   double buyPrice=NormalizePrice(Ask+PointsToPrice(FirstStep));
   double sellPrice=NormalizePrice(Bid-PointsToPrice(FirstStep));

   if(EnableR1AdmissionGate)
   {
      string buyReason="PASS",sellReason="PASS";
      bool buyAllowed=R1AdmissionAllowed(OP_BUY,Lot,buyPrice,buyReason);
      bool sellAllowed=R1AdmissionAllowed(OP_SELL,Lot,sellPrice,sellReason);
      if(!buyAllowed||!sellAllowed)
      {
         string reason=(!buyAllowed?"BUY_":"SELL_");
         reason+=(!buyAllowed?buyReason:sellReason);
         R1Decision("BLOCK",reason);
         Print(EA_NAME," RULE 1: FIRST cycle blocked atomically. BUY=",buyReason," SELL=",sellReason);
         CreateEngineActionMarker("R1.1","BLOCK",OP_BUY,Lot);
         CreateEngineActionMarker("R1.1","BLOCK",OP_SELL,Lot);
         return(EAGOLD_ACTION_BLOCKED);
      }
   }

   int buyTicket=SendPending(OP_BUYSTOP,buyPrice,Lot,"EAGOLD R1 FIRST BUY");
   if(buyTicket<=0)
   {
      Print(EA_NAME," RULE 1 ATOMIC: BUY seed failed. First cycle remains flat.");
      return(EAGOLD_ACTION_FAILED);
   }

   int sellTicket=SendPending(OP_SELLSTOP,sellPrice,Lot,"EAGOLD R1 FIRST SELL");
   if(sellTicket<=0)
   {
      bool rollbackOk=DeletePendingOrder(buyTicket);
      Print(EA_NAME," RULE 1 ATOMIC: SELL seed failed. BUY rollback=",(rollbackOk?"OK":"FAILED"));
      if(rollbackOk&&CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)
         return(EAGOLD_ACTION_FAILED);
      EAGOLD_R10RequestReconciliation();
      return(EAGOLD_ACTION_PARTIAL);
   }

   bool bothPresent=(CountDirectionPending(OP_BUY)>0&&CountDirectionPending(OP_SELL)>0);
   if(!bothPresent)
   {
      bool buyRollback=(CountDirectionPending(OP_BUY)==0);
      bool sellRollback=(CountDirectionPending(OP_SELL)==0);
      if(!buyRollback)
      {
         if(OrderSelect(buyTicket,SELECT_BY_TICKET,MODE_TRADES))
            buyRollback=DeletePendingOrder(buyTicket);
      }
      if(!sellRollback)
      {
         if(OrderSelect(sellTicket,SELECT_BY_TICKET,MODE_TRADES))
            sellRollback=DeletePendingOrder(sellTicket);
      }
      Print(EA_NAME," RULE 1 ATOMIC: post-send verification failed. rollback BUY=",(buyRollback?"OK":"FAILED")," SELL=",(sellRollback?"OK":"FAILED"));
      if(CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)
         return(EAGOLD_ACTION_FAILED);
      EAGOLD_R10RequestReconciliation();
      return(EAGOLD_ACTION_PARTIAL);
   }

   // Close the admission latch. It remains closed until a real market
   // position proves that this cycle became active, then later becomes flat.
   g_eagoldR1CycleArmed=false;

   Print(EA_NAME," RULE 1 ATOMIC: initial seeds created. BUY=",buyTicket," SELL=",sellTicket);
   CreateEngineActionMarker("R1","SEED",OP_BUY,Lot);
   CreateEngineActionMarker("R1","SEED",OP_SELL,Lot);
   return(EAGOLD_ACTION_COMPLETED);
}

#endif
