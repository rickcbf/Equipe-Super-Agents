# RickEA — Gerador de Relatório MT5

Ferramenta **local** (roda no seu PC, sem instalar nada) que transforma o histórico do
MetaTrader 5 num relatório de performance bonito, na identidade RickEA, pronto pra salvar em PDF.

> Arquivo: `RickEA-Relatorio-MT5.html` · Funciona **offline** · Nenhum dado sai do seu PC.

## Como usar (3 passos)
1. **Exporte o histórico no MT5**: aba **Caixa de Ferramentas → Histórico** → clique direito →
   **Relatório → HTML** (gera o `ReportHistory-<conta>.html`). *Ou* use o relatório do
   **Testador de Estratégia** (backtest) salvo em HTML.
2. **Abra** o `RickEA-Relatorio-MT5.html` (duplo clique — abre no navegador).
3. **Arraste** o `ReportHistory-*.html` pra dentro da página (ou clique em "Escolher arquivo").
   O relatório aparece na hora. Clique em **🖨️ Salvar / Imprimir PDF** pra exportar.

## O que ele calcula
- Lucro líquido, retorno %, **fator de lucro**, **% de acerto**
- **Curva de capital** (gráfico) e **drawdown máximo** (R$/US$ e %)
- Payoff esperado, ganho/perda média, **R:R realizado**
- Maior ganho/perda, sequência máx. de ganhos e perdas
- Saldo inicial/final e a **tabela de todas as operações fechadas**

## Detalhes técnicos
- Lê relatório em **português e inglês** (detecta as colunas pelos nomes).
- Usa a tabela de **Negócios** (com saldo) ou, se não houver, **Posições** (reconstrói a curva).
- Ignora depósitos e as pernas de entrada ("in"); conta só as saídas ("out") como trade fechado.
- Tudo é processado no navegador via JavaScript — **não envia nada pra internet**.

## Dica
Use pra acompanhar o **RoboForex Challenge** e comparar semanas: gere o PDF a cada exportação e
guarde em `RoboForex_Challenge/statements/` no seu PC.
