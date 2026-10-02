#ifndef EAGOLD_CONFIG_MQH
#define EAGOLD_CONFIG_MQH
#define EAGOLD_VERSION "0.117"
#define EAGOLD_EXPIRY_DATE D'2026.12.31 00:00'
double g_panelMinProfit=0.0; double g_panelMaxProfit=0.0; double g_panelMaxLots=0.0; bool g_panelInitialized=false; bool EAGOLD_TradingAllowed(){return(TimeCurrent()<EAGOLD_EXPIRY_DATE);}
input string INPUT_GROUP_GENERAL="=== 01 GENERAL / IDENTITY ===";
// [01.01] MagicNumber
extern int P01_01_MagicNumber=1101;
// [01.02] RequireCleanLegacyOwnership
extern bool P01_02_RequireCleanLegacyOwnership=true;
// [01.03] EnableLegacyReattach
extern bool P01_03_EnableLegacyReattach=false;
input string INPUT_GROUP_MONEY="=== 02 CORE MONEY / LOT PROGRESSION ===";
// [02.01] Lot
extern double P02_01_Lot=0.01;
// [02.02] Multiplier
extern double P02_02_Multiplier=1.10;
// [02.03] DigitsLots
extern int P02_03_DigitsLots=2;
// [02.04] LotIncrement
extern double P02_04_LotIncrement=0.02;
// [02.05] MaxOpenLot
extern double P02_05_MaxOpenLot=3.00;
// [02.06] TakeProfit
extern double P02_06_TakeProfit=5.00;
// [02.09] SpreadLimit
extern int P02_09_SpreadLimit=100;
input string INPUT_GROUP_GRID="=== 02A CORE GRID / DISTANCES ===";
// [02A.01] FirstStep
extern double P02A_01_FirstStep=160.0;
// [02A.02] MiniGrid1
extern double P02A_02_MiniGrid1=320.0;
// [02A.03] SmartGrid1
extern double P02A_03_SmartGrid1=280.0;
// [02A.04] RecoveryMinDistance
extern double P02A_04_RecoveryMinDistance=340.0;
// [02A.05] MiniGrid2
extern double P02A_05_MiniGrid2=80.0;
// [02A.07] PendingStepTrail
extern double P02A_07_PendingStepTrail=50.0;
// [02A.08] BasketRestartStep
extern double P02A_08_BasketRestartStep=160.0; input string INPUT_GROUP_GLOBAL_TRAIL="=== 03 GLOBAL STOP TRAIL CONTROL ===";
// [03.09] EnableGlobalStopTrail
extern bool P03_09_EnableGlobalStopTrail=true;
// [03.10] GlobalStopTrailCooldownSeconds
extern double P03_10_GlobalStopTrailCooldownSeconds=0.0;
// [03.11] GlobalStopTrailMinStepPoints
extern double P03_11_GlobalStopTrailMinStepPoints=0.0;
input string INPUT_GROUP_BRX="=== 04 BRX / BASKET REALIZATION ===";
// [04.01] EnableBasketRealization
extern bool P04_01_EnableBasketRealization=true;
// [04.02] BRXRealizationMode
extern int P04_02_BRXRealizationMode=3;
// [04.03] BRXDirectionalMinProfit
extern double P04_03_BRXDirectionalMinProfit=5.00;
// [04.04] BRXBidirectionalMinProfit
extern double P04_04_BRXBidirectionalMinProfit=5.00;
// [04.05] BRXRealizationSafetyBuffer
extern double P04_05_BRXRealizationSafetyBuffer=5.00;
// [04.06] BRXRequireWeightedBE
extern bool P04_06_BRXRequireWeightedBE=false;
// [04.07] BRXWeightedBEBufferPoints
extern double P04_07_BRXWeightedBEBufferPoints=0.0;
input string INPUT_GROUP_R9="=== 05 R9 / EXPOSURE CONTROLLER ===";
// [05.01] EnableR9Hedge
extern bool P05_01_EnableR9Hedge=true;
// [05.02] R9ExposureTriggerLots
extern double P05_02_R9ExposureTriggerLots=1.00;
// [05.04] R9HedgeFraction
extern double P05_04_R9HedgeFraction=0.6666666667;
// [05.05] R9BalanceCap
extern double P05_05_R9BalanceCap=0.50;
input string INPUT_GROUP_R10="=== 05 R10 / EXPOSURE REDUCTION ===";
// [05.06] EnableR10Reduce
extern bool P05_06_EnableR10Reduce=true;
// [05.07] R10MinExposureLots
extern double P05_07_R10MinExposureLots=0.01;
// [05.08] EnableR10PairReduction
extern bool P05_08_EnableR10PairReduction=true;
// [05.09] R10PairMinProfit
extern double P05_09_R10PairMinProfit=5.00;
// [05.10] R10PairMaxLots
extern double P05_10_R10PairMaxLots=1.00;
// [05.11] R10PairCooldownSeconds
extern int P05_11_R10PairCooldownSeconds=30;
input string INPUT_GROUP_R11="=== 05 R11 / RECOVERY STEP & EXPOSURE GOVERNOR ===";
// [05.17] EnableRecoveryStepMultiplier
extern bool P05_17_EnableRecoveryStepMultiplier=true;
// [05.18] RecoveryStepMultiplier
extern double P05_18_RecoveryStepMultiplier=1.15;
// [05.19] RecoveryStepMax
extern double P05_19_RecoveryStepMax=500.0;
// [05.20] EnableR11ExposureGovernor
extern bool P05_20_EnableR11ExposureGovernor=true;
// [05.21] R11TaperStartGrossExposureLots
extern double P05_21_R11TaperStartGrossExposureLots=8.00;
// [05.22] R11BlockGrossExposureLots
extern double P05_22_R11BlockGrossExposureLots=12.00;
// [05.23] R11MinNetToGrossRatio
extern double P05_23_R11MinNetToGrossRatio=0.10;
// [05.24] R11MinRecoveryLotFactor
extern double P05_24_R11MinRecoveryLotFactor=0.25;
input string INPUT_GROUP_ENGINE_MARKERS="=== 07 ENGINE ACTION MARKERS ===";
// [07.07] EnableEngineActionMarkers
extern bool P07_07_EnableEngineActionMarkers=true;
input string INPUT_GROUP_R10_MARKERS="=== 07 R10 / ACTION MARKERS ===";
// [07.01] EnableR10VisualMarker
extern bool P07_01_EnableR10VisualMarker=true;
// [07.03] R10MarkerFontSize
extern int P07_03_R10MarkerFontSize=9;
// [07.04] R10BuyMarkerColor
extern color P07_04_R10BuyMarkerColor=clrLime;
// [07.05] R10SellMarkerColor
extern color P07_05_R10SellMarkerColor=clrTomato;
// [07.06] R10MarkerOffsetPoints
extern double P07_06_R10MarkerOffsetPoints=25.0;
input string INPUT_GROUP_PANEL="=== 07 MODULAR PANEL / DEBUG ===";
// [07.14] EnableModularizationPanel
extern bool P07_14_EnableModularizationPanel=true;
// [07.15] EnableModularizationDebug
extern bool P07_15_EnableModularizationDebug=false;
input string INPUT_GROUP_CHART_GUIDES="=== 07 CHART BASKET GUIDES ===";
// [07.16] EnableChartBasketGuides
extern bool P07_16_EnableChartBasketGuides=true;
// [07.17] ChartBasketGuideOffsetBars
extern int P07_17_ChartBasketGuideOffsetBars=2;
input string INPUT_GROUP_UI="=== 07 UI / PANEL LAYOUT ===";
// [07.26] PanelBackgroundWidth
extern int P07_26_PanelBackgroundWidth=430;

// -----------------------------------------------------------------------------
// Indexed input names exposed in the MT4 Inputs window.
// Internal source compatibility is preserved through aliases.
// -----------------------------------------------------------------------------
#define MagicNumber P01_01_MagicNumber
#define RequireCleanLegacyOwnership P01_02_RequireCleanLegacyOwnership
#define EnableLegacyReattach P01_03_EnableLegacyReattach
#define Lot P02_01_Lot
#define Multiplier P02_02_Multiplier
#define DigitsLots P02_03_DigitsLots
#define LotIncrement P02_04_LotIncrement
#define MaxOpenLot P02_05_MaxOpenLot
#define TakeProfit P02_06_TakeProfit
#define SpreadLimit P02_09_SpreadLimit
#define FirstStep P02A_01_FirstStep
#define MiniGrid1 P02A_02_MiniGrid1
#define SmartGrid1 P02A_03_SmartGrid1
#define RecoveryMinDistance P02A_04_RecoveryMinDistance
#define MiniGrid2 P02A_05_MiniGrid2
#define PendingStepTrail P02A_07_PendingStepTrail
#define BasketRestartStep P02A_08_BasketRestartStep
#define EnableGlobalStopTrail P03_09_EnableGlobalStopTrail
#define GlobalStopTrailCooldownSeconds P03_10_GlobalStopTrailCooldownSeconds
#define GlobalStopTrailMinStepPoints P03_11_GlobalStopTrailMinStepPoints
#define EnableBasketRealization P04_01_EnableBasketRealization
#define BRXRealizationMode P04_02_BRXRealizationMode
#define BRXDirectionalMinProfit P04_03_BRXDirectionalMinProfit
#define BRXBidirectionalMinProfit P04_04_BRXBidirectionalMinProfit
#define BRXRealizationSafetyBuffer P04_05_BRXRealizationSafetyBuffer
#define BRXRequireWeightedBE P04_06_BRXRequireWeightedBE
#define BRXWeightedBEBufferPoints P04_07_BRXWeightedBEBufferPoints
#define EnableR9Hedge P05_01_EnableR9Hedge
#define R9ExposureTriggerLots P05_02_R9ExposureTriggerLots
#define R9HedgeFraction P05_04_R9HedgeFraction
#define R9BalanceCap P05_05_R9BalanceCap
#define EnableR10Reduce P05_06_EnableR10Reduce
#define R10MinExposureLots P05_07_R10MinExposureLots
#define EnableR10PairReduction P05_08_EnableR10PairReduction
#define R10PairMinProfit P05_09_R10PairMinProfit
#define R10PairMaxLots P05_10_R10PairMaxLots
#define R10PairCooldownSeconds P05_11_R10PairCooldownSeconds
#define EnableR10VisualMarker P07_01_EnableR10VisualMarker
#define R10MarkerFontSize P07_03_R10MarkerFontSize
#define R10BuyMarkerColor P07_04_R10BuyMarkerColor
#define R10SellMarkerColor P07_05_R10SellMarkerColor
#define R10MarkerOffsetPoints P07_06_R10MarkerOffsetPoints
#define EnableRecoveryStepMultiplier P05_17_EnableRecoveryStepMultiplier
#define RecoveryStepMultiplier P05_18_RecoveryStepMultiplier
#define RecoveryStepMax P05_19_RecoveryStepMax
#define EnableR11ExposureGovernor P05_20_EnableR11ExposureGovernor
#define R11TaperStartGrossExposureLots P05_21_R11TaperStartGrossExposureLots
#define R11BlockGrossExposureLots P05_22_R11BlockGrossExposureLots
#define R11MinNetToGrossRatio P05_23_R11MinNetToGrossRatio
#define R11MinRecoveryLotFactor P05_24_R11MinRecoveryLotFactor
#define EnableEngineActionMarkers P07_07_EnableEngineActionMarkers
#define EnableModularizationPanel P07_14_EnableModularizationPanel
#define EnableModularizationDebug P07_15_EnableModularizationDebug
#define EnableChartBasketGuides P07_16_EnableChartBasketGuides
#define ChartBasketGuideOffsetBars P07_17_ChartBasketGuideOffsetBars
#define PanelBackgroundWidth P07_26_PanelBackgroundWidth
#endif