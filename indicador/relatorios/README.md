# RickEA — Gerador de Relatório MT5

Ferramenta **grátis** que transforma o histórico do MetaTrader 5 num relatório de performance
bonito, na identidade RickEA, pronto pra salvar em PDF. Roda **no navegador**, offline se quiser,
e **nenhum dado sai do PC** de quem usa.

## Onde ela fica
- **Página pública:** `relatorio.html` na **raiz do repositório** → publicada em
  **https://rickea.vercel.app/relatorio** (via Vercel, `cleanUrls`).
- Esta pasta guarda só a documentação. O arquivo da ferramenta é o `relatorio.html` da raiz.

## Como usar
1. Abra **https://rickea.vercel.app/relatorio** (ou baixe o `relatorio.html` e dê duplo clique).
2. No MT5: aba **Histórico** → botão direito → **Relatório → HTML** (período "Todo o histórico").
3. **Arraste** o `ReportHistory-*.html` pra dentro da página → relatório pronto → **Salvar/Imprimir PDF**.

## O que calcula
Lucro líquido, retorno, **fator de lucro**, **% de acerto**, **curva de capital**, **drawdown máx.**,
payoff, recuperação, Sharpe, R:R realizado, maior ganho/perda, sequências, **estado da conta**
(saldo, capital líquido, **flutuante P/L**) e a tabela de todas as operações.

## Técnico
- Lê relatório em **português e inglês** (detecta colunas pelos nomes e usa o bloco oficial "Resultados").
- Usa a tabela de **Posições** (lucro ancorado na última célula, imune ao deslocamento por comentário)
  ou, se não houver, a de **Negócios** com a coluna Saldo.
- Alerta quando o **flutuante** das posições abertas é maior que o lucro fechado.
- 100% client-side (JavaScript no navegador) — **não envia nada pra internet**.
