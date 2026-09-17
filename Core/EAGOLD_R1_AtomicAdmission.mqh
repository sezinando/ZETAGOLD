#ifndef EAGOLD_R1_ATOMIC_ADMISSION_MQH
#define EAGOLD_R1_ATOMIC_ADMISSION_MQH

// R1 atomic first-seed transaction.
// A flat EAGOLD basket must end the admission attempt with either BOTH
// directional seed pendings present or NONE. A one-sided seed is never
// accepted as a successful first cycle.
bool g_eagoldR1CycleArmed=true;
bool g_eagoldR1BasketWasActive=false;

void EAGOLD_R1ResetCycleLatch(){g_eagoldR1CycleArmed=true;g_eagoldR1BasketWasActive=false;}

void EAGOLD_R1ObserveCycle(){int livePositions=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);if(livePositions>0){g_eagoldR1BasketWasActive=true;return;}if(g_eagoldR1BasketWasActive){if(!g_eagoldR1CycleArmed){g_eagoldR1CycleArmed=true;Print(EA_NAME," RULE 1 CYCLE: BASKET_FLAT -> R1_REARM.");}g_eagoldR1BasketWasActive=false;}}

EAGOLD_ActionResult EAGOLD_CreateFirstOrdersAtomic()
{
   EAGOLD_R1ObserveCycle();
   if(EAGOLD_EntrySuspendedThisTick())return(EAGOLD_ACTION_BLOCKED);
   if(!g_eagoldR1CycleArmed)return(EAGOLD_ACTION_BLOCKED);
   if(CountEAGOLDOrders()>0)return(EAGOLD_ACTION_BLOCKED);
   RefreshRates();
   double buyPrice=NormalizePrice(Ask+PointsToPrice(FirstStep));
   double sellPrice=NormalizePrice(Bid-PointsToPrice(FirstStep));
   if(EnableR1AdmissionGate)
   {
      string buyReason="PASS",sellReason="PASS";
      bool buyAllowed=R1AdmissionAllowed(OP_BUY,Lot,buyPrice,buyReason);
      bool sellAllowed=R1AdmissionAllowed(OP_SELL,Lot,sellPrice,sellReason);
      if(!buyAllowed||!sellAllowed){string reason=(!buyAllowed?"BUY_":"SELL_");reason+=(!buyAllowed?buyReason:sellReason);R1Decision("BLOCK",reason);Print(EA_NAME," RULE 1: FIRST cycle blocked atomically. BUY=",buyReason," SELL=",sellReason);CreateEngineActionMarker("R1.1","BLOCK",OP_BUY,Lot);CreateEngineActionMarker("R1.1","BLOCK",OP_SELL,Lot);return(EAGOLD_ACTION_BLOCKED);}
   }
   int buyTicket=SendPending(OP_BUYSTOP,buyPrice,Lot,"EAGOLD R1 FIRST BUY");
   if(buyTicket<=0)return(EAGOLD_ACTION_FAILED);
   int sellTicket=SendPending(OP_SELLSTOP,sellPrice,Lot,"EAGOLD R1 FIRST SELL");
   if(sellTicket<=0){bool rollbackOk=DeletePendingOrder(buyTicket);if(rollbackOk&&CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)return(EAGOLD_ACTION_FAILED);EAGOLD_R10RequestReconciliation();return(EAGOLD_ACTION_PARTIAL);}
   bool bothPresent=(CountDirectionPending(OP_BUY)>0&&CountDirectionPending(OP_SELL)>0);
   if(!bothPresent){bool buyRollback=(CountDirectionPending(OP_BUY)==0),sellRollback=(CountDirectionPending(OP_SELL)==0);if(!buyRollback&&OrderSelect(buyTicket,SELECT_BY_TICKET,MODE_TRADES))buyRollback=DeletePendingOrder(buyTicket);if(!sellRollback&&OrderSelect(sellTicket,SELECT_BY_TICKET,MODE_TRADES))sellRollback=DeletePendingOrder(sellTicket);if(CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)return(EAGOLD_ACTION_FAILED);EAGOLD_R10RequestReconciliation();return(EAGOLD_ACTION_PARTIAL);}
   g_eagoldR1CycleArmed=false;
   Print(EA_NAME," RULE 1 ATOMIC: initial seeds created. BUY=",buyTicket," SELL=",sellTicket);
   CreateEngineActionMarker("R1","SEED",OP_BUY,Lot);CreateEngineActionMarker("R1","SEED",OP_SELL,Lot);
   return(EAGOLD_ACTION_COMPLETED);
}

#endif
