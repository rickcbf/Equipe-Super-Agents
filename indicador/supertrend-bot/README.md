# RickEA SuperTrend Bot (MT5)

Robô baseado no indicador **RickEA SuperTrend V-2** (`RickEA_SuperTrend_V-2_original.mq5`, a cópia do original).
Arquivo único: `RickEA_SuperTrend_Bot.mq5`. Não precisa de indicador nem de imagem em outra pasta.

## Instalar
1. Copie `RickEA_SuperTrend_Bot.mq5` para `MQL5/Experts/`.
2. Abra no MetaEditor e compile (F7).
3. Arraste no gráfico e ative o **Algo Trading**.

## O que aparece no gráfico
- SuperTrend verde/vermelha, EMA azul e as setas do indicador (douradas; azul/vermelha no engolfo), desenhadas pelo próprio robô.
- Setas ciano/magenta onde o robô entrou.
- Preço grande no canto superior direito (verde quando sobe, vermelho quando cai).
- Painel à esquerda: cor da tendência, resultado do dia, entradas do dia, posição atual, ciclo, horário do PC e status.
- Logo RickEA no fundo do gráfico, embutido no código (posição, tamanho e opacidade nas configurações).

## Regra de entrada
- A SuperTrend **vira de cor** (vela fechada) → entra a favor da nova cor.
- A vela de entrada precisa ser **de força** (corpo ≥ 60% do tamanho da vela e tamanho ≥ 1× ATR) e ter **volume** ≥ 1,2× a média de 20 velas. É o filtro anti-lateral.
- Se a vela da virada não passar no filtro, o robô aceita a primeira vela de força nas próximas `InpJanelaVirada` velas (padrão 3).
- `Uma entrada por ciclo = true`: só uma operação por cor. Com `false`, reentra no mesmo ciclo em novas velas de força quando estiver zerado.
- Filtros extras opcionais: preço acima/abaixo da EMA e ADX dentro da faixa mín/máx.
- Parâmetros do indicador únicos para todos os dias: período do ATR, multiplicador, EMA, período do ADX e faixa mín/máx (sem ajuste por dia da semana).

## Gestão
| Item | Opções |
|---|---|
| Direção | Compras e vendas / só compras / só vendas |
| Stop | Último fundo (compra) ou topo (venda) + folga · pontos fixos · sem stop |
| Take | 1:1 · 1:2 · 1:3 (risco:retorno sobre o stop) · pontos · sem take |
| Lote | Fixo ou % de risco do saldo (calculado pela distância do stop) |
| Break even | Gatilho em pontos + offset |
| Trailing | Só começa com lucro ≥ pontos de início; distância e passo em pontos |
| Take por ciclo | Lucro das posições abertas no ciclo ≥ X → fecha e espera a próxima virada |
| Take global / Stop global | Resultado do dia (fechado + aberto) ≥ meta ou ≤ −stop → fecha e para até o dia seguinte |
| Horário | Início/fim pelo **relógio do PC** (`TimeLocal`), inclusive janelas que passam da meia-noite |

## Observações
- O indicador original lê o **buffer 2 do ADX (−DI)** e não a linha principal. Para as setas saírem iguais, o padrão do robô é `-DI`. Dá para trocar em *"Linha do ADX usada"*.
- No Strategy Tester o "horário do PC" passa a ser o horário simulado (é assim no MT5).
- Para trocar o logo: substitua `assets/logo-rickea.webp` e rode `python3 indicador/supertrend-bot/gerar_logo_mq5.py`.
