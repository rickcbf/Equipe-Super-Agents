//+------------------------------------------------------------------+
//|                                        RickEA_TopBottom.mq5      |
//|   RickEA TOP/BOTTOM - maximas e minimas dos 2 dias anteriores    |
//|   Marca H do dia-1 e do dia-2 (SELL ZONE, vermelha) e L do       |
//|   dia-1 e do dia-2 (BUY ZONE, verde), com retangulo de baixa     |
//|   opacidade do inicio do dia-2 ate a vela atual, texto no meio,  |
//|   preco grande na cor da tendencia (igual ao RickEA X-TREND) e   |
//|   alerta no topo/centro do grafico quando o preco entra na zona. |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RickEA TOP/BOTTOM"
#property version   "1.01"
#property description "Zonas entre as 2 maximas e as 2 minimas dos dias anteriores"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   0

//--- zonas
input string InpBrand        = "RICKEA TOP/BOTTOM"; // Titulo / marca
input color  InpSellClr      = clrRed;      // Cor da SELL ZONE (entre as 2 maximas)
input color  InpBuyClr       = clrLime;     // Cor da BUY ZONE (entre as 2 minimas)
input int    InpOpacity      = 18;          // Opacidade do preenchimento (0-100)
input int    InpExtendBars   = 0;           // Prolongar N barras alem da vela atual
input bool   InpShowLevels   = true;        // Desenhar as linhas das maximas/minimas
input bool   InpShowLevelTag = true;        // Etiqueta com o preco de cada nivel
input int    InpZoneFontSize = 14;          // Tamanho do texto SELL ZONE / BUY ZONE
//--- alerta no topo do grafico
input bool   InpShowAlertTop = true;        // Frase de alerta no topo/centro
input int    InpAlertFontSize= 18;          // Tamanho da frase de alerta
input int    InpAlertYOffset = 24;          // Distancia do topo (pixels)
//--- preco grande (igual ao RickEA X-TREND)
input bool   InpBigPrice     = true;        // Preco grande no canto sup. direito
input int    InpBigPriceSize = 26;          // Tamanho da fonte do preco grande
input bool   InpBigPriceByTrend = true;     // Cor pela tendencia (verde alta/vermelho baixa)
input color  InpBigPriceClr  = clrYellow;   // Cor fixa (se ByTrend=false)
input int    InpAtrPeriod    = 10;          // ATR Period (tendencia do preco grande)
input double InpAtrMult      = 3.0;         // ATR Multiplier (tendencia do preco grande)
//--- alertas (disparam ao ENTRAR numa zona)
input bool   InpAlertPush    = false;       // Enviar PUSH pro celular (MetaQuotes ID)
input bool   InpAlertPopup   = false;       // Alerta popup + som no terminal
input bool   InpAlertEmail   = false;       // Enviar e-mail

//--- buffers de calculo (SuperTrend so para a cor do preco grande)
double BufDir[];
double BufUpper[];
double BufLower[];

int    hAtr = INVALID_HANDLE;
string PFX  = "TB_";
int    g_lastZone = 0;   // 0=fora, 1=BUY ZONE, -1=SELL ZONE

//--- prototipos
void  CalcTrend(const int rt,const int prev,const double &hi[],const double &lo[],const double &cl[]);
void  Zone(string id,double top,double bot,color clr,string text,datetime tStart,datetime tEnd);
void  Level(string id,double price,color clr,datetime tStart,datetime tEnd,string tag);
void  AlertLabel(int zone);
void  BigPrice(int dir,double px);
void  FireAlert(int zone,double px);
color Fade(color clr,int pct);
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,BufDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(1,BufUpper,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,BufLower,INDICATOR_CALCULATIONS);
   ArraySetAsSeries(BufDir,false);
   ArraySetAsSeries(BufUpper,false);
   ArraySetAsSeries(BufLower,false);
   IndicatorSetString(INDICATOR_SHORTNAME,"TOP/BOTTOM");
   hAtr=iATR(_Symbol,_Period,InpAtrPeriod);
   if(hAtr==INVALID_HANDLE)
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PFX);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<InpAtrPeriod+2)
      return(0);
   CalcTrend(rates_total,prev_calculated,high,low,close);
   //--- maximas/minimas do dia anterior (shift 1) e de dois dias atras (shift 2)
   MqlRates d1[];
   ArraySetAsSeries(d1,true);
   if(CopyRates(_Symbol,PERIOD_D1,0,3,d1)<3)
      return(prev_calculated);
   double hPrev  = d1[1].high;   // maxima do dia anterior
   double hPrev2 = d1[2].high;   // maxima de dois dias atras
   double lPrev  = d1[1].low;    // minima do dia anterior
   double lPrev2 = d1[2].low;    // minima de dois dias atras
   double sellTop = MathMax(hPrev,hPrev2);
   double sellBot = MathMin(hPrev,hPrev2);
   double buyTop  = MathMax(lPrev,lPrev2);
   double buyBot  = MathMin(lPrev,lPrev2);
   datetime tStart = d1[2].time;   // inicio do dia-2
   datetime tEnd   = time[rates_total-1]+PeriodSeconds()*InpExtendBars;
   if(tEnd<=tStart)
      tEnd=tStart+PeriodSeconds();
   //--- zonas
   Zone("SELL",sellTop,sellBot,InpSellClr,"SELL ZONE",tStart,tEnd);
   Zone("BUY",buyTop,buyBot,InpBuyClr,"BUY ZONE",tStart,tEnd);
   if(InpShowLevels)
     {
      Level("H1",hPrev,InpSellClr,tStart,tEnd,"H D-1");
      Level("H2",hPrev2,InpSellClr,tStart,tEnd,"H D-2");
      Level("L1",lPrev,InpBuyClr,tStart,tEnd,"L D-1");
      Level("L2",lPrev2,InpBuyClr,tStart,tEnd,"L D-2");
     }
   //--- preco atual e zona em que ele esta
   double px=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0.0)
      px=close[rates_total-1];
   int zone=0;
   if(px<=sellTop && px>=sellBot)
      zone=-1;                      // entre as duas maximas
   else
      if(px<=buyTop && px>=buyBot)
         zone=1;                    // entre as duas minimas
   if(InpShowAlertTop)
      AlertLabel(zone);
   if(InpBigPrice)
      BigPrice((int)BufDir[rates_total-1],px);
   FireAlert(zone,px);
   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| SuperTrend/ATR - so para dar a cor da tendencia ao preco grande   |
//+------------------------------------------------------------------+
void CalcTrend(const int rt,const int prev,const double &hi[],const double &lo[],const double &cl[])
  {
   if(BarsCalculated(hAtr)<rt)
      return;
   double atr[];
   ArraySetAsSeries(atr,false);
   if(CopyBuffer(hAtr,0,0,rt,atr)<rt)
      return;
   int start=(prev>1)?prev-1:InpAtrPeriod+1;
   for(int i=start; i<rt; i++)
     {
      double hl2=(hi[i]+lo[i])/2.0;
      double up=hl2+InpAtrMult*atr[i];
      double dn=hl2-InpAtrMult*atr[i];
      if(i==0 || BufDir[i-1]==0.0)
        {
         BufUpper[i]=up;
         BufLower[i]=dn;
         BufDir[i]=(cl[i]>=hl2)?1:-1;
        }
      else
        {
         BufUpper[i]=(up<BufUpper[i-1] || cl[i-1]>BufUpper[i-1])?up:BufUpper[i-1];
         BufLower[i]=(dn>BufLower[i-1] || cl[i-1]<BufLower[i-1])?dn:BufLower[i-1];
         double dir=BufDir[i-1];
         if(dir==1.0 && cl[i]<BufLower[i])
            dir=-1.0;
         if(dir==-1.0 && cl[i]>BufUpper[i])
            dir=1.0;
         BufDir[i]=dir;
        }
     }
  }
//+------------------------------------------------------------------+
//| Retangulo da zona + texto no meio                                 |
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
//| Linha de uma maxima/minima + etiqueta com o preco                 |
//+------------------------------------------------------------------+
void Level(string id,double price,color clr,datetime tStart,datetime tEnd,string tag)
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
      ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
     }
   else
     {
      ObjectMove(0,n,0,tStart,price);
      ObjectMove(0,n,1,tEnd,price);
     }
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   string t=PFX+"LVT_"+id;
   if(!InpShowLevelTag)
     {
      if(ObjectFind(0,t)>=0)
         ObjectDelete(0,t);
      return;
     }
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
//| Frase de alerta no topo, centro do grafico                        |
//+------------------------------------------------------------------+
void AlertLabel(int zone)
  {
   string n=PFX+"ALERT";
   if(zone==0)
     {
      if(ObjectFind(0,n)>=0)
         ObjectDelete(0,n);
      return;
     }
   string text=(zone==-1)?"ALERT: SELL ZONE":"ALERT: BUY ZONE";
   color clr=(zone==-1)?InpSellClr:InpBuyClr;
   int xMid=(int)(ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)/2);
   if(ObjectFind(0,n)<0)
     {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_UPPER);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetString(0,n,OBJPROP_FONT,"Arial Black");
     }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,xMid);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,InpAlertYOffset);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,InpAlertFontSize);
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
  }
//+------------------------------------------------------------------+
//| Preco grande no canto superior direito (igual ao X-TREND)         |
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
//| Push/popup/e-mail - so na ENTRADA da zona (nao repete)            |
//+------------------------------------------------------------------+
void FireAlert(int zone,double px)
  {
   if(zone==g_lastZone)
      return;
   g_lastZone=zone;
   if(zone==0)
      return;
   if(!InpAlertPush && !InpAlertPopup && !InpAlertEmail)
      return;
   string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
   string what=(zone==-1)?"SELL ZONE":"BUY ZONE";
   string msg=InpBrand+" "+_Symbol+" "+tf+": preco entrou na "+what+" @ "+DoubleToString(px,_Digits);
   if(InpAlertPush)
      SendNotification(msg);
   if(InpAlertPopup)
      Alert(msg);
   if(InpAlertEmail)
      SendMail(InpBrand+" - "+what+" "+_Symbol,msg);
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
