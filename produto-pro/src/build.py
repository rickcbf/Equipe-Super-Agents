"""Monta produto-pro/RelatorioPro-RickEA.html a partir do gerador local + modulos Pro."""
import os
here=os.path.dirname(os.path.abspath(__file__))
root=os.path.abspath(os.path.join(here,'..','..'))
base=open(os.path.join(root,'ferramentas-locais','relatorio-mt5','RelatorioMT5-RickEA.html'),encoding='utf-8').read()
css=open(os.path.join(here,'pro.css'),encoding='utf-8').read()
js=open(os.path.join(here,'pro.js'),encoding='utf-8').read()
sec=open(os.path.join(here,'pro-sections.html'),encoding='utf-8').read()
top,rest=sec.split('    <!-- ========== PRO: lote',1)
rest='    <!-- ========== PRO: lote'+rest

def rep(s,a,b):
    assert s.count(a)==1, a
    return s.replace(a,b)

s=base
s=rep(s,'<title>RickEA Relatório MT5</title>','<title>RickEA Relatório Pro</title>')
s=rep(s,'@media print{',css+'@media print{')
s=rep(s,'<h1>Relatório de performance do MT5</h1>','<h1>Relatório de Performance Pro</h1>')
s=rep(s,'<p class="lead">Arraste o relatório de histórico exportado do MetaTrader 5 para gerar a análise da conta: curva de saldo, resultado por robô, ativos, posições abertas e fluxo de caixa.',
        '<p class="lead">Arraste o relatório de histórico exportado do MetaTrader 5. Além da análise completa da conta, o Pro calcula a nota da sua conta, um plano de melhoria, o lote ideal para o seu saldo, o risco de quebra por Monte Carlo, o mapa de dia e horário e simula o que teria acontecido sem os seus piores trades.')
s=s.replace('<div class="brand">RickEA Investments</div>','<div class="brand">RickEA Investments<span class="pro-badge">PRO</span></div>')
s=rep(s,'    <div class="kpi-grid" id="kpis"></div>\n','    <div class="kpi-grid" id="kpis"></div>\n\n'+top)
s=rep(s,'    <div id="alertsWrap">',rest+'    <div id="alertsWrap">')
s=rep(s,'''      <span>RickEA Investments · @ri.chartrader</span>
    </div>''','''      <span>RickEA Relatório de Performance Pro · @ri.chartrader</span>
    </div>
    <p class="disclaimer">Conteúdo educativo. As análises, simulações e sugestões de lote são calculadas a partir do histórico enviado e não são recomendação de investimento. Resultados passados não garantem resultados futuros. Operar alavancado envolve risco de perda do capital.</p>''')
s=rep(s,"document.title='RickEA Relatório '+(acct.login||'MT5');","document.title='RickEA Relatório Pro '+(acct.login||'');")
s=rep(s,'  requestAnimationFrame(drawChart);\n}','  requestAnimationFrame(drawChart);\n  renderPro(r,a);\n}')
s=rep(s,'/* ================= eventos ================= */',js+'\n/* ================= eventos ================= */')
out=os.path.join(root,'produto-pro','RelatorioPro-RickEA.html')
open(out,'w',encoding='utf-8').write(s)
print('ok',out,len(s))
