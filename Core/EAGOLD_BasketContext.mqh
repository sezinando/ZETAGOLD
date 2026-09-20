#ifndef EAGOLD_BASKET_CONTEXT_MQH
#define EAGOLD_BASKET_CONTEXT_MQH

// BASKET CONTEXT — architectural foundation
//
// A basket is an economic unit identified independently from direction.
// The current master architecture still uses one MagicNumber, so this layer
// deliberately starts with an explicit broker-visible basket tag in the order
// comment. It does NOT change lifecycle, recovery, BRX, R9 or R11 semantics yet.
//
// Tag format: [B1], [B2], ...
// The tag is intentionally short because MT4 order comments have a limited
// broker-visible length.

struct EAGOLD_BasketContext
{
   int      basketId;
   int      direction;
   bool     active;
   int      positionCount;
   int      pendingCount;
   double   lots;
   double   profit;
   double   weightedPrice;
   double   lastEntryPrice;
   datetime createdAt;
};

string EAGOLD_BasketTag(int basketId)
{
   if(basketId<=0)return("");
   return("[B"+IntegerToString(basketId)+"]");
}

string EAGOLD_CommentWithBasket(string comment,int basketId)
{
   string tag=EAGOLD_BasketTag(basketId);
   if(tag=="")return(comment);
   if(StringFind(comment,tag,0)>=0)return(comment);
   return(comment+" "+tag);
}

int EAGOLD_OrderBasketId()
{
   string c=OrderComment();
   int p=StringFind(c,"[B",0);
   if(p<0)return(0);

   int start=p+2;
   int end=StringFind(c,"]",start);
   if(end<=start)return(0);

   string value=StringSubstr(c,start,end-start);
   int id=(int)StringToInteger(value);
   if(id<1)return(0);
   return(id);
}

bool EAGOLD_IsBasketOrder(int basketId)
{
   if(basketId<=0)return(false);
   if(!IsEAGOLDOrder())return(false);
   return(EAGOLD_OrderBasketId()==basketId);
}

void EAGOLD_BasketContextReset(EAGOLD_BasketContext &c,int basketId)
{
   c.basketId=basketId;
   c.direction=-1;
   c.active=false;
   c.positionCount=0;
   c.pendingCount=0;
   c.lots=0.0;
   c.profit=0.0;
   c.weightedPrice=0.0;
   c.lastEntryPrice=0.0;
   c.createdAt=0;
}

void EAGOLD_BasketContextBuild(int basketId,EAGOLD_BasketContext &c)
{
   EAGOLD_BasketContextReset(c,basketId);

   double weightedSum=0.0;
   datetime latest=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(!EAGOLD_IsBasketOrder(basketId))
         continue;

      int type=OrderType();

      if(type==OP_BUY || type==OP_SELL)
      {
         c.active=true;
         c.positionCount++;
         c.lots+=OrderLots();
         c.profit+=OrderProfit()+OrderSwap()+OrderCommission();
         weightedSum+=OrderOpenPrice()*OrderLots();

         if(type==OP_BUY)c.direction=OP_BUY;
         else if(type==OP_SELL)c.direction=OP_SELL;

         if(OrderOpenTime()>=latest)
         {
            latest=OrderOpenTime();
            c.lastEntryPrice=OrderOpenPrice();
            c.createdAt=OrderOpenTime();
         }
      }
      else if(type==OP_BUYSTOP || type==OP_SELLSTOP)
      {
         c.pendingCount++;
         if(c.direction<0)
            c.direction=(type==OP_BUYSTOP?OP_BUY:OP_SELL);
      }
   }

   if(c.lots>0.0)
      c.weightedPrice=weightedSum/c.lots;
}

int EAGOLD_BasketCount(int basketId)
{
   EAGOLD_BasketContext c;
   EAGOLD_BasketContextBuild(basketId,c);
   return(c.positionCount+c.pendingCount);
}

bool EAGOLD_BasketIsFlat(int basketId)
{
   return(EAGOLD_BasketCount(basketId)==0);
}

int EAGOLD_BasketSendPending(int basketId,int type,double price,double lots,string comment)
{
   if(basketId<=0)return(-1);
   return(SendPending(type,price,lots,EAGOLD_CommentWithBasket(comment,basketId)));
}

void EAGOLD_BasketContextLog(string prefix,const EAGOLD_BasketContext &c)
{
   Print(EA_NAME," BASKET CONTEXT ",prefix,
         " id=",c.basketId,
         " direction=",(c.direction==OP_BUY?"BUY":(c.direction==OP_SELL?"SELL":"FLAT")),
         " active=",c.active,
         " positions=",c.positionCount,
         " pending=",c.pendingCount,
         " lots=",DoubleToString(c.lots,DigitsLots),
         " profit=",DoubleToString(c.profit,2),
         " weightedBE=",DoubleToString(c.weightedPrice,Digits),
         " lastEntry=",DoubleToString(c.lastEntryPrice,Digits));
}

#endif
