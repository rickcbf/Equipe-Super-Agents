//+------------------------------------------------------------------+
//|                                        RickEA_B3-Strategy.mq5     |
//|                          RickEA Investments - @ri.chartrader      |
//|                                                                  |
//|  Automatiza o setup MANUAL do print (timeframe padrao M3):        |
//|                                                                  |
//|  VENDA (SELL):                                                    |
//|   1) Vela GATILHO cruza a EMA 7 pra BAIXO (abre acima, fecha      |
//|      abaixo) e e uma vela de baixa (corpo forte, opcional).       |
//|   2) HiLo Activator virou/esta VERMELHO.                          |
//|   3) Confluencia: Estocastico (6,3,3) rompeu o nivel 80 pra baixo |
//|      em ate N velas (padrao 5).                                   |
//|   -> Entrada no ROMPIMENTO pra baixo da vela gatilho (Sell Stop). |
//|   -> Stop ACIMA da vela gatilho. Alvo 3:1 (configuravel).         |
//|                                                                  |
//|  COMPRA (BUY) = espelho:                                          |
//|   1) Vela GATILHO cruza a EMA 7 pra CIMA (abre abaixo, fecha      |
//|      acima) e e vela de alta.                                     |
//|   2) HiLo Activator virou/esta VERDE.                             |
//|   3) Estocastico rompeu o nivel 20 pra cima em ate N velas.       |
//|   -> Entrada no ROMPIMENTO pra cima (Buy Stop). Stop ABAIXO.      |
//|      Alvo 3:1.                                                    |
//|                                                                  |
//|  Avaliacao SEMPRE na vela FECHADA (shift 1) -> nao repinta.       |
//|  1 operacao por vez. HiLo embutido (Gann). Lote por risco %.      |
//+------------------------------------------------------------------+
#property copyright "RickEA Investments"
#property link      "https://rickea.vercel.app"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade         trade;

//==================== INPUTS ====================
input group "== Identificacao =="
input long   InpMagic         = 76030300;                 // Magic number
input string InpComment       = "RickEA B3-Strategy";     // Comentario das ordens

input group "== Media 7 EMA (gatilho / envelope Rick) =="
input int                InpEmaPeriod = 7;                 // Periodo da EMA (gatilho)
input ENUM_APPLIED_PRICE InpEmaPrice  = PRICE_CLOSE;       // Preco da EMA

input group "== HiLo Activator (embutido - Gann) =="
input bool   InpHiLoUseCustom = false;                     // Usar indicador externo (iCustom)?
input string InpHiLoName      = "LT HiLo Activator";       // Nome do indicador em MQL5/Indicators
input int    InpHiLoBuffer    = 0;                         // Buffer da linha/direcao do iCustom
input int    InpHiLoPeriod    = 3;                         // Periodo do HiLo interno

input group "== Estocastico (6,3,3) =="
input int    InpStochK        = 6;                         // %K
input int    InpStochD        = 3;                         // %D
input int    InpStochSlow     = 3;                         // Slowing
input double InpStochHigh     = 80.0;                      // Nivel alto (venda)
input double InpStochLow      = 20.0;                      // Nivel baixo (compra)
input int    InpStochLookback = 5;                         // Confluencia: rompeu o nivel em ate N velas

input group "== Sinal / entrada =="
input bool   InpAllowBuy      = true;                      // Permitir compras
input bool   InpAllowSell     = true;                      // Permitir vendas
input double InpMinBodyRatio  = 0.5;                       // Corpo minimo da vela gatilho (0=desliga)
input bool   InpRequireHiLoTurn = false;                   // Exigir HiLo VIRANDO (nao so o estado)
input double InpRR            = 3.0;                        // Alvo em R:R (3 = 3 pra 1)
input int    InpSLBufferPts   = 2;                         // Folga do stop (pontos) alem da vela
input int    InpPendingExpiry = 3;                         // Cancela a pendente se nao romper em N velas
input int    InpMaxSpreadPts  = 0;                         // Spread maximo (pontos, 0=off)

input group "== Lote / risco =="
input int    InpLotMode       = 1;                         // 0=Lote fixo  1=Risco %
input double InpLotFixed      = 0.05;                      // Lote fixo (modo 0)
input double InpRiskPercent   = 1.0;                       // Risco % da conta (modo 1)

input group "== Filtro de horario (opcional) =="
input bool   InpUseHours      = false;                     // Ativar filtro de horario
input int    InpHourStart     = 0;                         // Hora inicial (0-23)
input int    InpHourEnd       = 24;                        // Hora final (1-24)

input group "== Execucao =="
input int    InpDeviationPts  = 20;                        // Desvio maximo (pontos)

//==================== GLOBAIS ====================
int      hEma   = INVALID_HANDLE;
int      hStoch = INVALID_HANDLE;
int      hHiLo  = INVALID_HANDLE;
datetime g_lastBar = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints((ulong)InpDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   hEma = iMA(_Symbol,_Period,InpEmaPeriod,0,MODE_EMA,InpEmaPrice);
   hStoch = iStochastic(_Symbol,_Period,InpStochK,InpStochD,InpStochSlow,MODE_SMA,STO_LOWHIGH);
   if(hEma==INVALID_HANDLE || hStoch==INVALID_HANDLE)
     {
      Print("Erro ao criar handles de indicadores.");
      return(INIT_FAILED);
     }

   if(InpHiLoUseCustom)
     {
      hHiLo = iCustom(_Symbol,_Period,InpHiLoName);
      if(hHiLo==INVALID_HANDLE)
         Print("Aviso: nao consegui carregar o iCustom '",InpHiLoName,
               "'. Confira o nome/caminho em MQL5/Indicators. Usando estado neutro.");
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hEma!=INVALID_HANDLE)   IndicatorRelease(hEma);
   if(hStoch!=INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hHiLo!=INVALID_HANDLE)  IndicatorRelease(hHiLo);
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime t0 = iTime(_Symbol,_Period,0);
   if(t0==0) return;
   if(t0==g_lastBar) return;   // so processa 1x por vela (na abertura da nova = fecho da anterior)
   g_lastBar = t0;

   ManagePending();                 // expira pendentes antigas

   if(HasPosition() || HasPending()) // 1 operacao por vez
      return;

   if(InpUseHours && !HourAllowed())
      return;

   if(InpMaxSpreadPts>0)
     {
      long spr = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
      if(spr>InpMaxSpreadPts) return;
     }

   CheckSignals();
  }
//+------------------------------------------------------------------+
//|  Avalia o setup na vela fechada (shift 1)                        |
//+------------------------------------------------------------------+
void CheckSignals()
  {
   int need = MathMax(InpEmaPeriod, InpStochLookback+3);
   if(Bars(_Symbol,_Period) < need+InpHiLoPeriod+260) return;

   double ema1 = IndVal(hEma,0,1);
   if(ema1==EMPTY_VALUE || ema1<=0) return;

   double o = iOpen (_Symbol,_Period,1);
   double h = iHigh (_Symbol,_Period,1);
   double l = iLow  (_Symbol,_Period,1);
   double c = iClose(_Symbol,_Period,1);
   if(o==0 || h==0 || l==0 || c==0) return;

   double rng = h-l;
   bool bodyOK = (InpMinBodyRatio<=0.0) ||
                 (rng>0 && MathAbs(c-o) >= InpMinBodyRatio*rng);

   int dir1 = HiLoDir(1);
   int dir2 = HiLoDir(2);

   //--- VENDA ---------------------------------------------------------
   if(InpAllowSell)
     {
      bool trigger = (o>ema1 && c<ema1 && c<o);          // cruzou EMA 7 pra baixo, vela de baixa
      bool hilo    = InpRequireHiLoTurn ? (dir1==-1 && dir2!=-1) : (dir1==-1);
      bool stoch   = StochCrossedDown();                  // rompeu 80 pra baixo em ate N velas
      if(trigger && bodyOK && hilo && stoch)
        {
         OpenSetup(true,o,h,l,c);
         return;
        }
     }

   //--- COMPRA --------------------------------------------------------
   if(InpAllowBuy)
     {
      bool trigger = (o<ema1 && c>ema1 && c>o);           // cruzou EMA 7 pra cima, vela de alta
      bool hilo    = InpRequireHiLoTurn ? (dir1==1 && dir2!=1) : (dir1==1);
      bool stoch   = StochCrossedUp();                     // rompeu 20 pra cima em ate N velas
      if(trigger && bodyOK && hilo && stoch)
        {
         OpenSetup(false,o,h,l,c);
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//|  Monta e envia a operacao (Sell/Buy Stop no rompimento)          |
//+------------------------------------------------------------------+
void OpenSetup(bool isSell,double o,double h,double l,double c)
  {
   double point = _Point;
   double buf   = InpSLBufferPts*point;
   double entry, sl, tp, risk;

   if(isSell)
     {
      entry = l;                 // rompimento pra baixo
      sl    = h + buf;           // stop acima da vela gatilho
      risk  = sl - entry;
      if(risk<=0) return;
      tp    = entry - InpRR*risk;
     }
   else
     {
      entry = h;                 // rompimento pra cima
      sl    = l - buf;           // stop abaixo da vela gatilho
      risk  = entry - sl;
      if(risk<=0) return;
      tp    = entry + InpRR*risk;
     }

   entry = NormalizeDouble(entry,_Digits);
   sl    = NormalizeDouble(sl,_Digits);
   tp    = NormalizeDouble(tp,_Digits);

   //--- respeita a distancia minima do broker (stops level)
   double minDist = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   if(risk < minDist)
     {
      Print("Setup ignorado: risco (",DoubleToString(risk,_Digits),
            ") < distancia minima do broker (",DoubleToString(minDist,_Digits),").");
      return;
     }

   double lots = CalcLots(risk);
   if(lots<=0) return;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   // pendente fica GTC; a expiracao por N velas e tratada em ManagePending()
   // (evita rejeicao em brokers que nao aceitam ORDER_TIME_SPECIFIED).

   bool ok=false;
   if(isSell)
     {
      // se o preco JA rompeu pra baixo, entra a mercado; senao, Sell Stop
      if(bid <= entry + minDist)
         ok = trade.Sell(lots,_Symbol,0.0,sl,tp,InpComment);
      else
         ok = trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,0,InpComment);
     }
   else
     {
      if(ask >= entry - minDist)
         ok = trade.Buy(lots,_Symbol,0.0,sl,tp,InpComment);
      else
         ok = trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,0,InpComment);
     }

   if(!ok)
      Print("Falha ao enviar ordem. retcode=",trade.ResultRetcode(),
            " - ",trade.ResultRetcodeDescription());
   else
      Print(isSell?"SELL":"BUY"," setup enviado. entry=",DoubleToString(entry,_Digits),
            " SL=",DoubleToString(sl,_Digits)," TP=",DoubleToString(tp,_Digits),
            " lote=",DoubleToString(lots,2));
  }
//+------------------------------------------------------------------+
//|  Cancela pendentes que nao romperam dentro do prazo              |
//+------------------------------------------------------------------+
void ManagePending()
  {
   if(InpPendingExpiry<=0) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      long type = OrderGetInteger(ORDER_TYPE);
      if(type!=ORDER_TYPE_SELL_STOP && type!=ORDER_TYPE_BUY_STOP) continue;

      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int barsElapsed = (int)((TimeCurrent()-setup)/PeriodSeconds());
      if(barsElapsed >= InpPendingExpiry)
         trade.OrderDelete(tk);
     }
  }
//+------------------------------------------------------------------+
//|  HiLo Activator (Gann) embutido -> +1 verde / -1 vermelho / 0    |
//+------------------------------------------------------------------+
int HiLoDir(int shift)
  {
   if(InpHiLoUseCustom && hHiLo!=INVALID_HANDLE)
     {
      double v = IndVal(hHiLo,InpHiLoBuffer,shift);
      double c = iClose(_Symbol,_Period,shift);
      if(v==EMPTY_VALUE || v==0 || c==0) return 0;
      return (c>v) ? 1 : -1;
     }

   int P = InpHiLoPeriod;
   if(P<1) P=1;
   int win = 250;                                  // janela p/ estabilizar o estado
   int total = win + P + shift + 2;

   double hh[],ll[],cc[];
   ArraySetAsSeries(hh,true); ArraySetAsSeries(ll,true); ArraySetAsSeries(cc,true);
   if(CopyHigh (_Symbol,_Period,0,total,hh)<total) return 0;
   if(CopyLow  (_Symbol,_Period,0,total,ll)<total) return 0;
   if(CopyClose(_Symbol,_Period,0,total,cc)<total) return 0;

   int oldest = total - P - 2;                     // ultimo indice que tem P barras anteriores
   int prevDir = 0;
   for(int i=oldest;i>=shift;i--)
     {
      double sumH=0, sumL=0;
      for(int k=1;k<=P;k++){ sumH+=hh[i+k]; sumL+=ll[i+k]; }
      double smaH=sumH/P, smaL=sumL/P;
      int d;
      if(cc[i]>smaH)      d=1;
      else if(cc[i]<smaL) d=-1;
      else                d=(prevDir==0)?((cc[i]>=smaH)?1:-1):prevDir;
      prevDir=d;
     }
   return prevDir;
  }
//+------------------------------------------------------------------+
//|  Estocastico rompeu o nivel 80 pra BAIXO em ate N velas          |
//+------------------------------------------------------------------+
bool StochCrossedDown()
  {
   int n = InpStochLookback;
   if(n<1) n=1;
   double k[];
   ArraySetAsSeries(k,true);
   if(CopyBuffer(hStoch,MAIN_LINE,1,n+1,k) < n+1) return false;
   for(int i=0;i<n;i++)                             // shift 1..n
      if(k[i] < InpStochHigh && k[i+1] >= InpStochHigh)
         return true;
   return false;
  }
//+------------------------------------------------------------------+
//|  Estocastico rompeu o nivel 20 pra CIMA em ate N velas           |
//+------------------------------------------------------------------+
bool StochCrossedUp()
  {
   int n = InpStochLookback;
   if(n<1) n=1;
   double k[];
   ArraySetAsSeries(k,true);
   if(CopyBuffer(hStoch,MAIN_LINE,1,n+1,k) < n+1) return false;
   for(int i=0;i<n;i++)
      if(k[i] > InpStochLow && k[i+1] <= InpStochLow)
         return true;
   return false;
  }
//+------------------------------------------------------------------+
//|  Lote por risco % (ou fixo)                                      |
//+------------------------------------------------------------------+
double CalcLots(double riskPriceDist)
  {
   if(InpLotMode==0) return NormalizeLot(InpLotFixed);

   double tickVal  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickVal<=0 || tickSize<=0) return NormalizeLot(InpLotFixed);

   double riskMoney   = AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercent/100.0;
   double moneyPerLot = (riskPriceDist/tickSize)*tickVal;
   if(moneyPerLot<=0) return NormalizeLot(InpLotFixed);

   return NormalizeLot(riskMoney/moneyPerLot);
  }
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
  {
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   lots = MathFloor(lots/step)*step;
   if(lots<mn) lots=mn;
   if(lots>mx) lots=mx;
   return lots;
  }
//+------------------------------------------------------------------+
//|  Utilitarios                                                     |
//+------------------------------------------------------------------+
double IndVal(int handle,int buffer,int shift)
  {
   double a[];
   ArraySetAsSeries(a,true);
   if(CopyBuffer(handle,buffer,shift,1,a)==1) return a[0];
   return EMPTY_VALUE;
  }
//+------------------------------------------------------------------+
bool HasPosition()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)==InpMagic) return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
bool HasPending()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      long type = OrderGetInteger(ORDER_TYPE);
      if(type==ORDER_TYPE_SELL_STOP || type==ORDER_TYPE_BUY_STOP) return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
bool HourAllowed()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   int hr = dt.hour;
   if(InpHourStart<=InpHourEnd)
      return (hr>=InpHourStart && hr<InpHourEnd);
   return (hr>=InpHourStart || hr<InpHourEnd);   // janela que cruza a meia-noite
  }
//+------------------------------------------------------------------+
