# RickEA MA — versão de vendas (licença + validade)

Mesma estratégia e mesmo visual do `RickEA_MA.mq5`. O que muda é que esta
versão **só abre operação com uma chave de licença válida**, amarrada ao número
da conta e com data de validade.

| Arquivo | Vai para | Quem recebe |
|---|---|---|
| `RickEA_MA_Vendas.mq5` | `MQL5\Experts\` | **só você** (compile e entregue o `.ex5`) |
| `tools/RickEA_KeyGen.mq5` | `MQL5\Scripts\` | **só você**, nunca o cliente |
| `tools/rickea_keygen.py` | sua máquina | **só você** |
| `Images\RickEA_Logo_*.bmp` | `MQL5\Images\` | o cliente também precisa |

## Antes de vender a primeira cópia: troque o segredo

O segredo é o que impede alguém de fabricar chave. Ele aparece em **três**
arquivos e precisa ser **idêntico** nos três:

```
RickEA_MA_Vendas.mq5     linha 29   #define RICK_LICENSE_SECRET "..."
tools/RickEA_KeyGen.mq5  linha 19   #define RICK_LICENSE_SECRET "..."
tools/rickea_keygen.py   linha 31   DEFAULT_SECRET = "..."
```

Troque o `TROQUE-ESTE-SEGREDO-RICKEA-2026` por uma frase longa e sua, recompile
os dois `.mq5` e guarde o segredo. **Se você trocar o segredo depois, todas as
chaves já entregues param de funcionar** — então defina antes de vender.

## Como é a chave

```
RMA-37308561-20261231-B045-FC4D-222D-9AB8
 |      |        |              |
 |      |        |              assinatura (16 hex do SHA-256)
 |      |        validade AAAAMMDD  (00000000 = vitalícia)
 |      conta MT5 do cliente        (0 = vale em qualquer conta)
 prefixo
```

A assinatura é o SHA-256 de `SEGREDO|RICKEA-MA|conta|validade`. O robô refaz a
mesma conta e compara. Se o cliente editar a conta ou esticar a data dentro da
chave, a assinatura não bate mais e a licença cai.

## Gerando chaves

**No MT5** (jeito mais prático no dia a dia): copie `RickEA_KeyGen.mq5` pra
`MQL5\Scripts\`, compile e execute em qualquer gráfico. Preencha conta,
validade e o nome do cliente. A chave sai no log **Experts**, num **Alert**
(dá pra copiar com Ctrl+C) e fica registrada em
`MQL5\Files\RickEA_Licencas.csv`.

**No terminal** (bom pra lote):
```bash
python3 rickea_keygen.py --conta 37308561 --dias 30
python3 rickea_keygen.py --conta 37308561 --ate 2026-12-31
python3 rickea_keygen.py --conta 0 --vitalicia            # chave mestra sua
python3 rickea_keygen.py --lote contas.txt --dias 365     # uma conta por linha
python3 rickea_keygen.py --conferir RMA-37308561-...      # confere uma chave
```

### Confira que os dois geradores batem
Com o segredo padrão, os três exemplos abaixo têm que sair **idênticos** no
script do MT5 e no Python. Rode os dois e compare antes de trocar o segredo —
se baterem, a implementação está casada:

| Conta | Validade | Chave esperada |
|---|---|---|
| 37308561 | 2026.12.31 | `RMA-37308561-20261231-B045-FC4D-222D-9AB8` |
| 0 | vitalícia | `RMA-0-00000000-E4B9-BAD6-13C2-084B` |
| 123456 | 2027.01.01 | `RMA-123456-20270101-9C7E-BBE9-15F4-BCF7` |

## Como o cliente usa
1. Ele te passa o **número da conta MT5**.
2. Você gera a chave e manda.
3. Ele cola em **`LicenseKey`** nos parâmetros do robô.

O painel ganhou a linha **Licença**: `OK - 27d`, `VITALICIA`, `TESTE - 5d` ou
`BLOQUEADO`. Faltando `Warn_DaysBefore` dias (padrão 7) pro vencimento, ela fica
laranja e o log avisa.

## Período de teste
`Trial_Days` (padrão 7) libera o robô sem chave, e `Trial_DemoOnly` mantém isso
só em conta demo. A data do primeiro uso fica gravada em
`Terminal\Common\Files\RickEA_MA_Trial_<conta>.dat` — reinstalar o terminal ou
trocar de pasta de dados não zera o contador. Ponha `Trial_Days=0` se não quiser
teste nenhum.

## O que acontece sem licença válida
- **Não abre posição nova.**
- **Continua cuidando do que já está aberto** — trailing, take global, fechar na
  reversão. Ninguém fica na mão com posição aberta porque a licença venceu.
- Aviso vermelho no meio do gráfico com o motivo e o número da conta, e o mesmo
  no log.
- A licença é reconferida **a cada minuto**, então se vencer com o robô rodando
  ele para de abrir na hora.

## Até onde essa proteção vai (leia isto)

Essa é a proteção que dá pra fazer dentro do próprio EA, e é o que a maioria dos
vendedores de robô usa. Ela resolve o caso real: o cliente passar o `.ex5` pro
amigo, que abre em outra conta e não funciona.

O que ela **não** resolve: o segredo está dentro do `.ex5`. Quem souber
desmontar o binário consegue extrair o segredo e fabricar chave. Então:

- **Nunca** entregue o `.mq5` — só o `.ex5`.
- **Nunca** entregue o `RickEA_KeyGen` (nem fonte, nem compilado).
- Troque o segredo a cada versão nova do produto.
- Se quiser proteção de verdade, o caminho é **validação em servidor**: o EA
  consulta uma URL sua (WebRequest) com o número da conta, e o servidor
  responde se está liberado. Aí o segredo nunca sai da sua máquina. Dá pra
  fazer depois, é só me pedir.
- Vender pelo **MQL5 Market** também resolve, porque a MetaQuotes faz o
  travamento por conta no lado deles.

## Parâmetros novos
| Parâmetro | Padrão | O que faz |
|---|---|---|
| `LicenseKey` | vazio | a chave do cliente |
| `Trial_Days` | 7 | dias de teste sem chave (0 = sem teste) |
| `Trial_DemoOnly` | true | teste só em conta demo |
| `Warn_DaysBefore` | 7 | quando começar a avisar do vencimento |

Todo o resto (média, grid, martingale, take global, visual) é igual ao
`RickEA_MA.mq5` — veja o [README.md](README.md).
