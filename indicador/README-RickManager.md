# RickManager (MT5) — Gestão Global de Meta e Stop

Gerenciador de conta **por ciclo**. Ele não opera: soma o resultado de **todas as posições
abertas** (qualquer par, qualquer robô, qualquer magic number) e, quando o ciclo bate a
**meta de lucro** ou o **limite de prejuízo**, **fecha tudo** e **desliga o AutoTrading** do
terminal — para os outros EAs não continuarem abrindo ordem.

- Código: `RickManager.mq5`
- Pronto pra usar (não precisa compilar): `downloads/RickManager-V2.ex5`
- Página: https://rickea.vercel.app/ (categoria **Robôs / EAs**, grátis)

## Instalação

1. Baixe o **`RickManager-V2.ex5`** na página.
2. MT5 → **Arquivo → Abrir Pasta de Dados** → `MQL5/Experts/` → cole o arquivo lá.
3. **Reinicie o MT5** (ou clique direito no Navegador → Atualizar).
4. Arraste **RickManager-V2** para **um gráfico qualquer** (ele lê a conta inteira, não
   importa o par).
5. Na aba **Comum**, marque ☑ **Permitir importações DLL**.

> ### Por que precisa de DLL?
> Não existe função MQL5 que desligue o botão **AutoTrading**. O único jeito é mandar o mesmo
> comando do `Ctrl+E` para a janela do terminal (`WM_COMMAND` / id `33020`) via `user32.dll`.
> Sem essa permissão, o EA cai no **plano B**: fecha os outros gráficos, o que descarrega os
> EAs anexados a eles — funciona, mas você perde o layout.

## Como funciona o ciclo

1. Ao iniciar, ele grava o **saldo** como base do ciclo.
2. A cada tick/segundo calcula `PnL do ciclo = flutuante + (saldo atual − saldo base)`.
3. Bateu `InpTargetProfit` ou `InpTargetLoss` → **fecha todas as posições** → **desliga o
   AutoTrading** → fica em estado **PARADO**.
4. Se você religar o AutoTrading na mão (`Ctrl+E`), ele abre um **ciclo novo** com a base
   atualizada (`InpResumeOnManualEnable`).

**A ordem importa:** ele fecha as posições *antes* de desligar o AutoTrading, porque sem o
AutoTrading o próprio EA perde o direito de enviar ordens.

## Parâmetros principais

| Parâmetro | Padrão | O que faz |
|---|---|---|
| `InpTargetProfit` | 10.0 | meta de lucro em $ (positivo) |
| `InpTargetLoss` | -50000.0 | limite de prejuízo em $ (negativo) |
| `InpCloseOnTarget` | true | fecha todas as posições ao bater a meta |
| `InpDisableAutoTrade` | true | desliga o AutoTrading ao bater a meta |
| `InpCloseOtherChartsOnFail` | true | plano B sem DLL: fecha os outros gráficos |
| `InpCooldownSec` | 5 | carência após abrir um ciclo (anti-churn) |
| `InpRemoveExpert` | false | remover o EA do gráfico ao parar |
| `InpResumeOnManualEnable` | true | novo ciclo se você religar o AutoTrading |
| `InpIncludeSwap` / `InpIncludeComm` | true | incluir swap e comissão no cálculo |
| `InpCheckInterval` | 1 | intervalo de checagem, em segundos |

## Painel no gráfico

Ciclo, saldo base, flutuante, **PnL do ciclo com % da meta**, metas, ciclos fechados, último
resultado, posições abertas, tempo do ciclo, **estado do AutoTrading** (LIGADO/DESLIGADO) e
**status** do gerenciador.

## Por que a v2 (1.10)

A versão anterior tinha dois problemas sérios:

- `InpDisableAutoTrade` só chamava `ExpertRemove()` — isso **removia o RickManager** do gráfico
  e deixava o AutoTrading ligado. O guardião saía e os robôs continuavam operando.
- `StartNewCycle()` lia o saldo **antes** de os fechamentos caírem na conta. A base do ciclo
  nascia defasada no valor do lucro, a meta disparava de novo na primeira ordem seguinte e
  virava um ciclo abre/fecha **comendo spread**. Corrigido com `WaitForAccountSettle()` + a
  carência de `InpCooldownSec`.

Também foi corrigido o cálculo de comissão, que re-selecionava a posição por símbolo dentro do
laço e podia somar a comissão de outra posição.

## Avisos

- Teste em **conta demo** primeiro, com meta baixa, e confira no log a linha
  `AutoTrading DESABILITADO` e o botão ficando cinza.
- No **Testador de Estratégia** não existe botão de AutoTrading para desligar.
- Ele fecha **todas** as posições da conta, inclusive as abertas na mão.
