# RickEA TOP/BOTTOM (MT5)

Marca as **duas máximas** e as **duas mínimas** dos dias anteriores (D-1 e D-2) e desenha as
zonas operacionais entre elas.

Arquivo: `RickEA_TopBottom_Indicator.mq5`

## O que ele desenha
- **SELL ZONE** — retângulo **vermelho de baixa opacidade** entre a máxima do dia anterior e a
  máxima de dois dias atrás, começando no **início do dia D-2** e indo **até a vela atual**, com
  o texto `SELL ZONE` no meio.
- **BUY ZONE** — o mesmo entre as duas **mínimas**, em **verde**, com `BUY ZONE` no meio.
- **Linhas pontilhadas** em cada nível (H D-1, H D-2, L D-1, L D-2) com etiqueta de preço.
- **Preço grande** no canto superior direito, **na cor da tendência** (SuperTrend/ATR 10 · 3.0),
  igual ao RickEA X-TREND.
- **Frase de alerta no topo, centralizada**: `ALERT: SELL ZONE` quando o preço está entre as duas
  máximas e `ALERT: BUY ZONE` quando está entre as duas mínimas. Fora das zonas, some.

## Instalação (jeito seguro)
1. MT5 → **Arquivo → Abrir Pasta de Dados** → entre em `MQL5/Indicators/`.
2. **Copie o arquivo `RickEA_TopBottom_Indicator.mq5` para essa pasta** (arquivo inteiro, não
   copiar/colar o texto).
3. No **MetaEditor**: **Arquivo → Abrir** → escolha o arquivo → **Compilar (F7)**.
4. No gráfico: **Navegador → Indicadores → RickEA_TopBottom_Indicator** (arraste pro gráfico).

> **Se for colar o código dentro do MetaEditor:** crie o arquivo pelo assistente e depois
> **apague TUDO que o assistente gerou** (`Ctrl+A` → `Delete`) **antes** de colar. O assistente
> do MetaEditor já cria um esqueleto com `OnInit()` / `OnCalculate()`; se o código for colado
> por cima ou no meio desse esqueleto, as chaves/parênteses ficam desbalanceados e aparecem
> dezenas de erros em cascata do tipo `unbalanced parentheses`, `unexpected end of program` e
> `undeclared identifier 'CalcTrend' / 'Zone' / 'Level'` (as funções depois do ponto quebrado
> somem para o compilador). O arquivo em si compila limpo.

Pode rodar junto com o RickEA X-TREND no mesmo gráfico (os objetos usam prefixos diferentes:
`TB_` aqui, `XT_` lá). Se usar os dois, desligue `InpBigPrice` em um deles para o preço grande
não sobrepor.

## Parâmetros principais
| Parâmetro | Padrão | O que faz |
|---|---|---|
| `InpSellClr` / `InpBuyClr` | vermelho / verde | cor das zonas |
| `InpOpacity` | 18 | opacidade do preenchimento (0–100) |
| `InpExtendBars` | 0 | prolongar N barras além da vela atual |
| `InpShowLevels` / `InpShowLevelTag` | true | linhas e etiquetas dos 4 níveis |
| `InpZoneFontSize` | 14 | tamanho de `SELL ZONE` / `BUY ZONE` |
| `InpShowAlertTop` / `InpAlertFontSize` / `InpAlertYOffset` | true / 18 / 24 | frase no topo |
| `InpBigPrice` / `InpBigPriceSize` / `InpBigPriceByTrend` | true / 26 / true | preço grande |
| `InpAtrPeriod` / `InpAtrMult` | 10 / 3.0 | tendência que colore o preço grande |
| `InpAlertPush` / `InpAlertPopup` / `InpAlertEmail` | false | avisos ao **entrar** numa zona |

## Detalhes de comportamento
- As máximas/mínimas vêm do **timeframe diário (D1)**, então funcionam em qualquer período do
  gráfico (M1, M5, H1…).
- O MT5 **não tem canal alfa** em objeto de gráfico: a "pouca opacidade" é feita misturando a cor
  da zona com a cor de fundo do gráfico na proporção de `InpOpacity`, e o retângulo fica **atrás
  das velas** (`BACK=true`). Fundo claro ou escuro é detectado automaticamente.
- Se as duas faixas se sobrepuserem (dia de range apertado), a **SELL ZONE tem prioridade** na
  frase de alerta.
- Os alertas push/popup/e-mail disparam **uma vez por entrada** na zona, não a cada tick.
