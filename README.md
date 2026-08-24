# RickEA — Teoria de Dow

> 🗺️ **Comece pelo [`CONTEXTO.md`](CONTEXTO.md)** — o mapa de tudo (projetos, pastas, links ao vivo, calendário e convenções). Este README cobre só a página de vendas.

Página de vendas do ebook **"A Teoria de Dow Aplicada ao Trading Moderno"**, para hospedar como página externa da Hotmart.

## Arquivos
- `index.html` — **loja RickEA Investments** (home, servida em `/`), vitrine multi-produto.
- `ebook.html` — página de vendas do ebook (servida em `/ebook`), **autossuficiente**.

## Links dos botões
Todos os botões de compra ("Comprar agora") apontam para a página de pagamento:
- **Pagamento (Comprar Agora):** https://pay.hotmart.com/M107215100L
- Página de vendas: https://go.hotmart.com/M107215100L
- Página do produto: https://go.hotmart.com/M107215100L?dp=1

## Como publicar

### Vercel (recomendado)
Site estático, sem build. O `vercel.json` já está configurado (framework "Other").

**Opção A — pelo site (2 min, sem instalar nada):**
1. Acesse https://vercel.com/new
2. "Import Git Repository" → escolha `rickcbf/Equipe-Super-Agents`
3. Framework Preset: **Other** · Build Command: *(vazio)* · Output Directory: *(vazio / raiz)*
4. Deploy → você recebe uma URL `https://<projeto>.vercel.app`

Obs.: a Vercel publica em produção a partir da branch padrão (`main`). Faça o merge desta
branch para `main` antes, ou selecione a branch no deploy.

**Opção B — pela CLI (na sua máquina):**
```bash
npm i -g vercel      # ou use: npx vercel
cd Equipe-Super-Agents
vercel               # login + deploy de preview
vercel --prod        # publica em produção
```

### Outras opções
Também funciona em GitHub Pages, Netlify, ou colando o `index.html` num bloco de HTML do
editor de páginas da Hotmart.

## Capa do ebook
A capa oficial (astronauta) já está **embutida** no `ebook.html` como data URI, dentro de uma
moldura 3D. O arquivo original também está salvo em `assets/capa-ebook.png` (642×955).

## Identidade visual
- Fundo carbono `#06080D`, neon azul `#38BDF8`, laranja RickEA `#FF7A29`
- Tipografia: Orbitron (marca), Rajdhani (títulos), Manrope (corpo), JetBrains Mono (dados)
- Tema dark único, estética "terminal de trading"
