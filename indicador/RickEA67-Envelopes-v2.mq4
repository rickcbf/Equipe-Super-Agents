//+------------------------------------------------------------------+
//|                                        RickEA67-Envelopes-v2.mq4 |
//|                               Copyright 2024, RiCharTrader Ltd.  |
//|                                           https://t.me/RickEA_IA |
//+------------------------------------------------------------------+
//| Estrategia: reversao a media com Envelopes + RSI.                |
//|  Compra: preco toca/fura a banda inferior e RSI <= nivel baixo.  |
//|  Venda : preco toca/fura a banda superior e RSI >= nivel alto.   |
//|                                                                  |
//| v2.00                                                            |
//|  - Stop loss opcional (ATR ou pontos fixos)                      |
//|  - Take profit na media (SMA) ou na banda oposta                 |
//|  - Filtro de tendencia opcional (inclinacao da SMA / media longa)|
//|  - Magic number, filtro de spread, filtro de horario             |
//|  - Lote fixo ou por % de risco                                   |
//|  - Painel com preco grande (canto superior direito) e spread     |
//|  - Envelopes, media e sinais plotados no grafico, painel         |
//|    RickEA Monitor, nome do bot e Instagram nos cantos de baixo   |
//|  - Correcoes: ordens de terceiros, flags travadas, loop de       |
//|    fechamento e slippage                                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, RiCharTrader Ltd."
#property link      "https://t.me/RickEA_IA"
#property version   "2.12"
#property description "Envelopes + RSI (reversao a media) com SL, TP, filtros e lote por risco."
#property strict

//--- Tipos de configuracao
enum ENUM_SL_MODO
  {
   SL_DESLIGADO = 0,   // Sem stop loss
   SL_ATR       = 1,   // Stop por ATR
   SL_PONTOS    = 2    // Stop em pontos fixos
  };

enum ENUM_TP_MODO
  {
   TP_MEDIA        = 0, // Media (SMA) do Envelopes
   TP_BANDA_OPOSTA = 1  // Banda oposta
  };

enum ENUM_TENDENCIA_MODO
  {
   TEND_DESLIGADO   = 0, // Sem filtro de tendencia
   TEND_INCLINACAO  = 1, // Inclinacao da SMA do Envelopes
   TEND_MEDIA_LONGA = 2  // Preco acima/abaixo da media longa
  };

enum ENUM_LOTE_MODO
  {
   LOTE_FIXO  = 0,     // Lote fixo
   LOTE_RISCO = 1      // % de risco sobre o saldo
  };

//--- Parametros de entrada
input string              Sec1                = "===== SINAL =====";            // ===== SINAL =====
input int                 EnvelopesPeriod     = 20;     // Periodo do Envelopes (SMA)
input double              EnvelopesDeviation  = 0.40;   // Desvio do Envelopes (%)
input int                 RSIPeriod           = 6;      // Periodo do RSI
input double              RSILevelLow         = 20;     // RSI nivel baixo (compra)
input double              RSILevelHigh        = 80;     // RSI nivel alto (venda)
input bool                UsarCandleFechado   = false;  // Sinal so no candle fechado (false = tempo real, como o original)

input string              Sec2                = "===== STOP LOSS =====";        // ===== STOP LOSS =====
input ENUM_SL_MODO        StopModo            = SL_ATR; // Tipo de stop loss
input int                 ATRPeriodo          = 14;     // ATR: periodo
input double              ATRMultiplicador    = 1.5;    // ATR: multiplicador (stop = ATR x mult.)
input int                 StopPontos          = 300;    // Pontos fixos: distancia do stop (pontos)

input string              Sec3                = "===== TAKE PROFIT =====";      // ===== TAKE PROFIT =====
input ENUM_TP_MODO        TakeModo            = TP_MEDIA; // Alvo de saida
input bool                TPNaCorretora       = true;   // Gravar o TP na ordem (atualizado a cada candle)

input string              Sec4                = "===== FILTRO DE TENDENCIA =====";  // ===== FILTRO DE TENDENCIA =====
input ENUM_TENDENCIA_MODO TendenciaModo       = TEND_DESLIGADO; // Tipo de filtro de tendencia
input int                 InclinacaoBarras    = 5;      // Inclinacao: quantas barras para medir
input int                 InclinacaoMinPontos = 50;     // Inclinacao: minimo (pontos) para considerar tendencia
input int                 MediaLongaPeriodo   = 200;    // Media longa: periodo
input ENUM_MA_METHOD      MediaLongaMetodo    = MODE_EMA; // Media longa: metodo

input string              Sec5                = "===== LOTE / RISCO =====";     // ===== LOTE / RISCO =====
input ENUM_LOTE_MODO      LoteModo            = LOTE_FIXO; // Tipo de lote
input double              LotSize             = 0.01;   // Lote fixo
input double              RiscoPercentual     = 1.0;    // Risco por operacao (% do saldo) - exige stop

input string              Sec6                = "===== EXECUCAO / FILTROS =====";   // ===== EXECUCAO / FILTROS =====
input int                 MagicNumber         = 670067; // Magic number (identifica as ordens deste EA)
input int                 SpreadMaxPontos     = 30;     // Spread maximo para entrar (pontos, 0 = desligado)
input int                 SlippagePontos      = 30;     // Slippage maximo (pontos)
input bool                UsarFiltroHorario   = false;  // Usar filtro de horario (hora do servidor)
input int                 HoraInicio          = 8;      // Horario: hora de inicio
input int                 MinutoInicio        = 0;      // Horario: minuto de inicio
input int                 HoraFim             = 20;     // Horario: hora de fim
input int                 MinutoFim           = 0;      // Horario: minuto de fim
input string              Comentario          = "RickEA67 Envelopes+RSI"; // Comentario das ordens

input string              Sec7                = "===== PAINEL DE PRECO =====";  // ===== PAINEL DE PRECO =====
input bool                MostrarPreco        = true;     // Mostrar preco grande no canto superior direito
input int                 PrecoTamanho        = 28;       // Tamanho da fonte do preco
input int                 SpreadTamanho       = 12;       // Tamanho da fonte do spread
input color               CorPrecoAlta        = clrLime;  // Cor do preco subindo
input color               CorPrecoBaixa       = clrRed;   // Cor do preco caindo
input color               CorSpread           = clrGold;  // Cor do spread
input int                 PainelMargemX       = 10;       // Distancia da borda direita (pixels)
input int                 PainelMargemY       = 15;       // Distancia do topo (pixels)

input string              Sec8                = "===== VISUAL DO BOT =====";    // ===== VISUAL DO BOT =====
input bool                MostrarIndicadores  = true;     // Plotar Envelopes, media e media longa no grafico
input int                 BarrasDesenho       = 300;      // Quantos candles desenhar
input color               CorBandas           = clrDodgerBlue; // Cor das bandas do Envelopes
input color               CorMedia            = clrGold;  // Cor da media (SMA) do Envelopes
input color               CorMediaLonga       = clrOrange; // Cor da media longa (filtro de tendencia)
input bool                MostrarSinais       = true;     // Setas nos candles com confluencia Banda + RSI
input bool                MostrarPainel       = true;     // Painel RickEA Monitor (canto superior esquerdo)
input bool                MostrarRodape       = true;     // Nome do bot e Instagram nos cantos de baixo
input string              NomeBot             = "RickEA67-Envelopes"; // Nome exibido no grafico
input string              TextoInstagram      = "Instagram: @ri.chartrader"; // Propaganda (canto inferior direito)

//--- Variaveis globais
datetime g_ultimaEntrada  = 0;   // hora da ultima entrada (uma entrada por candle)
datetime g_ultimaBarraTP  = 0;   // ultima barra em que o TP foi atualizado
datetime g_ultimoReparo   = 0;   // ultima tentativa de colocar SL/TP faltando
datetime g_ultimoAvisoLote = 0;  // evita repetir aviso de lote por candle
double   g_ultimoBid      = 0;   // para colorir o preco (alta/baixa)
color    g_corPreco       = clrLime;
string   PFX              = "RickEA67_";       // prefixo de todos os objetos do grafico
string   OBJ_PRECO        = "RickEA67_Preco";
string   OBJ_SPREAD       = "RickEA67_Spread";
string   g_status         = "Iniciando...";    // o que o bot esta fazendo agora
color    g_corStatus      = clrWhite;
datetime g_ultimaBarraDesenho = 0;
int      g_histTotal      = -1;                // cache das estatisticas do historico
datetime g_histDia        = 0;
int      g_wins           = 0;
int      g_losses         = 0;
double   g_somaGanhos     = 0;
double   g_somaPerdas     = 0;
double   g_lucroHoje      = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(EnvelopesPeriod <= 0)    { Print("Periodo do Envelopes deve ser maior que zero"); return(INIT_PARAMETERS_INCORRECT); }
   if(EnvelopesDeviation <= 0) { Print("Desvio do Envelopes deve ser maior que zero");  return(INIT_PARAMETERS_INCORRECT); }
   if(RSIPeriod <= 0)          { Print("Periodo do RSI deve ser maior que zero");       return(INIT_PARAMETERS_INCORRECT); }
   if(RSILevelLow >= RSILevelHigh)
     { Print("RSI nivel baixo deve ser menor que o nivel alto"); return(INIT_PARAMETERS_INCORRECT); }

   if(StopModo == SL_ATR && (ATRPeriodo <= 0 || ATRMultiplicador <= 0))
     { Print("Stop por ATR: periodo e multiplicador devem ser maiores que zero"); return(INIT_PARAMETERS_INCORRECT); }
   if(StopModo == SL_PONTOS && StopPontos <= 0)
     { Print("Stop em pontos deve ser maior que zero"); return(INIT_PARAMETERS_INCORRECT); }

   if(TendenciaModo == TEND_INCLINACAO && (InclinacaoBarras <= 0 || InclinacaoMinPontos < 0))
     { Print("Filtro de inclinacao: parametros invalidos"); return(INIT_PARAMETERS_INCORRECT); }
   if(TendenciaModo == TEND_MEDIA_LONGA && MediaLongaPeriodo <= 0)
     { Print("Periodo da media longa deve ser maior que zero"); return(INIT_PARAMETERS_INCORRECT); }

   if(LoteModo == LOTE_FIXO && LotSize <= 0)
     { Print("Tamanho do lote deve ser maior que zero"); return(INIT_PARAMETERS_INCORRECT); }
   if(LoteModo == LOTE_RISCO)
     {
      if(StopModo == SL_DESLIGADO)
        { Print("Lote por % de risco exige stop loss ligado (ATR ou pontos)"); return(INIT_PARAMETERS_INCORRECT); }
      if(RiscoPercentual <= 0 || RiscoPercentual > 100)
        { Print("Risco percentual deve estar entre 0 e 100"); return(INIT_PARAMETERS_INCORRECT); }
     }

   if(SpreadMaxPontos < 0 || SlippagePontos < 0)
     { Print("Spread maximo e slippage nao podem ser negativos"); return(INIT_PARAMETERS_INCORRECT); }
   if(HoraInicio < 0 || HoraInicio > 23 || HoraFim < 0 || HoraFim > 23 ||
      MinutoInicio < 0 || MinutoInicio > 59 || MinutoFim < 0 || MinutoFim > 59)
     { Print("Filtro de horario: hora 0-23 e minuto 0-59"); return(INIT_PARAMETERS_INCORRECT); }

   // Recupera a ultima entrada deste EA (protege contra reentrada no mesmo candle apos reiniciar)
   g_ultimaEntrada = UltimaEntradaRegistrada();

   g_corPreco = CorPrecoAlta;
   g_ultimoBid = 0;
   g_ultimaBarraDesenho = 0;
   g_histTotal = -1;
   AtualizarVisual();

   Print("Bot Envelopes + RSI v2 iniciado com sucesso! Magic: ", MagicNumber);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
   Print("Bot Envelopes + RSI v2 finalizado!");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars < BarrasNecessarias())
     {
      DefinirStatus("Carregando historico...", clrSilver);
      AtualizarVisual();
      return;
     }

   // Saida pelo alvo, SL/TP faltando e atualizacao do TP
   GerenciarPosicoes();

   // Uma posicao por vez (somente as ordens deste EA contam)
   if(ContarPosicoes() > 0)
      DefinirStatusPosicao();
   else
      VerificarEntrada();

   AtualizarVisual();
  }

//+------------------------------------------------------------------+
//| Verificar condicoes para abrir posicoes                          |
//+------------------------------------------------------------------+
void VerificarEntrada()
  {
   if(!IsTradeAllowed())
     {
      DefinirStatus("Trade bloqueado (ligue o AutoTrading)", clrRed);
      return;
     }

   // Uma entrada por candle (evita reentrar no mesmo candle apos um stop)
   if(g_ultimaEntrada >= Time[0])
     {
      DefinirStatus("Aguardando o proximo candle", clrSilver);
      return;
     }

   int s = UsarCandleFechado ? 1 : 0;

   double upperBand = iEnvelopes(Symbol(), 0, EnvelopesPeriod, MODE_SMA, 0, PRICE_CLOSE, EnvelopesDeviation, MODE_UPPER, s);
   double lowerBand = iEnvelopes(Symbol(), 0, EnvelopesPeriod, MODE_SMA, 0, PRICE_CLOSE, EnvelopesDeviation, MODE_LOWER, s);
   double rsi       = iRSI(Symbol(), 0, RSIPeriod, PRICE_CLOSE, s);
   double preco     = Close[s];

   int tipo = -1;
   if(preco <= lowerBand && rsi <= RSILevelLow)
      tipo = OP_BUY;
   else if(preco >= upperBand && rsi >= RSILevelHigh)
      tipo = OP_SELL;

   if(tipo < 0)
     {
      DefinirStatus("Aguardando sinal (banda + RSI)", clrWhite);
      return;
     }

   string lado = (tipo == OP_BUY) ? "COMPRA" : "VENDA";
   if(!DentroDoHorario())
     {
      DefinirStatus("Sinal de " + lado + " ignorado: fora do horario", clrOrange);
      return;
     }
   if(!SpreadOk())
     {
      DefinirStatus("Sinal de " + lado + " ignorado: spread alto", clrOrange);
      return;
     }
   if(!TendenciaPermite(tipo))
     {
      DefinirStatus("Sinal de " + lado + " ignorado: contra a tendencia", clrOrange);
      return;
     }

   DefinirStatus("Sinal de " + lado + ": enviando ordem", clrYellow);
   AbrirOrdem(tipo);
  }

//+------------------------------------------------------------------+
//| Abre a ordem e grava SL/TP logo em seguida (compativel com ECN)  |
//+------------------------------------------------------------------+
void AbrirOrdem(int tipo)
  {
   RefreshRates();

   double dist = DistanciaStop();          // 0 quando o stop esta desligado
   double lote = CalcularLote(dist);
   if(lote <= 0)
     {
      DefinirStatus("Entrada ignorada: lote invalido", clrOrange);
      return;
     }

   ResetLastError();
   if(AccountFreeMarginCheck(Symbol(), tipo, lote) <= 0 || GetLastError() == 134)
     {
      Print("Margem insuficiente para abrir ", lote, " lotes");
      DefinirStatus("Entrada ignorada: margem insuficiente", clrRed);
      return;
     }

   double preco = (tipo == OP_BUY) ? Ask : Bid;
   color  cor   = (tipo == OP_BUY) ? clrGreen : clrRed;
   string nome  = (tipo == OP_BUY) ? "compra" : "venda";

   int ticket = OrderSend(Symbol(), tipo, lote, NormalizeDouble(preco, Digits), SlippagePontos,
                          0, 0, Comentario, MagicNumber, 0, cor);
   if(ticket < 0)
     {
      int erro = GetLastError();
      Print("Erro ao abrir ordem de ", nome, ". Erro: ", erro);
      DefinirStatus("Erro ao abrir " + nome + " (erro " + IntegerToString(erro) + ")", clrRed);
      return;
     }

   g_ultimaEntrada = TimeCurrent();
   Print("Ordem de ", nome, " aberta com sucesso. Ticket: ", ticket, " Lote: ", lote);

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   double abertura = OrderOpenPrice();
   double sl = 0;
   if(dist > 0)
      sl = NormalizeDouble((tipo == OP_BUY) ? abertura - dist : abertura + dist, Digits);

   double tp = TPNaCorretora ? TPValido(tipo, AlvoSaida(tipo)) : 0;

   if(sl != 0 || tp != 0)
      ModificarOrdem(ticket, abertura, sl, tp);
   // Se a modificacao falhar, GerenciarPosicoes tenta de novo nos proximos ticks
  }

//+------------------------------------------------------------------+
//| Gerencia as posicoes abertas deste EA                            |
//+------------------------------------------------------------------+
void GerenciarPosicoes()
  {
   bool novaBarra   = (Time[0] != g_ultimaBarraTP);
   bool podeReparar = (TimeCurrent() - g_ultimoReparo >= 5);

   // Loop de tras para frente: fechar uma ordem nao pula a proxima
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int tipo = OrderType();
      if(tipo != OP_BUY && tipo != OP_SELL)
         continue;

      RefreshRates();
      int    ticket   = OrderTicket();
      double abertura = OrderOpenPrice();
      double slAtual  = OrderStopLoss();
      double tpAtual  = OrderTakeProfit();
      double alvo     = AlvoSaida(tipo);

      // 1) Saida pelo alvo (media ou banda oposta), como no original
      if((tipo == OP_BUY && Bid >= alvo) || (tipo == OP_SELL && Bid <= alvo))
        {
         FecharOrdemSelecionada("alvo atingido");
         continue;
        }

      double slNovo = slAtual;
      double tpNovo = tpAtual;

      // 2) Stop faltando (falha na abertura ou EA reiniciado): coloca agora
      if(StopModo != SL_DESLIGADO && slAtual == 0 && podeReparar)
        {
         double dist = DistanciaStop();
         slNovo = NormalizeDouble((tipo == OP_BUY) ? abertura - dist : abertura + dist, Digits);

         // Preco ja passou do stop: fecha a mercado
         if((tipo == OP_BUY && Bid <= slNovo) || (tipo == OP_SELL && Ask >= slNovo))
           {
            FecharOrdemSelecionada("preco alem do stop");
            continue;
           }
         slNovo = SLValido(tipo, slNovo);
        }

      // 3) TP acompanha a linha-alvo a cada candle novo
      if(TPNaCorretora && (novaBarra || (tpAtual == 0 && podeReparar)))
        {
         double tpCalc = TPValido(tipo, alvo);
         if(tpCalc != 0)
            tpNovo = tpCalc;
        }

      if(MathAbs(slNovo - slAtual) >= Point / 2 || MathAbs(tpNovo - tpAtual) >= Point / 2)
        {
         if(!ModificarOrdem(ticket, abertura, slNovo, tpNovo))
            g_ultimoReparo = TimeCurrent();
        }
     }

   g_ultimaBarraTP = Time[0];
  }

//+------------------------------------------------------------------+
//| Fecha a ordem que esta selecionada                               |
//+------------------------------------------------------------------+
bool FecharOrdemSelecionada(string motivo)
  {
   RefreshRates();
   int    tipo  = OrderType();
   double preco = (tipo == OP_BUY) ? Bid : Ask;
   color  cor   = (tipo == OP_BUY) ? clrGreen : clrRed;
   string nome  = (tipo == OP_BUY) ? "compra" : "venda";

   if(OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(preco, Digits), SlippagePontos, cor))
     {
      Print("Ordem de ", nome, " fechada (", motivo, "). Ticket: ", OrderTicket());
      return(true);
     }

   Print("Erro ao fechar ordem de ", nome, ". Ticket: ", OrderTicket(), " Erro: ", GetLastError());
   return(false);
  }

//+------------------------------------------------------------------+
//| Altera SL/TP de uma ordem                                        |
//+------------------------------------------------------------------+
bool ModificarOrdem(int ticket, double abertura, double sl, double tp)
  {
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   if(OrderModify(ticket, NormalizeDouble(abertura, Digits), sl, tp, 0, clrNONE))
      return(true);

   Print("Erro ao definir SL/TP. Ticket: ", ticket, " SL: ", sl, " TP: ", tp, " Erro: ", GetLastError());
   return(false);
  }

//+------------------------------------------------------------------+
//| Linha-alvo de saida: media (SMA) ou banda oposta (candle atual)  |
//+------------------------------------------------------------------+
double AlvoSaida(int tipo)
  {
   if(TakeModo == TP_MEDIA)
      return(iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, 0));

   if(tipo == OP_BUY)
      return(iEnvelopes(Symbol(), 0, EnvelopesPeriod, MODE_SMA, 0, PRICE_CLOSE, EnvelopesDeviation, MODE_UPPER, 0));
   return(iEnvelopes(Symbol(), 0, EnvelopesPeriod, MODE_SMA, 0, PRICE_CLOSE, EnvelopesDeviation, MODE_LOWER, 0));
  }

//+------------------------------------------------------------------+
//| Distancia do stop em preco (0 = stop desligado)                  |
//+------------------------------------------------------------------+
double DistanciaStop()
  {
   double dist = 0;
   if(StopModo == SL_ATR)
      dist = iATR(Symbol(), 0, ATRPeriodo, 1) * ATRMultiplicador;
   else if(StopModo == SL_PONTOS)
      dist = StopPontos * Point;
   else
      return(0);

   // Respeita a distancia minima da corretora (stop level + spread)
   double minimo = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD) + 1) * Point;
   return(MathMax(dist, minimo));
  }

//+------------------------------------------------------------------+
//| Afasta o SL se estiver mais perto que o stop level               |
//+------------------------------------------------------------------+
double SLValido(int tipo, double sl)
  {
   double minDist = (MarketInfo(Symbol(), MODE_STOPLEVEL) + 1) * Point;
   if(tipo == OP_BUY && sl > Bid - minDist)
      sl = Bid - minDist;
   if(tipo == OP_SELL && sl < Ask + minDist)
      sl = Ask + minDist;
   return(NormalizeDouble(sl, Digits));
  }

//+------------------------------------------------------------------+
//| TP valido para a corretora (0 = muito perto, nao gravar)         |
//+------------------------------------------------------------------+
double TPValido(int tipo, double tp)
  {
   if(tp <= 0)
      return(0);
   double minDist = (MarketInfo(Symbol(), MODE_STOPLEVEL) + 1) * Point;
   if(tipo == OP_BUY && tp <= Bid + minDist)
      return(0);
   if(tipo == OP_SELL && tp >= Ask - minDist)
      return(0);
   return(NormalizeDouble(tp, Digits));
  }

//+------------------------------------------------------------------+
//| Lote fixo ou pelo % de risco sobre o saldo                       |
//+------------------------------------------------------------------+
double CalcularLote(double distStop)
  {
   double minLote = MarketInfo(Symbol(), MODE_MINLOT);

   if(LoteModo == LOTE_FIXO)
      return(NormalizarLote(MathMax(LotSize, minLote)));

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || distStop <= 0)
     {
      Print("Nao foi possivel calcular o lote por risco (tick value/size ou stop invalido)");
      return(0);
     }

   double riscoDinheiro = AccountBalance() * RiscoPercentual / 100.0;
   double perdaPorLote  = distStop / tickSize * tickValue;
   double lote          = NormalizarLote(riscoDinheiro / perdaPorLote);

   if(lote < minLote)
     {
      if(g_ultimoAvisoLote != Time[0])
        {
         Print("Lote pelo risco (", DoubleToString(riscoDinheiro / perdaPorLote, 4),
               ") abaixo do minimo da corretora (", minLote, "). Entrada ignorada.");
         g_ultimoAvisoLote = Time[0];
        }
      return(0);
     }
   return(lote);
  }

//+------------------------------------------------------------------+
//| Ajusta o lote ao passo e aos limites da corretora                |
//+------------------------------------------------------------------+
double NormalizarLote(double lote)
  {
   double passo  = MarketInfo(Symbol(), MODE_LOTSTEP);
   double maxLote = MarketInfo(Symbol(), MODE_MAXLOT);
   if(passo <= 0)
      passo = 0.01;

   lote = MathFloor(lote / passo + 1e-9) * passo;
   if(lote > maxLote)
      lote = maxLote;

   int casas = (int)MathMax(0, MathCeil(-MathLog10(passo) - 1e-9));
   return(NormalizeDouble(lote, casas));
  }

//+------------------------------------------------------------------+
//| Filtro de tendencia                                              |
//+------------------------------------------------------------------+
bool TendenciaPermite(int tipo)
  {
   if(TendenciaModo == TEND_DESLIGADO)
      return(true);

   if(TendenciaModo == TEND_INCLINACAO)
     {
      // Inclinacao da SMA do Envelopes em pontos (candles fechados)
      double smaAtual = iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
      double smaAntes = iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, 1 + InclinacaoBarras);
      double inclinacao = (smaAtual - smaAntes) / Point;

      // Nao compra com a media caindo forte, nao vende com a media subindo forte
      if(tipo == OP_BUY)
         return(inclinacao > -InclinacaoMinPontos);
      return(inclinacao < InclinacaoMinPontos);
     }

   // Media longa: compra so acima dela, vende so abaixo
   double mediaLonga = iMA(Symbol(), 0, MediaLongaPeriodo, 0, MediaLongaMetodo, PRICE_CLOSE, 1);
   if(tipo == OP_BUY)
      return(Close[1] > mediaLonga);
   return(Close[1] < mediaLonga);
  }

//+------------------------------------------------------------------+
//| Filtro de spread                                                 |
//+------------------------------------------------------------------+
bool SpreadOk()
  {
   if(SpreadMaxPontos <= 0)
      return(true);
   return(MarketInfo(Symbol(), MODE_SPREAD) <= SpreadMaxPontos);
  }

//+------------------------------------------------------------------+
//| Filtro de horario (hora do servidor, aceita virada de dia)       |
//+------------------------------------------------------------------+
bool DentroDoHorario()
  {
   if(!UsarFiltroHorario)
      return(true);

   datetime agora = TimeCurrent();
   int minutos = TimeHour(agora) * 60 + TimeMinute(agora);
   int inicio  = HoraInicio * 60 + MinutoInicio;
   int fim     = HoraFim * 60 + MinutoFim;

   if(inicio == fim)
      return(true);
   if(inicio < fim)
      return(minutos >= inicio && minutos < fim);
   return(minutos >= inicio || minutos < fim);   // ex.: 22:00 ate 06:00
  }

//+------------------------------------------------------------------+
//| Quantas posicoes deste EA estao abertas neste simbolo            |
//+------------------------------------------------------------------+
int ContarPosicoes()
  {
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
         total++;
     }
   return(total);
  }

//+------------------------------------------------------------------+
//| Hora da ultima entrada deste EA (abertas e historico)            |
//+------------------------------------------------------------------+
datetime UltimaEntradaRegistrada()
  {
   datetime ultima = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderOpenTime() > ultima)
            ultima = OrderOpenTime();

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderOpenTime() > ultima)
            ultima = OrderOpenTime();

   return(ultima);
  }

//+------------------------------------------------------------------+
//| Painel: preco grande no canto superior direito + spread abaixo   |
//+------------------------------------------------------------------+
void AtualizarPainelPreco()
  {
   if(!MostrarPreco)
      return;

   RefreshRates();
   if(g_ultimoBid > 0)
     {
      if(Bid > g_ultimoBid)
         g_corPreco = CorPrecoAlta;
      else if(Bid < g_ultimoBid)
         g_corPreco = CorPrecoBaixa;
     }
   g_ultimoBid = Bid;

   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);

   CriarRotulo(OBJ_PRECO, DoubleToString(Bid, Digits), "Arial Bold", PrecoTamanho, g_corPreco,
               CORNER_RIGHT_UPPER, ANCHOR_RIGHT_UPPER, PainelMargemX, PainelMargemY);
   // Spread logo abaixo do preco, alinhado pela direita
   int ySpread = PainelMargemY + (int)MathRound(PrecoTamanho * 1.6) + 4;
   CriarRotulo(OBJ_SPREAD, "Spread: " + IntegerToString(spread), "Arial Bold", SpreadTamanho, CorSpread,
               CORNER_RIGHT_UPPER, ANCHOR_RIGHT_UPPER, PainelMargemX, ySpread);
  }

//+------------------------------------------------------------------+
//| Atualiza tudo que aparece no grafico                             |
//+------------------------------------------------------------------+
void AtualizarVisual()
  {
   // No testador sem modo visual nao desenha nada (mais rapido)
   if(IsTesting() && !IsVisualMode())
      return;

   AtualizarPainelPreco();
   DesenharIndicadores();
   AtualizarPainel();
   AtualizarRodape();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Status mostrado no painel                                        |
//+------------------------------------------------------------------+
void DefinirStatus(string texto, color cor)
  {
   g_status    = texto;
   g_corStatus = cor;
  }

void DefinirStatusPosicao()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY)
        { DefinirStatus("Em COMPRA - alvo: " + DoubleToString(AlvoSaida(OP_BUY), Digits), clrLime); return; }
      if(OrderType() == OP_SELL)
        { DefinirStatus("Em VENDA - alvo: " + DoubleToString(AlvoSaida(OP_SELL), Digits), clrRed); return; }
     }
  }

//+------------------------------------------------------------------+
//| Envelopes, media, media longa e setas de sinal no grafico        |
//+------------------------------------------------------------------+
void DesenharIndicadores()
  {
   if(!MostrarIndicadores && !MostrarSinais)
      return;

   int n = MathMin(BarrasDesenho, Bars - BarrasNecessarias() - 1);
   if(n < 1)
      return;

   bool primeiraVez = (g_ultimaBarraDesenho == 0);
   bool novaBarra   = (Time[0] != g_ultimaBarraDesenho);

   // Num candle novo redesenha tudo; no mesmo candle so o trecho atual se move
   int ate = novaBarra ? n : 1;

   if(MostrarIndicadores)
     {
      for(int i = 0; i < ate; i++)
        {
         string id = IntegerToString(i);
         Segmento(PFX + "EnvSup_" + id, i, Envelope(MODE_UPPER, i + 1), Envelope(MODE_UPPER, i), CorBandas, STYLE_SOLID, 2);
         Segmento(PFX + "EnvInf_" + id, i, Envelope(MODE_LOWER, i + 1), Envelope(MODE_LOWER, i), CorBandas, STYLE_SOLID, 2);
         Segmento(PFX + "EnvMed_" + id, i, MediaEnvelope(i + 1), MediaEnvelope(i), CorMedia, STYLE_DOT, 1);

         if(TendenciaModo == TEND_MEDIA_LONGA)
            Segmento(PFX + "MLonga_" + id, i,
                     iMA(Symbol(), 0, MediaLongaPeriodo, 0, MediaLongaMetodo, PRICE_CLOSE, i + 1),
                     iMA(Symbol(), 0, MediaLongaPeriodo, 0, MediaLongaMetodo, PRICE_CLOSE, i),
                     CorMediaLonga, STYLE_SOLID, 2);
        }
     }

   // Setas: candle fechado com preco na banda e RSI no nivel
   if(MostrarSinais && novaBarra)
     {
      int ultimo = primeiraVez ? n : 1;
      for(int k = 1; k <= ultimo; k++)
        {
         double rsi = iRSI(Symbol(), 0, RSIPeriod, PRICE_CLOSE, k);
         if(Close[k] <= Envelope(MODE_LOWER, k) && rsi <= RSILevelLow)
            Seta(PFX + "SigC_" + IntegerToString((long)Time[k]), Time[k], Low[k], 233, clrLime, ANCHOR_TOP);
         else if(Close[k] >= Envelope(MODE_UPPER, k) && rsi >= RSILevelHigh)
            Seta(PFX + "SigV_" + IntegerToString((long)Time[k]), Time[k], High[k], 234, clrRed, ANCHOR_BOTTOM);
        }
     }

   g_ultimaBarraDesenho = Time[0];
  }

double Envelope(int linha, int shift)
  {
   return(iEnvelopes(Symbol(), 0, EnvelopesPeriod, MODE_SMA, 0, PRICE_CLOSE, EnvelopesDeviation, linha, shift));
  }

double MediaEnvelope(int shift)
  {
   return(iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, shift));
  }

//+------------------------------------------------------------------+
//| Um trecho de linha entre o candle i+1 e o candle i               |
//+------------------------------------------------------------------+
void Segmento(string nome, int i, double v1, double v0, color cor, int estilo, int largura)
  {
   if(v1 <= 0 || v0 <= 0)
      return;

   if(ObjectFind(0, nome) < 0)
     {
      ObjectCreate(0, nome, OBJ_TREND, 0, Time[i + 1], v1, Time[i], v0);
      ObjectSetInteger(0, nome, OBJPROP_RAY, false);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nome, OBJPROP_BACK, false);
     }
   else
     {
      ObjectMove(0, nome, 0, Time[i + 1], v1);
      ObjectMove(0, nome, 1, Time[i], v0);
     }
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, estilo);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, largura);
  }

//+------------------------------------------------------------------+
//| Seta de sinal                                                    |
//+------------------------------------------------------------------+
void Seta(string nome, datetime t, double preco, int codigo, color cor, int ancora)
  {
   if(ObjectFind(0, nome) >= 0)
      return;
   ObjectCreate(0, nome, OBJ_ARROW, 0, t, preco);
   ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, codigo);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, ancora);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Painel RickEA Monitor (canto superior esquerdo)                  |
//+------------------------------------------------------------------+
void AtualizarPainel()
  {
   if(!MostrarPainel)
      return;

   AtualizarEstatisticas();

   // Posicoes abertas deste EA
   double lucroAtual = 0, lotesC = 0, lotesV = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY)
         lotesC += OrderLots();
      else if(OrderType() == OP_SELL)
         lotesV += OrderLots();
      else
         continue;
      lucroAtual += OrderProfit() + OrderSwap() + OrderCommission();
     }

   double saldo    = AccountBalance();
   double drawdown = (saldo > 0 && AccountEquity() < saldo) ? (saldo - AccountEquity()) / saldo * 100.0 : 0;
   int    totalOps = g_wins + g_losses;
   double winRate  = (totalOps > 0) ? 100.0 * g_wins / totalOps : 0;
   double rr       = (g_wins > 0 && g_losses > 0 && g_somaPerdas > 0)
                     ? (g_somaGanhos / g_wins) / (g_somaPerdas / g_losses) : 0;

   double rsi  = iRSI(Symbol(), 0, RSIPeriod, PRICE_CLOSE, 0);
   color  corR = (rsi <= RSILevelLow) ? clrLime : (rsi >= RSILevelHigh) ? clrRed : clrWhite;

   int x = 10, y = 20, h = 17;
   LinhaPainel(0,  "RickEA Monitor", 12, clrWhite, x, y);
   y += 22;
   LinhaPainel(1,  Symbol() + " " + TextoTimeframe(), 10, clrLime, x, y);                         y += h;
   LinhaPainel(2,  "Lucro Atual: " + DoubleToString(lucroAtual, 2), 10, lucroAtual >= 0 ? clrLime : clrRed, x, y); y += h;
   LinhaPainel(3,  "Drawdown: " + DoubleToString(drawdown, 2) + "%", 10, clrRed, x, y);            y += h;
   LinhaPainel(4,  "Win Rate: " + DoubleToString(winRate, 1) + "% (" + IntegerToString(g_wins) + "/" + IntegerToString(totalOps) + ")",
               10, (totalOps == 0 || winRate >= 50) ? clrLime : clrRed, x, y);                   y += h + 6;
   LinhaPainel(5,  "Lucro Hoje: " + DoubleToString(g_lucroHoje, 2), 10, g_lucroHoje >= 0 ? clrLime : clrRed, x, y); y += h + 6;
   LinhaPainel(6,  "Lotes: C:" + DoubleToString(lotesC, 2) + " V:" + DoubleToString(lotesV, 2) + " T:" + DoubleToString(lotesC + lotesV, 2),
               10, clrDeepSkyBlue, x, y);                                                         y += h;
   LinhaPainel(7,  "R/R Medio: " + DoubleToString(rr, 2), 10, clrGold, x, y);                     y += h + 6;
   LinhaPainel(8,  "RSI(" + IntegerToString(RSIPeriod) + "): " + DoubleToString(rsi, 1) +
               "  [" + DoubleToString(RSILevelLow, 0) + "/" + DoubleToString(RSILevelHigh, 0) + "]", 10, corR, x, y); y += h;
   LinhaPainel(9,  "Tendencia: " + TextoTendencia(), 10, clrSilver, x, y);                        y += h;
   LinhaPainel(10, "Status: " + g_status, 10, g_corStatus, x, y);
  }

void LinhaPainel(int linha, string texto, int tamanho, color cor, int x, int y)
  {
   CriarRotulo(PFX + "Painel_" + IntegerToString(linha), texto, "Arial", tamanho, cor,
               CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER, x, y);
  }

//+------------------------------------------------------------------+
//| Estatisticas do historico (so recalcula quando muda)             |
//+------------------------------------------------------------------+
void AtualizarEstatisticas()
  {
   datetime hoje  = StrToTime(TimeToStr(TimeCurrent(), TIME_DATE));
   int      total = OrdersHistoryTotal();
   if(total == g_histTotal && hoje == g_histDia)
      return;

   g_histTotal  = total;
   g_histDia    = hoje;
   g_wins       = 0;
   g_losses     = 0;
   g_somaGanhos = 0;
   g_somaPerdas = 0;
   g_lucroHoje  = 0;

   for(int i = total - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      double r = OrderProfit() + OrderSwap() + OrderCommission();
      if(r > 0)      { g_wins++;   g_somaGanhos += r; }
      else if(r < 0) { g_losses++; g_somaPerdas -= r; }

      if(OrderCloseTime() >= hoje)
         g_lucroHoje += r;
     }
  }

string TextoTimeframe()
  {
   string tf = EnumToString((ENUM_TIMEFRAMES)Period());   // ex.: PERIOD_M15
   return(StringSubstr(tf, 7));
  }

string TextoTendencia()
  {
   if(TendenciaModo == TEND_DESLIGADO)
      return("filtro desligado");

   if(TendenciaModo == TEND_INCLINACAO)
     {
      double incl = (iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, 1) -
                     iMA(Symbol(), 0, EnvelopesPeriod, 0, MODE_SMA, PRICE_CLOSE, 1 + InclinacaoBarras)) / Point;
      string d = (incl > InclinacaoMinPontos) ? "ALTA" : (incl < -InclinacaoMinPontos) ? "BAIXA" : "LATERAL";
      return(d + " (incl. " + DoubleToString(incl, 0) + " pts)");
     }

   double ml = iMA(Symbol(), 0, MediaLongaPeriodo, 0, MediaLongaMetodo, PRICE_CLOSE, 1);
   return((Close[1] > ml ? "ALTA" : "BAIXA") + " (media " + IntegerToString(MediaLongaPeriodo) + ")");
  }

//+------------------------------------------------------------------+
//| Nome do bot (inferior esquerdo) e Instagram (inferior direito)   |
//+------------------------------------------------------------------+
void AtualizarRodape()
  {
   if(!MostrarRodape)
      return;

   string fonte = "Times New Roman";

   // Canto inferior esquerdo: nome do bot
   CriarRotulo(PFX + "NomeEsq", NomeBot, fonte, 20, clrLime, CORNER_LEFT_LOWER, ANCHOR_LEFT_LOWER, 10, 10);

   // Canto inferior direito: bloco empilhado de baixo para cima
   int x = 10, y = 8;
   // BALANCE e EQUITY removidos da tela para nao expor o saldo da conta
   CriarRotulo(PFX + "Rod_Orders",  "ALL ORDERS:  " + IntegerToString(OrdersTotal()), fonte, 14, clrYellow,    CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, x, y); y += 24;
   CriarRotulo(PFX + "Rod_Time",    "TIME:  " + TimeToStr(TimeCurrent(), TIME_MINUTES),  fonte, 14, clrWhite,      CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, x, y); y += 24;
   CriarRotulo(PFX + "Rod_Date",    "DATE:  " + TimeToStr(TimeCurrent(), TIME_DATE),     fonte, 14, clrWhite,      CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, x, y); y += 26;
   CriarRotulo(PFX + "Rod_Nome",    NomeBot,                                             fonte, 20, clrBlue,       CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, x, y); y += 32;
   CriarRotulo(PFX + "Rod_Insta",   TextoInstagram,                                      fonte, 16, clrRed,        CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER, x, y);
  }

//+------------------------------------------------------------------+
//| Cria/atualiza um texto fixo na tela                              |
//+------------------------------------------------------------------+
void CriarRotulo(string nome, string texto, string fonte, int tamanho, color cor,
                 int canto, int ancora, int x, int y)
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
//| Barras minimas para os indicadores                               |
//+------------------------------------------------------------------+
int BarrasNecessarias()
  {
   int n = MathMax(EnvelopesPeriod, RSIPeriod);
   if(StopModo == SL_ATR)
      n = MathMax(n, ATRPeriodo);
   if(TendenciaModo == TEND_INCLINACAO)
      n = MathMax(n, EnvelopesPeriod + InclinacaoBarras);
   if(TendenciaModo == TEND_MEDIA_LONGA)
      n = MathMax(n, MediaLongaPeriodo);
   return(n + 2);
  }
//+------------------------------------------------------------------+
