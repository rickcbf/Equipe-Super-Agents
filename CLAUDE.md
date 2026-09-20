# Equipe Super Agents — regras do repositório

## Entrega de arquivos (sempre)
Nunca despejar código longo no chat esperando que o Rick copie e cole — ele não
consegue copiar tudo. **Sempre** que produzir um arquivo (robô `.mq5`,
indicador, script, HTML, set, imagem), entregar assim:

1. Salvar o arquivo no repositório, commitar e dar push na branch da tarefa.
2. Mandar o arquivo pro Rick com a ferramenta `SendUserFile` (card de download).
   Quando forem vários arquivos relacionados, mandar também um `.zip` com o
   conjunto pronto pra instalar.
3. Deixar no chat só o link raw do GitHub e o resumo do que mudou — o repo é
   público, então o raw funciona direto:
   `https://raw.githubusercontent.com/rickcbf/Equipe-Super-Agents/<branch>/<caminho>`

No chat vai o resumo e o link. O código vai por arquivo.

## Robôs e indicadores MT5
- Robôs (EAs) ficam em `robo/`, indicadores em `indicador/`.
- Todo EA/indicador novo vem com: `README.md` de instalação, presets `.set` em
  `sets/` e, se usar marca d'água, os BMPs em `Images/`.
- Não dá pra compilar MQL5 neste ambiente (não existe MetaEditor no Linux).
  Entregar sempre o `.mq5` e avisar que o F7 no MetaEditor é o teste final.

## Visual padrão RickEA
Painel e preço grande no canto superior direito, fundo do painel com pouca
opacidade na cor da tendência (verde alta / vermelho baixa) e a logo RickEA
preenchendo o fundo do gráfico. A opacidade é simulada misturando a cor da
tendência com a cor de fundo do gráfico — o MT5 não tem canal alfa em painel.
