# RickEAFimathePro (MT5 / MQL5) — v3

Expert Advisor da estratégia **Fimathe**.

## Instalar
1. Copie `RickEAFimathePro.mq5` para `...\MQL5\Experts\` do seu MetaTrader 5.
2. Abra no **MetaEditor** → **Compile** (F7).
3. No gráfico arraste o EA **RickEAFimathePro** → habilite *Algo Trading* → OK.

## Lógica de entrada (dois cenários)

**Canal de referência** = **N velas** (padrão **4**; ajuste em `InpChannelBars`,
ou use o modo topo/fundo em `InpChannelMode`). `lg` = tamanho do canal (topo−fundo).

### Cenário 1 — entrada na C1
1. Preço rompe um lado do canal → projeta a **C1** a favor (C1 = borda + 1× `lg`)
   e **salva** o canal.
2. **Entrada no rompimento da C1**:
   - Rompeu p/ **cima** → COMPRA no rompimento de `topo + lg`.
   - Rompeu p/ **baixo** → VENDA no rompimento de `fundo − lg`.
3. **Alvo = 2× o canal** a partir da entrada.
4. **Stop** na borda **oposta** do canal ± spread (compra: fundo − spread;
   venda: topo + spread).

### Cenário 2 — entrada inversa (C1 negada)
1. Rompeu um lado e marcou a C1, **mas não rompeu a C1** e voltou pro canal.
2. Depois **rompe o canal de referência pro lado oposto** → **entrada no
   rompimento do canal** (não numa nova C1):
   - Ex.: rompeu o fundo, marcou C1 de venda, negou, voltou e rompeu o topo →
     **COMPRA** no topo, **stop abaixo do canal**, **alvo 2×** pra cima.
   - Para venda, as projeções são ao contrário.
3. **Alvo = 2× o canal**. **Stop** na borda oposta ± spread.

## Outras características
- **Uma ordem por vez.**
- **Ajuste manual:** arraste as linhas amarelas do canal; o EA lê a nova posição
  e recalcula C1/entrada/TP/stop.
- **Visual em segmentos** (não linhas de tela cheia), aparecendo só quando fazem
  sentido: canal **amarelo pontilhado**; C1 pendente na cor da entrada;
  entrada **azul**(compra)/**laranja**(venda), TP **verde**, stop **vermelho**.
- **Painel (quadro)** com fase, canal, C1±, entrada/TP/stop, P&L do dia e botões
  **ZERAR ORDEM** e **BOT: ON/OFF** (desativado = passivo; só ZERAR fecha).

## Principais parâmetros
- `InpChannelMode` / `InpChannelBars` (4) — como formar o canal.
- `InpTPmult` (2.0) — alvo em múltiplos do canal, medido a partir da entrada.
- `InpStopSpreadMult` (1.0) — folga do stop em múltiplos do spread.
- `InpMaxConcurrent` (1) — uma ordem por vez.
- Gestão de risco, filtro de notícias, modo de lote e alerta sonoro mantidos.
