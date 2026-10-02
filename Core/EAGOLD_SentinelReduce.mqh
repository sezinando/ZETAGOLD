#ifndef EAGOLD_SENTINEL_REDUCE_MQH
#define EAGOLD_SENTINEL_REDUCE_MQH

// ============================================================================
// ZETAGOLD <-> SENTINEL_CESTA REDUCE BRIDGE
//
// O SENTINEL_CESTA publica somente a selecao:
//   SENTINEL_SELECTED_<SYMBOL>_<MAGIC>_1..3
// ou, quando o CESTA usa Magic=-1:
//   SENTINEL_SELECTED_<SYMBOL>_-1_1..3
//
// O painel ZETAGOLD e o executor desta operacao.
// Nenhum recurso de BUY/SELL/HED/CLOSE ALL do SENTINEL e importado.
// ============================================================================

#define EAGOLD_SENTINEL_REDUCE_BUTTON "EAGOLD_SENTINEL_REDUCE_BTN"
#define EAGOLD_SENTINEL_REDUCE_T1     "EAGOLD_SENTINEL_REDUCE_T1"
#define EAGOLD_SENTINEL_REDUCE_T2     "EAGOLD_SENTINEL_REDUCE_T2"
#define EAGOLD_SENTINEL_REDUCE_T3     "EAGOLD_SENTINEL_REDUCE_T3"
#define EAGOLD_SENTINEL_REDUCE_INFO   "EAGOLD_SENTINEL_REDUCE_INFO"

bool   g_sentinelReduceProcessing=false;
string g_sentinelReduceStatus="";

string EAGOLD_SentinelReduceSelectedName(int slot)
{
   return "SENTINEL_SELECTED_"+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+IntegerToString(slot);
}

string EAGOLD_SentinelReduceGenericName(int slot)
{
   return "SENTINEL_SELECTED_"+Symbol()+"_-1_"+IntegerToString(slot);
}

string EAGOLD_SentinelReduceActionName()
{
   return "SENTINEL_SELECTED_ACTION_"+Symbol()+"_"+IntegerToString(MagicNumber);
}

string EAGOLD_SentinelReduceGenericActionName()
{
   return "SENTINEL_SELECTED_ACTION_"+Symbol()+"_-1";
}

int EAGOLD_SentinelReduceGetTicket(int slot)
{
   if(slot<1 || slot>3)
      return(-1);

   string name=EAGOLD_SentinelReduceSelectedName(slot);

   if(!GlobalVariableCheck(name))
   {
      name=EAGOLD_SentinelReduceGenericName(slot);
      if(!GlobalVariableCheck(name))
         return(-1);
   }

   int ticket=(int)GlobalVariableGet(name);
   return(ticket>0 ? ticket : -1);
}

void EAGOLD_SentinelReduceClearSelection()
{
   for(int slot=1;slot<=3;slot++)
   {
      GlobalVariableDel(EAGOLD_SentinelReduceSelectedName(slot));
      GlobalVariableDel(EAGOLD_SentinelReduceGenericName(slot));
   }

   GlobalVariablesFlush();
}

bool EAGOLD_SentinelReduceSnapshot(
   int ticket,
   int &type,
   double &lots,
   double &result)
{
   type=-1;
   lots=0.0;
   result=0.0;

   if(ticket<=0)
      return(false);

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return(false);

   if(!IsEAGOLDOrder())
      return(false);

   type=OrderType();
   if(type!=OP_BUY && type!=OP_SELL)
      return(false);

   lots=OrderLots();
   result=OrderProfit()+OrderSwap()+OrderCommission();

   return(lots>0.0);
}

double EAGOLD_SentinelReduceNormalizeLots(double lots)
{
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);

   if(step<=0.0)
      step=Lot;
   if(step<=0.0)
      step=0.01;

   lots=MathFloor((lots+0.0000000001)/step)*step;
   lots=MathMin(lots,maxLot);

   if(lots<minLot)
      return(0.0);

   return(NormalizeDouble(lots,DigitsLots));
}

bool EAGOLD_SentinelReducePartialClose(int ticket,double lots)
{
   if(ticket<=0 || lots<=0.0)
      return(false);

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return(false);

   if(!IsEAGOLDOrder())
      return(false);

   int type=OrderType();
   if(type!=OP_BUY && type!=OP_SELL)
      return(false);

   lots=EAGOLD_SentinelReduceNormalizeLots(MathMin(lots,OrderLots()));
   if(lots<=0.0)
      return(false);

   RefreshRates();

   double price=(type==OP_BUY ? Bid : Ask);

   for(int attempt=0;attempt<3;attempt++)
   {
      ResetLastError();

      if(OrderClose(ticket,lots,NormalizePrice(price),0,clrNONE))
         return(true);

      int err=GetLastError();
      Print(EA_NAME," SENTINEL REDUCE close failed ticket=",ticket,
            " lots=",DoubleToString(lots,DigitsLots),
            " attempt=",IntegerToString(attempt+1),
            " error=",IntegerToString(err));

      Sleep(100);
      RefreshRates();
      price=(type==OP_BUY ? Bid : Ask);
   }

   return(false);
}

void EAGOLD_SentinelReduceSetStatus(string status,color statusColor)
{
   g_sentinelReduceStatus=status;
   Print(EA_NAME," SENTINEL REDUCE: ",status);
}

bool EAGOLD_SentinelReduceExecute()
{
   if(!EnableSentinelReduce || g_sentinelReduceProcessing)
      return(false);

   g_sentinelReduceProcessing=true;

   int t1=EAGOLD_SentinelReduceGetTicket(1);
   int t2=EAGOLD_SentinelReduceGetTicket(2);
   int t3=EAGOLD_SentinelReduceGetTicket(3);

   // -----------------------------------------------------------------------
   // Uma unica selecao: reduz diretamente a ordem.
   // T1 = LOSS ou T2 = WIN, conforme semantica do CESTA.
   // -----------------------------------------------------------------------
   if((t1>0 && t2<=0 && t3<=0) ||
      (t1<=0 && t2>0 && t3<=0))
   {
      int ticket=(t1>0 ? t1 : t2);
      int type=-1;
      double lots=0.0;
      double result=0.0;

      if(!EAGOLD_SentinelReduceSnapshot(ticket,type,lots,result))
      {
         EAGOLD_SentinelReduceSetStatus("SELECAO INVALIDA",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      double closeLots=
         EAGOLD_SentinelReduceNormalizeLots(
            MathMin(SentinelReduceLots,lots)
         );

      if(closeLots<=0.0)
      {
         EAGOLD_SentinelReduceSetStatus("LOTE REDUCE INVALIDO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      if(!EAGOLD_SentinelReducePartialClose(ticket,closeLots))
      {
         EAGOLD_SentinelReduceSetStatus(
            "REDUCE ERRO #"+IntegerToString(ticket),
            clrTomato
         );
         g_sentinelReduceProcessing=false;
         return(false);
      }

      EAGOLD_SentinelReduceSetStatus(
         "REDUCE #"+IntegerToString(ticket)+
         " LOT "+DoubleToString(closeLots,DigitsLots),
         clrLime
      );

      EAGOLD_SentinelReduceClearSelection();
      g_sentinelReduceProcessing=false;
      return(true);
   }

   // -----------------------------------------------------------------------
   // WIN + LOSS:
   // T1 = LOSS
   // T2/T3 = WINs que fornecem o credito.
   // A maior WIN e consumida primeiro, depois a segunda se necessario.
   // -----------------------------------------------------------------------
   if(t1>0 && t2>0)
   {
      int type1=-1,type2=-1,type3=-1;
      double lots1=0.0,lots2=0.0,lots3=0.0;
      double result1=0.0,result2=0.0,result3=0.0;

      if(!EAGOLD_SentinelReduceSnapshot(t1,type1,lots1,result1) ||
         !EAGOLD_SentinelReduceSnapshot(t2,type2,lots2,result2))
      {
         EAGOLD_SentinelReduceSetStatus("SELECAO INVALIDA",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      if(result1>=-0.00000001 || result2<=0.00000001)
      {
         EAGOLD_SentinelReduceSetStatus("T1 LOSS / T2 WIN INVALIDOS",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      if(t3>0)
      {
         if(!EAGOLD_SentinelReduceSnapshot(t3,type3,lots3,result3) ||
            result3<=0.00000001)
         {
            EAGOLD_SentinelReduceSetStatus("T3 WIN INVALIDA",clrTomato);
            g_sentinelReduceProcessing=false;
            return(false);
         }
      }

      double lossCloseLots=
         EAGOLD_SentinelReduceNormalizeLots(
            MathMin(SentinelReduceLots,lots1)
         );

      if(lossCloseLots<=0.0)
      {
         EAGOLD_SentinelReduceSetStatus("LOTE LOSS INVALIDO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      double lossRealized=result1*lossCloseLots/lots1;
      double requiredMoney=
         MathAbs(lossRealized)+
         MathMax(0.0,SentinelReduceMinProfit);

      // Ordena T2/T3 pela maior WIN.
      int credit1=t2;
      double creditLots1=lots2;
      double creditResult1=result2;

      int credit2=t3;
      double creditLots2=lots3;
      double creditResult2=result3;

      if(credit2>0 && creditResult2>creditResult1)
      {
         int swapTicket=credit1;
         credit1=credit2;
         credit2=swapTicket;

         double swapLots=creditLots1;
         creditLots1=creditLots2;
         creditLots2=swapLots;

         double swapResult=creditResult1;
         creditResult1=creditResult2;
         creditResult2=swapResult;
      }

      double profitPerLot1=creditResult1/creditLots1;
      if(profitPerLot1<=0.0)
      {
         EAGOLD_SentinelReduceSetStatus("CREDITO INVALIDO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      double creditClose1=
         EAGOLD_SentinelReduceNormalizeLots(
            MathMin(
               creditLots1,
               MathCeil((requiredMoney/profitPerLot1)/MarketInfo(Symbol(),MODE_LOTSTEP))*MarketInfo(Symbol(),MODE_LOTSTEP)
            )
         );

      double creditUsed1=
         creditResult1*creditClose1/creditLots1;

      double remaining=requiredMoney-creditUsed1;
      double creditClose2=0.0;

      if(credit2>0 && remaining>0.00000001)
      {
         double profitPerLot2=creditResult2/creditLots2;

         if(profitPerLot2<=0.0)
         {
            EAGOLD_SentinelReduceSetStatus("CREDITO 2 INVALIDO",clrTomato);
            g_sentinelReduceProcessing=false;
            return(false);
         }

         creditClose2=
            EAGOLD_SentinelReduceNormalizeLots(
               MathMin(
                  creditLots2,
                  MathCeil((remaining/profitPerLot2)/MarketInfo(Symbol(),MODE_LOTSTEP))*MarketInfo(Symbol(),MODE_LOTSTEP)
               )
            );
      }

      double creditExecution=
         creditResult1*creditClose1/creditLots1;

      if(credit2>0 && creditLots2>0.0)
         creditExecution+=creditResult2*creditClose2/creditLots2;

      double projectedProfit=creditExecution+lossRealized;

      if(creditExecution+0.00000001<requiredMoney ||
         projectedProfit+0.00000001<SentinelReduceMinProfit)
      {
         EAGOLD_SentinelReduceSetStatus(
            "REDUCE AGUARDAR CREDITO "+DoubleToString(requiredMoney,2),
            clrYellow
         );
         g_sentinelReduceProcessing=false;
         return(false);
      }

      // Valida tudo antes do primeiro close.
      if(!EAGOLD_SentinelReduceSnapshot(credit1,type1,lots1,result1) ||
         lots1<creditClose1)
      {
         EAGOLD_SentinelReduceSetStatus("CREDITO 1 INVALIDO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      if(credit2>0 && creditClose2>0.0)
      {
         if(!EAGOLD_SentinelReduceSnapshot(credit2,type2,lots2,result2) ||
            lots2<creditClose2)
         {
            EAGOLD_SentinelReduceSetStatus("CREDITO 2 INVALIDO",clrTomato);
            g_sentinelReduceProcessing=false;
            return(false);
         }
      }

      if(!EAGOLD_SentinelReduceSnapshot(t1,type1,lots1,result1) ||
         lots1<lossCloseLots)
      {
         EAGOLD_SentinelReduceSetStatus("LOSS INVALIDA",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      // Ordem operacional: WIN maior -> WIN secundaria -> LOSS.
      if(!EAGOLD_SentinelReducePartialClose(credit1,creditClose1))
      {
         EAGOLD_SentinelReduceSetStatus("CREDITO 1 ERRO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      if(credit2>0 && creditClose2>0.0)
      {
         if(!EAGOLD_SentinelReducePartialClose(credit2,creditClose2))
         {
            EAGOLD_SentinelReduceSetStatus("CREDITO 1 OK / CREDITO 2 ERRO",clrTomato);
            g_sentinelReduceProcessing=false;
            return(false);
         }
      }

      if(!EAGOLD_SentinelReducePartialClose(t1,lossCloseLots))
      {
         EAGOLD_SentinelReduceSetStatus("CREDITO OK / LOSS ERRO",clrTomato);
         g_sentinelReduceProcessing=false;
         return(false);
      }

      EAGOLD_SentinelReduceSetStatus(
         "REDUCE "+DoubleToString(projectedProfit,2)+
         " LOSS "+DoubleToString(lossCloseLots,DigitsLots)+
         " C1 "+DoubleToString(creditClose1,DigitsLots)+
         " C2 "+DoubleToString(creditClose2,DigitsLots),
         clrLime
      );

      EAGOLD_SentinelReduceClearSelection();
      g_sentinelReduceProcessing=false;
      return(true);
   }

   EAGOLD_SentinelReduceSetStatus("SELECAO INCOMPATIVEL",clrTomato);
   g_sentinelReduceProcessing=false;
   return(false);
}

void EAGOLD_SentinelReduceProcessExternalRequest()
{
   string name=EAGOLD_SentinelReduceActionName();
   string fallback=EAGOLD_SentinelReduceGenericActionName();

   double action=0.0;

   if(GlobalVariableCheck(name))
      action=GlobalVariableGet(name);
   else if(GlobalVariableCheck(fallback))
      action=GlobalVariableGet(fallback);

   if(action<=0.00000001)
      return;

   GlobalVariableDel(name);
   GlobalVariableDel(fallback);
   GlobalVariablesFlush();

   if(action==1.0)
      EAGOLD_SentinelReduceExecute();
}

void EAGOLD_SentinelReduceCreateButton()
{
   if(ObjectFind(0,EAGOLD_SENTINEL_REDUCE_BUTTON)<0)
   {
      ObjectCreate(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_YDISTANCE,505);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_XSIZE,260);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_YSIZE,22);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_ZORDER,1001);
   }
}

string EAGOLD_SentinelReduceTypeText(int ticket)
{
   int type=-1;
   double lots=0.0;
   double result=0.0;

   if(!EAGOLD_SentinelReduceSnapshot(ticket,type,lots,result))
      return("--");

   return(type==OP_BUY ? "BUY" : "SELL");
}

void EAGOLD_SentinelReduceUpdatePanel()
{
   if(!EnableSentinelReduce)
      return;

   EAGOLD_SentinelReduceCreateButton();

   int t1=EAGOLD_SentinelReduceGetTicket(1);
   int t2=EAGOLD_SentinelReduceGetTicket(2);
   int t3=EAGOLD_SentinelReduceGetTicket(3);

   string s1=(t1>0 ? "T1 #"+IntegerToString(t1)+" "+EAGOLD_SentinelReduceTypeText(t1) : "T1 --");
   string s2=(t2>0 ? "T2 #"+IntegerToString(t2)+" "+EAGOLD_SentinelReduceTypeText(t2) : "T2 --");
   string s3=(t3>0 ? "T3 #"+IntegerToString(t3)+" "+EAGOLD_SentinelReduceTypeText(t3) : "T3 --");

   ObjectSetString(0,EAGOLD_SENTINEL_REDUCE_T1,OBJPROP_TEXT,s1);
   ObjectSetString(0,EAGOLD_SENTINEL_REDUCE_T2,OBJPROP_TEXT,s2);
   ObjectSetString(0,EAGOLD_SENTINEL_REDUCE_T3,OBJPROP_TEXT,s3);

   bool ready=(t1>0 || t2>0);
   string buttonText=ready ? "REDUCE SELECIONADO" : "AGUARDANDO SENTINEL_CESTA";

   ObjectSetString(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_TEXT,buttonText);
   ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_BGCOLOR,ready?clrDarkGoldenrod:clrDimGray);
   ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_COLOR,clrWhite);
}

bool EAGOLD_SentinelReduceOnChartEvent(
   const int id,
   const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK)
      return(false);

   if(sparam!=EAGOLD_SENTINEL_REDUCE_BUTTON)
      return(false);

   ObjectSetInteger(0,EAGOLD_SENTINEL_REDUCE_BUTTON,OBJPROP_STATE,false);
   EAGOLD_SentinelReduceExecute();
   return(true);
}

void EAGOLD_SentinelReduceDeletePanel()
{
   string ids[]={
      EAGOLD_SENTINEL_REDUCE_BUTTON,
      EAGOLD_SENTINEL_REDUCE_T1,
      EAGOLD_SENTINEL_REDUCE_T2,
      EAGOLD_SENTINEL_REDUCE_T3,
      EAGOLD_SENTINEL_REDUCE_INFO
   };

   for(int i=0;i<ArraySize(ids);i++)
      if(ObjectFind(0,ids[i])>=0)
         ObjectDelete(0,ids[i]);
}

#endif
