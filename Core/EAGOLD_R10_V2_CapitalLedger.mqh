#ifndef EAGOLD_R10_V2_CAPITAL_LEDGER_MQH
#define EAGOLD_R10_V2_CAPITAL_LEDGER_MQH

//==================================================================
// R10 v2 — REDUCTION CAPITAL LEDGER
// ETAPA 13.13
//
// Authoritative accounting boundary for capital that may finance
// R10 v2 reduction.
//
// Current authorized source:
//   R13 Recovery Capital
//
// The ledger mirrors the already-authorized R13 capital; it does not
// manufacture additional capital from Balance, Equity, Free Margin
// or floating P/L.
//
// State model:
//   GENERATED -> ELIGIBLE -> RESERVED -> CONSUMED
//                              |
//                              -> RELEASED
//
// This stage does not execute broker operations.
//==================================================================

struct EAGOLD_R10V2CapitalLedger
{
   double realizedProfitGenerated;
   double capitalEligible;
   double capitalReserved;
   double capitalConsumed;
   double capitalReleased;
   double capitalRemaining;
   double r13CapitalAvailable;
   double r13CapitalUsed;
};

EAGOLD_R10V2CapitalLedger g_r10V2CapitalLedger;

void EAGOLD_R10V2CapitalLedgerReset()
{
   g_r10V2CapitalLedger.realizedProfitGenerated=0.0;
   g_r10V2CapitalLedger.capitalEligible=0.0;
   g_r10V2CapitalLedger.capitalReserved=0.0;
   g_r10V2CapitalLedger.capitalConsumed=0.0;
   g_r10V2CapitalLedger.capitalReleased=0.0;
   g_r10V2CapitalLedger.capitalRemaining=0.0;
   g_r10V2CapitalLedger.r13CapitalAvailable=0.0;
   g_r10V2CapitalLedger.r13CapitalUsed=0.0;
   g_r10V2CapitalLedger.reservationActive=false;
   g_r10V2CapitalLedger.reservationAmount=0.0;
   g_r10V2CapitalLedger.reservationTicket=-1;
   g_r10V2CapitalLedger.reservationTicket2=-1;
   g_r10V2CapitalLedger.reservationTimestamp=0;
}

void EAGOLD_R10V2CapitalLedgerSync()
{
   // R13 is the current explicit capital authority.
   // Mirror its already-authorized available balance; do not add it
   // again to RealizationCascade or any other profit bucket.
   double available=MathMax(0.0,g_r13RecoveryCapitalAvailable);
   double used=MathMax(0.0,g_r13RecoveryCapitalUsed);

   g_r10V2CapitalLedger.r13CapitalAvailable=available;
   g_r10V2CapitalLedger.r13CapitalUsed=used;

   g_r10V2CapitalLedger.capitalEligible=available;
   g_r10V2CapitalLedger.capitalRemaining=MathMax(
      0.0,
      g_r10V2CapitalLedger.capitalEligible
      -g_r10V2CapitalLedger.capitalReserved
      -g_r10V2CapitalLedger.capitalConsumed);
}

double EAGOLD_R10V2CapitalAvailable()
{
   return(MathMax(0.0,g_r10V2CapitalLedger.capitalRemaining));
}

double EAGOLD_R10V2CapitalCapacityLots(
   double lossPerLot,
   double desiredLots)
{
   if(lossPerLot<=0.0 || desiredLots<Lot)return(0.0);

   double utilization=MathMax(0.0,MathMin(1.0,R10V2CapitalUtilization));
   double spendable=EAGOLD_R10V2CapitalAvailable()*utilization;
   if(spendable<=0.0)return(0.0);

   double capacity=spendable/lossPerLot;
   capacity=MathMin(capacity,desiredLots);

   return(EAGOLD_R10V2NormalizeCapacityLots(capacity));
}

bool EAGOLD_R10V2CapitalReserve(double amount)
{
   if(amount<=0.0)return(false);
   double available=EAGOLD_R10V2CapitalAvailable();
   if(amount>available+0.01)return(false);

   g_r10V2CapitalLedger.capitalReserved+=amount;
   g_r10V2CapitalLedger.capitalRemaining=MathMax(
      0.0,
      g_r10V2CapitalLedger.capitalEligible
      -g_r10V2CapitalLedger.capitalReserved
      -g_r10V2CapitalLedger.capitalConsumed);
   return(true);
}

void EAGOLD_R10V2CapitalRelease(double amount)
{
   if(amount<=0.0)return;
   double released=MathMin(amount,g_r10V2CapitalLedger.capitalReserved);
   g_r10V2CapitalLedger.capitalReserved-=released;
   g_r10V2CapitalLedger.capitalReleased+=released;
   g_r10V2CapitalLedger.capitalRemaining=MathMax(
      0.0,
      g_r10V2CapitalLedger.capitalEligible
      -g_r10V2CapitalLedger.capitalReserved
      -g_r10V2CapitalLedger.capitalConsumed
      +g_r10V2CapitalLedger.capitalReleased);
}

bool EAGOLD_R10V2CapitalConsumeReserved(double amount)
{
   if(amount<=0.0)return(false);
   if(amount>g_r10V2CapitalLedger.capitalReserved+0.01)return(false);

   g_r10V2CapitalLedger.capitalReserved-=amount;
   g_r10V2CapitalLedger.capitalConsumed+=amount;
   g_r10V2CapitalLedger.capitalRemaining=MathMax(
      0.0,
      g_r10V2CapitalLedger.capitalEligible
      -g_r10V2CapitalLedger.capitalReserved
      -g_r10V2CapitalLedger.capitalConsumed);
   return(true);
}

// ETAPA 13.18 — one active reservation transaction.
// Reservation is a hold only; it is not consumption.
bool EAGOLD_R10V2CapitalReserveTransaction(
   double amount,
   int ticket,
   int ticket2,
   datetime timestamp)
{
   if(amount<=0.0)return(false);
   if(ticket<0)return(false);
   if(g_r10V2CapitalLedger.reservationActive)return(false);

   if(!EAGOLD_R10V2CapitalReserve(amount))
      return(false);

   g_r10V2CapitalLedger.reservationActive=true;
   g_r10V2CapitalLedger.reservationAmount=amount;
   g_r10V2CapitalLedger.reservationTicket=ticket;
   g_r10V2CapitalLedger.reservationTicket2=ticket2;
   g_r10V2CapitalLedger.reservationTimestamp=timestamp;
   return(true);
}

bool EAGOLD_R10V2CapitalReservationActive()
{
   return(g_r10V2CapitalLedger.reservationActive);
}

double EAGOLD_R10V2CapitalReservationAmount()
{
   return(MathMax(0.0,g_r10V2CapitalLedger.reservationAmount));
}

bool EAGOLD_R10V2CapitalReleaseTransaction()
{
   if(!g_r10V2CapitalLedger.reservationActive)return(false);

   double amount=g_r10V2CapitalLedger.reservationAmount;
   EAGOLD_R10V2CapitalRelease(amount);

   g_r10V2CapitalLedger.reservationActive=false;
   g_r10V2CapitalLedger.reservationAmount=0.0;
   g_r10V2CapitalLedger.reservationTicket=-1;
   g_r10V2CapitalLedger.reservationTicket2=-1;
   g_r10V2CapitalLedger.reservationTimestamp=0;
   return(true);
}

bool EAGOLD_R10V2CapitalConsumeReservation(double consumedAmount)
{
   if(!g_r10V2CapitalLedger.reservationActive)return(false);

   double reserved=g_r10V2CapitalLedger.reservationAmount;
   double consume=MathMax(0.0,MathMin(consumedAmount,reserved));
   if(consume<=0.0)return(false);

   if(!EAGOLD_R10V2CapitalConsumeReserved(consume))
      return(false);

   double release=reserved-consume;
   if(release>0.0)
      EAGOLD_R10V2CapitalRelease(release);

   g_r10V2CapitalLedger.reservationActive=false;
   g_r10V2CapitalLedger.reservationAmount=0.0;
   g_r10V2CapitalLedger.reservationTicket=-1;
   g_r10V2CapitalLedger.reservationTicket2=-1;
   g_r10V2CapitalLedger.reservationTimestamp=0;
   return(true);
}

#endif
