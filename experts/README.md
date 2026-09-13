# RickEAFimathePro (MT5 / MQL5) — v2

Expert Advisor da estratégia **Fimathe** reescrito conforme os ajustes pedidos.

## Instalar
1. Copie `RickEAFimathePro.mq5` para
   `...\MQL5\Experts\` do seu MetaTrader 5.
2. Abra no **MetaEditor** → **Compile** (F7).
3. No gráfico (ex.: XAUUSD) arraste o EA **RickEAFimathePro** → habilite
   *Algo Trading* → OK.

## O que mudou nesta versão
- **C3 removido.** Não há mais níveis/ordens de C3 nem o split 75%/25% —
  agora é **uma ordem por vez**.
- **Canal de referência = vela de TOPO ou de FUNDO** (swing) **mais próxima do
  preço**. Reavalia a cada nova vela enquanto aguarda o rompimento.
- **Ajuste manual:** arraste as linhas amarelas do canal; o EA lê a nova posição
  e recalcula entrada/TP/stop automaticamente.
- **Entrada pelo lado que romper primeiro:**
  - Rompeu para **baixo** → **VENDA**, alvo (TP) = **1× o tamanho do canal**.
  - Rompeu para **cima** → **COMPRA**, alvo (TP) = **1× o tamanho do canal**.
- **Entrada inversa (rejeição):** se, após romper um lado, o preço **rejeitar e
  voltar para dentro do canal**, a posição é fechada e o EA arma a entrada no
  **rompimento do lado oposto**, com alvo = **1,5× o tamanho do canal**.
- **Stop:** um **spread** abaixo do canal (compras) e **spread+** acima do canal
  (vendas), para não ser pego pelo spread. Ajuste fino em `InpStopSpreadMult`.
- **Visual em segmentos** (não linhas de tela cheia):
  - Canal: **amarelo pontilhado discreto** (aparece quando formado).
  - Entrada: **azul** (compra) / **laranja** (venda) — só quando rompe.
  - TP: **verde**. Stop: **vermelho**. Só aparecem quando há rompimento.
- **Painel (quadro)** no canto superior esquerdo com fase, canal, entrada/TP/stop,
  P&L do dia e dois botões:
  - **ZERAR ORDEM** — fecha a posição atual e reinicia o ciclo.
  - **BOT: ON/OFF** — ativa/desativa o EA (desativado = passivo; só ZERAR fecha).

## Principais parâmetros
- `InpSwingLookback` — força do swing (velas de cada lado) para achar topo/fundo.
- `InpTPmultPrimary` (1.0) / `InpTPmultInverse` (1.5) — alvos em múltiplos do canal.
- `InpStopSpreadMult` (1.0) — folga do stop em múltiplos do spread.
- `InpMaxConcurrent` (1) — uma ordem por vez.
- Gestão de risco, filtro de notícias, modo de lote e alerta sonoro mantidos.
