#ifndef EAGOLD_R10_V2_BALANCED_PAIR_MQH
#define EAGOLD_R10_V2_BALANCED_PAIR_MQH

//==================================================================
// R10 v2 — BALANCED PAIR SELECTION / CAPACITY
// ETAPA 13.15
//
// Explicitly resolves the two legs required by Balanced Reduce.
// This module is read-only: no broker mutation and no real capital
// reservation.
//
// Invariant for an authorized common reduction q:
//   BUY'  = BUY  - q
//   SELL' = SELL - q
//   GROSS'= GROSS - 2q
//   NET'  = NET
//==================================================================

struct EAGOLD_R10V2BalancedPair
{
   bool found;
   EAGOLD_R10V2Ticket buy;
   EAGOLD_R10V2Ticket sell;
   double commonCandidateLots;
   double commonDesiredLots;
   double commonExposureCapacity;
   double commonR11Capacity;
   double commonBrokerCapacity;
   double commonCapitalCapacity;
   double authorizedCommonLots;
   double capitalRequired;
};

void EAGOLD_R10V2BalancedPairReset(EAGOLD_R10V2BalancedPair &pair)
{
   pair.found=false;
   EAGOLD_R10V2TicketReset(pair.buy);
   EAGOLD_R10V2TicketReset(pair.sell);
   pair.commonCandidateLots=0.0;
   pair.commonDesiredLots=0.0;
   pair.commonExposureCapacity=0.0;
   pair.commonR11Capacity=0.0;
   pair.commonBrokerCapacity=0.0;
   pair.commonCapitalCapacity=0.0;
   pair.authorizedCommonLots=0.0;
   pair.capitalRequired=0.0;
}

bool EAGOLD_R10V2BalancedBetter(const EAGOLD_R10V2Ticket &a,
                                 const EAGOLD_R10V2Ticket &b)
{
   if(b.ticket<0)return(true);
   if(a.distanceToMarket>b.distanceToMarket)return(true);
   if(a.lossPerLot>b.lossPerLot)return(true);
   return(false);
}

void EAGOLD_R10V2SelectBalancedPair(const EAGOLD_R10V2Context &ctx,
                                     EAGOLD_R10V2BalancedPair &pair)
{
   EAGOLD_R10V2BalancedPairReset(pair);

   EAGOLD_R10V2Ticket bestBuy;
   EAGOLD_R10V2Ticket bestSell;
   EAGOLD_R10V2TicketReset(bestBuy);
   EAGOLD_R10V2TicketReset(bestSell);

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;

      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)continue;

      EAGOLD_R10V2Ticket candidate;
      EAGOLD_R10V2BuildTicket(ctx,candidate);
      if(candidate.ticket<0 || candidate.lots<Lot)continue;

      if(type==OP_BUY)
      {
         if(EAGOLD_R10V2BalancedBetter(candidate,bestBuy))
            bestBuy=candidate;
      }
      else
      {
         if(EAGOLD_R10V2BalancedBetter(candidate,bestSell))
            bestSell=candidate;
      }
   }

   if(bestBuy.ticket<0 || bestSell.ticket<0)return;

   pair.found=true;
   pair.buy=bestBuy;
   pair.sell=bestSell;
   pair.commonCandidateLots=MathMin(bestBuy.lots,bestSell.lots);
   double ratio=R10V2ReduceRatio;
   if(ratio<0.0)ratio=0.0;
   pair.commonDesiredLots=pair.commonCandidateLots*ratio;
   if(R10V2MaxReductionLots>0.0)
      pair.commonDesiredLots=MathMin(pair.commonDesiredLots,R10V2MaxReductionLots);
   pair.commonDesiredLots=MathMin(
      pair.commonDesiredLots,pair.commonCandidateLots);
   pair.commonDesiredLots=EAGOLD_R10V2NormalizeCapacityLots(pair.commonDesiredLots);
   if(pair.commonDesiredLots>pair.commonCandidateLots)
      pair.commonDesiredLots=pair.commonCandidateLots;
}

double EAGOLD_R10V2BalancedCapitalRequirement(
   const EAGOLD_R10V2BalancedPair &pair,
   double commonLots)
{
   if(!pair.found || commonLots<Lot)return(0.0);

   double buyPerLot=0.0;
   double sellPerLot=0.0;

   if(pair.buy.lots>0.0)
      buyPerLot=pair.buy.floatingProfit/pair.buy.lots;
   if(pair.sell.lots>0.0)
      sellPerLot=pair.sell.floatingProfit/pair.sell.lots;

   double projectedPL=commonLots*(buyPerLot+sellPerLot);
   return(MathMax(0.0,-projectedPL));
}

#endif
