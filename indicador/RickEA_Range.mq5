//+------------------------------------------------------------------+
//|                                          RickEA_Range.mq5        |
//|                                                    RichardTrader |
//|                                         Instagram:@ri.chartrader |
//|                                                                  |
//|  Continuidade de 3 velas:                                        |
//|   COMPRA: vela 3 com maxima E minima acima da vela 2, e a vela 2 |
//|           com maxima E minima acima da vela 1. RSI ate 50.       |
//|           Stop abaixo da minima da vela 1.                       |
//|   VENDA:  vela 3 com maxima E minima abaixo da vela 2, e a vela 2|
//|           com maxima E minima abaixo da vela 1. RSI a partir 50. |
//|           Stop acima da maxima da vela 1.                        |
//|   ALVO:   1:1.5 ou 1:2 do risco (ou valor livre).                |
//|                                                                  |
//|  Opcional: filtro de tendencia pela media (compra acima, venda   |
//|  abaixo), direcao, lote fixo ou por risco, take e stop global.   |
//|  Sem grid - cada entrada tem so o seu stop e o seu take.         |
//|  Visual RickEA: range das 3 velas marcado no grafico, preco      |
//|  grande no canto superior direito, painel com fundo de pouca     |
//|  opacidade na cor da tendencia e a logo no fundo (marca d'agua). |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "Instagram:@ri.chartrader"
#property version   "1.00"
#property description "RickEA Range - 3 velas em sequencia + RSI 50, stop na vela 1, alvo 1:1.5 ou 1:2."
#property description "Filtro de media opcional, take/stop global e visual RickEA."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_RICK_DIR
  {
   RICK_BUY_SELL  = 0,   // Compras e Vendas
   RICK_BUY_ONLY  = 1,   // Somente Compras
   RICK_SELL_ONLY = 2    // Somente Vendas
  };

enum ENUM_RICK_RR
  {
   RICK_RR_15     = 0,   // Alvo 1:1.5 (uma vez e meia o risco)
   RICK_RR_20     = 1,   // Alvo 1:2 (duas vezes o risco)
   RICK_RR_CUSTOM = 2    // Alvo livre (RR_Custom)
  };

enum ENUM_RICK_LOTMODE
  {
   RICK_LOT_FIXED = 0,   // Lote fixo
   RICK_LOT_RISK  = 1    // Lote por risco (% do saldo no stop)
  };

//+------------------------------------------------------------------+
//| Parametros de entrada                                            |
//+------------------------------------------------------------------+
input group "=== BASICO ==="
input ENUM_RICK_LOTMODE LotMode      = RICK_LOT_FIXED; // Modo do lote
input double          FIXED_LOT      = 0.01;           // Lote fixo
input double          RiskPercent    = 1.0;            // Risco por entrada (% do saldo, modo por risco)
input ulong           MagicNumber    = 3300;           // Magic Number
input int             SLIPPAGE       = 30;             // Desvio maximo (pontos)
input int             MaxSpread      = 0;              // Spread maximo para entrar (pontos, 0 = OFF)
input string          EA_NAME        = "RickEA Range"; // Nome no painel / comentario

input group "=== SETUP 3 VELAS ==="
input ENUM_RICK_DIR   TradeDirection = RICK_BUY_SELL;  // Direcao permitida
input ENUM_RICK_RR    TargetRR       = RICK_RR_20;     // Alvo (multiplo do risco)
input double          RR_Custom      = 2.0;            // Alvo livre (se TargetRR = livre)
input int             StopOffset     = 0;              // Folga do stop alem da vela 1 (pontos)
input int             MaxPositions   = 1;              // Maximo de ordens abertas ao mesmo tempo
input int             MinRangePoints = 0;              // Range minimo das 3 velas (pontos, 0 = OFF)
input int             MaxRangePoints = 0;              // Range maximo das 3 velas (pontos, 0 = OFF)

input group "=== RSI ==="
input bool            RSI_Enable     = true;           // Usar filtro de RSI
input int             RSI_Period     = 14;             // RSI: periodo
input ENUM_APPLIED_PRICE RSI_Price   = PRICE_CLOSE;    // RSI: preco aplicado
input double          RSI_BuyMax     = 50.0;           // Compra so com RSI ate este valor
input double          RSI_SellMin    = 50.0;           // Venda so com RSI a partir deste valor

input group "=== TENDENCIA PELA MEDIA (opcional) ==="
input bool            MA_Filter      = false;          // Ligar filtro: compra acima / venda abaixo da media
input int             MA_Period      = 200;            // Periodo da media
input ENUM_MA_METHOD  MA_Method      = MODE_EMA;       // Metodo da media
input ENUM_APPLIED_PRICE MA_Price    = PRICE_CLOSE;    // Preco aplicado
input ENUM_TIMEFRAMES MA_Timeframe   = PERIOD_CURRENT; // Tempo grafico da media
input bool            MA_Draw        = true;           // Mostrar a media no grafico

input group "=== TAKE / STOP GLOBAL (dinheiro, 0 = OFF) ==="
input double          GlobalTP       = 0.0;            // Take global: fecha tudo quando o flutuante >= valor
input double          GlobalSL       = 0.0;            // Stop global: fecha tudo quando o flutuante <= -valor

input group "=== RANGE NO GRAFICO ==="
input bool            Range_Show     = true;           // Marcar o range das 3 velas
input int             Range_History  = 300;            // Marcar setups antigos nas ultimas N velas (0 = OFF)
input bool            Range_Filtered = false;          // Marcar tambem setups barrados pelos filtros (cinza)
input bool            Range_Lines    = true;           // Linhas de stop e alvo na entrada
input int             Range_LineBars = 10;             // Comprimento das linhas de stop/alvo (velas)

input group "=== VISUAL ==="
input bool            Visual_Enable  = true;           // Ligar o visual
input bool            BigPrice_Show  = true;           // Preco grande (canto sup. direito)
input int             BigPrice_Size  = 30;             // Tamanho da fonte do preco grande
input bool            BigPrice_ByTrend = true;         // Preco na cor da tendencia
input color           BigPrice_Fixed = clrGold;        // Cor fixa (se ByTrend = false)
input bool            Panel_Show     = true;           // Painel de status
input int             Panel_Opacity  = 18;             // Opacidade do fundo do painel (%)
input int             Panel_X        = 12;             // Painel: margem a direita (px)
input int             Panel_Y        = 12;             // Painel: margem do topo (px)
input int             Panel_Width    = 330;            // Painel: largura (px)
input color           Panel_TrendUp  = clrLime;        // Cor da tendencia de alta / compra
input color           Panel_TrendDown= clrRed;         // Cor da tendencia de baixa / venda
input bool            Logo_Show      = true;           // Logo no fundo do grafico (marca d'agua)
input bool            Logo_AutoSize  = true;           // Escolher o tamanho da logo pelo grafico
input int             Logo_Fill      = 85;             // Quanto da altura do grafico a logo ocupa (%)
input bool            Logo_Dark      = false;          // Usar a versao _dark (se o alfa nao renderizar)
input string          Logo_File      = "RickEA_Logo_768.bmp"; // Arquivo (quando AutoSize = false)
input int             Logo_FileSize  = 768;            // Tamanho desse arquivo em px

//+------------------------------------------------------------------+
//| Globais                                                          |
//+------------------------------------------------------------------+
CTrade        trade;
CPositionInfo pos;

string   PFX          = "RRNG_";
int      g_hRSI       = INVALID_HANDLE;
int      g_hMA        = INVALID_HANDLE;
double   g_point      = 0.0;
int      g_digits     = 5;

int      g_trend      = 0;        // +1 alta, -1 baixa, 0 indefinido
int      g_pattern    = 0;        // padrao nas 3 ultimas velas fechadas: +1, -1, 0
double   g_rsi        = 0.0;
double   g_ma         = 0.0;
string   g_status     = "Aguardando setup";
color    g_statusClr  = clrSilver;
bool     g_closing    = false;    // take/stop global pediu para fechar tudo

int      g_chartW=0, g_chartH=0;
bool     g_logoFailed = false;
bool     g_histDone   = false;    // setups antigos ja marcados

//--- estatisticas (so ordens deste robo neste simbolo)
datetime g_statTime   = 0;
double   g_real[3];               // realizado: 0 dia, 1 semana, 2 mes
int      g_wins = 0, g_loss = 0;
double   g_sumWin = 0.0, g_sumLoss = 0.0;

//+------------------------------------------------------------------+
//| Inicializacao                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_point  = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SLIPPAGE);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_hRSI=iRSI(_Symbol,PERIOD_CURRENT,RSI_Period,RSI_Price);
   if(g_hRSI==INVALID_HANDLE)
     {
      Print("RickEA Range: falha ao criar o RSI, erro ",GetLastError());
      return(INIT_FAILED);
     }
   g_hMA=iMA(_Symbol,MA_Timeframe,MA_Period,0,MA_Method,MA_Price);
   if(g_hMA==INVALID_HANDLE)
     {
      Print("RickEA Range: falha ao criar a media, erro ",GetLastError());
      return(INIT_FAILED);
     }
   if(MA_Draw && (MA_Timeframe==PERIOD_CURRENT || MA_Timeframe==(ENUM_TIMEFRAMES)_Period))
      ChartIndicatorAdd(0,0,g_hMA);

   if(RR()<=0.0)
     {
      Print("RickEA Range: alvo invalido (RR_Custom precisa ser maior que zero).");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(Visual_Enable && !IsBlindTester())
     {
      g_chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      g_chartH=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      DrawLogo();
      EventSetTimer(1);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0,PFX);
   if(g_hRSI!=INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hMA!=INVALID_HANDLE)  IndicatorRelease(g_hMA);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Timer - o painel respira mesmo sem tick                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!Visual_Enable) return;
   TryMarkHistory();
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
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int cnt=CountPositions();
   if(cnt==0) g_closing=false;

   //--- take / stop global a cada tick
   CheckGlobal(cnt);

   //--- a estrategia so roda na abertura da vela nova
   if(IsNewBar())
      CheckForEntry();

   if(Visual_Enable && !IsBlindTester())
     {
      TryMarkHistory();
      UpdateReadings();
      DrawVisuals();
     }
  }
//+------------------------------------------------------------------+
bool IsBlindTester()
  {
   return(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE));
  }
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   static datetime last=0;
   datetime t=iTime(_Symbol,PERIOD_CURRENT,0);
   if(t==0 || t==last) return(false);
   last=t;
   return(true);
  }
//+------------------------------------------------------------------+
double RR()
  {
   if(TargetRR==RICK_RR_15) return(1.5);
   if(TargetRR==RICK_RR_20) return(2.0);
   return(RR_Custom);
  }
//+------------------------------------------------------------------+
double Buf(const int handle,const int shift)
  {
   double b[1];
   if(CopyBuffer(handle,0,shift,1,b)<1) return(0.0);
   return(b[0]);
  }
//+------------------------------------------------------------------+
//| Padrao de continuidade nas velas s+2 (vela 1), s+1 (vela 2) e s  |
//| (vela 3). Retorna +1 compra, -1 venda, 0 nada.                   |
//+------------------------------------------------------------------+
int Pattern(const int s)
  {
   double h1=iHigh(_Symbol,PERIOD_CURRENT,s+2), l1=iLow(_Symbol,PERIOD_CURRENT,s+2);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,s+1), l2=iLow(_Symbol,PERIOD_CURRENT,s+1);
   double h3=iHigh(_Symbol,PERIOD_CURRENT,s),   l3=iLow(_Symbol,PERIOD_CURRENT,s);
   if(h1<=0.0 || h2<=0.0 || h3<=0.0) return(0);

   if(h3>h2 && l3>l2 && h2>h1 && l2>l1) return(1);
   if(h3<h2 && l3<l2 && h2<h1 && l2<l1) return(-1);
   return(0);
  }
//+------------------------------------------------------------------+
//| Range das 3 velas (maxima e minima do conjunto)                  |
//+------------------------------------------------------------------+
void RangeOf(const int s,double &hi,double &lo)
  {
   hi=MathMax(iHigh(_Symbol,PERIOD_CURRENT,s),MathMax(iHigh(_Symbol,PERIOD_CURRENT,s+1),iHigh(_Symbol,PERIOD_CURRENT,s+2)));
   lo=MathMin(iLow(_Symbol,PERIOD_CURRENT,s), MathMin(iLow(_Symbol,PERIOD_CURRENT,s+1), iLow(_Symbol,PERIOD_CURRENT,s+2)));
  }
//+------------------------------------------------------------------+
bool DirAllowed(const int dir)
  {
   if(dir>0 && TradeDirection==RICK_SELL_ONLY) return(false);
   if(dir<0 && TradeDirection==RICK_BUY_ONLY)  return(false);
   return(true);
  }
//+------------------------------------------------------------------+
bool RsiOk(const int dir,const double rsi)
  {
   if(!RSI_Enable) return(true);
   if(rsi<=0.0) return(false);
   return(dir>0 ? (rsi<=RSI_BuyMax) : (rsi>=RSI_SellMin));
  }
//+------------------------------------------------------------------+
//| Media no fechamento da vela s do grafico (respeita MA_Timeframe) |
//+------------------------------------------------------------------+
double MAAt(const int s)
  {
   if(MA_Timeframe==PERIOD_CURRENT || MA_Timeframe==(ENUM_TIMEFRAMES)_Period)
      return(Buf(g_hMA,s));
   datetime t=iTime(_Symbol,PERIOD_CURRENT,s);
   int sh=iBarShift(_Symbol,MA_Timeframe,t,false);
   if(sh<0) return(0.0);
   return(Buf(g_hMA,sh));
  }
//+------------------------------------------------------------------+
bool MaOk(const int dir,const double close,const double ma)
  {
   if(!MA_Filter) return(true);
   if(ma<=0.0) return(false);
   return(dir>0 ? (close>ma) : (close<ma));
  }
//+------------------------------------------------------------------+
bool RangeSizeOk(const double hi,const double lo)
  {
   double pts=(hi-lo)/g_point;
   if(MinRangePoints>0 && pts<MinRangePoints) return(false);
   if(MaxRangePoints>0 && pts>MaxRangePoints) return(false);
   return(true);
  }
//+------------------------------------------------------------------+
//| Entrada na abertura da vela que vem depois da vela 3             |
//+------------------------------------------------------------------+
void CheckForEntry()
  {
   int dir=Pattern(1);
   if(dir==0)
     {
      SetStatus("Aguardando setup de 3 velas",clrSilver);
      return;
     }

   double hi,lo;
   RangeOf(1,hi,lo);
   double rsi  =Buf(g_hRSI,1);
   double close=iClose(_Symbol,PERIOD_CURRENT,1);
   double ma   =MAAt(1);
   string side =(dir>0)?"COMPRA":"VENDA";

   bool ok=true;
   string why="";
   if(!DirAllowed(dir))            { ok=false; why="direcao desligada"; }
   else if(!RsiOk(dir,rsi))        { ok=false; why=StringFormat("RSI %.1f fora do limite",rsi); }
   else if(!MaOk(dir,close,ma))    { ok=false; why=(dir>0)?"preco abaixo da media":"preco acima da media"; }
   else if(!RangeSizeOk(hi,lo))    { ok=false; why="tamanho do range fora do limite"; }
   else if(g_closing)              { ok=false; why="fechando pelo take/stop global"; }
   else if(CountPositions()>=MathMax(1,MaxPositions)) { ok=false; why="maximo de ordens abertas"; }
   else if(MaxSpread>0 && SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>MaxSpread) { ok=false; why="spread alto"; }

   if(!ok)
     {
      SetStatus("Setup de "+side+" barrado: "+why,clrOrange);
      if(Visual_Enable && Range_Show && Range_Filtered && !IsBlindTester())
         DrawRange(1,dir,false);
      return;
     }

   if(OpenTrade(dir))
     {
      SetStatus("Entrou "+side+" no setup de 3 velas",(dir>0)?Panel_TrendUp:Panel_TrendDown);
      if(Visual_Enable && Range_Show && !IsBlindTester())
         DrawRange(1,dir,true);
     }
  }
//+------------------------------------------------------------------+
//| Abre a ordem com stop na vela 1 e alvo RR x risco                |
//+------------------------------------------------------------------+
bool OpenTrade(const int dir)
  {
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ask<=0.0 || bid<=0.0) return(false);

   double px=(dir>0)?ask:bid;
   double sl=(dir>0)?iLow(_Symbol,PERIOD_CURRENT,3)-StopOffset*g_point
                    :iHigh(_Symbol,PERIOD_CURRENT,3)+StopOffset*g_point;

   //--- respeita a distancia minima de stop da corretora
   double minDist=(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*g_point;
   double risk=(dir>0)?(px-sl):(sl-px);
   if(risk<=0.0)
     {
      SetStatus("Preco ja passou do stop da vela 1 - entrada cancelada",clrOrange);
      return(false);
     }
   if(risk<minDist)
     {
      risk=minDist;
      sl=(dir>0)?(px-risk):(px+risk);
     }
   double tp=(dir>0)?(px+risk*RR()):(px-risk*RR());
   sl=NormalizeDouble(sl,g_digits);
   tp=NormalizeDouble(tp,g_digits);

   double lot=CalcLot(risk);
   if(lot<=0.0)
     {
      SetStatus("Lote calculado invalido",clrOrange);
      return(false);
     }

   string cmt=EA_NAME+" "+((dir>0)?"C":"V")+" 1:"+DoubleToString(RR(),1);
   bool ok=(dir>0) ? trade.Buy(lot,_Symbol,0.0,sl,tp,cmt)
                   : trade.Sell(lot,_Symbol,0.0,sl,tp,cmt);
   uint rc=trade.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL && rc!=TRADE_RETCODE_PLACED))
     {
      PrintFormat("RickEA Range: falha ao abrir %s %.2f - %u %s",(dir>0?"BUY":"SELL"),lot,
                  trade.ResultRetcode(),trade.ResultRetcodeDescription());
      SetStatus("Falha ao abrir a ordem ("+(string)trade.ResultRetcode()+")",clrOrange);
      return(false);
     }
   PrintFormat("RickEA Range: %s %.2f @ %s  SL %s  TP %s (1:%.1f)",(dir>0?"BUY":"SELL"),lot,
               DoubleToString(px,g_digits),DoubleToString(sl,g_digits),DoubleToString(tp,g_digits),RR());
   return(true);
  }
//+------------------------------------------------------------------+
//| Lote fixo ou por risco (% do saldo perdido se bater o stop)      |
//+------------------------------------------------------------------+
double CalcLot(const double riskDist)
  {
   double lot=FIXED_LOT;
   if(LotMode==RICK_LOT_RISK)
     {
      double tickVal =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tickVal<=0.0) tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double money   =AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
      if(tickVal<=0.0 || tickSize<=0.0 || riskDist<=0.0) return(0.0);
      double lossPerLot=riskDist/tickSize*tickVal;
      if(lossPerLot<=0.0) return(0.0);
      lot=money/lossPerLot;
     }
   return(NormalizeLot(lot));
  }
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double mn =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double stp=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(stp<=0.0) stp=0.01;
   lot=MathFloor(lot/stp+1e-9)*stp;
   if(lot<mn) lot=mn;
   if(mx>0.0 && lot>mx) lot=mx;
   return(NormalizeDouble(lot,8));
  }
//+------------------------------------------------------------------+
//| Posicoes do robo                                                 |
//+------------------------------------------------------------------+
int CountPositions()
  {
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(pos.SelectByIndex(i) && pos.Magic()==MagicNumber && pos.Symbol()==_Symbol)
         n++;
   return(n);
  }
//+------------------------------------------------------------------+
double Floating()
  {
   double p=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(pos.SelectByIndex(i) && pos.Magic()==MagicNumber && pos.Symbol()==_Symbol)
         p+=pos.Profit()+pos.Swap()+pos.Commission();
   return(p);
  }
//+------------------------------------------------------------------+
//| Take global / stop global em dinheiro                            |
//+------------------------------------------------------------------+
void CheckGlobal(const int cnt)
  {
   if(cnt==0 || g_closing) return;
   double fl=Floating();
   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   if(GlobalTP>0.0 && fl>=GlobalTP)
      CloseAll("TAKE GLOBAL ("+DoubleToString(fl,2)+" "+cur+")");
   else if(GlobalSL>0.0 && fl<=-GlobalSL)
      CloseAll("STOP GLOBAL ("+DoubleToString(fl,2)+" "+cur+")");
  }
//+------------------------------------------------------------------+
void CloseAll(const string why)
  {
   g_closing=true;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Magic()!=MagicNumber || pos.Symbol()!=_Symbol) continue;
      if(!trade.PositionClose(pos.Ticket()))
         PrintFormat("RickEA Range: falha ao fechar #%I64u - %u %s",pos.Ticket(),
                     trade.ResultRetcode(),trade.ResultRetcodeDescription());
     }
   Print("RickEA Range: ",why," - fechando todas as ordens do robo.");
   SetStatus(why+" - ordens encerradas",clrGold);
   g_statTime=0;
  }
//+------------------------------------------------------------------+
void SetStatus(const string txt,const color clr)
  {
   if(txt!=g_status) Print("RickEA Range: ",txt);
   g_status=txt;
   g_statusClr=clr;
  }
//+==================================================================+
//|                     RANGE DAS 3 VELAS                            |
//+==================================================================+
//| s = indice da vela 3 (a mais nova do setup)                      |
//+------------------------------------------------------------------+
void DrawRange(const int s,const int dir,const bool valid)
  {
   double hi,lo;
   RangeOf(s,hi,lo);
   datetime t1=iTime(_Symbol,PERIOD_CURRENT,s+2);
   datetime t3=iTime(_Symbol,PERIOD_CURRENT,s);
   if(t1==0 || t3==0) return;
   datetime t3e=t3+PeriodSeconds(PERIOD_CURRENT);

   color c=valid ? ((dir>0)?Panel_TrendUp:Panel_TrendDown) : clrGray;
   string id=PFX+"RNG_"+(string)(long)t3;

   string box=id+"_BOX";
   if(ObjectFind(0,box)<0)
      ObjectCreate(0,box,OBJ_RECTANGLE,0,t1,hi,t3e,lo);
   ObjectSetInteger(0,box,OBJPROP_TIME,0,t1);
   ObjectSetDouble (0,box,OBJPROP_PRICE,0,hi);
   ObjectSetInteger(0,box,OBJPROP_TIME,1,t3e);
   ObjectSetDouble (0,box,OBJPROP_PRICE,1,lo);
   ObjectSetInteger(0,box,OBJPROP_COLOR,Blend(c,ChartBg(),0.35));
   ObjectSetInteger(0,box,OBJPROP_FILL,true);
   ObjectSetInteger(0,box,OBJPROP_BACK,true);
   ObjectSetInteger(0,box,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,box,OBJPROP_HIDDEN,true);

   string brd=id+"_BRD";
   if(ObjectFind(0,brd)<0)
      ObjectCreate(0,brd,OBJ_RECTANGLE,0,t1,hi,t3e,lo);
   ObjectSetInteger(0,brd,OBJPROP_TIME,0,t1);
   ObjectSetDouble (0,brd,OBJPROP_PRICE,0,hi);
   ObjectSetInteger(0,brd,OBJPROP_TIME,1,t3e);
   ObjectSetDouble (0,brd,OBJPROP_PRICE,1,lo);
   ObjectSetInteger(0,brd,OBJPROP_COLOR,c);
   ObjectSetInteger(0,brd,OBJPROP_FILL,false);
   ObjectSetInteger(0,brd,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,brd,OBJPROP_BACK,false);
   ObjectSetInteger(0,brd,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,brd,OBJPROP_HIDDEN,true);

   //--- linhas de stop e alvo a partir da vela de entrada
   if(!valid || !Range_Lines) return;
   double entry=(s>=1)?iOpen(_Symbol,PERIOD_CURRENT,s-1):0.0;
   if(entry<=0.0) return;
   double sl=(dir>0)?(iLow(_Symbol,PERIOD_CURRENT,s+2)-StopOffset*g_point)
                    :(iHigh(_Symbol,PERIOD_CURRENT,s+2)+StopOffset*g_point);
   double risk=MathAbs(entry-sl);
   double tp=(dir>0)?(entry+risk*RR()):(entry-risk*RR());
   datetime te=t3e+PeriodSeconds(PERIOD_CURRENT)*MathMax(1,Range_LineBars);
   Seg(id+"_SL",t3e,sl,te,Panel_TrendDown,"SL");
   Seg(id+"_TP",t3e,tp,te,Panel_TrendUp,"TP 1:"+DoubleToString(RR(),1));
   Seg(id+"_EN",t3e,entry,te,clrSilver,"Entrada");
  }
//+------------------------------------------------------------------+
void Seg(const string name,const datetime t0,const double p,const datetime t1,
         const color clr,const string tip)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_TREND,0,t0,p,t1,p);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t0);
   ObjectSetDouble (0,name,OBJPROP_PRICE,0,p);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t1);
   ObjectSetDouble (0,name,OBJPROP_PRICE,1,p);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString (0,name,OBJPROP_TOOLTIP,tip);
  }
//+------------------------------------------------------------------+
//| Os indicadores so ficam prontos depois do OnInit: marca o        |
//| historico uma vez, quando o RSI e a media ja foram calculados.   |
//+------------------------------------------------------------------+
void TryMarkHistory()
  {
   if(g_histDone) return;
   if(!Range_Show || Range_History<=0) { g_histDone=true; return; }
   if(BarsCalculated(g_hRSI)<=0 || BarsCalculated(g_hMA)<=0) return;
   MarkHistory();
   g_histDone=true;
  }
//+------------------------------------------------------------------+
//| Marca os setups que apareceram nas ultimas N velas               |
//+------------------------------------------------------------------+
void MarkHistory()
  {
   int bars=MathMin(Range_History,Bars(_Symbol,PERIOD_CURRENT)-5);
   for(int s=bars;s>=1;s--)
     {
      int dir=Pattern(s);
      if(dir==0) continue;
      double hi,lo;
      RangeOf(s,hi,lo);
      bool valid=DirAllowed(dir) && RsiOk(dir,Buf(g_hRSI,s)) &&
                 MaOk(dir,iClose(_Symbol,PERIOD_CURRENT,s),MAAt(s)) && RangeSizeOk(hi,lo);
      if(valid || Range_Filtered)
         DrawRange(s,dir,valid);
     }
  }
//+==================================================================+
//|                            VISUAL                                |
//+==================================================================+
void UpdateReadings()
  {
   g_rsi    =Buf(g_hRSI,0);
   g_ma     =MAAt(0);
   g_pattern=Pattern(1);

   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0.0) return;
   if(g_ma>0.0)
      g_trend=(px>g_ma)?1:((px<g_ma)?-1:0);
   else
      g_trend=(px>=iClose(_Symbol,PERIOD_CURRENT,1))?1:-1;
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
string Money(const double v)
  {
   return((v>=0.0?"+":"")+DoubleToString(v,2));
  }
//+------------------------------------------------------------------+
//| Painel + preco grande no canto superior direito                  |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   UpdateStats();

   color accent = TrendColor();
   color bg     = ChartBg();
   color fill   = Blend(accent,bg,Panel_Opacity/100.0);
   color head   = Blend(accent,bg,MathMin(1.0,(Panel_Opacity+14)/100.0));

   int pad    = 12;
   int headH  = 24;
   int priceH = (BigPrice_Show ? BigPrice_Size+16 : 0);
   int rowH   = 17;
   int rows   = (Panel_Show ? 12 : 0);
   int panelH = headH+priceH+pad+rows*rowH+(Panel_Show?pad:0);

   // OBJ_RECTANGLE_LABEL com canto a direita mede a distancia ate a borda
   // ESQUERDA da caixa e cresce pra direita - por isso soma a largura aqui.
   int boxX=Panel_X+Panel_Width;
   Box(PFX+"BG",  boxX,Panel_Y,Panel_Width,panelH,fill,accent,true);
   Box(PFX+"HEAD",boxX,Panel_Y,Panel_Width,headH,head,accent,false);

   int xl=Panel_X+Panel_Width-pad;     // borda interna esquerda (canto = direita)
   int xr=Panel_X+pad;                 // borda interna direita
   int y =Panel_Y+5;

   Text(PFX+"T_BRAND",xl,y,EA_NAME,clrWhite,10,true,ANCHOR_LEFT_UPPER);
   Text(PFX+"T_SYM",  xr,y,_Symbol+" "+TFName(),Blend(clrWhite,bg,0.75),9,true,ANCHOR_RIGHT_UPPER);
   y+=headH;

   if(BigPrice_Show)
     {
      color pc=BigPrice_ByTrend?accent:BigPrice_Fixed;
      Text(PFX+"T_PRICE",xr,y+6,DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),g_digits),pc,BigPrice_Size,true,ANCHOR_RIGHT_UPPER,"Arial Black");
      Text(PFX+"T_TREND",xl,y+6+BigPrice_Size/2-6,(g_trend>0?"ALTA":(g_trend<0?"BAIXA":"---")),pc,10,true,ANCHOR_LEFT_UPPER);
      y+=priceH;
     }
   if(!Panel_Show) return;
   y+=pad;

   //--- posicao aberta do robo
   int    total=0;
   string posTxt="nenhuma", sltpTxt="- / -";
   double floating=0.0;
   color  posClr=clrSilver;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(pos.SelectByIndex(i) && pos.Magic()==MagicNumber && pos.Symbol()==_Symbol)
        {
         total++;
         floating+=pos.Profit()+pos.Swap()+pos.Commission();
         bool isBuy=(pos.PositionType()==POSITION_TYPE_BUY);
         posTxt=StringFormat("%s %.2f @ %s",(isBuy?"BUY":"SELL"),pos.Volume(),
                             DoubleToString(pos.PriceOpen(),g_digits));
         sltpTxt=DoubleToString(pos.StopLoss(),g_digits)+" / "+DoubleToString(pos.TakeProfit(),g_digits);
         posClr=(isBuy?Panel_TrendUp:Panel_TrendDown);
        }
   if(total>1) posTxt=(string)total+" ordens abertas";

   //--- leituras
   string patTxt=(g_pattern>0)?"ALTA (3 velas subindo)":((g_pattern<0)?"BAIXA (3 velas caindo)":"nenhum");
   color  patClr=(g_pattern>0)?Panel_TrendUp:((g_pattern<0)?Panel_TrendDown:clrSilver);

   string rsiTxt;
   color  rsiClr=clrWhite;
   if(!RSI_Enable) { rsiTxt=StringFormat("%.1f  filtro OFF",g_rsi); rsiClr=clrSilver; }
   else if(g_rsi<=RSI_BuyMax && g_rsi>=RSI_SellMin) { rsiTxt=StringFormat("%.1f  compra e venda",g_rsi); }
   else if(g_rsi<=RSI_BuyMax) { rsiTxt=StringFormat("%.1f  libera COMPRA",g_rsi); rsiClr=Panel_TrendUp; }
   else if(g_rsi>=RSI_SellMin){ rsiTxt=StringFormat("%.1f  libera VENDA",g_rsi);  rsiClr=Panel_TrendDown; }
   else rsiTxt=StringFormat("%.1f",g_rsi);

   string maTxt=DoubleToString(g_ma,g_digits)+(g_trend>0?"  acima":(g_trend<0?"  abaixo":""))+
                (MA_Filter?"":"  (OFF)");
   color  maClr=MA_Filter?accent:clrSilver;

   string cur=AccountInfoString(ACCOUNT_CURRENCY);
   int    trades=g_wins+g_loss;
   double acerto=(trades>0)?100.0*g_wins/trades:0.0;
   double payoff=(g_wins>0 && g_loss>0 && g_sumLoss>0.0)?(g_sumWin/g_wins)/(g_sumLoss/g_loss):0.0;

   Row(PFX+"R_PAT", "Padrao 3 velas", patTxt, patClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_RSI", StringFormat("RSI (%d)  C<=%.0f V>=%.0f",RSI_Period,RSI_BuyMax,RSI_SellMin),
                    rsiTxt, rsiClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_MA",  StringFormat("Media %s %d",MAName(),MA_Period), maTxt, maClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_SET", "Stop / Alvo", "vela 1 / 1:"+DoubleToString(RR(),1)+"  ["+DirName()+"]",
                    clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_POS", "Posicao", posTxt, posClr, xl,xr,y); y+=rowH;
   Row(PFX+"R_SLTP","SL / TP", sltpTxt, clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_PL",  "Flutuante", Money(floating)+" "+cur,
                    (floating>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y); y+=rowH;
   Row(PFX+"R_GLB", "Take / Stop global",
                    (GlobalTP>0?DoubleToString(GlobalTP,2):"OFF")+" / "+(GlobalSL>0?DoubleToString(GlobalSL,2):"OFF"),
                    clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_D",   "Realizado dia / semana",
                    Money(g_real[0])+" / "+Money(g_real[1]),
                    (g_real[0]>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y); y+=rowH;
   Row(PFX+"R_M",   "Realizado mes", Money(g_real[2])+" "+cur,
                    (g_real[2]>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y); y+=rowH;
   Row(PFX+"R_ACC", "Trades / Acerto / Payoff",
                    StringFormat("%d / %.0f%% / %.2f",trades,acerto,payoff),
                    (payoff>=1.0 || trades==0)?Panel_TrendUp:Panel_TrendDown, xl,xr,y); y+=rowH;
   Text(PFX+"R_ST_V",xl,y,g_status,g_statusClr,8,false,ANCHOR_LEFT_UPPER);
  }
//+------------------------------------------------------------------+
string DirName()
  {
   if(TradeDirection==RICK_BUY_ONLY)  return("so compras");
   if(TradeDirection==RICK_SELL_ONLY) return("so vendas");
   return("C + V");
  }
//+------------------------------------------------------------------+
string MAName()
  {
   if(MA_Method==MODE_SMA)  return("SMA");
   if(MA_Method==MODE_EMA)  return("EMA");
   if(MA_Method==MODE_SMMA) return("SMMA");
   return("LWMA");
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
//| Logo INTEIRA no fundo do grafico (marca d'agua centralizada)     |
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
      Print("RickEA Range: nao achei a logo em MQL5\\Images. Copie os RickEA_Logo_*.bmp para la.");
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
//| Estatisticas so das ordens do robo neste simbolo                 |
//| Realizado do dia, da semana e do mes; acerto e payoff por trade  |
//+------------------------------------------------------------------+
void UpdateStats()
  {
   if(g_statTime>0 && TimeCurrent()-g_statTime<3) return;
   g_statTime=TimeCurrent();

   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   d.hour=0; d.min=0; d.sec=0;
   datetime dayStart  =StructToTime(d);
   int      dow       =(d.day_of_week==0)?6:d.day_of_week-1;   // semana comeca na segunda
   datetime weekStart =dayStart-dow*86400;
   d.day=1;
   datetime monthStart=StructToTime(d);
   datetime starts[3];
   starts[0]=dayStart; starts[1]=weekStart; starts[2]=monthStart;

   for(int p=0;p<3;p++) g_real[p]=0.0;
   g_wins=0; g_loss=0; g_sumWin=0.0; g_sumLoss=0.0;

   datetime from=(weekStart<monthStart)?weekStart:monthStart;
   if(!HistorySelect(from,TimeCurrent()+60)) return;

   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
     {
      ulong tk=HistoryDealGetTicket(i);
      if(tk==0) continue;
      if((ulong)HistoryDealGetInteger(tk,DEAL_MAGIC)!=MagicNumber) continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol) continue;
      long type=HistoryDealGetInteger(tk,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;

      double   v=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+
                 HistoryDealGetDouble(tk,DEAL_COMMISSION);
      datetime t=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
      long entry=HistoryDealGetInteger(tk,DEAL_ENTRY);

      for(int p=0;p<3;p++)
         if(t>=starts[p]) g_real[p]+=v;

      //--- cada saida e um trade (sem parcial neste robo); conta o mes
      if(t>=monthStart && (entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT || entry==DEAL_ENTRY_OUT_BY))
        {
         if(v>0.0)      { g_wins++; g_sumWin+=v; }
         else if(v<0.0) { g_loss++; g_sumLoss-=v; }
        }
     }
  }
//+------------------------------------------------------------------+
