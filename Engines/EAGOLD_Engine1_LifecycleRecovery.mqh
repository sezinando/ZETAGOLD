#ifndef EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_MQH
#define EAGOLD_ENGINE1_LIFECYCLE_RECOVERY_MQH

//==================================================================
// ENGINE 1 — LIFECYCLE & RECOVERY
// Structural consolidation of the v0.106 business modules.
// Behavior intentionally preserved: R1 / R4 / R5 / R7 / Recovery / R10.2 / R11.
// No trading logic redesign.
//==================================================================

//==================================================================
// RECOVERY — R11 / R10.2
// Source responsibility consolidated from EAGOLD_Recovery.mqh.
//==================================================================

double RecoveryStepForLevel(int level){double step=RecoveryMinDistance;if(level<0)level=0;if(EnableRecoveryStepMultiplier&&RecoveryStepMultiplier>1.0){for(int i=0;i<level;i++){step*=RecoveryStepMultiplier;if(RecoveryStepMax>0.0&&step>=RecoveryStepMax){step=RecoveryStepMax;break;}}}if(RecoveryStepMax>0.0&&step>RecoveryStepMax)step=RecoveryStepMax;return(step);}

int RecoveryLevel(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(0);return(count-1);}

double R10RecoveryDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double debt=g_r10RecoveryStartEquity-g_r10RecoveryWorstEquity;if(debt<0.0)debt=0.0;return(debt);}

double R10RecoveryRemainingDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double remaining=g_r10RecoveryStartEquity-AccountEquity();if(remaining<0.0)remaining=0.0;return(remaining);}

double R10RecoverySurplus(){if(!g_r10RecoveryCycleActive)return(0.0);double surplus=AccountEquity()-g_r10RecoveryStartEquity;if(surplus<0.0)surplus=0.0;return(surplus);}

double R10RecoveryTarget(){double debt=R10RecoveryDebt();double target=MathMax(0.0,R10RecoveryProfitTarget);if(R10RecoveryDebtTargetPercent>0.0)target+=debt*(R10RecoveryDebtTargetPercent/100.0);return(target);}

void R10RecoveryStartCycle(){g_r10RecoveryCycleActive=true;g_r10RecoveryStartEquity=AccountEquity();g_r10RecoveryWorstEquity=g_r10RecoveryStartEquity;Print(EA_NAME," R10.2 CYCLE START: equity=",DoubleToString(g_r10RecoveryStartEquity,2));CreateEngineActionMarker("R10.2","CYCLE",HeavyDirection(),0.0);}

void R10RecoveryResetCycle(){if(g_r10RecoveryCycleActive){Print(EA_NAME," R10.2 CYCLE RESET: debt=",DoubleToString(R10RecoveryDebt(),2)," surplus=",DoubleToString(R10RecoverySurplus(),2));CreateEngineActionMarker("R10.2","REALIZE",HeavyDirection(),0.0);}g_r10RecoveryCycleActive=false;g_r10RecoveryStartEquity=0.0;g_r10RecoveryWorstEquity=0.0;}

void R10RecoveryUpdateState(){if(!EnableR10RecoveryRealization)return;double equity=AccountEquity();if(CountEAGOLDOrders()==0){R10RecoveryResetCycle();return;}if(!g_r10RecoveryCycleActive)R10RecoveryStartCycle();if(equity<g_r10RecoveryWorstEquity)g_r10RecoveryWorstEquity=equity;}

bool R10RecoveryAllowBasketClose(int direction){if(!EnableR10RecoveryRealization)return(true);if(!g_r10RecoveryCycleActive)return(true);double debt=R10RecoveryDebt();if(debt<R10RecoveryMinDebt)return(true);double remaining=R10RecoveryRemainingDebt();double surplus=R10RecoverySurplus();double target=R10RecoveryTarget();if(R10RecoveryRequireDebtRepaid&&remaining>0.01){Print(EA_NAME," R10.2 HOLD: debt not repaid. remaining=",DoubleToString(remaining,2)," debt=",DoubleToString(debt,2));return(false);}if(surplus+0.01<target){Print(EA_NAME," R10.2 HOLD: recovery target not reached. surplus=",DoubleToString(surplus,2)," target=",DoubleToString(target,2));return(false);}return(true);}

bool GetLatestActivatedPosition(int direction,double &latestPrice,double &latestLot,int &latestTicket){int type=(direction==OP_BUY?OP_BUY:OP_SELL);latestPrice=0.0;latestLot=NormalizeLot(Lot);latestTicket=-1;datetime latestTime=0;bool found=false;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;datetime t=OrderOpenTime();int ticket=OrderTicket();if(!found||t>latestTime||(t==latestTime&&ticket>latestTicket)){found=true;latestTime=t;latestPrice=OrderOpenPrice();latestLot=OrderLots();latestTicket=ticket;}}return(found);}

bool HasRecoveryPending(int direction){string tag=(direction==OP_BUY?"EAGOLD BUY RECOVERY":"EAGOLD SELL RECOVERY");int type=(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP);for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;if(StringFind(OrderComment(),tag,0)>=0)return(true);}return(false);}

double NextRecoveryLot(double previousLot){if(previousLot<=0.0)return(NormalizeLot(Lot));return(NormalizeLot(previousLot*Multiplier+LotIncrement));}

void BuyRecovery(){if(SmartGrid1<=0.0||RecoveryMinDistance<=0.0)return;if(CountDirectionPositions(OP_BUY)<=0||HasRecoveryPending(OP_BUY))return;double p=0.0,l=Lot;int t=-1;if(!GetLatestActivatedPosition(OP_BUY,p,l,t))return;RefreshRates();if(p-Ask<PointsToPrice(2.0*SmartGrid1))return;int level=RecoveryLevel(OP_BUY)-1;double dynamicStep=RecoveryStepForLevel(level);double stop=NormalizePrice(Ask+PointsToPrice(dynamicStep));if(stop<=Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point)return;Print(EA_NAME," RULE 11 BUY STEP: level=",level," step=",DoubleToString(dynamicStep,1)," multiplier=",DoubleToString(RecoveryStepMultiplier,2));double recoveryLot=NextRecoveryLot(l);int recoveryTicket=SendPending(OP_BUYSTOP,stop,recoveryLot,"EAGOLD BUY RECOVERY");if(recoveryTicket>0){CreateEngineActionMarker("R5","RECOVERY",OP_BUY,recoveryLot);CreateEngineActionMarker("R11","STEP "+DoubleToString(dynamicStep,0),OP_BUY,0.0);}}

void SellRecovery(){if(SmartGrid1<=0.0||RecoveryMinDistance<=0.0)return;if(CountDirectionPositions(OP_SELL)<=0||HasRecoveryPending(OP_SELL))return;double p=0.0,l=Lot;int t=-1;if(!GetLatestActivatedPosition(OP_SELL,p,l,t))return;RefreshRates();if(Bid-p<PointsToPrice(2.0*SmartGrid1))return;int level=RecoveryLevel(OP_SELL)-1;double dynamicStep=RecoveryStepForLevel(level);double stop=NormalizePrice(Bid-PointsToPrice(dynamicStep));if(stop>=Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point)return;Print(EA_NAME," RULE 11 SELL STEP: level=",level," step=",DoubleToString(dynamicStep,1)," multiplier=",DoubleToString(RecoveryStepMultiplier,2));double recoveryLot=NextRecoveryLot(l);int recoveryTicket=SendPending(OP_SELLSTOP,stop,recoveryLot,"EAGOLD SELL RECOVERY");if(recoveryTicket>0){CreateEngineActionMarker("R5","RECOVERY",OP_SELL,recoveryLot);CreateEngineActionMarker("R11","STEP "+DoubleToString(dynamicStep,0),OP_SELL,0.0);}}

//==================================================================
// R1 ADMISSION
// Source responsibility consolidated from EAGOLD_R1_Admission.mqh.
//==================================================================

void R1Decision(string decision,string reason){g_r1LastDecision=decision;g_r1LastReason=reason;g_r1LastDecisionTime=TimeCurrent();if(EnableR1DecisionLog)Print(EA_NAME," R1 ADMISSION: ",decision," reason=",reason);}

bool R1ValidateLot(double lots,string &reason){double minLot=MarketInfo(Symbol(),MODE_MINLOT);double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP);double eps=0.0000001;if(minLot>0.0&&lots<minLot-eps){reason="BROKER_MIN_LOT";return(false);}if(maxLot>0.0&&lots>maxLot+eps){reason="BROKER_MAX_LOT";return(false);}if(lotStep>0.0){double steps=(lots-minLot)/lotStep;double nearest=MathRound(steps);if(MathAbs(steps-nearest)>0.000001){reason="BROKER_LOT_STEP";return(false);}}reason="PASS";return(true);}

bool R1BrokerGuard(int direction,double price,string &reason){double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL);if(stopLevel<0.0)stopLevel=0.0;double requiredDistance=stopLevel+MathMax(0.0,R1BrokerSafetyBufferPoints);RefreshRates();double actualDistance=(direction==OP_BUY?(price-Ask):(Bid-price))/Point;if(actualDistance+0.000001<requiredDistance){reason="BROKER_STOPLEVEL";return(false);}reason="PASS";return(true);}

bool R1TradePermissionGuard(string &reason){double allowed=MarketInfo(Symbol(),MODE_TRADEALLOWED);if(allowed<0.5){reason="TRADE_NOT_ALLOWED";return(false);}reason="PASS";return(true);}

bool R1MarginGuard(int direction,double lots,string &reason){int marketType=(direction==OP_BUY?OP_BUY:OP_SELL);ResetLastError();double remaining=AccountFreeMarginCheck(Symbol(),marketType,lots);int err=GetLastError();if(remaining<=0.0||err==134){reason="INSUFFICIENT_MARGIN";return(false);}if(R1MinFreeMarginAfterOrder>0.0&&remaining<R1MinFreeMarginAfterOrder){reason="MIN_FREE_MARGIN";return(false);}reason="PASS";return(true);}

bool R1AdmissionAllowed(int direction,double lots,double price,string &reason){reason="PASS";if(!EnableR1AdmissionGate){R1Decision("DISABLED","MASTER_OFF");return(true);}string localReason="PASS";if(EnableR1TradePermissionGuard){if(!R1TradePermissionGuard(localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1BrokerGuard){if(!R1BrokerGuard(direction,price,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1LotGuard){if(!R1ValidateLot(lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1MarginGuard){if(!R1MarginGuard(direction,lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}R1Decision("ALLOW","ALL_ENABLED_GATES_PASS");return(true);}

//==================================================================
// LIFECYCLE — R4 / R5 / R7
// Source responsibility consolidated from EAGOLD_Lifecycle.mqh.
//==================================================================

void EnsureDirectionMachineAlive(int direction){if(CountDirectionPositions(direction)>0)return;if(CountDirectionPending(direction)>0)return;RefreshRates();int ticket=-1;if(direction==OP_BUY)ticket=SendPending(OP_BUYSTOP,Ask+PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART BUY");else ticket=SendPending(OP_SELLSTOP,Bid-PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART SELL");if(ticket>0)Print(EA_NAME," KEEP-ALIVE: ",(direction==OP_BUY?"BUY":"SELL")," machine recreated. STOP ticket=",ticket);}

void CreateFirstOrdersIfFlat(){if(CountEAGOLDOrders()==0){RefreshRates();double buyPrice=NormalizePrice(Ask+PointsToPrice(FirstStep));double sellPrice=NormalizePrice(Bid-PointsToPrice(FirstStep));if(EnableR1AdmissionGate){string buyReason="PASS",sellReason="PASS";bool buyAllowed=R1AdmissionAllowed(OP_BUY,Lot,buyPrice,buyReason);bool sellAllowed=R1AdmissionAllowed(OP_SELL,Lot,sellPrice,sellReason);if(!buyAllowed||!sellAllowed){string reason=(!buyAllowed?"BUY_":"SELL_");reason+=(!buyAllowed?buyReason:sellReason);R1Decision("BLOCK",reason);Print(EA_NAME," RULE 1: FIRST cycle blocked atomically. BUY=",buyReason," SELL=",sellReason);CreateEngineActionMarker("R1.1","BLOCK",OP_BUY,Lot);CreateEngineActionMarker("R1.1","BLOCK",OP_SELL,Lot);return;}}int b=SendPending(OP_BUYSTOP,buyPrice,Lot,"EAGOLD R1 FIRST BUY");int s=SendPending(OP_SELLSTOP,sellPrice,Lot,"EAGOLD R1 FIRST SELL");if(b>0||s>0){Print(EA_NAME," RULE 1: initial seeds created. BUY=",b," SELL=",s);CreateEngineActionMarker("R1","SEED",OP_BUY,Lot);CreateEngineActionMarker("R1","SEED",OP_SELL,Lot);}return;}EnsureDirectionMachineAlive(OP_BUY);EnsureDirectionMachineAlive(OP_SELL);}

bool CanCloseLightBasket(int direction){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);if(b==s)return(true);if(direction==OP_BUY&&b<s&&s>0.0)return(false);if(direction==OP_SELL&&s<b&&b>0.0)return(false);return(true);}

bool CloseDirectionPositionsRobust(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);int tickets[];ArrayResize(tickets,0);for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;int n=ArraySize(tickets);ArrayResize(tickets,n+1);tickets[n]=OrderTicket();}bool ok=true;for(int j=0;j<ArraySize(tickets);j++){if(!CloseMarketOrder(tickets[j]))ok=false;}return(ok&&CountDirectionPositions(direction)==0);}

void BuySingleTakeProfit(){if(CountDirectionPositions(OP_BUY)!=1)return;if(!CanCloseLightBasket(OP_BUY))return;if(!R10RecoveryAllowBasketClose(OP_BUY))return;if(DirectionBasketProfit(OP_BUY)<TakeProfit)return;int ticket=-1;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder()&&OrderType()==OP_BUY){ticket=OrderTicket();break;}}if(ticket>0&&CloseMarketOrder(ticket)){CloseAllDirectionPending(OP_BUY);SendPending(OP_BUYSTOP,Ask+PointsToPrice(MiniGrid1),Lot,"EAGOLD R4 BUY NEXT");Print(EA_NAME," RULE 4 BUY TP REENTRY. closed=",ticket);CreateEngineActionMarker("R4","REALIZE",OP_BUY,Lot);}}

void SellSingleTakeProfit(){if(CountDirectionPositions(OP_SELL)!=1)return;if(!CanCloseLightBasket(OP_SELL))return;if(!R10RecoveryAllowBasketClose(OP_SELL))return;if(DirectionBasketProfit(OP_SELL)<TakeProfit)return;int ticket=-1;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder()&&OrderType()==OP_SELL){ticket=OrderTicket();break;}}if(ticket>0&&CloseMarketOrder(ticket)){CloseAllDirectionPending(OP_SELL);SendPending(OP_SELLSTOP,Bid-PointsToPrice(MiniGrid2),Lot,"EAGOLD R4 SELL NEXT");Print(EA_NAME," RULE 4 SELL TP REENTRY. closed=",ticket);CreateEngineActionMarker("R4","REALIZE",OP_SELL,Lot);}}

bool BuyBasketTargetReached(){int count=CountDirectionPositions(OP_BUY);if(count<=1||TakeProfit<=0.0)return(false);return(DirectionBasketProfit(OP_BUY)>=count*TakeProfit);}

bool SellBasketTargetReached(){int count=CountDirectionPositions(OP_SELL);if(count<=1||TakeProfit<=0.0)return(false);return(DirectionBasketProfit(OP_SELL)>=count*TakeProfit);}

bool BuyBasketClose(){int count=CountDirectionPositions(OP_BUY);if(count<=1||TakeProfit<=0.0)return(false);if(!CanCloseLightBasket(OP_BUY))return(false);if(!R10RecoveryAllowBasketClose(OP_BUY))return(false);double target=count*TakeProfit,profit=DirectionBasketProfit(OP_BUY);if(profit<target)return(false);Print(EA_NAME," RULE 5 BUY TARGET. count=",count," profit=",DoubleToString(profit,2)," target=",DoubleToString(target,2));bool closed=CloseDirectionPositionsRobust(OP_BUY);if(closed){CloseAllDirectionPending(OP_BUY);Print(EA_NAME," RULE 5 BUY CLOSED ALL. count=",count);CreateEngineActionMarker("R5","BALANCE",OP_BUY,DirectionLots(OP_BUY));return(true);}Print(EA_NAME," RULE 5 BUY PARTIAL/FAILED. remaining=",CountDirectionPositions(OP_BUY));return(false);}

bool SellBasketClose(){int count=CountDirectionPositions(OP_SELL);if(count<=1||TakeProfit<=0.0)return(false);if(!CanCloseLightBasket(OP_SELL))return(false);if(!R10RecoveryAllowBasketClose(OP_SELL))return(false);double target=count*TakeProfit,profit=DirectionBasketProfit(OP_SELL);if(profit<target)return(false);Print(EA_NAME," RULE 5 SELL TARGET. count=",count," profit=",DoubleToString(profit,2)," target=",DoubleToString(target,2));bool closed=CloseDirectionPositionsRobust(OP_SELL);if(closed){CloseAllDirectionPending(OP_SELL);Print(EA_NAME," RULE 5 SELL CLOSED ALL. count=",count);CreateEngineActionMarker("R5","BALANCE",OP_SELL,DirectionLots(OP_SELL));return(true);}Print(EA_NAME," RULE 5 SELL PARTIAL/FAILED. remaining=",CountDirectionPositions(OP_SELL));return(false);}

void TrailAllStopOrders(){if(PendingStepTrail<=0.0)return;double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)continue;string c=OrderComment();double resetPoints=0.0,triggerPoints=PendingStepTrail;string family="GLOBAL";if(StringFind(c,"EAGOLD R1 FIRST",0)>=0){resetPoints=FirstStep;triggerPoints=FirstStep+PendingStepTrail;family="R1 FIRST";}else if(StringFind(c,"EAGOLD BUY RECOVERY",0)>=0||StringFind(c,"EAGOLD SELL RECOVERY",0)>=0){resetPoints=RecoveryMinDistance;family="RECOVERY";}else if(StringFind(c,"EAGOLD R4 BUY NEXT",0)>=0){resetPoints=MiniGrid1;family="R4 BUY";}else if(StringFind(c,"EAGOLD R4 SELL NEXT",0)>=0){resetPoints=MiniGrid2;family="R4 SELL";}else if(StringFind(c,"EAGOLD R7 RESTART",0)>=0){resetPoints=BasketRestartStep;family="R7 RESTART";}else{double marketDistance=(type==OP_BUYSTOP?OrderOpenPrice()-Ask:Bid-OrderOpenPrice());if(marketDistance<=0.0)continue;resetPoints=marketDistance/Point;family="GLOBAL UNKNOWN";}if(resetPoints<=0.0||triggerPoints<=0.0)continue;double trigger=PointsToPrice(triggerPoints),resetDistance=PointsToPrice(resetPoints);RefreshRates();double current=OrderOpenPrice(),desired=current,adverseDistance=0.0;int ticket=OrderTicket();if(type==OP_BUYSTOP){adverseDistance=current-Ask;if(adverseDistance<trigger)continue;desired=NormalizePrice(Ask+resetDistance);if(desired>=current||desired<=Ask+stopLevel)continue;}else{adverseDistance=Bid-current;if(adverseDistance<trigger)continue;desired=NormalizePrice(Bid-resetDistance);if(desired<=current||desired>=Bid-stopLevel)continue;}ResetLastError();if(!OrderModify(ticket,desired,0,0,0,clrNONE))Print(EA_NAME," GLOBAL STOP TRAIL FAILED ticket=",ticket," family=",family," error=",GetLastError());else Print(EA_NAME," GLOBAL STOP TRAIL ticket=",ticket," family=",family," old=",DoubleToString(current,Digits)," new=",DoubleToString(desired,Digits)," adverse=",DoubleToString(adverseDistance/Point,1)," trigger=",DoubleToString(triggerPoints,1)," reset=",DoubleToString(resetPoints,1));}}

void RestartEmptyBasket(int direction){if(BasketRestartStep<=0.0)return;if(CountDirectionPositions(direction)!=0||CountDirectionPending(direction)!=0)return;RefreshRates();if(direction==OP_BUY){int r7ticket=SendPending(OP_BUYSTOP,Ask+PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART BUY");if(r7ticket>0)CreateEngineActionMarker("R7","RESTART",OP_BUY,Lot);}else{int r7ticket=SendPending(OP_SELLSTOP,Bid-PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART SELL");if(r7ticket>0)CreateEngineActionMarker("R7","RESTART",OP_SELL,Lot);}}

void BuyMachine(){if(BuyBasketTargetReached()&&DirectionLots(OP_BUY)>DirectionLots(OP_SELL))Rule10Reduce(OP_BUY);bool basketClosed=BuyBasketClose();if(basketClosed)RestartEmptyBasket(OP_BUY);BuySingleTakeProfit();BuyRecovery();}

void SellMachine(){if(SellBasketTargetReached()&&DirectionLots(OP_SELL)>DirectionLots(OP_BUY))Rule10Reduce(OP_SELL);bool basketClosed=SellBasketClose();if(basketClosed)RestartEmptyBasket(OP_SELL);SellSingleTakeProfit();SellRecovery();}

#endif
