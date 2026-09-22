//+------------------------------------------------------------------+
//|                                                 RickManager.mq5  |
//|                          Gerenciador de Conta por Ciclo - MT5     |
//+------------------------------------------------------------------+
#property copyright "RickEA"
#property version   "1.20"
#property description "Gerenciador de conta por ciclo (lucro/prejuizo)"
#property description "Fecha TODAS as posicoes ao atingir target"
#property description "Desliga o botao AutoTrading: WM_COMMAND + Ctrl+E real"
#property description "Apaga tambem as ordens pendentes ao bater a meta"
#property description "Funciona por saldo total, nao por par"
#property description  "Telegram: https://t.me/+6jbcqyJ5O7YyNDgx "
#property description  "https://www.youtube.com/channel/UCVYoJ1Z9t5BpleQinwHD4Rw"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| WinAPI - necessario para desligar o botao AutoTrading             |
//| Requer: Ferramentas > Opcoes > Expert Advisors >                  |
//|         "Permitir importacoes DLL" MARCADO                        |
//+------------------------------------------------------------------+
#import "user32.dll"
   int  PostMessageW(long hWnd, uint Msg, long wParam, long lParam);
   long GetParent(long hWnd);
   long GetAncestor(long hWnd, uint gaFlags);
   long GetForegroundWindow();
   int  SetForegroundWindow(long hWnd);
   int  ShowWindow(long hWnd, int nCmdShow);
   int  IsIconic(long hWnd);
   void keybd_event(uchar bVk, uchar bScan, uint dwFlags, ulong dwExtraInfo);
#import

#define WM_COMMAND        0x0111
#define GA_ROOT           2
#define ID_AUTOTRADING    33020   // comando do botao AutoTrading (Ctrl+E) no MT5
#define VK_CONTROL        0x11
#define VK_KEY_E          0x45
#define KEYEVENTF_KEYUP   0x0002
#define SW_RESTORE        9

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input string   _hdr1_            = "=== GERENCIAMENTO POR CICLO ==="; // ========================
input double   InpTargetProfit   = 10.0;        // Meta de Lucro ($) - valor positivo
input double   InpTargetLoss     = -50000.0;    // Meta de Prejuizo ($) - valor negativo (ex: -5)
input bool     InpCloseOnTarget  = true;        // Fechar todas posicoes ao atingir meta
input bool     InpDeletePending  = true;        // Apagar ordens pendentes ao atingir meta
input bool     InpDisableAutoTrade = true;      // Desabilitar AutoTrading ao atingir meta
input bool     InpRemoveExpert   = false;       // Remover este EA do grafico ao parar
input bool     InpResumeOnManualEnable = true;  // Novo ciclo se religar AutoTrading na mao
input bool     InpCloseOtherChartsOnFail = true;// Se falhar: fechar outros graficos (mata os EAs)
input int      InpCooldownSec    = 5;           // Carencia apos novo ciclo (seg) - anti-churn

input string   _hdr2_            = "=== CONFIGURACOES ==="; // ========================
input int      InpCheckInterval  = 1;           // Intervalo de checagem (segundos)
input bool     InpIncludeSwap    = true;        // Incluir swap no calculo
input bool     InpIncludeComm    = true;        // Incluir comissao no calculo
input bool     InpShowPanel      = true;        // Mostrar painel no grafico
input int      InpPanelX         = 10;          // Painel posicao X
input int      InpPanelY         = 30;          // Painel posicao Y
input color    InpColorProfit    = clrLime;     // Cor lucro
input color    InpColorLoss      = clrRed;      // Cor prejuizo
input color    InpColorNeutral   = clrWhite;    // Cor neutro
input bool     InpAlertOnClose   = true;        // Alerta ao fechar ciclo
input int      InpFontSize       = 10;          // Tamanho da fonte do painel

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
CTrade   g_trade;
double   g_cycleStart    = 0;
int      g_cycleCount    = 1;
int      g_closedCycles  = 0;
double   g_lastCycleResult = 0;
datetime g_cycleStartTime = 0;
bool     g_closing       = false;
bool     g_stopped       = false;   // ciclo encerrado, aguardando religar AutoTrading
bool     g_autoDisabled  = false;   // true so se o AutoTrading foi realmente desligado
ulong    g_cooldownUntil = 0;       // trava o gatilho logo apos abrir um ciclo
ulong    g_lastWarn      = 0;       // ultimo alerta de "AutoTrading ainda ligado"
string   g_status        = "Ativo";

//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetDeviationInPoints(30);

   g_cycleStart     = AccountInfoDouble(ACCOUNT_BALANCE);
   g_cycleStartTime = TimeCurrent();
   g_cycleCount     = 1;
   g_closedCycles   = 0;
   g_closing        = false;
   g_stopped        = false;
   g_autoDisabled   = false;
   g_cooldownUntil  = 0;
   g_lastWarn       = 0;
   g_status         = "Ativo";

   if(InpShowPanel)
      CreatePanel();

   EventSetTimer(MathMax(InpCheckInterval, 1));

   Print("RickManager iniciado | Saldo inicial: ", g_cycleStart,
         " | Meta lucro: ", InpTargetProfit,
         " | Meta prejuizo: ", InpTargetLoss);

   Print("Diagnostico | DLLs permitidas: ",
         (MQLInfoInteger(MQL_DLLS_ALLOWED) ? "SIM" : "NAO"),
         " | AutoTrading: ",
         (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "LIGADO" : "DESLIGADO"),
         " | EA autorizado: ",
         (MQLInfoInteger(MQL_TRADE_ALLOWED) ? "SIM" : "NAO"));

   if(InpDisableAutoTrade && !MQLInfoInteger(MQL_DLLS_ALLOWED))
      Alert("RickManager: marque 'Permitir importacoes DLL' nas propriedades do EA, ",
            "senao o AutoTrading NAO sera desligado ao bater a meta.");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "RM_");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   CheckCycle();
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   CheckCycle();
  }

//+------------------------------------------------------------------+
void CheckCycle()
  {
   if(g_closing) return;

   double pnl = GetTotalFloatingPnL();
   double cyclePnL = pnl + (AccountInfoDouble(ACCOUNT_BALANCE) - g_cycleStart);

   // Ciclo ja encerrado: so observa o botao AutoTrading
   if(g_stopped)
     {
      if(InpShowPanel)
         UpdatePanel(cyclePnL, pnl);

      // nao conseguimos desligar: avisa a cada 30s ate o usuario agir
      if(!g_autoDisabled && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
         if(GetTickCount64() - g_lastWarn > 30000)
           {
            g_lastWarn = GetTickCount64();
            Alert("RickManager: ciclo encerrado mas o AutoTrading CONTINUA LIGADO! ",
                  "Desligue manualmente (Ctrl+E) - os EAs ainda podem abrir ordens.");
           }
         return;
        }

      // so retoma se o AutoTrading tinha sido desligado por nos e o usuario religou
      if(InpResumeOnManualEnable && g_autoDisabled &&
         TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
         Print("AutoTrading religado manualmente - iniciando novo ciclo");
         g_stopped = false;
         g_status  = "Ativo";
         StartNewCycle();
        }
      return;
     }

   if(InpShowPanel)
      UpdatePanel(cyclePnL, pnl);

   // carencia: evita disparar de novo antes de o saldo do fechamento anterior
   // aparecer na conta (era isso que gerava o ciclo abre/fecha comendo spread)
   if(GetTickCount64() < g_cooldownUntil)
      return;

   bool hitProfit = (InpTargetProfit > 0 && cyclePnL >= InpTargetProfit);
   bool hitLoss   = (InpTargetLoss < 0 && cyclePnL <= InpTargetLoss);

   if(hitProfit || hitLoss)
     {
      g_closing = true;
      string reason = hitProfit ? "META DE LUCRO" : "META DE PREJUIZO";

      Print("=== CICLO ", g_cycleCount, " ENCERRADO === ",
            reason, " | PnL: ", DoubleToString(cyclePnL, 2));

      // IMPORTANTE: fechar ANTES de desligar o AutoTrading.
      // Com o AutoTrading desligado o EA perde o direito de enviar ordens.
      if(InpCloseOnTarget)
         CloseAllAccountPositions();

      // ordens pendentes disparam no servidor mesmo com o AutoTrading
      // desligado - se nao apagar, o ciclo "parado" ainda abre posicao
      if(InpDeletePending)
         DeleteAllPendingOrders();

      g_lastCycleResult = cyclePnL;
      g_closedCycles++;

      if(InpAlertOnClose)
         Alert("RickManager: ", reason,
               " atingido! PnL ciclo: $", DoubleToString(cyclePnL, 2));

      if(InpDisableAutoTrade)
        {
         bool ok = DisableAutoTrading();

         g_autoDisabled = ok;
         g_stopped = true;
         g_closing = false;
         g_status  = ok ? "PARADO - AutoTrading OFF" : "PARADO - FALHA ao desligar";

         if(InpShowPanel)
            UpdatePanel(cyclePnL, pnl);

         // so sai do grafico se o AutoTrading foi mesmo desligado;
         // se falhou, o EA fica para continuar alertando
         if(InpRemoveExpert && ok)
           {
            Print("Removendo RickManager do grafico");
            ExpertRemove();
           }
         else if(InpRemoveExpert && !ok)
            Print("EA mantido no grafico: AutoTrading nao foi desligado");
         return;
        }

      StartNewCycle();
     }
  }

//+------------------------------------------------------------------+
//| Desliga de fato o botao AutoTrading do terminal.                  |
//| Nao existe funcao MQL5 para isso. Dois metodos, nessa ordem:      |
//|  1) WM_COMMAND/33020 para a janela principal (silencioso, mas     |
//|     nem todo build do MT5 aceita esse id de comando);             |
//|  2) Ctrl+E de verdade via keybd_event, exatamente como se voce    |
//|     apertasse no teclado (traz o terminal para frente e devolve   |
//|     o foco para a janela que estava antes).                       |
//+------------------------------------------------------------------+
bool DisableAutoTrading()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Print("AutoTrading ja estava desligado");
      return true;
     }

   if(MQLInfoInteger(MQL_TESTER))
     {
      Print("Modo tester: AutoTrading nao pode ser desligado pelo terminal");
      return false;   // no tester nao existe botao para desligar
     }

   if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
     {
      Print("ERRO: importacoes DLL bloqueadas - nao e possivel desligar o AutoTrading.");
      Alert("RickManager: NAO consegui desligar o AutoTrading. ",
            "Marque 'Permitir importacoes DLL' nas propriedades do EA e recarregue.");
      AutoTradeFallback();
      return false;
     }

   long hwnd = TerminalMainWindow();
   if(hwnd == 0)
     {
      Print("ERRO: janela principal do terminal nao encontrada");
      AutoTradeFallback();
      return false;
     }

   Print("Desligando AutoTrading | janela do terminal: ", hwnd);

   // --- Metodo 1: mensagem de comando (nao rouba o foco) ---
   for(int attempt = 1; attempt <= 2; attempt++)
     {
      int posted = PostMessageW(hwnd, WM_COMMAND, ID_AUTOTRADING, 0);
      Print("Metodo 1 (WM_COMMAND) tentativa ", attempt,
            " | PostMessage retornou ", posted);

      if(WaitAutoTradeOff(1500))
        {
         Print("AutoTrading DESABILITADO pelo metodo 1 (WM_COMMAND)");
         return true;
        }
     }

   // --- Metodo 2: Ctrl+E real no teclado ---
   for(int attempt = 1; attempt <= 2; attempt++)
     {
      Print("Metodo 2 (Ctrl+E real) tentativa ", attempt);

      if(!SendCtrlE(hwnd))
         break;

      if(WaitAutoTradeOff(2000))
        {
         Print("AutoTrading DESABILITADO pelo metodo 2 (Ctrl+E real)");
         return true;
        }
     }

   Print("ERRO: nao foi possivel desligar o AutoTrading pelos dois metodos");
   AutoTradeFallback();
   return false;
  }

//+------------------------------------------------------------------+
//| Espera o AutoTrading apagar (PostMessage e teclado sao assincronos)|
//+------------------------------------------------------------------+
bool WaitAutoTradeOff(int timeoutMs)
  {
   int steps = timeoutMs / 100;
   for(int i = 0; i < steps && !IsStopped(); i++)
     {
      Sleep(100);
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Manda um Ctrl+E de verdade para o terminal                        |
//+------------------------------------------------------------------+
bool SendCtrlE(long hwnd)
  {
   long prev = GetForegroundWindow();

   if(IsIconic(hwnd) != 0)
      ShowWindow(hwnd, SW_RESTORE);

   SetForegroundWindow(hwnd);
   Sleep(250);

   // se o Windows nao deixou o terminal vir para frente, NAO envia a
   // tecla: ela iria parar no programa que estiver em foco
   if(GetForegroundWindow() != hwnd)
     {
      Print("Nao consegui trazer o terminal para frente - Ctrl+E nao enviado");
      return false;
     }

   keybd_event(VK_CONTROL, 0, 0, 0);
   keybd_event(VK_KEY_E,   0, 0, 0);
   keybd_event(VK_KEY_E,   0, KEYEVENTF_KEYUP, 0);
   keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);

   Sleep(300);

   // devolve o foco para onde estava
   if(prev != 0 && prev != hwnd)
      SetForegroundWindow(prev);

   return true;
  }

//+------------------------------------------------------------------+
//| Plano B (sem DLL): fecha os outros graficos, o que descarrega     |
//| todos os EAs anexados a eles. Nao depende de permissao de DLL.    |
//+------------------------------------------------------------------+
void AutoTradeFallback()
  {
   if(InpCloseOtherChartsOnFail)
     {
      int killed = CloseOtherCharts();
      Print("Plano B: ", killed, " graficos fechados (EAs descarregados)");
      Alert("RickManager: nao consegui desligar o AutoTrading. ",
            killed, " graficos foram fechados para parar os EAs. ",
            "Desligue o AutoTrading manualmente (Ctrl+E).");
     }
   else
      Alert("RickManager: falha ao desligar o AutoTrading - ",
            "desligue manualmente (Ctrl+E) AGORA, os EAs continuam operando.");
  }

//+------------------------------------------------------------------+
//| Fecha todos os graficos menos o deste EA                          |
//+------------------------------------------------------------------+
int CloseOtherCharts()
  {
   long me = ChartID();
   long ids[];
   int  n = 0;

   // coleta antes de fechar: fechar durante a iteracao quebra o ChartNext
   long id = ChartFirst();
   while(id >= 0)
     {
      if(id != me)
        {
         ArrayResize(ids, n + 1);
         ids[n++] = id;
        }
      id = ChartNext(id);
     }

   for(int i = 0; i < n; i++)
     {
      Print("Fechando grafico ", ids[i], " ", ChartSymbol(ids[i]));
      ChartClose(ids[i]);
     }
   return n;
  }

//+------------------------------------------------------------------+
//| Handle da janela principal do MetaTrader                          |
//+------------------------------------------------------------------+
long TerminalMainWindow()
  {
   long chartWnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
   if(chartWnd == 0) return 0;

   long root = GetAncestor(chartWnd, GA_ROOT);
   if(root != 0) return root;

   // fallback: sobe a arvore de janelas ate a raiz
   long current = chartWnd;
   while(true)
     {
      long parent = GetParent(current);
      if(parent == 0) break;
      current = parent;
     }
   return current;
  }

//+------------------------------------------------------------------+
//| PnL flutuante total da conta (todas posicoes, todos pares)        |
//+------------------------------------------------------------------+
double GetTotalFloatingPnL()
  {
   double total = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);   // ja seleciona a posicao
      if(ticket == 0) continue;

      total += PositionGetDouble(POSITION_PROFIT);

      if(InpIncludeSwap)
         total += PositionGetDouble(POSITION_SWAP);

      if(InpIncludeComm)
         total += PositionCommission(PositionGetInteger(POSITION_IDENTIFIER));
     }

   return total;
  }

//+------------------------------------------------------------------+
//| Comissao acumulada nos deals da posicao                           |
//+------------------------------------------------------------------+
double PositionCommission(long positionId)
  {
   if(!HistorySelectByPosition(positionId))
      return 0;

   double comm = 0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
         comm += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
     }
   return comm;
  }

//+------------------------------------------------------------------+
//| Close ALL positions in the account (any symbol, any magic)        |
//+------------------------------------------------------------------+
void CloseAllAccountPositions()
  {
   int total = PositionsTotal();
   Print("Fechando ", total, " posicoes...");

   for(int attempt = 0; attempt < 5; attempt++)
     {
      int remaining = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         string sym = PositionGetString(POSITION_SYMBOL);
         g_trade.PositionClose(ticket);

         if(g_trade.ResultRetcode() == 10009 || g_trade.ResultRetcode() == 10008)
            Print("Fechada posicao #", ticket, " ", sym);
         else
           {
            Print("Erro fechando #", ticket, " ", sym,
                  " retcode=", g_trade.ResultRetcode());
            remaining++;
           }
        }

      if(PositionsTotal() == 0 || remaining == 0)
         break;

      Sleep(500);
     }

   Print("Posicoes restantes: ", PositionsTotal());
  }

//+------------------------------------------------------------------+
//| Apaga TODAS as ordens pendentes da conta                          |
//| Pendente dispara no servidor mesmo com o AutoTrading desligado.   |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
  {
   int total = OrdersTotal();
   if(total == 0)
      return;

   Print("Apagando ", total, " ordens pendentes...");

   for(int attempt = 0; attempt < 3; attempt++)
     {
      int remaining = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;

         string sym = OrderGetString(ORDER_SYMBOL);

         if(g_trade.OrderDelete(ticket))
            Print("Apagada pendente #", ticket, " ", sym);
         else
           {
            Print("Erro apagando pendente #", ticket, " ", sym,
                  " retcode=", g_trade.ResultRetcode());
            remaining++;
           }
        }

      if(OrdersTotal() == 0 || remaining == 0)
         break;

      Sleep(500);
     }

   Print("Ordens pendentes restantes: ", OrdersTotal());
  }

//+------------------------------------------------------------------+
//| Start a new cycle                                                 |
//+------------------------------------------------------------------+
void StartNewCycle()
  {
   // espera o saldo refletir os fechamentos: ler o saldo cedo demais deixava
   // a base do ciclo defasada e a meta disparava na primeira ordem seguinte
   WaitForAccountSettle();

   g_cycleCount++;
   g_cycleStart     = AccountInfoDouble(ACCOUNT_BALANCE);
   g_cycleStartTime = TimeCurrent();
   g_closing        = false;
   g_stopped        = false;
   g_autoDisabled   = false;
   g_cooldownUntil  = GetTickCount64() + (ulong)MathMax(InpCooldownSec, 0) * 1000;
   g_status         = "Ativo";

   Print("=== NOVO CICLO ", g_cycleCount, " INICIADO === Saldo: ",
         DoubleToString(g_cycleStart, 2));
  }

//+------------------------------------------------------------------+
//| Espera o saldo da conta parar de mudar apos os fechamentos        |
//+------------------------------------------------------------------+
void WaitForAccountSettle()
  {
   double last   = AccountInfoDouble(ACCOUNT_BALANCE);
   int    stable = 0;

   for(int i = 0; i < 40 && !IsStopped(); i++)   // ate ~6 segundos
     {
      Sleep(150);
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);

      if(bal == last && PositionsTotal() == 0)
        {
         stable++;
         if(stable >= 3)
            return;
        }
      else
        {
         stable = 0;
         last   = bal;
        }
     }

   Print("Aviso: saldo nao estabilizou em 6s (posicoes restantes: ",
         PositionsTotal(), ") - base do ciclo pode ficar imprecisa");
  }

//+------------------------------------------------------------------+
//| Panel functions                                                   |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   CreateLabel("RM_Title",   InpPanelX, InpPanelY,       "RickManager",           clrGold, InpFontSize + 2);
   CreateLabel("RM_Sep1",    InpPanelX, InpPanelY + 22,   "------------------------", clrGray, InpFontSize - 2);
   CreateLabel("RM_Cycle",   InpPanelX, InpPanelY + 38,   "Ciclo: 1",              InpColorNeutral, InpFontSize);
   CreateLabel("RM_Balance", InpPanelX, InpPanelY + 56,   "Saldo inicio: ...",     InpColorNeutral, InpFontSize);
   CreateLabel("RM_Float",   InpPanelX, InpPanelY + 74,   "Flutuante: ...",        InpColorNeutral, InpFontSize);
   CreateLabel("RM_CyclePnL",InpPanelX, InpPanelY + 92,   "PnL Ciclo: ...",        InpColorNeutral, InpFontSize);
   CreateLabel("RM_Target",  InpPanelX, InpPanelY + 110,  "Meta: ...",             InpColorNeutral, InpFontSize);
   CreateLabel("RM_Sep2",    InpPanelX, InpPanelY + 128,  "------------------------", clrGray, InpFontSize - 2);
   CreateLabel("RM_Closed",  InpPanelX, InpPanelY + 144,  "Ciclos fechados: 0",   InpColorNeutral, InpFontSize);
   CreateLabel("RM_Last",    InpPanelX, InpPanelY + 162,  "Ultimo resultado: -",   InpColorNeutral, InpFontSize);
   CreateLabel("RM_Pos",     InpPanelX, InpPanelY + 180,  "Posicoes abertas: 0",  InpColorNeutral, InpFontSize);
   CreateLabel("RM_Time",    InpPanelX, InpPanelY + 198,  "Tempo ciclo: -",       InpColorNeutral, InpFontSize);
   CreateLabel("RM_Auto",    InpPanelX, InpPanelY + 216,  "AutoTrading: -",       InpColorNeutral, InpFontSize);
   CreateLabel("RM_Status",  InpPanelX, InpPanelY + 234,  "Status: Ativo",        InpColorNeutral, InpFontSize);
  }

//+------------------------------------------------------------------+
void UpdatePanel(double cyclePnL, double floating)
  {
   color pnlColor = (cyclePnL > 0) ? InpColorProfit :
                     (cyclePnL < 0) ? InpColorLoss : InpColorNeutral;

   double pctToTarget = 0;
   if(cyclePnL >= 0 && InpTargetProfit > 0)
      pctToTarget = (cyclePnL / InpTargetProfit) * 100.0;
   else if(cyclePnL < 0 && InpTargetLoss < 0)
      pctToTarget = (cyclePnL / InpTargetLoss) * 100.0;

   long elapsed = (long)(TimeCurrent() - g_cycleStartTime);
   int hrs = (int)(elapsed / 3600);
   int mins = (int)((elapsed % 3600) / 60);

   SetLabelText("RM_Cycle",    "Ciclo: " + IntegerToString(g_cycleCount));
   SetLabelText("RM_Balance",  "Saldo inicio: $" + DoubleToString(g_cycleStart, 2));
   SetLabelText("RM_Float",    "Flutuante: $" + DoubleToString(floating, 2));

   ObjectSetInteger(0, "RM_Float", OBJPROP_COLOR,
                    (floating >= 0) ? InpColorProfit : InpColorLoss);

   SetLabelText("RM_CyclePnL", "PnL Ciclo: $" + DoubleToString(cyclePnL, 2) +
                " (" + DoubleToString(pctToTarget, 1) + "%)");
   ObjectSetInteger(0, "RM_CyclePnL", OBJPROP_COLOR, pnlColor);

   SetLabelText("RM_Target",   "Meta: +" + DoubleToString(InpTargetProfit, 2) +
                " / " + DoubleToString(InpTargetLoss, 2));

   SetLabelText("RM_Closed",   "Ciclos fechados: " + IntegerToString(g_closedCycles));
   if(g_closedCycles > 0)
     {
      SetLabelText("RM_Last",  "Ultimo resultado: $" + DoubleToString(g_lastCycleResult, 2));
      ObjectSetInteger(0, "RM_Last", OBJPROP_COLOR,
                       (g_lastCycleResult >= 0) ? InpColorProfit : InpColorLoss);
     }

   SetLabelText("RM_Pos",      "Posicoes: " + IntegerToString(PositionsTotal()) +
                " | Pendentes: " + IntegerToString(OrdersTotal()));
   SetLabelText("RM_Time",     "Tempo ciclo: " + IntegerToString(hrs) + "h " +
                IntegerToString(mins) + "m");

   bool autoOn = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   SetLabelText("RM_Auto",     "AutoTrading: " + (autoOn ? "LIGADO" : "DESLIGADO"));
   ObjectSetInteger(0, "RM_Auto", OBJPROP_COLOR,
                    autoOn ? InpColorProfit : InpColorLoss);

   SetLabelText("RM_Status",   "Status: " + g_status);
   ObjectSetInteger(0, "RM_Status", OBJPROP_COLOR,
                    g_stopped ? InpColorLoss : InpColorNeutral);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text,
                 color clr, int fontSize)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
void SetLabelText(string name, string text)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }
//+------------------------------------------------------------------+
