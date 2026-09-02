# RickEA — Indicadores para cTrader

Indicadores da marca **RickEA** para a **cTrader (C# / cAlgo API)**.

## Arquivos
- `RickEA_Statistics.cs` — **RickEA Statistics**: painel de **estatística e probabilidade** baseado num
  range de N velas (ver seção abaixo). ⭐ novo
- `RickEA_XTrend.cs` — o **indicador** de tendência (SuperTrend/ATR + EMA + níveis, painel, preço grande).
- `RickEA_XTrend_Alert.cs` — o **cBot de alerta de virada** (avisa quando a tendência vira BUY↔SELL).
- (original MT5: `RickEA_XTrend_Indicator.mq5` — mantido só como referência da lógica.)

---

## ⭐ RickEA Statistics (RickEA_Statistics.cs)

Painel de **probabilidade e estatística** que lê um **RANGE ajustável de N velas fechadas** e mostra
**tudo calculado dentro desse range**. A ideia é ler de relance a força do momento.

### O que o painel mostra
- **Cor predominante do momento:** o painel fica **VERDE** quando predominam velas de alta (BUY) e
  **VERMELHO** quando predominam velas de baixa (SELL). O cabeçalho mostra **▲ ALTA / ▼ BAIXA**.
- **Campos BUY e SELL — o que predomina fica EM CIMA** — cada um com a **quantidade de velas** e o
  **percentual** ao lado.
- **Barra de probabilidade** (largura do painel): dividida em **verde (BUY)** e **vermelho (SELL)**,
  preenchida na proporção de cada lado = a probabilidade do momento a partir das velas do range.
- **Preço do ativo GRANDE**, no canto superior direito, **acima** do painel (atualiza a cada tick).
- **Range (pips):** tamanho do range = **maior máxima − menor mínima** das N velas, em pips.
- **Média pips/vela:** amplitude média (máxima−mínima) por vela dentro do range.
- **Última vela (pips):** pips da **última vela encerrada** (verde se subiu, vermelho se caiu).
- **Pips BUY (verde)** e **Pips SELL (vermelho):** soma dos corpos das velas de alta e de baixa.
- **Maior seq. BUY / SELL:** a **maior sequência seguida** de velas de alta e de baixa no range.
- **Velas no range:** quantas velas realmente entraram no cálculo.

### Definição de vela
- **BUY** = fechamento **>** abertura · **SELL** = fechamento **<** abertura · fecha = abre → neutra
  (doji, não conta para nenhum lado). Os **percentuais usam BUY+SELL** como base.
- O range usa as **N últimas velas ENCERRADAS** (a vela que está se formando fica de fora), então os
  números não "piscam" a cada tick — só o **preço grande** e a barra atualizam ao vivo.

### Parâmetros
- **Range (qtd. de velas)** — o "set" ajustável (padrão **20**). Tudo é calculado dentro dele.
- **Título do painel** (padrão `RICKEA STATISTICS`).
- **Mostrar preço grande** · **Tamanho da fonte do preço** (padrão 34).
- **Posição (horizontal/vertical)** — onde o painel fica ancorado no gráfico (padrão: canto **superior
  direito**).

### Instalar
1. cTrader → **Automate** → **New Indicator** → apague o exemplo → cole o `RickEA_Statistics.cs` inteiro.
2. **Build** (martelo) → abra um gráfico → **Indicators → f(x) → RickEA Statistics** → ajuste o **Range**.

> **Prévia visual:** abra `indicador/preview-statistics.html` no navegador para ver o layout/cores do
> painel (é só uma maquete estática pra validar o visual — os números vêm do gráfico na cTrader).

---

## RickEA X-Trend (RickEA_XTrend.cs)

## cBot de alerta (RickEA_XTrend_Alert.cs)
Roda a MESMA lógica SuperTrend, mas **só na barra fechada** (não repinta) e **não opera a conta** —
é só um vigia. Quando a tendência vira, ele avisa por: **som** (.wav opcional), **texto grande no
gráfico** (verde/vermelho), **log** e **e-mail opcional**.

**Instalar:** Automate → **New cBot** → cole o `RickEA_XTrend_Alert.cs` → **Build** → abra o gráfico →
adicione **RickEA X-Trend Alert** → ajuste ATR (10 / 3.0) → **PLAY**. Deixe rodando na aba Automate.

> **Push no celular:** a API de cBot da cTrader **não** tem push direto pro app. O caminho que
> funciona é o **e-mail** (ative "Enviar e-mail" e configure o SMTP em *cTrader → Settings → Email*);
> deixe seu e-mail com notificação no celular. Som e aviso no gráfico funcionam sem configurar nada.

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
