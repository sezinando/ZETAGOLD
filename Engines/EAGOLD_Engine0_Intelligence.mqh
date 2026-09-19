#ifndef EAGOLD_ENGINE0_INTELLIGENCE_MQH
#define EAGOLD_ENGINE0_INTELLIGENCE_MQH

//==================================================================
// ENGINE 0 — MARKET INTELLIGENCE / DIRECTION SELECTOR
// Phase 1: SHADOW MODE.
// Purpose:
//   - classify current market state;
//   - estimate continuation vs exhaustion context;
//   - produce BUY / SELL / WAIT evidence;
//   - NEVER place, modify or close orders.
// This is intentionally transparent and rule-based.
// Thresholds are calibration points, not final optimized values.
//==================================================================

#define ZG_DIR_SELL -1
#define ZG_DIR_WAIT  0
#define ZG_DIR_BUY   1

struct ZG_DirectionDecision
{
   int    Direction;
   int    Regime;

   double BuyScore;
   double SellScore;
   double Edge;
   double Confidence;

   double ATR;
   double ADX;
   double EMA21;
   double EMA50;
   double EMASlope;
   double RangePosition;
   double BollingerZ;
   double Momentum;
   double MomentumAcceleration;
   double ExtensionATR;

   bool   Extreme;
   bool   Continuation;
   bool   Exhaustion;
};

bool ZG_IntelligenceEnabled()
{
   return(EnableZGIntelligence);
}

double ZG_Clamp(double value,double lo,double hi)
{
   if(value<lo)return(lo);
   if(value>hi)return(hi);
   return(value);
}

double ZG_SafeDiv(double a,double b)
{
   if(MathAbs(b)<0.000000001)return(0.0);
   return(a/b);
}

double ZG_ATR(int tf,int shift)
{
   return(iATR(Symbol(),tf,ZG_ATRPeriod,shift));
}

double ZG_EMA(int tf,int period,int shift)
{
   return(iMA(Symbol(),tf,period,0,MODE_EMA,PRICE_CLOSE,shift));
}

double ZG_EMASlope(int tf)
{
   double a=ZG_EMA(tf,ZG_EMAFast,1);
   double b=ZG_EMA(tf,ZG_EMAFast,1+ZG_SlopeLookback);
   double atr=ZG_ATR(tf,1);
   return(ZG_SafeDiv(a-b,atr));
}

double ZG_BollingerZ(int tf,int shift)
{
   double mid=iBands(Symbol(),tf,ZG_BBPeriod, ZG_BBDeviation,0,PRICE_CLOSE,MODE_MAIN,shift);
   double upper=iBands(Symbol(),tf,ZG_BBPeriod, ZG_BBDeviation,0,PRICE_CLOSE,MODE_UPPER,shift);
   double lower=iBands(Symbol(),tf,ZG_BBPeriod, ZG_BBDeviation,0,PRICE_CLOSE,MODE_LOWER,shift);
   double half=(upper-lower)/2.0;
   double close=iClose(Symbol(),tf,shift);
   return(ZG_SafeDiv(close-mid,half));
}

double ZG_RangePosition(int tf,int lookback,int shift)
{
   if(lookback<2)return(0.5);
   int hiShift=iHighest(Symbol(),tf,MODE_HIGH,lookback,shift);
   int loShift=iLowest(Symbol(),tf,MODE_LOW,lookback,shift);
   double hi=iHigh(Symbol(),tf,hiShift);
   double lo=iLow(Symbol(),tf,loShift);
   double close=iClose(Symbol(),tf,shift);
   if(hi<=lo)return(0.5);
   return(ZG_Clamp((close-lo)/(hi-lo),0.0,1.0));
}

double ZG_Momentum(int tf,int shift)
{
   double now=iClose(Symbol(),tf,shift);
   double past=iClose(Symbol(),tf,shift+ZG_MomentumLookback);
   return(ZG_SafeDiv(now-past,ZG_ATR(tf,shift)));
}

double ZG_MomentumAcceleration(int tf)
{
   double m1=ZG_Momentum(tf,1);
   double m2=ZG_Momentum(tf,1+ZG_MomentumAccelLookback);
   return(m1-m2);
}

bool ZG_IsExtreme(double rangePos,double bbz,double extension)
{
   if(rangePos>=ZG_ExtremeRangeHigh)return(true);
   if(rangePos<=ZG_ExtremeRangeLow)return(true);
   if(MathAbs(bbz)>=ZG_ExtremeBBZ)return(true);
   if(MathAbs(extension)>=ZG_ExtremeExtensionATR)return(true);
   return(false);
}

int ZG_Regime(double slope,double adx)
{
   if(adx<ZG_MinADX)return(0);
   if(slope>=ZG_MinTrendSlope)return(1);
   if(slope<=-ZG_MinTrendSlope)return(-1);
   return(0);
}

void ZG_IntelligenceReset(ZG_DirectionDecision &d)
{
   d.Direction=ZG_DIR_WAIT;
   d.Regime=0;
   d.BuyScore=0.0;
   d.SellScore=0.0;
   d.Edge=0.0;
   d.Confidence=0.0;
   d.ATR=0.0;
   d.ADX=0.0;
   d.EMA21=0.0;
   d.EMA50=0.0;
   d.EMASlope=0.0;
   d.RangePosition=0.5;
   d.BollingerZ=0.0;
   d.Momentum=0.0;
   d.MomentumAcceleration=0.0;
   d.ExtensionATR=0.0;
   d.Extreme=false;
   d.Continuation=false;
   d.Exhaustion=false;
}

void ZG_IntelligenceEvaluate(ZG_DirectionDecision &d)
{
   ZG_IntelligenceReset(d);

   if(!EnableZGIntelligence)return;
   if(iBars(Symbol(),ZG_Timeframe)<ZG_MinBarsRequired)return;

   int tf=ZG_Timeframe;
   int sh=1;

   d.ATR=ZG_ATR(tf,sh);
   if(d.ATR<=0.0)return;

   d.EMA21=ZG_EMA(tf,ZG_EMAFast,sh);
   d.EMA50=ZG_EMA(tf,ZG_EMASlow,sh);
   d.EMASlope=ZG_EMASlope(tf);
   d.ADX=iADX(Symbol(),tf,ZG_ADXPeriod,PRICE_CLOSE,MODE_MAIN,sh);
   d.RangePosition=ZG_RangePosition(tf,ZG_RangeLookback,sh);
   d.BollingerZ=ZG_BollingerZ(tf,sh);
   d.Momentum=ZG_Momentum(tf,sh);
   d.MomentumAcceleration=ZG_MomentumAcceleration(tf);

   double close=iClose(Symbol(),tf,sh);
   d.ExtensionATR=ZG_SafeDiv(close-d.EMA21,d.ATR);
   d.Extreme=ZG_IsExtreme(d.RangePosition,d.BollingerZ,d.ExtensionATR);
   d.Regime=ZG_Regime(d.EMASlope,d.ADX);

   // ---------------------------------------------------------------
   // BASE EVIDENCE
   // Trend alignment contributes modestly. It does not decide alone.
   // ---------------------------------------------------------------
   if(d.Regime>0)d.BuyScore+=ZG_TrendWeight;
   if(d.Regime<0)d.SellScore+=ZG_TrendWeight;

   // Momentum direction.
   if(d.Momentum>ZG_MomentumNeutralBand)d.BuyScore+=ZG_MomentumWeight;
   if(d.Momentum<-ZG_MomentumNeutralBand)d.SellScore+=ZG_MomentumWeight;

   // Momentum acceleration reinforces continuation.
   if(d.MomentumAcceleration>ZG_MomentumAccelerationBand)d.BuyScore+=ZG_AccelerationWeight;
   if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand)d.SellScore+=ZG_AccelerationWeight;

   // ---------------------------------------------------------------
   // LOCATION / EXTENSION
   // Do NOT use top=SELL / bottom=BUY.
   // Location is interpreted together with momentum and slope.
   // ---------------------------------------------------------------
   bool upper=(d.RangePosition>=ZG_ExtremeRangeHigh || d.BollingerZ>=ZG_ExtremeBBZ);
   bool lower=(d.RangePosition<=ZG_ExtremeRangeLow || d.BollingerZ<=-ZG_ExtremeBBZ);

   if(upper)
   {
      if(d.MomentumAcceleration>ZG_MomentumAccelerationBand && d.EMASlope>0.0)
         d.BuyScore+=ZG_ContinuationWeight;
      else if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand || d.EMASlope<ZG_MinTrendSlope)
         d.SellScore+=ZG_ExhaustionWeight;
   }

   if(lower)
   {
      if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand && d.EMASlope<0.0)
         d.SellScore+=ZG_ContinuationWeight;
      else if(d.MomentumAcceleration>ZG_MomentumAccelerationBand || d.EMASlope>-ZG_MinTrendSlope)
         d.BuyScore+=ZG_ExhaustionWeight;
   }

   // Non-extreme directional momentum.
   if(!upper && !lower)
   {
      if(d.Momentum>ZG_MomentumNeutralBand)d.BuyScore+=ZG_NormalMomentumWeight;
      if(d.Momentum<-ZG_MomentumNeutralBand)d.SellScore+=ZG_NormalMomentumWeight;
   }

   // ---------------------------------------------------------------
   // CONTINUATION / EXHAUSTION FLAGS
   // These are observational features for calibration.
   // ---------------------------------------------------------------
   d.Continuation=false;
   d.Exhaustion=false;

   if(d.Extreme)
   {
      if(d.Regime>0 &&
         d.Momentum>ZG_MomentumNeutralBand &&
         d.MomentumAcceleration>ZG_MomentumAccelerationBand)
         d.Continuation=true;

      if(d.Regime<0 &&
         d.Momentum<-ZG_MomentumNeutralBand &&
         d.MomentumAcceleration<-ZG_MomentumAccelerationBand)
         d.Continuation=true;

      if((d.Regime>=0 && d.MomentumAcceleration<-ZG_MomentumAccelerationBand) ||
         (d.Regime<=0 && d.MomentumAcceleration>ZG_MomentumAccelerationBand))
         d.Exhaustion=true;
   }

   // ADX extreme is deliberately not a direction by itself.
   // Very weak trend reduces confidence rather than forcing a side.
   if(d.ADX<ZG_MinADX)
   {
      d.BuyScore*=0.85;
      d.SellScore*=0.85;
   }

   d.Edge=d.BuyScore-d.SellScore;

   double total=d.BuyScore+d.SellScore;
   if(total>0.0)
      d.Confidence=ZG_Clamp(MathAbs(d.Edge)/total,0.0,1.0);

   d.Direction=ZG_DIR_WAIT;

   if(d.Confidence>=ZG_MinConfidence &&
      MathAbs(d.Edge)>=ZG_MinEdge)
   {
      if(d.Edge>0.0)d.Direction=ZG_DIR_BUY;
      else if(d.Edge<0.0)d.Direction=ZG_DIR_SELL;
   }

   if(ZG_ShadowLogEnabled)
      ZG_IntelligenceLog(d);
}

void ZG_IntelligenceLog(const ZG_DirectionDecision &d)
{
   string file=ZG_ShadowFileName;
   int h=FileOpen(file,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h<0)return;

   if(FileSize(h)==0)
   {
      FileWrite(h,
         "time","symbol","tf","price","regime","atr","adx",
         "ema21","ema50","ema_slope","range_pos","bb_z",
         "momentum","momentum_accel","extension_atr","extreme",
         "continuation","exhaustion","buy_score","sell_score",
         "edge","confidence","direction");
   }

   FileSeek(h,0,SEEK_END);

   FileWrite(h,
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      Symbol(),
      ZG_TFToString(ZG_Timeframe),
      DoubleToString(iClose(Symbol(),ZG_Timeframe,1),Digits),
      d.Regime,
      DoubleToString(d.ATR,Digits),
      DoubleToString(d.ADX,2),
      DoubleToString(d.EMA21,Digits),
      DoubleToString(d.EMA50,Digits),
      DoubleToString(d.EMASlope,4),
      DoubleToString(d.RangePosition,4),
      DoubleToString(d.BollingerZ,4),
      DoubleToString(d.Momentum,4),
      DoubleToString(d.MomentumAcceleration,4),
      DoubleToString(d.ExtensionATR,4),
      d.Extreme,
      d.Continuation,
      d.Exhaustion,
      DoubleToString(d.BuyScore,4),
      DoubleToString(d.SellScore,4),
      DoubleToString(d.Edge,4),
      DoubleToString(d.Confidence,4),
      d.Direction);

   FileClose(h);
}

string ZG_TFToString(int tf)
{
   if(tf==PERIOD_M1)return("M1");
   if(tf==PERIOD_M5)return("M5");
   if(tf==PERIOD_M15)return("M15");
   if(tf==PERIOD_M30)return("M30");
   if(tf==PERIOD_H1)return("H1");
   if(tf==PERIOD_H4)return("H4");
   if(tf==PERIOD_D1)return("D1");
   return(IntegerToString(tf));
}

#endif
