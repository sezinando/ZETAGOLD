#ifndef EAGOLD_ENGINE0_INTELLIGENCE_MQH
#define EAGOLD_ENGINE0_INTELLIGENCE_MQH
// ENGINE 0 — MARKET INTELLIGENCE / DIRECTION SELECTOR
#define ZG_DIR_SELL -1
#define ZG_DIR_WAIT 0
#define ZG_DIR_BUY 1
struct ZG_DirectionDecision {
 int Direction; int Regime; double BuyScore; double SellScore; double Edge; double Confidence;
 double ATR; double ADX; double EMA21; double EMA50; double EMASlope; double RangePosition;
 double BollingerZ; double Momentum; double MomentumAcceleration; double ExtensionATR;
 bool Extreme; bool Continuation; bool Exhaustion;
};
bool ZG_IntelligenceEnabled(){return(EnableZGIntelligence);}
bool ZG_DirectionFilterEnabled(){return(EnableZGIntelligence && ZG_EnableDirectionFilter && !ZG_IntelligenceShadowMode);}
bool ZG_GridIntelligenceEnabled(){return(EnableZGIntelligence && ZG_EnableGridIntelligence && !ZG_IntelligenceShadowMode);}
double ZG_Clamp(double v,double lo,double hi){if(v<lo)return(lo);if(v>hi)return(hi);return(v);}
double ZG_SafeDiv(double a,double b){if(MathAbs(b)<0.000000001)return(0.0);return(a/b);}
double ZG_ATR(int tf,int sh){return(iATR(Symbol(),tf,ZG_ATRPeriod,sh));}
double ZG_EMA(int tf,int p,int sh){return(iMA(Symbol(),tf,p,0,MODE_EMA,PRICE_CLOSE,sh));}
double ZG_EMASlope(int tf){return ZG_SafeDiv(ZG_EMA(tf,ZG_EMAFast,1)-ZG_EMA(tf,ZG_EMAFast,1+ZG_SlopeLookback),ZG_ATR(tf,1));}
double ZG_BollingerZ(int tf,int sh){double m=iBands(Symbol(),tf,ZG_BBPeriod,ZG_BBDeviation,0,PRICE_CLOSE,MODE_MAIN,sh);double u=iBands(Symbol(),tf,ZG_BBPeriod,ZG_BBDeviation,0,PRICE_CLOSE,MODE_UPPER,sh);double l=iBands(Symbol(),tf,ZG_BBPeriod,ZG_BBDeviation,0,PRICE_CLOSE,MODE_LOWER,sh);return ZG_SafeDiv(iClose(Symbol(),tf,sh)-m,(u-l)/2.0);}
double ZG_RangePosition(int tf,int n,int sh){int hs=iHighest(Symbol(),tf,MODE_HIGH,n,sh),ls=iLowest(Symbol(),tf,MODE_LOW,n,sh);double hi=iHigh(Symbol(),tf,hs),lo=iLow(Symbol(),tf,ls);if(hi<=lo)return .5;return ZG_Clamp((iClose(Symbol(),tf,sh)-lo)/(hi-lo),0,1);}
double ZG_Momentum(int tf,int sh){return ZG_SafeDiv(iClose(Symbol(),tf,sh)-iClose(Symbol(),tf,sh+ZG_MomentumLookback),ZG_ATR(tf,sh));}
void ZG_IntelligenceReset(ZG_DirectionDecision &d){d.Direction=0;d.Regime=0;d.BuyScore=0;d.SellScore=0;d.Edge=0;d.Confidence=0;d.ATR=0;d.ADX=0;d.EMA21=0;d.EMA50=0;d.EMASlope=0;d.RangePosition=.5;d.BollingerZ=0;d.Momentum=0;d.MomentumAcceleration=0;d.ExtensionATR=0;d.Extreme=false;d.Continuation=false;d.Exhaustion=false;}
bool ZG_IsNewBar(){static datetime last=0;datetime t=iTime(Symbol(),ZG_Timeframe,0);if(t<=0||t==last)return false;last=t;return true;}
void ZG_IntelligenceEvaluate(ZG_DirectionDecision &d){
 ZG_IntelligenceReset(d); if(!EnableZGIntelligence||iBars(Symbol(),ZG_Timeframe)<ZG_MinBarsRequired)return;
 int tf=ZG_Timeframe,sh=1; d.ATR=ZG_ATR(tf,sh);if(d.ATR<=0)return;
 d.EMA21=ZG_EMA(tf,ZG_EMAFast,sh);d.EMA50=ZG_EMA(tf,ZG_EMASlow,sh);d.EMASlope=ZG_EMASlope(tf);
 d.ADX=iADX(Symbol(),tf,ZG_ADXPeriod,PRICE_CLOSE,MODE_MAIN,sh);d.RangePosition=ZG_RangePosition(tf,ZG_RangeLookback,sh);d.BollingerZ=ZG_BollingerZ(tf,sh);
 d.Momentum=ZG_Momentum(tf,sh);d.MomentumAcceleration=ZG_Momentum(tf,1)-ZG_Momentum(tf,1+ZG_MomentumAccelLookback);
 d.ExtensionATR=ZG_SafeDiv(iClose(Symbol(),tf,sh)-d.EMA21,d.ATR);
 d.Extreme=(d.RangePosition>=ZG_ExtremeRangeHigh||d.RangePosition<=ZG_ExtremeRangeLow||MathAbs(d.BollingerZ)>=ZG_ExtremeBBZ||MathAbs(d.ExtensionATR)>=ZG_ExtremeExtensionATR);
 d.Regime=(d.ADX<ZG_MinADX?0:(d.EMASlope>=ZG_MinTrendSlope?1:(d.EMASlope<=-ZG_MinTrendSlope?-1:0)));
 if(d.Regime>0)d.BuyScore+=ZG_TrendWeight;if(d.Regime<0)d.SellScore+=ZG_TrendWeight;
 if(d.Momentum>ZG_MomentumNeutralBand)d.BuyScore+=ZG_MomentumWeight;if(d.Momentum<-ZG_MomentumNeutralBand)d.SellScore+=ZG_MomentumWeight;
 if(d.MomentumAcceleration>ZG_MomentumAccelerationBand)d.BuyScore+=ZG_AccelerationWeight;if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand)d.SellScore+=ZG_AccelerationWeight;
 bool upper=(d.RangePosition>=ZG_ExtremeRangeHigh||d.BollingerZ>=ZG_ExtremeBBZ),lower=(d.RangePosition<=ZG_ExtremeRangeLow||d.BollingerZ<=-ZG_ExtremeBBZ);
 if(upper){if(d.MomentumAcceleration>ZG_MomentumAccelerationBand&&d.EMASlope>0)d.BuyScore+=ZG_ContinuationWeight;else if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand||d.EMASlope<ZG_MinTrendSlope)d.SellScore+=ZG_ExhaustionWeight;}
 if(lower){if(d.MomentumAcceleration<-ZG_MomentumAccelerationBand&&d.EMASlope<0)d.SellScore+=ZG_ContinuationWeight;else if(d.MomentumAcceleration>ZG_MomentumAccelerationBand||d.EMASlope>-ZG_MinTrendSlope)d.BuyScore+=ZG_ExhaustionWeight;}
 if(!upper&&!lower){if(d.Momentum>ZG_MomentumNeutralBand)d.BuyScore+=ZG_NormalMomentumWeight;if(d.Momentum<-ZG_MomentumNeutralBand)d.SellScore+=ZG_NormalMomentumWeight;}
 if(d.Extreme){if(d.Regime>0&&d.Momentum>ZG_MomentumNeutralBand&&d.MomentumAcceleration>ZG_MomentumAccelerationBand)d.Continuation=true;if(d.Regime<0&&d.Momentum<-ZG_MomentumNeutralBand&&d.MomentumAcceleration<-ZG_MomentumAccelerationBand)d.Continuation=true;if((d.Regime>=0&&d.MomentumAcceleration<-ZG_MomentumAccelerationBand)||(d.Regime<=0&&d.MomentumAcceleration>ZG_MomentumAccelerationBand))d.Exhaustion=true;}
 d.Edge=d.BuyScore-d.SellScore;double total=d.BuyScore+d.SellScore;if(total>0)d.Confidence=ZG_Clamp(MathAbs(d.Edge)/total,0,1);
 if(d.Confidence>=ZG_MinConfidence&&MathAbs(d.Edge)>=ZG_MinEdge)d.Direction=(d.Edge>0?ZG_DIR_BUY:ZG_DIR_SELL);
}
bool ZG_IntelligenceEvaluateOnNewBar(ZG_DirectionDecision &d){if(!ZG_IsNewBar())return false;ZG_IntelligenceEvaluate(d);return true;}
// Admission uses the last closed H1 state. WAIT means no new direction is admitted.
bool ZG_IntelligenceAdmissionAllowed(ZG_DirectionDecision &d,int direction){if(!ZG_DirectionFilterEnabled())return true;if(direction==OP_BUY)return(d.Direction==ZG_DIR_BUY);if(direction==OP_SELL)return(d.Direction==ZG_DIR_SELL);return false;}
#endif
