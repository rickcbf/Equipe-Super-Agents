# 🗺️ CONTEXTO — mapa dos projetos (leia isto primeiro)

Este arquivo é o **índice mestre**. Quando eu (Claude) começar uma sessão, ou quando você trocar
de assunto, aponte pra cá: `veja o CONTEXTO.md`. Assim ninguém se perde.

> **Convenção pra trocar de assunto:** comece a mensagem com
> `[MUDANDO DE ASSUNTO] Tema: <projeto>` + 1 frase de contexto. Use sempre os mesmos nomes de projeto
> (abaixo). Projetos bem diferentes → melhor abrir **outra conversa/repositório**.

---

## 📁 Projetos ativos

### 1) RickEA — Teoria de Dow (este repositório)
Marca de trading **RickEA Investments** / Instagram **@ri.chartrader**. Ebook
*"A Teoria de Dow Aplicada ao Trading Moderno"* + página de vendas + campanha de Instagram.
- **Site (Vercel):** https://equipe-super-agents.vercel.app/
- **Checkout (Hotmart):** https://pay.hotmart.com/M107215100L · cupom **RICK50** → R$10,00
- **Skill que automatiza:** `rickea-instagram` (ver seção Skill)

### 2) Indicador (a definir) — OUTRO projeto
> Placeholder. Quando formos mexer no indicador, o ideal é um **repositório separado**
> (ex.: `indicador-xyz`) ou **outra conversa**, pra não misturar com o RickEA.
> Preencha aqui: nome, plataforma (MT4/MT5/TradingView), o que ele faz, onde está o código.

---

## 🗂️ Estrutura deste repositório

```
Equipe-Super-Agents/
├── CONTEXTO.md            ← este mapa
├── README.md              ← índice curto
├── index.html             ← PÁGINA DE VENDAS (servida em / na Vercel) — NÃO mover
├── obrigado.html          ← página de obrigado (/obrigado) — NÃO mover
├── painel.html            ← hub de links (/painel) — NÃO mover
├── kit-postagem.html      ← kit de postagem manual (/kit-postagem) — NÃO mover
├── vercel.json            ← config do deploy
├── assets/
│   └── capa-ebook.png     ← capa oficial do ebook (astronauta)
├── campanha/              ← BIBLIOTECA DE MÍDIA (tudo que vira post)
│   ├── (raiz)             ← feed, stories, pacote, reels de lançamento + README/legendas
│   ├── carrossel/         ← carrossel de lançamento (7 cards)
│   ├── educativo/         ← carrossel "Como ler a tendência" (6 cards)
│   ├── growth/            ← reels de crescimento + story
│   └── semana-2/          ← volume, gestão de risco, rompimento
├── docs/
│   └── plano-crescimento.html  ← plano/dashboard de crescimento
└── skill/
    └── rickea-instagram.skill  ← backup da skill empacotada
```

> ⚠️ **Por que os .html ficam na raiz:** a Vercel serve o site a partir da raiz. Mover
> `index/obrigado/painel/kit-postagem` mudaria as URLs que já estão no ar (Hotmart, bio, etc.).
> Por isso eles ficam na raiz de propósito. O resto (mídia, docs, skill) está organizado em pastas.

---

## 🔗 Links ao vivo
- Vendas: https://equipe-super-agents.vercel.app/
- Obrigado: https://equipe-super-agents.vercel.app/obrigado
- Painel (hub): https://equipe-super-agents.vercel.app/painel
- Kit de postagem: https://equipe-super-agents.vercel.app/kit-postagem

## 🤖 Skill
- **`rickea-instagram`** — cria reels/carrosséis/stories na identidade RickEA (grátis) e agenda no
  Metricool. Backup em `skill/rickea-instagram.skill`. Instalada no perfil.
  Playbook e horários em: `skill/` → `references/playbook.md` e `references/scheduling.md`.
- Para acionar: *"prepara a semana do @ri.chartrader"*, *"cria um carrossel sobre X"*.

## 📅 Metricool (@ri.chartrader · blogId 6510161)
- Fuso America/New_York · horários de pico **10:30** (manhã) e **18:00** (dias de semana).
- **Limite: 20 posts/mês.** Fique de olho pra não estourar (soma com o outro produto).
- Calendário de setembro dos posts RickEA está no `painel` e no `kit-postagem`.

---

## 💻 Estrutura recomendada no SEU PC (Windows)

Sugestão pra organizar `C:\Users\rickc\` (crie uma pasta `Projetos`):

```
C:\Users\rickc\Projetos\
├── RickEA-TeoriaDeDow\
│   ├── 01_Ebook\            ← PDF do ebook + os 3 bônus
│   ├── 02_Capa-Mockups\     ← capa do astronauta, mockups
│   ├── 03_Campanha-Insta\
│   │   ├── Reels\
│   │   ├── Carrosseis\
│   │   ├── Stories\
│   │   └── Anuncios\
│   ├── 04_Site\             ← backup do site (baixado do GitHub)
│   └── 05_Documentos\       ← plano, relatórios, legendas
│
└── Indicador\               ← quando começar: código + prints + docs
```

**Regras simples:**
- Nome de arquivo com **data + tema**: `2026-09-reel-volume.mp4` (ordena sozinho).
- O **repositório do GitHub é a fonte da verdade** dos arquivos da campanha — o PC é cópia.
- Baixar tudo de uma vez: no GitHub, botão **Code → Download ZIP**.
```
```
