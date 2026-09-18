#ifndef EAGOLD_R10_V2_SHADOW_MQH
#define EAGOLD_R10_V2_SHADOW_MQH

// EAGOLD R10 v2 DECISION SHADOW v1.0
// Observer-only. No broker mutation, no capital reservation, no R11/R13 mutation.
// Purpose: measure what R10 v2 WOULD decide from the real state.

long g_r10v2ShadowSequence=0;
int g_r10v2ShadowHandle=INVALID_HANDLE;
string g_r10v2ShadowLastSignature="";

string R10V2ShadowDirName(int direction){return(direction==OP_BUY?"BUY":(direction==OP_SELL?"SELL":"NONE"));}

void R10V2ShadowHeader(int handle){
   if(FileSize(handle)>0)return;
   FileWrite(handle,
      "SHADOW_SEQ","TIMESTAMP","PHASE","CYCLE_ID","DIRECTION","OBJECTIVE","SELECTION_POLICY",
      "TARGET_TICKET","TARGET_LOTS","DESIRED_LOTS","CAPITAL_AVAILABLE","CAPITAL_CAPACITY",
      "EXPOSURE_CAPACITY","R11_CAPACITY","BROKER_CAPACITY","AUTHORIZED_LOTS",
      "BUY_LOTS_BEFORE","SELL_LOTS_BEFORE","GROSS_BEFORE","NET_BEFORE",
      "BUY_LOTS_AFTER","SELL_LOTS_AFTER","GROSS_AFTER","NET_AFTER",
      "TARGET_PL","TARGET_LOSS_PER_LOT","GROSS_RELIEF","NET_DELTA",
      "RECOVERY_LOAD_BEFORE","RECOVERY_LOAD_AFTER","RECOVERY_LOAD_RELIEF",
      "PROJECTED_REALIZED_PL","PROJECTED_CAPITAL_CONSUMED",
      "DECISION_STATE","DECISION_REASON");
}

int R10V2ShadowOpen(){
   if(g_r10v2ShadowHandle!=INVALID_HANDLE)return(g_r10v2ShadowHandle);
   ResetLastError();
   g_r10v2ShadowHandle=FileOpen("EAGOLD_R10_V2_SHADOW.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(g_r10v2ShadowHandle==INVALID_HANDLE){
      Print(EA_NAME," R10 V2 SHADOW: FileOpen FAILED error=",GetLastError());
      return(INVALID_HANDLE);
   }
   FileSeek(g_r10v2ShadowHandle,0,SEEK_END);
   R10V2ShadowHeader(g_r10v2ShadowHandle);
   return(g_r10v2ShadowHandle);
}

void EAGOLD_R10V2ShadowClose(){
   if(g_r10v2ShadowHandle==INVALID_HANDLE)return;
   FileFlush(g_r10v2ShadowHandle);
   FileClose(g_r10v2ShadowHandle);
   g_r10v2ShadowHandle=INVALID_HANDLE;
}

double R10V2ShadowRecoveryLoad(int direction){
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   double load=0.0;
   RefreshRates();
   double market=(direction==OP_BUY?Bid:Ask);
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      load+=OrderLots()*MathAbs(OrderOpenPrice()-market);
   }
   return(load);
}

double R10V2ShadowWorstLossPerLot(int direction,int &ticket,double &ticketLots,double &ticketPL){
   ticket=-1;ticketLots=0.0;ticketPL=0.0;
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   double worstPerLot=0.0;
   double worstOpen=0.0;
   bool found=false;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      double lots=OrderLots();
      if(lots<Lot)continue;
      double pl=OrderProfit()+OrderSwap()+OrderCommission();
      if(pl>=0.0)continue;
      double perLot=MathAbs(pl)/lots;
      double open=OrderOpenPrice();
      bool moreAdverse=(!found||(type==OP_BUY&&open>worstOpen)||(type==OP_SELL&&open<worstOpen));
      if(moreAdverse){
         found=true;ticket=OrderTicket();ticketLots=lots;ticketPL=pl;worstOpen=open;worstPerLot=perLot;
      }
   }
   return(worstPerLot);
}

double R10V2ShadowNormalizeLots(double lots){
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   if(step<=0.0)step=Lot;
   if(minLot<=0.0)minLot=Lot;
   lots=MathFloor((lots+1.0e-10)/step)*step;
   lots=NormalizeDouble(lots,DigitsLots);
   if(lots<minLot||lots<Lot)return(0.0);
   return(lots);
}

void EAGOLD_R10V2ShadowWrite(string phase){
   if(!EnableCounterfactualPathTelemetry)return;
   int handle=R10V2ShadowOpen();
   if(handle==INVALID_HANDLE)return;

   double buy=DirectionLots(OP_BUY),sell=DirectionLots(OP_SELL);
   double gross=buy+sell,net=MathAbs(buy-sell);
   if(gross<Lot)return;

   int direction=HeavyDirection();
   string objective="NONE",policy="NONE",state="NO_OPPORTUNITY",reason="NO_EXPOSURE";
   int targetTicket=-1;
   double targetLots=0.0,targetPL=0.0,lossPerLot=0.0;
   double desired=0.0,capitalAvailable=0.0,capitalCapacity=0.0,exposureCapacity=0.0;
   double r11Capacity=0.0,brokerCapacity=0.0,authorized=0.0;
   double projectedPL=0.0,projectedCapital=0.0;
   double recoveryBefore=0.0,recoveryAfter=0.0;
   double grossAfter=gross,netAfter=net,buyAfter=buy,sellAfter=sell;

   if(direction<0){
      reason="BALANCED_NOT_DOMINANT";
   }else{
      lossPerLot=R10V2ShadowWorstLossPerLot(direction,targetTicket,targetLots,targetPL);

      // OPP-1: balanced reduction preserves NET and reduces GROSS.
      double balancedCapacity=MathMin(buy,sell);
      if(balancedCapacity>=Lot && R10MinExposureLots>0.0){
         objective="BALANCED_REDUCTION";
         policy="COMMON_VOLUME";
         desired=R10V2ShadowNormalizeLots(balancedCapacity*0.125);
         if(desired>=Lot){
            exposureCapacity=balancedCapacity;
            r11Capacity=desired; // R11 governs additions; shadow keeps reduction permissive.
            brokerCapacity=balancedCapacity;
            authorized=MathMin(desired,MathMin(exposureCapacity,MathMin(r11Capacity,brokerCapacity)));
            authorized=R10V2ShadowNormalizeLots(authorized);
            if(authorized>=Lot){
               state="AUTHORIZED";reason="GROSS_RELIEF_NET_PRESERVED";
               buyAfter=buy-authorized;sellAfter=sell-authorized;
               grossAfter=buyAfter+sellAfter;netAfter=MathAbs(buyAfter-sellAfter);
               recoveryBefore=R10V2ShadowRecoveryLoad(OP_BUY)+R10V2ShadowRecoveryLoad(OP_SELL);
               // Balanced reduction is a projection only; use current load minus proportional relief.
               recoveryAfter=MathMax(0.0,recoveryBefore-(recoveryBefore*(2.0*authorized/MathMax(gross,Lot))));
               projectedPL=0.0;projectedCapital=0.0;
            }else reason="BROKER_CAPACITY";
         }else reason="CANDIDATE_BELOW_BROKER_MIN";
      }

      // OPP-2/3: if no balanced authorization, test adverse-ticket adjustment.
      if(state!="AUTHORIZED" && targetTicket>0 && lossPerLot>0.0){
         objective="POSITION_ADJUSTMENT";
         policy="MOST_ADVERSE_TICKET";
         state="CANDIDATE";
         reason="TARGET_ELIGIBLE";

         double realizedTotal=EAGOLDAccumulatedProfit();
         double cycleRealized=(g_excursionActive?realizedTotal-g_excursionStartRealized:0.0);
         capitalAvailable=MathMax(0.0,cycleRealized);
         capitalCapacity=(capitalAvailable>0.0?capitalAvailable/lossPerLot:0.0);
         double ratioLots=R10V2ShadowNormalizeLots(targetLots*0.125);
         desired=ratioLots;
         exposureCapacity=MathMax(0.0,DirectionLots(direction)-DirectionLots(direction==OP_BUY?OP_SELL:OP_BUY));
         r11Capacity=desired;
         brokerCapacity=targetLots;
         authorized=MathMin(desired,MathMin(capitalCapacity,MathMin(exposureCapacity,MathMin(r11Capacity,brokerCapacity))));
         authorized=R10V2ShadowNormalizeLots(authorized);
         if(capitalAvailable<=0.0){state="BLOCKED";reason="NO_CAPITAL";}
         else if(exposureCapacity<Lot){state="BLOCKED";reason="NO_EXPOSURE_CAPACITY";}
         else if(authorized<Lot){state="BLOCKED";reason="BROKER_CAPACITY";}
         else{
            state="AUTHORIZED";reason="CAPITAL_FUNDED_POSITION_ADJUSTMENT";
            projectedCapital=authorized*lossPerLot;
            projectedPL=-projectedCapital;
            if(direction==OP_BUY)buyAfter=buy-authorized;else sellAfter=sell-authorized;
            grossAfter=buyAfter+sellAfter;netAfter=MathAbs(buyAfter-sellAfter);
            recoveryBefore=R10V2ShadowRecoveryLoad(direction);
            recoveryAfter=MathMax(0.0,recoveryBefore-(authorized/MathMax(DirectionLots(direction),Lot))*recoveryBefore);
         }
      }
   }

   double grossRelief=gross-grossAfter;
   double netDelta=netAfter-net;
   string cycleId=(g_excursionActive?g_excursionCycleId:"");
   string signature=state+"|"+reason+"|"+IntegerToString(targetTicket)+"|"+DoubleToString(authorized,DigitsLots)+"|"+DoubleToString(gross,DigitsLots)+"|"+DoubleToString(net,DigitsLots);
   if(signature==g_r10v2ShadowLastSignature && phase=="PRE_ACTION")return;
   g_r10v2ShadowLastSignature=signature;

   g_r10v2ShadowSequence++;
   FileWrite(handle,
      IntegerToString((int)g_r10v2ShadowSequence),TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),phase,cycleId,
      R10V2ShadowDirName(direction),objective,policy,IntegerToString(targetTicket),
      DoubleToString(targetLots,DigitsLots),DoubleToString(desired,DigitsLots),
      DoubleToString(capitalAvailable,2),DoubleToString(capitalCapacity,DigitsLots),
      DoubleToString(exposureCapacity,DigitsLots),DoubleToString(r11Capacity,DigitsLots),
      DoubleToString(brokerCapacity,DigitsLots),DoubleToString(authorized,DigitsLots),
      DoubleToString(buy,DigitsLots),DoubleToString(sell,DigitsLots),DoubleToString(gross,DigitsLots),
      DoubleToString(net,DigitsLots),DoubleToString(buyAfter,DigitsLots),DoubleToString(sellAfter,DigitsLots),
      DoubleToString(grossAfter,DigitsLots),DoubleToString(netAfter,DigitsLots),
      DoubleToString(targetPL,2),DoubleToString(lossPerLot,2),DoubleToString(grossRelief,DigitsLots),
      DoubleToString(netDelta,DigitsLots),DoubleToString(recoveryBefore,2),DoubleToString(recoveryAfter,2),
      DoubleToString(MathMax(0.0,recoveryBefore-recoveryAfter),2),DoubleToString(projectedPL,2),
      DoubleToString(projectedCapital,2),state,reason);
   FileFlush(handle);

   if(state=="AUTHORIZED"||state=="CANDIDATE")
      Print(EA_NAME," R10 V2 SHADOW: state=",state," objective=",objective," policy=",policy,
            " target=",targetTicket," desired=",DoubleToString(desired,DigitsLots),
            " capitalCap=",DoubleToString(capitalCapacity,DigitsLots),
            " r11Cap=",DoubleToString(r11Capacity,DigitsLots),
            " authorized=",DoubleToString(authorized,DigitsLots),
            " grossRelief=",DoubleToString(grossRelief,DigitsLots),
            " reason=",reason);
}

void EAGOLD_R10V2ShadowReset(){
   EAGOLD_R10V2ShadowClose();
   g_r10v2ShadowSequence=0;
   g_r10v2ShadowHandle=INVALID_HANDLE;
   g_r10v2ShadowLastSignature="";
}

#endif
