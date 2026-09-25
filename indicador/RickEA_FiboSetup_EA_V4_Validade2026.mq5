//+------------------------------------------------------------------+
//|                                              FiboSetup_EA.mq5    |
//|                         Setup Fibonacci - RicharTrader           |
//|                                                                  |
//|  Entradas:    Fibonacci 0.618 / 0.786                            |
//|  Parcial 50%: Extensao  -0.272 (acima/abaixo do swing)           |
//|  Alvo final:  Extensao  -0.618 (R:R ~2.4:1)                      |
//|  Stop Loss:   Fibonacci  1.127                                   |
//+------------------------------------------------------------------+
#property copyright "RicharTrader"
#property version   "5.00"
#property description "Setup Fibonacci: Entrada 0.618/0.786 | Parcial -0.272 | TP -0.424 | SL 1.127 | R:R 1.6:1"
#property description "Valido ate 31/12/2026 (horario do servidor)"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Grupos de inputs
input group "=== NIVEIS DE FIBONACCI ==="
input double Inp_Entry1     = 0.618;   // Nivel de Entrada 1
input double Inp_Entry2     = 0.786;   // Nivel de Entrada 2 (0.886 desativado - dilui performance)
input double Inp_PartialTP  = -0.272;  // Extensao Parcial (negativo = alem do swing)
input double Inp_FullTP     = -0.424;  // Extensao Alvo Final (R:R ~1.6:1)
input double Inp_StopLoss   = 1.272;   // Nivel do Stop Loss (R:R ~1.6:1 na entrada 0.618)

input group "=== CONFIGURACOES DE TRADE ==="
input double Inp_LotSize        = 0.10;  // Volume (Lote)
input double Inp_PartialPercent = 50.0;  // % do lote para fechar na parcial
input bool   Inp_Breakeven      = true;  // Mover SL para breakeven apos parcial
input int    Inp_SwingLookback  = 50;    // Barras para detectar Swing (era 30)
input double Inp_ZonePoints     = 20.0;  // Tolerancia de zona de entrada (era 15)
input bool   Inp_TradeAuto      = true;  // Operar automaticamente (false = so alertas)
input bool   Inp_DrawLevels     = true;  // Desenhar niveis no grafico
input bool   Inp_SendAlerts     = true;  // Enviar alertas de sinal

input group "=== GESTAO DE RISCO DIARIA ==="
input double Inp_MaxDailyLossPct  = 3.0;  // Perda maxima diaria (%)
input double Inp_MaxDailyProfitPct= 2.0;  // Meta diaria (%) - para ao atingir
input int    Inp_MaxTradesPerDay  = 6;    // Maximo de trades por dia

input group "=== IDENTIFICACAO ==="
input int    Inp_MagicNumber = 78618;   // Magic Number

//--- Validade da licenca (horario do servidor da corretora)
const datetime LIC_EXPIRY = D'2026.12.31 23:59:59';
bool           g_expiredMsg = false;

//--- Objetos globais
CTrade         g_trade;
CPositionInfo  g_pos;

//--- Variaveis de estado
double g_swingHigh    = 0;
double g_swingLow     = 0;
bool   g_isBullish    = false;
bool   g_isBearish    = false;
bool   g_partialDone  = false;
bool   g_breakevenDone = false;
datetime g_lastSignalTime = 0;

//--- Niveis de entrada (retracoes)
double g_lvl_618  = 0;
double g_lvl_786  = 0;
double g_lvl_1127 = 0;

//--- Niveis de saida (extensoes - calculados dinamicamente)
double g_lvl_tp_partial = 0;  // Extensao parcial (Inp_PartialTP)
double g_lvl_tp_final   = 0;  // Extensao alvo final (Inp_FullTP)

//--- Controle diario
int    g_tradesToday     = 0;
double g_balanceDayStart = 0;
datetime g_lastDayCheck  = 0;

//+------------------------------------------------------------------+
//| Inicializacao                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Validade: vencido e sem posicao para administrar = nao carrega
    if(Expired() && !HasOpenPosition())
    {
        Alert("FiboSetup EA: a validade terminou em 31/12/2026. Fale com @ri.chartrader para renovar.");
        return(INIT_FAILED);
    }

    g_trade.SetExpertMagicNumber(Inp_MagicNumber);
    g_trade.SetDeviationInPoints(20);
    g_trade.SetTypeFilling(ORDER_FILLING_RETURN);  // RETURN: compativel com todos os brokers
    g_trade.LogLevel(LOG_LEVEL_ERRORS);

    g_balanceDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
    g_lastDayCheck    = TimeCurrent();

    Print("FiboSetup EA V5 iniciado | Magic: ", Inp_MagicNumber,
          " | Auto: ", Inp_TradeAuto,
          " | TP: ", Inp_FullTP, " | SL: ", Inp_StopLoss,
          " | MaxLoss: ", Inp_MaxDailyLossPct, "% | Meta: ", Inp_MaxDailyProfitPct, "%");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Limpeza                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DeleteAllObjects();
    Comment("");
}

//+------------------------------------------------------------------+
//| Loop principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- So executa logica em candle novo (evita excesso de processamento)
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool newBar = (currentBar != lastBar);
    if(newBar) lastBar = currentBar;

    //--- Detecta swings e calcula niveis
    if(newBar)
    {
        DetectSwings();
        CalculateFiboLevels();

        if(Inp_DrawLevels)
            DrawFiboLevels();
    }

    //--- Validade: depois de 31/12/2026 so administra o que estiver aberto
    if(newBar)
        Comment(ExpiryText());
    if(Expired())
    {
        if(!g_expiredMsg)
        {
            g_expiredMsg = true;
            Comment(ExpiryText());
            Alert("FiboSetup EA: a validade terminou em 31/12/2026. Nenhuma ordem nova sera aberta. Fale com @ri.chartrader para renovar.");
        }
        ManagePositions();
        if(!HasOpenPosition())
            ExpertRemove();          // nada mais para administrar: sai do grafico
        return;
    }

    //--- Verifica entradas e gerencia posicoes a cada tick
    CheckForEntry();
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Validade: usa o horario do servidor (nao o relogio do PC)        |
//+------------------------------------------------------------------+
datetime ServerNow()
{
    datetime t = TimeTradeServer();
    if(t < TimeCurrent()) t = TimeCurrent();
    return t;
}

bool Expired()
{
    datetime now = ServerNow();
    return (now > 0 && now > LIC_EXPIRY);
}

string ExpiryText()
{
    if(Expired())
        return "FiboSetup EA - LICENCA EXPIRADA em 31/12/2026 (sem ordens novas)";
    int days = (int)((LIC_EXPIRY - ServerNow()) / 86400);
    if(days <= 15)
        return "FiboSetup EA - valido ate 31/12/2026 (faltam " + IntegerToString(days) + " dia(s))";
    return "FiboSetup EA - valido ate 31/12/2026";
}

//+------------------------------------------------------------------+
//| Detecta o ultimo Swing High e Swing Low significativos           |
//+------------------------------------------------------------------+
void DetectSwings()
{
    int lb = Inp_SwingLookback;
    double highPrice = 0;
    double lowPrice  = DBL_MAX;
    int    highBar   = 0;
    int    lowBar    = 0;

    for(int i = 1; i <= lb; i++)
    {
        double h = iHigh(_Symbol, PERIOD_CURRENT, i);
        double l = iLow(_Symbol, PERIOD_CURRENT, i);

        if(h > highPrice) { highPrice = h; highBar = i; }
        if(l < lowPrice)  { lowPrice  = l; lowBar  = i; }
    }

    if(highPrice == 0 || lowPrice == DBL_MAX) return;

    //--- Determina direcao:
    //    Bullish setup: low formado ANTES do high (impulso de alta, agora retraindo para compra)
    //    Bearish setup: high formado ANTES do low (impulso de baixa, agora retraindo para venda)
    if(lowBar > highBar)
    {
        //--- Impulso de alta: A (low) -> B (high), aguardando retracao para COMPRA
        g_swingLow  = lowPrice;
        g_swingHigh = highPrice;
        g_isBullish = true;
        g_isBearish = false;
    }
    else
    {
        //--- Impulso de baixa: A (high) -> B (low), aguardando retracao para VENDA
        g_swingHigh = highPrice;
        g_swingLow  = lowPrice;
        g_isBullish = false;
        g_isBearish = true;
    }
}

//+------------------------------------------------------------------+
//| Calcula os precos dos niveis de Fibonacci                        |
//+------------------------------------------------------------------+
void CalculateFiboLevels()
{
    if(g_swingHigh == 0 || g_swingLow == 0) return;

    double range = g_swingHigh - g_swingLow;
    if(range <= 0) return;

    if(g_isBullish)
    {
        //--- Retracoes (entradas): medidas do High para baixo
        g_lvl_618  = g_swingHigh - range * Inp_Entry1;   // Entrada 1
        g_lvl_786  = g_swingHigh - range * Inp_Entry2;   // Entrada 2
        g_lvl_1127 = g_swingHigh - range * Inp_StopLoss; // Stop Loss (abaixo do Low)

        //--- Extensoes de saida: negativo = acima do swingHigh (nova alta)
        g_lvl_tp_partial = (Inp_PartialTP < 0)
            ? g_swingHigh + range * MathAbs(Inp_PartialTP)  // extensao acima do High
            : g_swingHigh - range * Inp_PartialTP;           // retracao conservadora
        g_lvl_tp_final = (Inp_FullTP < 0)
            ? g_swingHigh + range * MathAbs(Inp_FullTP)
            : g_swingHigh - range * Inp_FullTP;
    }
    else
    {
        //--- Retracoes (entradas): medidas do Low para cima
        g_lvl_618  = g_swingLow + range * Inp_Entry1;    // Entrada 1
        g_lvl_786  = g_swingLow + range * Inp_Entry2;    // Entrada 2
        g_lvl_1127 = g_swingLow + range * Inp_StopLoss;  // Stop Loss (acima do High)

        //--- Extensoes de saida: negativo = abaixo do swingLow (nova baixa)
        g_lvl_tp_partial = (Inp_PartialTP < 0)
            ? g_swingLow - range * MathAbs(Inp_PartialTP)
            : g_swingLow + range * Inp_PartialTP;
        g_lvl_tp_final = (Inp_FullTP < 0)
            ? g_swingLow - range * MathAbs(Inp_FullTP)
            : g_swingLow + range * Inp_FullTP;
    }
}

//+------------------------------------------------------------------+
//| Verifica se ha sinal de entrada                                  |
//+------------------------------------------------------------------+
void CheckForEntry()
{
    if(g_swingHigh == 0 || g_swingLow == 0) return;
    if(g_lvl_618 == 0 || g_lvl_tp_final == 0) return;

    //--- Limites diarios
    CheckDailyReset();
    if(g_tradesToday >= Inp_MaxTradesPerDay) return;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(g_balanceDayStart > 0)
    {
        double pnlPct = (balance - g_balanceDayStart) / g_balanceDayStart * 100.0;
        if(pnlPct <= -Inp_MaxDailyLossPct)
        {
            if(Inp_SendAlerts)
                Alert("STOP DIARIO: -", Inp_MaxDailyLossPct, "% atingido. EA pausado.");
            return;
        }
        if(pnlPct >= Inp_MaxDailyProfitPct)
        {
            if(Inp_SendAlerts)
                Alert("META DIARIA: +", Inp_MaxDailyProfitPct, "% atingida. EA pausado.");
            return;
        }
    }

    //--- Evita multiplas entradas no mesmo candle
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBar == g_lastSignalTime) return;

    //--- Verifica se ja existe posicao aberta deste EA
    if(HasOpenPosition()) return;

    double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double zone  = Inp_ZonePoints * point;

    if(g_isBullish)
    {
        if(ask <= g_lvl_1127 || ask >= g_swingHigh) return;

        bool in618 = (MathAbs(ask - g_lvl_618) <= zone);
        bool in786 = (MathAbs(ask - g_lvl_786) <= zone);

        if(in618 || in786)
        {
            string lvlName    = in618 ? "0.618" : "0.786";
            double entryPrice = ask;
            double sl         = g_lvl_1127;
            double tp         = g_lvl_tp_final;

            SendSignalAlert("COMPRA", lvlName, entryPrice, sl, tp, g_lvl_tp_partial);

            if(Inp_TradeAuto)
            {
                if(g_trade.Buy(Inp_LotSize, _Symbol, entryPrice, sl, tp,
                               "FiboSetup BUY @" + lvlName))
                {
                    g_partialDone   = false;
                    g_breakevenDone = false;
                    g_lastSignalTime = currentBar;
                    g_tradesToday++;
                    Print("COMPRA aberta | Entrada: ", entryPrice,
                          " | SL: ", sl, " | TP: ", tp,
                          " | Parcial: ", g_lvl_tp_partial,
                          " | Fibo: ", lvlName);
                }
            }
        }
    }
    else if(g_isBearish)
    {
        if(bid >= g_lvl_1127 || bid <= g_swingLow) return;

        bool in618 = (MathAbs(bid - g_lvl_618) <= zone);
        bool in786 = (MathAbs(bid - g_lvl_786) <= zone);

        if(in618 || in786)
        {
            string lvlName    = in618 ? "0.618" : "0.786";
            double entryPrice = bid;
            double sl         = g_lvl_1127;
            double tp         = g_lvl_tp_final;

            SendSignalAlert("VENDA", lvlName, entryPrice, sl, tp, g_lvl_tp_partial);

            if(Inp_TradeAuto)
            {
                if(g_trade.Sell(Inp_LotSize, _Symbol, entryPrice, sl, tp,
                                "FiboSetup SELL @" + lvlName))
                {
                    g_partialDone   = false;
                    g_breakevenDone = false;
                    g_lastSignalTime = currentBar;
                    g_tradesToday++;
                    Print("VENDA aberta | Entrada: ", entryPrice,
                          " | SL: ", sl, " | TP: ", tp,
                          " | Parcial: ", g_lvl_tp_partial,
                          " | Fibo: ", lvlName);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Gerencia posicoes abertas (fechamento parcial)                   |
//+------------------------------------------------------------------+
void ManagePositions()
{
    if(!HasOpenPosition()) return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_pos.SelectByIndex(i)) continue;
        if(g_pos.Magic() != Inp_MagicNumber) continue;
        if(g_pos.Symbol() != _Symbol) continue;

        ENUM_POSITION_TYPE posType = g_pos.PositionType();

        //--- Fechamento parcial na extensao -0.272
        if(!g_partialDone)
        {
            bool hitPartial = false;
            if(posType == POSITION_TYPE_BUY  && bid >= g_lvl_tp_partial) hitPartial = true;
            if(posType == POSITION_TYPE_SELL && ask <= g_lvl_tp_partial) hitPartial = true;

            if(hitPartial)
            {
                double vol     = g_pos.Volume();
                double volMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                double lotToClose = NormalizeVolume(vol * Inp_PartialPercent / 100.0, volMin, volStep);

                if(lotToClose >= volMin && (vol - lotToClose) >= volMin)
                {
                    if(g_trade.PositionClosePartial(g_pos.Ticket(), lotToClose))
                    {
                        g_partialDone = true;
                        Print("PARCIAL FECHADA | ", lotToClose, " lotes @ extensao ",
                              Inp_PartialTP, " = ", DoubleToString(g_lvl_tp_partial, _Digits));

                        if(Inp_SendAlerts)
                            Alert("PARCIAL 50% | ", _Symbol, " | Extensao ",
                                  Inp_PartialTP, " @ ", DoubleToString(g_lvl_tp_partial, _Digits));
                    }
                }
                else
                {
                    g_trade.PositionClose(g_pos.Ticket());
                    g_partialDone = true;
                    Print("Posicao fechada totalmente (volume insuficiente para parcial)");
                }
            }
        }

        //--- Mover SL para breakeven apos parcial
        if(g_partialDone && !g_breakevenDone && Inp_Breakeven)
        {
            double entryPrice = g_pos.PriceOpen();
            double currentSL  = g_pos.StopLoss();
            double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

            bool shouldMove = false;
            if(posType == POSITION_TYPE_BUY  && currentSL < entryPrice - point) shouldMove = true;
            if(posType == POSITION_TYPE_SELL && currentSL > entryPrice + point) shouldMove = true;

            if(shouldMove)
            {
                if(g_trade.PositionModify(g_pos.Ticket(), entryPrice, g_pos.TakeProfit()))
                {
                    g_breakevenDone = true;
                    Print("BREAKEVEN ativado | SL movido para entrada: ",
                          DoubleToString(entryPrice, _Digits));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Verifica se existe posicao aberta deste EA                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Reset diario dos contadores de risco                             |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime now, last;
    TimeToStruct(TimeCurrent(), now);
    TimeToStruct(g_lastDayCheck, last);

    if(now.day != last.day || now.mon != last.mon)
    {
        g_tradesToday     = 0;
        g_balanceDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
        g_lastDayCheck    = TimeCurrent();
        Print("Reset diario | Balance inicial: ", g_balanceDayStart);
    }
}

//+------------------------------------------------------------------+
//| Verifica se existe posicao aberta deste EA                       |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(g_pos.SelectByIndex(i) &&
           g_pos.Magic() == Inp_MagicNumber &&
           g_pos.Symbol() == _Symbol)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Normaliza volume respeitando step e minimo do ativo              |
//+------------------------------------------------------------------+
double NormalizeVolume(double vol, double minVol, double step)
{
    vol = MathFloor(vol / step) * step;
    if(vol < minVol) vol = minVol;
    return NormalizeDouble(vol, 2);
}

//+------------------------------------------------------------------+
//| Envia alerta formatado com os dados do sinal                     |
//+------------------------------------------------------------------+
void SendSignalAlert(string direction, string fiboLevel,
                     double entry, double sl, double tp, double partial)
{
    if(!Inp_SendAlerts) return;

    double riskPoints   = MathAbs(entry - sl);
    double rewardPoints = MathAbs(tp - entry);
    double rr = (riskPoints > 0) ? rewardPoints / riskPoints : 0;

    string msg = StringFormat(
        "SINAL %s | %s\n"
        "Fibo: %s | Entrada: %s\n"
        "Stop Loss: %s (Fibo 1.127)\n"
        "Parcial 50%%: %s (Fibo 0.382)\n"
        "Alvo Final: %s (Fibo 0.236)\n"
        "R/R: 1:%.2f",
        direction, _Symbol, fiboLevel,
        DoubleToString(entry, _Digits),
        DoubleToString(sl, _Digits),
        DoubleToString(partial, _Digits),
        DoubleToString(tp, _Digits),
        rr
    );

    Alert(msg);
    Print(msg);
}

//+------------------------------------------------------------------+
//| Desenha linhas horizontais dos niveis de Fibonacci               |
//+------------------------------------------------------------------+
void DrawFiboLevels()
{
    if(g_swingHigh == 0 || g_swingLow == 0) return;

    string dir = g_isBullish ? "BUY" : "SELL";

    DrawHLine("Fibo_SwingHigh",   g_swingHigh,       clrLime,        "0.000 - Swing High");
    DrawHLine("Fibo_SwingLow",    g_swingLow,        clrLime,        "1.000 - Swing Low");
    DrawHLine("Fibo_TP_Final",    g_lvl_tp_final,    clrDodgerBlue,  DoubleToString(Inp_FullTP,3) + " - Alvo Final [" + dir + "] R:R~2.4");
    DrawHLine("Fibo_TP_Partial",  g_lvl_tp_partial,  clrSteelBlue,   DoubleToString(Inp_PartialTP,3) + " - Parcial 50%");
    DrawHLine("Fibo_618",         g_lvl_618,         clrGold,        "0.618 - Entrada 1");
    DrawHLine("Fibo_786",         g_lvl_786,         clrOrange,      "0.786 - Entrada 2");
    DrawHLine("Fibo_1127",        g_lvl_1127,        clrRed,         "1.127 - Stop Loss");

    //--- Zona de entrada (retangulo visual entre 0.618 e 0.886)
    DrawEntryZone();

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Desenha um retangulo sombreado na zona de entrada                |
//+------------------------------------------------------------------+
void DrawEntryZone()
{
    string name = "Fibo_EntryZone";
    datetime t1 = iTime(_Symbol, PERIOD_CURRENT, Inp_SwingLookback);
    datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20;

    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, g_lvl_618, t2, g_lvl_786);

    ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
    ObjectSetDouble(0, name,  OBJPROP_PRICE, 0, g_lvl_618);
    ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
    ObjectSetDouble(0, name,  OBJPROP_PRICE, 1, g_lvl_786);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
    ObjectSetInteger(0, name, OBJPROP_FILL,  true);
    ObjectSetInteger(0, name, OBJPROP_BACK,  true);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetString(0, name,  OBJPROP_TOOLTIP, "Zona de Entrada: 0.618 ~ 0.786");
}

//+------------------------------------------------------------------+
//| Desenha uma linha horizontal com rotulo                          |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, string label)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

    ObjectSetDouble(0, name,  OBJPROP_PRICE,   price);
    ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
    ObjectSetString(0, name,  OBJPROP_TOOLTIP, label + " @ " + DoubleToString(price, _Digits));
    ObjectSetString(0, name,  OBJPROP_TEXT,    label);
}

//+------------------------------------------------------------------+
//| Remove todos os objetos criados pelo EA                          |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    string prefix = "Fibo_";
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, prefix) == 0)
            ObjectDelete(0, objName);
    }
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Exibe painel de informacoes no canto da tela                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE && Inp_DrawLevels)
    {
        CalculateFiboLevels();
        DrawFiboLevels();
    }
}
//+------------------------------------------------------------------+
