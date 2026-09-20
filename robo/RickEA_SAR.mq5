//+------------------------------------------------------------------+
//|                                                   RickEA_SAR.mq5 |
//|                                 Copyright © 2006, RichardTrader. |
//|                                         Instagram:@ri.chartrader |
//|                                                                  |
//|  Parabolic SAR + filtro ADX, entrada na abertura da vela nova,    |
//|  uma posicao por vez, SL/TP fixos e breakeven.                   |
//|  Visual RickEA: preco grande no canto superior direito, painel   |
//|  com fundo de pouca opacidade na cor da tendencia e a logo       |
//|  inteira no fundo do grafico.                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2006, RichardTrader."
#property link      "Instagram:@ri.chartrader"
#property version   "2.00"
#property description "RickEA SAR - Parabolic SAR + ADX com painel e visual RickEA."
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Expert\Money\MoneyFixedRisk.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CMoneyFixedRisk *m_money;
//--- input parameters
input group "=== OPERACIONAL ==="
input ushort   InpStopLoss       = 150;      // Stop Loss (in pips)
input ushort   InpTakeProfit     = 250;      // Take Profit (in pips)
input double   Risk              = 0.10;     // Risk in percent for a deal
input ushort   InpBreakeven      = 100;      // Breakeven (in pips)
input int      ADX_adx_period    = 14;       // ADX: averaging period
input int      ADX_max           = 20;       // ADX: so entra abaixo deste valor
input double   SAR_step          = 0.02;     // SAR: price increment step - acceleration factor
input double   SAR_maximum       = 0.2;      // SAR: maximum value of step
input ulong    InpMagic          = 7898998;  // Magic number
input ulong    InpSlippage       = 10;       // Desvio maximo (pontos)
input string   EA_NAME           = "RickEA SAR"; // Nome no painel

input group "=== VISUAL ==="
input bool     Visual_Enable     = true;     // Ligar o visual
input bool     BigPrice_Show     = true;     // Preco grande (canto sup. direito)
input int      BigPrice_Size     = 30;       // Tamanho da fonte do preco grande
input bool     BigPrice_ByTrend  = true;     // Preco na cor da tendencia
input color    BigPrice_Fixed    = clrGold;  // Cor fixa (se ByTrend = false)
input bool     Panel_Show        = true;     // Painel de status
input int      Panel_Opacity     = 18;       // Opacidade do fundo do painel (%)
input int      Panel_X           = 12;       // Painel: margem a direita (px)
input int      Panel_Y           = 12;       // Painel: margem do topo (px)
input int      Panel_Width       = 300;      // Painel: largura (px)
input color    Panel_TrendUp     = clrLime;  // Cor da tendencia de alta
input color    Panel_TrendDown   = clrRed;   // Cor da tendencia de baixa
input bool     Logo_Show         = true;     // Logo inteira no fundo do grafico
input bool     Logo_AutoSize     = true;     // Escolher o tamanho da logo pelo grafico
input int      Logo_Fill         = 85;       // Quanto da altura do grafico a logo ocupa (%)
input bool     Logo_Dark         = false;    // Usar a versao _dark (se o alfa nao renderizar)
input string   Logo_File         = "RickEA_Logo_768.bmp"; // Arquivo (quando AutoSize = false)
input int      Logo_FileSize     = 768;      // Tamanho desse arquivo em px
//---
ulong          m_ticket;
ulong          m_magic=7898998;              // magic number
ulong          m_slippage=10;                // slippage

double         ExtStopLoss=0.0;
double         ExtTakeProfit=0.0;
double         ExtBreakeven=0.0;

int            handle_iADX;                  // variable for storing the handle of the iADX indicator
int            handle_iSAR;                  // variable for storing the handle of the iSAR indicator

long           cmd=-1;                       // signal to open a new position, "-1" -> initialization

double         m_adjusted_point;             // point value adjusted for 3 or 5 points

//--- visual
string         PFX="RSAR_";
int            g_trend=0;                    // +1 alta (SAR abaixo), -1 baixa (SAR acima)
double         g_sar=0.0, g_adx=0.0;
int            g_chartW=0, g_chartH=0;
bool           g_logoFailed=false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();
//---
   m_magic=InpMagic;
   m_slippage=InpSlippage;
   m_trade.SetExpertMagicNumber(m_magic);
//---
   if(IsFillingTypeAllowed(SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtStopLoss=InpStopLoss*m_adjusted_point;
   ExtTakeProfit=InpTakeProfit*m_adjusted_point;
   ExtBreakeven=InpBreakeven*m_adjusted_point;
//--- aviso: stop curto demais pro simbolo (tipico ao rodar o set de forex no ouro)
   if(ExtStopLoss>0.0)
     {
      double spread=m_symbol.Spread()*m_symbol.Point();
      if(spread>0.0 && ExtStopLoss<spread*5.0)
         PrintFormat("RickEA SAR: ATENCAO - Stop Loss de %s (%d pips) e muito curto para %s. "
                     "O spread atual sozinho ja e %s. Aumente InpStopLoss/InpTakeProfit.",
                     DoubleToString(ExtStopLoss,m_symbol.Digits()),InpStopLoss,
                     m_symbol.Name(),DoubleToString(spread,m_symbol.Digits()));
     }
//---
   if(m_money!=NULL)
      delete m_money;
   m_money=new CMoneyFixedRisk;
   if(m_money!=NULL)
     {
      if(!m_money.Init(GetPointer(m_symbol),Period(),m_symbol.Point()*digits_adjust))
         return(INIT_FAILED);
      m_money.Percent(Risk);
     }
   else
     {
      Print("Error create object CMoneyFixedRisk");
      return(INIT_FAILED);
     }
//--- create handle of the indicator iADX
   handle_iADX=iADX(m_symbol.Name(),Period(),ADX_adx_period);
//--- if the handle is not created
   if(handle_iADX==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iADX indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//--- create handle of the indicator iSAR
   handle_iSAR=iSAR(m_symbol.Name(),Period(),SAR_step,SAR_maximum);
//--- if the handle is not created
   if(handle_iSAR==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iSAR indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//---
   cmd=-1;  // signal to open a new position, "-1" -> initialization
//--- visual
   if(Visual_Enable)
     {
      g_chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      g_chartH=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      DrawLogo();
      EventSetTimer(1);
     }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0,PFX);
   ChartRedraw();
//---
   if(m_money!=NULL)
      delete m_money;
  }
//+------------------------------------------------------------------+
//| Timer - o painel respira mesmo sem tick                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!Visual_Enable) return;
   UpdateReadings();
   DrawVisuals();
  }
//+------------------------------------------------------------------+
//| Chart change - reposiciona a logo quando o grafico muda de tamanho|
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id!=CHARTEVENT_CHART_CHANGE || !Visual_Enable || !Logo_Show) return;

   int w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int h=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(w==g_chartW && h==g_chartH) return;

   g_chartW=w; g_chartH=h;
   DrawLogo();
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- o visual roda em todo tick; a estrategia so na vela nova
   if(Visual_Enable)
     {
      UpdateReadings();
      DrawVisuals();
     }
//--- we work only at the time of the birth of new bar
   static datetime PrevBars=0;
   datetime time_0=iTime(0);
   if(time_0==PrevBars)
      return;
   PrevBars=time_0;
//---
   int total=0;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            total++;
            if(ExtBreakeven!=0) // breakeven
              {
               if(m_position.PositionType()==POSITION_TYPE_BUY)
                 {
                  if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtBreakeven)
                     if(!CompareDoubles(m_position.StopLoss(),m_position.PriceOpen(),m_symbol.Digits()))
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           m_position.PriceOpen(),
                           m_position.TakeProfit()))
                           Print("Modify ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                        continue;
                       }
                 }
               else
                 {
                  if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtBreakeven)
                     if(!CompareDoubles(m_position.StopLoss(),m_position.PriceOpen(),m_symbol.Digits()))
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           m_position.PriceOpen(),
                           m_position.TakeProfit()))
                           Print("Modify ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                       }
                 }
              }

           }
//---
   if(total==0)
     {
      double sar=iSARGet(0);
      double adx=iADXGet(MAIN_LINE,0);
      double close=iClose(0);
      if(close==0.0)
        {
         PrevBars=iTime(1);
         return;
        }
      if(!RefreshRates())
        {
         PrevBars=iTime(1);
         return;
        }
      if((ENUM_DEAL_TYPE)cmd==DEAL_TYPE_BUY || cmd==-1)
        {
         //--- we wait when the trend rises a little and in the market everything will be quiet
         if((sar<close) && (adx<ADX_max))
           {
            //--- open BUY position
            double sl=(InpStopLoss==0)?0.0:m_symbol.Ask()-ExtStopLoss;
            double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+ExtTakeProfit;
            OpenBuy(sl,tp);
            return;
           }
        }
      else if((ENUM_DEAL_TYPE)cmd==DEAL_TYPE_SELL)
        {
         //--- we wait when the trend a little falls and in the market everything will be quiet
         if((sar>close) && (adx<ADX_max))
           {
            //--- open SELL position
            double sl=(InpStopLoss==0)?0.0:m_symbol.Bid()+ExtStopLoss;
            double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-ExtTakeProfit;
            OpenSell(sl,tp);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- get transaction type as enumeration value
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(type==TRADE_TRANSACTION_DEAL_ADD)
     {
      long     deal_type         =-1;
      long     deal_entry        =-1;
      long     deal_magic        =0;
      long     deal_reason       =-1;
      string   deal_symbol       ="";
      if(HistoryDealSelect(trans.deal))
        {
         deal_type         =HistoryDealGetInteger(trans.deal,DEAL_TYPE);
         deal_entry        =HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         deal_magic        =HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
         deal_reason       =HistoryDealGetInteger(trans.deal,DEAL_REASON);
         deal_symbol       =HistoryDealGetString(trans.deal,DEAL_SYMBOL);
        }
      else
         return;
      if(deal_symbol==m_symbol.Name() && deal_magic==m_magic)
         if(deal_entry==DEAL_ENTRY_OUT)
           {
            if((ENUM_DEAL_REASON)deal_reason==DEAL_REASON_TP)
              {
               //--- bateu o alvo: proxima entrada inverte o lado
               if((ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_BUY)
                  cmd=DEAL_TYPE_SELL;
               else if((ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_SELL)
                  cmd=DEAL_TYPE_BUY;
              }
            else if((ENUM_DEAL_REASON)deal_reason==DEAL_REASON_SL)
              {
               //--- bateu o stop: proxima entrada repete o lado
               if((ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_BUY)
                  cmd=DEAL_TYPE_BUY;
               else if((ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_SELL)
                  cmd=DEAL_TYPE_SELL;
              }
           }
     }
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes
   int filling=m_symbol.TradeFillFlags();
//--- Return true, if mode fill_type is allowed
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| Get Close for specified bar index                                |
//+------------------------------------------------------------------+
double iClose(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=m_symbol.Name();
   if(timeframe==0)
      timeframe=Period();
   double Close[1];
   double close=0;
   int copied=CopyClose(symbol,timeframe,index,1,Close);
   if(copied>0)
      close=Close[0];
   return(close);
  }
//+------------------------------------------------------------------+
//| Get Time for specified bar index                                 |
//+------------------------------------------------------------------+
datetime iTime(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=m_symbol.Name();
   if(timeframe==0)
      timeframe=Period();
   datetime Time[1];
   datetime time=0;
   int copied=CopyTime(symbol,timeframe,index,1,Time);
   if(copied>0)
      time=Time[0];
   return(time);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iADX                                |
//|  the buffer numbers are the following:                           |
//|    0 - MAIN_LINE, 1 - PLUSDI_LINE, 2 - MINUSDI_LINE              |
//+------------------------------------------------------------------+
double iADXGet(const int buffer,const int index)
  {
   double ADX[1];
//--- reset error code
   ResetLastError();
//--- fill a part of the iADXBuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(handle_iADX,buffer,index,1,ADX)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iADX indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(0.0);
     }
   return(ADX[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iSAR                                |
//+------------------------------------------------------------------+
double iSARGet(const int index)
  {
   double SAR[1];
//--- reset error code
   ResetLastError();
//--- fill a part of the iSARBuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(handle_iSAR,0,index,1,SAR)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iSAR indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(0.0);
     }
   return(SAR[0]);
  }
//+------------------------------------------------------------------+
//| Compare doubles                                                  |
//+------------------------------------------------------------------+
bool CompareDoubles(double number1,double number2,int digits)
  {
   if(NormalizeDouble(number1-number2,digits)==0)
      return(true);
   else
      return(false);
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);
   if(check_open_long_lot==0.0)
      return;

//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_long_lot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_long_lot)
        {
         if(m_trade.Buy(check_open_long_lot,NULL,m_symbol.Ask(),sl,tp,EA_NAME))
           {
            if(m_trade.ResultDeal()==0)
               Print("RickEA SAR#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
           }
         else
            Print("RickEA SAR#3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);
   if(check_open_short_lot==0.0)
      return;

//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_short_lot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_short_lot)
        {
         if(m_trade.Sell(check_open_short_lot,NULL,m_symbol.Bid(),sl,tp,EA_NAME))
           {
            if(m_trade.ResultDeal()==0)
               Print("RickEA SAR#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
           }
         else
            Print("RickEA SAR#3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
        }
//---
  }
//+==================================================================+
//|                            VISUAL                                |
//+==================================================================+
void UpdateReadings()
  {
   g_sar=iSARGet(0);
   g_adx=iADXGet(MAIN_LINE,0);

   double px=m_symbol.Bid();
   if(px<=0.0 || g_sar<=0.0) return;
   g_trend=(g_sar<px)?1:((g_sar>px)?-1:0);
  }
//+------------------------------------------------------------------+
color ChartBg()
  {
   return((color)ChartGetInteger(0,CHART_COLOR_BACKGROUND));
  }
//+------------------------------------------------------------------+
color Blend(const color fg,const color bg,const double alpha)
  {
   double a=MathMax(0.0,MathMin(1.0,alpha));
   int fr=(int)(fg & 0xFF), fgn=(int)((fg>>8) & 0xFF), fb=(int)((fg>>16) & 0xFF);
   int br=(int)(bg & 0xFF), bgn=(int)((bg>>8) & 0xFF), bb=(int)((bg>>16) & 0xFF);

   int r=(int)(fr*a+br*(1.0-a));
   int g=(int)(fgn*a+bgn*(1.0-a));
   int b=(int)(fb*a+bb*(1.0-a));
   return((color)((b<<16)|(g<<8)|r));
  }
//+------------------------------------------------------------------+
color TrendColor()
  {
   if(g_trend>0) return(Panel_TrendUp);
   if(g_trend<0) return(Panel_TrendDown);
   return(clrSilver);
  }
//+------------------------------------------------------------------+
void DrawVisuals()
  {
   if(BigPrice_Show || Panel_Show) DrawPanel();
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Painel + preco grande no canto superior direito                  |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   color accent = TrendColor();
   color bg     = ChartBg();
   color fill   = Blend(accent,bg,Panel_Opacity/100.0);
   color head   = Blend(accent,bg,MathMin(1.0,(Panel_Opacity+14)/100.0));

   int pad    = 12;
   int headH  = 24;
   int priceH = (BigPrice_Show ? BigPrice_Size+16 : 0);
   int rowH   = 17;
   int rows   = 8;
   int panelH = headH+priceH+pad+rows*rowH+pad;

   // OBJ_RECTANGLE_LABEL com canto a direita mede a distancia ate a borda
   // ESQUERDA da caixa e cresce pra direita - por isso soma a largura aqui.
   int boxX=Panel_X+Panel_Width;
   Box(PFX+"BG",  boxX,Panel_Y,Panel_Width,panelH,fill,accent,true);
   Box(PFX+"HEAD",boxX,Panel_Y,Panel_Width,headH,head,accent,false);

   int xl=Panel_X+Panel_Width-pad;     // borda interna esquerda (canto = direita)
   int xr=Panel_X+pad;                 // borda interna direita
   int y =Panel_Y+5;

   Text(PFX+"T_BRAND",xl,y,EA_NAME,clrWhite,10,true,ANCHOR_LEFT_UPPER);
   Text(PFX+"T_SYM",  xr,y,m_symbol.Name()+" "+TFName(),Blend(clrWhite,bg,0.75),9,true,ANCHOR_RIGHT_UPPER);
   y+=headH;

   if(BigPrice_Show)
     {
      color pc=BigPrice_ByTrend?accent:BigPrice_Fixed;
      Text(PFX+"T_PRICE",xr,y+6,DoubleToString(m_symbol.Bid(),m_symbol.Digits()),pc,BigPrice_Size,true,ANCHOR_RIGHT_UPPER,"Arial Black");
      Text(PFX+"T_TREND",xl,y+6+BigPrice_Size/2-6,(g_trend>0?"ALTA":(g_trend<0?"BAIXA":"---")),pc,10,true,ANCHOR_LEFT_UPPER);
      y+=priceH;
     }
   y+=pad;

   //--- dados da posicao aberta
   int    total=0;
   string posTxt="nenhuma";
   double floating=0.0;
   color  posClr=clrSilver;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            total++;
            floating+=m_position.Profit()+m_position.Swap()+m_position.Commission();
            bool isBuy=(m_position.PositionType()==POSITION_TYPE_BUY);
            posTxt=StringFormat("%s %.2f @ %s",(isBuy?"BUY":"SELL"),m_position.Volume(),
                                DoubleToString(m_position.PriceOpen(),m_symbol.Digits()));
            posClr=(isBuy?Panel_TrendUp:Panel_TrendDown);
           }

   bool   adxOk =(g_adx<ADX_max);
   string nextTxt=(cmd==-1)?"qualquer lado":(((ENUM_DEAL_TYPE)cmd==DEAL_TYPE_BUY)?"COMPRA":"VENDA");
   color  nextClr=(cmd==-1)?clrWhite:(((ENUM_DEAL_TYPE)cmd==DEAL_TYPE_BUY)?Panel_TrendUp:Panel_TrendDown);

   Row(PFX+"R_SAR", StringFormat("SAR %.2f/%.1f",SAR_step,SAR_maximum),
                    DoubleToString(g_sar,m_symbol.Digits())+(g_trend>0?"  abaixo":"  acima"),
                    accent, xl,xr,y); y+=rowH;
   Row(PFX+"R_ADX", "ADX ("+(string)ADX_adx_period+")",
                    StringFormat("%.1f  %s",g_adx,(adxOk?"calmo":"forte")),
                    (adxOk?Panel_TrendUp:clrOrange), xl,xr,y); y+=rowH;
   Row(PFX+"R_FIL", "Filtro ADX < "+(string)ADX_max,
                    (adxOk?"LIBERADO":"BLOQUEADO"),
                    (adxOk?Panel_TrendUp:clrOrange), xl,xr,y); y+=rowH;
   Row(PFX+"R_NEXT","Proxima entrada", nextTxt, nextClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_POS", "Posicao", posTxt, posClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_SLTP","SL / TP",
                    StringFormat("%s / %s",DoubleToString(ExtStopLoss,m_symbol.Digits()),
                                 DoubleToString(ExtTakeProfit,m_symbol.Digits())),
                    clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_RISK","Risco / Lote",
                    StringFormat("%.2f%% / %.2f",Risk,NextLotPreview()),
                    clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_PL",  "Flutuante / Eq.",
                    StringFormat("%.2f / %.2f",floating,AccountInfoDouble(ACCOUNT_EQUITY)),
                    (floating>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y);
  }
//+------------------------------------------------------------------+
//| Lote que a proxima entrada usaria (so pra mostrar no painel)     |
//+------------------------------------------------------------------+
double NextLotPreview()
  {
   if(m_money==NULL || InpStopLoss==0) return(0.0);
   double ask=m_symbol.Ask();
   if(ask<=0.0) return(0.0);
   return(m_money.CheckOpenLong(ask,m_symbol.NormalizePrice(ask-ExtStopLoss)));
  }
//+------------------------------------------------------------------+
void Row(const string id,const string label,const string value,const color vclr,
         const int xl,const int xr,const int y)
  {
   Text(id+"_L",xl,y,label,Blend(clrWhite,ChartBg(),0.70),9,false,ANCHOR_LEFT_UPPER);
   Text(id+"_V",xr,y,value,vclr,9,true,ANCHOR_RIGHT_UPPER);
  }
//+------------------------------------------------------------------+
void Box(const string name,const int x,const int y,const int w,const int h,
         const color bg,const color border,const bool back)
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
  }
//+------------------------------------------------------------------+
void Text(const string name,const int x,const int y,const string txt,const color clr,
          const int size,const bool bold,const ENUM_ANCHOR_POINT anchor,
          const string font="Arial")
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
     }
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetString(0,name,OBJPROP_FONT,(font=="Arial" && bold)?"Arial Bold":font);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
  }
//+------------------------------------------------------------------+
//| Logo INTEIRA no fundo do grafico (uma so, centralizada)          |
//+------------------------------------------------------------------+
void DrawLogo()
  {
   string name=PFX+"LOGO";
   ObjectDelete(0,name);
   if(!Logo_Show || g_logoFailed) return;

   int w=(g_chartW>0)?g_chartW:(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int h=(g_chartH>0)?g_chartH:(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(w<=0 || h<=0) return;

   if(!ObjectCreate(0,name,OBJ_BITMAP_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);      // atras das velas

   //--- o MT5 recorta o BMP, nao redimensiona: escolhe o maior arquivo que cabe
   int size=0;
   if(Logo_AutoSize)
     {
      int cand[6]={1024,768,512,256,128,96};
      int want=(int)(MathMin(w,h)*MathMax(10,MathMin(100,Logo_Fill))/100.0);
      for(int i=0;i<6;i++)
        {
         if(cand[i]>want && i<5) continue;          // grande demais: tenta o proximo
         if(ObjectSetString(0,name,OBJPROP_BMPFILE,LogoPath(cand[i])))
           {
            size=cand[i];
            break;
           }
        }
     }
   else if(ObjectSetString(0,name,OBJPROP_BMPFILE,"\\Images\\"+Logo_File))
      size=Logo_FileSize;

   if(size<=0)
     {
      ObjectDelete(0,name);
      g_logoFailed=true;
      Print("RickEA SAR: nao achei a logo em MQL5\\Images. Copie os RickEA_Logo_*.bmp para la.");
      return;
     }

   ObjectSetInteger(0,name,OBJPROP_XSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,(w-size)/2);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,(h-size)/2);
  }
//+------------------------------------------------------------------+
string LogoPath(const int size)
  {
   return("\\Images\\RickEA_Logo_"+(string)size+(Logo_Dark?"_dark":"")+".bmp");
  }
//+------------------------------------------------------------------+
string TFName()
  {
   string s=EnumToString((ENUM_TIMEFRAMES)Period());
   StringReplace(s,"PERIOD_","");
   return(s);
  }
//+------------------------------------------------------------------+
