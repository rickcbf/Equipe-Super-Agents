//+------------------------------------------------------------------+
//|                                        RickEAFimathePro.mq5      |
//|  Estrategia Fimathe PRO — Canal de referencia (N velas)          |
//|                                                                  |
//|  Canal de referencia = N velas (padrao 4).                        |
//|                                                                  |
//|  CENARIO 1 (entrada na C1):                                        |
//|    Rompeu um lado -> projeta o canal a favor (C1 = borda + 1x lg). |
//|    ENTRADA no rompimento da C1. Alvo = 2x o canal a partir da      |
//|    entrada. Stop na borda OPOSTA do canal +/- spread.             |
//|    (vale p/ compra e venda, invertido)                            |
//|                                                                  |
//|  CENARIO 2 (entrada inversa):                                      |
//|    Rompeu um lado, marcou a C1, mas NEGOU (nao rompeu a C1) e      |
//|    voltou pro canal; depois rompeu o canal pro LADO OPOSTO ->      |
//|    ENTRADA no rompimento do canal de referencia (nao numa nova     |
//|    C1). Alvo = 2x o canal. Stop na borda oposta +/- spread.       |
//|                                                                  |
//|  UMA ordem por vez. Canal pode ser movido manualmente (arraste).  |
//|  Painel com botoes ZERAR ORDEM e ATIVAR/DESATIVAR o bot.          |
//+------------------------------------------------------------------+
#property copyright   "RickEA"
#property version     "3.00"
#property description "RickEAFimathe PRO — canal N velas, entrada C1 e inversa, alvo 2x"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_FASE
{
   FASE_SEM_CANAL,          // Sem canal — vai formar
   FASE_CANAL,              // Canal formado — monitorando rompimento/C1
   FASE_EM_POSICAO,         // Ordem aberta
   FASE_CANAL_LARGO         // Canal largo demais — nao opera
};

enum ENUM_CH_MODE
{
   CH_MODE_BARS  = 0,       // Canal por N velas (padrao)
   CH_MODE_SWING = 1        // Canal pela vela de topo/fundo mais proxima
};

enum ENUM_LOT_MODE
{
   LOT_MODE_FIXED   = 0,    // Lote fixo
   LOT_MODE_PERCENT = 1     // Percentual do saldo
};

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group "══════ Canal de Referencia ══════"
input ENUM_CH_MODE     InpChannelMode   = CH_MODE_BARS;    // Como formar o canal
input int              InpChannelBars   = 4;               // Velas do canal (modo N velas)
input int              InpSwingLookback = 3;               // Forca do swing (modo topo/fundo)
input int              InpSwingMaxScan  = 300;             // Alcance da busca (modo topo/fundo)
input group "══════ Entrada / Alvos ══════"
input double           InpTPmult        = 2.0;             // Alvo (x tamanho do canal, a partir da entrada)
input double           InpStopSpreadMult= 1.0;             // Folga do stop (x spread) alem do canal
input group "══════ Gestao de Risco ══════"
input int              InpMaxConcurrent = 1;               // Max trades simultaneos (uma ordem por vez)
input double           InpMaxDailyLoss  = 3.0;             // Perda diaria maxima (%)
input int              InpMaxTradesDay  = 5;               // Max trades por dia
input double           InpMetaUSD       = 50.0;            // Meta diaria USD (0=desativado)
input double           InpStopUSD       = 30.0;            // Stop diario USD (0=desativado)
input group "══════ Execucao ══════"
input ENUM_LOT_MODE    InpLotMode       = LOT_MODE_FIXED;  // Modo de lote
input double           InpLotFixed      = 0.01;            // Lote fixo
input double           InpLotPercent    = 1.0;             // Risco por trade (%)
input ulong            InpMagic         = 20251018;        // Magic Number
input int              InpSlippage      = 10;              // Slippage (pontos)
input group "══════ Filtros ══════"
input bool             InpNewsFilter    = true;            // Filtrar noticias alto impacto
input int              InpNewsBuffer    = 60;              // Buffer noticias (minutos)
input bool             InpAlertSound    = true;            // Alerta sonoro nos sinais
input group "══════ Visual ══════"
input bool             InpStartActive   = true;            // Bot ativo ao iniciar
input int              InpExtendBars    = 30;              // Extensao das linhas a direita (velas)
input color            InpClrCanal      = clrYellow;       // Canal (amarelo, discreto)
input color            InpClrTP         = clrLime;         // Take Profit (verde)
input color            InpClrSL         = clrRed;          // Stop Loss (vermelho)
input color            InpClrBuy        = clrDodgerBlue;   // Entrada COMPRA (azul)
input color            InpClrSell       = clrDarkOrange;   // Entrada VENDA (laranja)

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
CTrade         g_trade;

double         g_canal_high   = 0;
double         g_canal_low    = 0;
double         g_largura      = 0;
double         g_c1_up        = 0;    // projecao C1 acima = ch + lg
double         g_c1_dn        = 0;    // projecao C1 abaixo = cl - lg
datetime       g_ref_time     = 0;    // 1a vela do canal (inicio dos segmentos)

ENUM_FASE      g_fase         = FASE_SEM_CANAL;
int            g_primary_dir  = 0;    // lado do 1o rompimento do canal (+1/-1)
bool           g_c1_negated   = false;// rompeu, nao foi na C1 e voltou pro canal
bool           g_was_inside   = false;// preco esteve dentro do canal desde a formacao
bool           g_manual       = false;// canal movido manualmente
bool           g_bot_active   = true; // bot habilitado (botao do painel)

int            g_pos_dir      = 0;    // direcao da posicao atual (+1/-1)
string         g_entry_kind   = "";   // "C1" ou "INV"
double         g_entrada      = 0;
double         g_take         = 0;
double         g_stop         = 0;
datetime       g_entry_time   = 0;    // inicio dos segmentos de entrada/TP/SL

datetime       g_last_bar_time= 0;
int            g_prev_count   = 0;
int            g_trades_today = 0;
datetime       g_day_start    = 0;

const string   OBJ_PREFIX     = "RickFim_";

//+------------------------------------------------------------------+
//| Prototipos                                                        |
//+------------------------------------------------------------------+
void   RunStateMachine();
bool   BuildChannel();
bool   BuildChannelBars();
bool   BuildChannelSwing();
bool   IsSwingHigh(int i,int L);
bool   IsSwingLow(int i,int L);
void   ComputeC1();
void   SyncManualChannel();
bool   EnterTrade(int dir,double entry,double tp,double sl,string kind);
void   ResetCycle();
void   CloseAll(string motivo);
double StopBuffer();
int    CountOurPositions();
int    CountAllMagicPositions();
double CalcLot(double sl_distance);
double RoundLot(double lot);
bool   CanTrade(string &reason);
double GetDailyProfit();
bool   NewsAllowed();
double GetLgMax();
ENUM_ORDER_TYPE_FILLING DetectFilling();
void   DrawAll();
void   DrawSeg(string id,double price,color clr,ENUM_LINE_STYLE st,int w,datetime tStart,bool selectable);
void   DelObj(string id);
void   EnsurePanel();
void   UpdatePanel();
void   CreateRect(string n,int x,int y,int w,int h,color bg,color border);
void   CreateLabel(string n,int x,int y,string text,color clr,int fs,bool bold);
void   CreateButton(string n,int x,int y,int w,int h,string text,color fg,color bg);

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(DetectFilling());

   g_bot_active    = InpStartActive;
   g_day_start     = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_last_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);

   int count = CountOurPositions();
   g_prev_count = count;
   if(count > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)        continue;

         long pt   = PositionGetInteger(POSITION_TYPE);
         g_entrada = PositionGetDouble(POSITION_PRICE_OPEN);
         g_stop    = PositionGetDouble(POSITION_SL);
         g_take    = PositionGetDouble(POSITION_TP);
         g_pos_dir = (pt == POSITION_TYPE_BUY) ? 1 : -1;
         g_fase    = FASE_EM_POSICAO;
         g_entry_kind = "?";
         g_entry_time = iTime(_Symbol, PERIOD_CURRENT, 0);
         break;
      }
      PrintFormat("[Fimathe] %d posicao(oes) detectada(s) — modo protecao", count);
   }

   EnsurePanel();
   PrintFormat("[Fimathe PRO v3] %s %s | Magic=%d | Bot=%s | Canal=%s(%d)",
               _Symbol, EnumToString(_Period), InpMagic, g_bot_active ? "ON" : "OFF",
               (InpChannelMode == CH_MODE_BARS ? "N velas" : "swing"), InpChannelBars);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   Comment("");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Reset diario
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_day_start)
   {
      g_day_start    = today;
      g_trades_today = 0;
   }

   // Fechamento pelo broker (TP/SL) enquanto EM_POSICAO
   int cur = CountOurPositions();
   if(cur == 0 && g_prev_count > 0 && g_fase == FASE_EM_POSICAO)
   {
      Print("[Fimathe] Posicao fechada pelo broker — reiniciando ciclo");
      ResetCycle();
   }
   g_prev_count = cur;

   // Ajuste manual do canal (arraste)
   SyncManualChannel();

   // (Re)constroi canal enquanto ocioso, sem rompimento armado e sem ajuste manual
   bool newbar = false;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t != g_last_bar_time) { newbar = true; g_last_bar_time = t; }

   bool idle = (CountOurPositions() == 0 && g_primary_dir == 0 &&
                (g_fase == FASE_SEM_CANAL || g_fase == FASE_CANAL || g_fase == FASE_CANAL_LARGO));
   if(g_fase == FASE_SEM_CANAL || (newbar && idle && !g_manual))
   {
      if(BuildChannel())
      {
         g_was_inside = false;
         if(g_fase == FASE_SEM_CANAL || g_fase == FASE_CANAL_LARGO)
            g_fase = FASE_CANAL;
      }
   }

   ComputeC1();
   RunStateMachine();
   DrawAll();
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Maquina de estados Fimathe                                        |
//+------------------------------------------------------------------+
void RunStateMachine()
{
   if(g_canal_high <= 0 || g_canal_low <= 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0) return;
   if(!g_bot_active) return;              // desativado = passivo (so ZERAR fecha)

   double ch = g_canal_high, cl = g_canal_low, lg = g_largura;
   double buf = StopBuffer();

   // Canal largo demais
   if(lg > GetLgMax())
   {
      if(g_fase == FASE_CANAL) g_fase = FASE_CANAL_LARGO;
      return;
   }
   if(g_fase == FASE_CANAL_LARGO && lg <= GetLgMax()) g_fase = FASE_CANAL;
   if(g_fase != FASE_CANAL) return;

   // Preco dentro do canal (habilita 1o rompimento)
   if(bid >= cl && bid <= ch) g_was_inside = true;

   // ── 1o rompimento do canal: define o lado primario ──
   if(g_primary_dir == 0)
   {
      if(!g_was_inside) return;
      if(bid > ch)      g_primary_dir = 1;    // rompeu p/ cima
      else if(bid < cl) g_primary_dir = -1;   // rompeu p/ baixo
      if(g_primary_dir != 0)
         PrintFormat("[Fimathe] 1o rompimento %s | C1up=%s C1dn=%s",
                     (g_primary_dir > 0 ? "CIMA" : "BAIXO"),
                     DoubleToString(g_c1_up, _Digits), DoubleToString(g_c1_dn, _Digits));
      return;
   }

   // ── Negacao: voltou pro canal sem romper a C1 ──
   if(g_primary_dir > 0 && bid < ch) g_c1_negated = true;
   if(g_primary_dir < 0 && bid > cl) g_c1_negated = true;

   // ── Gatilhos de entrada ──
   if(g_primary_dir > 0)
   {
      // CENARIO 1: rompeu a C1 acima -> COMPRA na C1
      if(bid >= g_c1_up)
      {
         double entry = g_c1_up;
         double tp    = NormalizeDouble(entry + lg * InpTPmult, _Digits);
         double sl    = NormalizeDouble(cl - buf, _Digits);
         EnterTrade(1, entry, tp, sl, "C1");
      }
      // CENARIO 2: negou e rompeu o canal pra baixo -> VENDA na borda do canal
      else if(g_c1_negated && bid < cl)
      {
         double entry = cl;
         double tp    = NormalizeDouble(entry - lg * InpTPmult, _Digits);
         double sl    = NormalizeDouble(ch + buf, _Digits);
         EnterTrade(-1, entry, tp, sl, "INV");
      }
   }
   else // g_primary_dir < 0
   {
      // CENARIO 1: rompeu a C1 abaixo -> VENDA na C1
      if(bid <= g_c1_dn)
      {
         double entry = g_c1_dn;
         double tp    = NormalizeDouble(entry - lg * InpTPmult, _Digits);
         double sl    = NormalizeDouble(ch + buf, _Digits);
         EnterTrade(-1, entry, tp, sl, "C1");
      }
      // CENARIO 2: negou e rompeu o canal pra cima -> COMPRA na borda do canal
      else if(g_c1_negated && bid > ch)
      {
         double entry = ch;
         double tp    = NormalizeDouble(entry + lg * InpTPmult, _Digits);
         double sl    = NormalizeDouble(cl - buf, _Digits);
         EnterTrade(1, entry, tp, sl, "INV");
      }
   }
}

//+------------------------------------------------------------------+
//| Projecoes C1 a partir do canal atual                              |
//+------------------------------------------------------------------+
void ComputeC1()
{
   if(g_canal_high <= 0 || g_canal_low <= 0) { g_c1_up = 0; g_c1_dn = 0; return; }
   g_c1_up = NormalizeDouble(g_canal_high + g_largura, _Digits);
   g_c1_dn = NormalizeDouble(g_canal_low  - g_largura, _Digits);
}

//+------------------------------------------------------------------+
//| Constroi o canal conforme o modo                                  |
//+------------------------------------------------------------------+
bool BuildChannel()
{
   if(InpChannelMode == CH_MODE_SWING) return BuildChannelSwing();
   return BuildChannelBars();
}

//+------------------------------------------------------------------+
//| Canal = ultimas N velas fechadas                                  |
//+------------------------------------------------------------------+
bool BuildChannelBars()
{
   int n = InpChannelBars;
   if(n < 1) n = 1;
   if(Bars(_Symbol, PERIOD_CURRENT) < n + 2) return false;

   double hi = 0, lo = DBL_MAX;
   for(int i = 1; i <= n; i++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow (_Symbol, PERIOD_CURRENT, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   if(hi - lo <= 0) return false;

   g_canal_high = NormalizeDouble(hi, _Digits);
   g_canal_low  = NormalizeDouble(lo, _Digits);
   g_largura    = NormalizeDouble(hi - lo, _Digits);
   g_ref_time   = iTime(_Symbol, PERIOD_CURRENT, n);   // 1a vela do canal
   g_manual     = false;
   return true;
}

//+------------------------------------------------------------------+
//| Canal = vela de topo/fundo mais proxima do preco (opcional)       |
//+------------------------------------------------------------------+
bool BuildChannelSwing()
{
   int L    = InpSwingLookback;
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars < L * 2 + 5) return false;

   int scan = MathMin(InpSwingMaxScan, bars - L - 1);
   int hiIdx = -1, loIdx = -1;
   for(int i = L + 1; i <= scan; i++)
   {
      if(hiIdx < 0 && IsSwingHigh(i, L)) hiIdx = i;
      if(loIdx < 0 && IsSwingLow(i, L))  loIdx = i;
      if(hiIdx > 0 && loIdx > 0) break;
   }

   double preco = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int chosen = -1;
   if(hiIdx > 0 && loIdx > 0)
   {
      double dH = MathAbs(preco - iHigh(_Symbol, PERIOD_CURRENT, hiIdx));
      double dL = MathAbs(preco - iLow (_Symbol, PERIOD_CURRENT, loIdx));
      chosen = (dH <= dL) ? hiIdx : loIdx;
   }
   else if(hiIdx > 0) chosen = hiIdx;
   else if(loIdx > 0) chosen = loIdx;
   else return false;

   double hi = iHigh(_Symbol, PERIOD_CURRENT, chosen);
   double lo = iLow (_Symbol, PERIOD_CURRENT, chosen);
   if(hi - lo <= 0) return false;

   g_canal_high = NormalizeDouble(hi, _Digits);
   g_canal_low  = NormalizeDouble(lo, _Digits);
   g_largura    = NormalizeDouble(hi - lo, _Digits);
   g_ref_time   = iTime(_Symbol, PERIOD_CURRENT, chosen);
   g_manual     = false;
   return true;
}

bool IsSwingHigh(int i,int L)
{
   double h = iHigh(_Symbol, PERIOD_CURRENT, i);
   for(int k = 1; k <= L; k++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, i + k) > h) return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, i - k) > h) return false;
   }
   return true;
}

bool IsSwingLow(int i,int L)
{
   double l = iLow(_Symbol, PERIOD_CURRENT, i);
   for(int k = 1; k <= L; k++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, i + k) < l) return false;
      if(iLow(_Symbol, PERIOD_CURRENT, i - k) < l) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Le o canal se o usuario arrastou as linhas (ajuste manual)        |
//+------------------------------------------------------------------+
void SyncManualChannel()
{
   string nH = OBJ_PREFIX + "CH";
   string nL = OBJ_PREFIX + "CL";
   if(ObjectFind(0, nH) < 0 || ObjectFind(0, nL) < 0) return;

   double ph = ObjectGetDouble(0, nH, OBJPROP_PRICE, 0);
   double pl = ObjectGetDouble(0, nL, OBJPROP_PRICE, 0);
   if(ph <= 0 || pl <= 0) return;

   if(MathAbs(ph - g_canal_high) > _Point / 2.0 ||
      MathAbs(pl - g_canal_low)  > _Point / 2.0)
   {
      double hi = MathMax(ph, pl);
      double lo = MathMin(ph, pl);
      if(hi - lo <= 0) return;

      g_canal_high = NormalizeDouble(hi, _Digits);
      g_canal_low  = NormalizeDouble(lo, _Digits);
      g_largura    = NormalizeDouble(hi - lo, _Digits);
      g_manual     = true;
      ComputeC1();
      if(g_fase == FASE_SEM_CANAL || g_fase == FASE_CANAL_LARGO) g_fase = FASE_CANAL;
      PrintFormat("[Fimathe] Canal ajustado manualmente: H=%s L=%s Lg=%s",
                  DoubleToString(g_canal_high, _Digits),
                  DoubleToString(g_canal_low, _Digits),
                  DoubleToString(g_largura, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Folga do stop = spread * mult                                     |
//+------------------------------------------------------------------+
double StopBuffer()
{
   double sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(sp <= 0)
      sp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sp <= 0)
      sp = _Point * 10;                    // fallback minimo
   return sp * InpStopSpreadMult;
}

//+------------------------------------------------------------------+
//| Abre a ordem (uma por vez)                                        |
//+------------------------------------------------------------------+
bool EnterTrade(int dir,double entry,double tp,double sl,string kind)
{
   if(!g_bot_active) return false;
   if(CountOurPositions() > 0) return false;          // uma ordem por vez

   if(InpNewsFilter && !NewsAllowed())
   {
      Print("[Fimathe] Bloqueado — noticia de alto impacto");
      return false;
   }
   string block;
   if(!CanTrade(block))
   {
      PrintFormat("[Fimathe] Risco bloqueado: %s", block);
      return false;
   }

   // Respeita distancia minima de stops (a partir do preco atual)
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(dir > 0)
   {
      if(price - sl < stops) sl = price - stops;
      if(tp - price < stops) tp = price + stops;
   }
   else
   {
      if(sl - price < stops) sl = price + stops;
      if(price - tp < stops) tp = price - stops;
   }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double sl_dist = MathAbs(price - sl);
   double lot = RoundLot(CalcLot(sl_dist));
   if(lot <= 0)
   {
      Print("[Fimathe] Lote invalido");
      return false;
   }

   string comment = "RickFim_" + kind;
   bool ok = (dir > 0) ? g_trade.Buy (lot, _Symbol, 0, sl, tp, comment)
                       : g_trade.Sell(lot, _Symbol, 0, sl, tp, comment);
   if(!ok)
   {
      PrintFormat("[Fimathe] Falha ordem %s: err=%d retcode=%u",
                  kind, GetLastError(), g_trade.ResultRetcode());
      return false;
   }

   g_pos_dir     = dir;
   g_entry_kind  = kind;
   g_entrada     = entry;
   g_stop        = sl;
   g_take        = tp;
   g_fase        = FASE_EM_POSICAO;
   g_entry_time  = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_trades_today++;

   PrintFormat("[Fimathe] %s (%s) lot=%.2f entry=%s TP=%s SL=%s",
               (dir > 0 ? "COMPRA" : "VENDA"), kind, lot,
               DoubleToString(entry, _Digits), DoubleToString(tp, _Digits),
               DoubleToString(sl, _Digits));
   if(InpAlertSound)
      Alert(StringFormat("[Fimathe PRO] %s (%s) em %s",
            (dir > 0 ? "COMPRA" : "VENDA"), kind, _Symbol));
   return true;
}

//+------------------------------------------------------------------+
void ResetCycle()
{
   g_fase        = FASE_SEM_CANAL;
   g_primary_dir = 0;
   g_c1_negated  = false;
   g_was_inside  = false;
   g_manual      = false;
   g_pos_dir     = 0;
   g_entry_kind  = "";
   g_canal_high  = 0;
   g_canal_low   = 0;
   g_largura     = 0;
   g_c1_up       = 0;
   g_c1_dn       = 0;
   g_entrada     = 0;
   g_take        = 0;
   g_stop        = 0;
   DelObj("CH"); DelObj("CL"); DelObj("C1");
   DelObj("LV_ENTRY"); DelObj("LV_TP"); DelObj("LV_SL");
}

//+------------------------------------------------------------------+
void CloseAll(string motivo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)        continue;
      if(g_trade.PositionClose(ticket))
         PrintFormat("[Fimathe] Fechada #%d (%s)", ticket, motivo);
      else
         PrintFormat("[Fimathe] Falha ao fechar #%d: err=%d", ticket, GetLastError());
   }
   g_prev_count = CountOurPositions();
}

//+------------------------------------------------------------------+
int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

int CountAllMagicPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
double GetLgMax()
{
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") >= 0)                                          return 800.0;
   if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 ||
      StringFind(s, "XRP") >= 0)                                          return 3000.0;
   if(StringFind(s, "US30")  >= 0 || StringFind(s, "NAS") >= 0 ||
      StringFind(s, "SPX")   >= 0 || StringFind(s, "US500") >= 0 ||
      StringFind(s, "GER")   >= 0 || StringFind(s, "DAX") >= 0 ||
      StringFind(s, "UK100") >= 0)                                        return 1500.0;
   return 600.0;
}

//+------------------------------------------------------------------+
double CalcLot(double sl_distance)
{
   if(InpLotMode == LOT_MODE_FIXED || sl_distance <= 0)
      return InpLotFixed;

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0 || tick_value <= 0)
      return InpLotFixed;

   double balance      = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount  = balance * InpLotPercent / 100.0;
   double dist_ticks   = sl_distance / tick_size;
   double risk_per_lot = dist_ticks * tick_value;
   if(risk_per_lot <= 0) return InpLotFixed;

   return risk_amount / risk_per_lot;
}

double RoundLot(double lot)
{
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;

   lot = MathFloor(lot / step) * step;
   int decimals = (step < 1) ? (int)MathCeil(-MathLog10(step)) : 0;
   lot = NormalizeDouble(lot, decimals);

   if(lot < vol_min) lot = vol_min;
   if(lot > vol_max) lot = vol_max;
   return lot;
}

//+------------------------------------------------------------------+
bool CanTrade(string &reason)
{
   int active = CountAllMagicPositions();
   if(active >= InpMaxConcurrent)
   {
      reason = StringFormat("Max simultaneos (%d/%d)", active, InpMaxConcurrent);
      return false;
   }
   if(g_trades_today >= InpMaxTradesDay)
   {
      reason = StringFormat("Max trades/dia (%d/%d)", g_trades_today, InpMaxTradesDay);
      return false;
   }

   double daily   = GetDailyProfit();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(InpMetaUSD > 0 && daily >= InpMetaUSD)
   {
      reason = StringFormat("Meta atingida ($%.2f / $%.2f)", daily, InpMetaUSD);
      return false;
   }
   if(InpStopUSD > 0 && daily <= -InpStopUSD)
   {
      reason = StringFormat("Stop diario ($%.2f / -$%.2f)", daily, InpStopUSD);
      return false;
   }
   if(balance > 0)
   {
      double pct = daily / balance * 100.0;
      if(pct <= -InpMaxDailyLoss)
      {
         reason = StringFormat("Perda max (%.2f%% / -%.2f%%)", pct, InpMaxDailyLoss);
         return false;
      }
   }
   return true;
}

double GetDailyProfit()
{
   datetime from = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime to   = from + 86400;
   if(!HistorySelect(from, to)) return 0;

   double total = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagic)  continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)  continue;
      total += HistoryDealGetDouble(ticket, DEAL_PROFIT)
             + HistoryDealGetDouble(ticket, DEAL_SWAP)
             + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return total;
}

//+------------------------------------------------------------------+
bool NewsAllowed()
{
   datetime from = TimeCurrent() - InpNewsBuffer * 60;
   datetime to   = TimeCurrent() + InpNewsBuffer * 60;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from, to);
   if(count <= 0) return true;

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(CalendarEventById(values[i].event_id, event))
      {
         if(event.importance == CALENDAR_IMPORTANCE_HIGH)
         {
            PrintFormat("[Fimathe] Noticia alto impacto: %s", event.name);
            return false;
         }
      }
   }
   return true;
}

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING DetectFilling()
{
   uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   if((fill & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Desenho — segmentos (nao linhas de tela cheia)                    |
//+------------------------------------------------------------------+
void DrawAll()
{
   // Canal (amarelo discreto) — quando formado
   if(g_canal_high > 0 && g_canal_low > 0)
   {
      datetime tRef = (g_ref_time > 0) ? g_ref_time : g_last_bar_time - PeriodSeconds() * 3;
      DrawSeg("CH", g_canal_high, InpClrCanal, STYLE_DOT, 1, tRef, true);
      DrawSeg("CL", g_canal_low,  InpClrCanal, STYLE_DOT, 1, tRef, true);
   }
   else { DelObj("CH"); DelObj("CL"); }

   // C1 pendente (cenario 1) — quando ha rompimento armado e sem posicao
   if(g_fase == FASE_CANAL && g_primary_dir != 0)
   {
      double c1  = (g_primary_dir > 0) ? g_c1_up : g_c1_dn;
      color  cc1 = (g_primary_dir > 0) ? InpClrBuy : InpClrSell;
      datetime tR = (g_ref_time > 0) ? g_ref_time : g_last_bar_time;
      DrawSeg("C1", c1, cc1, STYLE_DASHDOT, 1, tR, false);
   }
   else DelObj("C1");

   // Entrada / TP / Stop — quando EM_POSICAO
   if(g_fase == FASE_EM_POSICAO && g_pos_dir != 0)
   {
      datetime tE = (g_entry_time > 0) ? g_entry_time : g_last_bar_time;
      color cEntry = (g_pos_dir > 0) ? InpClrBuy : InpClrSell;
      DrawSeg("LV_ENTRY", g_entrada, cEntry,   STYLE_DASH,  1, tE, false);
      DrawSeg("LV_TP",    g_take,    InpClrTP, STYLE_SOLID, 2, tE, false);
      DrawSeg("LV_SL",    g_stop,    InpClrSL, STYLE_SOLID, 2, tE, false);
   }
   else
   {
      DelObj("LV_ENTRY"); DelObj("LV_TP"); DelObj("LV_SL");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void DrawSeg(string id,double price,color clr,ENUM_LINE_STYLE st,int w,datetime tStart,bool selectable)
{
   string n = OBJ_PREFIX + id;
   datetime tEnd = g_last_bar_time + PeriodSeconds() * InpExtendBars;
   if(tStart <= 0)    tStart = g_last_bar_time - PeriodSeconds() * 3;
   if(tStart >= tEnd) tStart = tEnd - PeriodSeconds() * 3;

   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_TREND, 0, tStart, price, tEnd, price);
      ObjectSetInteger(0, n, OBJPROP_RAY_LEFT,  false);
      ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, selectable);
      ObjectSetInteger(0, n, OBJPROP_SELECTED,   false);
      ObjectSetInteger(0, n, OBJPROP_BACK,       false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
      if(selectable)
         ObjectSetString(0, n, OBJPROP_TOOLTIP, "Canal de referencia (arraste p/ ajustar)");
   }
   else
   {
      ObjectMove(0, n, 0, tStart, price);
      ObjectMove(0, n, 1, tEnd,   price);
   }
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_STYLE, st);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, w);
}

void DelObj(string id)
{
   string n = OBJ_PREFIX + id;
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
}

//+------------------------------------------------------------------+
//| Painel (quadro) com botoes                                        |
//+------------------------------------------------------------------+
void EnsurePanel()
{
   CreateRect (OBJ_PREFIX + "P_BG",   10, 18, 288, 194, C'25,25,25',  clrGoldenrod);
   CreateRect (OBJ_PREFIX + "P_HEAD", 10, 18, 288, 22,  C'70,55,0',   clrGoldenrod);
   CreateLabel(OBJ_PREFIX + "P_T",    18, 21, "RickEA Fimathe PRO", clrWhite, 10, true);

   CreateLabel(OBJ_PREFIX + "P_L0", 18, 48,  "", clrWhite,  9, true);
   CreateLabel(OBJ_PREFIX + "P_L1", 18, 66,  "", clrSilver, 9, false);
   CreateLabel(OBJ_PREFIX + "P_L2", 18, 84,  "", clrSilver, 9, false);
   CreateLabel(OBJ_PREFIX + "P_L3", 18, 102, "", InpClrBuy, 9, false);
   CreateLabel(OBJ_PREFIX + "P_L4", 18, 120, "", InpClrTP,  9, false);
   CreateLabel(OBJ_PREFIX + "P_L5", 18, 138, "", InpClrSL,  9, false);
   CreateLabel(OBJ_PREFIX + "P_L6", 18, 156, "", clrSilver, 9, false);

   CreateButton(OBJ_PREFIX + "BTN_ZERAR",  18,  178, 130, 26, "ZERAR ORDEM", clrWhite, C'130,0,0');
   CreateButton(OBJ_PREFIX + "BTN_TOGGLE", 156, 178, 130, 26, "BOT: ON",     clrWhite, C'0,100,0');
}

void UpdatePanel()
{
   string fase_str;
   switch(g_fase)
   {
      case FASE_SEM_CANAL:   fase_str = "Formando canal...";           break;
      case FASE_CANAL:
         if(g_primary_dir == 0)       fase_str = "Canal — aguardando rompimento";
         else if(!g_c1_negated)       fase_str = StringFormat("Rompeu %s — aguardando C1",
                                                    (g_primary_dir > 0 ? "CIMA" : "BAIXO"));
         else                         fase_str = "Negou C1 — aguardando inversa";
         break;
      case FASE_EM_POSICAO:  fase_str = StringFormat("EM POSICAO (%s)", g_entry_kind); break;
      case FASE_CANAL_LARGO: fase_str = "Canal largo — sem operar";    break;
      default:               fase_str = "---";                         break;
   }

   double daily = GetDailyProfit();
   int    pos   = CountOurPositions();

   CreateLabel(OBJ_PREFIX + "P_L0", 18, 48, "Fase: " + fase_str, clrWhite, 9, true);
   CreateLabel(OBJ_PREFIX + "P_L1", 18, 66,
               StringFormat("Canal H=%s L=%s Lg=%s",
                            DoubleToString(g_canal_high, _Digits),
                            DoubleToString(g_canal_low,  _Digits),
                            DoubleToString(g_largura,    _Digits)),
               clrSilver, 9, false);
   CreateLabel(OBJ_PREFIX + "P_L2", 18, 84,
               StringFormat("C1+ =%s   C1- =%s",
                            DoubleToString(g_c1_up, _Digits),
                            DoubleToString(g_c1_dn, _Digits)),
               clrGoldenrod, 9, false);

   if(g_fase == FASE_EM_POSICAO && g_pos_dir != 0)
   {
      color cEntry = (g_pos_dir > 0) ? InpClrBuy : InpClrSell;
      CreateLabel(OBJ_PREFIX + "P_L3", 18, 102,
                  StringFormat("Entrada %s: %s", (g_pos_dir > 0 ? "COMPRA" : "VENDA"),
                               DoubleToString(g_entrada, _Digits)), cEntry, 9, false);
      CreateLabel(OBJ_PREFIX + "P_L4", 18, 120, "TP (verde): "  + DoubleToString(g_take, _Digits), InpClrTP, 9, false);
      CreateLabel(OBJ_PREFIX + "P_L5", 18, 138, "Stop (verm): " + DoubleToString(g_stop, _Digits), InpClrSL, 9, false);
   }
   else
   {
      CreateLabel(OBJ_PREFIX + "P_L3", 18, 102, "Entrada: —", clrDimGray, 9, false);
      CreateLabel(OBJ_PREFIX + "P_L4", 18, 120, "TP: —",      clrDimGray, 9, false);
      CreateLabel(OBJ_PREFIX + "P_L5", 18, 138, "Stop: —",    clrDimGray, 9, false);
   }

   CreateLabel(OBJ_PREFIX + "P_L6", 18, 156,
               StringFormat("Pos:%d  Trades:%d/%d  P&L dia:$%.2f",
                            pos, g_trades_today, InpMaxTradesDay, daily),
               (daily >= 0 ? clrLime : clrTomato), 9, false);

   string bn = OBJ_PREFIX + "BTN_TOGGLE";
   ObjectSetString (0, bn, OBJPROP_TEXT,    g_bot_active ? "BOT: ON" : "BOT: OFF");
   ObjectSetInteger(0, bn, OBJPROP_BGCOLOR, g_bot_active ? C'0,100,0' : C'90,90,90');
   ObjectSetInteger(0, bn, OBJPROP_STATE,   false);
}

//+------------------------------------------------------------------+
void CreateRect(string n,int x,int y,int w,int h,color bg,color border)
{
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE,   x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE,   y);
      ObjectSetInteger(0, n, OBJPROP_XSIZE,       w);
      ObjectSetInteger(0, n, OBJPROP_YSIZE,       h);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_BACK,        false);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0, n, OBJPROP_WIDTH,       1);
   }
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR,   border);
}

void CreateLabel(string n,int x,int y,string text,color clr,int fs,bool bold)
{
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   }
   ObjectSetString (0, n, OBJPROP_TEXT,     text);
   ObjectSetInteger(0, n, OBJPROP_COLOR,    clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
   ObjectSetString (0, n, OBJPROP_FONT,     bold ? "Arial Bold" : "Arial");
}

void CreateButton(string n,int x,int y,int w,int h,string text,color fg,color bg)
{
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  y);
      ObjectSetInteger(0, n, OBJPROP_XSIZE,      w);
      ObjectSetInteger(0, n, OBJPROP_YSIZE,      h);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
      ObjectSetString (0, n, OBJPROP_FONT,       "Arial Bold");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   9);
   }
   ObjectSetString (0, n, OBJPROP_TEXT,    text);
   ObjectSetInteger(0, n, OBJPROP_COLOR,   fg);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_STATE,   false);
}

//+------------------------------------------------------------------+
//| Cliques nos botoes do painel                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == OBJ_PREFIX + "BTN_ZERAR")
   {
      CloseAll("botao ZERAR ORDEM");
      ResetCycle();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      Print("[Fimathe] ZERAR ORDEM acionado pelo painel");
   }
   else if(sparam == OBJ_PREFIX + "BTN_TOGGLE")
   {
      g_bot_active = !g_bot_active;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      PrintFormat("[Fimathe] Bot %s pelo painel", g_bot_active ? "ATIVADO" : "DESATIVADO");
      UpdatePanel();
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
