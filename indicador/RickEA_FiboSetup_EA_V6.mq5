//+------------------------------------------------------------------+
//|                                    RickEA_FiboSetup_EA_V6.mq5    |
//|                         Setup Fibonacci - RicharTrader           |
//|                                                                  |
//|  Entradas:    Fibonacci 0.618 / 0.786                            |
//|  Parcial 50%: Extensao  -0.272 (acima/abaixo do swing)           |
//|  Alvo final:  Extensao  -0.424                                   |
//|  Stop Loss:   Fibonacci  1.272                                   |
//|                                                                  |
//| v6 (mesmas entradas, stops e alvos da v5 - os .set continuam     |
//| valendo, os parametros antigos tem o mesmo nome):                |
//|  - Fibo AUTOMATICA ou MANUAL (arraste os pontos) + botao         |
//|    FIBO AUTO, igual ao RickEA FiboGrid                           |
//|  - Direcao: compras e vendas / so compras / so vendas            |
//|  - Uma ordem por vela (opcional) e maximo de ordens abertas      |
//|  - Take global, stop global e take por ciclo (em dinheiro)       |
//|  - Filtro de forca opcional (ADX e/ou RSI)                       |
//|  - Preco grande no canto superior esquerdo                       |
//|  - Painel so das ordens do robo: abertas, realizado e DD do dia, |
//|    da semana e do mes, RR do setup, acerto e payoff              |
//+------------------------------------------------------------------+
#property copyright "RicharTrader"
#property version   "6.00"
#property description "Setup Fibonacci: Entrada 0.618/0.786 | Parcial -0.272 | TP -0.424 | SL 1.272"
#property description "v6: Fibo auto/manual, direcao, take/stop global, take por ciclo, filtro de forca e painel"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- tipos novos da v6
enum ENUM_FIBOMODE
  {
   FIBO_AUTO   = 0, // Automatica (o robo acha o swing)
   FIBO_MANUAL = 1  // Manual (voce arrasta a Fibo no grafico)
  };

enum ENUM_TRADEDIR
  {
   DIR_BOTH      = 0, // Compras e vendas
   DIR_BUY_ONLY  = 1, // Somente compras
   DIR_SELL_ONLY = 2  // Somente vendas
  };

enum ENUM_FORCE
  {
   FORCE_OFF     = 0, // Desligado
   FORCE_ADX     = 1, // ADX (forca da tendencia)
   FORCE_RSI     = 2, // RSI (pullback)
   FORCE_ADX_RSI = 3  // ADX + RSI
  };

//--- Grupos de inputs (os da v5 com o MESMO nome e valor padrao)
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

input group "=== FIBO: AUTOMATICA OU MANUAL (v6) ==="
input ENUM_FIBOMODE Inp_FiboMode   = FIBO_AUTO; // Fibo: automatica ou manual (arrastar)
input bool          Inp_AutoButton = true;      // Manual: botao "FIBO AUTO" (leva a Fibo para o swing automatico)
input bool          Inp_SyncManual = true;      // Manual: ao mover a Fibo, mover SL/TP das ordens abertas

input group "=== DIRECAO E ENTRADA (v6) ==="
input ENUM_TRADEDIR Inp_TradeDir       = DIR_BOTH; // Direcao: compras e vendas, so compras ou so vendas
input bool          Inp_OneOrderPerBar = true;     // Uma ordem por vela
input int           Inp_MaxPositions   = 1;        // Maximo de ordens abertas ao mesmo tempo (1 = como a v5)

input group "=== FILTRO DE FORCA (opcional, v6) ==="
input ENUM_FORCE Inp_ForceFilter = FORCE_OFF; // Filtro de forca para a entrada
input int        Inp_ADXPeriod   = 14;        // ADX: periodo
input double     Inp_ADXMin      = 20.0;      // ADX: minimo para entrar
input bool       Inp_ADXUseDI    = false;     // ADX: exigir +DI > -DI na compra (e o contrario na venda)
input int        Inp_RSIPeriod   = 14;        // RSI: periodo
input double     Inp_RSIBuyMax   = 50.0;      // RSI: compra so com RSI ate este valor (pullback)
input double     Inp_RSISellMin  = 50.0;      // RSI: venda so com RSI a partir deste valor

input group "=== TAKE / STOP GLOBAL E CICLO (dinheiro, 0 = OFF, v6) ==="
input double Inp_GlobalTP          = 0.0;  // Take global: fecha tudo quando o flutuante das ordens >= valor
input double Inp_GlobalSL          = 0.0;  // Stop global: fecha tudo quando o flutuante <= -valor
input double Inp_CycleTP           = 0.0;  // Take por ciclo: realizado no ciclo + flutuante >= valor
input bool   Inp_BlockLegAfterClose= true; // Depois do take/stop global ou do ciclo, nao reentrar no mesmo swing

input group "=== VISUAL (v6) ==="
input bool   Inp_BigPrice       = true;     // Preco grande no canto superior esquerdo
input int    Inp_BigPriceSize   = 28;       // Tamanho da fonte do preco grande
input bool   Inp_ShowPanel      = true;     // Painel das ordens do robo
input int    Inp_PanelFontSize  = 9;        // Tamanho da fonte do painel
input color  Inp_BuyClr         = clrLime;  // Cor de compra / alta
input color  Inp_SellClr        = clrRed;   // Cor de venda / baixa

//--- pernada (swing)
struct SLeg
  {
   bool     ok;
   bool     bull;   // true = impulso de alta (compra na retracao)
   double   hi;
   double   lo;
   datetime tHi;
   datetime tLo;
  };

//--- Objetos globais
CTrade         g_trade;
CPositionInfo  g_pos;

//--- Variaveis de estado (v5)
double g_swingHigh    = 0;
double g_swingLow     = 0;
bool   g_isBullish    = false;
bool   g_isBearish    = false;
datetime g_lastSignalTime = 0;

//--- Niveis de entrada (retracoes)
double g_lvl_618  = 0;
double g_lvl_786  = 0;
double g_lvl_1127 = 0;

//--- Niveis de saida (extensoes)
double g_lvl_tp_partial = 0;
double g_lvl_tp_final   = 0;

//--- Controle diario
int    g_tradesToday     = 0;
double g_balanceDayStart = 0;
datetime g_lastDayCheck  = 0;
bool   g_dailyAlertDone  = false;

//--- v6
string   MFIB          = "FSM_FIBO";   // Fibo manual (fora do prefixo "Fibo_" para sobreviver a troca de tempo grafico)
SLeg     g_leg;                        // swing em uso
bool     g_closing     = false;        // pediu para fechar tudo, esperando zerar
datetime g_cycleStart  = 0;            // inicio do ciclo aberto (0 = sem ciclo)
bool     g_blockOn     = false;        // swing bloqueado depois de take/stop global ou ciclo
bool     g_blockBull   = false;
double   g_blockHi     = 0;
double   g_blockLo     = 0;
int      g_hADX        = INVALID_HANDLE;
int      g_hRSI        = INVALID_HANDLE;
string   g_status      = "Iniciando...";
color    g_statusClr   = clrSilver;
string   g_forceTxt    = "desligado";

//--- estatisticas (so ordens deste robo neste simbolo)
datetime g_statTime    = 0;
double   g_real[3];                    // realizado: 0 dia, 1 semana, 2 mes
double   g_cum[3];                     // curva acumulada do periodo
double   g_peak[3];                    // pico da curva do periodo
double   g_ddHist[3];                  // maior DD fechado do periodo
int      g_trWins = 0, g_trLoss = 0;
double   g_sumWin = 0, g_sumLoss = 0;

//+------------------------------------------------------------------+
//| Inicializacao                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    if(Inp_MaxPositions < 1)
    {
        Print("FiboSetup V6: Inp_MaxPositions tem que ser pelo menos 1.");
        return(INIT_PARAMETERS_INCORRECT);
    }

    g_trade.SetExpertMagicNumber(Inp_MagicNumber);
    g_trade.SetDeviationInPoints(20);
    g_trade.SetTypeFilling(ORDER_FILLING_RETURN);  // RETURN: compativel com todos os brokers
    g_trade.LogLevel(LOG_LEVEL_ERRORS);

    g_balanceDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
    g_lastDayCheck    = TimeCurrent();

    if(Inp_ForceFilter == FORCE_ADX || Inp_ForceFilter == FORCE_ADX_RSI)
    {
        g_hADX = iADX(_Symbol, PERIOD_CURRENT, Inp_ADXPeriod);
        if(g_hADX == INVALID_HANDLE) { Print("FiboSetup V6: falha ao criar o ADX."); return(INIT_FAILED); }
    }
    if(Inp_ForceFilter == FORCE_RSI || Inp_ForceFilter == FORCE_ADX_RSI)
    {
        g_hRSI = iRSI(_Symbol, PERIOD_CURRENT, Inp_RSIPeriod, PRICE_CLOSE);
        if(g_hRSI == INVALID_HANDLE) { Print("FiboSetup V6: falha ao criar o RSI."); return(INIT_FAILED); }
    }

    g_leg.ok = false;
    if(Inp_FiboMode == FIBO_MANUAL)
    {
        ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);   // avisa se a Fibo for apagada
        CreateManual();
        if(Inp_AutoButton)
            AutoButton();
        Print("FiboSetup V6: modo MANUAL - arraste os dois pontos da Fibo (1.0 = origem do swing, 0.0 = extremo).");
    }

    g_cycleStart = OldestOpenTime();          // ciclo que ja estava aberto (restart / troca de tempo grafico)
    g_statTime   = 0;
    UpdateLeg(true, CountPositions());
    if(Inp_DrawLevels)
        DrawFiboLevels();
    DrawVisual();

    Print("FiboSetup EA V6 iniciado | Magic: ", Inp_MagicNumber,
          " | Auto: ", Inp_TradeAuto,
          " | Fibo: ", (Inp_FiboMode == FIBO_MANUAL ? "MANUAL" : "AUTO"),
          " | Direcao: ", DirName(),
          " | TP: ", Inp_FullTP, " | SL: ", Inp_StopLoss,
          " | MaxLoss: ", Inp_MaxDailyLossPct, "% | Meta: ", Inp_MaxDailyProfitPct, "%");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Limpeza                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_hADX != INVALID_HANDLE) IndicatorRelease(g_hADX);
    if(g_hRSI != INVALID_HANDLE) IndicatorRelease(g_hRSI);
    DeleteAllObjects();
    if(reason == REASON_REMOVE)       // tirou o robo do grafico: apaga a Fibo manual tambem
        ObjectDelete(0, MFIB);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Loop principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool newBar = (currentBar != lastBar);
    if(newBar) lastBar = currentBar;

    //--- ciclo: comeca na 1a ordem e termina quando zera
    int cnt = CountPositions();
    if(cnt > 0 && g_cycleStart == 0)
        g_cycleStart = OldestOpenTime();
    if(cnt == 0)
    {
        g_cycleStart = 0;
        g_closing    = false;
    }

    //--- swing e niveis
    bool changed = UpdateLeg(newBar, cnt);
    if(Inp_DrawLevels && (newBar || changed))
        DrawFiboLevels();

    //--- take/stop global e take por ciclo
    CheckGlobalAndCycle(cnt);

    //--- entradas e gestao das ordens
    if(!g_closing)
    {
        CheckForEntry();
        ManagePositions();
    }
    else
        SetStatus("Fechando as ordens...", clrOrange);

    DrawVisual();
}

//+------------------------------------------------------------------+
//| Atualiza o swing: manual (le o objeto) ou automatico             |
//| Retorna true se o swing mudou                                    |
//+------------------------------------------------------------------+
bool UpdateLeg(bool newBar, int cnt)
{
    SLeg l;
    l.ok = false;

    if(Inp_FiboMode == FIBO_MANUAL)
    {
        if(ObjectFind(0, MFIB) < 0)
            CreateManual();
        if(!ReadManual(l))
        {
            bool had = g_leg.ok;
            g_leg.ok = false;
            return(had);
        }
        if(g_leg.ok && SameLeg(l, g_leg))
            return(false);
        g_leg = l;
        ApplyLeg();
        if(cnt > 0 && Inp_SyncManual)
            SyncStops();                     // Fibo movida: SL e alvo acompanham
        return(true);
    }

    //--- automatico: com ordem aberta o swing fica travado (parcial e alvo nao mudam no meio do trade)
    if(cnt > 0 && g_leg.ok)
        return(false);
    if(!newBar && g_leg.ok)
        return(false);
    if(!FindLegAuto(l))
        return(false);
    bool mudou = !(g_leg.ok && SameLeg(l, g_leg));
    g_leg = l;
    ApplyLeg();
    return(mudou);
}

bool SameLeg(const SLeg &a, const SLeg &b)
{
    double pt = _Point / 2.0;
    return(a.bull == b.bull && MathAbs(a.hi - b.hi) < pt && MathAbs(a.lo - b.lo) < pt);
}

//--- copia o swing para as variaveis da v5 e recalcula os niveis
void ApplyLeg()
{
    g_swingHigh = g_leg.hi;
    g_swingLow  = g_leg.lo;
    g_isBullish = g_leg.bull;
    g_isBearish = !g_leg.bull;
    CalculateFiboLevels();
}

//+------------------------------------------------------------------+
//| Swing automatico (mesma regra da v5)                             |
//+------------------------------------------------------------------+
bool FindLegAuto(SLeg &leg)
{
    leg.ok = false;
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

    if(highPrice == 0 || lowPrice == DBL_MAX || highPrice <= lowPrice) return(false);

    //--- Bullish setup: low formado ANTES do high (impulso de alta, agora retraindo para compra)
    //--- Bearish setup: high formado ANTES do low (impulso de baixa, agora retraindo para venda)
    leg.hi   = highPrice;
    leg.lo   = lowPrice;
    leg.tHi  = iTime(_Symbol, PERIOD_CURRENT, highBar);
    leg.tLo  = iTime(_Symbol, PERIOD_CURRENT, lowBar);
    leg.bull = (lowBar > highBar);
    leg.ok   = true;
    return(true);
}

//+------------------------------------------------------------------+
//| Calcula os precos dos niveis de Fibonacci (igual a v5)           |
//+------------------------------------------------------------------+
void CalculateFiboLevels()
{
    if(g_swingHigh == 0 || g_swingLow == 0) return;

    double range = g_swingHigh - g_swingLow;
    if(range <= 0) return;

    if(g_isBullish)
    {
        g_lvl_618  = g_swingHigh - range * Inp_Entry1;
        g_lvl_786  = g_swingHigh - range * Inp_Entry2;
        g_lvl_1127 = g_swingHigh - range * Inp_StopLoss;

        g_lvl_tp_partial = (Inp_PartialTP < 0)
            ? g_swingHigh + range * MathAbs(Inp_PartialTP)
            : g_swingHigh - range * Inp_PartialTP;
        g_lvl_tp_final = (Inp_FullTP < 0)
            ? g_swingHigh + range * MathAbs(Inp_FullTP)
            : g_swingHigh - range * Inp_FullTP;
    }
    else
    {
        g_lvl_618  = g_swingLow + range * Inp_Entry1;
        g_lvl_786  = g_swingLow + range * Inp_Entry2;
        g_lvl_1127 = g_swingLow + range * Inp_StopLoss;

        g_lvl_tp_partial = (Inp_PartialTP < 0)
            ? g_swingLow - range * MathAbs(Inp_PartialTP)
            : g_swingLow + range * Inp_PartialTP;
        g_lvl_tp_final = (Inp_FullTP < 0)
            ? g_swingLow - range * MathAbs(Inp_FullTP)
            : g_swingLow + range * Inp_FullTP;
    }
}

//+------------------------------------------------------------------+
//| Verifica se ha sinal de entrada (gatilho da v5 + filtros da v6)  |
//+------------------------------------------------------------------+
void CheckForEntry()
{
    if(!g_leg.ok || g_swingHigh == 0 || g_swingLow == 0)
    {
        SetStatus(Inp_FiboMode == FIBO_MANUAL ? "Fibo manual pequena demais: afaste os pontos" : "Procurando swing", clrSilver);
        return;
    }
    if(g_lvl_618 == 0 || g_lvl_tp_final == 0) return;

    //--- Limites diarios
    CheckDailyReset();
    if(g_tradesToday >= Inp_MaxTradesPerDay)
    {
        SetStatus("Limite de " + IntegerToString(Inp_MaxTradesPerDay) + " trades do dia atingido", clrOrange);
        return;
    }

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(g_balanceDayStart > 0)
    {
        double pnlPct = (balance - g_balanceDayStart) / g_balanceDayStart * 100.0;
        if(pnlPct <= -Inp_MaxDailyLossPct)
        {
            if(Inp_SendAlerts && !g_dailyAlertDone)
                Alert("STOP DIARIO: -", Inp_MaxDailyLossPct, "% atingido. EA pausado.");
            g_dailyAlertDone = true;
            SetStatus("Stop diario atingido - pausado ate amanha", clrRed);
            return;
        }
        if(pnlPct >= Inp_MaxDailyProfitPct)
        {
            if(Inp_SendAlerts && !g_dailyAlertDone)
                Alert("META DIARIA: +", Inp_MaxDailyProfitPct, "% atingida. EA pausado.");
            g_dailyAlertDone = true;
            SetStatus("Meta diaria atingida - pausado ate amanha", Inp_BuyClr);
            return;
        }
    }

    //--- Uma ordem por vela
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(Inp_OneOrderPerBar && currentBar == g_lastSignalTime)
    {
        SetStatus("Aguardando a proxima vela", clrSilver);
        return;
    }

    //--- Maximo de ordens abertas
    if(CountPositions() >= Inp_MaxPositions)
    {
        SetStatus("Ordem aberta - gerenciando parcial, breakeven e alvo", clrWhite);
        return;
    }

    if(IsBlocked())
    {
        SetStatus("Swing bloqueado (take/stop global ou ciclo) - esperando novo swing", clrOrange);
        return;
    }

    if(!DirAllowed(g_isBullish))
    {
        SetStatus("Swing de " + (g_isBullish ? "COMPRA" : "VENDA") + " ignorado: " + DirName(), clrGray);
        return;
    }

    double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double zone  = Inp_ZonePoints * point;
    string e1    = DoubleToString(Inp_Entry1, 3);
    string e2    = DoubleToString(Inp_Entry2, 3);

    if(g_isBullish)
    {
        if(ask <= g_lvl_1127 || ask >= g_swingHigh)
        {
            SetStatus("Preco fora do setup de compra", clrSilver);
            return;
        }

        string lvlName = "";
        if(MathAbs(ask - g_lvl_618) <= zone && !HasLevelOpen(e1))      lvlName = e1;
        else if(MathAbs(ask - g_lvl_786) <= zone && !HasLevelOpen(e2)) lvlName = e2;
        if(lvlName == "")
        {
            SetStatus("Aguardando retracao de COMPRA em " + e1 + " / " + e2, Inp_BuyClr);
            return;
        }
        if(!ForceOK(true))
        {
            SetStatus("COMPRA em " + lvlName + " barrada pelo filtro de forca", clrOrange);
            return;
        }

        double entryPrice = ask;
        double sl         = g_lvl_1127;
        double tp         = g_lvl_tp_final;

        SendSignalAlert("COMPRA", lvlName, entryPrice, sl, tp, g_lvl_tp_partial);

        if(Inp_TradeAuto)
        {
            if(g_trade.Buy(Inp_LotSize, _Symbol, entryPrice, sl, tp, "FiboSetup BUY @" + lvlName))
            {
                g_lastSignalTime = currentBar;
                g_tradesToday++;
                if(g_cycleStart == 0) g_cycleStart = TimeCurrent();
                Print("COMPRA aberta | Entrada: ", entryPrice, " | SL: ", sl, " | TP: ", tp,
                      " | Parcial: ", g_lvl_tp_partial, " | Fibo: ", lvlName);
            }
        }
        else
            g_lastSignalTime = currentBar;      // so alerta: um aviso por vela
    }
    else if(g_isBearish)
    {
        if(bid >= g_lvl_1127 || bid <= g_swingLow)
        {
            SetStatus("Preco fora do setup de venda", clrSilver);
            return;
        }

        string lvlName = "";
        if(MathAbs(bid - g_lvl_618) <= zone && !HasLevelOpen(e1))      lvlName = e1;
        else if(MathAbs(bid - g_lvl_786) <= zone && !HasLevelOpen(e2)) lvlName = e2;
        if(lvlName == "")
        {
            SetStatus("Aguardando retracao de VENDA em " + e1 + " / " + e2, Inp_SellClr);
            return;
        }
        if(!ForceOK(false))
        {
            SetStatus("VENDA em " + lvlName + " barrada pelo filtro de forca", clrOrange);
            return;
        }

        double entryPrice = bid;
        double sl         = g_lvl_1127;
        double tp         = g_lvl_tp_final;

        SendSignalAlert("VENDA", lvlName, entryPrice, sl, tp, g_lvl_tp_partial);

        if(Inp_TradeAuto)
        {
            if(g_trade.Sell(Inp_LotSize, _Symbol, entryPrice, sl, tp, "FiboSetup SELL @" + lvlName))
            {
                g_lastSignalTime = currentBar;
                g_tradesToday++;
                if(g_cycleStart == 0) g_cycleStart = TimeCurrent();
                Print("VENDA aberta | Entrada: ", entryPrice, " | SL: ", sl, " | TP: ", tp,
                      " | Parcial: ", g_lvl_tp_partial, " | Fibo: ", lvlName);
            }
        }
        else
            g_lastSignalTime = currentBar;
    }
}

//+------------------------------------------------------------------+
//| Gerencia posicoes abertas (parcial e breakeven, como na v5)      |
//| Cada ordem e tratada pelo proprio volume: se ja esta menor que o |
//| lote de entrada, a parcial ja foi feita.                         |
//+------------------------------------------------------------------+
void ManagePositions()
{
    double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double volMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_pos.SelectByIndex(i)) continue;
        if(g_pos.Magic() != Inp_MagicNumber) continue;
        if(g_pos.Symbol() != _Symbol) continue;

        ENUM_POSITION_TYPE posType = g_pos.PositionType();
        double vol         = g_pos.Volume();
        bool   partialDone = (vol < Inp_LotSize - volStep / 2.0);

        //--- Fechamento parcial na extensao
        if(!partialDone && g_lvl_tp_partial > 0)
        {
            bool hitPartial = false;
            if(posType == POSITION_TYPE_BUY  && bid >= g_lvl_tp_partial) hitPartial = true;
            if(posType == POSITION_TYPE_SELL && ask <= g_lvl_tp_partial) hitPartial = true;

            if(hitPartial)
            {
                double lotToClose = NormalizeVolume(vol * Inp_PartialPercent / 100.0, volMin, volStep);

                if(lotToClose >= volMin && (vol - lotToClose) >= volMin)
                {
                    if(g_trade.PositionClosePartial(g_pos.Ticket(), lotToClose))
                    {
                        partialDone = true;
                        Print("PARCIAL FECHADA | ", lotToClose, " lotes @ extensao ",
                              Inp_PartialTP, " = ", DoubleToString(g_lvl_tp_partial, _Digits));
                        if(Inp_SendAlerts)
                            Alert("PARCIAL ", DoubleToString(Inp_PartialPercent, 0), "% | ", _Symbol, " | Extensao ",
                                  Inp_PartialTP, " @ ", DoubleToString(g_lvl_tp_partial, _Digits));
                    }
                }
                else
                {
                    g_trade.PositionClose(g_pos.Ticket());
                    Print("Posicao fechada totalmente (volume insuficiente para parcial)");
                    continue;
                }
            }
        }

        //--- Mover SL para breakeven apos parcial
        if(partialDone && Inp_Breakeven && g_pos.SelectByTicket(g_pos.Ticket()))
        {
            double entryPrice = g_pos.PriceOpen();
            double currentSL  = g_pos.StopLoss();

            bool shouldMove = false;
            if(posType == POSITION_TYPE_BUY  && currentSL < entryPrice - point) shouldMove = true;
            if(posType == POSITION_TYPE_SELL && (currentSL > entryPrice + point || currentSL == 0)) shouldMove = true;

            if(shouldMove)
            {
                if(g_trade.PositionModify(g_pos.Ticket(), entryPrice, g_pos.TakeProfit()))
                    Print("BREAKEVEN ativado | SL movido para entrada: ", DoubleToString(entryPrice, _Digits));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Take global, stop global e take por ciclo                        |
//+------------------------------------------------------------------+
void CheckGlobalAndCycle(int cnt)
{
    if(cnt == 0 || g_closing)
        return;

    double fl = Floating();
    string cur = AccountInfoString(ACCOUNT_CURRENCY);

    if(Inp_GlobalTP > 0 && fl >= Inp_GlobalTP)
    {
        CloseAll("TAKE GLOBAL (" + DoubleToString(fl, 2) + " " + cur + ")");
        return;
    }
    if(Inp_GlobalSL > 0 && fl <= -Inp_GlobalSL)
    {
        CloseAll("STOP GLOBAL (" + DoubleToString(fl, 2) + " " + cur + ")");
        return;
    }
    if(Inp_CycleTP > 0 && g_cycleStart > 0)
    {
        double total = RealizedSince(g_cycleStart) + fl;
        if(total >= Inp_CycleTP)
            CloseAll("TAKE DO CICLO (" + DoubleToString(total, 2) + " " + cur + ")");
    }
}

void CloseAll(string why)
{
    g_closing = true;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_pos.SelectByIndex(i)) continue;
        if(g_pos.Magic() != Inp_MagicNumber || g_pos.Symbol() != _Symbol) continue;
        if(!g_trade.PositionClose(g_pos.Ticket()))
            Print("Falha ao fechar #", g_pos.Ticket(), " (", g_trade.ResultRetcode(), ") ", g_trade.ResultRetcodeDescription());
    }
    if(Inp_BlockLegAfterClose && g_leg.ok)
    {
        g_blockOn   = true;
        g_blockBull = g_leg.bull;
        g_blockHi   = g_leg.hi;
        g_blockLo   = g_leg.lo;
    }
    Print(why, " - fechando todas as ordens do FiboSetup.");
    if(Inp_SendAlerts)
        Alert("FiboSetup ", _Symbol, ": ", why, " - ordens encerradas.");
    g_statTime = 0;
}

bool IsBlocked()
{
    if(!g_blockOn || !g_leg.ok)
        return(false);
    double pt = _Point / 2.0;
    return(g_leg.bull == g_blockBull && MathAbs(g_leg.hi - g_blockHi) < pt && MathAbs(g_leg.lo - g_blockLo) < pt);
}

//+------------------------------------------------------------------+
//| Filtros                                                          |
//+------------------------------------------------------------------+
bool DirAllowed(bool buy)
{
    if(Inp_TradeDir == DIR_BUY_ONLY)  return(buy);
    if(Inp_TradeDir == DIR_SELL_ONLY) return(!buy);
    return(true);
}

string DirName()
{
    if(Inp_TradeDir == DIR_BUY_ONLY)  return("SOMENTE COMPRAS");
    if(Inp_TradeDir == DIR_SELL_ONLY) return("SOMENTE VENDAS");
    return("COMPRAS E VENDAS");
}

double BufferValue(int handle, int buffer, int shift)
{
    double b[1];
    if(handle == INVALID_HANDLE || CopyBuffer(handle, buffer, shift, 1, b) != 1)
        return(EMPTY_VALUE);
    return(b[0]);
}

//--- filtro de forca no candle fechado (atualiza o texto do painel)
bool ForceOK(bool buy)
{
    if(Inp_ForceFilter == FORCE_OFF)
    {
        g_forceTxt = "desligado";
        return(true);
    }
    bool   ok  = true;
    string txt = "";

    if(Inp_ForceFilter == FORCE_ADX || Inp_ForceFilter == FORCE_ADX_RSI)
    {
        double adx = BufferValue(g_hADX, 0, 1);
        double pdi = BufferValue(g_hADX, 1, 1);
        double mdi = BufferValue(g_hADX, 2, 1);
        if(adx == EMPTY_VALUE) return(false);
        bool okA = (adx >= Inp_ADXMin);
        if(Inp_ADXUseDI)
            okA = okA && (buy ? pdi > mdi : mdi > pdi);
        txt += "ADX " + DoubleToString(adx, 1) + (Inp_ADXUseDI ? " +DI " + DoubleToString(pdi, 1) + " -DI " + DoubleToString(mdi, 1) : "")
               + (okA ? " OK" : " FRACO") + "  ";
        ok = ok && okA;
    }
    if(Inp_ForceFilter == FORCE_RSI || Inp_ForceFilter == FORCE_ADX_RSI)
    {
        double rsi = BufferValue(g_hRSI, 0, 1);
        if(rsi == EMPTY_VALUE) return(false);
        bool okR = buy ? (rsi <= Inp_RSIBuyMax) : (rsi >= Inp_RSISellMin);
        txt += "RSI " + DoubleToString(rsi, 1) + (okR ? " OK" : " FORA");
        ok = ok && okR;
    }
    g_forceTxt = txt;
    return(ok);
}

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
        g_dailyAlertDone  = false;
        Print("Reset diario | Balance inicial: ", g_balanceDayStart);
    }
}

//+------------------------------------------------------------------+
//| Ordens deste EA                                                  |
//+------------------------------------------------------------------+
int CountPositions()
{
    int n = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(g_pos.SelectByIndex(i) && g_pos.Magic() == Inp_MagicNumber && g_pos.Symbol() == _Symbol)
            n++;
    return(n);
}

bool HasOpenPosition()
{
    return(CountPositions() > 0);
}

//--- ja existe ordem aberta neste nivel? (com mais de uma ordem permitida, cada nivel entra uma vez)
bool HasLevelOpen(string lvlName)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(g_pos.SelectByIndex(i) && g_pos.Magic() == Inp_MagicNumber && g_pos.Symbol() == _Symbol &&
           StringFind(g_pos.Comment(), "@" + lvlName) >= 0)
            return(true);
    return(false);
}

double Floating()
{
    double p = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(g_pos.SelectByIndex(i) && g_pos.Magic() == Inp_MagicNumber && g_pos.Symbol() == _Symbol)
            p += g_pos.Profit() + g_pos.Swap();
    return(p);
}

datetime OldestOpenTime()
{
    datetime t = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(g_pos.SelectByIndex(i) && g_pos.Magic() == Inp_MagicNumber && g_pos.Symbol() == _Symbol)
            if(t == 0 || g_pos.Time() < t)
                t = g_pos.Time();
    return(t);
}

//--- lucro realizado (deals deste EA) desde um horario
double RealizedSince(datetime from)
{
    double total = 0;
    if(!HistorySelect(from, TimeCurrent() + 60))
        return(0);
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong d = HistoryDealGetTicket(i);
        if(d == 0) continue;
        if(HistoryDealGetInteger(d, DEAL_MAGIC) != Inp_MagicNumber) continue;
        if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
        total += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                 HistoryDealGetDouble(d, DEAL_COMMISSION);
    }
    return(total);
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
        "Stop Loss: %s (Fibo %.3f)\n"
        "Parcial %.0f%%: %s (Fibo %.3f)\n"
        "Alvo Final: %s (Fibo %.3f)\n"
        "R/R: 1:%.2f",
        direction, _Symbol, fiboLevel,
        DoubleToString(entry, _Digits),
        DoubleToString(sl, _Digits), Inp_StopLoss,
        Inp_PartialPercent, DoubleToString(partial, _Digits), Inp_PartialTP,
        DoubleToString(tp, _Digits), Inp_FullTP,
        rr
    );

    Alert(msg);
    Print(msg);
}

void SetStatus(string txt, color clr)
{
    g_status    = txt;
    g_statusClr = clr;
}

//+------------------------------------------------------------------+
//| FIBO MANUAL (mesma pegada do RickEA FiboGrid)                    |
//| Ponto 1 do objeto = origem do swing (1.0), ponto 2 = extremo (0) |
//+------------------------------------------------------------------+
bool ReadManual(SLeg &leg)
{
    leg.ok = false;
    if(ObjectFind(0, MFIB) < 0)
        return(false);
    datetime t0 = (datetime)ObjectGetInteger(0, MFIB, OBJPROP_TIME, 0);
    double   p0 = ObjectGetDouble(0, MFIB, OBJPROP_PRICE, 0);
    datetime t1 = (datetime)ObjectGetInteger(0, MFIB, OBJPROP_TIME, 1);
    double   p1 = ObjectGetDouble(0, MFIB, OBJPROP_PRICE, 1);
    if(p0 <= 0.0 || p1 <= 0.0 || MathAbs(p1 - p0) < 10 * _Point)
        return(false);
    leg.bull = (p1 > p0);                 // extremo acima da origem = impulso de alta
    leg.hi   = MathMax(p0, p1);
    leg.lo   = MathMin(p0, p1);
    leg.tHi  = leg.bull ? t1 : t0;
    leg.tLo  = leg.bull ? t0 : t1;
    leg.ok   = true;
    return(true);
}

//--- cria a Fibo manual (se ainda nao existe) no swing automatico
void CreateManual()
{
    if(ObjectFind(0, MFIB) >= 0)
        return;                            // ja existe: mantem onde voce deixou
    SLeg a;
    a.ok = false;
    if(!FindLegAuto(a))
        return;
    datetime tBase = a.bull ? a.tLo : a.tHi;
    double   pBase = a.bull ? a.lo  : a.hi;
    datetime tExt  = a.bull ? a.tHi : a.tLo;
    double   pExt  = a.bull ? a.hi  : a.lo;
    if(!ObjectCreate(0, MFIB, OBJ_FIBO, 0, tBase, pBase, tExt, pExt))
    {
        Print("FiboSetup V6: nao foi possivel criar a Fibo manual (", GetLastError(), ").");
        return;
    }
    ObjectSetInteger(0, MFIB, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, MFIB, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, MFIB, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, MFIB, OBJPROP_BACK, false);
    ObjectSetInteger(0, MFIB, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, MFIB, OBJPROP_WIDTH, 2);
    ObjectSetString(0, MFIB, OBJPROP_TOOLTIP, "Fibo do RickEA FiboSetup: arraste os pontos");

    //--- os niveis do setup (entradas, stop, parcial e alvo)
    double vals[7];
    string txts[7];
    vals[0] = 0.0;           txts[0] = "0.0 Swing";
    vals[1] = Inp_Entry1;    txts[1] = DoubleToString(Inp_Entry1, 3) + " Entrada 1";
    vals[2] = Inp_Entry2;    txts[2] = DoubleToString(Inp_Entry2, 3) + " Entrada 2";
    vals[3] = 1.0;           txts[3] = "1.0 Origem";
    vals[4] = Inp_StopLoss;  txts[4] = DoubleToString(Inp_StopLoss, 3) + " STOP";
    vals[5] = Inp_PartialTP; txts[5] = DoubleToString(Inp_PartialTP, 3) + " Parcial";
    vals[6] = Inp_FullTP;    txts[6] = DoubleToString(Inp_FullTP, 3) + " ALVO";
    ObjectSetInteger(0, MFIB, OBJPROP_LEVELS, 7);
    for(int i = 0; i < 7; i++)
    {
        ObjectSetDouble(0, MFIB, OBJPROP_LEVELVALUE, i, vals[i]);
        ObjectSetString(0, MFIB, OBJPROP_LEVELTEXT, i, txts[i] + "  %$");
        ObjectSetInteger(0, MFIB, OBJPROP_LEVELSTYLE, i, (i == 0 || i == 3) ? STYLE_SOLID : STYLE_DOT);
        ObjectSetInteger(0, MFIB, OBJPROP_LEVELWIDTH, i, 1);
    }
    StyleManual(a.bull);
}

void PlaceManual(const SLeg &a)
{
    if(ObjectFind(0, MFIB) < 0)
        return;
    ObjectMove(0, MFIB, 0, a.bull ? a.tLo : a.tHi, a.bull ? a.lo : a.hi);
    ObjectMove(0, MFIB, 1, a.bull ? a.tHi : a.tLo, a.bull ? a.hi : a.lo);
    StyleManual(a.bull);
}

//--- cor da Fibo manual pela direcao (cinza se a direcao estiver desligada)
void StyleManual(bool bull)
{
    if(ObjectFind(0, MFIB) < 0)
        return;
    color clr = bull ? Inp_BuyClr : Inp_SellClr;
    if(!DirAllowed(bull))
        clr = clrGray;
    ObjectSetInteger(0, MFIB, OBJPROP_COLOR, clr);
    int n = (int)ObjectGetInteger(0, MFIB, OBJPROP_LEVELS);
    for(int i = 0; i < n; i++)
    {
        color lc = clr;
        if(i == 4) lc = clrRed;            // stop
        if(i == 6) lc = clrDodgerBlue;     // alvo
        ObjectSetInteger(0, MFIB, OBJPROP_LEVELCOLOR, i, lc);
    }
}

//--- botao FIBO AUTO: leva a Fibo manual para o swing automatico
void SnapManualToAuto()
{
    SLeg a;
    a.ok = false;
    if(!FindLegAuto(a))
    {
        Print("FiboSetup V6: nenhum swing automatico agora - a Fibo manual ficou onde estava.");
        return;
    }
    if(ObjectFind(0, MFIB) < 0)
        CreateManual();
    PlaceManual(a);
    Print("FiboSetup V6: Fibo manual reposicionada no swing automatico.");
}

void AutoButton()
{
    string n = "Fibo_BTN_AUTO";
    if(ObjectFind(0, n) < 0)
    {
        ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, n, OBJPROP_XDISTANCE, 12);
        ObjectSetInteger(0, n, OBJPROP_YDISTANCE, 40);
        ObjectSetInteger(0, n, OBJPROP_XSIZE, 110);
        ObjectSetInteger(0, n, OBJPROP_YSIZE, 24);
        ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
        ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
    }
    ObjectSetString(0, n, OBJPROP_TEXT, "FIBO AUTO");
    ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'40,60,95');
    ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrSilver);
    ObjectSetInteger(0, n, OBJPROP_STATE, false);
}

//--- Fibo manual movida com ordem aberta: leva SL e alvo para os niveis novos
void SyncStops()
{
    double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_pos.SelectByIndex(i)) continue;
        if(g_pos.Magic() != Inp_MagicNumber || g_pos.Symbol() != _Symbol) continue;

        bool   buy = (g_pos.PositionType() == POSITION_TYPE_BUY);
        double sl  = NormalizeDouble(g_lvl_1127, _Digits);
        double tp  = NormalizeDouble(g_lvl_tp_final, _Digits);
        bool   be  = Inp_Breakeven && (g_pos.Volume() < Inp_LotSize - volStep / 2.0);
        if(be) sl = g_pos.StopLoss();       // depois da parcial o stop fica no breakeven

        double ref = buy ? bid : ask;
        bool okSL = buy ? (sl < ref - minDist) : (sl > ref + minDist);
        bool okTP = buy ? (tp > ref + minDist) : (tp < ref - minDist);
        if(!okSL || !okTP)
            continue;                        // Fibo do lado errado do preco: mantem os niveis antigos
        if(MathAbs(sl - g_pos.StopLoss()) < _Point / 2.0 && MathAbs(tp - g_pos.TakeProfit()) < _Point / 2.0)
            continue;
        if(!g_trade.PositionModify(g_pos.Ticket(), sl, tp))
            Print("FiboSetup V6: falha ao mover SL/TP #", g_pos.Ticket(), " (", g_trade.ResultRetcode(), ")");
    }
}

//+------------------------------------------------------------------+
//| Desenha os niveis de Fibonacci (v5) - no modo manual a propria   |
//| Fibo mostra os niveis, entao so a zona de entrada e desenhada    |
//+------------------------------------------------------------------+
void DrawFiboLevels()
{
    if(!g_leg.ok || g_swingHigh == 0 || g_swingLow == 0)
    {
        ObjectsDeleteAll(0, "Fibo_SwingHigh");
        ObjectsDeleteAll(0, "Fibo_SwingLow");
        ObjectsDeleteAll(0, "Fibo_TP_");
        ObjectsDeleteAll(0, "Fibo_618");
        ObjectsDeleteAll(0, "Fibo_786");
        ObjectsDeleteAll(0, "Fibo_1127");
        ObjectsDeleteAll(0, "Fibo_EntryZone");
        ChartRedraw();
        return;
    }

    string dir = g_isBullish ? "BUY" : "SELL";

    if(Inp_FiboMode == FIBO_AUTO)
    {
        DrawHLine("Fibo_SwingHigh",   g_swingHigh,       clrLime,        "0.000 - Swing High");
        DrawHLine("Fibo_SwingLow",    g_swingLow,        clrLime,        "1.000 - Swing Low");
        DrawHLine("Fibo_TP_Final",    g_lvl_tp_final,    clrDodgerBlue,  DoubleToString(Inp_FullTP,3) + " - Alvo Final [" + dir + "]");
        DrawHLine("Fibo_TP_Partial",  g_lvl_tp_partial,  clrSteelBlue,   DoubleToString(Inp_PartialTP,3) + " - Parcial");
        DrawHLine("Fibo_618",         g_lvl_618,         clrGold,        DoubleToString(Inp_Entry1,3) + " - Entrada 1");
        DrawHLine("Fibo_786",         g_lvl_786,         clrOrange,      DoubleToString(Inp_Entry2,3) + " - Entrada 2");
        DrawHLine("Fibo_1127",        g_lvl_1127,        clrRed,         DoubleToString(Inp_StopLoss,3) + " - Stop Loss");
    }
    else
        StyleManual(g_isBullish);

    DrawEntryZone();
    ChartRedraw();
}

void DrawEntryZone()
{
    string name = "Fibo_EntryZone";
    datetime t1 = (Inp_FiboMode == FIBO_MANUAL) ? (datetime)MathMin((long)g_leg.tHi, (long)g_leg.tLo)
                                                : iTime(_Symbol, PERIOD_CURRENT, Inp_SwingLookback);
    datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20;

    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, g_lvl_618, t2, g_lvl_786);

    ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
    ObjectSetDouble(0, name,  OBJPROP_PRICE, 0, g_lvl_618);
    ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
    ObjectSetDouble(0, name,  OBJPROP_PRICE, 1, g_lvl_786);
    ObjectSetInteger(0, name, OBJPROP_COLOR, DirAllowed(g_isBullish) ? clrGold : clrDimGray);
    ObjectSetInteger(0, name, OBJPROP_FILL,  true);
    ObjectSetInteger(0, name, OBJPROP_BACK,  true);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name,  OBJPROP_TOOLTIP, "Zona de Entrada: " + DoubleToString(Inp_Entry1,3) + " ~ " + DoubleToString(Inp_Entry2,3));
}

void DrawHLine(string name, double price, color clr, string label)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

    ObjectSetDouble(0, name,  OBJPROP_PRICE,   price);
    ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name,  OBJPROP_TOOLTIP, label + " @ " + DoubleToString(price, _Digits));
    ObjectSetString(0, name,  OBJPROP_TEXT,    label);
}

//--- remove todos os objetos do EA (prefixo "Fibo_"; a Fibo manual tem nome proprio)
void DeleteAllObjects()
{
    ObjectsDeleteAll(0, "Fibo_");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Eventos do grafico: arrastar a Fibo manual e botao FIBO AUTO     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(Inp_FiboMode == FIBO_MANUAL)
    {
        if(id == CHARTEVENT_OBJECT_CLICK && sparam == "Fibo_BTN_AUTO")
        {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            SnapManualToAuto();
            RefreshNow();
            return;
        }
        if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE) && sparam == MFIB)
        {
            RefreshNow();
            return;
        }
        if(id == CHARTEVENT_OBJECT_DELETE && sparam == MFIB)
        {
            CreateManual();                  // apagou sem querer: recria no swing automatico
            RefreshNow();
            return;
        }
    }
    if(id == CHARTEVENT_CHART_CHANGE && Inp_DrawLevels)
    {
        CalculateFiboLevels();
        DrawFiboLevels();
        DrawVisual();
    }
}

void RefreshNow()
{
    UpdateLeg(false, CountPositions());
    if(Inp_DrawLevels)
        DrawFiboLevels();
    DrawVisual();
}

//+------------------------------------------------------------------+
//| VISUAL: preco grande (canto superior esquerdo) + painel          |
//+------------------------------------------------------------------+
void DrawVisual()
{
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
        return;

    int y = 8;
    if(Inp_BigPrice)
    {
        double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double prev = iClose(_Symbol, PERIOD_CURRENT, 1);
        color  clr  = (bid >= prev) ? Inp_BuyClr : Inp_SellClr;
        Label("Fibo_BIGPX", 12, y, DoubleToString(bid, _Digits), clr, Inp_BigPriceSize, "Arial Black");
        y += (int)MathRound(Inp_BigPriceSize * 1.75) + 6;
    }
    if(Inp_ShowPanel)
        DrawPanel(y);
    ChartRedraw();
}

void Label(string name, int x, int y, string txt, color clr, int size, string font)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetString(0, name, OBJPROP_FONT, font);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

string Money(double v)
{
    return((v >= 0 ? "+" : "") + DoubleToString(v, 2));
}

void DrawPanel(int y0)
{
    UpdateStats();

    string cur = AccountInfoString(ACCOUNT_CURRENCY);
    string tf  = StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7);

    //--- ordens abertas do robo
    int    nb = 0, ns = 0;
    double lots = 0, fl = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_pos.SelectByIndex(i)) continue;
        if(g_pos.Magic() != Inp_MagicNumber || g_pos.Symbol() != _Symbol) continue;
        if(g_pos.PositionType() == POSITION_TYPE_BUY) nb++; else ns++;
        lots += g_pos.Volume();
        fl   += g_pos.Profit() + g_pos.Swap();
    }

    //--- DD de cada periodo com o flutuante de agora
    double dd[3], ddPct[3];
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    for(int p = 0; p < 3; p++)
    {
        dd[p] = MathMax(g_ddHist[p], g_peak[p] - (g_cum[p] + fl));
        double baseBal = bal - g_real[p];                  // saldo aproximado no inicio do periodo
        ddPct[p] = (baseBal > 0) ? dd[p] / baseBal * 100.0 : 0.0;
    }

    int    trades  = g_trWins + g_trLoss;
    double acerto  = (trades > 0) ? 100.0 * g_trWins / trades : 0.0;
    double payoff  = (g_trWins > 0 && g_trLoss > 0 && g_sumLoss > 0)
                     ? (g_sumWin / g_trWins) / (g_sumLoss / g_trLoss) * 100.0 : 0.0;
    double risk    = MathAbs(g_lvl_618 - g_lvl_1127);
    double rrSetup = (risk > 0) ? MathAbs(g_lvl_tp_final - g_lvl_618) / risk : 0.0;

    string t[14];
    color  c[14];
    int    n = 0;

    t[n] = "RICKEA FIBO SETUP v6   " + _Symbol + " " + tf + "   [" + DirName() + "]"; c[n++] = clrSilver;

    if(!g_leg.ok)
    {
        t[n] = (Inp_FiboMode == FIBO_MANUAL) ? "Fibo MANUAL: afaste os dois pontos da Fibo" : "Fibo AUTO: procurando swing";
        c[n++] = clrSilver;
    }
    else
    {
        string flag = IsBlocked() ? "  [BLOQUEADO]" : "";
        if(!DirAllowed(g_isBullish)) flag += "  [DESLIGADO: " + DirName() + "]";
        t[n] = (Inp_FiboMode == FIBO_MANUAL ? "Fibo MANUAL: " : "Fibo AUTO: ") +
               (g_isBullish ? "ALTA -> COMPRA na retracao" : "QUEDA -> VENDA na retracao") + flag;
        c[n++] = g_isBullish ? Inp_BuyClr : Inp_SellClr;
        t[n] = "Entrada " + DoubleToString(Inp_Entry1, 3) + ": " + DoubleToString(g_lvl_618, _Digits) +
               "   " + DoubleToString(Inp_Entry2, 3) + ": " + DoubleToString(g_lvl_786, _Digits) +
               "   Stop " + DoubleToString(Inp_StopLoss, 3) + ": " + DoubleToString(g_lvl_1127, _Digits);
        c[n++] = clrGold;
        t[n] = "Parcial " + DoubleToString(Inp_PartialTP, 3) + ": " + DoubleToString(g_lvl_tp_partial, _Digits) +
               "   Alvo " + DoubleToString(Inp_FullTP, 3) + ": " + DoubleToString(g_lvl_tp_final, _Digits) +
               "   RR setup 1:" + DoubleToString(rrSetup, 2);
        c[n++] = clrDodgerBlue;
    }
    if(Inp_ForceFilter != FORCE_OFF && g_forceTxt == "desligado")
        g_forceTxt = "aguardando sinal";
    t[n] = "Forca: " + g_forceTxt;                                             c[n++] = clrSilver;
    t[n] = "Status: " + g_status;                                              c[n++] = g_statusClr;
    t[n] = "---------------- ORDENS DO ROBO ----------------";                 c[n++] = clrDimGray;
    t[n] = "Abertas: " + IntegerToString(nb + ns) + " (C:" + IntegerToString(nb) + " V:" + IntegerToString(ns) +
           ")   Lotes: " + DoubleToString(lots, 2) + "   Flutuante: " + Money(fl) + " " + cur;
    c[n++] = (fl >= 0) ? Inp_BuyClr : Inp_SellClr;
    double cycReal = (g_cycleStart > 0) ? RealizedSince(g_cycleStart) : 0.0;
    t[n] = "Ciclo: realizado " + Money(cycReal) + " + flut. " + Money(fl) + " = " + Money(cycReal + fl) +
           (Inp_CycleTP > 0 ? "  / alvo " + DoubleToString(Inp_CycleTP, 2) : "");
    c[n++] = (cycReal + fl >= 0) ? Inp_BuyClr : Inp_SellClr;
    t[n] = "Realizado   Dia: " + Money(g_real[0]) + "   Semana: " + Money(g_real[1]) + "   Mes: " + Money(g_real[2]);
    c[n++] = (g_real[0] >= 0) ? Inp_BuyClr : Inp_SellClr;
    t[n] = "DD          Dia: " + DoubleToString(dd[0], 2) + " (" + DoubleToString(ddPct[0], 2) + "%)   Semana: " +
           DoubleToString(dd[1], 2) + " (" + DoubleToString(ddPct[1], 2) + "%)   Mes: " +
           DoubleToString(dd[2], 2) + " (" + DoubleToString(ddPct[2], 2) + "%)";
    c[n++] = clrOrange;
    t[n] = "Trades: " + IntegerToString(trades) + "   Acerto: " + DoubleToString(acerto, 1) +
           "%   Payoff: " + DoubleToString(payoff, 0) + "% (ganho medio / perda media)";
    c[n++] = (payoff >= 100 || trades == 0) ? Inp_BuyClr : Inp_SellClr;
    t[n] = "Take global: " + (Inp_GlobalTP > 0 ? DoubleToString(Inp_GlobalTP, 2) : "OFF") +
           "   Stop global: " + (Inp_GlobalSL > 0 ? DoubleToString(Inp_GlobalSL, 2) : "OFF") +
           "   Take ciclo: " + (Inp_CycleTP > 0 ? DoubleToString(Inp_CycleTP, 2) : "OFF");
    c[n++] = clrGray;

    //--- fundo escuro para ler por cima das velas
    int fs = Inp_PanelFontSize, lineH = fs + 8, maxLen = 0;
    for(int i = 0; i < n; i++) maxLen = MathMax(maxLen, StringLen(t[i]));
    int w = (int)(maxLen * fs * 0.78) + 24;
    int h = n * lineH + 14;
    string bg = "Fibo_PNL_BG";
    if(ObjectFind(0, bg) < 0)
    {
        ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, bg, OBJPROP_BACK, false);
    }
    ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 6);
    ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, y0);
    ObjectSetInteger(0, bg, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, bg, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'12,16,28');
    ObjectSetInteger(0, bg, OBJPROP_COLOR, C'40,60,95');

    for(int i = 0; i < n; i++)
        Label("Fibo_PNL" + IntegerToString(i), 14, y0 + 7 + i * lineH, t[i], c[i], fs, "Consolas");
    for(int i = n; i < 14; i++)
        ObjectDelete(0, "Fibo_PNL" + IntegerToString(i));
}

//+------------------------------------------------------------------+
//| Estatisticas so das ordens do robo neste simbolo                 |
//| Realizado e DD do dia, da semana e do mes; acerto e payoff por   |
//| trade (cada posicao, somando as parciais)                        |
//+------------------------------------------------------------------+
void UpdateStats()
{
    if(g_statTime > 0 && TimeCurrent() - g_statTime < 3)
        return;
    g_statTime = TimeCurrent();

    MqlDateTime d;
    TimeToStruct(TimeCurrent(), d);
    d.hour = 0; d.min = 0; d.sec = 0;
    datetime dayStart   = StructToTime(d);
    int      dow        = (d.day_of_week == 0) ? 6 : d.day_of_week - 1;   // semana comeca na segunda
    datetime weekStart  = dayStart - dow * 86400;
    d.day = 1;
    datetime monthStart = StructToTime(d);
    datetime starts[3];
    starts[0] = dayStart; starts[1] = weekStart; starts[2] = monthStart;

    for(int p = 0; p < 3; p++) { g_real[p] = 0; g_cum[p] = 0; g_peak[p] = 0; g_ddHist[p] = 0; }
    g_trWins = 0; g_trLoss = 0; g_sumWin = 0; g_sumLoss = 0;

    if(!HistorySelect(0, TimeCurrent() + 60))
        return;

    ulong  ids[];
    double res[];
    bool   closed[];
    int    nIds = 0;

    int total = HistoryDealsTotal();
    for(int i = 0; i < total; i++)                   // em ordem de tempo
    {
        ulong tk = HistoryDealGetTicket(i);
        if(tk == 0) continue;
        if(HistoryDealGetInteger(tk, DEAL_MAGIC) != Inp_MagicNumber) continue;
        if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
        long type = HistoryDealGetInteger(tk, DEAL_TYPE);
        if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;

        double   v     = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) +
                         HistoryDealGetDouble(tk, DEAL_COMMISSION);
        datetime t     = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
        long     entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
        ulong    pid   = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);

        for(int p = 0; p < 3; p++)
        {
            if(t < starts[p]) continue;
            g_real[p] += v;
            g_cum[p]  += v;
            if(g_cum[p] > g_peak[p]) g_peak[p] = g_cum[p];
            g_ddHist[p] = MathMax(g_ddHist[p], g_peak[p] - g_cum[p]);
        }

        //--- resultado por posicao (entrada + parciais + saida)
        int k = -1;
        for(int j = 0; j < nIds; j++) if(ids[j] == pid) { k = j; break; }
        if(k < 0)
        {
            k = nIds++;
            ArrayResize(ids, nIds); ArrayResize(res, nIds); ArrayResize(closed, nIds);
            ids[k] = pid; res[k] = 0; closed[k] = false;
        }
        res[k] += v;
        if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
            closed[k] = true;
    }

    //--- so posicoes que ja fecharam por completo contam como trade
    for(int j = 0; j < nIds; j++)
    {
        if(!closed[j]) continue;
        if(PositionSelectByTicket(ids[j])) continue;   // ainda aberta (so fez parcial)
        if(res[j] > 0)      { g_trWins++; g_sumWin  += res[j]; }
        else if(res[j] < 0) { g_trLoss++; g_sumLoss -= res[j]; }
    }
}
//+------------------------------------------------------------------+
