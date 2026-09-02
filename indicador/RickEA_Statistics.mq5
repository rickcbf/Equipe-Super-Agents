//+------------------------------------------------------------------+
//|                                          RickEA_Statistics.mq5     |
//|   RickEA Statistics — painel de ESTATISTICA e PROBABILIDADE        |
//|   Le um RANGE de N velas fechadas (ajustavel) e mostra, TUDO       |
//|   calculado DENTRO desse range:                                    |
//|     - Cor predominante (painel VERDE em alta / VERMELHO em baixa)  |
//|     - Campos BUY e SELL (o que PREDOMINA fica EM CIMA) com a       |
//|       quantidade de velas e o percentual ao lado                   |
//|     - Barra horizontal de probabilidade (verde/vermelho por %)     |
//|     - Preco do ativo GRANDE no canto superior direito, acima       |
//|     - Tamanho do range (em pips) e media de pips por vela          |
//|     - Pips da ultima vela encerrada                                |
//|     - Soma de pips BUY (verde) e SELL (vermelho)                   |
//|     - Maior sequencia seguida de velas BUY e SELL no range         |
//|                                                                    |
//|   Versao gemea do RickEA_Statistics.cs (cTrader).                  |
//|   Autor: RichardTrader                                             |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RickEA Statistics"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- inputs
input int    InpRangeCandles = 20;                  // Range (qtd. de velas)
input string InpBrand        = "RICKEA STATISTICS"; // Titulo do painel
input bool   InpShowBigPrice = true;                // Mostrar preco grande
input int    InpBigPriceSize = 28;                  // Tamanho da fonte do preco
input int    InpMarginX      = 14;                  // Margem da direita (px)
input int    InpMarginY      = 14;                  // Margem do topo (px)

//--- paleta
#define CLR_GREEN   ((color)C'22,199,132')   // #16C784
#define CLR_RED     ((color)C'234,57,67')    // #EA3943
#define CLR_GREENBG ((color)C'10,46,32')
#define CLR_REDBG   ((color)C'48,14,16')
#define CLR_NEUTBG  ((color)C'18,22,30')
#define CLR_BORDER  ((color)C'60,70,85')
#define CLR_DIM     ((color)C'176,190,197')
#define CLR_WHITE   ((color)C'240,244,248')

//--- geometria do painel
#define PFX   "RST_"
#define PANEL_W  272
#define PAD      12
#define FONT     "Arial"
#define FONTB    "Arial Bold"

//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"RickEA Statistics");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PFX);
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);

   if(rates_total < 4)
      return(rates_total);

   //--- range = ultimas N velas FECHADAS (exclui a vela em formacao = indice 0) ---
   int sample = InpRangeCandles;
   if(sample > rates_total-1) sample = rates_total-1;   // 1..sample sao fechadas
   if(sample < 1) sample = 1;

   int    buyCount=0, sellCount=0;
   double buyPips=0.0, sellPips=0.0, sumAmpl=0.0;
   double maxHigh=-DBL_MAX, minLow=DBL_MAX;
   int    curBuy=0, curSell=0, maxBuy=0, maxSell=0;

   for(int i=1; i<=sample; i++)
     {
      double o=open[i], c=close[i], h=high[i], l=low[i];
      if(h>maxHigh) maxHigh=h;
      if(l<minLow)  minLow=l;
      sumAmpl += (h-l);

      if(c>o)        // vela BUY
        {
         buyCount++; buyPips += (c-o);
         curBuy++; curSell=0; if(curBuy>maxBuy) maxBuy=curBuy;
        }
      else if(c<o)   // vela SELL
        {
         sellCount++; sellPips += (o-c);
         curSell++; curBuy=0; if(curSell>maxSell) maxSell=curSell;
        }
      else           // doji / neutra
        {
         curBuy=0; curSell=0;
        }
     }

   //--- pip do simbolo (5/3 digitos -> pip = 10 pontos) ---
   double pip = _Point;
   if(_Digits==3 || _Digits==5) pip = 10.0*_Point;
   if(pip<=0.0) pip=_Point>0.0?_Point:1.0;

   double rangePips = (maxHigh-minLow)/pip;
   double avgPips   = (sumAmpl/sample)/pip;
   double buyPipsN  = buyPips/pip;
   double sellPipsN = sellPips/pip;

   //--- ultima vela encerrada (indice 1) ---
   double lastPips = (high[1]-low[1])/pip;
   int    lastDir  = (close[1]>open[1]) ? 1 : ((close[1]<open[1]) ? -1 : 0);

   //--- percentuais (base = BUY+SELL) ---
   int    decisive = buyCount+sellCount;
   double buyPct   = decisive>0 ? 100.0*buyCount/decisive : 50.0;
   double sellPct  = decisive>0 ? 100.0*sellCount/decisive : 50.0;
   bool   buyDom   = (buyCount>=sellCount);

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid<=0.0) bid=close[0];

   DrawPanel(buyDom,buyCount,sellCount,buyPct,sellPct,
             rangePips,avgPips,lastPips,lastDir,
             buyPipsN,sellPipsN,maxBuy,maxSell,sample,bid);

   ChartRedraw(0);
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Desenho / atualizacao do painel                                   |
//+------------------------------------------------------------------+
void DrawPanel(bool buyDom,int buyCount,int sellCount,double buyPct,double sellPct,
               double rangePips,double avgPips,double lastPips,int lastDir,
               double buyPipsN,double sellPipsN,int maxBuy,int maxSell,int sample,double bid)
  {
   int chartW = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int panelLeft = chartW - InpMarginX - PANEL_W;
   if(panelLeft < 0) panelLeft = 0;

   int cLeft  = panelLeft + PAD;
   int cRight = panelLeft + PANEL_W - PAD;
   int cW     = PANEL_W - 2*PAD;

   //--- preco grande (acima do painel, a direita) ---
   int y = InpMarginY;
   if(InpShowBigPrice)
     {
      Label(PFX+"bigprice",cRight,y,DoubleToString(bid,_Digits),
            CLR_WHITE,InpBigPriceSize,FONTB,ANCHOR_RIGHT_UPPER);
      y += InpBigPriceSize + 12;
     }
   else ObjectDelete(0,PFX+"bigprice");

   int panelTop = y;
   int panelH   = 258;

   //--- fundo do painel (cor pela predominancia) ---
   color bg     = buyDom ? CLR_GREENBG : CLR_REDBG;
   color border = buyDom ? CLR_GREEN   : CLR_RED;
   Rect(PFX+"bg",panelLeft,panelTop,PANEL_W,panelH,bg,border,2);

   int ry = panelTop + PAD;

   //--- cabecalho: titulo (esq) + direcao (dir) ---
   Label(PFX+"title",cLeft,ry,InpBrand,CLR_WHITE,11,FONTB,ANCHOR_LEFT_UPPER);
   Label(PFX+"dir",cRight,ry,buyDom?"▲ ALTA":"▼ BAIXA",border,11,FONTB,ANCHOR_RIGHT_UPPER);
   ry += 24;

   //--- linhas BUY/SELL (a predominante em cima) ---
   if(buyDom)
     {
      DirRow("top", cLeft,cRight,ry,   "BUY", buyCount, buyPct, CLR_GREEN);
      DirRow("bot", cLeft,cRight,ry+24,"SELL",sellCount,sellPct,CLR_RED);
     }
   else
     {
      DirRow("top", cLeft,cRight,ry,   "SELL",sellCount,sellPct,CLR_RED);
      DirRow("bot", cLeft,cRight,ry+24,"BUY", buyCount, buyPct, CLR_GREEN);
     }
   ry += 52;

   //--- barra de probabilidade (largura do painel) ---
   int barH = 24;
   int buyW = (int)MathRound(cW * buyPct/100.0);
   if(buyW<0) buyW=0; if(buyW>cW) buyW=cW;
   int sellW = cW - buyW;

   Rect(PFX+"barbuy", cLeft,      ry, buyW  >0?buyW :1, barH, CLR_GREEN, CLR_GREEN, 0);
   Rect(PFX+"barsell",cLeft+buyW, ry, sellW >0?sellW:1, barH, CLR_RED,   CLR_RED,   0);
   if(buyPct>=12.0)
      Label(PFX+"barbuytxt", cLeft+buyW/2,        ry+barH/2, DoubleToString(buyPct,0)+"%", clrWhite,10,FONTB,ANCHOR_CENTER);
   else ObjectDelete(0,PFX+"barbuytxt");
   if(sellPct>=12.0)
      Label(PFX+"barselltxt",cLeft+buyW+sellW/2,  ry+barH/2, DoubleToString(sellPct,0)+"%",clrWhite,10,FONTB,ANCHOR_CENTER);
   else ObjectDelete(0,PFX+"barselltxt");
   ry += barH + 12;

   //--- grade de estatisticas ---
   string lastStr = (lastDir>=0?"+":"-") + DoubleToString(lastPips,1);
   color  lastClr = lastDir>0 ? CLR_GREEN : (lastDir<0 ? CLR_RED : CLR_DIM);

   ry = StatRow("r1",cLeft,cRight,ry,"Range (pips)",       DoubleToString(rangePips,1),  CLR_WHITE);
   ry = StatRow("r2",cLeft,cRight,ry,"Media pips/vela",    DoubleToString(avgPips,1),    CLR_WHITE);
   ry = StatRow("r3",cLeft,cRight,ry,"Ultima vela (pips)", lastStr,                      lastClr);
   ry = StatRow("r4",cLeft,cRight,ry,"Pips BUY",           "+"+DoubleToString(buyPipsN,1), CLR_GREEN);
   ry = StatRow("r5",cLeft,cRight,ry,"Pips SELL",          "-"+DoubleToString(sellPipsN,1),CLR_RED);
   ry = StatRow("r6",cLeft,cRight,ry,"Maior seq. BUY",     IntegerToString(maxBuy),      CLR_GREEN);
   ry = StatRow("r7",cLeft,cRight,ry,"Maior seq. SELL",    IntegerToString(maxSell),     CLR_RED);
   ry = StatRow("r8",cLeft,cRight,ry,"Velas no range",     IntegerToString(sample),      CLR_WHITE);
  }

//--- linha BUY/SELL: [ palavra ]      [ N velas ]        [ % ] --------
void DirRow(string id,int cLeft,int cRight,int y,string word,int candles,double pct,color clr)
  {
   Label(PFX+"d_"+id+"_w",cLeft, y, word, clr,14,FONTB,ANCHOR_LEFT_UPPER);
   string cnt = IntegerToString(candles) + (candles==1?" vela":" velas");
   Label(PFX+"d_"+id+"_c",(cLeft+cRight)/2, y, cnt, clr,12,FONTB,ANCHOR_UPPER);
   Label(PFX+"d_"+id+"_p",cRight, y, DoubleToString(pct,0)+"%", clr,14,FONTB,ANCHOR_RIGHT_UPPER);
  }

//--- linha de estatistica: [ rotulo .......... valor ] ---------------
int StatRow(string id,int cLeft,int cRight,int y,string caption,string value,color valueClr)
  {
   Label(PFX+"s_"+id+"_k",cLeft, y, caption, CLR_DIM,  9,FONT, ANCHOR_LEFT_UPPER);
   Label(PFX+"s_"+id+"_v",cRight,y, value,   valueClr, 9,FONTB,ANCHOR_RIGHT_UPPER);
   return(y+16);
  }

//+------------------------------------------------------------------+
//| Helpers de objetos                                                |
//+------------------------------------------------------------------+
void Rect(string name,int x,int y,int w,int h,color bg,color border,int borderW)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,borderW);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
  }

void Label(string name,int x,int y,string text,color clr,int fs,string font,ENUM_ANCHOR_POINT anchor)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fs);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,10);
  }
//+------------------------------------------------------------------+
