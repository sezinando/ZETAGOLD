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

      double selectedPrice=(selectedDirection==OP_BUY?
         NormalizePrice(Ask+PointsToPrice(FirstStep)):
         NormalizePrice(Bid-PointsToPrice(FirstStep)));
      int selectedTicket=SendPending(
         selectedDirection==OP_BUY?OP_BUYSTOP:OP_SELLSTOP,
         selectedPrice,Lot,
         selectedDirection==OP_BUY?"EAGOLD ZG FIRST BUY":"EAGOLD ZG FIRST SELL");
      if(selectedTicket<=0)
      {
         Print(EA_NAME," RULE 1 INTELLIGENCE: selected seed failed. Direction=",
               (selectedDirection==OP_BUY?"BUY":"SELL"));
         return(EAGOLD_ACTION_FAILED);
      }

      g_eagoldR1CycleArmed=false;
      R1Decision("PASS",selectedDirection==OP_BUY?"INTELLIGENCE_BUY":"INTELLIGENCE_SELL");
      Print(EA_NAME," RULE 1 INTELLIGENCE: one-sided seed created. Direction=",
            (selectedDirection==OP_BUY?"BUY":"SELL")," ticket=",selectedTicket,
            " edge=",DoubleToString(g_zgIntelligenceDecision.Edge,2),
            " confidence=",DoubleToString(g_zgIntelligenceDecision.Confidence,2));
      CreateEngineActionMarker("R1","ZG_SEED",selectedDirection,Lot);
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
