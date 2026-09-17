#ifndef EAGOLD_ORDERS_MQH
#define EAGOLD_ORDERS_MQH

// EAGOLD order recognition supports explicit Magic and PAR/Symbol modes.

bool IsR13Order(){
   if(OrderSymbol()!=Symbol())return(false);
   return(OrderMagicNumber()==R13MagicNumber);
}

bool IsR13OwnershipConfigurationValid(){
   if(R13MagicNumber<=0)return(false);
   if(MagicNumber<=0)return(false);
   if(R13MagicNumber==MagicNumber)return(false);
   return(true);
}

int CountLegacyMagicOrders(){
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=Symbol())continue;
      if(OrderMagicNumber()==-1)count++;
   }
   return(count);
}

bool EAGOLDAllSymbolRecognitionAllowed(){return(EnableLegacyReattach);}

bool EAGOLDValidateOwnershipConfiguration(){
   if(MagicNumber<=0)return(false);
   if(R13MagicNumber<=0)return(false);
   if(MagicNumber==R13MagicNumber)return(false);
   if(RequireCleanLegacyOwnership){
      int legacy=CountLegacyMagicOrders();
      if(legacy>0)return(false);
   }
   return(true);
}

bool IsEAGOLDOrder(){
   if(OrderSymbol()!=Symbol())return(false);
   if(OrderMagicNumber()==R13MagicNumber)return(false);
   if(MagicNumber<=0)return(false);
   if(EAGOLDAllSymbolRecognitionAllowed())return(true);
   return(OrderMagicNumber()==MagicNumber);
}

int CountOrdersByType(int type){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;if(OrderType()==type)count++;}return(count);}
int CountDirectionPositions(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUY:OP_SELL));}
int CountDirectionPending(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP));}
int CountEAGOLDOrders(){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder())count++;}return(count);}
double DirectionBasketProfit(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}
double DirectionLots(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderLots();}return(total);}
double ExposureLots(){return(MathAbs(DirectionLots(OP_BUY)-DirectionLots(OP_SELL)));}
int HeavyDirection(){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);if(b>s)return(OP_BUY);if(s>b)return(OP_SELL);return(-1);}
double EAGOLDAccumulatedProfit(){double total=0.0;for(int i=OrdersHistoryTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type==OP_BUY||type==OP_SELL)total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}
double EAGOLDTodayProfit(){double total=0.0;datetime dayStart=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));datetime now=TimeCurrent();for(int i=OrdersHistoryTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)continue;datetime closeTime=OrderCloseTime();if(closeTime<dayStart||closeTime>now)continue;total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}

#endif
