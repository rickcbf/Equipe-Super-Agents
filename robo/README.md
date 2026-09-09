# RickEA B3-Strategy — Robô (EA MT5)

Automatiza o **setup manual do print** (@ri.chartrader) — HiLo Activator + Média 7 EMA +
Estocástico (6,3,3). Feito pra rodar no **timeframe M3** (mas funciona em qualquer TF).

> Arquivo: `RickEA_B3-Strategy.mq5` · Linguagem: **MQL5** (MetaTrader 5).

---

## 🎯 Como o robô lê a estratégia

O robô avalia **sempre na vela FECHADA** (não repinta) e só mantém **1 operação por vez**.

### 🔴 VENDA (SELL)
1. **Vela gatilho** cruza a **EMA 7 pra baixo**: abre **acima** e fecha **abaixo** da média,
   e é uma vela de baixa (`close < open`). Corpo forte opcional (`InpMinBodyRatio`).
2. **HiLo Activator VERMELHO** (tendência de baixa).
3. **Confluência**: o **Estocástico** rompeu o **nível 80 pra baixo** em **até N velas** (padrão 5).
4. **Entrada** → **Sell Stop** na **mínima da vela gatilho** (no rompimento pra baixo).
5. **Stop** → **acima** da vela gatilho (máxima + folga). **Alvo 3:1** (configurável).

### 🔵 COMPRA (BUY) — espelho
1. Vela gatilho cruza a **EMA 7 pra cima**: abre abaixo e fecha acima, vela de alta.
2. **HiLo Activator VERDE**.
3. Estocástico rompeu o **nível 20 pra cima** em até N velas.
4. **Entrada** → **Buy Stop** na **máxima da vela gatilho**.
5. **Stop** → **abaixo** da vela gatilho. **Alvo 3:1**.

Se o preço **já rompeu** a vela quando ela fecha, o robô entra **a mercado** em vez de deixar a
pendente. Se a pendente **não romper** em `InpPendingExpiry` velas (padrão 3), ela é **cancelada**.

---

## 🧩 Indicadores (embutidos — não precisa instalar nada)
- **EMA 7** (`iMA`) — a "média de 7 exponencial" que substitui o Envelope Rick.
- **Estocástico (6,3,3)** (`iStochastic`) — mesmíssimos parâmetros do print (`Stoch(6,3,3)`).
- **HiLo Activator (Gann)** — implementado **dentro do EA** (período configurável, padrão 3).
  Verde = fecho acima da média das máximas; Vermelho = fecho abaixo da média das mínimas.

> **Quer usar o seu `LT HiLo Activator` da Market?** Ligue `InpHiLoUseCustom = true` e ajuste
> `InpHiLoName` (nome exato em `MQL5/Indicators`) e `InpHiLoBuffer`. O robô lê a linha e compara
> com o fecho: fecho acima da linha = verde, abaixo = vermelho.

---

## ⚙️ Parâmetros principais
| Input | Padrão | O que faz |
|---|---|---|
| `InpEmaPeriod` | 7 | Período da EMA gatilho |
| `InpHiLoPeriod` | 3 | Período do HiLo embutido |
| `InpStochK/D/Slow` | 6/3/3 | Estocástico |
| `InpStochHigh/Low` | 80/20 | Níveis de rompimento |
| `InpStochLookback` | 5 | "até N velas atrás" pra confluência |
| `InpMinBodyRatio` | 0.5 | Corpo mínimo da vela gatilho (0 = desliga) |
| `InpRequireHiLoTurn` | false | Exigir HiLo **virando** (não só o estado) |
| `InpRR` | 3.0 | Alvo em R:R (3 pra 1) |
| `InpSLBufferPts` | 2 | Folga do stop além da vela (pontos) |
| `InpPendingExpiry` | 3 | Cancela a pendente se não romper em N velas |
| `InpLotMode` | 1 | 0 = lote fixo · 1 = **risco %** |
| `InpRiskPercent` | 1.0 | % da conta arriscada por trade (modo risco) |
| `InpLotFixed` | 0.05 | Lote fixo (modo 0) |
| `InpMaxSpreadPts` | 0 | Spread máx. (0 = desliga) |
| `InpUseHours` | false | Filtro de horário (servidor) |

O **lote por risco %** calcula o tamanho pelo tamanho do stop pra arriscar sempre a mesma % da
conta — quanto maior a vela gatilho, menor o lote, mantendo o risco constante.

---

## 📥 Instalar na MetaTrader 5
1. Abra o MT5 → **Arquivo → Abrir Pasta de Dados** → `MQL5/Experts/`.
2. Copie o `RickEA_B3-Strategy.mq5` pra lá.
3. Abra o **MetaEditor** (F4) → selecione o arquivo → **Compilar** (F7). Tem que dar **0 erros**.
4. Volte ao MT5 → arraste **RickEA B3-Strategy** pro gráfico (ex.: **XAUUSD, M3**).
5. Marque **Permitir Algo Trading** (botão no topo) e confira os parâmetros → **OK**.

---

## 🧪 Antes de operar de verdade
- Rode no **Testador de Estratégia** (Ctrl+R) no par/TF que você opera (XAUUSD M3) pra ver o
  comportamento e ajustar `InpMinBodyRatio`, `InpStochLookback`, `InpRR` e o HiLo.
- Depois **conta demo** por alguns dias antes da real.
- Se o seu `LT HiLo Activator` tiver um jeito específico de marcar a cor/direção, me manda o
  **código-fonte `.mq5`** dele que eu troco o HiLo embutido pela lógica idêntica à sua.

> ⚠️ Trading envolve risco. Este robô automatiza um setup discricionário; valide sempre antes de
> usar capital real.
