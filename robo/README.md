# RickEA MA — robô MT5 de média móvel

Compra **acima** da média, vende **abaixo** da média. No set dá pra escolher
**só compras**, **só vendas** ou **os dois**, e ligar (ou não) **grid**,
**martingale**, **ciclo de take global** e **entrada por vela**.

O visual é o mesmo padrão do RickEA X-Trend: **preço grande no canto superior
direito**, **painel com fundo de pouca opacidade na cor da tendência** (verde na
alta, vermelho na baixa — o preço grande acompanha) e a **logo RickEA
preenchendo o fundo do gráfico**.

> Este README é do **RickEA MA**. O **RickEA SAR** (Parabolic SAR + ADX) tem o
> seu próprio: [`README-SAR.md`](README-SAR.md).

## Arquivos
```
robo/
  RickEA_MA.mq5                      <- o robô (copiar para MQL5\Experts)
  RickEA_SAR.mq5                     <- robô SAR + ADX (ver README-SAR.md)
  Images/RickEA_Logo_*.bmp           <- marca d'água (copiar para MQL5\Images)
  sets/*.set                         <- presets prontos (MQL5\Presets)
  tools/make_logo_bmp.py             <- gera a logo em outro tamanho/opacidade
```

## Instalação
1. No MT5: **Arquivo → Abrir Pasta de Dados**.
2. Copie `RickEA_MA.mq5` para `MQL5\Experts\`.
3. Copie a pasta `Images\` (os `RickEA_Logo_*.bmp`) para `MQL5\Images\`.
4. Copie os `.set` para `MQL5\Presets\` (opcional).
5. No MetaEditor: abra `RickEA_MA.mq5` → **Compilar** (F7).
6. Arraste o **RickEA MA** para o gráfico, marque **Permitir negociação
   automática** e carregue um preset no botão **Abrir** da aba de parâmetros.

## Como ele opera
- **Tendência** = preço contra a média (`EMA`, período 17 por padrão; dá pra
  trocar o método, o preço aplicado, o deslocamento e o tempo gráfico da média).
- **Acima da média** → compra. **Abaixo da média** → venda. O que é permitido
  sai do `TradeDirection`.
- `STOPLOSS` / `TAKEPROFIT` em **pontos** na própria ordem — `0` desliga.
  Quando você usa o ciclo de take global, o normal é deixar `TAKEPROFIT=0`.

### Modo de entrada
| `EntryMode` | O que faz |
|---|---|
| `Tick` | avalia a cada tick: preço atual contra a média |
| `Por vela` | **entrada por vela** — só na abertura da vela nova, olhando a vela já fechada contra a média |
| `Cruzamento` | igual ao de cima, mas só quando a vela fechada **cruza** a média |

`OneEntryPerCandle` limita a **uma entrada por vela** (vale também para as
adições do grid). `MinDistMA_Points` evita entrar colado na média.

### Grid (opcional)
Adiciona ordens **contra o preço**, a cada `Grid_StepPoints` a partir da última
entrada daquele lado, até `Grid_MaxOrders`. `Grid_StepMult` acima de 1.0 vai
abrindo a distância a cada nível. Com `Grid_RequireSignal=true` ele só adiciona
enquanto a média continuar concordando com o lado.

### Martingale (opcional)
Multiplica o lote a cada adição: `FIXED_LOT × Martin_Multiplier^nível`, parando
de multiplicar depois de `Martin_MaxLevels` e respeitando `Martin_MaxLot`.
Só faz sentido junto do grid.

### Ciclo de take global (opcional)
Fecha a cesta inteira quando o flutuante bate o alvo:
- `Cycle_Scope`: cesta **global** (compras + vendas juntas) ou **por lado**.
- `Cycle_Unit`: alvo em **dinheiro** da conta ou em **% do saldo**.
- `Cycle_TakeProfit` / `Cycle_StopLoss` (0 = sem stop global).
- `Cycle_WaitNewSignal`: depois de fechar, espera a média virar antes de abrir
  o próximo ciclo naquele lado.
- `Cycle_OverrideTP` (ligado por padrão): com o ciclo ativo, as ordens saem
  **sem TP próprio**. É o que faz a meta ser da cesta e não de cada ordem — se
  cada ordem levar o `TAKEPROFIT` individual, ela fecha sozinha antes de a
  cesta somar. O robô também tira o TP de posições que já estavam abertas com
  alvo próprio e avisa no log.

### Trailing (`if 0 value >> OFF`)
`TRAILINGSTART` = lucro em pontos para ligar · `TRAILINGSTOP` = distância do
preço até o stop · `TRAILINGSTEP` = passo mínimo para mexer de novo.
`TRAILINGSTOP=0` desliga tudo. `BreakEvenFirst` segura o stop no preço de
entrada antes de começar a arrastar.

## Visual

### Painel e preço grande
Ficam juntos no **canto superior direito**. O fundo é a cor da tendência
misturada com a cor de fundo do gráfico — `Panel_Opacity` (padrão 18%) controla
o quanto a cor aparece. O MT5 não tem canal alfa em retângulo de painel, então
a "pouca opacidade" é feita nessa mistura: o resultado na tela é idêntico e não
custa nada de processamento.

O painel mostra: média e valor, direção permitida, modo de entrada, compras e
vendas abertas (quantidade, volume e resultado), grid/martingale ligados,
progresso do take global e flutuante × patrimônio.

### Logo no fundo
`Logo_Show` liga a marca d'água. `Logo_Mode`:
- **Mosaico** — preenche o gráfico inteiro, fileiras alternadas (padrão);
- **Centro** — uma logo só, no meio.

`Logo_Size` precisa ser **o tamanho do BMP** (o MT5 recorta, não redimensiona).
Os arquivos prontos são `RickEA_Logo_96/128/192/256/512.bmp`. Se o alfa não
renderizar no seu build, troque para a versão `_dark` (mesma logo já mesclada
com fundo preto, para gráfico escuro).

Para outra opacidade ou outro fundo:
```bash
python3 robo/tools/make_logo_bmp.py --sizes 160 --opacity 10 --bg 12,12,20
```

## Presets
| Arquivo | Para que serve |
|---|---|
| `RickEA_MA_Simples.set` | uma ordem por lado, sem grid/martingale/ciclo |
| `RickEA_MA_Grid_Martin_Ciclo.set` | grid + martingale fechando no take global de 5 |
| `RickEA_MA_SoCompras_PorVela.set` | só compras, entrada na abertura da vela |

## Antes de ligar no real
- Teste no **Testador de Estratégia** com o preset que você vai usar.
- **Grid e martingale multiplicam risco**: a cesta só fecha no lucro se a conta
  aguentar a sequência contra. Comece com `Grid_MaxOrders` baixo,
  `Martin_Multiplier` perto de 1.3 e `Martin_MaxLot` preenchido.
- Em **conta netting** os dois lados não ficam abertos ao mesmo tempo (as
  posições se fundem). O robô avisa no log e continua funcionando — o grid soma
  volume normalmente.
