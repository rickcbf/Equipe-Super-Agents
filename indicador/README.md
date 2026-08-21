# RickEA X-Trend — porte MT5 → cTrader

Indicador de tendência (SuperTrend/ATR + EMA + painel visual), portado do MetaTrader 5 (MQL5)
para a **cTrader (C# / cAlgo API)**.

## Arquivos
- `RickEA_XTrend.cs` — o indicador para cTrader.
- (original MT5: `RickEA_XTrend_Indicator.mq5` — mantido só como referência da lógica.)

## Como instalar na cTrader
1. Abra a cTrader → aba **Automate**.
2. **New Indicator** → apague o código de exemplo → **cole o `RickEA_XTrend.cs` inteiro**.
3. Clique em **Build** (martelo). Se compilar sem erro, ele aparece na lista de indicadores.
4. Abra um gráfico (ex.: XAUUSD) → **Indicators → f(x) → RickEA X-Trend** → ajuste os parâmetros → OK.

## Parâmetros (iguais ao MT5)
ATR Period (10) · ATR Multiplier (3.0) · EMA Period (50) · mostrar painel/níveis · valor de 1 ponto ($) ·
TP1/TP2/TP3 (16/60/120) · Stop (20) · passo do trailing (100) · altura/largura das etiquetas ·
preço grande + cor pela tendência.

## O que é idêntico ao MT5
- **SuperTrend** com ATR **Wilder** (= `iATR`) e a mesma regra de bandas/virada → direção da tendência.
- **Cor das velas** pela tendência (verde alta / vermelho baixa).
- **Linha SuperTrend** verde/vermelha e **EMA** tracejada dourada.
- **Níveis** Entrada/TP1/TP2/TP3/SL a partir da barra da virada, com o **mesmo cálculo** e o
  **SL com trailing de display** (vai pra BE + passos após passar o TP1).
- **Etiquetas** (caixas coloridas) e **painel** (BUY/SELL, targets, stop, minutos, P&L em pontos).
- **Preço grande** no canto superior direito, colorido pela tendência.

## Ajustes visuais (revisão)
- **Preço grande** (canto superior direito): agora usa `Chart.DrawText` com **fonte grande de verdade**
  (`FontSize = 36`, negrito) e **muda de cor pela tendência** (verde/vermelho). Fica ancorado no topo
  da área visível, à direita.
- **Etiquetas (TP/SL/Entrada):** o valor agora é **branco, em negrito e centralizado DENTRO da caixa**.
  A caixa usa uma versão escurecida da cor do nível (pra o texto branco ficar legível), e a **linha**
  projetada continua na cor viva (amarelo/dourado/vermelho/azul).
- **Painel:** acompanha a **cor da tendência** (verde no BUY, vermelho no SELL) — cor forçada a cada
  atualização.
- **Linha de tendência:** as duas séries (verde/vermelho) são **zeradas a cada barra** e só a ativa é
  preenchida, então **nunca aparecem as duas ao mesmo tempo** e a linha bate com a cor da vela.
  (Em mercado lateral o SuperTrend vira rápido — verde e vermelho alternando são viradas reais, não bug;
  se quiser menos viradas, aumente o **ATR Multiplier**.)

## Diferenças (limitações da cTrader — não afetam os sinais)
- **Cor das velas:** usa `Chart.SetBarColor` (cTrader **4.1+**). Se sua versão for antiga e não
  compilar por causa dessa linha, comente a linha marcada com `«SETBARCOLOR»`.
- **Painel:** na cTrader é **texto fixo de canto** (sem o retângulo preenchido do MT5), mas com a
  mesma informação e cor pela tendência.
- **Alertas** (push/popup/email do MT5) **não** entraram no indicador — na cTrader isso fica melhor
  num **cBot**. Se quiser, eu faço um cBot de alerta na virada depois.

## Validação (importante)
Não consigo compilar a cTrader aqui, então rode o **Build** aí e me diga:
- Compilou sem erro? (se der erro, me manda a mensagem exata)
- No gráfico, os níveis/painel/cores batem com o MT5? (manda um print)

Aí eu ajusto o que precisar até ficar idêntico.
