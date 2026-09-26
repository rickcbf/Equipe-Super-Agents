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
- **Site (Vercel):** https://rickea.vercel.app/
- **Checkout ebook Teoria de Dow (Hotmart):** https://pay.hotmart.com/M107215100L · cupom **RICK50** → R$10,00
- **Checkout ebook Código dos Traders de Elite (Hotmart):** https://pay.hotmart.com/T106424524D · R$9,99 (de R$37) · capa `assets/capa-traders-elite.png`
- **Checkout MCP TradingView Gold (Hotmart):** https://pay.hotmart.com/M106450067D · R$49 (de R$97) · página `/mcp-tradingview`
- **Checkout RickEA Relatório de Performance Pro (Hotmart):** https://pay.hotmart.com/Q107762850I · R$9,99 · página `/relatorio-pro` · capa `assets/capa-relatorio-pro.png`
- **Checkout RickEA FiboGrid (Hotmart):** https://pay.hotmart.com/Y107764003J (links do site usam `?offDiscount=RICK50` = cupom RICK50, 50% OFF) · licença de 3 meses · página `/fibogrid` · capa `assets/capa-fibogrid.png`
- **Licença FiboGrid por cliente:** abrir `indicador/Gerador-Licenca-FiboGrid.html` (local, não vai pro site), informar nome + conta MT5 + data da compra → baixa o `.mq5` com vencimento em compra + 90 dias e travado na conta. Compilar (F7, X64 Regular) e enviar só o `.ex5`. Modelo: `indicador/RickEA_FiboGrid_v4_Licenca.mq5`; se alterar o modelo, rodar `python3 indicador/licenca/build.py`.
- **Checkout RickEA Mentoria — Mentalidade e Sucesso (Hotmart):** https://pay.hotmart.com/G106467310N · R$49,99 · página `/mentoria` · capa `assets/capa-mentoria.png`
- **Skill que automatiza:** `rickea-instagram` (ver seção Skill)

### 2) RickEA X-Trend — Indicador
Indicador de tendência. **Está pronto e perfeito na MetaTrader 5** (código em **MQL5** — `.mq5`).
- **Objetivo atual:** portar para a **cTrader** (linguagem **C# / cTrader Automate API**, ex-cAlgo),
  para usar o mesmo indicador lá também.
- **Status:** aguardando o **código-fonte `.mq5`** para iniciar a conversão MQL5 → C#.
- **Recomendação:** projeto separado — repositório próprio (ex.: `rickea-x-trend`) ou pasta
  `indicador/` neste repo. Definir ao começar.

### 3) RickEA SuperTrend Bot — Robô MT5
Robô (EA) em cima do indicador **RickEA SuperTrend V-2**. Entra na virada de cor da SuperTrend, só em vela de força + volume.
- **Código:** `indicador/supertrend-bot/RickEA_SuperTrend_Bot.mq5` (arquivo único, com o logo embutido)
- **Indicador original:** `indicador/supertrend-bot/RickEA_SuperTrend_V-2_original.mq5`
- **Manual:** `indicador/supertrend-bot/README.md` · logo regerado por `gerar_logo_mq5.py`
- **Status:** v1.00 escrita, aguardando compilação/teste do usuário (F7).

---

## 🗂️ Estrutura deste repositório

```
Equipe-Super-Agents/
├── CONTEXTO.md            ← este mapa
├── README.md              ← índice curto
├── index.html             ← LOJA/VITRINE RickEA Investments (servida em / na Vercel) — NÃO mover
├── ebook.html             ← página de vendas do ebook Teoria de Dow (/ebook) — NÃO mover
├── traders-elite.html     ← página de vendas do Código dos Traders de Elite (/traders-elite) — NÃO mover
├── mcp-tradingview.html   ← página de vendas do MCP TradingView Gold (/mcp-tradingview) — NÃO mover
├── mentoria.html          ← página de vendas da RickEA Mentoria (/mentoria) — NÃO mover
├── relatorio-pro.html     ← página de vendas do Relatório de Performance Pro (/relatorio-pro) — NÃO mover
├── fibogrid.html          ← página de vendas do robô RickEA FiboGrid (/fibogrid) — NÃO mover
├── png/ · referencias/    ← assets originais da campanha MCP (fonte; usados pela página) 
├── obrigado.html          ← página de obrigado do ebook Teoria de Dow (/obrigado) — NÃO mover
├── obrigado-elite.html    ← obrigado + UPSELL (Traders de Elite → Teoria de Dow) (/obrigado-elite) — NÃO mover
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
- **Loja RickEA Investments (home):** https://rickea.vercel.app/
- Página do ebook: https://rickea.vercel.app/ebook
- Obrigado: https://rickea.vercel.app/obrigado
- Painel (hub): https://rickea.vercel.app/painel
- Kit de postagem: https://rickea.vercel.app/kit-postagem

> **Loja (`index.html`, home):** vitrine multi-produto da empresa. Catálogo é um array
> `PRODUCTS` no `<script>` — pra adicionar produto é só copiar um bloco. Cada `checkout` é um
> link Hotmart (`pay.hotmart.com/...`); sem link vira botão "Tenho interesse" (WhatsApp).
> WhatsApp já configurado (+1 770 256 2736). Logo: salvar em `assets/logo-rickea.png`
> (o cabeçalho já usa ela automaticamente; sem o arquivo, mostra o selo "R").

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

---

## 🖥️ Ferramentas locais (rodam no PC do usuário)
- `ferramentas-locais/relatorio-mt5/RelatorioMT5-RickEA.html` — gerador de relatório do MT5 no
  **layout escuro RickEA** (KPIs, curva de saldo, resultado por EA/comentário, ativos, posições
  abertas, fluxo de caixa, pontos de atenção). Arrasta o `ReportHistory-*.html`; tudo offline.
- `Instalar-na-Area-de-Trabalho.bat` copia para `%LOCALAPPDATA%\RickEA\RelatorioMT5` e cria o
  atalho na Área de Trabalho. Pacote pronto: `ferramentas-locais/RelatorioMT5-RickEA-local.zip`.
- A versão web gratuita continua sendo `relatorio.html` (/relatorio), com o layout antigo.

- **RickEA Relatório de Performance Pro (R$ 9,99) — pronto para vender.** Pasta `produto-pro/`
  (fora do site via `.vercelignore`). Entrega da Hotmart: `produto-pro/RickEA-Relatorio-Pro.zip`
  (HTML + instalador .bat + LEIA-ME). Código: `produto-pro/src/` (pro.js, pro.css, pro-sections.html);
  `python3 produto-pro/src/build.py` monta o HTML final a partir do gerador local + módulos Pro.
  Recursos: nota da conta 0–100, plano de melhoria, lote proporcional, Monte Carlo, mapa dia×hora,
  risco × retorno, simulador "e se". Página de vendas `/relatorio-pro`; checkout ligado no anúncio do `relatorio.html`
  (`PRO_CHECKOUT`) e no card da loja. Para trocar o link: `CHECKOUT` no fim do `relatorio-pro.html`.
