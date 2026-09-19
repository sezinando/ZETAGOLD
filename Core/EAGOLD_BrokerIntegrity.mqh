#ifndef EAGOLD_BROKER_INTEGRITY_MQH
#define EAGOLD_BROKER_INTEGRITY_MQH

// BROKER INTEGRITY / DOUBLE CHECK
// Purpose: establish broker-visible truth before economic engines act.
// OrdersTotal/OrderSelect are treated as the authoritative live census.
// No synthetic order state is created here.

struct EAGOLD_BrokerIntegrity
{
   bool valid;
   bool flat;
   bool orphanTagged;
   int totalSymbolOrders;
   int eagoldOrders;
   int positions;
   int buyPositions;
   int sellPositions;
   int buyPending;
   int sellPending;
   double buyLots;
   double sellLots;
   int orphanTaggedCount;
   int orphanTicket;
};

bool EAGOLD_IsEAGOLDTaggedComment(string comment)
{
   if(StringFind(comment,"EAGOLD ",0)==0) return(true);
   if(StringFind(comment,"EAGOLD_",0)==0) return(true);
   return(false);
}

void EAGOLD_BrokerIntegrityReset(EAGOLD_BrokerIntegrity &c)
{
   c.valid=false;
   c.flat=false;
   c.orphanTagged=false;
   c.totalSymbolOrders=0;
   c.eagoldOrders=0;
   c.positions=0;
   c.buyPositions=0;
   c.sellPositions=0;
   c.buyPending=0;
   c.sellPending=0;
   c.buyLots=0.0;
   c.sellLots=0.0;
   c.orphanTaggedCount=0;
   c.orphanTicket=-1;
}

bool EAGOLD_BrokerIntegrityScan(EAGOLD_BrokerIntegrity &c)
{
   EAGOLD_BrokerIntegrityReset(c);
   RefreshRates();

   int total=OrdersTotal();

   for(int i=total-1;i>=0;i--)
   {
      ResetLastError();
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         int err=GetLastError();
         Print(EA_NAME," BROKER DOUBLE CHECK: OrderSelect failed pos=",i," err=",err);
         return(false);
      }

      if(OrderSymbol()!=Symbol())
         continue;

      c.totalSymbolOrders++;

      int type=OrderType();
      int magic=OrderMagicNumber();
      string comment=OrderComment();

      if(magic==R13MagicNumber)
         continue;

      if(IsEAGOLDOrder())
      {
         c.eagoldOrders++;

         if(type==OP_BUY)
         {
            c.positions++;
            c.buyPositions++;
            c.buyLots+=OrderLots();
         }
         else if(type==OP_SELL)
         {
            c.positions++;
            c.sellPositions++;
            c.sellLots+=OrderLots();
         }
         else if(type==OP_BUYSTOP)
            c.buyPending++;
         else if(type==OP_SELLSTOP)
            c.sellPending++;
      }
      else if(EAGOLD_IsEAGOLDTaggedComment(comment))
      {
         // Do NOT silently adopt a foreign-magic order. It is an ownership
         // anomaly and must block economic execution until explicitly resolved.
         c.orphanTagged=true;
         c.orphanTaggedCount++;
         if(c.orphanTicket<0)
            c.orphanTicket=OrderTicket();

         Print(EA_NAME,
               " BROKER DOUBLE CHECK: ORPHAN TAGGED ORDER ticket=",OrderTicket(),
               " magic=",magic,
               " type=",type,
               " comment=",comment);
      }
   }

   // Independent helper cross-check. The broker census and the existing
   // ownership helpers must agree before engines are released.
   double helperBuy=DirectionLots(OP_BUY);
   double helperSell=DirectionLots(OP_SELL);
   int helperTotal=CountEAGOLDOrders();

   if(MathAbs(c.buyLots-helperBuy)>0.00001 ||
      MathAbs(c.sellLots-helperSell)>0.00001 ||
      c.eagoldOrders!=helperTotal)
   {
      Print(EA_NAME,
            " BROKER DOUBLE CHECK: CENSUS MISMATCH raw=",
            c.eagoldOrders,
            " helper=",helperTotal,
            " rawBuyLots=",DoubleToString(c.buyLots,DigitsLots),
            " helperBuyLots=",DoubleToString(helperBuy,DigitsLots),
            " rawSellLots=",DoubleToString(c.sellLots,DigitsLots),
            " helperSellLots=",DoubleToString(helperSell,DigitsLots));
      return(false);
   }

   c.flat=(c.eagoldOrders==0);
   c.valid=(!c.orphanTagged);
   return(c.valid);
}

#endif
