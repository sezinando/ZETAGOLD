#ifndef EAGOLD_R10_V2_CONTEXT_MQH
#define EAGOLD_R10_V2_CONTEXT_MQH

//==================================================================
// R10 v2 — DECISION CONTEXT
// ETAPA 13.1
//
// Read-only snapshot of the current EAGOLD exposure state.
// This module does NOT:
//   - close/open/delete orders
//   - change SL/TP
//   - reserve/consume reduction capital
//   - call R11
//   - replace the operational R10
//
// It is the data boundary for the future R10 v2 decision layer.
//==================================================================

struct EAGOLD_R10V2Context
{
   datetime timestamp;
   string   symbol;
   int      magic;

   int      buyTickets;
   int      sellTickets;
   int      buyPending;
   int      sellPending;

   double   buyLots;
   double   sellLots;
   double   grossExposure;
   double   netExposure;

   double   buyProfit;
   double   sellProfit;
   double   totalFloatingProfit;

   double   accountBalance;
   double   accountEquity;
   double   freeMargin;

   double   realizedProfitAll;
   double   realizedProfitToday;

   double   bid;
   double   ask;
   double   spreadPoints;

   bool     hasExposure;
   bool     hasBothDirections;
   bool     heavyBuy;
   bool     heavySell;
};

void EAGOLD_R10V2ContextReset(EAGOLD_R10V2Context &ctx)
{
   ctx.timestamp=0;
   ctx.symbol="";
   ctx.magic=0;

   ctx.buyTickets=0;
   ctx.sellTickets=0;
   ctx.buyPending=0;
   ctx.sellPending=0;

   ctx.buyLots=0.0;
   ctx.sellLots=0.0;
   ctx.grossExposure=0.0;
   ctx.netExposure=0.0;

   ctx.buyProfit=0.0;
   ctx.sellProfit=0.0;
   ctx.totalFloatingProfit=0.0;

   ctx.accountBalance=0.0;
   ctx.accountEquity=0.0;
   ctx.freeMargin=0.0;

   ctx.realizedProfitAll=0.0;
   ctx.realizedProfitToday=0.0;

   ctx.bid=0.0;
   ctx.ask=0.0;
   ctx.spreadPoints=0.0;

   ctx.hasExposure=false;
   ctx.hasBothDirections=false;
   ctx.heavyBuy=false;
   ctx.heavySell=false;
}

void EAGOLD_R10V2ContextBuild(EAGOLD_R10V2Context &ctx)
{
   EAGOLD_R10V2ContextReset(ctx);

   ctx.timestamp=TimeCurrent();
   ctx.symbol=Symbol();
   ctx.magic=MagicNumber;

   RefreshRates();

   ctx.bid=Bid;
   ctx.ask=Ask;
   ctx.spreadPoints=(Ask-Bid)/Point;

   ctx.accountBalance=AccountBalance();
   ctx.accountEquity=AccountEquity();
   ctx.freeMargin=AccountFreeMargin();

   ctx.realizedProfitAll=EAGOLDAccumulatedProfit();
   ctx.realizedProfitToday=EAGOLDTodayProfit();

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(!IsEAGOLDOrder())
         continue;

      int type=OrderType();

      if(type==OP_BUY)
      {
         ctx.buyTickets++;
         ctx.buyLots+=OrderLots();
         ctx.buyProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
      else if(type==OP_SELL)
      {
         ctx.sellTickets++;
         ctx.sellLots+=OrderLots();
         ctx.sellProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
      else if(type==OP_BUYSTOP || type==OP_BUYLIMIT)
      {
         ctx.buyPending++;
      }
      else if(type==OP_SELLSTOP || type==OP_SELLLIMIT)
      {
         ctx.sellPending++;
      }
   }

   ctx.grossExposure=ctx.buyLots+ctx.sellLots;
   ctx.netExposure=MathAbs(ctx.buyLots-ctx.sellLots);
   ctx.totalFloatingProfit=ctx.buyProfit+ctx.sellProfit;

   ctx.hasExposure=(ctx.grossExposure>=Lot);
   ctx.hasBothDirections=(ctx.buyLots>=Lot && ctx.sellLots>=Lot);
   ctx.heavyBuy=(ctx.buyLots>ctx.sellLots);
   ctx.heavySell=(ctx.sellLots>ctx.buyLots);
}

#endif
