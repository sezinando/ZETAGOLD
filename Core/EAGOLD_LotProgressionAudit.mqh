#ifndef EAGOLD_LOT_PROGRESSION_AUDIT_MQH
#define EAGOLD_LOT_PROGRESSION_AUDIT_MQH

// ETAPA 13.46-A — deterministic lot progression audit.
// Read-only. No broker access and no order mutation.
// Validates the configured mathematical progression independently
// from R11's later exposure adjustment.

double EAGOLD_AuditNormalizeLot(double lot)
{
   if(lot<Lot) lot=Lot;
   if(MaxOpenLot>0.0 && lot>MaxOpenLot) lot=MaxOpenLot;
   return(NormalizeDouble(lot,DigitsLots));
}

void EAGOLD_RunLotProgressionAudit()
{
   Print(EA_NAME,
      " LOT PROGRESSION AUDIT START | Lot=",DoubleToString(Lot,DigitsLots),
      " Multiplier=",DoubleToString(Multiplier,4),
      " LotIncrement=",DoubleToString(LotIncrement,4),
      " DigitsLots=",DigitsLots,
      " MaxOpenLot=",DoubleToString(MaxOpenLot,DigitsLots));

   double previous=EAGOLD_AuditNormalizeLot(Lot);
   bool monotonic=true;
   bool formulaOk=true;

   for(int level=1;level<=20;level++)
   {
      double raw=previous*Multiplier+LotIncrement;
      double next=EAGOLD_AuditNormalizeLot(raw);

      if(next+0.0000001<previous)
         monotonic=false;

      if(LotIncrement==0.0 && MathAbs(raw-previous*Multiplier)>0.0000001)
         formulaOk=false;

      Print(EA_NAME,
         " LOT AUDIT | level=",level,
         " previous=",DoubleToString(previous,DigitsLots),
         " raw=",DoubleToString(raw,6),
         " normalized=",DoubleToString(next,DigitsLots));

      previous=next;
   }

   Print(EA_NAME,
      " LOT PROGRESSION AUDIT RESULT | monotonic=",monotonic?"PASS":"FAIL",
      " multiplicativeFormula=",formulaOk?"PASS":"FAIL",
      " brokerAdjustment=SEPARATE_R11_STAGE");
}

#endif
