#ifndef EAGOLD_R10_V2_BACKTEST_MQH
#define EAGOLD_R10_V2_BACKTEST_MQH

// EAGOLD R10 v2 BACKTEST SIMULATION v1.0
// Safety boundary: execution is permitted ONLY inside the MT4 Strategy Tester.
// This module intentionally does not execute on live/demo charts.
// It reuses the current R10 v2 decision primitives and converts an authorized
// decision into real tester-side partial closes so the subsequent EA state evolves.

datetime g_r10v2BacktestLastAction=0;

bool R10V2BacktestEnabled(){
   return(EnableR10V2BacktestSimulation && IsTesting());
}

bool R10V2BacktestCooldownReady(){
   if(R10V2CooldownSeconds<=0)return(true);
   if(g_r10v2BacktestLastAction==0)return(true);
   return((TimeCurrent()-g_r10v2BacktestLastAction)>=R10V2CooldownSeconds);
}

double R10V2BacktestClampRatio(){
   double ratio=R10V2ReduceRatio;
   if(ratio<0.0)ratio=0.0;
   if(ratio>1.0)ratio=1.0;
   return(ratio);
}

double R10V2BacktestCapLots(double lots){
   if(R10V2MaxReductionLots>0.0)lots=MathMin(lots,R10V2MaxReductionLots);
   return(R10V2ShadowNormalizeLots(lots));
}

double R10V2BacktestCycleCapital(){
   double total=EAGOLDAccumulatedProfit();
   double cycle=(g_excursionActive?total-g_excursionStartRealized:0.0);
   return(MathMax(0.0,cycle));
}

bool R10V2BacktestCloseTicket(int ticket,double lots,double &realized){
   realized=0.0;
   if(ticket<0||lots<Lot)return(false);
   return(CloseMarketOrderLots(ticket,lots,realized));
}

bool R10V2BacktestFindTicket(int direction,int &ticket,double &ticketLots,double &ticketPL,double &lossPerLot){
   lossPerLot=R10V2ShadowWorstLossPerLot(direction,ticket,ticketLots,ticketPL);
   return(ticket>0 && ticketLots>=Lot && ticketPL<0.0 && lossPerLot>0.0);
}

// Returns true only when a tester-side reduction was actually executed.
// A failed/partial sequence requests reconciliation through the Action Contract.
bool EAGOLD_R10V2BacktestExecute(){
   if(!R10V2BacktestEnabled())return(false);
   if(!EAGOLD_EconomicExecutionAllowed())return(false);
   if(!EnableR10Reduce)return(false);
   if(!R10V2BacktestCooldownReady())return(false);

   double buy=DirectionLots(OP_BUY),sell=DirectionLots(OP_SELL);
   double gross=buy+sell;
   if(gross<R10MinExposureLots)return(false);

   double ratio=R10V2BacktestClampRatio();
   if(ratio<=0.0)return(false);

   // OPP-1: Balanced Reduction. Equal volume is removed from both directions,
   // preserving NET exposure while reducing GROSS exposure.
   if(R10V2EnableBalancedReduction && buy>=Lot && sell>=Lot){
      double common=R10V2BacktestCapLots(MathMin(buy,sell)*ratio);
      if(common>=Lot && (2.0*common)>=R10V2MinGrossRelief){
         int buyTicket=-1,sellTicket=-1;
         double buyLots=0.0,buyPL=0.0,buyLossPerLot=0.0;
         double sellLots=0.0,sellPL=0.0,sellLossPerLot=0.0;
         bool haveBuy=R10V2BacktestFindTicket(OP_BUY,buyTicket,buyLots,buyPL,buyLossPerLot);
         bool haveSell=R10V2BacktestFindTicket(OP_SELL,sellTicket,sellLots,sellPL,sellLossPerLot);

         // Balanced reduction does not require a losing target; it requires
         // executable tickets on both sides.
         if(haveBuy && haveSell){
            double realizedBuy=0.0,realizedSell=0.0;
            bool okBuy=R10V2BacktestCloseTicket(buyTicket,MathMin(common,buyLots),realizedBuy);
            if(!okBuy){
               EAGOLD_ApplyActionResult(EAGOLD_ACTION_FAILED,"R10_V2_BT","BALANCED_REDUCTION",OP_BUY,common);
               return(false);
            }

            bool okSell=R10V2BacktestCloseTicket(sellTicket,MathMin(common,sellLots),realizedSell);
            if(!okSell){
               EAGOLD_R10RequestReconciliation();
               g_eagoldTickPolicy=EAGOLD_TICK_HALT_FOR_RECONCILIATION;
               EAGOLD_ApplyActionResult(EAGOLD_ACTION_PARTIAL,"R10_V2_BT","BALANCED_REDUCTION",OP_SELL,common);
               return(true);
            }

            g_r10v2BacktestLastAction=TimeCurrent();
            EAGOLD_ApplyActionResult(EAGOLD_ACTION_PARTIAL,"R10_V2_BT","BALANCED_REDUCTION",OP_BUY,common);
            Print(EA_NAME," R10 V2 BACKTEST: BALANCED executed buyTicket=",buyTicket,
                  " sellTicket=",sellTicket," lots=",DoubleToString(common,DigitsLots),
                  " realized=",DoubleToString(realizedBuy+realizedSell,2));
            return(true);
         }
      }
   }

   // OPP-2/3: Position / directional adjustment funded by realized cycle capital.
   int direction=HeavyDirection();
   if(direction<0)return(false);
   if(!R10V2EnablePositionAdjustment && !R10V2EnableDirectionalReduction)return(false);

   int ticket=-1;
   double ticketLots=0.0,ticketPL=0.0,lossPerLot=0.0;
   if(!R10V2BacktestFindTicket(direction,ticket,ticketLots,ticketPL,lossPerLot))return(false);
   if(R10V2MinimumLossPerLot>0.0 && lossPerLot<R10V2MinimumLossPerLot)return(false);

   double capital=R10V2BacktestCycleCapital()*MathMax(0.0,MathMin(1.0,R10V2CapitalUtilization));
   if(capital<=0.0)return(false);

   double candidate=R10V2BacktestCapLots(ticketLots*ratio);
   double capitalCapacity=R10V2BacktestCapLots(capital/lossPerLot);
   double opposite=(direction==OP_BUY?sell:buy);
   double same=(direction==OP_BUY?buy:sell);
   double exposureCapacity=MathMax(0.0,same-opposite);
   double authorized=MathMin(candidate,MathMin(capitalCapacity,exposureCapacity));
   authorized=R10V2BacktestCapLots(authorized);

   if(authorized<Lot)return(false);
   if(authorized>ticketLots)authorized=ticketLots;

   double realized=0.0;
   if(!R10V2BacktestCloseTicket(ticket,authorized,realized)){
      EAGOLD_ApplyActionResult(EAGOLD_ACTION_FAILED,"R10_V2_BT","POSITION_ADJUSTMENT",direction,authorized);
      return(false);
   }

   g_r10v2BacktestLastAction=TimeCurrent();
   EAGOLD_ApplyActionResult(EAGOLD_ACTION_PARTIAL,"R10_V2_BT",
                            (R10V2EnablePositionAdjustment?"POSITION_ADJUSTMENT":"DIRECTIONAL_REDUCTION"),
                            direction,authorized);
   Print(EA_NAME," R10 V2 BACKTEST: POSITION executed ticket=",ticket,
         " direction=",R10V2ShadowDirName(direction),
         " lots=",DoubleToString(authorized,DigitsLots),
         " capitalUsed=",DoubleToString(MathAbs(realized),2),
         " lossPerLot=",DoubleToString(lossPerLot,2));
   return(true);
}

void EAGOLD_R10V2BacktestReset(){
   g_r10v2BacktestLastAction=0;
}

#endif
