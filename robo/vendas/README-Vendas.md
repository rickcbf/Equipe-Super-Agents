# RickEA MA e RickEA SAR — versão de vendas (padrão do FiboGrid)

A licença é **compilada dentro do `.ex5`**. O cliente não digita chave nenhuma:
você gera o `.mq5` dele no gerador HTML, compila, e manda só o `.ex5`.

```
robo/vendas/
  RickEA_MA_v1_Licenca.mq5         <- molde do MA  (as 3 linhas ficam no topo)
  Gerador-Licenca-RickEA-MA.html   <- gerador do MA
  RickEA_SAR_v2_Licenca.mq5        <- molde do SAR
  Gerador-Licenca-RickEA-SAR.html  <- gerador do SAR
```

Cada gerador já traz o `.mq5` do seu robô embutido — é um arquivo só, abre no
navegador, não precisa de internet nem servidor. O funcionamento é idêntico nos
dois; onde o texto abaixo disser "o robô", vale para os dois.

## As 3 linhas

No topo do `.mq5`, iguaizinhas às do FiboGrid:

```mql5
#define LIC_CLIENTE "CLIENTE"
#define LIC_CONTA   0
#define LIC_VENCE   D'2026.12.31 23:59:59'
```

- **LIC_CLIENTE** — nome do comprador, aparece no painel.
- **LIC_CONTA** — conta MT5 liberada. `0` libera qualquer conta (não recomendado
  pra venda).
- **LIC_VENCE** — último instante válido, no **horário do servidor da corretora**.

Dá pra editar na mão, mas o normal é usar o gerador.

## O fluxo de venda

1. Abra o **`Gerador-Licenca-RickEA-MA.html`** no navegador (é um arquivo só,
   não precisa de internet nem servidor).
2. Preencha **nome do cliente**, **conta MT5**, **data da compra** e **dias de
   licença** (vem 90 por padrão). O resumo mostra a data de vencimento.
3. **Baixar .mq5 do cliente** — sai
   `RickEA_MA_Joao_Silva_ate_2027-01-15.mq5` (ou `RickEA_SAR_...`), já com as 3
   linhas preenchidas.
4. Jogue em `MQL5\Experts`, abra no MetaEditor e **compile com F7**
   (Ferramentas › Opções › Compiladores: **X64 Regular**, senão dá o erro de AVX2).
5. Mande ao cliente **só o `.ex5`** — nunca o `.mq5` — mais a pasta
   `Images\` com os `RickEA_Logo_*.bmp` (é o que desenha a logo no fundo).

> O SAR usa a **logo inteira centralizada** e escolhe sozinho o maior BMP que
> cabe no gráfico, então mande os arquivos grandes junto (768 e 1024). O MA
> usa o mosaico de 128 por padrão.

## Como o robô se comporta

| Situação | O que acontece |
|---|---|
| Conta errada | `Alert` dizendo de qual conta é a licença e qual é a atual, e o robô **não carrega** (`INIT_FAILED`). |
| Vencido, **sem** posição aberta | `Alert` com a data do vencimento e o robô **não carrega**. |
| Vencido, **com** posição aberta | Carrega e **administra o que está aberto** (no MA: trailing, take global, reversão; no SAR: breakeven), mas **não abre ordem nova**. Avisa no log. |
| Vencendo com o robô rodando | No primeiro tick depois do vencimento, um `Alert` e para de abrir. |
| Backtest | O travamento por conta é ignorado no Testador (`MQL_TESTER`), pra você conseguir testar. |

O painel ganhou duas linhas no fim: **Cliente** e **Licença até**, com a data e
os dias restantes. Fica verde normalmente, **laranja** faltando 15 dias ou menos,
e **vermelho** depois de vencida — igual ao FiboGrid.

A validade usa `TimeTradeServer()` (horário do servidor da corretora), não o
relógio do PC — atrasar o Windows não estica a licença.

## O que eu tirei

A primeira versão de vendas do MA era por **chave digitada** (`RMA-conta-data-assinatura`),
com gerador em script MT5 e em Python. Removi os quatro arquivos
(`RickEA_MA_Vendas.mq5`, `tools/RickEA_KeyGen.mq5`, `tools/rickea_keygen.py` e o
`README-Vendas.md` antigo) porque você pediu este jeito **no lugar** daquele.
Eles continuam no histórico do git, no commit `4d0346f`, se um dia quiser
resgatar.

## Diferença entre os dois jeitos, pra você saber o que está escolhendo

**Este (FiboGrid):** um `.ex5` por cliente. Não tem segredo dentro do binário
pra alguém extrair e fabricar chave — o que está lá dentro é só a conta e a data
daquele cliente. Renovar = gerar e compilar de novo, e reenviar o arquivo.

**O de chave:** um `.ex5` só pra todo mundo, renovação é mandar uma chave nova
por WhatsApp, sem recompilar nada. Em compensação o segredo mora no binário.

Para o volume de um produto vendido no manual, o jeito do FiboGrid é mais
simples e mais seguro. Se um dia a renovação virar trabalho demais, aí vale
voltar pro de chave — ou partir pra validação em servidor, que resolve os dois
problemas de uma vez.
