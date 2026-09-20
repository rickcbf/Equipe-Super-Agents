# RickEA SAR — robô MT5 de Parabolic SAR + ADX

Feito em cima do `RickEA SAR.mq5` original. A **estratégia é a mesma** — o que
entrou foi o visual RickEA (painel, preço grande e logo inteira no fundo),
mais alguns parâmetros que estavam travados no código.

## Como ele opera (inalterado)
- Trabalha **só na abertura da vela nova**, nunca no meio da vela.
- **Uma posição por vez.** Só procura entrada quando não há nenhuma aberta.
- **Compra** quando o SAR está **abaixo** do fechamento e o **ADX < 20**
  (mercado calmo). **Vende** quando o SAR está **acima** e o ADX < 20.
- SL e TP fixos, definidos na entrada. **Breakeven**: passado `InpBreakeven`
  de lucro, o stop vai pro preço de entrada.
- **Lote por risco**: `CMoneyFixedRisk` calcula o volume pra arriscar `Risk`%
  do saldo até o stop. Não é lote fixo.
- **Alternância de lado**: bateu o **TP**, a próxima entrada inverte o lado;
  bateu o **SL**, a próxima repete o mesmo lado. No primeiro start (ou depois
  de reiniciar) ele aceita qualquer lado.

## O que foi acrescentado
- **Painel** no canto superior direito, no mesmo padrão do RickEA MA: fundo de
  pouca opacidade na cor da tendência (verde = SAR abaixo, vermelho = SAR
  acima). Mostra SAR, ADX e se o filtro está liberado, qual o próximo lado
  permitido, posição aberta, SL/TP em preço, risco e lote da próxima entrada,
  flutuante e patrimônio.
- **Preço grande** na cor da tendência, igual ao RickEA MA.
- **Logo inteira** no fundo — uma só, centralizada, atrás das velas (não é
  mosaico). `Logo_Fill` define quanto da altura do gráfico ela ocupa e o robô
  escolhe sozinho o maior BMP que cabe (1024 → 768 → 512 → 256 → 128 → 96).
- **`ADX_max`, `InpMagic`, `InpSlippage` e `EA_NAME`** viraram parâmetros
  (antes estavam fixos no código).
- **Aviso de stop curto**: se o SL configurado for menor que 5× o spread atual
  do símbolo, ele avisa no log em vez de operar às cegas.
- Removidos os `DebugBreak()` — em conta real eles não têm o que fazer ali.

## Instalação
1. MT5 → **Arquivo → Abrir Pasta de Dados**.
2. `RickEA_SAR.mq5` → `MQL5\Experts\`
3. A pasta `Images\` (os `RickEA_Logo_*.bmp`) → `MQL5\Images\`
4. Os `.set` → `MQL5\Presets\`
5. MetaEditor → abrir o arquivo → **Compilar (F7)** → arrastar pro gráfico.

## ATENÇÃO: os valores padrão não servem pro ouro

O `InpStopLoss=150` / `InpTakeProfit=250` do arquivo original são de par de
forex. A conversão de "pip" do código é `Point × 10` em símbolo de 3 ou 5
dígitos e `Point × 1` nos demais — nos dois casos, **no XAUUSD isso dá 1 pip =
0,01 dólar**. Ou seja, os valores originais são:

| Parâmetro | Valor original | No ouro dá |
|---|---|---|
| Stop Loss | 150 | **US$ 1,50** |
| Take Profit | 250 | **US$ 2,50** |
| Breakeven | 100 | **US$ 1,00** |

O spread do ouro costuma ser US$ 0,20 a US$ 0,50 sozinho. Com stop de US$ 1,50
praticamente toda operação morre no ruído — não é a estratégia que está ruim,
é a escala. Use os presets `RickEA_SAR_XAU_M15.set` (SL 700 = US$ 7) ou
`RickEA_SAR_XAU_H1.set` (SL 1500 = US$ 15).

## Em que tempo gráfico funciona melhor no XAU

**Não dá pra responder isso sem rodar o testador** — não existe MetaEditor nem
histórico de preço neste ambiente, então qualquer número que eu desse seria
invenção. O que dá pra dizer com segurança é o raciocínio de custo e escala:

| TF | Leitura |
|---|---|
| M1 / M5 | O spread + slippage come o alvo. SAR vira a toda hora e o filtro ADX<20 deixa entrar bem no meio do chop. **Não recomendo nem testar a sério.** |
| M15 | Primeiro TF em que o movimento médio supera o custo com folga. Bom número de trades pra amostra ter validade estatística. **Comece por aqui.** |
| M30 / H1 | Menos trades, cada um com follow-through melhor — combina com o TP fixo maior que o SL. **O mais provável de sustentar resultado.** |
| H4 | Sinal limpo, mas poucas operações. Precisa de anos de histórico pra amostra fechar. |

O detalhe que manda nesse robô: como o TP é **1,7× o SL** e ele entra em
mercado calmo (ADX<20), ele precisa que o preço ande depois da entrada. Em TF
baixo isso quase nunca acontece antes do custo. Meu palpite fundamentado é
**M15 ou H1** — mas é palpite, e palpite não paga conta.

### Como tirar a dúvida de verdade
1. Testador de Estratégia → **RickEA SAR** → XAUUSD → **Todos os ticks reais**.
2. Carregue `RickEA_SAR_Otimizacao_XAU.set` (já vem com o visual desligado, que
   deixa o teste muito mais rápido).
3. Rode a otimização **um TF de cada vez**: M5, M15, M30, H1, H4.
4. Anote de cada um: **Fator de lucro, Drawdown máximo, nº de operações e
   Sharpe**. TF com menos de ~100 operações no período não vale como resposta.
5. Me manda os relatórios que eu comparo e te digo qual sustenta.

## Presets
| Arquivo | Para que serve |
|---|---|
| `RickEA_SAR_XAU_M15.set` | ouro em M15, SL US$ 7 / TP US$ 12 |
| `RickEA_SAR_XAU_H1.set` | ouro em H1, SL US$ 15 / TP US$ 25 |
| `RickEA_SAR_Otimizacao_XAU.set` | otimização no testador, visual desligado |

> Os valores dos dois primeiros são **ponto de partida dimensionado pelo ATR
> típico do ouro**, não resultado de backtest. Rode o testador antes de pôr
> dinheiro real.
