#ifndef EAGOLD_TRADING_GUARDS_MQH
#define EAGOLD_TRADING_GUARDS_MQH

bool g_eagoldEntrySuspendedThisTick=false;
void EAGOLD_ResetEntrySuspension(){g_eagoldEntrySuspendedThisTick=false;}
bool EAGOLD_EntrySuspendedThisTick(){return(g_eagoldEntrySuspendedThisTick);}
bool EAGOLD_TradingWindowOpen(){if(!EnableTradingTimeWindow)return(true);int start=(TradeStartHour*60)+TradeStartMinute,end=(TradeEndHour*60)+TradeEndMinute,now=(TimeHour(TimeCurrent())*60)+TimeMinute(TimeCurrent());if(start==end)return(true);if(start<end)return(now>=start&&now<end);return(now>=start||now<end);}
bool EAGOLD_SpreadAllowed(){if(SpreadLimit<=0)return(true);RefreshRates();double spreadPoints=(Ask-Bid)/Point;if(spreadPoints<=SpreadLimit)return(true);Print(EA_NAME," ENTRY BLOCKED: spread=",DoubleToString(spreadPoints,1)," points > SpreadLimit=",IntegerToString(SpreadLimit));return(false);}
bool EAGOLD_NewOrderAdmissionAllowed(){if(EAGOLD_EntrySuspendedThisTick())return(false);if(!EAGOLD_TradingAllowed())return(false);if(!EAGOLD_TradingWindowOpen())return(false);return(EAGOLD_SpreadAllowed());}
int EAGOLD_SuspendInvalidPendingEntries(){EAGOLD_ResetEntrySuspension();bool windowOpen=EAGOLD_TradingWindowOpen(),spreadOpen=EAGOLD_SpreadAllowed();if(windowOpen&&spreadOpen)return(0);g_eagoldEntrySuspendedThisTick=true;int deleted=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)continue;int ticket=OrderTicket();ResetLastError();if(OrderDelete(ticket)){deleted++;Print(EA_NAME," ENTRY SUSPENDED: pending ticket=",ticket," removed because entry conditions are closed.");}else Print(EA_NAME," ENTRY SUSPEND FAILED: pending ticket=",ticket," error=",GetLastError());}return(deleted);}

#endif
