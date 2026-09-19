#ifndef EAGOLD_R10_V2_CALIBRATION_MQH
#define EAGOLD_R10_V2_CALIBRATION_MQH

//==================================================================
// R10 v2 — ETAPA 13.35 CALIBRATION
//
// Deterministic parameter sensitivity laboratory.
// No broker mutation, no capital reservation, no R11 mutation,
// no CSV and no live execution.
//
// Purpose:
//   expose how the principal R10 v2 controls alter candidate,
//   desired, gross-relief and capital demand for the same
//   in-memory scenario.
//
// This is sensitivity analysis, not optimization.
// It deliberately does not select a "best" parameter.
//==================================================================

struct EAGOLD_R10V2CalibrationRow
{
   double ratio;
   double candidateLots;
   double desiredLots;
   double authorizedLots;
   double grossRelief;
   double capitalRequired;
   bool   valid;
};

struct EAGOLD_R10V2CalibrationResult
{
   int rows;
   int validRows;
   int rejectedRows;
   double minimumGrossRelief;
   double maximumGrossRelief;
   double minimumCapitalRequired;
   double maximumCapitalRequired;
   double minimumAuthorizedLots;
   double maximumAuthorizedLots;
};

void EAGOLD_R10V2CalibrationRowReset(EAGOLD_R10V2CalibrationRow &r)
{
   r.ratio=0.0;
   r.candidateLots=0.0;
   r.desiredLots=0.0;
   r.authorizedLots=0.0;
   r.grossRelief=0.0;
   r.capitalRequired=0.0;
   r.valid=false;
}

bool EAGOLD_R10V2CalibrationProjectBalanced(
   double buyLots,
   double sellLots,
   double buyProfit,
   double sellProfit,
   double ratio,
   double maxReductionLots,
   double &reductionLots,
   double &grossRelief,
   double &capitalRequired)
{
   reductionLots=0.0;
   grossRelief=0.0;
   capitalRequired=0.0;

   if(buyLots<0.0 || sellLots<0.0 || ratio<=0.0)
      return(false);

   double candidate=MathMin(buyLots,sellLots);
   if(candidate<Lot)
      return(false);

   double desired=candidate*ratio;
   if(maxReductionLots>0.0)
      desired=MathMin(desired,maxReductionLots);

   double normalized=NormalizeLot(desired);
   if(normalized<Lot || normalized>candidate+Lot*0.5)
      return(false);

   reductionLots=normalized;
   grossRelief=2.0*reductionLots;

   double buyPerLot=(buyLots>0.0?buyProfit/buyLots:0.0);
   double sellPerLot=(sellLots>0.0?sellProfit/sellLots:0.0);
   capitalRequired=MathMax(0.0,-reductionLots*(buyPerLot+sellPerLot));

   return(grossRelief>0.0);
}

void EAGOLD_R10V2CalibrationRun()
{
   // Fixed scenario: identical state for every row.
   // BUY 10 / SELL 8 preserves NET +2 under Balanced Reduction.
   double buyLots=10.0;
   double sellLots=8.0;
   double buyProfit=20.0;
   double sellProfit=-60.0;

   double ratios[6];
   ratios[0]=0.25;
   ratios[1]=0.20;
   ratios[2]=1.0/6.0;
   ratios[3]=1.0/7.0;
   ratios[4]=0.125;
   ratios[5]=0.10;

   EAGOLD_R10V2CalibrationResult summary;
   summary.rows=0;
   summary.validRows=0;
   summary.rejectedRows=0;
   summary.minimumGrossRelief=0.0;
   summary.maximumGrossRelief=0.0;
   summary.minimumCapitalRequired=0.0;
   summary.maximumCapitalRequired=0.0;
   summary.minimumAuthorizedLots=0.0;
   summary.maximumAuthorizedLots=0.0;

   Print(EA_NAME," R10 v2 CALIBRATION BEGIN scenario BUY=10 SELL=8");

   for(int i=0;i<6;i++)
   {
      EAGOLD_R10V2CalibrationRow row;
      EAGOLD_R10V2CalibrationRowReset(row);
      row.ratio=ratios[i];
      row.candidateLots=MathMin(buyLots,sellLots);

      double reduction=0.0;
      bool ok=EAGOLD_R10V2CalibrationProjectBalanced(
         buyLots,sellLots,buyProfit,sellProfit,
         row.ratio,R10V2MaxReductionLots,
         reduction,row.grossRelief,row.capitalRequired);

      row.desiredLots=reduction;
      row.authorizedLots=0.0;
      row.valid=ok;

      summary.rows++;
      if(ok)
      {
         summary.validRows++;
         row.authorizedLots=reduction;
         if(summary.minimumGrossRelief<=0.0 || row.grossRelief<summary.minimumGrossRelief)
            summary.minimumGrossRelief=row.grossRelief;
         if(row.grossRelief>summary.maximumGrossRelief)
            summary.maximumGrossRelief=row.grossRelief;
         if(summary.minimumCapitalRequired<=0.0 || row.capitalRequired<summary.minimumCapitalRequired)
            summary.minimumCapitalRequired=row.capitalRequired;
         if(row.capitalRequired>summary.maximumCapitalRequired)
            summary.maximumCapitalRequired=row.capitalRequired;
         if(summary.minimumAuthorizedLots<=0.0 || row.authorizedLots<summary.minimumAuthorizedLots)
            summary.minimumAuthorizedLots=row.authorizedLots;
         if(row.authorizedLots>summary.maximumAuthorizedLots)
            summary.maximumAuthorizedLots=row.authorizedLots;
      }
      else
         summary.rejectedRows++;

      Print(EA_NAME,
            " R10 v2 CALIBRATION ratio=",DoubleToString(row.ratio,6),
            " candidate=",DoubleToString(row.candidateLots,DigitsLots),
            " desired=",DoubleToString(row.desiredLots,DigitsLots),
            " authorized=",DoubleToString(row.authorizedLots,DigitsLots),
            " grossRelief=",DoubleToString(row.grossRelief,DigitsLots),
            " capital=",DoubleToString(row.capitalRequired,2),
            " result=",ok ? "VALID" : "REJECTED");
   }

   Print(EA_NAME,
         " R10 v2 CALIBRATION SUMMARY rows=",summary.rows,
         " valid=",summary.validRows,
         " rejected=",summary.rejectedRows,
         " grossRelief[min,max]=",
         DoubleToString(summary.minimumGrossRelief,DigitsLots),",",
         DoubleToString(summary.maximumGrossRelief,DigitsLots),
         " capital[min,max]=",
         DoubleToString(summary.minimumCapitalRequired,2),",",
         DoubleToString(summary.maximumCapitalRequired,2),
         " authorizedLots[min,max]=",
         DoubleToString(summary.minimumAuthorizedLots,DigitsLots),",",
         DoubleToString(summary.maximumAuthorizedLots,DigitsLots));
}

#endif
