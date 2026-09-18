#ifndef EAGOLD_R10_V2_TARGET_SELECTION_MQH
#define EAGOLD_R10_V2_TARGET_SELECTION_MQH

//==================================================================
// R10 v2 — TARGET SELECTION ENGINE
// ETAPA 13.10
//
// Builds an explicit ticket census and selects a target according to
// a deterministic policy. This module is read-only.
//
// It does NOT:
//   - close/open/delete orders
//   - reserve/consume capital
//   - call R11
//   - authorize execution
//
// Target Selection answers only:
//   "QUAL posição pode representar melhor esta oportunidade?"
//
// Authorization remains downstream.
//==================================================================

enum EAGOLD_R10V2SelectionPolicy
{
   EAGOLD_R10V2_POLICY_NONE=0,
   EAGOLD_R10V2_POLICY_FARTHEST=1,
   EAGOLD_R10V2_POLICY_WORST_LOSS=2,
   EAGOLD_R10V2_POLICY_LOSS_PER_LOT=3,
   EAGOLD_R10V2_POLICY_RECOVERY_LOAD=4,
   EAGOLD_R10V2_POLICY_CONCENTRATION=5,
   EAGOLD_R10V2_POLICY_STRUCTURAL_IMPACT=6,
   EAGOLD_R10V2_POLICY_BALANCED=7
};

string EAGOLD_R10V2SelectionPolicyName(EAGOLD_R10V2SelectionPolicy policy)
{
   if(policy==EAGOLD_R10V2_POLICY_FARTHEST)return("FARTHEST");
   if(policy==EAGOLD_R10V2_POLICY_WORST_LOSS)return("WORST_LOSS");
   if(policy==EAGOLD_R10V2_POLICY_LOSS_PER_LOT)return("LOSS_PER_LOT");
   if(policy==EAGOLD_R10V2_POLICY_RECOVERY_LOAD)return("RECOVERY_LOAD");
   if(policy==EAGOLD_R10V2_POLICY_CONCENTRATION)return("CONCENTRATION");
   if(policy==EAGOLD_R10V2_POLICY_STRUCTURAL_IMPACT)return("STRUCTURAL_IMPACT");
   if(policy==EAGOLD_R10V2_POLICY_BALANCED)return("BALANCED");
   return("NONE");
}

struct EAGOLD_R10V2Ticket
{
   int      ticket;
   int      direction;
   double   lots;
   double   openPrice;
   double   currentPrice;
   double   floatingProfit;
   double   lossPerLot;
   double   distanceToMarket;
   int      ageSeconds;
   double   recoveryLoad;
   double   relativeVolume;
   int      structuralPosition;
};

struct EAGOLD_R10V2Target
{
   bool     found;
   int      ticket;
   int      direction;
   double   candidateLots;
   double   floatingProfit;
   double   lossPerLot;
   double   distanceToMarket;
   double   recoveryLoad;
   double   relativeVolume;
   int      structuralPosition;
   EAGOLD_R10V2SelectionPolicy policy;
};

void EAGOLD_R10V2TicketReset(EAGOLD_R10V2Ticket &t)
{
   t.ticket=-1;
   t.direction=0;
   t.lots=0.0;
   t.openPrice=0.0;
   t.currentPrice=0.0;
   t.floatingProfit=0.0;
   t.lossPerLot=0.0;
   t.distanceToMarket=0.0;
   t.ageSeconds=0;
   t.recoveryLoad=0.0;
   t.relativeVolume=0.0;
   t.structuralPosition=0;
}

double EAGOLD_R10V2TicketRecoveryLoad(const EAGOLD_R10V2Ticket &t)
{
   // Price-distance proxy. Monetary conversion belongs to the
   // economic/capacity layer and is intentionally not assumed here.
   return(t.lots*t.distanceToMarket);
}

double EAGOLD_R10V2TicketRelativeVolume(const EAGOLD_R10V2Ticket &t,
                                        double directionLots)
{
   if(directionLots<=0.0)return(0.0);
   return(t.lots/directionLots);
}

void EAGOLD_R10V2BuildTicket(const EAGOLD_R10V2Context &ctx,
                             EAGOLD_R10V2Ticket &t)
{
   EAGOLD_R10V2TicketReset(t);

   if(OrderSymbol()!=ctx.symbol)return;

   int type=OrderType();
   if(type!=OP_BUY && type!=OP_SELL)return;

   t.ticket=OrderTicket();
   t.direction=type;
   t.lots=OrderLots();
   t.openPrice=OrderOpenPrice();
   t.currentPrice=(type==OP_BUY?ctx.bid:ctx.ask);
   t.floatingProfit=OrderProfit()+OrderSwap()+OrderCommission();

   if(t.lots>0.0)
      t.lossPerLot=(t.floatingProfit<0.0 ? (-t.floatingProfit/t.lots) : 0.0);

   t.distanceToMarket=MathAbs(t.currentPrice-t.openPrice)/Point;

   datetime openTime=OrderOpenTime();
   if(openTime>0 && ctx.timestamp>=openTime)
      t.ageSeconds=(int)(ctx.timestamp-openTime);

   t.recoveryLoad=EAGOLD_R10V2TicketRecoveryLoad(t);

   double dirLots=(type==OP_BUY?ctx.buyLots:ctx.sellLots);
   t.relativeVolume=EAGOLD_R10V2TicketRelativeVolume(t,dirLots);

   t.structuralPosition=0;
}

bool EAGOLD_R10V2TicketEligible(const EAGOLD_R10V2Ticket &t,
                                 EAGOLD_R10V2Opportunity opportunity)
{
   if(t.ticket<0 || t.lots<Lot)return(false);

   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT ||
      opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
   {
      // Position/directional adjustment targets adverse exposure.
      if(t.floatingProfit>=0.0)return(false);
   }

   return(true);
}

bool EAGOLD_R10V2BetterTarget(const EAGOLD_R10V2Ticket &a,
                              const EAGOLD_R10V2Ticket &b,
                              EAGOLD_R10V2SelectionPolicy policy)
{
   if(b.ticket<0)return(true);

   if(policy==EAGOLD_R10V2_POLICY_FARTHEST)
      return(a.distanceToMarket>b.distanceToMarket);

   if(policy==EAGOLD_R10V2_POLICY_WORST_LOSS)
      return(a.floatingProfit<b.floatingProfit);

   if(policy==EAGOLD_R10V2_POLICY_LOSS_PER_LOT)
      return(a.lossPerLot>b.lossPerLot);

   if(policy==EAGOLD_R10V2_POLICY_RECOVERY_LOAD)
      return(a.recoveryLoad>b.recoveryLoad);

   if(policy==EAGOLD_R10V2_POLICY_CONCENTRATION)
      return(a.relativeVolume>b.relativeVolume);

   if(policy==EAGOLD_R10V2_POLICY_STRUCTURAL_IMPACT)
      return(a.distanceToMarket>b.distanceToMarket);

   return(false);
}

EAGOLD_R10V2SelectionPolicy EAGOLD_R10V2PolicyForOpportunity(
   EAGOLD_R10V2Opportunity opportunity)
{
   if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      return(EAGOLD_R10V2_POLICY_BALANCED);

   if(opportunity==EAGOLD_R10V2_OPP_POSITION_ADJUSTMENT)
      return(EAGOLD_R10V2_POLICY_STRUCTURAL_IMPACT);

   if(opportunity==EAGOLD_R10V2_OPP_DIRECTIONAL_REDUCTION)
      return(EAGOLD_R10V2_POLICY_WORST_LOSS);

   return(EAGOLD_R10V2_POLICY_NONE);
}

void EAGOLD_R10V2SelectTarget(const EAGOLD_R10V2Context &ctx,
                              EAGOLD_R10V2Opportunity opportunity,
                              EAGOLD_R10V2Target &target)
{
   target.found=false;
   target.ticket=-1;
   target.direction=0;
   target.candidateLots=0.0;
   target.floatingProfit=0.0;
   target.lossPerLot=0.0;
   target.distanceToMarket=0.0;
   target.recoveryLoad=0.0;
   target.relativeVolume=0.0;
   target.structuralPosition=0;

   target.policy=EAGOLD_R10V2PolicyForOpportunity(opportunity);

   if(opportunity==EAGOLD_R10V2_OPP_NONE)return;

   EAGOLD_R10V2Ticket best;
   EAGOLD_R10V2TicketReset(best);

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;

      EAGOLD_R10V2Ticket candidate;
      EAGOLD_R10V2BuildTicket(ctx,candidate);

      if(!EAGOLD_R10V2TicketEligible(candidate,opportunity))continue;

      if(opportunity==EAGOLD_R10V2_OPP_BALANCED_REDUCTION)
      {
         // Balanced selection is deliberately restricted to the
         // heavier direction; the opposite ticket is resolved by
         // the later pair-selection/capacity stage.
         if(candidate.direction!=HeavyDirection())continue;
      }

      if(!target.found || EAGOLD_R10V2BetterTarget(candidate,best,target.policy))
      {
         best=candidate;
         target.found=true;
      }
   }

   if(!target.found)return;

   target.ticket=best.ticket;
   target.direction=best.direction;
   target.candidateLots=best.lots;
   target.floatingProfit=best.floatingProfit;
   target.lossPerLot=best.lossPerLot;
   target.distanceToMarket=best.distanceToMarket;
   target.recoveryLoad=best.recoveryLoad;
   target.relativeVolume=best.relativeVolume;
   target.structuralPosition=best.structuralPosition;
}

#endif
