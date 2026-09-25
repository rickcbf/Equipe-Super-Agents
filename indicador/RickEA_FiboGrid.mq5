//+------------------------------------------------------------------+
//|                                       RickEA_FiboGrid_EA.mq5     |
//|                                Copyright 2025, Richartrader Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RickEA FIBO GRID"
#property version   "1.02"
#property description "Instagram:@ri.chartrader"

#include <Trade\Trade.mqh>

//--- modo do take profit da cesta
enum ENUM_TPMODE
  {
   TP_MONEY_TOTAL=0,   // Dinheiro: valor fixo para a cesta (US$)
   TP_MONEY_PER_POS=1, // Dinheiro: valor x numero de ordens (US$)
   TP_POINTS_AVG=2     // Pontos a partir do preco medio
  };

//--- direcao das operacoes
enum ENUM_TRADEDIR
  {
   DIR_BOTH=0,       // Compras e vendas
   DIR_BUY_ONLY=1,   // Somente compras
   DIR_SELL_ONLY=2   // Somente vendas
  };

//--- deteccao da pernada
input string InpBrand          = "RICKEA FIBO GRID"; // Titulo / marca
input ENUM_TRADEDIR InpTradeDir = DIR_BOTH; // Direcao: compras, vendas ou ambas
input int    InpSwingDepth     = 5;        // Fractal: barras de cada lado do topo/fundo
input int    InpLegLookback    = 400;      // Barras analisadas para achar a pernada
input int    InpMinLegPoints   = 300;      // Tamanho minimo da pernada (pontos)
//--- zona de operacao (retracao de Fibonacci)
input double InpFibFrom        = 0.0;      // Inicio da zona (% de retracao)
input double InpFibTo          = 38.2;     // Fim da zona - para de abrir ordens (% retracao)
input double InpFibStop        = 23.0;     // Stop: % da pernada PARA FORA do extremo
//--- grid
input double InpLots           = 0.01;     // Lote da primeira ordem
input double InpLotMultiplier  = 1.0;      // Multiplicador de lote por nivel (1.0 = lote fixo)
input int    InpGridPoints     = 200;      // Espacamento do grid (pontos)
input int    InpMaxPositions   = 10;       // Maximo de ordens no ciclo
input bool   InpAttachSL       = true;     // Deixar SL no nivel de stop (protecao no servidor)
//--- take profit / encerramento
input ENUM_TPMODE InpTPMode    = TP_MONEY_TOTAL; // Modo do take da cesta
input double InpTPMoney        = 2.0;      // Take em dinheiro (US$)
input int    InpTPPoints       = 150;      // Take em pontos do preco medio (modo pontos)
input double InpMaxLossMoney   = 0.0;      // Perda maxima da cesta (US$, 0 = desligado)
input bool   InpReenterAfterTP = false;    // Reentrar na MESMA pernada depois do take
//--- visual (mesma pegada do RickEA TOP/BOTTOM)
input bool   InpShowFibo       = true;     // Plotar a FIBO no grafico
input color  InpSellClr        = clrRed;   // Cor da zona de VENDA (pernada de alta)
input color  InpBuyClr         = clrLime;  // Cor da zona de COMPRA (pernada de queda)
input int    InpOpacity        = 18;       // Opacidade do preenchimento (0-100)
input color  InpStopClr        = clrOrange;// Cor da linha de stop
input bool   InpShowLevels     = true;     // Desenhar as linhas dos niveis de Fibo
input int    InpExtendBars     = 0;        // Prolongar N barras alem da vela atual
input int    InpZoneFontSize   = 14;       // Tamanho do texto da zona
input bool   InpShowPanel      = true;     // Painel de status no canto
input int    InpPanelFontSize  = 9;        // Tamanho da fonte do painel
//--- preco grande (igual ao RickEA TOP/BOTTOM / X-TREND)
input bool   InpBigPrice       = true;     // Preco grande no canto sup. direito
input int    InpBigPriceSize   = 26;       // Tamanho da fonte do preco grande
input bool   InpBigPriceByTrend= true;     // Cor pela tendencia (verde alta/vermelho baixa)
input color  InpBigPriceClr    = clrYellow;// Cor fixa (se ByTrend=false)
input int    InpAtrPeriod      = 10;       // ATR Period (tendencia do preco grande)
input double InpAtrMult        = 3.0;      // ATR Multiplier (tendencia do preco grande)
input int    InpTrendBars      = 500;      // Barras usadas no calculo da tendencia
//--- geral
input long   InpMagic          = 20260920; // Magic number
input int    InpSlippage       = 20;       // Desvio maximo (pontos)
input bool   InpAlertPush      = false;    // PUSH no celular (abriu/fechou ciclo)
input bool   InpAlertPopup     = false;    // Alerta popup no terminal

//--- pernada
struct SLeg
  {
   bool     ok;      // pernada valida
   int      dir;     // +1 alta (grid de VENDA) / -1 queda (grid de COMPRA)
   double   ext;     // extremo da pernada = 0% de retracao
   double   base;    // origem da pernada  = 100% de retracao
   datetime tBase;   // tempo da origem
   datetime tExt;    // tempo do extremo
  };

CTrade   trade;
string   PFX="FG_";
SLeg     g_leg;                 // pernada viva (recalculada quando esta fora do mercado)
SLeg     g_lock;                // pernada travada durante o ciclo
bool     g_active=false;        // ciclo em andamento
bool     g_closing=false;       // pediu fechamento, esperando zerar
datetime g_blockBase=0;         // origem da pernada bloqueada (stop/take)
int      g_blockDir=0;          // direcao da pernada bloqueada
datetime g_lastBar=0;
double   g_pt=0.0;
int      g_hAtr=INVALID_HANDLE;
int      g_trendDir=0;          // +1 alta / -1 baixa (SuperTrend/ATR, so para a cor do preco)

//--- prototipos
bool   FindLeg(SLeg &leg);
double FibLevel(const SLeg &leg,double pct);
double StopPrice(const SLeg &leg);
double RetPct(const SLeg &leg,double price);
void   CycleStats(int &cnt,double &lots,double &avg,double &profit);
double MinDistance(double price);
bool   TakeHit(int cnt,double avg,double profit,double bid,double ask);
bool   OpenOrder(const SLeg &leg,int cnt);
void   CloseAll(string why);
void   AdoptPositions(int cnt);
void   BlockLeg(const SLeg &leg);
bool   IsBlocked(const SLeg &leg);
void   EndCycle(string why);
bool   TradeAllowed();
bool   DirAllowed(int dir);
string DirName();
double NormLot(double lot);
void   DrawFibo(const SLeg &leg);
void   DeleteFibo();
void   Zone(string id,double top,double bot,color clr,string text,datetime tStart,datetime tEnd);
void   Level(string id,double price,color clr,int style,datetime tStart,datetime tEnd,string tag);
void   LegLine(const SLeg &leg,color clr);
void   Panel(const SLeg &leg,int cnt,double lots,double avg,double profit);
int    TrendDir();
void   BigPrice(int dir,double px);
void   PanelLine(int idx,string text,color clr);
void   Notify(string msg);
color  Fade(color clr,int pct);
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFibTo<=InpFibFrom)
     {
      Print(InpBrand,": o fim da zona (InpFibTo) tem que ser maior que o inicio (InpFibFrom).");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpFibStop<=0.0)
     {
      Print(InpBrand,": InpFibStop tem que ser maior que zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpGridPoints<=0)
     {
      Print(InpBrand,": InpGridPoints tem que ser maior que zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLots<=0.0 || InpLotMultiplier<=0.0)
     {
      Print(InpBrand,": lote invalido.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMaxPositions<1)
     {
      Print(InpBrand,": InpMaxPositions tem que ser pelo menos 1.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpSwingDepth<2)
     {
      Print(InpBrand,": InpSwingDepth tem que ser pelo menos 2.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLegLookback<InpSwingDepth*4+20)
     {
      Print(InpBrand,": InpLegLookback curto demais para esse InpSwingDepth.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpAtrPeriod<1)
     {
      Print(InpBrand,": InpAtrPeriod tem que ser pelo menos 1.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_pt=_Point;
   g_hAtr=iATR(_Symbol,_Period,InpAtrPeriod);
   if(g_hAtr==INVALID_HANDLE)
     {
      Print(InpBrand,": nao foi possivel criar o ATR da tendencia.");
      return(INIT_FAILED);
     }
   Print(InpBrand,": direcao das operacoes = ",DirName(),".");
   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints((ulong)InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   g_leg.ok=false;
   g_lock.ok=false;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_hAtr!=INVALID_HANDLE)
      IndicatorRelease(g_hAtr);
   ObjectsDeleteAll(0,PFX);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;
   //--- nova barra?
   datetime bt=(datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
   bool newBar=(bt!=g_lastBar);
   if(newBar)
      g_lastBar=bt;
   //--- estado do ciclo
   int    cnt=0;
   double lots=0.0,avg=0.0,profit=0.0;
   CycleStats(cnt,lots,avg,profit);
   if(cnt>0 && !g_active)
      AdoptPositions(cnt);
   if(cnt==0 && g_active)
      EndCycle("posicoes zeradas");
   if(cnt==0)
      g_closing=false;
   //--- pernada: recalcula quando esta fora do mercado
   if(!g_active && (newBar || !g_leg.ok))
      FindLeg(g_leg);
   SLeg leg=g_leg;
   if(g_active && g_lock.ok)
      leg=g_lock;
   //--- visual
   if(InpShowFibo && leg.ok)
      DrawFibo(leg);
   if(InpShowFibo && !leg.ok)
      DeleteFibo();
   if(InpShowPanel)
      Panel(leg,cnt,lots,avg,profit);
   if(InpBigPrice)
     {
      if(newBar || g_trendDir==0)
         g_trendDir=TrendDir();
      BigPrice(g_trendDir,bid);
     }
   ChartRedraw();
   //--- gestao do ciclo aberto
   if(cnt>0)
     {
      if(g_lock.ok)
        {
         double stop=StopPrice(g_lock);
         bool hitStop=(g_lock.dir==1)?(ask>=stop):(bid<=stop);
         if(hitStop && !g_closing)
           {
            CloseAll("STOP FIBO "+DoubleToString(InpFibStop,1)+"% fora da pernada");
            BlockLeg(g_lock);
            return;
           }
        }
      if(InpMaxLossMoney>0.0 && profit<=-InpMaxLossMoney && !g_closing)
        {
         CloseAll("PERDA MAXIMA da cesta ("+DoubleToString(profit,2)+" US$)");
         BlockLeg(g_lock);
         return;
        }
      if(!g_closing && TakeHit(cnt,avg,profit,bid,ask))
        {
         CloseAll("TAKE da cesta ("+DoubleToString(profit,2)+" US$)");
         if(!InpReenterAfterTP)
            BlockLeg(g_lock);
         return;
        }
     }
   //--- entradas
   if(g_closing)
      return;
   if(!TradeAllowed())
      return;
   if(!leg.ok)
      return;
   if(IsBlocked(leg))
      return;
   if(!DirAllowed(leg.dir))                 // filtro: somente compras / somente vendas
      return;
   if(cnt>0 && !g_lock.ok)   // ciclo assumido sem pernada compativel: nao abre grid novo
      return;
   if(cnt>=InpMaxPositions)
      return;
   double px=(leg.dir==1)?bid:ask;          // vende no bid / compra no ask
   double ret=RetPct(leg,px);
   if(ret<InpFibFrom || ret>InpFibTo)       // so opera dentro da zona 0% -> 38.2%
      return;
   if(cnt>0 && MinDistance(px)<InpGridPoints*g_pt-g_pt/2.0)
      return;                               // respeita o espacamento do grid
   if(!OpenOrder(leg,cnt))
      return;
   if(cnt==0)
     {
      g_lock=leg;                           // trava a pernada no inicio do ciclo
      g_active=true;
     }
   Notify((leg.dir==1?"VENDA":"COMPRA")+" #"+IntegerToString(cnt+1)+" @ "+
          DoubleToString(px,_Digits)+" (retracao "+DoubleToString(ret,1)+"%)");
  }
//+------------------------------------------------------------------+
//| Acha a pernada: ultimos dois pontos de reversao alternados        |
//+------------------------------------------------------------------+
bool FindLeg(SLeg &leg)
  {
   leg.ok=false;
   int bars=Bars(_Symbol,_Period);
   if(bars<InpSwingDepth*4+20)
      return(false);
   int count=MathMin(InpLegLookback,bars-1);
   double hi[],lo[];
   datetime tm[];
   ArraySetAsSeries(hi,false);
   ArraySetAsSeries(lo,false);
   ArraySetAsSeries(tm,false);
   if(CopyHigh(_Symbol,_Period,0,count,hi)<count)
      return(false);
   if(CopyLow(_Symbol,_Period,0,count,lo)<count)
      return(false);
   if(CopyTime(_Symbol,_Period,0,count,tm)<count)
      return(false);
   //--- index 0 = barra mais antiga, count-1 = barra atual (em formacao)
   int      lastType=0,prevType=0,lastIdx=-1;
   double   lastPx=0.0,prevPx=0.0;
   datetime lastTm=0,prevTm=0;
   for(int i=InpSwingDepth; i<=count-2-InpSwingDepth; i++)
     {
      bool isHigh=true,isLow=true;
      for(int k=1; k<=InpSwingDepth; k++)
        {
         if(hi[i]<hi[i-k] || hi[i]<hi[i+k])
            isHigh=false;
         if(lo[i]>lo[i-k] || lo[i]>lo[i+k])
            isLow=false;
         if(!isHigh && !isLow)
            break;
        }
      if(!isHigh && !isLow)
         continue;
      if(isHigh && isLow)      // barra que e topo e fundo ao mesmo tempo: trata como topo
         isLow=false;
      int    t=isHigh?1:-1;
      double p=isHigh?hi[i]:lo[i];
      if(lastType==t)
        {
         bool better=(t==1)?(p>=lastPx):(p<=lastPx);   // mesmo tipo seguido: fica o mais extremo
         if(better)
           {
            lastPx=p;
            lastTm=tm[i];
            lastIdx=i;
           }
         continue;
        }
      prevType=lastType;
      prevPx=lastPx;
      prevTm=lastTm;
      lastType=t;
      lastPx=p;
      lastTm=tm[i];
      lastIdx=i;
     }
   if(lastType==0 || prevType==0 || lastIdx<0)
      return(false);
   leg.dir  = (lastType==1)?1:-1;
   leg.base = prevPx;
   leg.tBase= prevTm;
   leg.ext  = lastPx;
   leg.tExt = lastTm;
   //--- estende o extremo se o preco foi mais longe depois do ultimo swing
   for(int i=lastIdx+1; i<count; i++)
     {
      if(leg.dir==1 && hi[i]>leg.ext)
        {
         leg.ext=hi[i];
         leg.tExt=tm[i];
        }
      if(leg.dir==-1 && lo[i]<leg.ext)
        {
         leg.ext=lo[i];
         leg.tExt=tm[i];
        }
     }
   if(leg.dir==1 && leg.ext<=leg.base)
      return(false);
   if(leg.dir==-1 && leg.ext>=leg.base)
      return(false);
   if(MathAbs(leg.ext-leg.base)<InpMinLegPoints*g_pt)
      return(false);
   leg.ok=true;
   return(true);
  }
//+------------------------------------------------------------------+
//| Nivel de Fibo (pct = % de retracao a partir do extremo)           |
//+------------------------------------------------------------------+
double FibLevel(const SLeg &leg,double pct)
  {
   double R=MathAbs(leg.ext-leg.base);
   return(leg.ext-leg.dir*pct/100.0*R);
  }
//+------------------------------------------------------------------+
//| Nivel de stop: InpFibStop% da pernada PARA FORA do extremo        |
//+------------------------------------------------------------------+
double StopPrice(const SLeg &leg)
  {
   double R=MathAbs(leg.ext-leg.base);
   return(leg.ext+leg.dir*InpFibStop/100.0*R);
  }
//+------------------------------------------------------------------+
//| Quanto o preco ja retraiu da pernada, em %                        |
//+------------------------------------------------------------------+
double RetPct(const SLeg &leg,double price)
  {
   double R=MathAbs(leg.ext-leg.base);
   if(R<=0.0)
      return(0.0);
   return(leg.dir*(leg.ext-price)/R*100.0);
  }
//+------------------------------------------------------------------+
//| Ordens do robo neste simbolo: quantidade, lote, medio e flutuante |
//+------------------------------------------------------------------+
void CycleStats(int &cnt,double &lots,double &avg,double &profit)
  {
   cnt=0;
   lots=0.0;
   avg=0.0;
   profit=0.0;
   double wsum=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic)
         continue;
      double v=PositionGetDouble(POSITION_VOLUME);
      cnt++;
      lots+=v;
      wsum+=PositionGetDouble(POSITION_PRICE_OPEN)*v;
      profit+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
     }
   if(lots>0.0)
      avg=wsum/lots;
  }
//+------------------------------------------------------------------+
//| Distancia ate a ordem mais proxima do ciclo (em preco)             |
//+------------------------------------------------------------------+
double MinDistance(double price)
  {
   double best=DBL_MAX;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic)
         continue;
      double d=MathAbs(price-PositionGetDouble(POSITION_PRICE_OPEN));
      if(d<best)
         best=d;
     }
   return(best);
  }
//+------------------------------------------------------------------+
//| Bateu o alvo da cesta?                                            |
//+------------------------------------------------------------------+
bool TakeHit(int cnt,double avg,double profit,double bid,double ask)
  {
   if(cnt<=0)
      return(false);
   if(InpTPMode==TP_MONEY_TOTAL)
      return(profit>=InpTPMoney);
   if(InpTPMode==TP_MONEY_PER_POS)
      return(profit>=InpTPMoney*cnt);
   //--- pontos a partir do preco medio
   if(!g_lock.ok || avg<=0.0)
      return(false);
   if(g_lock.dir==1)
      return(bid<=avg-InpTPPoints*g_pt);   // cesta vendida
   return(ask>=avg+InpTPPoints*g_pt);      // cesta comprada
  }
//+------------------------------------------------------------------+
//| Abre a proxima ordem do grid                                      |
//+------------------------------------------------------------------+
bool OpenOrder(const SLeg &leg,int cnt)
  {
   double lot=NormLot(InpLots*MathPow(InpLotMultiplier,cnt));
   if(lot<=0.0)
     {
      Print(InpBrand,": lote calculado invalido, ordem nao enviada.");
      return(false);
     }
   double sl=0.0;
   if(InpAttachSL)
     {
      double stop=NormalizeDouble(StopPrice(leg),_Digits);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      long   lvl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
      double minDist=(double)lvl*g_pt;
      double ref=(leg.dir==1)?ask:bid;
      if(MathAbs(stop-ref)>minDist)
         sl=stop;
      else
         Print(InpBrand,": stop do Fibo perto demais do preco (stops level), ordem sem SL.");
     }
   string cm="FiboGrid #"+IntegerToString(cnt+1);
   bool ok=false;
   if(leg.dir==1)
      ok=trade.Sell(lot,_Symbol,0.0,sl,0.0,cm);
   else
      ok=trade.Buy(lot,_Symbol,0.0,sl,0.0,cm);
   if(!ok)
      Print(InpBrand,": falha ao enviar ordem (",trade.ResultRetcode(),") ",trade.ResultRetcodeDescription());
   return(ok);
  }
//+------------------------------------------------------------------+
//| Fecha todas as ordens do robo neste simbolo                       |
//+------------------------------------------------------------------+
void CloseAll(string why)
  {
   g_closing=true;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic)
         continue;
      if(!trade.PositionClose(tk))
         Print(InpBrand,": falha ao fechar #",tk," (",trade.ResultRetcode(),") ",trade.ResultRetcodeDescription());
     }
   Print(InpBrand,": ",why," - fechando todas as ordens.");
   Notify(why+" - todas as ordens encerradas.");
  }
//+------------------------------------------------------------------+
//| Assume posicoes que ja estavam abertas (restart / troca de TF)     |
//+------------------------------------------------------------------+
void AdoptPositions(int cnt)
  {
   int dir=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic)
         continue;
      dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)?1:-1;
      break;
     }
   g_active=true;
   SLeg leg;
   leg.ok=false;
   if(FindLeg(leg) && leg.dir==dir)
      g_lock=leg;
   else
     {
      g_lock.ok=false;
      Print(InpBrand,": ",cnt," ordem(ns) aberta(s) sem pernada compativel - o robo so vai administrar o take em dinheiro, sem grid novo nem stop de Fibo.");
     }
  }
//+------------------------------------------------------------------+
//| Bloqueia a pernada (nao reentra ate aparecer outra)               |
//+------------------------------------------------------------------+
void BlockLeg(const SLeg &leg)
  {
   if(!leg.ok)
      return;
   g_blockBase=leg.tBase;
   g_blockDir=leg.dir;
  }
//+------------------------------------------------------------------+
bool IsBlocked(const SLeg &leg)
  {
   if(g_blockDir==0)
      return(false);
   return(leg.dir==g_blockDir && leg.tBase==g_blockBase);
  }
//+------------------------------------------------------------------+
void EndCycle(string why)
  {
   g_active=false;
   g_closing=false;
   g_lock.ok=false;
   g_leg.ok=false;              // forca recalculo da pernada
   Print(InpBrand,": ciclo encerrado (",why,").");
  }
//+------------------------------------------------------------------+
bool TradeAllowed()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return(false);
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return(false);
   ENUM_SYMBOL_TRADE_MODE tm=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tm==SYMBOL_TRADE_MODE_DISABLED || tm==SYMBOL_TRADE_MODE_CLOSEONLY)
      return(false);
   return(true);
  }
//+------------------------------------------------------------------+
//| Filtro de direcao: dir=+1 grid de VENDA / dir=-1 grid de COMPRA   |
//+------------------------------------------------------------------+
bool DirAllowed(int dir)
  {
   if(InpTradeDir==DIR_BUY_ONLY)
      return(dir==-1);
   if(InpTradeDir==DIR_SELL_ONLY)
      return(dir==1);
   return(true);
  }
//+------------------------------------------------------------------+
string DirName()
  {
   if(InpTradeDir==DIR_BUY_ONLY)
      return("SOMENTE COMPRAS");
   if(InpTradeDir==DIR_SELL_ONLY)
      return("SOMENTE VENDAS");
   return("COMPRAS E VENDAS");
  }
//+------------------------------------------------------------------+
double NormLot(double lot)
  {
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0.0)
      st=0.01;
   double v=MathFloor(lot/st+0.5)*st;
   if(v<mn)
      v=mn;
   if(v>mx)
      v=mx;
   int dg=(int)MathMax(0.0,MathCeil(-MathLog10(st)));
   return(NormalizeDouble(v,dg));
  }
//+------------------------------------------------------------------+
//| FIBO no grafico: zona, niveis, pernada e linha de stop            |
//+------------------------------------------------------------------+
void DrawFibo(const SLeg &leg)
  {
   color   clr=(leg.dir==1)?InpSellClr:InpBuyClr;
   string  txt=(leg.dir==1)?"FIBO SELL ZONE 0 - "+DoubleToString(InpFibTo,1)
               :"FIBO BUY ZONE 0 - "+DoubleToString(InpFibTo,1);
   if(!DirAllowed(leg.dir))
      txt=txt+" (DESLIGADA)";
   datetime tStart=leg.tBase;
   datetime tEnd=(datetime)(SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE)+
                            (long)PeriodSeconds()*(InpExtendBars+1));
   if(tEnd<=tStart)
      tEnd=tStart+PeriodSeconds();
   double edge=FibLevel(leg,InpFibTo);
   double top=MathMax(leg.ext,edge);
   double bot=MathMin(leg.ext,edge);
   Zone("OP",top,bot,clr,txt,leg.tExt,tEnd);
   LegLine(leg,clr);
   if(InpShowLevels)
     {
      double pcts[6]={0.0,23.6,38.2,50.0,61.8,100.0};
      for(int i=0; i<6; i++)
        {
         double px=FibLevel(leg,pcts[i]);
         int st=(pcts[i]==0.0 || pcts[i]==100.0)?STYLE_SOLID:STYLE_DOT;
         Level("F"+IntegerToString(i),px,clr,st,tStart,tEnd,DoubleToString(pcts[i],1)+"%");
        }
     }
   Level("STOP",StopPrice(leg),InpStopClr,STYLE_DASH,tStart,tEnd,
         "STOP "+DoubleToString(InpFibStop,1)+"%");
  }
//+------------------------------------------------------------------+
void DeleteFibo()
  {
   ObjectsDeleteAll(0,PFX+"ZONE_");
   ObjectsDeleteAll(0,PFX+"ZTXT_");
   ObjectsDeleteAll(0,PFX+"LV_");
   ObjectsDeleteAll(0,PFX+"LVT_");
   ObjectsDeleteAll(0,PFX+"LEG");
  }
//+------------------------------------------------------------------+
//| Retangulo da zona (opacidade baixa) + texto no meio               |
//+------------------------------------------------------------------+
void Zone(string id,double top,double bot,color clr,string text,datetime tStart,datetime tEnd)
  {
   string r=PFX+"ZONE_"+id;
   if(ObjectFind(0,r)<0)
     {
      ObjectCreate(0,r,OBJ_RECTANGLE,0,tStart,top,tEnd,bot);
      ObjectSetInteger(0,r,OBJPROP_FILL,true);
      ObjectSetInteger(0,r,OBJPROP_BACK,true);
      ObjectSetInteger(0,r,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,r,OBJPROP_HIDDEN,true);
     }
   else
     {
      ObjectMove(0,r,0,tStart,top);
      ObjectMove(0,r,1,tEnd,bot);
     }
   // MT5 nao tem canal alfa em objeto de grafico: a pouca opacidade vem de
   // misturar a cor da zona com o fundo do grafico na proporcao InpOpacity.
   ObjectSetInteger(0,r,OBJPROP_COLOR,Fade(clr,InpOpacity));
   string t=PFX+"ZTXT_"+id;
   datetime tMid=(datetime)(tStart+(tEnd-tStart)/2);
   double pMid=(top+bot)/2.0;
   if(ObjectFind(0,t)<0)
     {
      ObjectCreate(0,t,OBJ_TEXT,0,tMid,pMid);
      ObjectSetInteger(0,t,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(0,t,OBJPROP_BACK,true);
      ObjectSetInteger(0,t,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,t,OBJPROP_HIDDEN,true);
      ObjectSetString(0,t,OBJPROP_FONT,"Arial Black");
     }
   else
      ObjectMove(0,t,0,tMid,pMid);
   ObjectSetString(0,t,OBJPROP_TEXT,text);
   ObjectSetInteger(0,t,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,t,OBJPROP_FONTSIZE,InpZoneFontSize);
  }
//+------------------------------------------------------------------+
//| Linha horizontal de um nivel + etiqueta                           |
//+------------------------------------------------------------------+
void Level(string id,double price,color clr,int style,datetime tStart,datetime tEnd,string tag)
  {
   string n=PFX+"LV_"+id;
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_TREND,0,tStart,price,tEnd,price);
      ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
     }
   else
     {
      ObjectMove(0,n,0,tStart,price);
      ObjectMove(0,n,1,tEnd,price);
     }
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   string t=PFX+"LVT_"+id;
   if(ObjectFind(0,t)<0)
     {
      ObjectCreate(0,t,OBJ_TEXT,0,tEnd,price);
      ObjectSetInteger(0,t,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,t,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,t,OBJPROP_HIDDEN,true);
      ObjectSetString(0,t,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,t,OBJPROP_FONTSIZE,8);
     }
   else
      ObjectMove(0,t,0,tEnd,price);
   ObjectSetString(0,t,OBJPROP_TEXT," "+tag+" "+DoubleToString(price,_Digits));
   ObjectSetInteger(0,t,OBJPROP_COLOR,clr);
  }
//+------------------------------------------------------------------+
//| A pernada em si (origem -> extremo)                               |
//+------------------------------------------------------------------+
void LegLine(const SLeg &leg,color clr)
  {
   string n=PFX+"LEG";
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_TREND,0,leg.tBase,leg.base,leg.tExt,leg.ext);
      ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
     }
   else
     {
      ObjectMove(0,n,0,leg.tBase,leg.base);
      ObjectMove(0,n,1,leg.tExt,leg.ext);
     }
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
  }
//+------------------------------------------------------------------+
//| Painel de status (canto superior esquerdo)                        |
//+------------------------------------------------------------------+
void Panel(const SLeg &leg,int cnt,double lots,double avg,double profit)
  {
   color base=(leg.ok && leg.dir==-1)?InpBuyClr:InpSellClr;
   PanelLine(0,InpBrand+"  "+_Symbol+"   ["+DirName()+"]",clrSilver);
   if(!leg.ok)
     {
      PanelLine(1,"Pernada: procurando (min "+IntegerToString(InpMinLegPoints)+" pts)",clrSilver);
      PanelLine(2,"",clrSilver);
      PanelLine(3,"",clrSilver);
      PanelLine(4,"",clrSilver);
      PanelLine(5,"",clrSilver);
      return;
     }
   double px=(leg.dir==1)?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   string side=(leg.dir==1)?"ALTA -> grid de VENDA":"QUEDA -> grid de COMPRA";
   string flag=IsBlocked(leg)?"  [BLOQUEADA]":"";
   if(!DirAllowed(leg.dir))
      flag=flag+"  [DESLIGADA: "+DirName()+"]";
   PanelLine(1,"Pernada: "+side+flag,base);
   PanelLine(2,"0%: "+DoubleToString(leg.ext,_Digits)+"   "+DoubleToString(InpFibTo,1)+"%: "+
             DoubleToString(FibLevel(leg,InpFibTo),_Digits)+"   100%: "+DoubleToString(leg.base,_Digits),base);
   PanelLine(3,"Retracao agora: "+DoubleToString(RetPct(leg,px),1)+"%   STOP: "+
             DoubleToString(StopPrice(leg),_Digits),InpStopClr);
   PanelLine(4,"Ordens: "+IntegerToString(cnt)+"/"+IntegerToString(InpMaxPositions)+
             "   Lotes: "+DoubleToString(lots,2)+"   Medio: "+(cnt>0?DoubleToString(avg,_Digits):"-"),clrSilver);
   string alvo=(InpTPMode==TP_POINTS_AVG)?(IntegerToString(InpTPPoints)+" pts do medio")
               :((InpTPMode==TP_MONEY_PER_POS)?("US$ "+DoubleToString(InpTPMoney*MathMax(cnt,1),2))
                 :("US$ "+DoubleToString(InpTPMoney,2)));
   PanelLine(5,"Flutuante: US$ "+DoubleToString(profit,2)+"   Alvo: "+alvo,
             (profit>=0.0)?clrLime:clrRed);
  }
//+------------------------------------------------------------------+
void PanelLine(int idx,string text,color clr)
  {
   string n=PFX+"PNL"+IntegerToString(idx);
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,12);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,18+idx*(InpPanelFontSize+7));
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetString(0,n,OBJPROP_FONT,"Consolas");
     }
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,InpPanelFontSize);
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
  }
//+------------------------------------------------------------------+
//| SuperTrend/ATR - so para dar a cor da tendencia ao preco grande    |
//+------------------------------------------------------------------+
int TrendDir()
  {
   int bars=Bars(_Symbol,_Period);
   if(bars<InpAtrPeriod+3)
      return(0);
   if(BarsCalculated(g_hAtr)<InpAtrPeriod+3)
      return(0);
   int count=MathMin(InpTrendBars,bars-1);
   if(count<InpAtrPeriod+3)
      return(0);
   double atr[],hi[],lo[],cl[];
   ArraySetAsSeries(atr,false);
   ArraySetAsSeries(hi,false);
   ArraySetAsSeries(lo,false);
   ArraySetAsSeries(cl,false);
   if(CopyBuffer(g_hAtr,0,0,count,atr)<count)
      return(0);
   if(CopyHigh(_Symbol,_Period,0,count,hi)<count)
      return(0);
   if(CopyLow(_Symbol,_Period,0,count,lo)<count)
      return(0);
   if(CopyClose(_Symbol,_Period,0,count,cl)<count)
      return(0);
   double upPrev=0.0,dnPrev=0.0,dir=0.0;
   for(int i=0; i<count; i++)
     {
      double hl2=(hi[i]+lo[i])/2.0;
      double up=hl2+InpAtrMult*atr[i];
      double dn=hl2-InpAtrMult*atr[i];
      if(i==0 || dir==0.0)
        {
         upPrev=up;
         dnPrev=dn;
         dir=(cl[i]>=hl2)?1.0:-1.0;
         continue;
        }
      double upNew=(up<upPrev || cl[i-1]>upPrev)?up:upPrev;
      double dnNew=(dn>dnPrev || cl[i-1]<dnPrev)?dn:dnPrev;
      if(dir==1.0 && cl[i]<dnNew)
         dir=-1.0;
      else
         if(dir==-1.0 && cl[i]>upNew)
            dir=1.0;
      upPrev=upNew;
      dnPrev=dnNew;
     }
   return((int)dir);
  }
//+------------------------------------------------------------------+
//| Preco grande no canto superior direito (igual ao TOP/BOTTOM)       |
//+------------------------------------------------------------------+
void BigPrice(int dir,double px)
  {
   color clr=InpBigPriceClr;
   if(InpBigPriceByTrend && dir!=0)
      clr=(dir==1)?clrLime:clrRed;
   string n=PFX+"BIGPX";
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,14);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,12);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetString(0,n,OBJPROP_FONT,"Arial Black");
     }
   ObjectSetString(0,n,OBJPROP_TEXT,DoubleToString(px,_Digits));
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,InpBigPriceSize);
  }
//+------------------------------------------------------------------+
void Notify(string msg)
  {
   string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
   string full=InpBrand+" "+_Symbol+" "+tf+": "+msg;
   if(InpAlertPush)
      SendNotification(full);
   if(InpAlertPopup)
      Alert(full);
  }
//+------------------------------------------------------------------+
//| Mistura a cor com o fundo do grafico (simula baixa opacidade)     |
//+------------------------------------------------------------------+
color Fade(color clr,int pct)
  {
   int p=pct;
   if(p<0)
      p=0;
   if(p>100)
      p=100;
   int c=(int)clr;
   int bg=(int)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   int r=((c&0xFF)*p+(bg&0xFF)*(100-p))/100;
   int g=(((c>>8)&0xFF)*p+((bg>>8)&0xFF)*(100-p))/100;
   int b=(((c>>16)&0xFF)*p+((bg>>16)&0xFF)*(100-p))/100;
   return((color)((b<<16)|(g<<8)|r));
  }
//+------------------------------------------------------------------+
