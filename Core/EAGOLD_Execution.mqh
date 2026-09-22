#ifndef EAGOLD_EXECUTION_MQH
#define EAGOLD_EXECUTION_MQH

// v0.116 Golden Reference parity.
// Core execution owns broker primitives and the explicit R7 restart authorization.
// Economic orchestration remains in Engines / EA.

// Restart authority:
// R7 is the ONLY authority permitted to submit an EAGOLD R7 RESTART pending.
bool g_eagoldR7RestartAuthorized=false;

void EAGOLD_R7BeginRestartAuthorization(){g_eagoldR7RestartAuthorized=true;}
void EAGOLD_R7EndRestartAuthorization(){g_eagoldR7RestartAuthorized=false;}

#define EAGOLD_MAX_ORDER_COMMENT_LENGTH 31
string EAGOLD_CompactOrderComment(string technicalComment,int orderType=-1)
{
   string c=technicalComment;
   int dir=-1;
   if(StringFind(c,"BUY",0)>=0)dir=OP_BUY; else if(StringFind(c,"SELL",0)>=0)dir=OP_SELL;
   if(dir<0&&(orderType==OP_BUY||orderType==OP_SELL))dir=orderType;

   // Match the most specific engine tag first. This avoids R10/R11/R13
   // being misclassified as R1 because "R1" is a substring of those tags.
   if(StringFind(c,"R13",0)>=0)return("R13 "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"ACT")));
   if(StringFind(c,"R11",0)>=0)return("R11 "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"ACT")));
   if(StringFind(c,"R10",0)>=0)return("R10 RED");
   if(StringFind(c,"R9",0)>=0)return("R9 HEDGE");
   if(StringFind(c,"R7",0)>=0)return("R7 "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"RESTART")));
   if(StringFind(c,"R4",0)>=0)return("R4 "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"NEXT")));
   if(StringFind(c,"R1",0)>=0)return("R1 "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"SEED")));
   if(StringFind(c,"BRX",0)>=0)return("BRX");
   if(StringFind(c,"RECOVERY",0)>=0)return("REC "+(dir==OP_BUY?"BUY":(dir==OP_SELL?"SELL":"ACT")));
   return(c);
}
string EAGOLD_BuildOrderComment(string technicalComment,int orderType=-1)
{
   string prefix=StrategyComment;
   string compact=EAGOLD_CompactOrderComment(technicalComment,orderType);
   if(StringLen(prefix)<=0)return(compact);
   int total=StringLen(prefix)+3+StringLen(compact);
   if(total>EAGOLD_MAX_ORDER_COMMENT_LENGTH)
   {
      Print(EA_NAME," ORDER COMMENT: prefix exceeds MT4 31-char budget; preserving prefix only. prefix=",prefix);
      return(prefix);
   }
   return(prefix+" | "+compact);
}
int SendPending(int type,double price,double lots,string comment)
{
   if(!EAGOLD_NewOrderAdmissionAllowed())return(-1);

   bool isR7Restart=(StringFind(comment,"EAGOLD R7 RESTART",0)>=0);
   if(isR7Restart)
   {
      if(!g_eagoldR7RestartAuthorized)
      {
         Print(EA_NAME," R7 RESTART BLOCKED: unauthorized restart authority. Only transactional R7 may submit restart entries.");
         return(-1);
      }
      if(!EAGOLD_EconomicExecutionAllowed())
      {
         Print(EA_NAME," R7 RESTART BLOCKED: current tick already consumed by another economic action. The transactional R7 authority will evaluate on the next tick.");
         return(-1);
      }
   }

   RefreshRates();
   double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;
   price=NormalizePrice(price);
   lots=NormalizeLot(lots);
   if(type==OP_BUYSTOP&&price<=Ask+stopLevel)return(-1);
   if(type==OP_SELLSTOP&&price>=Bid-stopLevel)return(-1);
   ResetLastError();
   string finalComment=EAGOLD_BuildOrderComment(comment,type);
   int ticket=OrderSend(Symbol(),type,lots,price,0,0,0,finalComment,MagicNumber,0,clrNONE);
   if(ticket<0)Print(EA_NAME," OrderSend failed. type=",type," error=",GetLastError()," comment=",comment);
   else Print(EA_NAME," pending created. ticket=",ticket," type=",type," price=",DoubleToString(price,Digits)," lot=",DoubleToString(lots,DigitsLots)," comment=",comment);
   return(ticket);
}

int SendMarket(int type,double lots,string comment)
{
   if(!EAGOLD_NewOrderAdmissionAllowed())return(-1);
   RefreshRates();
   lots=NormalizeLot(lots);
   double price=(type==OP_BUY?Ask:Bid);
   ResetLastError();
   string finalComment=EAGOLD_BuildOrderComment(comment);
   int ticket=OrderSend(Symbol(),type,lots,NormalizePrice(price),0,0,0,finalComment,MagicNumber,0,clrNONE);
   if(ticket<0)Print(EA_NAME," market send failed. type=",type," error=",GetLastError()," comment=",comment);
   else Print(EA_NAME," market created. ticket=",ticket," type=",type," lot=",DoubleToString(lots,DigitsLots)," comment=",comment);
   return(ticket);
}

// Generic reserved-Magic market entry. R13 is outside the Master ownership set.
int SendMarketByMagic(int type,double lots,string comment,int magic)
{
   if(!EAGOLD_NewOrderAdmissionAllowed())return(-1);
   if(magic<0){Print(EA_NAME," market send blocked: invalid magic.");return(-1);}
   if(type!=OP_BUY&&type!=OP_SELL)return(-1);
   RefreshRates();
   lots=NormalizeLot(lots);
   if(lots<Lot)return(-1);
   double price=(type==OP_BUY?Ask:Bid);
   ResetLastError();
   string finalComment=EAGOLD_BuildOrderComment(comment);
   int ticket=OrderSend(Symbol(),type,lots,NormalizePrice(price),0,0,0,finalComment,magic,0,clrNONE);
   if(ticket<0)Print(EA_NAME," market send failed. type=",type," magic=",magic," error=",GetLastError()," comment=",comment);
   else Print(EA_NAME," market created. ticket=",ticket," type=",type," lot=",DoubleToString(lots,DigitsLots)," magic=",magic," comment=",comment);
   return(ticket);
}

// Generic reserved-Magic close. Used by R13 without crossing Master ownership.
bool CloseMarketOrderByMagic(int ticket,int magic,double &realized)
{
   realized=0.0;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=magic)return(false);
   int type=OrderType();
   if(type!=OP_BUY&&type!=OP_SELL)return(false);
   double lots=OrderLots();
   RefreshRates();
   double price=(type==OP_BUY?Bid:Ask);
   ResetLastError();
   if(!OrderClose(ticket,lots,NormalizePrice(price),0,clrNONE))
   {
      Print(EA_NAME," market close failed. ticket=",ticket," magic=",magic," error=",GetLastError());
      return(false);
   }
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))realized=OrderProfit()+OrderSwap()+OrderCommission();
   return(true);
}

bool CloseMarketOrder(int ticket)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(!IsEAGOLDOrder())return(false);
   int type=OrderType();
   if(type!=OP_BUY&&type!=OP_SELL)return(false);
   RefreshRates();
   double price=(type==OP_BUY?Bid:Ask);
   ResetLastError();
   if(!OrderClose(ticket,OrderLots(),NormalizePrice(price),0,clrNONE))
   {
      Print(EA_NAME," market close failed. ticket=",ticket," error=",GetLastError());
      return(false);
   }
   return(true);
}

bool CloseMarketOrderLots(int ticket,double lots,double &realized)
{
   realized=0.0;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(!IsEAGOLDOrder())return(false);
   int type=OrderType();
   if(type!=OP_BUY&&type!=OP_SELL)return(false);
   double available=OrderLots();
   double closeLots=NormalizeDouble(MathMin(lots,available),DigitsLots);
   if(closeLots<Lot)return(false);
   RefreshRates();
   double price=(type==OP_BUY?Bid:Ask);
   ResetLastError();
   if(!OrderClose(ticket,closeLots,NormalizePrice(price),0,clrNONE))
   {
      Print(EA_NAME," partial close failed. ticket=",ticket," lots=",DoubleToString(closeLots,DigitsLots)," error=",GetLastError());
      return(false);
   }
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))realized=OrderProfit()+OrderSwap()+OrderCommission();
   return(true);
}

bool DeletePendingOrder(int ticket)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(!IsEAGOLDOrder())return(false);
   int type=OrderType();
   if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)return(false);
   ResetLastError();
   if(!OrderDelete(ticket))
   {
      Print(EA_NAME," pending delete failed. ticket=",ticket," error=",GetLastError());
      return(false);
   }
   return(true);
}

bool CloseAllDirectionPending(int direction)
{
   int type=(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP);
   bool allDeleted=true;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      if(!DeletePendingOrder(OrderTicket()))allDeleted=false;
   }
   if(CountDirectionPending(direction)>0)allDeleted=false;
   return(allDeleted);
}

#endif
