#ifndef EAGOLD_DIRECTION_CONTROL_MQH
#define EAGOLD_DIRECTION_CONTROL_MQH
bool EAGOLD_ManualDirectionFilterEnabled(){return(TradeDirectionMode==EAGOLD_DIRECTION_ONLY_BUY||TradeDirectionMode==EAGOLD_DIRECTION_ONLY_SELL);}
int EAGOLD_SelectedDirection(){if(TradeDirectionMode==EAGOLD_DIRECTION_ONLY_BUY)return(OP_BUY);if(TradeDirectionMode==EAGOLD_DIRECTION_ONLY_SELL)return(OP_SELL);return(-1);}
bool EAGOLD_EntryDirectionAllowed(int direction){if(direction!=OP_BUY&&direction!=OP_SELL)return(false);if(TradeDirectionMode==EAGOLD_DIRECTION_BOTH)return(true);return(EAGOLD_SelectedDirection()==direction);}
bool EAGOLD_EconomicCreationAllowed(int direction){return(EAGOLD_EntryDirectionAllowed(direction));}
string EAGOLD_DirectionName(int direction){if(direction==OP_BUY)return("BUY");if(direction==OP_SELL)return("SELL");return("WAIT");}
string EAGOLD_OperationalDirectionName(){if(TradeDirectionMode==EAGOLD_DIRECTION_ONLY_BUY)return("BUY ONLY");if(TradeDirectionMode==EAGOLD_DIRECTION_ONLY_SELL)return("SELL ONLY");return("BOTH");}
#endif
