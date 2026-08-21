//+------------------------------------------------------------------+
//|                                                       XTrend.mq5  |
//|                 X-TREND - SuperTrend / ATR + painel visual        |
//|  Pinta candles pela tendencia, linha SuperTrend, EMA tracejada,   |
//|  e (quando InpShowVisuals=true) desenha ENTRADA/TP1/TP2/TP3/SL,   |
//|  painel inferior-esquerdo e o preco grande no canto sup. direito. |
//|  Buffer 5=Trend, 7=EMA, 8=Dir (lidos pelo EA via iCustom).        |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RickEA X-TREND"
#property version   "1.20"
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots   3

#property indicator_label1  "XTrend"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrLime,clrRed
#property indicator_width1  1

#property indicator_label2  "Trend"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLime,clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "EMA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

//--- PRIMEIROS 3 inputs: iguais aos que o EA passa no iCustom (NAO reordenar)
input int    InpAtrPeriod   = 10;     // ATR Period (SuperTrend)
input double InpAtrMult     = 3.0;    // ATR Multiplier (robusto walk-forward)
input int    InpEmaPeriod   = 50;     // EMA Period (tracejada)
//--- 4o input: o EA passa 'false' aqui -> indicador nao desenha por baixo do EA
input bool   InpShowVisuals = true;   // Desenhar painel/entradas/preco grande
//--- visual / niveis
input string InpAuthor      = "RichardTrader";      // Propriedade
input string InpBrand       = "RICKEA X-TREND";     // Titulo do painel
input double InpPontoEmDolar= 1.0;    // Valor de 1 "ponto" no preco ($)
input double InpTP1_pts     = 16;     // TP1 (pontos)
input double InpTP2_pts     = 60;     // TP2 (pontos)
input double InpTP3_pts     = 120;    // TP3 (pontos)
input double InpSL_pts      = 20;     // Stop inicial (pontos)
input double InpTrailStep_pts = 100;  // Passo do trailing (display do SL)
input double InpTagHeight   = 4.0;    // Altura das etiquetas (no preco)
input int    InpTagWidthBars= 18;     // Largura das etiquetas (barras)
input bool   InpBigPrice    = true;   // Preco grande no canto sup. direito
input int    InpBigPriceSize= 26;     // Tamanho da fonte do preco grande
input bool   InpBigPriceByTrend = true;  // Preco muda de cor pela tendencia (verde alta/vermelho baixa)
input color  InpBigPriceClr = clrYellow; // Cor fixa (se ByTrend=false)
//--- alertas (opcionais) - disparam na virada da tendencia (fecho da vela)
input bool   InpAlertPush   = false;  // Enviar PUSH pro celular (MetaQuotes ID)
input bool   InpAlertPopup  = false;  // Alerta popup + som no terminal
input bool   InpAlertEmail  = false;  // Enviar e-mail

//--- buffers
double BufOpen[],BufHigh[],BufLow[],BufClose[],BufCColor[];
double BufTrend[],BufTColor[],BufEma[],BufDir[],BufUpper[],BufLower[];

int hAtr=INVALID_HANDLE, hEma=INVALID_HANDLE;
string PFX="XT_";
datetime g_lastAlertBar=0;   // ultima barra que ja gerou alerta (evita repetir)
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,BufOpen,INDICATOR_DATA);
   SetIndexBuffer(1,BufHigh,INDICATOR_DATA);
   SetIndexBuffer(2,BufLow,INDICATOR_DATA);
   SetIndexBuffer(3,BufClose,INDICATOR_DATA);
   SetIndexBuffer(4,BufCColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5,BufTrend,INDICATOR_DATA);
   SetIndexBuffer(6,BufTColor,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7,BufEma,INDICATOR_DATA);
   SetIndexBuffer(8,BufDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,BufUpper,INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,BufLower,INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufOpen,false);   ArraySetAsSeries(BufHigh,false);
   ArraySetAsSeries(BufLow,false);    ArraySetAsSeries(BufClose,false);
   ArraySetAsSeries(BufCColor,false); ArraySetAsSeries(BufTrend,false);
   ArraySetAsSeries(BufTColor,false); ArraySetAsSeries(BufEma,false);
   ArraySetAsSeries(BufDir,false);    ArraySetAsSeries(BufUpper,false);
   ArraySetAsSeries(BufLower,false);

   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   IndicatorSetString(INDICATOR_SHORTNAME,"X-TREND");

   hAtr=iATR(_Symbol,_Period,InpAtrPeriod);
   hEma=iMA(_Symbol,_Period,InpEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(hAtr==INVALID_HANDLE || hEma==INVALID_HANDLE) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PFX);
  }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
  {
   if(rates_total < InpAtrPeriod+2) return(0);
   if(BarsCalculated(hAtr)<rates_total || BarsCalculated(hEma)<rates_total)
      return(prev_calculated);

   double atr[];
   ArraySetAsSeries(atr,false);
   if(CopyBuffer(hAtr,0,0,rates_total,atr)<rates_total) return(prev_calculated);
   if(CopyBuffer(hEma,0,0,rates_total,BufEma)<rates_total) return(prev_calculated);

   int start=(prev_calculated>1)?prev_calculated-1:InpAtrPeriod+1;
   for(int i=start;i<rates_total;i++)
     {
      double hl2=(high[i]+low[i])/2.0;
      double up=hl2+InpAtrMult*atr[i];
      double dn=hl2-InpAtrMult*atr[i];
      if(i==0 || BufDir[i-1]==0)
        {
         BufUpper[i]=up; BufLower[i]=dn;
         BufDir[i]=(close[i]>=hl2)?1:-1;
        }
      else
        {
         BufUpper[i]=(up<BufUpper[i-1] || close[i-1]>BufUpper[i-1])?up:BufUpper[i-1];
         BufLower[i]=(dn>BufLower[i-1] || close[i-1]<BufLower[i-1])?dn:BufLower[i-1];
         double dir=BufDir[i-1];
         if(dir==1  && close[i]<BufLower[i]) dir=-1;
         if(dir==-1 && close[i]>BufUpper[i]) dir=1;
         BufDir[i]=dir;
        }
      BufTrend[i]=(BufDir[i]==1)?BufLower[i]:BufUpper[i];
      BufTColor[i]=(BufDir[i]==1)?0:1;
      BufOpen[i]=open[i]; BufHigh[i]=high[i]; BufLow[i]=low[i]; BufClose[i]=close[i];
      BufCColor[i]=(BufDir[i]==1)?0:1;
     }

   if(InpShowVisuals)
     {
      DrawTrade(rates_total,time,close);
      if(InpBigPrice) DrawBigPrice((int)BufDir[rates_total-1]);
     }

   CheckAlert(rates_total,prev_calculated,time,close);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Alerta na virada confirmada (fecho da vela) - sem repaint         |
//+------------------------------------------------------------------+
void CheckAlert(const int rt,const int prev,const datetime &time[],const double &close[])
  {
   if(rt<InpAtrPeriod+4) return;
   int c1=rt-2;   // ultima vela FECHADA
   int c0=rt-3;   // anterior

   // na primeira carga (historico) so marca a barra atual como "ja vista"
   if(prev==0){ g_lastAlertBar=time[c1]; return; }

   if(!InpAlertPush && !InpAlertPopup && !InpAlertEmail) return;

   if(BufDir[c1]!=BufDir[c0] && time[c1]!=g_lastAlertBar)
     {
      g_lastAlertBar=time[c1];
      int dir=(int)BufDir[c1];
      string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
      string what=(dir==1)?"BUY (ALTA)":"SELL (BAIXA)";
      string msg=InpBrand+" "+_Symbol+" "+tf+": sinal "+what+" @ "+DoubleToString(close[c1],_Digits);
      if(InpAlertPush)  SendNotification(msg);
      if(InpAlertPopup) Alert(msg);
      if(InpAlertEmail) SendMail(InpBrand+" - sinal "+_Symbol,msg);
     }
  }
//+==================================================================+
//|  Desenho da operacao (entrada/TPs/SL + painel)                    |
//+==================================================================+
void DrawTrade(const int rt,const datetime &time[],const double &close[])
  {
   int curDir=(int)BufDir[rt-1];
   if(curDir==0) return;
   int sig=rt-1;
   while(sig>1 && BufDir[sig-1]==curDir) sig--;

   double P=InpPontoEmDolar;
   double entry=close[sig];
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0) px=close[rt-1];

   double tp1=entry+curDir*InpTP1_pts*P;
   double tp2=entry+curDir*InpTP2_pts*P;
   double tp3=entry+curDir*InpTP3_pts*P;

   // SL com trailing (display): inicial oposto; ao passar TP1 -> BE + passos
   double sl=entry-curDir*InpSL_pts*P;
   double favor=curDir*(px-entry);
   double step=InpTrailStep_pts*P;
   if(favor>=InpTP1_pts*P && step>0)
     {
      int steps=(int)MathFloor((favor-InpTP1_pts*P)/step);
      sl=entry+curDir*steps*step;   // steps=0 => BE (entrada)
     }

   datetime tlast=time[rt-1];
   datetime tStart=time[sig];                                   // barra da virada do ATR
   datetime tEnd=tlast+PeriodSeconds()*(1+InpTagWidthBars);     // ate as etiquetas
   string   word=(curDir==1)?"BUY":"SELL";

   // segmentos (so da virada ate a direita, nao atravessam o grafico)
   LevelLine("ENTRY",entry,clrDodgerBlue,STYLE_DASH,1, tStart,tEnd);
   LevelLine("SL",   sl,   clrRed,       STYLE_DASH,2, tStart,tEnd);
   LevelLine("TP1",  tp1,  clrYellow,    STYLE_SOLID,2, tStart,tEnd);
   LevelLine("TP2",  tp2,  clrYellow,    STYLE_SOLID,2, tStart,tEnd);
   LevelLine("TP3",  tp3,  clrGold,      STYLE_SOLID,1, tStart,tEnd);

   // etiquetas destacadas (caixa preenchida) a direita
   Tag("ENTRY",entry,clrDodgerBlue,clrWhite,tlast," "+word+" @ "+DoubleToString(entry,_Digits));
   Tag("SL",   sl,   clrRed,       clrWhite,tlast," SL @ "+DoubleToString(sl,_Digits));
   Tag("TP1",  tp1,  clrYellow,    clrBlack,tlast," TP1 @ "+DoubleToString(tp1,_Digits));
   Tag("TP2",  tp2,  clrYellow,    clrBlack,tlast," TP2 @ "+DoubleToString(tp2,_Digits));
   Tag("TP3",  tp3,  clrGold,      clrBlack,tlast," TP3 @ "+DoubleToString(tp3,_Digits));

   // painel
   int mins=(int)((TimeCurrent()-time[sig])/60);
   double pnl=favor/P;
   DrawPanel(curDir,entry,tp1,tp2,tp3,sl,word,mins,pnl);
  }
//+------------------------------------------------------------------+
void LevelLine(string id,double price,color clr,ENUM_LINE_STYLE style,int width,
               datetime tStart,datetime tEnd)
  {
   string n=PFX+"L_"+id;
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_TREND,0,tStart,price,tEnd,price);
      ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
     }
   else
     {
      ObjectMove(0,n,0,tStart,price);
      ObjectMove(0,n,1,tEnd,price);
     }
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
  }
//+------------------------------------------------------------------+
void Tag(string id,double price,color bg,color fg,datetime tlast,string text)
  {
   datetime tA=tlast+PeriodSeconds();
   datetime tB=tlast+PeriodSeconds()*(1+InpTagWidthBars);
   double   h =InpTagHeight/2.0;

   string r=PFX+"BOX_"+id;
   if(ObjectFind(0,r)<0)
     {
      ObjectCreate(0,r,OBJ_RECTANGLE,0,tA,price+h,tB,price-h);
      ObjectSetInteger(0,r,OBJPROP_FILL,true);
      ObjectSetInteger(0,r,OBJPROP_BACK,false);
      ObjectSetInteger(0,r,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,r,OBJPROP_HIDDEN,true);
     }
   else { ObjectMove(0,r,0,tA,price+h); ObjectMove(0,r,1,tB,price-h); }
   ObjectSetInteger(0,r,OBJPROP_COLOR,bg);

   string t=PFX+"TXT_"+id;
   if(ObjectFind(0,t)<0)
     {
      ObjectCreate(0,t,OBJ_TEXT,0,tA,price);
      ObjectSetInteger(0,t,OBJPROP_ANCHOR,ANCHOR_LEFT);   // texto cresce p/ direita
      ObjectSetInteger(0,t,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,t,OBJPROP_HIDDEN,true);
      ObjectSetString(0,t,OBJPROP_FONT,"Arial Bold");
     }
   else ObjectMove(0,t,0,tA,price);
   ObjectSetString(0,t,OBJPROP_TEXT,text);
   ObjectSetInteger(0,t,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,t,OBJPROP_FONTSIZE,9);
  }
//+------------------------------------------------------------------+
void DrawBigPrice(int dir)
  {
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0) return;
   color  clr=InpBigPriceByTrend ? (dir==1?clrLime:clrRed) : InpBigPriceClr;
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
void DrawPanel(int dir,double entry,double tp1,double tp2,double tp3,
               double sl,string word,int mins,double pnl)
  {
   // cores pela tendencia do ATR (igual as velas)
   color accent = (dir==1) ? clrLime      : clrRed;          // borda / faixa viva
   color fill   = (dir==1) ? C'0,45,0'    : C'60,0,0';       // fundo (tom escuro p/ ler)
   color head   = (dir==1) ? C'0,85,0'    : C'110,0,0';      // faixa do titulo

   // fundo
   string bg=PFX+"PANEL_BG";
   if(ObjectFind(0,bg)<0)
     {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,8);
      ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,192);
      ObjectSetInteger(0,bg,OBJPROP_XSIZE,300);
      ObjectSetInteger(0,bg,OBJPROP_YSIZE,184);
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,bg,OBJPROP_BACK,false);
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
     }
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,fill);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,accent);
   // faixa do titulo
   string hb=PFX+"PANEL_HEAD";
   if(ObjectFind(0,hb)<0)
     {
      ObjectCreate(0,hb,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,hb,OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,hb,OBJPROP_XDISTANCE,8);
      ObjectSetInteger(0,hb,OBJPROP_YDISTANCE,192);
      ObjectSetInteger(0,hb,OBJPROP_XSIZE,300);
      ObjectSetInteger(0,hb,OBJPROP_YSIZE,26);
      ObjectSetInteger(0,hb,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,hb,OBJPROP_BACK,false);
      ObjectSetInteger(0,hb,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,hb,OBJPROP_HIDDEN,true);
     }
   ObjectSetInteger(0,hb,OBJPROP_BGCOLOR,head);
   ObjectSetInteger(0,hb,OBJPROP_COLOR,accent);

   PLine("H", InpBrand,                                              clrWhite, 11, 16, 184, true);
   PLine("0", "Trend signal: "+word+" @ "+DoubleToString(entry,_Digits), clrWhite, 10, 18, 142, true);
   PLine("1", "Last "+word+" signal came "+(string)mins+" minutes ago", clrWhite, 8, 18, 124, false);
   PLine("2", "     Target 1: "+DoubleToString(tp1,_Digits),          clrWhite, 9, 18, 100, false);
   PLine("3", "     Target 2: "+DoubleToString(tp2,_Digits),          clrWhite, 9, 18, 84,  false);
   PLine("4", "     Target 3: "+DoubleToString(tp3,_Digits),          clrWhite, 9, 18, 68,  false);
   PLine("5", "Stop loss: "+DoubleToString(sl,_Digits),               clrWhite, 9, 18, 42,  false);
   PLine("6", "Current P&L: "+DoubleToString(pnl,2)+" points",        clrWhite, 10, 18, 22, true);
  }
//+------------------------------------------------------------------+
void PLine(string id,string text,color clr,int fs,int x,int y,bool bold)
  {
   string n=PFX+"PL_"+id;
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
     }
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
  }
//+------------------------------------------------------------------+
