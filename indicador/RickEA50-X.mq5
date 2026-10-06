//+------------------------------------------------------------------+
//|                                                  RickEA50-X.mq5 |
//|                                 Copyright 2024,Richartrader Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| Versao MT5 do RickEA50-X v1.10 (MT4).          |
//|  - 1a entrada na abertura do candle: candle 1 fechou abaixo do   |
//|    candle 2 = VENDA, senao COMPRA                                |
//|  - Grid a cada Step pontos contra a ultima ordem (ate MaxTrades) |
//|  - TP de todas as ordens = preco medio +/- TakeProfit pontos     |
//|  - Hidden TP em dinheiro, meta diaria e equity stop opcionais    |
//| v1.10: spread corrigido, sem BALANCE/EQUITY na tela, painel,     |
//| linhas de preco medio/TP/proximo grid, seta do gatilho, uma      |
//| entrada por candle e filtro de tendencia.                        |
//| v1.11: opcao de direcao (compras e vendas / somente compras /    |
//| somente vendas).                                                 |
//| ATENCAO: exige conta HEDGING (o grid abre varias posicoes na     |
//| mesma direcao; em conta NETTING elas se fundem numa so).         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, RiCharTrader Ltd."
#property link      "telegram: @rickcbf"
#property version   "1.11"
#property description "RickEA50-X"
#property description "Instagram:@ri.chartrader"

#include <Trade\Trade.mqh>

int    password_status = -1;
string password_message[] = { "WRONG PASSWORD. Trading not allowed.",
                              "OK PASSWORD verified." };
input string user_password = "Digite um password";
string permitir_passwords[] = {"Rick1","Rick2"};
input string EA_Name_EA = "RickEA50-X";
input string t1 = "Instagram:@ri.chartrader";
input string t2 = "telegram: @rick_cbf";
input string Recommended_Deposit = "$100USD(10000Cents)for 0,01 Lot";
input string Time_Frame = "Time Frame M30 \\ H1(Recommended)";
input string Pairs = "EURUSD \\ GBPUSD \\ XAUUSD \\ USDJPY \\ EURUSDc \\ GBPUSDc \\ XAUUSDc \\ USDJPYc \\ ETHUSD \\ ETHUSDc ...";
input double Lot = 0.01;
input double LotMultiplicator = 1.05;
input double TakeProfit = 350; //Target
input double Step = 1200; //Grid
input double Average = 1;
input bool   Use_Daily_Target = false;
input double Daily_Target = 100;//Daily Profit(Money)
input int    MaxTrades = 6;
input bool   Hidden_TP = true;
input double Hiden_TP = 250;
input bool   UseEquityStop = false;
input double TotalEquityRisk = 50;
input double OpenRangePips = 1;
input double MaxDailyRange = 20000;
input int    Open_Hour = 00;
input int    Close_Hour = 23;
bool TradeOnThursday = true;
int  Thursday_Hour = 12;
bool TradeOnFriday = true;
int  Friday_Hour = 20;
input bool   Filter_Sideway = true;
input bool   Filter_News = true;
input bool   invisible_mode = true;

//--- Direcao das operacoes
enum ENUM_DIRECAO
  {
   DIRECAO_AMBAS   = 0, // Compras e vendas
   DIRECAO_COMPRAS = 1, // Somente compras
   DIRECAO_VENDAS  = 2  // Somente vendas
  };

//--- Melhorias v1.10
enum ENUM_TENDENCIA_MODO
  {
   TEND_DESLIGADO   = 0, // Sem filtro de tendencia
   TEND_INCLINACAO  = 1, // Inclinacao da SMA
   TEND_MEDIA_LONGA = 2  // Preco acima/abaixo da media longa
  };
input string              SecEntrada            = "===== ENTRADA =====";             // ===== ENTRADA =====
input ENUM_DIRECAO        Direcao               = DIRECAO_AMBAS; // Direcao: compras e vendas, somente compras ou somente vendas
input bool                UmaEntradaPorCandle   = true;   // Uma entrada por candle (timeframe do grafico)
input string              SecTendencia          = "===== FILTRO DE TENDENCIA =====";  // ===== FILTRO DE TENDENCIA =====
input ENUM_TENDENCIA_MODO TendenciaModo         = TEND_DESLIGADO; // Filtro de tendencia (vale para a 1a entrada)
input int                 InclinacaoSMAPeriodo  = 20;     // Inclinacao: periodo da SMA
input int                 InclinacaoBarras      = 5;      // Inclinacao: quantas barras para medir
input int                 InclinacaoMinPontos   = 50;     // Inclinacao: minimo (pontos) para considerar tendencia
input int                 MediaLongaPeriodo     = 50;    // Media longa: periodo
input ENUM_MA_METHOD      MediaLongaMetodo      = MODE_EMA; // Media longa: metodo
input string              SecVisual             = "===== VISUAL =====";              // ===== VISUAL =====
input bool                MostrarPainel         = true;   // Painel do bot (canto superior esquerdo)
input int                 PainelX               = 10;     // Painel: distancia da esquerda (pixels)
input int                 PainelY               = 20;     // Painel: distancia do topo (pixels)
input bool                MostrarLinhas         = true;   // Linhas de preco medio, TP e proximo grid
input bool                MostrarGatilho        = true;   // Seta do gatilho no ultimo candle fechado
input bool                MostrarMediaTendencia = true;   // Plotar a media do filtro de tendencia
input int                 BarrasDesenho         = 300;    // Quantos candles desenhar da media
input color               CorPrecoMedio         = clrGold;       // Cor do preco medio
input color               CorTP                 = clrLime;       // Cor do TP do grid
input color               CorGrid               = clrOrange;     // Cor do proximo grid
input color               CorMediaTend          = clrDodgerBlue; // Cor da media de tendencia

// Definir a data de expiracao (ANO, MES, DIA)
#define EXPIRATION_DATE D'2026.12.31'  // Expira em 31 de Dezembro de 2026

#define DIR_COMPRA 0
#define DIR_VENDA  1

//--- estado do robo (mesmas variaveis da versao MT4)
CTrade   trade;
int      g_magic          = 789150;  // magic por simbolo (I_i_0)
int      g_slippage       = 5;       // desvio maximo em pontos (I_d_34)
int      g_cont           = -2;      // contador do "Average" (I_i_76)
double   g_lote           = 0;       // ultimo lote calculado (I_d_69)
int      g_nUlt           = 0;       // ordens abertas na ultima entrada (I_i_90)
bool     g_temCompra      = false;   // ciclo comprado (I_b_18)
bool     g_temVenda       = false;   // ciclo vendido (I_b_19)
bool     g_entrar         = false;   // liberado para entrar (I_b_22)
bool     g_ajustarTP      = false;   // recalcular o TP do grid (I_b_16)
bool     g_tpPronto       = false;   // TP calculado (I_b_17)
double   g_eqRef          = 0;       // equity stop (I_d_57)
double   g_eqAnt          = 0;       // equity stop (I_d_58)
int      g_hSMA           = INVALID_HANDLE;
int      g_hMLonga        = INVALID_HANDLE;

string   PFX                  = "RickEA50_";   // prefixo dos objetos do grafico
datetime g_barraUltimaEntrada = 0;             // uma entrada por candle
datetime g_ultimaBarraDesenho = 0;
datetime g_ultimaLeituraHist  = 0;             // cache das estatisticas do historico
int      g_wins               = 0;
int      g_losses             = 0;
double   g_somaGanhos         = 0;
double   g_somaPerdas         = 0;
double   g_lucroHoje          = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(TimeCurrent() >= EXPIRATION_DATE)
     {
      Print(EA_Name_EA, " expirado! ENTRE EM CONTATO TELEGRAM: https://t.me/+6jbcqyJ5O7YyNDgx");
      ExpertRemove();
      return(INIT_FAILED);
     }
   ChartSetInteger(0, CHART_SHOW_GRID, false);

   //--- senhas (como na versao MT4: so informa, nao bloqueia)
   password_status = -1;
   for(int i = 0; i < ArraySize(permitir_passwords); i++)
      if(user_password == permitir_passwords[i])
        {
         password_status = i;
         break;
        }
   if(password_status != -1)
      Print("Ok... acesso liberado..." + password_message[1] + " , Status = ", password_status);
   else
      Print(password_message[0]);

   //--- o grid precisa de varias posicoes na mesma direcao
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Alert(EA_Name_EA, ": esta conta e NETTING. O robo precisa de conta HEDGING (o grid abre varias posicoes na mesma direcao).");
      return(INIT_FAILED);
     }

   g_magic = MagicDoSimbolo();
   Print(EA_Name_EA, ": direcao das operacoes = ", TextoDirecao(), ".");
   trade.SetExpertMagicNumber(g_magic);
   trade.SetDeviationInPoints(g_slippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   g_hSMA    = iMA(_Symbol, _Period, InclinacaoSMAPeriodo, 0, MODE_SMA, PRICE_CLOSE);
   g_hMLonga = iMA(_Symbol, _Period, MediaLongaPeriodo, 0, MediaLongaMetodo, PRICE_CLOSE);
   if(g_hSMA == INVALID_HANDLE || g_hMLonga == INVALID_HANDLE)
     {
      Print(EA_Name_EA, ": nao foi possivel criar as medias do filtro de tendencia.");
      return(INIT_FAILED);
     }

   g_cont               = -2;
   g_barraUltimaEntrada = UltimaEntradaRegistrada();
   g_ultimaBarraDesenho = 0;
   g_ultimaLeituraHist  = 0;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("************");
   if(g_hSMA != INVALID_HANDLE)
      IndicatorRelease(g_hSMA);
   if(g_hMLonga != INVALID_HANDLE)
      IndicatorRelease(g_hMLonga);
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Magic por simbolo (mesma tabela da versao MT4)                   |
//+------------------------------------------------------------------+
int MagicDoSimbolo()
  {
   string pares[] = {"AUDCAD","AUDJPY","AUDNZD","AUDUSD","CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY",
                     "EURUSD","GBPCHF","GBPJPY","GBPUSD","NZDJPY","NZDUSD","USDCHF","USDJPY","USDCAD"};
   for(int i = 0; i < ArraySize(pares); i++)
      if(_Symbol == pares[i] || _Symbol == pares[i] + "c" || _Symbol == pares[i] + "m")
         return(101101 + i);
   return(789150);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0 || tick.ask <= 0)
      return;
   double bid = tick.bid, ask = tick.ask;

   //--- tela
   DesenharRodape();
   double precoAtual = NormalizeDouble(bid, _Digits);
   double ref        = iClose(_Symbol, PERIOD_M1, 1);     // EMA(1) do M1 = fechamento do candle anterior
   color  corPreco   = (color)42495;
   if(ref > precoAtual) corPreco = (color)255;
   if(ref < precoAtual) corPreco = (color)65280;
   DesenharPrecoSpread(precoAtual, corPreco);
   AtualizarVisual();

   //--- meta diaria
   if(Use_Daily_Target)
     {
      if(LucroDoDia() >= Daily_Target)
        {
         FecharTudo();
         Print("\nCongratulations on achieving your daily target");
         return;
        }
     }

   //--- TP oculto em dinheiro
   if(Hidden_TP)
     {
      if(Hiden_TP <= LucroFlutuante())
        {
         Print("\nMagic Take Profit");
         FecharTudo();
        }
     }

   if(g_cont >= Average)
      g_cont = -2;
   if(ContarPosicoes() == 0)
      g_cont = -2;

   //--- equity stop
   double flutuante = LucroFlutuante();
   if(UseEquityStop && flutuante < 0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(ContarPosicoes() == 0)
         g_eqRef = equity;
      if(g_eqRef < g_eqAnt)
         g_eqRef = g_eqAnt;
      else
         g_eqRef = equity;
      g_eqAnt = equity;
      if(MathAbs(flutuante) > (TotalEquityRisk / 100) * g_eqRef)
        {
         FecharTudo();
         Print("Closed All due to Stop Out");
         g_ajustarTP = false;
        }
     }

   int n = ContarPosicoes();
   if(n == 0)
      g_tpPronto = false;

   //--- direcao do ciclo aberto
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelecionarMinha(i))
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        { g_temCompra = true;  g_temVenda = false; break; }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        { g_temCompra = false; g_temVenda = true;  break; }
     }

   //--- grid: preco andou Step pontos contra a ultima ordem
   if(n > 0 && n <= MaxTrades)
     {
      double ultCompra = UltimoPreco(POSITION_TYPE_BUY);
      double ultVenda  = UltimoPreco(POSITION_TYPE_SELL);
      if(CandleLiberado(5))
        {
         if(g_temCompra && (ultCompra - ask) >= Step * _Point)
            g_entrar = true;
         if(g_temVenda && (bid - ultVenda) >= Step * _Point)
            g_entrar = true;
        }
     }
   if(n < 1)
     {
      g_temVenda  = false;
      g_temCompra = false;
      if(CandleLiberado(2))
         g_entrar = true;
     }

   //--- nova ordem do grid
   if(g_entrar)
     {
      if(g_temVenda)
        {
         if(g_cont == -2)
            g_lote = NormalizeDouble(Lot * MathPow(LotMultiplicator, g_nUlt), 2);
         g_nUlt = n;
         if(g_lote > 0)
           {
            if(!Enviar(DIR_VENDA, g_lote, n))
              {
               Print("Error: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               return;
              }
            g_entrar    = false;
            g_ajustarTP = true;
           }
        }
      else if(g_temCompra)
        {
         if(g_cont == -2)
            g_lote = NormalizeDouble(Lot * MathPow(LotMultiplicator, g_nUlt), 2);
         g_nUlt = n;
         if(g_lote > 0)
           {
            if(!Enviar(DIR_COMPRA, g_lote, n))
              {
               Print("Error: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               return;
              }
            g_entrar    = false;
            g_ajustarTP = true;
           }
        }
     }

   //--- 1a entrada (faixa a partir da abertura do dia)
   if(OpenRangePips > 0 && MaxDailyRange > 0)
     {
      double abertura = AberturaDoDia();
      double l8  = NormalizeDouble(OpenRangePips * _Point + abertura, _Digits);
      double l9  = NormalizeDouble(abertura - OpenRangePips * _Point, _Digits);
      double l10 = NormalizeDouble(MaxDailyRange * _Point + l8, _Digits);
      double l11 = NormalizeDouble(l9 - MaxDailyRange * _Point, _Digits);
      double c0  = iClose(_Symbol, _Period, 0);
      if((c0 > l8 && c0 < l10) || (c0 < l9 && c0 > l11))
        {
         if(g_entrar && n < 1)
            if(!PrimeiraEntrada(n))
               return;
         g_entrar = false;
        }
     }
   else
     {
      if(g_entrar && n < 1)
         if(!PrimeiraEntrada(n))
            return;
     }

   //--- TP do grid = preco medio +/- TakeProfit
   n = ContarPosicoes();
   double somaPL = 0, somaL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelecionarMinha(i))
         continue;
      somaPL += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
      somaL  += PositionGetDouble(POSITION_VOLUME);
     }
   double medio = (n > 0 && somaL > 0) ? NormalizeDouble(somaPL / somaL, _Digits) : 0;
   double tp    = 0;
   if(g_ajustarTP)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(!SelecionarMinha(i))
            continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            tp = TakeProfit * _Point + medio;
         else
            tp = medio - TakeProfit * _Point;
         g_tpPronto = true;
        }
     }
   if(!g_ajustarTP || !g_tpPronto)
      return;
   tp = NormalizeDouble(tp, _Digits);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelecionarMinha(i))
         continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(MathAbs(PositionGetDouble(POSITION_TP) - tp) >= _Point / 2)
         trade.PositionModify(tk, PositionGetDouble(POSITION_SL), tp);
      g_ajustarTP = false;
     }
  }

//+------------------------------------------------------------------+
//| 1a entrada do ciclo (false = erro ao enviar a ordem)             |
//+------------------------------------------------------------------+
bool PrimeiraEntrada(int n)
  {
   if(!HorarioPermite())
      return(true);

   double c2  = iClose(_Symbol, _Period, 2);
   double c1  = iClose(_Symbol, _Period, 1);
   int    dir = (c2 > c1) ? DIR_VENDA : DIR_COMPRA;

   if(g_temVenda || g_temCompra || !DirecaoPermite(dir) || !TendenciaPermite(dir))
      return(true);

   g_nUlt = n;
   if(g_cont == -2)
      g_lote = NormalizeDouble(Lot * MathPow(LotMultiplicator, g_nUlt), 2);
   if(g_lote > 0)
     {
      if(!Enviar(dir, g_lote, g_nUlt))
        {
         Print(g_lote, "Error: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         return(false);
        }
      g_ajustarTP = true;
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Envia ordem a mercado (tenta de novo em requote/preco/timeout)   |
//+------------------------------------------------------------------+
bool Enviar(int dir, double lote, int n)
  {
   string cm = _Symbol + "-" + EA_Name_EA + "-" + IntegerToString(n);
   for(int tent = 0; tent < 100; tent++)
     {
      bool ok = (dir == DIR_COMPRA) ? trade.Buy(lote, _Symbol, 0.0, 0.0, 0.0, cm)
                                    : trade.Sell(lote, _Symbol, 0.0, 0.0, 0.0, cm);
      uint rc = trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL))
        {
         g_cont++;
         g_barraUltimaEntrada = TimeCurrent();
         return(true);
        }
      if(rc != TRADE_RETCODE_REQUOTE && rc != TRADE_RETCODE_PRICE_OFF &&
         rc != TRADE_RETCODE_PRICE_CHANGED && rc != TRADE_RETCODE_TIMEOUT)
         return(false);
      Sleep(5000);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Fecha todas as posicoes do robo neste simbolo                    |
//+------------------------------------------------------------------+
void FecharTudo()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == g_magic)
         trade.PositionClose(tk, g_slippage);
      Sleep(1000);
     }
  }

//+------------------------------------------------------------------+
//| Seleciona a posicao i se for deste robo e simbolo                |
//+------------------------------------------------------------------+
bool SelecionarMinha(int i)
  {
   ulong tk = PositionGetTicket(i);
   if(tk == 0)
      return(false);
   return(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == g_magic);
  }

int ContarPosicoes()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(SelecionarMinha(i))
         n++;
   return(n);
  }

double LucroFlutuante()
  {
   double p = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(SelecionarMinha(i))
         p += PositionGetDouble(POSITION_PROFIT);
   return(p);
  }

//+------------------------------------------------------------------+
//| Preco de abertura da posicao mais recente (maior ticket)         |
//+------------------------------------------------------------------+
double UltimoPreco(ENUM_POSITION_TYPE tipo)
  {
   double preco = 0;
   ulong  maior = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelecionarMinha(i))
         continue;
      if(PositionGetInteger(POSITION_TYPE) != tipo)
         continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(tk > maior)
        {
         maior = tk;
         preco = PositionGetDouble(POSITION_PRICE_OPEN);
        }
     }
   return(preco);
  }

//+------------------------------------------------------------------+
//| Abertura do 1o candle de hoje no timeframe do grafico            |
//+------------------------------------------------------------------+
double AberturaDoDia()
  {
   MqlDateTime hoje;
   TimeToStruct(TimeCurrent(), hoje);
   double abertura = 0;
   int    barras   = Bars(_Symbol, _Period);
   for(int i = 0; i < barras; i++)
     {
      MqlDateTime d;
      TimeToStruct(iTime(_Symbol, _Period, i), d);
      if(d.day_of_year != hoje.day_of_year)
         break;
      abertura = iOpen(_Symbol, _Period, i);
     }
   return(abertura);
  }

//+------------------------------------------------------------------+
//| Lucro fechado hoje pelo robo (meta diaria)                       |
//+------------------------------------------------------------------+
double LucroDoDia()
  {
   double total = 0;
   if(!HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent() + 60))
      return(0);
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != g_magic)
         continue;
      total += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
               HistoryDealGetDouble(d, DEAL_SWAP);
     }
   return(total);
  }

//+------------------------------------------------------------------+
//| Uma entrada por candle (timeframe do grafico)                    |
//+------------------------------------------------------------------+
bool CandleLiberado(int volumeMax)
  {
   if(UmaEntradaPorCandle)
      return(g_barraUltimaEntrada < iTime(_Symbol, _Period, 0));
   return(iVolume(_Symbol, _Period, 0) < volumeMax);   // original: so nos primeiros ticks do candle
  }

//+------------------------------------------------------------------+
//| Hora da ultima entrada deste EA (abertas e historico)            |
//+------------------------------------------------------------------+
datetime UltimaEntradaRegistrada()
  {
   datetime ultima = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(SelecionarMinha(i) && (datetime)PositionGetInteger(POSITION_TIME) > ultima)
         ultima = (datetime)PositionGetInteger(POSITION_TIME);

   if(HistorySelect(0, TimeCurrent() + 60))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol ||
            HistoryDealGetInteger(d, DEAL_MAGIC) != g_magic ||
            HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
            continue;
         datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         if(t > ultima)
            ultima = t;
        }
   return(ultima);
  }

//+------------------------------------------------------------------+
//| Filtro de tendencia (mesmo do RickEA67-Envelopes)                |
//+------------------------------------------------------------------+
double ValorMedia(int handle, int shift)
  {
   double b[1];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1)
      return(0);
   return(b[0]);
  }

double InclinacaoAtual()
  {
   return((ValorMedia(g_hSMA, 1) - ValorMedia(g_hSMA, 1 + InclinacaoBarras)) / _Point);
  }

bool TendenciaPermite(int dir)
  {
   if(TendenciaModo == TEND_DESLIGADO)
      return(true);

   if(TendenciaModo == TEND_INCLINACAO)
     {
      double inclinacao = InclinacaoAtual();
      // Nao compra com a media caindo forte, nao vende com a media subindo forte
      if(dir == DIR_COMPRA)
         return(inclinacao > -InclinacaoMinPontos);
      return(inclinacao < InclinacaoMinPontos);
     }

   // Media longa: compra so acima dela, vende so abaixo
   double mediaLonga = ValorMedia(g_hMLonga, 1);
   double c1         = iClose(_Symbol, _Period, 1);
   if(dir == DIR_COMPRA)
      return(c1 > mediaLonga);
   return(c1 < mediaLonga);
  }

string TextoTendencia()
  {
   if(TendenciaModo == TEND_DESLIGADO)
      return("filtro desligado");

   if(TendenciaModo == TEND_INCLINACAO)
     {
      double incl = InclinacaoAtual();
      string d = (incl > InclinacaoMinPontos) ? "ALTA" : (incl < -InclinacaoMinPontos) ? "BAIXA" : "LATERAL";
      return(d + " (incl. " + DoubleToString(incl, 0) + " pts)");
     }

   double ml = ValorMedia(g_hMLonga, 1);
   return((iClose(_Symbol, _Period, 1) > ml ? "ALTA" : "BAIXA") + " (media " + IntegerToString(MediaLongaPeriodo) + ")");
  }

//+------------------------------------------------------------------+
//| Mesmo filtro de dia/hora usado pelo bot na 1a entrada            |
//+------------------------------------------------------------------+
bool HorarioPermite()
  {
   MqlDateTime agora;
   TimeToStruct(TimeCurrent(), agora);
   int hora  = agora.hour;
   int dia   = agora.day_of_week;
   int abre  = (Open_Hour == 24) ? 0 : Open_Hour;
   int fecha = (Close_Hour == 24) ? 0 : Close_Hour;

   if(!TradeOnThursday && dia == 4) return(false);
   if(TradeOnThursday && dia == 4 && hora > Thursday_Hour) return(false);
   if(!TradeOnFriday && dia == 5) return(false);
   if(TradeOnFriday && dia == 5 && hora > Friday_Hour) return(false);
   if(abre < fecha && (hora < abre || hora >= fecha)) return(false);
   if(abre > fecha && hora < abre && hora >= fecha) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Filtro de direcao: somente compras / somente vendas / ambas      |
//+------------------------------------------------------------------+
bool DirecaoPermite(int dir)
  {
   if(Direcao == DIRECAO_COMPRAS)
      return(dir == DIR_COMPRA);
   if(Direcao == DIRECAO_VENDAS)
      return(dir == DIR_VENDA);
   return(true);
  }

string TextoDirecao()
  {
   if(Direcao == DIRECAO_COMPRAS)
      return("SOMENTE COMPRAS");
   if(Direcao == DIRECAO_VENDAS)
      return("SOMENTE VENDAS");
   return("COMPRAS E VENDAS");
  }

bool TradePermitido()
  {
   return(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED));
  }

//+------------------------------------------------------------------+
//| Nome do bot (inferior esquerdo) e Instagram (inferior direito)   |
//| BALANCE e EQUITY nao aparecem: nao expor o saldo da conta        |
//+------------------------------------------------------------------+
void DesenharRodape()
  {
   CriarRotulo(PFX + "Nome", EA_Name_EA, "Times New Roman Bold", 24, (color)65280,
               CORNER_LEFT_LOWER, ANCHOR_LEFT_LOWER, 4, 10);

   string fonte = "Times New Roman";
   CriarRotulo(PFX + "Rod_Orders", "ALL ORDERS:  " + IntegerToString(PositionsTotal() + OrdersTotal()),
               fonte, 16, clrYellow, CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, 10, 1);
   CriarRotulo(PFX + "Rod_Time", "TIME:  " + TimeToString(TimeLocal(), TIME_MINUTES),
               fonte, 16, clrWhite, CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, 10, 21);
   CriarRotulo(PFX + "Rod_Date", "DATE:  " + TimeToString(TimeLocal(), TIME_DATE),
               fonte, 16, clrWhite, CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, 10, 41);
   CriarRotulo(PFX + "Rod_Nome", EA_Name_EA, fonte, 24, clrBlue,
               CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, 10, 61);
   CriarRotulo(PFX + "Rod_Insta", "Instagram:@ri.chartrader", fonte, 18, clrRed,
               CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, 10, 91);
  }

//+------------------------------------------------------------------+
//| Preco grande + spread logo abaixo (canto superior direito)       |
//+------------------------------------------------------------------+
void DesenharPrecoSpread(double preco, color cor)
  {
   int tamanho = 30;
   int y       = 26;
   CriarRotulo(PFX + "Preco", DoubleToString(preco, _Digits), "Arial", tamanho, cor,
               CORNER_RIGHT_UPPER, ANCHOR_RIGHT_UPPER, 20, y);

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   CriarRotulo(PFX + "Spread", "Spread: " + IntegerToString(spread), "Times New Roman", 16, clrYellow,
               CORNER_RIGHT_UPPER, ANCHOR_RIGHT_UPPER, 20, y + (int)MathRound(tamanho * 1.6) + 4);
  }

//+------------------------------------------------------------------+
//| Tudo que o bot mostra no grafico                                 |
//+------------------------------------------------------------------+
void AtualizarVisual()
  {
   // No testador sem modo visual nao desenha nada (mais rapido)
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   if(Bars(_Symbol, _Period) < 3)
      return;

   int    nCompra = 0, nVenda = 0;
   ulong  tkC = 0, tkV = 0;
   double lotesC = 0, lotesV = 0, lucro = 0, somaPL = 0, somaL = 0;
   double ultCompra = 0, ultVenda = 0, tp = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!SelecionarMinha(i))
         continue;
      ulong  tk  = PositionGetInteger(POSITION_TICKET);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         nCompra++;
         lotesC += vol;
         if(tk > tkC) { tkC = tk; ultCompra = PositionGetDouble(POSITION_PRICE_OPEN); }
        }
      else
        {
         nVenda++;
         lotesV += vol;
         if(tk > tkV) { tkV = tk; ultVenda = PositionGetDouble(POSITION_PRICE_OPEN); }
        }
      lucro  += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      somaPL += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
      somaL  += vol;
      if(PositionGetDouble(POSITION_TP) > 0)
         tp = PositionGetDouble(POSITION_TP);
     }

   int    total    = nCompra + nVenda;
   double medio    = (somaL > 0) ? somaPL / somaL : 0;
   double proxGrid = 0;
   if(total > 0 && total <= MaxTrades)
      proxGrid = (nCompra > 0) ? ultCompra - Step * _Point : ultVenda + Step * _Point;

   // Gatilho da 1a entrada: candle 1 fechou abaixo do candle 2 = VENDA, senao COMPRA
   int dir = (iClose(_Symbol, _Period, 2) > iClose(_Symbol, _Period, 1)) ? DIR_VENDA : DIR_COMPRA;

   LinhaPreco(PFX + "Medio", medio, CorPrecoMedio, STYLE_DASH, "Preco medio");
   LinhaPreco(PFX + "TP", tp, CorTP, STYLE_SOLID, "TP do grid");
   LinhaPreco(PFX + "ProxGrid", proxGrid, CorGrid, STYLE_DOT,
              "Proximo grid (" + IntegerToString(total + 1) + ")");
   DesenharMediaTendencia();
   DesenharGatilho(total == 0, dir);

   if(MostrarPainel)
      AtualizarPainel(total, nCompra, lotesC, lotesV, lucro, medio, tp, proxGrid, dir);

   g_ultimaBarraDesenho = iTime(_Symbol, _Period, 0);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Linha horizontal com texto (preco medio, TP, proximo grid)       |
//+------------------------------------------------------------------+
void LinhaPreco(string nome, double preco, color cor, int estilo, string texto)
  {
   string nomeTxt = nome + "_txt";
   if(!MostrarLinhas || preco <= 0)
     {
      ObjectDelete(0, nome);
      ObjectDelete(0, nomeTxt);
      return;
     }

   if(ObjectFind(0, nome) < 0)
     {
      ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
     }
   else
      ObjectMove(0, nome, 0, 0, preco);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, estilo);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 1);

   datetime t = iTime(_Symbol, _Period, MathMin(15, Bars(_Symbol, _Period) - 1));
   if(ObjectFind(0, nomeTxt) < 0)
     {
      ObjectCreate(0, nomeTxt, OBJ_TEXT, 0, t, preco);
      ObjectSetInteger(0, nomeTxt, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, nomeTxt, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nomeTxt, OBJPROP_HIDDEN, true);
     }
   else
      ObjectMove(0, nomeTxt, 0, t, preco);
   ObjectSetString(0, nomeTxt, OBJPROP_TEXT, texto + " " + DoubleToString(preco, _Digits));
   ObjectSetString(0, nomeTxt, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, nomeTxt, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, nomeTxt, OBJPROP_COLOR, cor);
  }

//+------------------------------------------------------------------+
//| Seta do gatilho no ultimo candle fechado (so sem posicao aberta) |
//+------------------------------------------------------------------+
void DesenharGatilho(bool mostrar, int dir)
  {
   string nome = PFX + "Gatilho";
   ObjectDelete(0, nome);
   if(!MostrarGatilho || !mostrar)
      return;

   bool compra = (dir == DIR_COMPRA);
   ObjectCreate(0, nome, OBJ_ARROW, 0, iTime(_Symbol, _Period, 1),
                compra ? iLow(_Symbol, _Period, 1) : iHigh(_Symbol, _Period, 1));
   ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, compra ? 233 : 234);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, compra ? clrLime : clrRed);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, compra ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Media do filtro de tendencia plotada no grafico                  |
//+------------------------------------------------------------------+
void DesenharMediaTendencia()
  {
   if(!MostrarMediaTendencia || TendenciaModo == TEND_DESLIGADO)
      return;

   int handle  = (TendenciaModo == TEND_INCLINACAO) ? g_hSMA : g_hMLonga;
   int periodo = (TendenciaModo == TEND_INCLINACAO) ? InclinacaoSMAPeriodo : MediaLongaPeriodo;
   int n = MathMin(BarrasDesenho, Bars(_Symbol, _Period) - periodo - 2);
   if(n < 1)
      return;

   double   ma[];
   datetime tm[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(tm, true);
   if(CopyBuffer(handle, 0, 0, n + 1, ma) < n + 1)
      return;
   if(CopyTime(_Symbol, _Period, 0, n + 1, tm) < n + 1)
      return;

   // Num candle novo redesenha tudo; no mesmo candle so o trecho atual se move
   int ate = (iTime(_Symbol, _Period, 0) != g_ultimaBarraDesenho) ? n : 1;
   for(int i = 0; i < ate; i++)
      Segmento(PFX + "MTend_" + IntegerToString(i), tm[i + 1], ma[i + 1], tm[i], ma[i],
               CorMediaTend, STYLE_SOLID, 2);
  }

void Segmento(string nome, datetime t1, double v1, datetime t0, double v0, color cor, int estilo, int largura)
  {
   if(v1 <= 0 || v0 <= 0)
      return;

   if(ObjectFind(0, nome) < 0)
     {
      ObjectCreate(0, nome, OBJ_TREND, 0, t1, v1, t0, v0);
      ObjectSetInteger(0, nome, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, nome, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
     }
   else
     {
      ObjectMove(0, nome, 0, t1, v1);
      ObjectMove(0, nome, 1, t0, v0);
     }
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, estilo);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, largura);
  }

//+------------------------------------------------------------------+
//| Painel do bot (canto superior esquerdo) - sem saldo/equity       |
//+------------------------------------------------------------------+
void AtualizarPainel(int total, int nCompra, double lotesC, double lotesV, double lucro,
                     double medio, double tp, double proxGrid, int dir)
  {
   AtualizarEstatisticas();

   double saldo    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = (saldo > 0 && equity < saldo) ? (saldo - equity) / saldo * 100.0 : 0;
   int    totalOps = g_wins + g_losses;
   double winRate  = (totalOps > 0) ? 100.0 * g_wins / totalOps : 0;
   double rr       = (g_wins > 0 && g_losses > 0 && g_somaPerdas > 0)
                     ? (g_somaGanhos / g_wins) / (g_somaPerdas / g_losses) : 0;

   string ladoGat = (dir == DIR_COMPRA) ? "COMPRA" : "VENDA";
   string candle  = (dir == DIR_COMPRA) ? "ALTA" : "BAIXA";
   color  corGat  = (dir == DIR_COMPRA) ? clrLime : clrRed;

   // Status do bot
   string status;
   color  corSt;
   if(total > 0)
     {
      status = (nCompra > 0 ? "Em COMPRA" : "Em VENDA") + " - " + IntegerToString(total) + " ordem(ns)";
      corSt  = (nCompra > 0) ? clrLime : clrRed;
     }
   else if(!TradePermitido())
     { status = "Trade bloqueado (ligue o Algo Trading)"; corSt = clrRed; }
   else if(UmaEntradaPorCandle && g_barraUltimaEntrada >= iTime(_Symbol, _Period, 0))
     { status = "Aguardando o proximo candle"; corSt = clrSilver; }
   else if(!HorarioPermite())
     { status = "Fora do horario de operacao"; corSt = clrOrange; }
   else if(!DirecaoPermite(dir))
     { status = "Gatilho de " + ladoGat + " ignorado: " + TextoDirecao(); corSt = clrOrange; }
   else if(!TendenciaPermite(dir))
     { status = "Gatilho de " + ladoGat + " bloqueado pela tendencia"; corSt = clrOrange; }
   else if(!UmaEntradaPorCandle)
     { status = "Aguardando abertura do proximo candle"; corSt = clrWhite; }
   else
     { status = "Pronto: entrada de " + ladoGat + " neste candle"; corSt = clrYellow; }

   int x = PainelX, y = PainelY, h = 17;
   LinhaPainel(0,  EA_Name_EA + " Monitor", 12, clrWhite, x, y);                                 y += 22;
   LinhaPainel(1,  _Symbol + " " + TextoTimeframe() + "   [" + TextoDirecao() + "]", 10, clrLime, x, y); y += h;
   LinhaPainel(2,  "Lucro Atual: " + DoubleToString(lucro, 2), 10, lucro >= 0 ? clrLime : clrRed, x, y); y += h;
   LinhaPainel(3,  "Drawdown: " + DoubleToString(drawdown, 2) + "%", 10, clrRed, x, y);         y += h;
   LinhaPainel(4,  "Win Rate: " + DoubleToString(winRate, 1) + "% (" + IntegerToString(g_wins) + "/" + IntegerToString(totalOps) + ")",
               10, (totalOps == 0 || winRate >= 50) ? clrLime : clrRed, x, y);                y += h + 6;
   LinhaPainel(5,  "Lucro Hoje: " + DoubleToString(g_lucroHoje, 2), 10, g_lucroHoje >= 0 ? clrLime : clrRed, x, y); y += h + 6;
   LinhaPainel(6,  "Lotes: C:" + DoubleToString(lotesC, 2) + " V:" + DoubleToString(lotesV, 2) + " T:" + DoubleToString(lotesC + lotesV, 2),
               10, clrDeepSkyBlue, x, y);                                                      y += h;
   LinhaPainel(7,  "R/R Medio: " + DoubleToString(rr, 2), 10, clrGold, x, y);                  y += h + 6;
   LinhaPainel(8,  "Grid: " + IntegerToString(total) + "/" + IntegerToString(MaxTrades) +
               "  (passo " + DoubleToString(Step, 0) + " pts, TP " + DoubleToString(TakeProfit, 0) + " pts)", 10, clrWhite, x, y); y += h;
   LinhaPainel(9,  "Preco medio: " + (medio > 0 ? DoubleToString(medio, _Digits) : "-") +
               "   TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "-"), 10, CorPrecoMedio, x, y); y += h;
   LinhaPainel(10, "Proximo grid: " + (proxGrid > 0 ? DoubleToString(proxGrid, _Digits) : "-"), 10, CorGrid, x, y); y += h;
   LinhaPainel(11, "Gatilho: ultimo candle de " + candle + " -> " + ladoGat, 10, corGat, x, y); y += h;
   LinhaPainel(12, "Tendencia: " + TextoTendencia(), 10, clrSilver, x, y);                    y += h;
   LinhaPainel(13, "Status: " + status, 10, corSt, x, y);
  }

void LinhaPainel(int linha, string texto, int tamanho, color cor, int x, int y)
  {
   CriarRotulo(PFX + "Painel_" + IntegerToString(linha), texto, "Arial", tamanho, cor,
               CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER, x, y);
  }

//+------------------------------------------------------------------+
//| Estatisticas do historico (relidas no maximo a cada 5 segundos)  |
//+------------------------------------------------------------------+
void AtualizarEstatisticas()
  {
   if(TimeCurrent() - g_ultimaLeituraHist < 5)
      return;
   g_ultimaLeituraHist = TimeCurrent();

   g_wins       = 0;
   g_losses     = 0;
   g_somaGanhos = 0;
   g_somaPerdas = 0;
   g_lucroHoje  = 0;

   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0;
   d.min  = 0;
   d.sec  = 0;
   datetime hoje = StructToTime(d);

   if(!HistorySelect(0, TimeCurrent() + 60))
      return;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0)
         continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tk, DEAL_MAGIC) != g_magic)
         continue;
      long entrada = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entrada != DEAL_ENTRY_OUT && entrada != DEAL_ENTRY_INOUT && entrada != DEAL_ENTRY_OUT_BY)
         continue;

      double r = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) +
                 HistoryDealGetDouble(tk, DEAL_COMMISSION);
      if(r > 0)      { g_wins++;   g_somaGanhos += r; }
      else if(r < 0) { g_losses++; g_somaPerdas -= r; }

      if((datetime)HistoryDealGetInteger(tk, DEAL_TIME) >= hoje)
         g_lucroHoje += r;
     }
  }

string TextoTimeframe()
  {
   string tf = EnumToString((ENUM_TIMEFRAMES)Period());   // ex.: PERIOD_M15
   return(StringSubstr(tf, 7));
  }

//+------------------------------------------------------------------+
//| Cria/atualiza um texto fixo na tela                              |
//+------------------------------------------------------------------+
void CriarRotulo(string nome, string texto, string fonte, int tamanho, color cor,
                 ENUM_BASE_CORNER canto, ENUM_ANCHOR_POINT ancora, int x, int y)
  {
   if(ObjectFind(0, nome) < 0)
     {
      ObjectCreate(0, nome, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nome, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, nome, OBJPROP_CORNER, canto);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, ancora);
   ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetString(0, nome, OBJPROP_FONT, fonte);
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, tamanho);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
  }
//+------------------------------------------------------------------+
