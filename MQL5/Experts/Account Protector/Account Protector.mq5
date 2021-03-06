//+------------------------------------------------------------------+
//|                                            Account Protector.mq5 |
//| 				                 Copyright © 2017-2019, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-expert-advisors/Account-Protector/"
#property version   "1.03"
string    Version = "1.03";
#property strict

#property description "Protects account balance by applying given actions when set condtions trigger."
#property description "Trails stop-losses, applies breakeven, logs its actions, sends notifications.\r\n"
#property description "WARNING: There is no guarantee that the expert advisor will work as intended. Use at your own risk."

#include "Account Protector.mqh";

input int Slippage = 2; // Slippage
input string LogFileName = "log.txt"; // Log file name
input Enable EnableEmergencyButton = No; // Enable emergency button
input bool PanelOnTopOfChart = true; // PanelOnTopOfChart: Draw chart as background?
input bool DoNotResetConditions = false; // DoNotResetConditions: if true, condition won't be reset on trigger.
input bool DoNotResetActions = false; // DoNotResetActions: if true, actions won't be reset on trigger.

CAccountProtector ExtDialog;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+ 
int OnInit()
{
   if (!ExtDialog.LoadSettingsFromDisk())
   {
	   sets.CountCommSwaps = true;
	   sets.UseTimer = false;
	   sets.Timer = TimeToString(TimeCurrent() - 7200, TIME_MINUTES);
      sets.TimeLeft = "";
      sets.intTimeType = 0;
      sets.boolTrailingStart = false;
      sets.intTrailingStart = 0;
      sets.boolTrailingStep = false;
      sets.intTrailingStep = 0;
      sets.boolBreakEven = false;
      sets.intBreakEven = 0;
      sets.boolBreakEvenExtra = false;
      sets.intBreakEvenExtra = 0;
      sets.boolEquityTrailingStop = false;
      sets.doubleEquityTrailingStop = 0;
      sets.doubleCurrentEquityStopLoss = 0;
      sets.SnapEquity = AccountInfoDouble(ACCOUNT_EQUITY); 
	   sets.SnapEquityTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
	   sets.SnapMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
	   sets.SnapMarginTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
	   sets.OrderCommentary = "";
	   sets.intOrderCommentaryCondition = 0;
	   sets.MagicNumbers = "";
		sets.boolExcludeMagics = false;
		sets.intInstrumentFilter = 0;
	   sets.boolLossPerBalance = false;
	   sets.boolLossQuanUnits = false;
	   sets.boolLossPips = false;
	   sets.boolProfPerBalance = false;
	   sets.boolProfQuanUnits = false;
	   sets.boolProfPips = false;
	   sets.boolEquityLessUnits = false;
	   sets.boolEquityGrUnits = false;
	   sets.boolEquityLessPerSnap = false;
	   sets.boolEquityGrPerSnap = false;
	   sets.boolMarginLessUnits = false;
	   sets.boolMarginGrUnits = false;
	   sets.boolMarginLessPerSnap = false;
	   sets.boolMarginGrPerSnap = false;
	   sets.doubleLossPerBalance = 0;
	   sets.doubleLossQuanUnits = 0;
	   sets.intLossPips = 0;
	   sets.doubleProfPerBalance = 0;
	   sets.doubleProfQuanUnits = 0;
	   sets.intProfPips = 0;
	   sets.doubleEquityLessUnits = 0;
	   sets.doubleEquityGrUnits = 0;
	   sets.doubleEquityLessPerSnap = 0;
	   sets.doubleEquityGrPerSnap = 0;
	   sets.doubleMarginLessUnits = 0;
	   sets.doubleMarginGrUnits = 0;
	   sets.doubleMarginLessPerSnap = 0;
	   sets.doubleMarginGrPerSnap = 0;
	   sets.ClosePos = true;
	   sets.intClosePercentage = 100;
	   sets.DeletePend = true;
	   sets.DisAuto = true;
	   sets.SendMails = false;
	   sets.SendNotif = false;
	   sets.ClosePlatform = false;	
      sets.SelectedTab = MainTab;

		ExtDialog.SilentLogging = true;
		ExtDialog.Logging("=====EA IS FIRST ATTACHED TO CHART=====");
		ExtDialog.Logging("Account Number = " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ", Client Name = " + AccountInfoString(ACCOUNT_NAME));
		ExtDialog.Logging("Server Name = " + AccountInfoString(ACCOUNT_SERVER) + ", Broker Name = " + AccountInfoString(ACCOUNT_COMPANY));
		ExtDialog.Logging("Account Currency = " + AccountInfoString(ACCOUNT_CURRENCY) + ", Account Leverage = " + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
		ExtDialog.Logging("Account Balance = " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", Account Credit = " + DoubleToString(AccountInfoDouble(ACCOUNT_CREDIT), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
		ExtDialog.Logging("Account Equity = " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", Account Free Margin = " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
		ExtDialog.Logging("Account Margin Call / Stop-Out Mode = " + EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)));
		string units;
		int decimal_places;
		if (AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE) == ACCOUNT_STOPOUT_MODE_PERCENT)
		{
			units = "%";
			decimal_places = 0;
		}
		else
		{
			units = AccountInfoString(ACCOUNT_CURRENCY);
			decimal_places = 2;
		}
		ExtDialog.Logging("Account Margin Call Level = " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), decimal_places) + units + ", Account Margin Stopout Level = " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), decimal_places) + units);
		ExtDialog.Logging("Enable Emergency Button = " + EnumToString((Enable)EnableEmergencyButton));
		ExtDialog.SilentLogging = false;

      sets.Triggered = false;
      sets.TriggeredTime = "";
   }  
	
   ExtDialog.AccountCurrencyDigits = (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);

	if ((!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) || (!MQLInfoInteger(MQL_TRADE_ALLOWED)))
	{
		Alert("AutoTrading is disabled! EA will be not able to perform trading operations!");
		sets.ClosePos = false;
		sets.DeletePend = false;
		sets.DisAuto = false;
		sets.boolTrailingStart = false;
		sets.boolTrailingStep = false;
		sets.boolBreakEven = false;
		sets.boolBreakEvenExtra = false;
	}
	if (!MQLInfoInteger(MQL_DLLS_ALLOWED))
	{
		Alert("DLLs are not allowed! EA will be unable to turn AutoTrading off!");
		sets.DisAuto = false;
	}   

   EventSetTimer(5);
   if (!ExtDialog.Create(0, Symbol() + " Account Protector (ver. " + Version + ")", 0, 20, 20)) return(-1);
   ExtDialog.Run();
   ExtDialog.IniFileLoad();

   // Brings panel on top of other objects without actual maximization of the panel.
   ExtDialog.HideShowMaximize(false);
	ExtDialog.ShowSelectedTab();
	ExtDialog.RefreshPanelControls();
   ExtDialog.RefreshValues();

	ChartSetInteger(0, CHART_FOREGROUND, !PanelOnTopOfChart);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+  
void OnDeinit(const int reason)
{
   if ((reason == REASON_REMOVE) || (reason == REASON_CHARTCLOSE) || (reason == REASON_PROGRAM))
   {
		ExtDialog.DeleteSettingsFile();
		Print("Trying to delete ini file.");
		if (!FileIsExist(ExtDialog.IniFileName() + ".dat")) Print("File doesn't exist.");
		else if (!FileDelete(ExtDialog.IniFileName() + ".dat")) Print("Failed to delete file: " + ExtDialog.IniFileName() + ".dat. Error: " + IntegerToString(GetLastError()));
      else Print("Deleted ini file successfully.");
		ExtDialog.SilentLogging = true;
		ExtDialog.Logging("EA Account Protector is removed.");
		ExtDialog.Logging("Account Balance = " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", Account Credit = " + DoubleToString(AccountInfoDouble(ACCOUNT_CREDIT), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
		ExtDialog.Logging("Account Equity = " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", Account Free Margin = " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
		ExtDialog.SilentLogging = false;
		ExtDialog.Logging_Current_Settings();
   }  
   else
   {
		ExtDialog.SaveSettingsOnDisk();
		ExtDialog.IniFileSave();
   } 
   ExtDialog.Destroy();
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Remember the panel's location to have the same location for minimized and maximized states.
   if ((id == CHARTEVENT_CUSTOM + ON_DRAG_END) && (lparam == -1))
   {
      ExtDialog.remember_top = ExtDialog.Top();
      ExtDialog.remember_left = ExtDialog.Left();
   }

	// Call Panel's event handler only if it is not a CHARTEVENT_CHART_CHANGE - workaround for minimization bug on chart switch.
   if (id != CHARTEVENT_CHART_CHANGE) ExtDialog.ChartEvent(id, lparam, dparam, sparam);
   
   if (ExtDialog.Top() < 0) ExtDialog.Move(ExtDialog.Left(), 0);
}

//+------------------------------------------------------------------+
//| Tick event handler                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   ExtDialog.RefreshValues();
   ExtDialog.Trailing();
   ExtDialog.EquityTrailing();
   ExtDialog.MoveToBreakEven();
   ExtDialog.CheckAllConditions();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   ExtDialog.RefreshValues();
   ExtDialog.Trailing();
   ExtDialog.EquityTrailing();
   ExtDialog.MoveToBreakEven();
   ExtDialog.CheckAllConditions();
   ChartRedraw();
}