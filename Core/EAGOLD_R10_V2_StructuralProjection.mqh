#ifndef EAGOLD_R10_V2_STRUCTURAL_PROJECTION_MQH
#define EAGOLD_R10_V2_STRUCTURAL_PROJECTION_MQH

//==================================================================
// R10 v2 — STRUCTURAL IMPACT PROJECTION
// ETAPA 13.14
//
// Projects BEFORE/AFTER effects without broker mutation.
// Authorization requires an observable structural benefit.
//==================================================================

struct EAGOLD_R10V2BalancedProjection
{
   bool   valid;
   bool   structuralBenefit;
   double buyBefore;
   double buyAfter;
   double sellBefore;
   double sellAfter;
   double grossBefore;
   double grossAfter;
   double grossRelief;
   double netBefore;
   double netAfter;
   double netDelta;
   double recoveryLoadBefore;
   double recoveryLoadAfter;
   double recoveryLoadRelief;
   double buyAverageBefore;
   double buyAverageAfter;
   double sellAverageBefore;
   double sellAverageAfter;
};

void EAGOLD_R10V2BalancedProjectionReset(EAGOLD_R10V2BalancedProjection &p)
{
   p.valid=false;
   p.structuralBenefit=false;
   p.buyBefore=0.0;p.buyAfter=0.0;
   p.sellBefore=0.0;p.sellAfter=0.0;
   p.grossBefore=0.0;p.grossAfter=0.0;p.grossRelief=0.0;
   p.netBefore=0.0;p.netAfter=0.0;p.netDelta=0.0;
   p.recoveryLoadBefore=0.0;p.recoveryLoadAfter=0.0;
   p.recoveryLoadRelief=0.0;
   p.buyAverageBefore=0.0;p.buyAverageAfter=0.0;
   p.sellAverageBefore=0.0;p.sellAverageAfter=0.0;
}

double EAGOLD_R10V2ProjectedDirectionAverageAfterTicketReduction(
   int direction,int ticket,double q)
{
   double total=0.0;
   double weighted=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder() || OrderType()!=direction)continue;

      double lots=OrderLots();
      if(OrderTicket()==ticket)lots-=q;
      if(lots<=0.0)continue;

      total+=lots;
      weighted+=lots*OrderOpenPrice();
   }

   if(total<=0.0)return(0.0);
   return(weighted/total);
}

void EAGOLD_R10V2ProjectBalancedStructuralImpact(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2BalancedPair &pair,
   double commonLots,
   EAGOLD_R10V2BalancedProjection &p)
{
   EAGOLD_R10V2BalancedProjectionReset(p);

   if(!pair.found || pair.buy.ticket<0 || pair.sell.ticket<0)return;
   if(commonLots<Lot)return;

   double q=MathMin(commonLots,pair.commonCandidateLots);
   q=NormalizeDouble(q,DigitsLots);
   if(q<Lot)return;

   if(!OrderSelect(pair.buy.ticket,SELECT_BY_TICKET,MODE_TRADES))return;
   if(!IsEAGOLDOrder() || OrderType()!=OP_BUY)return;
   if(OrderLots()<q)return;

   if(!OrderSelect(pair.sell.ticket,SELECT_BY_TICKET,MODE_TRADES))return;
   if(!IsEAGOLDOrder() || OrderType()!=OP_SELL)return;
   if(OrderLots()<q)return;

   p.buyBefore=ctx.buyLots;
   p.sellBefore=ctx.sellLots;
   p.buyAfter=MathMax(0.0,p.buyBefore-q);
   p.sellAfter=MathMax(0.0,p.sellBefore-q);

   p.grossBefore=ctx.grossExposure;
   p.grossAfter=MathMax(0.0,p.grossBefore-(2.0*q));
   p.grossRelief=p.grossBefore-p.grossAfter;

   p.netBefore=ctx.netExposure;
   p.netAfter=p.netBefore;
   p.netDelta=p.netAfter-p.netBefore;

   p.recoveryLoadBefore=
      EAGOLD_R10V2DirectionRecoveryLoad(ctx,OP_BUY)+
      EAGOLD_R10V2DirectionRecoveryLoad(ctx,OP_SELL);

   double buyRelief=q*MathAbs(ctx.bid-pair.buy.openPrice)/Point;
   double sellRelief=q*MathAbs(ctx.ask-pair.sell.openPrice)/Point;
   p.recoveryLoadAfter=MathMax(0.0,p.recoveryLoadBefore-buyRelief-sellRelief);
   p.recoveryLoadRelief=p.recoveryLoadBefore-p.recoveryLoadAfter;

   p.buyAverageBefore=EAGOLD_R10V2DirectionWeightedAverage(ctx,OP_BUY);
   p.sellAverageBefore=EAGOLD_R10V2DirectionWeightedAverage(ctx,OP_SELL);
   p.buyAverageAfter=EAGOLD_R10V2ProjectedDirectionAverageAfterTicketReduction(
      OP_BUY,pair.buy.ticket,q);
   p.sellAverageAfter=EAGOLD_R10V2ProjectedDirectionAverageAfterTicketReduction(
      OP_SELL,pair.sell.ticket,q);

   p.valid=true;
   p.structuralBenefit=(p.grossRelief>0.0 || p.recoveryLoadRelief>0.0 ||
      MathAbs(p.buyAverageAfter-p.buyAverageBefore)>Point*0.1 ||
      MathAbs(p.sellAverageAfter-p.sellAverageBefore)>Point*0.1);

   // Hard invariant: Balanced must preserve NET exactly within
   // normalized lot precision.
   if(MathAbs(p.netDelta)>0.5*Lot)
      p.structuralBenefit=false;
}

bool EAGOLD_R10V2BalancedAuthorizationIntegrity(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2BalancedPair &pair,
   double desiredLots,
   double capitalCapacity,
   double exposureCapacity,
   double r11Capacity,
   double brokerCapacity,
   EAGOLD_R10V2BalancedProjection &projection,
   double &authorizedLots)
{
   authorizedLots=0.0;
   if(!pair.found)return(false);

   double candidate=MathMin(desiredLots,capitalCapacity);
   candidate=MathMin(candidate,exposureCapacity);
   candidate=MathMin(candidate,r11Capacity);
   candidate=MathMin(candidate,brokerCapacity);
   candidate=MathMin(candidate,pair.commonCandidateLots);
   candidate=EAGOLD_R10V2NormalizeCapacityLots(candidate);

   if(candidate<Lot)return(false);

   EAGOLD_R10V2ProjectBalancedStructuralImpact(
      ctx,pair,candidate,projection);

   if(!projection.valid || !projection.structuralBenefit)return(false);
   if(MathAbs(projection.netDelta)>0.5*Lot)return(false);

   authorizedLots=candidate;
   return(true);
}

struct EAGOLD_R10V2StructuralProjection
{
   bool   valid;
   bool   structuralBenefit;
   double lotsBefore;
   double lotsAfter;
   double grossBefore;
   double grossAfter;
   double grossRelief;
   double netBefore;
   double netAfter;
   double netDelta;
   double recoveryLoadBefore;
   double recoveryLoadAfter;
   double recoveryLoadRelief;
   double weightedAverageBefore;
   double weightedAverageAfter;
   double averageDelta;
};

void EAGOLD_R10V2StructuralProjectionReset(EAGOLD_R10V2StructuralProjection &p)
{
   p.valid=false;
   p.structuralBenefit=false;
   p.lotsBefore=0.0;
   p.lotsAfter=0.0;
   p.grossBefore=0.0;
   p.grossAfter=0.0;
   p.grossRelief=0.0;
   p.netBefore=0.0;
   p.netAfter=0.0;
   p.netDelta=0.0;
   p.recoveryLoadBefore=0.0;
   p.recoveryLoadAfter=0.0;
   p.recoveryLoadRelief=0.0;
   p.weightedAverageBefore=0.0;
   p.weightedAverageAfter=0.0;
   p.averageDelta=0.0;
}

double EAGOLD_R10V2DirectionWeightedAverage(const EAGOLD_R10V2Context &ctx,int direction)
{
   double total=0.0;
   double weighted=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder() || OrderType()!=direction)continue;
      double lots=OrderLots();
      if(lots<=0.0)continue;
      total+=lots;
      weighted+=lots*OrderOpenPrice();
   }

   if(total<=0.0)return(0.0);
   return(weighted/total);
}

double EAGOLD_R10V2DirectionRecoveryLoad(const EAGOLD_R10V2Context &ctx,int direction)
{
   double total=0.0;
   double market=(direction==OP_BUY?ctx.bid:ctx.ask);

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder() || OrderType()!=direction)continue;
      total+=OrderLots()*MathAbs(market-OrderOpenPrice())/Point;
   }

   return(total);
}

void EAGOLD_R10V2ProjectStructuralImpact(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2Target &target,
   double authorizedLots,
   EAGOLD_R10V2StructuralProjection &p)
{
   EAGOLD_R10V2StructuralProjectionReset(p);

   if(!target.found || target.ticket<0 || authorizedLots<Lot)return;

   if(!OrderSelect(target.ticket,SELECT_BY_TICKET,MODE_TRADES))return;
   if(!IsEAGOLDOrder())return;
   if(OrderType()!=target.direction)return;

   double ticketLots=OrderLots();
   if(ticketLots<Lot)return;

   double q=MathMin(authorizedLots,ticketLots);
   q=NormalizeDouble(q,DigitsLots);
   if(q<Lot)return;

   int dir=target.direction;
   int opposite=(dir==OP_BUY?OP_SELL:OP_BUY);

   double dirBefore=(dir==OP_BUY?ctx.buyLots:ctx.sellLots);
   double oppBefore=(opposite==OP_BUY?ctx.buyLots:ctx.sellLots);

   p.lotsBefore=dirBefore;
   p.lotsAfter=MathMax(0.0,dirBefore-q);
   p.grossBefore=ctx.grossExposure;
   p.grossAfter=MathMax(0.0,ctx.grossExposure-q);
   p.grossRelief=p.grossBefore-p.grossAfter;

   p.netBefore=ctx.netExposure;
   if(dir==OP_BUY)p.netAfter=p.netBefore-q;
   else p.netAfter=p.netBefore+q;
   p.netDelta=p.netAfter-p.netBefore;

   p.recoveryLoadBefore=EAGOLD_R10V2DirectionRecoveryLoad(ctx,dir);
   double ticketRecovery=q*MathAbs((dir==OP_BUY?ctx.bid:ctx.ask)-OrderOpenPrice())/Point;
   p.recoveryLoadAfter=MathMax(0.0,p.recoveryLoadBefore-ticketRecovery);
   p.recoveryLoadRelief=p.recoveryLoadBefore-p.recoveryLoadAfter;

   p.weightedAverageBefore=EAGOLD_R10V2DirectionWeightedAverage(ctx,dir);

   double weightedNumerator=0.0;
   double totalAfter=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder() || OrderType()!=dir)continue;

      double lots=OrderLots();
      if(OrderTicket()==target.ticket)lots-=q;
      if(lots<=0.0)continue;

      totalAfter+=lots;
      weightedNumerator+=lots*OrderOpenPrice();
   }

   if(totalAfter>0.0)
      p.weightedAverageAfter=weightedNumerator/totalAfter;

   p.averageDelta=p.weightedAverageAfter-p.weightedAverageBefore;

   p.valid=true;
   p.structuralBenefit=(p.grossRelief>0.0 || p.recoveryLoadRelief>0.0 ||
                        MathAbs(p.averageDelta)>Point*0.1);
}

bool EAGOLD_R10V2AuthorizationIntegrity(
   const EAGOLD_R10V2Context &ctx,
   const EAGOLD_R10V2Target &target,
   double desiredLots,
   double capitalCapacity,
   double exposureCapacity,
   double r11Capacity,
   double brokerCapacity,
   EAGOLD_R10V2StructuralProjection &projection,
   double &authorizedLots)
{
   authorizedLots=0.0;

   double candidate=MathMin(desiredLots,capitalCapacity);
   candidate=MathMin(candidate,exposureCapacity);
   candidate=MathMin(candidate,r11Capacity);
   candidate=MathMin(candidate,brokerCapacity);
   candidate=EAGOLD_R10V2NormalizeCapacityLots(candidate);

   if(candidate<Lot)return(false);

   EAGOLD_R10V2ProjectStructuralImpact(ctx,target,candidate,projection);
   if(!projection.valid || !projection.structuralBenefit)return(false);

   authorizedLots=candidate;
   return(true);
}

#endif
