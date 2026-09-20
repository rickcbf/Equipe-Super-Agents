//+------------------------------------------------------------------+
//|                                                    RickEA_MA.mq5 |
//|            RICKEA MA - compras ACIMA da media / vendas ABAIXO    |
//|                                                                  |
//|  Opcional no set: somente compras, somente vendas ou os dois,    |
//|  grid, martingale, ciclo de take global e entrada por vela.      |
//|  Visual: preco grande no canto superior direito, painel com      |
//|  fundo de pouca opacidade na cor da tendencia e a logo RickEA    |
//|  preenchendo o fundo do grafico.                                 |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RICKEA MA"
#property version   "1.00"
#property description "RickEA MA - media movel com grid, martingale, take global e painel RickEA."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_RICK_DIR
  {
   RICK_BUY_SELL  = 0,   // Compras e Vendas
   RICK_BUY_ONLY  = 1,   // Somente Compras
   RICK_SELL_ONLY = 2    // Somente Vendas
  };

enum ENUM_RICK_ENTRY
  {
   RICK_ENTRY_TICK      = 0,  // A cada tick (preco x media)
   RICK_ENTRY_BAR_OPEN  = 1,  // Por vela: vela fechada acima/abaixo da media
   RICK_ENTRY_BAR_CROSS = 2   // Por vela: somente no cruzamento da media
  };

enum ENUM_RICK_CYCLE
  {
   RICK_CYCLE_MONEY   = 0,    // Em dinheiro (moeda da conta)
   RICK_CYCLE_PERCENT = 1     // Em % do saldo
  };

enum ENUM_RICK_SCOPE
  {
   RICK_SCOPE_GLOBAL = 0,     // Cesta global (compras + vendas juntas)
   RICK_SCOPE_SIDE   = 1      // Uma cesta por lado (compras e vendas separadas)
  };

enum ENUM_RICK_LOGO
  {
   RICK_LOGO_TILE   = 0,      // Preencher o grafico (mosaico)
   RICK_LOGO_CENTER = 1       // Uma logo no centro
  };

//+------------------------------------------------------------------+
//| Parametros de entrada                                            |
//+------------------------------------------------------------------+
input group "=== BASICO ==="
input double          FIXED_LOT        = 0.01;        // FIXED_LOT (lote inicial)
input double          STOPLOSS         = 0.0;         // STOPLOSS (pontos, 0 = OFF)
input double          TAKEPROFIT       = 10000.0;     // TAKEPROFIT (pontos, 0 = OFF)
input int             SLIPPAGE         = 30;          // Desvio maximo (pontos)
input ulong           MagicNumber      = 12345;       // Magic Number, kind of...
input string          EA_NAME          = "RickEA MA"; // EA_NAME
input string          Copyright        = "RichardTrader"; // Copyright

input group "=== SETTING TRAIL (if 0 value>>OFF) ==="
input double          TRAILINGSTART    = 0.0;         // TRAILINGSTART (lucro em pontos p/ ligar)
input double          TRAILINGSTOP     = 0.0;         // TRAILINGSTOP (distancia do preco, pontos)
input double          TRAILINGSTEP     = 0.0;         // TRAILINGSTEP (passo minimo, pontos)
input bool            BreakEvenFirst   = false;       // Levar pro zero a zero antes de arrastar

input group "=== MEDIA MOVEL ==="
input int             EMA              = 17;          // EMA (periodo da media)
input ENUM_MA_METHOD  MA_Method        = MODE_EMA;    // Metodo da media
input ENUM_APPLIED_PRICE MA_Price      = PRICE_CLOSE; // Preco aplicado
input int             MA_Shift         = 0;           // Deslocamento da media
input ENUM_TIMEFRAMES MA_Timeframe     = PERIOD_CURRENT; // Tempo grafico da media

input group "=== DIRECAO E ENTRADA ==="
input ENUM_RICK_DIR   TradeDirection   = RICK_BUY_SELL;   // Direcao permitida
input ENUM_RICK_ENTRY EntryMode        = RICK_ENTRY_TICK; // Modo de entrada
input bool            OneEntryPerCandle= true;            // Uma entrada por vela
input int             MinDistMA_Points = 0;               // Distancia minima da media (pontos, 0 = OFF)
input bool            CloseOnReverse   = false;           // Fechar tudo quando a media virar

input group "=== GRID (opcional) ==="
input bool            Grid_Enable      = false;      // Ligar grid
input double          Grid_StepPoints  = 200;        // Distancia entre ordens (pontos)
input double          Grid_StepMult    = 1.0;        // Multiplicador da distancia (1.0 = fixa)
input int             Grid_MaxOrders   = 10;         // Maximo de ordens por lado
input bool            Grid_RequireSignal = false;    // So adicionar se a media ainda concordar

input group "=== MARTINGALE (opcional) ==="
input bool            Martin_Enable    = false;      // Ligar martingale
input double          Martin_Multiplier= 1.6;        // Multiplicador do lote
input int             Martin_MaxLevels = 6;          // Niveis que ainda multiplicam
input double          Martin_MaxLot    = 0.0;        // Lote maximo (0 = sem limite)

input group "=== CICLO / TAKE GLOBAL (opcional) ==="
input bool            Cycle_Enable     = false;      // Ligar ciclo de take global
input ENUM_RICK_SCOPE Cycle_Scope      = RICK_SCOPE_GLOBAL; // Cesta considerada
input ENUM_RICK_CYCLE Cycle_Unit       = RICK_CYCLE_MONEY;  // Unidade do alvo
input double          Cycle_TakeProfit = 10.0;       // Take global (fecha a cesta no lucro)
input double          Cycle_StopLoss   = 0.0;        // Stop global (0 = OFF)
input bool            Cycle_WaitNewSignal = true;    // Depois de fechar, esperar a media virar
input bool            Cycle_OverrideTP = true;      // Ciclo ligado ignora o TAKEPROFIT individual

input group "=== VISUAL ==="
input bool            Visual_Enable    = true;       // Ligar o visual
input bool            BigPrice_Show    = true;       // Preco grande (canto sup. direito)
input int             BigPrice_Size    = 30;         // Tamanho da fonte do preco grande
input bool            BigPrice_ByTrend = true;       // Preco na cor da tendencia
input color           BigPrice_Fixed   = clrGold;    // Cor fixa (se ByTrend = false)
input bool            Panel_Show       = true;       // Painel de status
input int             Panel_Opacity    = 18;         // Opacidade do fundo do painel (%)
input int             Panel_X          = 12;         // Painel: margem a direita (px)
input int             Panel_Y          = 12;         // Painel: margem do topo (px)
input int             Panel_Width      = 300;        // Painel: largura (px)
input color           Panel_TrendUp    = clrLime;    // Cor da tendencia de alta
input color           Panel_TrendDown  = clrRed;     // Cor da tendencia de baixa
input bool            Logo_Show        = true;       // Logo no fundo do grafico
input string          Logo_File        = "RickEA_Logo_128.bmp"; // Arquivo BMP (pasta MQL5\Images)
input ENUM_RICK_LOGO  Logo_Mode        = RICK_LOGO_TILE; // Como preencher
input int             Logo_Size        = 128;        // Tamanho da logo no BMP (px)
input int             Logo_Gap         = 60;         // Espaco entre as logos no mosaico (px)

//+------------------------------------------------------------------+
//| Globais                                                          |
//+------------------------------------------------------------------+
CTrade        trade;
CPositionInfo pos;

int      g_hMA        = INVALID_HANDLE;
double   g_point      = 0.0;
int      g_digits     = 5;
string   PFX          = "RMA_";

int      g_trend      = 0;        // +1 alta, -1 baixa, 0 indefinido
double   g_maValue    = 0.0;

datetime g_lastBar    = 0;        // ultima barra processada (modos por vela)
datetime g_entryBar[2];           // ultima barra em que entramos  [0]=buy [1]=sell

int      g_gridCount[2];          // ordens ja abertas no ciclo    [0]=buy [1]=sell
double   g_lastEntry[2];          // preco da ultima entrada
double   g_lastLot[2];            // lote da ultima entrada
int      g_blockDir   = 0;        // direcao bloqueada apos fechar ciclo

int      g_chartW     = 0;
int      g_chartH     = 0;
int      g_logoCount  = 0;
bool     g_logoFailed = false;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_point  = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_point<=0.0)
     {
      Print("RickEA MA: nao consegui ler o ponto do simbolo.");
      return(INIT_FAILED);
     }

   if(FIXED_LOT<=0.0)
     {
      Print("RickEA MA: FIXED_LOT precisa ser maior que zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(EMA<1)
     {
      Print("RickEA MA: periodo da media invalido.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(Grid_Enable && Grid_StepPoints<=0.0)
     {
      Print("RickEA MA: com o grid ligado, Grid_StepPoints precisa ser maior que zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_hMA = iMA(_Symbol,MA_Timeframe,EMA,MA_Shift,MA_Method,MA_Price);
   if(g_hMA==INVALID_HANDLE)
     {
      Print("RickEA MA: falha ao criar o handle da media.");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SLIPPAGE);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   for(int i=0;i<2;i++)
     {
      g_entryBar[i]  = 0;
      g_gridCount[i] = 0;
      g_lastEntry[i] = 0.0;
      g_lastLot[i]   = 0.0;
     }
   SyncBaskets();

   if(CycleOwnsTP() && TAKEPROFIT>0.0)
      Print("RickEA MA: ciclo de take global ligado - o TAKEPROFIT individual (",
            DoubleToString(TAKEPROFIT,0)," pontos) fica ignorado. Quem fecha a cesta e o Cycle_TakeProfit.");

   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("RickEA MA: conta netting - compras e vendas se fundem numa posicao so. ",
            "O grid soma volume normalmente, mas os dois lados nao ficam abertos ao mesmo tempo.");

   if(Visual_Enable)
     {
      g_chartW = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      g_chartH = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      DrawLogo();
     }

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_hMA!=INVALID_HANDLE) IndicatorRelease(g_hMA);
   ObjectsDeleteAll(0,PFX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| OnTimer - o visual respira mesmo sem tick                        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!Visual_Enable) return;
   UpdateTrend();
   DrawVisuals();
  }

//+------------------------------------------------------------------+
//| OnChartEvent - refaz o mosaico quando o grafico muda de tamanho  |
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
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateTrend();
   SyncBaskets();

   bool newBar=IsNewBar();

   if(Cycle_Enable)   ManageCycle();
   if(CloseOnReverse) ManageReverse();
   ManageTrailing();

   int sig=SignalDir(newBar);
   if(sig!=0)
     {
      // libera o bloqueio assim que a media vira pro outro lado
      if(g_blockDir!=0 && sig!=g_blockDir) g_blockDir=0;
      if(sig!=g_blockDir) TryEntries(sig);
     }

   if(Visual_Enable) DrawVisuals();
  }

//+------------------------------------------------------------------+
//| Leitura da media                                                 |
//+------------------------------------------------------------------+
double MAValue(const int shift)
  {
   double buf[];
   if(CopyBuffer(g_hMA,0,shift,1,buf)<1) return(0.0);
   return(buf[0]);
  }

void UpdateTrend()
  {
   double ma=MAValue(0);
   if(ma<=0.0) return;
   g_maValue=ma;

   double px=MidPrice();
   if(px<=0.0) return;
   g_trend=(px>ma)?1:((px<ma)?-1:0);
  }

double MidPrice()
  {
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0) return(0.0);
   return((bid+ask)/2.0);
  }

bool IsNewBar()
  {
   datetime t=iTime(_Symbol,MA_Timeframe,0);
   if(t==0 || t==g_lastBar) return(false);
   g_lastBar=t;
   return(true);
  }

//+------------------------------------------------------------------+
//| Sinal: +1 compra, -1 venda, 0 nada                               |
//+------------------------------------------------------------------+
int SignalDir(const bool newBar)
  {
   double ma,px;

   if(EntryMode==RICK_ENTRY_TICK)
     {
      ma=MAValue(0);
      px=MidPrice();
     }
   else
     {
      if(!newBar) return(0);                       // por vela: so na virada da barra
      ma=MAValue(1);
      px=iClose(_Symbol,MA_Timeframe,1);
     }
   if(ma<=0.0 || px<=0.0) return(0);

   if(MinDistMA_Points>0 && MathAbs(px-ma) < MinDistMA_Points*g_point) return(0);

   if(EntryMode==RICK_ENTRY_BAR_CROSS)
     {
      double ma2=MAValue(2);
      double px2=iClose(_Symbol,MA_Timeframe,2);
      if(ma2<=0.0 || px2<=0.0) return(0);
      if(px>ma && px2<=ma2) return(1);
      if(px<ma && px2>=ma2) return(-1);
      return(0);
     }

   return((px>ma)?1:((px<ma)?-1:0));
  }

bool DirAllowed(const int dir)
  {
   if(dir>0) return(TradeDirection==RICK_BUY_SELL || TradeDirection==RICK_BUY_ONLY);
   if(dir<0) return(TradeDirection==RICK_BUY_SELL || TradeDirection==RICK_SELL_ONLY);
   return(false);
  }

//+------------------------------------------------------------------+
//| Cesta: contagem, volume e lucro por lado                         |
//+------------------------------------------------------------------+
void BasketInfo(const int dir,int &count,double &volume,double &profit,
                double &best,double &worst)
  {
   count=0; volume=0.0; profit=0.0; best=0.0; worst=0.0;
   ENUM_POSITION_TYPE want=(dir>0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol || pos.Magic()!=MagicNumber) continue;
      if(dir!=0 && pos.PositionType()!=want) continue;

      double open=pos.PriceOpen();
      count++;
      volume += pos.Volume();
      profit += pos.Profit()+pos.Swap()+pos.Commission();

      if(count==1) { best=open; worst=open; }
      else
        {
         // "worst" = ponta mais distante a favor do grid (onde entra a proxima ordem)
         if(pos.PositionType()==POSITION_TYPE_BUY) { if(open<worst) worst=open; if(open>best) best=open; }
         else                                      { if(open>worst) worst=open; if(open<best) best=open; }
        }
     }
  }

void SyncBaskets()
  {
   for(int k=0;k<2;k++)
     {
      int dir=(k==0)?1:-1;
      int count; double vol,prof,best,worst;
      BasketInfo(dir,count,vol,prof,best,worst);
      if(count==0)                       // ciclo do lado fechou: zera os contadores
        {
         g_gridCount[k]=0;
         g_lastEntry[k]=0.0;
         g_lastLot[k]=0.0;
        }
      else if(g_gridCount[k]<count)      // posicoes abertas na mao: acompanha
        {
         g_gridCount[k]=count;
         if(g_lastEntry[k]<=0.0) g_lastEntry[k]=worst;
        }
     }
  }

//+------------------------------------------------------------------+
//| Entradas: primeira ordem e adicoes do grid                       |
//+------------------------------------------------------------------+
void TryEntries(const int dir)
  {
   if(!DirAllowed(dir)) return;

   int k=(dir>0)?0:1;
   int count; double vol,prof,best,worst;
   BasketInfo(dir,count,vol,prof,best,worst);

   if(OneEntryPerCandle)
     {
      datetime bar=iTime(_Symbol,MA_Timeframe,0);
      if(bar!=0 && bar==g_entryBar[k]) return;
     }

   if(count==0)                                    // primeira ordem do ciclo
     {
      OpenTrade(dir,NextLot(dir,0));
      return;
     }

   // em conta netting as posicoes se fundem numa so, entao o nivel do ciclo vem
   // do contador interno (quantas vezes ja entramos), nao de PositionsTotal()
   int level=MathMax(count,g_gridCount[k]);

   if(!Grid_Enable) return;                        // sem grid: uma ordem por lado
   if(level>=Grid_MaxOrders) return;
   if(Grid_RequireSignal && g_trend!=dir) return;

   double ref=(g_lastEntry[k]>0.0)?g_lastEntry[k]:worst;
   double step=GridStep(level);
   double px=(dir>0)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0.0 || ref<=0.0) return;

   double away=(dir>0)?(ref-px):(px-ref);          // so adiciona contra o preco
   if(away < step) return;

   OpenTrade(dir,NextLot(dir,level));
  }

double GridStep(const int count)
  {
   double mult=(Grid_StepMult>0.0)?Grid_StepMult:1.0;
   double pts=Grid_StepPoints*MathPow(mult,MathMax(0,count-1));
   return(pts*g_point);
  }

double NextLot(const int dir,const int count)
  {
   double lot=FIXED_LOT;
   if(Martin_Enable && count>0)
     {
      int levels=MathMin(count,MathMax(0,Martin_MaxLevels));
      double mult=(Martin_Multiplier>0.0)?Martin_Multiplier:1.0;
      lot=FIXED_LOT*MathPow(mult,levels);
      if(Martin_MaxLot>0.0 && lot>Martin_MaxLot) lot=Martin_MaxLot;
     }
   return(NormalizeLot(lot));
  }

double NormalizeLot(double lot)
  {
   double mn  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double stp = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(stp<=0.0) stp=mn;
   if(stp<=0.0) return(lot);

   lot=MathFloor(lot/stp+1e-8)*stp;
   if(lot<mn) lot=mn;
   if(mx>0.0 && lot>mx) lot=mx;
   return(NormalizeDouble(lot,2));
  }

void OpenTrade(const int dir,const double lot)
  {
   if(lot<=0.0) return;
   if(!MarginOk(dir,lot)) return;

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double px =(dir>0)?ask:bid;
   if(px<=0.0) return;

   double sl=0.0,tp=0.0;
   int    stops=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=stops*g_point;

   if(STOPLOSS>0.0)
     {
      double d=MathMax(STOPLOSS*g_point,minDist);
      sl=(dir>0)?(px-d):(px+d);
      sl=NormalizeDouble(sl,g_digits);
     }
   // com o ciclo ligado o alvo e da cesta inteira: ordem nenhuma leva TP proprio,
   // senao cada uma fecha sozinha e o take global nunca soma
   if(TAKEPROFIT>0.0 && !CycleOwnsTP())
     {
      double d=MathMax(TAKEPROFIT*g_point,minDist);
      tp=(dir>0)?(px+d):(px-d);
      tp=NormalizeDouble(tp,g_digits);
     }

   bool ok=(dir>0) ? trade.Buy(lot,_Symbol,0.0,sl,tp,EA_NAME)
                   : trade.Sell(lot,_Symbol,0.0,sl,tp,EA_NAME);

   if(!ok)
     {
      PrintFormat("RickEA MA: ordem %s recusada. retcode=%d (%s)",
                  (dir>0?"BUY":"SELL"),trade.ResultRetcode(),trade.ResultRetcodeDescription());
      return;
     }

   int k=(dir>0)?0:1;
   g_gridCount[k]++;
   g_lastEntry[k]=(trade.ResultPrice()>0.0)?trade.ResultPrice():px;
   g_lastLot[k]=lot;
   g_entryBar[k]=iTime(_Symbol,MA_Timeframe,0);
  }

bool MarginOk(const int dir,const double lot)
  {
   double px=(dir>0)?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double need=0.0;
   ENUM_ORDER_TYPE type=(dir>0)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(!OrderCalcMargin(type,_Symbol,lot,px,need)) return(true);   // nao deu pra calcular: deixa o servidor decidir
   if(need>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      static datetime warned=0;
      if(TimeCurrent()-warned>60)
        {
         warned=TimeCurrent();
         PrintFormat("RickEA MA: margem livre insuficiente para %.2f lote(s) (precisa %.2f).",lot,need);
        }
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Ciclo de take global                                             |
//+------------------------------------------------------------------+
bool CycleOwnsTP()
  {
   return(Cycle_Enable && Cycle_OverrideTP && Cycle_TakeProfit>0.0);
  }

// tira o TP individual de posicoes que ja estavam abertas com alvo proprio
void StripIndividualTP()
  {
   if(!CycleOwnsTP()) return;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol || pos.Magic()!=MagicNumber) continue;
      if(pos.TakeProfit()<=0.0) continue;

      if(trade.PositionModify(pos.Ticket(),pos.StopLoss(),0.0))
         PrintFormat("RickEA MA: TP individual removido de #%I64u - quem fecha e o take global.",pos.Ticket());
     }
  }

double CycleTarget(const double value)
  {
   if(Cycle_Unit==RICK_CYCLE_PERCENT)
      return(AccountInfoDouble(ACCOUNT_BALANCE)*value/100.0);
   return(value);
  }

void ManageCycle()
  {
   StripIndividualTP();

   if(Cycle_Scope==RICK_SCOPE_GLOBAL)
     {
      int count; double vol,prof,best,worst;
      BasketInfo(0,count,vol,prof,best,worst);
      if(count==0) return;
      CheckCycleClose(0,prof);
      return;
     }

   for(int k=0;k<2;k++)
     {
      int dir=(k==0)?1:-1;
      int count; double vol,prof,best,worst;
      BasketInfo(dir,count,vol,prof,best,worst);
      if(count==0) continue;
      CheckCycleClose(dir,prof);
     }
  }

void CheckCycleClose(const int dir,const double profit)
  {
   double tp=CycleTarget(Cycle_TakeProfit);
   double sl=CycleTarget(Cycle_StopLoss);

   if(tp>0.0 && profit>=tp)
     {
      CloseBasket(dir);
      PrintFormat("RickEA MA: ciclo fechado no take global (%.2f).",profit);
      if(Cycle_WaitNewSignal) g_blockDir=(dir!=0)?dir:g_trend;
      return;
     }
   if(sl>0.0 && profit<=-sl)
     {
      CloseBasket(dir);
      PrintFormat("RickEA MA: ciclo fechado no stop global (%.2f).",profit);
      if(Cycle_WaitNewSignal) g_blockDir=(dir!=0)?dir:g_trend;
     }
  }

void ManageReverse()
  {
   if(g_trend==0) return;
   int against=-g_trend;                         // lado que ficou contra a media
   int count; double vol,prof,best,worst;
   BasketInfo(against,count,vol,prof,best,worst);
   if(count>0) CloseBasket(against);
  }

void CloseBasket(const int dir)
  {
   ENUM_POSITION_TYPE want=(dir>0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol || pos.Magic()!=MagicNumber) continue;
      if(dir!=0 && pos.PositionType()!=want) continue;

      ulong ticket=pos.Ticket();
      if(!trade.PositionClose(ticket))
         PrintFormat("RickEA MA: falha ao fechar #%I64u. retcode=%d (%s)",
                     ticket,trade.ResultRetcode(),trade.ResultRetcodeDescription());
     }
   SyncBaskets();
  }

//+------------------------------------------------------------------+
//| Trailing stop                                                    |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   if(TRAILINGSTOP<=0.0) return;                 // if 0 value >> OFF

   int    stops   = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stops*g_point;
   double bid     = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0) return;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol || pos.Magic()!=MagicNumber) continue;

      bool   isBuy = (pos.PositionType()==POSITION_TYPE_BUY);
      double open  = pos.PriceOpen();
      double cur   = isBuy?bid:ask;
      double curSL = pos.StopLoss();
      double gain  = (isBuy?(cur-open):(open-cur))/g_point;

      if(TRAILINGSTART>0.0 && gain<TRAILINGSTART) continue;

      double dist=MathMax(TRAILINGSTOP*g_point,minDist);
      double newSL=isBuy?(cur-dist):(cur+dist);

      if(BreakEvenFirst)
        {
         if(isBuy  && newSL<open) newSL=open;
         if(!isBuy && newSL>open) newSL=open;
        }

      newSL=NormalizeDouble(newSL,g_digits);

      // nunca piora o stop e respeita o passo minimo
      if(curSL>0.0)
        {
         double step=TRAILINGSTEP*g_point;
         if(isBuy  && newSL <= curSL+step) continue;
         if(!isBuy && newSL >= curSL-step) continue;
        }
      else
        {
         if(isBuy  && newSL>=cur) continue;
         if(!isBuy && newSL<=cur) continue;
        }

      if(isBuy  && cur-newSL<minDist) continue;
      if(!isBuy && newSL-cur<minDist) continue;

      if(!trade.PositionModify(pos.Ticket(),newSL,pos.TakeProfit()))
         PrintFormat("RickEA MA: trailing falhou em #%I64u. retcode=%d (%s)",
                     pos.Ticket(),trade.ResultRetcode(),trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| VISUAL                                                           |
//+------------------------------------------------------------------+
color ChartBg()
  {
   return((color)ChartGetInteger(0,CHART_COLOR_BACKGROUND));
  }

color Blend(const color fg,const color bg,const double alpha)
  {
   double a=MathMax(0.0,MathMin(1.0,alpha));
   int fr= (int)( fg      & 0xFF), fgn=(int)((fg>>8) & 0xFF), fb=(int)((fg>>16) & 0xFF);
   int br= (int)( bg      & 0xFF), bgn=(int)((bg>>8) & 0xFF), bb=(int)((bg>>16) & 0xFF);

   int r=(int)(fr*a+br*(1.0-a));
   int g=(int)(fgn*a+bgn*(1.0-a));
   int b=(int)(fb*a+bb*(1.0-a));
   return((color)((b<<16)|(g<<8)|r));
  }

color TrendColor()
  {
   if(g_trend>0) return(Panel_TrendUp);
   if(g_trend<0) return(Panel_TrendDown);
   return(clrSilver);
  }

void DrawVisuals()
  {
   if(BigPrice_Show || Panel_Show) DrawPanel();
   ChartRedraw();
  }

//--- painel + preco grande, tudo no canto superior direito ---------
void DrawPanel()
  {
   color accent = TrendColor();
   color bg     = ChartBg();
   color fill   = Blend(accent,bg,Panel_Opacity/100.0);
   color head   = Blend(accent,bg,MathMin(1.0,(Panel_Opacity+14)/100.0));

   int pad      = 12;
   int headH    = 24;
   int priceH   = (BigPrice_Show ? BigPrice_Size+16 : 0);
   int rowH     = 17;

   //--- dados
   int    cb,cs; double vb,vs,pb,ps,bb,bs,wb,ws;
   BasketInfo( 1,cb,vb,pb,bb,wb);
   BasketInfo(-1,cs,vs,ps,bs,ws);
   double floating=pb+ps;

   int rows=8;
   int panelH=headH+priceH+pad+rows*rowH+pad;

   // OBJ_RECTANGLE_LABEL com canto a direita mede a distancia ate a borda
   // ESQUERDA da caixa e cresce pra direita - por isso soma a largura aqui,
   // senao o quadro sai pra fora, por cima da escala de preco.
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
      double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      color  pc=BigPrice_ByTrend?accent:BigPrice_Fixed;
      Text(PFX+"T_PRICE",xr,y+6,DoubleToString(px,g_digits),pc,BigPrice_Size,true,ANCHOR_RIGHT_UPPER,"Arial Black");
      Text(PFX+"T_TREND",xl,y+6+BigPrice_Size/2-6,(g_trend>0?"ALTA":(g_trend<0?"BAIXA":"---")),pc,10,true,ANCHOR_LEFT_UPPER);
      y+=priceH;
     }
   else
      Row(PFX+"R_TREND","Tendencia",(g_trend>0?"ALTA":(g_trend<0?"BAIXA":"---")),accent,xl,xr,y);

   y+=pad;

   string maName=MethodName()+"("+(string)EMA+") "+TFName();
   Row(PFX+"R_MA",   maName,            DoubleToString(g_maValue,g_digits),   clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_DIR",  "Direcao",         DirName(),                            clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_ENTRY","Entrada",         EntryName(),                          clrWhite, xl,xr,y); y+=rowH;
   Row(PFX+"R_BUY",  "Compras",         StringFormat("%d (%.2f)  %.2f",cb,vb,pb),
                                        (pb>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y); y+=rowH;
   Row(PFX+"R_SELL", "Vendas",          StringFormat("%d (%.2f)  %.2f",cs,vs,ps),
                                        (ps>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y); y+=rowH;
   Row(PFX+"R_MODE", "Grid / Martin",   (Grid_Enable?"ON":"OFF")+" / "+(Martin_Enable?"ON":"OFF"),
                                        clrWhite, xl,xr,y); y+=rowH;

   string cyc="OFF";
   if(Cycle_Enable)
     {
      double tgt=CycleTarget(Cycle_TakeProfit);
      cyc=StringFormat("%.2f / %.2f",floating,tgt);
     }
   Row(PFX+"R_CYCLE","Take global",     cyc,
                     (Cycle_Enable?(floating>=0?Panel_TrendUp:Panel_TrendDown):clrSilver), xl,xr,y); y+=rowH;

   Row(PFX+"R_PL",   "Flutuante / Eq.",
                     StringFormat("%.2f / %.2f",floating,AccountInfoDouble(ACCOUNT_EQUITY)),
                     (floating>=0?Panel_TrendUp:Panel_TrendDown), xl,xr,y);
  }

void Row(const string id,const string label,const string value,const color vclr,
         const int xl,const int xr,const int y)
  {
   Text(id+"_L",xl,y,label,Blend(clrWhite,ChartBg(),0.70),9,false,ANCHOR_LEFT_UPPER);
   Text(id+"_V",xr,y,value,vclr,9,true,ANCHOR_RIGHT_UPPER);
  }

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

//--- logo preenchendo o fundo do grafico ---------------------------
void DrawLogo()
  {
   for(int i=0;i<g_logoCount;i++) ObjectDelete(0,PFX+"LOGO_"+(string)i);
   g_logoCount=0;
   if(!Logo_Show || g_logoFailed) return;

   int w=(g_chartW>0)?g_chartW:(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int h=(g_chartH>0)?g_chartH:(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(w<=0 || h<=0) return;

   int size=MathMax(16,Logo_Size);

   if(Logo_Mode==RICK_LOGO_CENTER)
     {
      LogoTile(0,(w-size)/2,(h-size)/2,size);
      g_logoCount=1;
      return;
     }

   int step=size+MathMax(0,Logo_Gap);
   int cols=(int)MathCeil((double)w/step);
   int lines=(int)MathCeil((double)h/step);
   int total=cols*lines;
   if(total>240)                       // teto de objetos: aumenta o espaco antes de estourar
     {
      Print("RickEA MA: mosaico grande demais - aumente Logo_Size ou Logo_Gap.");
      step=(int)MathCeil(MathSqrt((double)w*h/240.0));
      cols=(int)MathCeil((double)w/step);
      lines=(int)MathCeil((double)h/step);
     }

   int n=0;
   for(int r=0;r<lines;r++)
      for(int c=0;c<cols;c++)
        {
         int x=c*step+((r%2==0)?0:step/2);     // fileiras alternadas: fica mais organico
         int y=r*step;
         if(x>w) continue;
         if(!LogoTile(n,x,y,size)) { g_logoCount=n; return; }
         n++;
        }
   g_logoCount=n;
  }

bool LogoTile(const int idx,const int x,const int y,const int size)
  {
   string name=PFX+"LOGO_"+(string)idx;
   if(ObjectFind(0,name)<0)
     {
      if(!ObjectCreate(0,name,OBJ_BITMAP_LABEL,0,0,0)) return(false);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);      // atras das velas
     }
   if(!ObjectSetString(0,name,OBJPROP_BMPFILE,"\\Images\\"+Logo_File))
     {
      ObjectDelete(0,name);
      g_logoFailed=true;
      Print("RickEA MA: nao achei \\Images\\",Logo_File," - copie o BMP para MQL5\\Images.");
      return(false);
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,size);
   return(true);
  }

//--- nomes amigaveis para o painel ---------------------------------
string TFName()
  {
   ENUM_TIMEFRAMES tf=(MA_Timeframe==PERIOD_CURRENT)?(ENUM_TIMEFRAMES)_Period:MA_Timeframe;
   string s=EnumToString(tf);
   StringReplace(s,"PERIOD_","");
   return(s);
  }

string MethodName()
  {
   switch(MA_Method)
     {
      case MODE_SMA:  return("SMA");
      case MODE_EMA:  return("EMA");
      case MODE_SMMA: return("SMMA");
      case MODE_LWMA: return("LWMA");
     }
   return("MA");
  }

string DirName()
  {
   switch(TradeDirection)
     {
      case RICK_BUY_ONLY:  return("So compras");
      case RICK_SELL_ONLY: return("So vendas");
     }
   return("Compras e vendas");
  }

string EntryName()
  {
   switch(EntryMode)
     {
      case RICK_ENTRY_BAR_OPEN:  return("Por vela");
      case RICK_ENTRY_BAR_CROSS: return("Cruzamento");
     }
   return("Tick");
  }
//+------------------------------------------------------------------+
