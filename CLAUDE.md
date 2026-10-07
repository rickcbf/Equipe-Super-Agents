# Regras fixas deste repositório

## Entrega de arquivos — SEMPRE

**Sempre que eu criar ou alterar um arquivo, devo enviá-lo para download no
chat na mesma resposta, sem o usuário precisar pedir.** Vale para tudo:
`.mq5`, `.cs`, `.html`, `.py`, `.png`, `.mp4`, PDF, etc.

- Enviar o arquivo final assim que ele ficar pronto, junto da explicação.
- Alterou de novo? Envia de novo a versão nova.
- Commitar e dar push **não substitui** o envio no chat.
- Se forem vários arquivos, enviar todos.

## Git

- Desenvolver sempre na branch designada da sessão (`claude/...`).
- Commit com mensagem descritiva em português; push ao terminar.
- Não abrir Pull Request sem o usuário pedir.

## Código MQL5 (`indicador/`)

- Arquivos `.mq5` em **ASCII sem acentos** e quebra de linha **CRLF** —
  é o que o MetaEditor espera.
- Não dá para compilar `.ex5` neste ambiente (Linux, sem MetaEditor).
  O usuário compila com F7 e manda o `.ex5` de volta quando for publicar
  em `downloads/`.

## Antes de dizer "nao achei" — SEMPRE buscar em TODAS as branches

Cada sessao trabalha numa branch `claude/...` diferente, entao um bot/arquivo
feito em outra conversa **nao aparece na branch atual**. Antes de responder que
algo nao existe, procurar em todas as branches do GitHub:

```bash
git fetch origin
git log --all --oneline -i --grep="<nome>"
git log --all --name-only --pretty=format: | grep -i "<nome>" | sort -u
git branch -r --contains <commit>          # descobre em qual branch esta
git show origin/<branch>:<caminho>         # le o arquivo sem trocar de branch
```

O mapa de onde esta cada bot fica no `CONTEXTO.md` (secao "Robos e indicadores:
em qual branch esta cada um"). Ao criar um bot novo, acrescentar la.

## Contexto dos projetos

Ler `CONTEXTO.md` — é o índice mestre de todos os projetos do repositório.
