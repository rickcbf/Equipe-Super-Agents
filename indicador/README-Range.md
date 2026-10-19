# RickEA Range (MT4 + MT5)

Robô de **continuidade de 3 velas**. Arquivos: `indicador/RickEA_Range.mq5` (MT5) e
`indicador/RickEA_Range.mq4` (MT4) — mesma estratégia e mesmo visual.

## Estratégia
| | Compra | Venda |
|---|---|---|
| Velas | vela 3 com máxima **e** mínima acima da vela 2; vela 2 com máxima **e** mínima acima da vela 1 | vela 3 com máxima **e** mínima abaixo da vela 2; vela 2 com máxima **e** mínima abaixo da vela 1 |
| RSI (14) | até 50 (`RSI_BuyMax`) | a partir de 50 (`RSI_SellMin`) |
| Stop | abaixo da mínima da vela 1 (+ `StopOffset`) | acima da máxima da vela 1 (+ `StopOffset`) |
| Alvo | `TargetRR`: 1:1.5, 1:2 ou livre (`RR_Custom`) | igual |

- Entra a mercado na abertura da vela seguinte à vela 3 (velas fechadas).
- O range das 3 velas fica marcado no gráfico (verde = compra, vermelho = venda), com linhas de
  entrada, stop e alvo. `Range_History` marca também os setups antigos; `Range_Filtered` mostra
  em cinza os setups barrados pelos filtros.
- **Sem grid**: cada ordem só tem o seu stop e o seu take.

## Opcionais
- **Tendência pela média** (`MA_Filter`): compra só acima, venda só abaixo da média escolhida
  (período, método, preço e tempo gráfico).
- **Take global / stop global** (`GlobalTP` / `GlobalSL`, em dinheiro): fecha todas as ordens do robô
  quando o flutuante bate o valor.
- Direção (compras e vendas / só compras / só vendas), máximo de ordens abertas, lote fixo ou
  por risco (% do saldo no stop), spread máximo, range mínimo/máximo das 3 velas.

## Visual RickEA
Preço grande no canto superior direito na cor da tendência, painel com fundo de pouca opacidade
(padrão das 3 velas, RSI, média, posição, SL/TP, flutuante, take/stop global, realizado
dia/semana/mês, acerto e payoff) e a logo de marca d'água no fundo.
A logo usa os mesmos `RickEA_Logo_*.bmp` do RickEA SAR: copiar para `MQL5\Images` (MT5) ou
`MQL4\Images` (MT4). Os BMPs estão em `robo/Images/` na branch `claude/sweet-meitner-622x2y`.
