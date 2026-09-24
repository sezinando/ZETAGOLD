#ifndef EAGOLD_NEWS_RISK_MQH
#define EAGOLD_NEWS_RISK_MQH

// News Risk Gate:
// T-30: block NEW orders; existing basket continues.
// T-5: RED -> FLAT.
// T..T+20: remain FLAT / blocked.
// T+20: normal admission resumes.
// Schedule times are MT4 server time.

struct EAGOLD_NewsEvent
{
   datetime eventTime;
   string currency;
   string impact;
   string title;
};

EAGOLD_NewsEvent g_eagoldNewsEvents[32];
int g_eagoldNewsEventCount=0;
datetime g_eagoldNewsLastRefresh=0;
datetime g_eagoldNewsFlatHandledEvent=0;
int g_eagoldNewsActiveIndex=-1;
int g_eagoldNewsLastState=-1;

#define EAGOLD_NEWS_STATE_NORMAL 0
#define EAGOLD_NEWS_STATE_PRE    1
#define EAGOLD_NEWS_STATE_FLAT   2

string EAGOLD_NewsTrim(string value){StringTrimLeft(value);StringTrimRight(value);return(value);}

void EAGOLD_NewsResetEvents(){g_eagoldNewsEventCount=0;g_eagoldNewsActiveIndex=-1;}

bool EAGOLD_NewsAddEvent(string dateTime,string currency,string impact,string title)
{
   if(g_eagoldNewsEventCount>=ArraySize(g_eagoldNewsEvents))return(false);
   datetime t=StringToTime(EAGOLD_NewsTrim(dateTime));
   if(t<=0)return(false);
   EAGOLD_NewsEvent e;
   e.eventTime=t;e.currency=EAGOLD_NewsTrim(currency);
   e.impact=EAGOLD_NewsTrim(impact);e.title=EAGOLD_NewsTrim(title);
   g_eagoldNewsEvents[g_eagoldNewsEventCount]=e;
   g_eagoldNewsEventCount++;
   return(true);
}

bool EAGOLD_NewsParseLine(string line)
{
   line=EAGOLD_NewsTrim(line);
   if(StringLen(line)<=0)return(false);
   if(StringGetCharacter(line,0)=='#')return(false);

   int p1=StringFind(line,"|",0);
   if(p1<0)return(EAGOLD_NewsAddEvent(line,"","",""));
   string dateTime=StringSubstr(line,0,p1);
   string rest=StringSubstr(line,p1+1);
   int p2=StringFind(rest,"|",0);
   if(p2<0)return(EAGOLD_NewsAddEvent(dateTime,rest,"",""));
   string currency=StringSubstr(rest,0,p2);
   string rest2=StringSubstr(rest,p2+1);
   int p3=StringFind(rest2,"|",0);
   if(p3<0)return(EAGOLD_NewsAddEvent(dateTime,currency,rest2,""));
   return(EAGOLD_NewsAddEvent(dateTime,currency,StringSubstr(rest2,0,p3),StringSubstr(rest2,p3+1)));
}

void EAGOLD_NewsLoadInputSchedule()
{
   int start=0;
   while(start<StringLen(NewsSchedule)&&g_eagoldNewsEventCount<ArraySize(g_eagoldNewsEvents))
   {
      int sep=StringFind(NewsSchedule,";",start);
      string item;
      if(sep<0){item=StringSubstr(NewsSchedule,start);start=StringLen(NewsSchedule);}
      else{item=StringSubstr(NewsSchedule,start,sep-start);start=sep+1;}
      EAGOLD_NewsParseLine(item);
   }
}

void EAGOLD_NewsLoadFileSchedule()
{
   if(!NewsFileEnabled||StringLen(NewsCommandFile)<=0)return;
   ResetLastError();
   int h=FileOpen(NewsCommandFile,FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)return;
   while(!FileIsEnding(h)&&g_eagoldNewsEventCount<ArraySize(g_eagoldNewsEvents))
   {
      string line=EAGOLD_NewsTrim(FileReadString(h));
      if(StringLen(line)>0&&line!="CLEAR")EAGOLD_NewsParseLine(line);
   }
   FileClose(h);
}

void EAGOLD_NewsRefresh()
{
   if(!EnableNewsFilter){EAGOLD_NewsResetEvents();return;}
   datetime now=TimeCurrent();
   int seconds=MathMax(1,NewsFileRefreshSeconds);
   if(g_eagoldNewsLastRefresh>0&&(now-g_eagoldNewsLastRefresh)<seconds)return;
   g_eagoldNewsLastRefresh=now;
   EAGOLD_NewsResetEvents();
   EAGOLD_NewsLoadFileSchedule();
   if(g_eagoldNewsEventCount==0)EAGOLD_NewsLoadInputSchedule();
}

int EAGOLD_NewsStateAt(datetime now,int &eventIndex)
{
   eventIndex=-1;
   if(!EnableNewsFilter||g_eagoldNewsEventCount<=0)return(EAGOLD_NEWS_STATE_NORMAL);

   int flatIndex=-1,preIndex=-1;
   datetime flatTime=0,preTime=0;
   for(int i=0;i<g_eagoldNewsEventCount;i++)
   {
      datetime t=g_eagoldNewsEvents[i].eventTime;
      datetime preStart=t-NewsPreBlockMinutes*60;
      datetime flatStart=t-NewsFlatMinutesBefore*60;
      datetime postEnd=t+NewsPostBlockMinutes*60;

      if(now>=flatStart&&now<postEnd)
      {
         if(flatIndex<0||t<flatTime){flatIndex=i;flatTime=t;}
      }
      else if(now>=preStart&&now<flatStart)
      {
         if(preIndex<0||t<preTime){preIndex=i;preTime=t;}
      }
   }
   if(flatIndex>=0){eventIndex=flatIndex;return(EAGOLD_NEWS_STATE_FLAT);}
   if(preIndex>=0){eventIndex=preIndex;return(EAGOLD_NEWS_STATE_PRE);}
   return(EAGOLD_NEWS_STATE_NORMAL);
}

int EAGOLD_NewsCurrentState(int &eventIndex){EAGOLD_NewsRefresh();return(EAGOLD_NewsStateAt(TimeCurrent(),eventIndex));}

bool EAGOLD_NewsNewOrderAllowed()
{
   int idx=-1;int state=EAGOLD_NewsCurrentState(idx);
   if(state==EAGOLD_NEWS_STATE_NORMAL)return(true);
   if(state!=g_eagoldNewsLastState||idx!=g_eagoldNewsActiveIndex)
   {
      g_eagoldNewsLastState=state;g_eagoldNewsActiveIndex=idx;
      if(idx>=0)Print(EA_NAME," NEWS GATE ",
         (state==EAGOLD_NEWS_STATE_PRE?"PRE":"FLAT"),
         " event=",TimeToString(g_eagoldNewsEvents[idx].eventTime,TIME_DATE|TIME_MINUTES),
         " currency=",g_eagoldNewsEvents[idx].currency,
         " impact=",g_eagoldNewsEvents[idx].impact,
         " title=",g_eagoldNewsEvents[idx].title);
   }
   return(false);
}

// Forward declarations for EAGOLD_Execution.mqh.
bool CloseMarketOrder(int ticket);
bool DeletePendingOrder(int ticket);
bool CloseMarketOrderByMagic(int ticket,int magic,double &realized);

bool EAGOLD_NewsForceFlat()
{
   int idx=-1;int state=EAGOLD_NewsCurrentState(idx);
   if(state!=EAGOLD_NEWS_STATE_FLAT||idx<0)return(false);
   datetime eventTime=g_eagoldNewsEvents[idx].eventTime;
   if(g_eagoldNewsFlatHandledEvent==eventTime)return(true);

   bool ok=true;int closed=0,deleted=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(IsEAGOLDOrder())
      {
         int type=OrderType();int ticket=OrderTicket();
         if(type==OP_BUY||type==OP_SELL){if(CloseMarketOrder(ticket))closed++;else ok=false;}
         else if(type==OP_BUYSTOP||type==OP_SELLSTOP){if(DeletePendingOrder(ticket))deleted++;else ok=false;}
      }
      else if(NewsFlatCloseR13&&IsR13Order()&&(OrderType()==OP_BUY||OrderType()==OP_SELL))
      {
         int ticketR13=OrderTicket();double realized=0.0;
         if(CloseMarketOrderByMagic(ticketR13,R13MagicNumber,realized))closed++;else ok=false;
      }
   }
   if(ok)
   {
      g_eagoldNewsFlatHandledEvent=eventTime;
      Print(EA_NAME," NEWS RED -> FLAT event=",TimeToString(eventTime,TIME_DATE|TIME_MINUTES),
            " closed=",closed," pending_deleted=",deleted);
   }
   else Print(EA_NAME," NEWS RED -> FLAT incomplete; retrying.");
   return(true);
}

#endif
