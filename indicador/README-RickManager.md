# RickManager (MT5) — Gestão Global de Meta e Stop

Gerenciador de conta **por ciclo**. Ele não opera: soma o resultado de **todas as posições
abertas** (qualquer par, qualquer robô, qualquer magic number) e, quando o ciclo bate a
**meta de lucro** ou o **limite de prejuízo**, **fecha tudo** e **desliga o AutoTrading** do
terminal — para os outros EAs não continuarem abrindo ordem.

- Código: `RickManager.mq5`
- Pronto pra usar (não precisa compilar): `downloads/RickManager.ex5`
- Página: https://rickea.vercel.app/ (categoria **Robôs / EAs**, grátis)

## Instalação

1. Baixe o **`RickManager.ex5`** na página.
2. MT5 → **Arquivo → Abrir Pasta de Dados** → `MQL5/Experts/` → cole o arquivo lá.
3. **Reinicie o MT5** (ou clique direito no Navegador → Atualizar).
4. Arraste **RickManager** para **um gráfico qualquer** (ele lê a conta inteira, não
   importa o par).
5. Na aba **Comum**, marque ☑ **Permitir importações DLL**.

> ### Por que precisa de DLL?
> Não existe função MQL5 que desligue o botão **AutoTrading**. É preciso falar com a janela do
> terminal pela `user32.dll`. O EA tenta dois caminhos, nessa ordem:
>
> 1. **`WM_COMMAND` / id `33020`** — o comando do botão, enviado direto para a janela. Silencioso,
>    não rouba o foco. **Não funciona em todo build do MT5.**
> 2. **`Ctrl+E` de verdade** (`keybd_event`) — traz o terminal para frente, aperta a tecla como
>    se fosse você e devolve o foco para a janela que estava antes. Se o Windows não deixar o
>    terminal vir para frente, ele **não** envia a tecla (senão ela cairia em outro programa).
>
> Se os dois falharem, vai para o **plano B**: fecha os outros gráficos, o que descarrega os
> EAs anexados a eles — funciona, mas você perde o layout.

## Como funciona o ciclo

1. Ao iniciar, ele grava o **saldo** como base do ciclo.
2. A cada tick/segundo calcula `PnL do ciclo = flutuante + (saldo atual − saldo base)`.
3. Bateu `InpTargetProfit` ou `InpTargetLoss` → **fecha todas as posições** → **apaga as ordens
   pendentes** → **desliga o AutoTrading** → fica em estado **PARADO**.
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
| `InpDeletePending` | true | apaga as ordens pendentes ao bater a meta |
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

## Histórico

### v1.20 — o que mudou

- **Segundo método para desligar o AutoTrading.** O `WM_COMMAND`/33020 sozinho falhou em conta
  real (build da FBS): o log mostrava `FALHA ao desligar` com o botão ainda aceso. Agora, se ele
  não resolver em 3 s, o EA manda um **`Ctrl+E` real** pelo teclado.
- **Apaga as ordens pendentes.** Essa era a maior brecha: pendente é executada **pelo servidor
  do broker**, o AutoTrading desligado não impede nada. Dava pra encerrar o ciclo "parado" e
  mesmo assim abrir posição minutos depois.
- **Log de diagnóstico no início** (`DLLs permitidas`, `AutoTrading`, `EA autorizado`) e o
  retorno do `PostMessage` no log, para saber qual método funcionou.
- Painel mostra **`Posições: X | Pendentes: Y`**.

### v1.10 — por que existiu

A versão original tinha dois problemas sérios:

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
