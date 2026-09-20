# RickEA FIBO GRID (robô / EA para MT5)

Robô que opera **grid nas retrações de Fibonacci da pernada**.

Arquivo: `RickEA_FiboGrid_EA.mq5` · prefixo dos objetos no gráfico: `FG_`

## A estratégia, na ordem em que o robô pensa

1. **Acha a pernada.** Usa topo/fundo por fractal (`InpSwingDepth` barras de cada lado) e pega os
   **dois últimos pontos de reversão alternados**. Se o preço já foi além do último topo/fundo, o
   extremo é estendido. Pernada menor que `InpMinLegPoints` é ignorada.
2. **Marca a FIBO.** O extremo da pernada é o **0%**, a origem é o **100%**.
   - Pernada de **alta** → zona de **VENDA** (vermelha) entre **0% e 38.2%**.
   - Pernada de **queda** → zona de **COMPRA** (verde) entre **0% e 38.2%**.
   Retângulo com opacidade baixa (`InpOpacity = 18`, o mesmo do RickEA TOP/BOTTOM), atrás das velas.
3. **Arma o grid dentro da zona.** Enquanto o preço estiver entre `InpFibFrom` (0%) e
   `InpFibTo` (38.2%), abre ordens **a favor da retração** (vende na retração da alta, compra na
   retração da queda), respeitando o espaçamento `InpGridPoints` em relação à ordem mais próxima.
   **Chegou no 38.2% → para de abrir ordens** (as que estão abertas continuam).
4. **Stop fora da pernada.** A pernada vai de 0 a 1; se o preço voltar **`InpFibStop`% da pernada
   para fora do extremo** (padrão **23%**, ou seja 0→1 e mais 0,23 além do extremo), **fecha tudo**
   e **não reentra nessa pernada** — só volta a operar quando aparecer outra pernada (nova origem).
   Com `InpAttachSL = true` esse nível também vai como **SL de cada ordem**, então a proteção fica
   no servidor mesmo se o MT5 cair.
5. **Take na cesta.** Junta tudo (preço médio) e encerra **todas** as ordens de uma vez:
   - `TP_MONEY_TOTAL` (padrão) — bateu **US$ `InpTPMoney`** de lucro flutuante na soma → fecha tudo.
     É o "juntou 3 médio, bateu 2 dólares, encerra".
   - `TP_MONEY_PER_POS` — o alvo é `InpTPMoney × número de ordens` (3 ordens × US$ 2 = US$ 6).
   - `TP_POINTS_AVG` — alvo em **pontos a partir do preço médio** (`InpTPPoints`).

## Instalação
1. MT5 → **Arquivo → Abrir Pasta de Dados** → entre em `MQL5/Experts/`.
2. **Copie o arquivo `RickEA_FiboGrid_EA.mq5` para essa pasta** (o arquivo inteiro, não copiar/colar
   o texto).
3. No **MetaEditor**: **Arquivo → Abrir** → escolha o arquivo → **Compilar (F7)**.
4. No gráfico: **Navegador → Consultores Especialistas → RickEA_FiboGrid_EA** (arraste pro gráfico)
   e deixe o **AutoTrading ligado**.

> **Se for colar o código dentro do MetaEditor:** crie o arquivo pelo assistente e depois
> **apague TUDO que o assistente gerou** (`Ctrl+A` → `Delete`) **antes** de colar. Senão as
> chaves ficam desbalanceadas e aparecem dezenas de erros em cascata.

**Teste no Testador de Estratégia antes de ir pra conta real** — é um grid, o tamanho de lote e o
espaçamento mudam completamente o risco.

## Parâmetros
| Parâmetro | Padrão | O que faz |
|---|---|---|
| `InpSwingDepth` | 5 | barras de cada lado para confirmar topo/fundo (pernada) |
| `InpLegLookback` | 400 | quantas barras ele olha pra trás procurando a pernada |
| `InpMinLegPoints` | 300 | pernada mínima em pontos (abaixo disso ele ignora) |
| `InpFibFrom` / `InpFibTo` | 0.0 / 38.2 | **zona de operação** (% de retração) |
| `InpFibStop` | 23.0 | % da pernada **para fora do extremo** que estopa tudo |
| `InpLots` | 0.01 | lote da primeira ordem |
| `InpLotMultiplier` | 1.0 | multiplicador por nível (1.0 = lote fixo; 1.5, 2.0 = martingale) |
| `InpGridPoints` | 200 | **espaçamento do grid** em pontos |
| `InpMaxPositions` | 10 | teto de ordens no ciclo |
| `InpAttachSL` | true | põe o nível de stop como SL de cada ordem |
| `InpTPMode` | dinheiro total | modo do take da cesta (ver acima) |
| `InpTPMoney` | 2.0 | alvo em US$ |
| `InpTPPoints` | 150 | alvo em pontos do preço médio (modo pontos) |
| `InpMaxLossMoney` | 0.0 | perda máxima da cesta em US$ (0 = desligado) |
| `InpReenterAfterTP` | false | depois do take, pode reentrar na **mesma** pernada? |
| `InpShowFibo` | true | plota a FIBO, a zona e a linha de stop |
| `InpSellClr` / `InpBuyClr` | vermelho / verde | cor da zona de venda / compra |
| `InpOpacity` | 18 | opacidade do preenchimento (0–100) |
| `InpStopClr` | laranja | cor da linha de stop |
| `InpShowLevels` | true | linhas dos níveis 0 / 23.6 / 38.2 / 50 / 61.8 / 100% |
| `InpExtendBars` | 0 | prolongar N barras além da vela atual |
| `InpShowPanel` / `InpPanelFontSize` | true / 9 | painel de status no canto superior esquerdo |
| `InpMagic` | 20260920 | magic number (separa as ordens do robô) |
| `InpSlippage` | 20 | desvio máximo em pontos |
| `InpAlertPush` / `InpAlertPopup` | false | aviso ao abrir ordem e ao encerrar o ciclo |

## O que aparece no gráfico
- **Retângulo da zona** (0% → 38.2%) vermelho na pernada de alta, verde na de queda, com o texto
  `FIBO SELL ZONE 0 - 38.2` / `FIBO BUY ZONE 0 - 38.2` no meio.
- **Linhas dos níveis** 0, 23.6, 38.2, 50, 61.8 e 100% com etiqueta de preço.
- **Linha da pernada** (origem → extremo), cheia, na cor do lado.
- **Linha de STOP** tracejada laranja, no `InpFibStop`% para fora do extremo.
- **Painel** com: pernada atual, níveis 0 / 38.2 / 100, retração agora, stop, nº de ordens, lotes,
  preço médio, flutuante em US$ e o alvo.

## Detalhes de comportamento
- **A pernada é travada quando a primeira ordem abre.** Enquanto o ciclo está aberto, os níveis não
  se mexem (a FIBO plotada é a travada). Sem ordens abertas, ele recalcula a pernada a cada barra.
- **Um ciclo por vez**, só num sentido. Ele não inverte com ordem aberta: primeiro encerra a cesta.
- **Depois do stop** (ou do `InpMaxLossMoney`) aquela pernada fica **bloqueada** — o painel mostra
  `[BLOQUEADA]`. Libera quando surgir uma pernada com **outra origem** ou de outro sentido.
- **Reinício do MT5 com ordens abertas:** ele adota as ordens do próprio magic. Se a pernada
  detectada for do mesmo sentido, retoma grid + stop normalmente; se não for, ele **só administra o
  take em dinheiro** (não abre grid novo e não usa stop de Fibo) e avisa isso no log.
- O MT5 **não tem canal alfa** em objeto de gráfico: a opacidade baixa é a cor da zona misturada com
  a cor de fundo do gráfico, na proporção de `InpOpacity` — fundo claro ou escuro é detectado
  automaticamente.
- Pode rodar junto com o RickEA TOP/BOTTOM (`TB_`) e o X-TREND (`XT_`): os prefixos são diferentes.
- O flutuante da cesta usa **lucro + swap** das posições. Comissão que o broker cobra fora da
  posição não entra nessa conta, então em conta com comissão alta vale subir um pouco o alvo.
