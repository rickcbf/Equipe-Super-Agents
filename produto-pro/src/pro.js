/* =====================================================================
   RickEA Relatório de Performance Pro — módulos Pro
   ===================================================================== */
var PRO=null;

function pv(p){ return p.profit+p.commission+p.swap; }
function median(arr){ if(!arr.length) return NaN; var s=arr.slice().sort(function(a,b){return a-b;}); var m=Math.floor(s.length/2); return s.length%2?s[m]:(s[m-1]+s[m])/2; }
function quantile(sorted,q){ if(!sorted.length) return NaN; var i=(sorted.length-1)*q, lo=Math.floor(i), hi=Math.ceil(i); return sorted[lo]+(sorted[hi]-sorted[lo])*(i-lo); }
function clamp(v,a,b){ return Math.max(a,Math.min(b,v)); }
function lerp(x,pts){ /* pts: [[x,y],...] crescente em x */
  if(x<=pts[0][0]) return pts[0][1];
  for(var i=1;i<pts.length;i++){ if(x<=pts[i][0]){ var a=pts[i-1],b=pts[i]; return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]); } }
  return pts[pts.length-1][1];
}
function dur(ms){ if(!isFinite(ms)||ms<0) return '—'; var m=ms/6e4; if(m<60) return Math.round(m)+' min'; var h=m/60; if(h<48) return (h<10?h.toFixed(1).replace('.',','):Math.round(h))+' h'; return Math.round(h/24)+' d'; }
function lotFmt(v){ return (Math.floor(v*100+1e-9)/100).toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:2}); }
function mulberry32(a){ return function(){ a|=0; a=a+0x6D2B79F5|0; var t=Math.imul(a^a>>>15,1|a); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; }; }
var DIAS=['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
var DIAS_LONGO=['domingo','segunda','terça','quarta','quinta','sexta','sábado'];

/* ---------- base de dados Pro ---------- */
function proPrepare(r,a){
  var P=r.positions.filter(function(p){return p.open&&p.close;}).slice().sort(function(x,y){return x.close-y.close;});
  var curve=a.curve.slice().sort(function(x,y){return x.t-y.t;});
  var fallback=isFinite(a.start)&&a.start>0?a.start:(a.endBal>0?a.endBal:1000);
  function balBefore(t){ var b=NaN; for(var i=0;i<curve.length;i++){ if(curve[i].t<t) b=curve[i].b; else break; } return (isFinite(b)&&b>0)?b:fallback; }
  P.forEach(function(p){ p.v=pv(p); p.bal=balBefore(p.close); p.pct=p.v/p.bal; p.hold=p.close-p.open; });
  return {P:P,r:r,a:a};
}

/* ================= 1. NOTA + PLANO ================= */
function proScore(D,mcBase){
  var a=D.a, P=D.P, r=D.r;
  var w=P.filter(function(p){return p.v>0;}), l=P.filter(function(p){return p.v<0;});
  var wr=P.length?w.length/P.length:0;
  var avgW=w.length?w.reduce(function(s,p){return s+p.v;},0)/w.length:0;
  var avgL=l.length?Math.abs(l.reduce(function(s,p){return s+p.v;},0)/l.length):0;
  var rr=avgL?avgW/avgL:(avgW>0?5:0);
  var be=1/(1+rr), edge=(wr-be)*100;
  var slAll=r.positions.concat(r.open), slShare=slAll.length?slAll.filter(function(p){return p.sl>0;}).length/slAll.length:0;
  var vols=P.map(function(p){return p.volume;}).filter(function(v){return v>0;});
  var medV=median(vols), maxV=vols.length?Math.max.apply(null,vols):0, lotRatio=medV?maxV/medV:1;

  var c=[
    {k:'Lucratividade',v:lerp(isFinite(a.pf)?a.pf:5,[[0.8,0],[1,6],[1.5,12],[2,16],[3,20]]),d:'Fator de lucro '+(isFinite(a.pf)?nf(a.pf):'∞')},
    {k:'Drawdown',v:lerp(isFinite(a.maxDDpct)?a.maxDDpct:0,[[5,20],[10,16],[20,10],[30,5],[50,0]]),d:'Queda máxima '+pct(a.maxDDpct,1)},
    {k:'Vantagem',v:lerp(edge,[[-10,0],[0,8],[10,16],[20,20]]),d:(edge>=0?'+':'')+edge.toFixed(1).replace('.',',')+' p.p. acima do acerto mínimo'},
    {k:'Gestão de risco',v:slShare*10+lerp(lotRatio,[[3,10],[8,5],[15,0]]),d:Math.round(slShare*100)+'% com stop · maior lote '+lotRatio.toFixed(1).replace('.',',')+'× o mediano'},
    {k:'Robustez',v:mcBase?lerp(mcBase.p30*100,[[0,20],[10,14],[25,8],[50,0]]):10,d:mcBase?pct(mcBase.p30*100,0)+' de chance de cair 30% em '+mcBase.N+' trades':'amostra pequena'}
  ];
  var total=Math.round(c.reduce(function(s,x){return s+x.v;},0));
  var grade=total>=80?'Excelente':total>=65?'Boa':total>=50?'Regular':total>=35?'Frágil':'Crítica';
  return {total:total,grade:grade,parts:c,wr:wr,rr:rr,be:be,edge:edge,slShare:slShare,lotRatio:lotRatio,medV:medV,maxV:maxV,avgW:avgW,avgL:avgL};
}

function netOf(list){ return list.reduce(function(s,p){return s+p.v;},0); }

function proPlan(D,S,mcBase,mcHalf,heat){
  var a=D.a, P=D.P, r=D.r, acts=[];
  function add(prio,imp,title,text){ acts.push({prio:prio,imp:imp,title:title,text:text}); }
  var totalNet=netOf(P);

  a.bots.forEach(function(b){
    if(b.n>=5 && b.net<0){
      var rest=netOf(P.filter(function(p){return botName(p.comment)!==b.name;}));
      add(Math.abs(b.net),'Alto','Revisar o '+(b.name||'Trading Manual'),
        'Fechou '+money(b.net,true)+' em '+b.n+' operações. Sem ele, o resultado do período iria de '+money(totalNet,true)+' para '+money(rest,true)+'.');
    }
  });
  a.syms.forEach(function(s){
    if(s.n>=4 && s.net<0){
      add(Math.abs(s.net)*0.9,'Médio','Rever as entradas em '+s.s,
        s.n+' operações e '+money(s.net,true)+' no total, com acerto de '+pct(s.wr)+'.');
    }
  });
  if(S.slShare<0.5){
    add(1e6*(0.5-S.slShare)+50,'Alto','Colocar stop loss em todas as entradas',
      'Só '+Math.round(S.slShare*100)+'% das posições tinham S/L. Sem stop, uma única operação pode apagar semanas de lucro.');
  }
  if(S.lotRatio>=6){
    var big=P.slice().sort(function(x,y){return y.volume-x.volume;})[0];
    add(400,'Alto','Padronizar o tamanho do lote',
      'A maior entrada ('+big.volume+' em '+big.symbol+') foi '+S.lotRatio.toFixed(1).replace('.',',')+'× o lote mediano ('+S.medV+'). Use a calculadora de lote abaixo para definir um tamanho fixo por risco.');
  }
  var grp={};
  r.open.forEach(function(p){ var k=p.symbol+'|'+p.type; (grp[k]=grp[k]||[]).push(p); });
  Object.keys(grp).forEach(function(k){ var g=grp[k]; if(g.length<3) return;
    var noSl=g.filter(function(p){return !(p.sl>0);}).length; if(!noSl) return;
    var fl=g.reduce(function(s,p){return s+p.profit;},0);
    add(600+Math.abs(Math.min(0,fl))*2,'Alto','Definir um stop para as '+g.length+' posições abertas em '+g[0].symbol,
      noSl+' delas estão sem stop e o flutuante é '+money(fl,true)+'. Defina até onde aceita perder antes de abrir a próxima.');
  });
  if(heat.worstHour && heat.worstHour.sum<0 && heat.worstHour.n>=2){
    add(Math.abs(heat.worstHour.sum)*0.8,'Médio','Evitar operar às '+String(heat.worstHour.h).padStart(2,'0')+'h',
      'É o horário de abertura com pior resultado: '+money(heat.worstHour.sum,true)+' em '+heat.worstHour.n+' operações.');
  }
  if(heat.worstDay && heat.worstDay.sum<0 && heat.worstDay.n>=3){
    add(Math.abs(heat.worstDay.sum)*0.7,'Médio','Reduzir a exposição na '+DIAS_LONGO[heat.worstDay.d],
      'Dia da semana com pior resultado: '+money(heat.worstDay.sum,true)+' em '+heat.worstDay.n+' operações.');
  }
  var w=P.filter(function(p){return p.v>0;}), l=P.filter(function(p){return p.v<0;});
  var hw=median(w.map(function(p){return p.hold;})), hl=median(l.map(function(p){return p.hold;}));
  if(l.length>=3 && w.length>=3 && hl>2*hw){
    add(300,'Médio','Cortar as perdas mais cedo',
      'Operações perdedoras ficam abertas '+dur(hl)+' (mediana) contra '+dur(hw)+' das vencedoras. Segurar o prejuízo esperando voltar aumenta a perda média.');
  }
  if(S.rr<0.7 && S.wr>0.55 && l.length>=3){
    add(250,'Médio','Equilibrar alvo e stop',
      'O ganho médio ('+money(S.avgW)+') é só '+Math.round(S.rr*100)+'% da perda média ('+money(S.avgL)+'). Cada perda exige '+(1/S.rr).toFixed(1).replace('.',',')+' ganhos para ser compensada.');
  }
  if(mcBase && mcBase.p30>0.15){
    add(500+mcBase.p30*1000,'Alto','Reduzir o risco por operação',
      'Com o lote atual, a simulação mostra '+pct(mcBase.p30*100,0)+' de chance de a conta cair 30% nos próximos '+mcBase.N+' trades.'+(mcHalf?' Com metade do lote, a chance cai para '+pct(mcHalf.p30*100,0)+'.':''));
  }
  var best=a.bots.filter(function(b){return b.net>0;})[0];
  if(best) add(1,'Manter','Manter o que funciona: '+(best.name||'Trading Manual'),
    'Rendeu '+money(best.net,true)+' em '+best.n+' operações, com acerto de '+pct(best.n?best.w/best.n*100:0)+'.');

  acts.sort(function(x,y){return y.prio-x.prio;});
  return acts.slice(0,5);
}

function renderScore(D,S,plan){
  var R=52, C=2*Math.PI*R, off=C*(1-S.total/100);
  var col=S.total>=65?'var(--green)':S.total>=50?'var(--gold)':'var(--red)';
  var ring='<svg viewBox="0 0 140 140" class="ring" role="img" aria-label="Nota '+S.total+' de 100">'
    +'<circle cx="70" cy="70" r="'+R+'" fill="none" stroke="var(--bg3)" stroke-width="12"/>'
    +'<circle cx="70" cy="70" r="'+R+'" fill="none" stroke="'+col+'" stroke-width="12" stroke-linecap="round" stroke-dasharray="'+C.toFixed(1)+'" stroke-dashoffset="'+off.toFixed(1)+'" transform="rotate(-90 70 70)"/>'
    +'<text x="70" y="72" text-anchor="middle" fill="var(--txt)" font-family="JetBrains Mono,Consolas,monospace" font-size="34" font-weight="600">'+S.total+'</text>'
    +'<text x="70" y="94" text-anchor="middle" fill="var(--txt3)" font-size="11">de 100</text></svg>';
  var parts=S.parts.map(function(p){
    var w=clamp(p.v/20*100,0,100), c=p.v>=14?'var(--green)':p.v>=8?'var(--gold)':'var(--red)';
    return '<div class="sc-part"><div class="sc-top"><span>'+p.k+'</span><span class="mono">'+Math.round(p.v)+'/20</span></div>'
      +'<div class="wr-track"><div class="wr-fill" style="width:'+w+'%;background:'+c+'"></div></div><div class="sc-d">'+esc(p.d)+'</div></div>';
  }).join('');
  document.getElementById('proScore').innerHTML=
    '<div class="sc-ring">'+ring+'<div class="sc-grade" style="color:'+col+'">Conta '+S.grade.toLowerCase()+'</div></div>'
    +'<div class="sc-parts">'+parts+'</div>';
  document.getElementById('proPlan').innerHTML=plan.map(function(x,i){
    var cl=x.imp==='Alto'?'bad':x.imp==='Médio'?'warn':'ok';
    return '<li class="plan-item"><span class="plan-n mono">'+(i+1)+'</span><div><div class="plan-h"><b>'+esc(x.title)+'</b><span class="chip '+cl+'">'+(x.imp==='Manter'?'Manter':'Impacto '+x.imp.toLowerCase())+'</span></div><p>'+esc(x.text)+'</p></div></li>';
  }).join('');
}

/* ================= 2. LOTE PROPORCIONAL ================= */
function lotModel(D){
  var bySym={};
  D.P.forEach(function(p){ (bySym[p.symbol]=bySym[p.symbol]||{closed:[],open:[]}).closed.push(p); });
  D.r.open.forEach(function(p){ (bySym[p.symbol]=bySym[p.symbol]||{closed:[],open:[]}).open.push(p); });
  return Object.keys(bySym).map(function(s){
    var g=bySym[s];
    var vpu=median(g.closed.filter(function(p){return p.volume>0 && isFinite(p.closePrice) && Math.abs(p.closePrice-p.price)>0 && p.profit!==0;})
      .map(function(p){ return Math.abs(p.profit)/(Math.abs(p.closePrice-p.price)*p.volume); }));
    var withSl=g.closed.concat(g.open).filter(function(p){return p.sl>0 && isFinite(p.price);}).map(function(p){return Math.abs(p.price-p.sl);}).filter(function(x){return x>0;});
    var stop=NaN, src='';
    if(withSl.length){ stop=median(withSl); src='mediana do seu S/L'; }
    else {
      var losers=g.closed.filter(function(p){return p.v<0 && isFinite(p.closePrice);}).map(function(p){return Math.abs(p.closePrice-p.price);}).filter(function(x){return x>0;});
      if(losers.length){ stop=median(losers); src='perda típica observada'; }
      else { var all=g.closed.filter(function(p){return isFinite(p.closePrice);}).map(function(p){return Math.abs(p.closePrice-p.price);}).filter(function(x){return x>0;});
        if(all.length){ stop=median(all); src='movimento típico'; } }
    }
    return {s:s,vpu:vpu,stop:stop,src:src,used:median(g.closed.concat(g.open).map(function(p){return p.volume;}).filter(function(v){return v>0;})),n:g.closed.length};
  }).filter(function(m){return isFinite(m.vpu)&&m.vpu>0;}).sort(function(x,y){return y.n-x.n;});
}

function renderLots(){
  var st=PRO.lot, bal=st.bal, risk=st.risk/100, budget=bal*risk;
  document.getElementById('lotBudget').textContent=money(budget);
  document.getElementById('lotBody').innerHTML=st.model.map(function(m,i){
    var stop=isFinite(st.stops[m.s])?st.stops[m.s]:m.stop;
    var lot=(isFinite(stop)&&stop>0)?budget/(stop*m.vpu):NaN;
    var ratio=(isFinite(lot)&&lot>0)?m.used/lot:NaN;
    var tag=!isFinite(lot)?'<span class="chip warn">sem dados</span>'
      :lot<0.01?'<span class="chip bad">stop grande p/ saldo</span>'
      :ratio>1.5?'<span class="chip bad">usa '+ratio.toFixed(1).replace('.',',')+'× o ideal</span>'
      :ratio<0.5?'<span class="chip warn">abaixo do ideal</span>':'<span class="chip ok">ok</span>';
    return '<tr><td><span class="sym-name">'+esc(m.s)+'</span><div class="note">'+m.n+' trades · $'+nf(m.vpu,m.vpu<10?2:0)+' por 1,0 de preço/lote</div></td>'
      +'<td><input class="lot-in mono" type="number" step="any" min="0" id="stop_'+i+'" data-sym="'+esc(m.s)+'" value="'+(isFinite(stop)?+stop.toPrecision(5):'')+'" aria-label="Distância do stop em '+esc(m.s)+'"><div class="note">'+esc(m.src||'informe o stop')+'</div></td>'
      +'<td class="mono">'+(isFinite(stop)?money(stop*m.vpu*0.01):'—')+'</td>'
      +'<td class="mono lot-big">'+(isFinite(lot)?(lot<0.01?'0,01*':lotFmt(lot)):'—')+'</td>'
      +'<td class="mono">'+(isFinite(m.used)?nf(Math.round(m.used*100)/100):'—')+'</td><td>'+tag+'</td></tr>';
  }).join('') || '<tr><td colspan="6" class="note">Sem operações suficientes para estimar o valor do ponto.</td></tr>';
  Array.prototype.forEach.call(document.querySelectorAll('.lot-in'),function(inp){
    inp.onchange=function(){ var v=num(inp.value); st.stops[inp.getAttribute('data-sym')]=v>0?v:NaN; renderLots(); };
  });
  /* operações que arriscaram mais que o orçamento */
  var over=PRO.D.P.filter(function(p){return p.v<0 && -p.pct>risk;}).sort(function(x,y){return x.pct-y.pct;});
  document.getElementById('lotOver').innerHTML=over.length
    ?'<b>'+over.length+' operaç'+(over.length>1?'ões perderam':'ão perdeu')+' mais de '+pct(st.risk,1)+' do saldo</b> numa só entrada. Piores: '
      +over.slice(0,4).map(function(p){return esc(p.symbol)+' '+dBR(p.open)+' ('+pct(p.pct*100,1)+')';}).join(', ')+'.'
    :'Nenhuma operação perdeu mais de '+pct(st.risk,1)+' do saldo numa só entrada.';
}

/* ================= 3. MONTE CARLO ================= */
function monteCarlo(rets,N,mult,runs,seed){
  var rnd=mulberry32(seed||42), n=rets.length;
  var paths=new Array(N+1); for(var s=0;s<=N;s++) paths[s]=new Float64Array(runs);
  var finals=new Float64Array(runs), dds=new Float64Array(runs);
  for(var k=0;k<runs;k++){
    var eq=1, peak=1, mdd=0; paths[0][k]=1;
    for(var t=1;t<=N;t++){
      var r=rets[Math.floor(rnd()*n)]*mult;
      eq=Math.max(0,eq*(1+r)); if(eq>peak) peak=eq;
      var dd=peak>0?(peak-eq)/peak:1; if(dd>mdd) mdd=dd;
      paths[t][k]=eq;
    }
    finals[k]=eq; dds[k]=mdd;
  }
  var fs=Array.prototype.slice.call(finals).sort(function(a,b){return a-b;});
  var ds=Array.prototype.slice.call(dds).sort(function(a,b){return a-b;});
  function share(th){ var c=0; for(var i=0;i<runs;i++) if(dds[i]>=th) c++; return c/runs; }
  var bands=[]; for(var t2=0;t2<=N;t2++){ var col=Array.prototype.slice.call(paths[t2]).sort(function(a,b){return a-b;});
    bands.push([quantile(col,.05),quantile(col,.25),quantile(col,.5),quantile(col,.75),quantile(col,.95)]); }
  var loss=0; for(var j=0;j<runs;j++) if(finals[j]<1) loss++;
  return {N:N,mult:mult,runs:runs,p20:share(.2),p30:share(.3),p50:share(.5),
    medFinal:quantile(fs,.5),p5Final:quantile(fs,.05),p95Final:quantile(fs,.95),
    medDD:quantile(ds,.5),p95DD:quantile(ds,.95),pLoss:loss/runs,bands:bands};
}
function renderMC(){
  var st=PRO.mc;
  var box=document.getElementById('mcBox');
  if(PRO.rets.length<10){ box.innerHTML='<p class="note">São necessárias pelo menos 10 operações fechadas para a simulação. Este relatório tem '+PRO.rets.length+'.</p>'; return; }
  var m=monteCarlo(PRO.rets,st.N,st.mult,1000,7);
  st.last=m;
  function tile(l,v,c,s){ return '<div class="mc-tile"><span class="kpi-label">'+l+'</span><span class="mc-v mono" style="color:'+c+'">'+v+'</span><span class="kpi-sub">'+s+'</span></div>'; }
  function riskCol(p){ return p>=.25?'var(--red)':p>=.1?'var(--gold)':'var(--green)'; }
  document.getElementById('mcTiles').innerHTML=
     tile('Cair 20%',pct(m.p20*100,1),riskCol(m.p20),'chance em '+m.N+' trades')
    +tile('Cair 30%',pct(m.p30*100,1),riskCol(m.p30),'chance em '+m.N+' trades')
    +tile('Perder metade',pct(m.p50*100,1),riskCol(m.p50),'risco de ruína (−50%)')
    +tile('Resultado típico',(m.medFinal>=1?'+':'')+pct((m.medFinal-1)*100,1),m.medFinal>=1?'var(--green)':'var(--red)','mediana dos cenários')
    +tile('Pior cenário comum',(m.p5Final>=1?'+':'')+pct((m.p5Final-1)*100,1),m.p5Final>=1?'var(--green)':'var(--red)','5% dos cenários ficam abaixo')
    +tile('Queda típica',pct(m.medDD*100,1),'var(--gold)','drawdown mediano · 95%: '+pct(m.p95DD*100,1));
  document.getElementById('mcNote').textContent='1.000 sequências sorteadas a partir dos seus '+PRO.rets.length+' resultados reais (em % do saldo), '
    +(st.mult===1?'com o lote atual':'com o lote '+(st.mult<1?'reduzido pela metade':'dobrado'))+'. '
    +(m.pLoss>0?pct(m.pLoss*100,0)+' dos cenários terminam abaixo do saldo inicial.':'Nenhum cenário terminou abaixo do saldo inicial.');
  requestAnimationFrame(drawMC);
}
function drawMC(){
  if(!PRO||!PRO.mc.last) return;
  var m=PRO.mc.last, c=document.getElementById('mcChart'); if(!c) return;
  var dpr=window.devicePixelRatio||1, W=c.getBoundingClientRect().width, H=240; if(!W) return;
  c.width=W*dpr; c.height=H*dpr; var x=c.getContext('2d'); x.setTransform(dpr,0,0,dpr,0,0); x.clearRect(0,0,W,H);
  var P={t:14,r:12,b:28,l:52}, cw=W-P.l-P.r, ch=H-P.t-P.b, N=m.N;
  var lo=Math.min(1,m.bands.reduce(function(s,b){return Math.min(s,b[0]);},1)), hi=Math.max(1,m.bands.reduce(function(s,b){return Math.max(s,b[4]);},1));
  var loP=Math.floor((lo-1)*10)/10, hiP=Math.ceil((hi-1)*10)/10; if(hiP-loP<0.2){hiP+=0.1;loP-=0.1;}
  var stepP=niceStep((hiP-loP)*100)/100;
  function X(t){return P.l+t/N*cw;} function Y(v){return P.t+ch-((v-1)-loP)/(hiP-loP)*ch;}
  x.font='10px "JetBrains Mono", Consolas, monospace';
  for(var g=Math.ceil(loP/stepP)*stepP; g<=hiP+1e-9; g+=stepP){ var y=Y(1+g);
    x.strokeStyle=Math.abs(g)<1e-9?'rgba(136,152,187,.55)':'rgba(38,50,72,.9)'; x.lineWidth=1; x.beginPath(); x.moveTo(P.l,y); x.lineTo(W-P.r,y); x.stroke();
    x.fillStyle='#5B6F8F'; x.textAlign='right'; x.fillText((g>0?'+':g<0?'−':'')+Math.round(Math.abs(g)*100)+'%',P.l-6,y+3.5); }
  function band(i0,i1,col){ x.beginPath(); for(var t=0;t<=N;t++) x.lineTo(X(t),Y(m.bands[t][i1])); for(var t2=N;t2>=0;t2--) x.lineTo(X(t2),Y(m.bands[t2][i0])); x.closePath(); x.fillStyle=col; x.fill(); }
  band(0,4,'rgba(91,140,247,.13)'); band(1,3,'rgba(91,140,247,.25)');
  x.beginPath(); for(var t=0;t<=N;t++){ var px=X(t),py=Y(m.bands[t][2]); t?x.lineTo(px,py):x.moveTo(px,py);} x.strokeStyle='#5B8CF7'; x.lineWidth=1.8; x.stroke();
  x.fillStyle='#5B6F8F'; x.textAlign='center';
  [0,.25,.5,.75,1].forEach(function(f){ var t=Math.round(N*f); x.fillText(t===0?'hoje':t+' trades',clamp(X(t),P.l+18,W-P.r-26),H-P.b+16); });
}

/* ================= 4. MAPA DE CALOR ================= */
function heatData(D){
  var cells={}, days={}, hours={};
  D.P.forEach(function(p){ var d=p.open.getDay(), h=p.open.getHours(), k=d+'_'+h;
    var c=cells[k]||(cells[k]={sum:0,n:0}); c.sum+=p.v; c.n++;
    var dd=days[d]||(days[d]={d:d,sum:0,n:0}); dd.sum+=p.v; dd.n++;
    var hh=hours[h]||(hours[h]={h:h,sum:0,n:0}); hh.sum+=p.v; hh.n++; });
  var dl=Object.keys(days).map(function(k){return days[k];}), hl=Object.keys(hours).map(function(k){return hours[k];});
  function best(l){return l.slice().sort(function(a,b){return b.sum-a.sum;})[0];} function worst(l){return l.slice().sort(function(a,b){return a.sum-b.sum;})[0];}
  return {cells:cells,days:days,hours:hours,bestDay:best(dl),worstDay:worst(dl),bestHour:best(hl),worstHour:worst(hl)};
}
function renderHeat(H){
  var keys=Object.keys(H.cells), mx=Math.max.apply(null,keys.map(function(k){return Math.abs(H.cells[k].sum);}).concat([1]));
  var order=[1,2,3,4,5,6,0].filter(function(d){return H.days[d];});
  var head='<tr><th></th>'; for(var h=0;h<24;h++) head+='<th>'+String(h).padStart(2,'0')+'</th>'; head+='<th class="hm-tot">Total</th></tr>';
  var body=order.map(function(d){
    var row='<tr><th class="hm-day">'+DIAS[d]+'</th>';
    for(var h=0;h<24;h++){ var c=H.cells[d+'_'+h];
      if(!c){ row+='<td class="hm-c hm-empty"></td>'; continue; }
      var a=0.32+0.68*Math.min(1,Math.abs(c.sum)/mx), col=c.sum>=0?'14,207,168':'255,71,104';
      row+='<td class="hm-c" style="background:rgba('+col+','+a.toFixed(2)+')" title="'+DIAS_LONGO[d]+' '+String(h).padStart(2,'0')+'h · '+c.n+' trade(s) · '+money(c.sum,true)+'"></td>'; }
    var t=H.days[d];
    return row+'<td class="hm-tot mono '+cls(t.sum)+'">'+moneyShort(t.sum,true)+'</td></tr>';
  }).join('');
  var foot='<tr><th class="hm-day">Total</th>'; for(var h2=0;h2<24;h2++){ var hh=H.hours[h2];
    foot+='<td class="hm-foot mono '+(hh?cls(hh.sum):'')+'">'+(hh?(hh.sum>=0?'+':'−')+Math.round(Math.abs(hh.sum)):'')+'</td>'; }
  foot+='<td></td></tr>';
  document.getElementById('heatTable').innerHTML='<thead>'+head+'</thead><tbody>'+body+foot+'</tbody>';
  function card(l,v,s,c){ return '<div class="mc-tile"><span class="kpi-label">'+l+'</span><span class="mc-v mono" style="color:'+c+'">'+v+'</span><span class="kpi-sub">'+s+'</span></div>'; }
  document.getElementById('heatTiles').innerHTML=
     card('Melhor dia',DIAS_LONGO[H.bestDay.d],money(H.bestDay.sum,true)+' em '+H.bestDay.n+' trades','var(--green)')
    +card('Pior dia',DIAS_LONGO[H.worstDay.d],money(H.worstDay.sum,true)+' em '+H.worstDay.n+' trades',H.worstDay.sum<0?'var(--red)':'var(--txt2)')
    +card('Melhor horário',String(H.bestHour.h).padStart(2,'0')+'h',money(H.bestHour.sum,true)+' em '+H.bestHour.n+' trades','var(--green)')
    +card('Pior horário',String(H.worstHour.h).padStart(2,'0')+'h',money(H.worstHour.sum,true)+' em '+H.worstHour.n+' trades',H.worstHour.sum<0?'var(--red)':'var(--txt2)');
}

/* ================= 5. RISCO × RETORNO ================= */
function rrRow(name,list){
  var w=list.filter(function(p){return p.v>0;}), l=list.filter(function(p){return p.v<0;});
  var wr=list.length?w.length/list.length:0;
  var aw=w.length?netOf(w)/w.length:0, al=l.length?Math.abs(netOf(l)/l.length):0;
  var rr=al?aw/al:(aw>0?Infinity:0), be=isFinite(rr)?1/(1+rr):0, edge=(wr-be)*100;
  var hw=median(w.map(function(p){return p.hold;})), hl=median(l.map(function(p){return p.hold;}));
  var diag, dc;
  if(list.length<5){ diag='amostra pequena'; dc='warn'; }
  else if(edge<0){ diag='sem vantagem: acerto abaixo do mínimo'; dc='bad'; }
  else if(l.length>=3 && w.length>=3 && hl>2*hw){ diag='segura perdas por mais tempo'; dc='warn'; }
  else if(isFinite(rr) && rr<0.6 && wr>0.6){ diag='ganha pouco e perde muito (alvo curto ou stop longo)'; dc='warn'; }
  else if(rr>2 && wr<0.35){ diag='alvo longo ou stop curto demais'; dc='warn'; }
  else { diag='equilibrado'; dc='ok'; }
  return '<tr><td><span class="sym-name">'+esc(name)+'</span></td><td class="mono">'+list.length+'</td><td class="mono">'+pct(wr*100)+'</td>'
    +'<td class="mono pos">'+money(aw)+'</td><td class="mono neg">'+(al?'−'+money(al):'—')+'</td>'
    +'<td class="mono">'+(isFinite(rr)?rr.toFixed(2).replace('.',','):'∞')+'</td><td class="mono">'+pct(be*100)+'</td>'
    +'<td class="mono '+(edge>=0?'pos':'neg')+'">'+(edge>=0?'+':'')+edge.toFixed(1).replace('.',',')+'</td>'
    +'<td class="mono '+cls(list.length?netOf(list)/list.length:0)+'">'+money(list.length?netOf(list)/list.length:0,true)+'</td>'
    +'<td class="mono">'+dur(hw)+' / '+dur(hl)+'</td><td><span class="chip '+dc+'">'+esc(diag)+'</span></td></tr>';
}
function renderRR(D){
  var bots={}, syms={};
  D.P.forEach(function(p){ (bots[botName(p.comment)]=bots[botName(p.comment)]||[]).push(p); (syms[p.symbol]=syms[p.symbol]||[]).push(p); });
  function rows(obj,manual){ return Object.keys(obj).sort(function(x,y){return netOf(obj[y])-netOf(obj[x]);}).map(function(k){return rrRow(k||manual,obj[k]);}).join(''); }
  document.getElementById('rrBots').innerHTML=rows(bots,'Trading Manual');
  document.getElementById('rrSyms').innerHTML=rows(syms,'—');
}

/* ================= 6. E SE ================= */
function statsOf(list){
  var s=list.slice().sort(function(x,y){return x.close-y.close;}), net=0, gp=0, gl=0, w=0, peak=0, run=0, dd=0, cum=[0];
  s.forEach(function(p){ net+=p.v; run+=p.v; if(p.v>0){gp+=p.v;w++;} else if(p.v<0) gl+=p.v; if(run>peak)peak=run; dd=Math.max(dd,peak-run); cum.push(run); });
  return {n:s.length,net:net,wr:s.length?w/s.length*100:0,pf:gl?gp/Math.abs(gl):(gp>0?Infinity:0),dd:dd,cum:cum,list:s};
}
function renderWhatIf(){
  var D=PRO.D, st=PRO.wi, H=PRO.heat;
  var badHours={}, badDays={};
  Object.keys(H.hours).forEach(function(k){ if(H.hours[k].sum<0) badHours[k]=1; });
  Object.keys(H.days).forEach(function(k){ if(H.days[k].sum<0) badDays[k]=1; });
  var keep=D.P.filter(function(p){
    if(st.bots[botName(p.comment)]) return false;
    if(st.syms[p.symbol]) return false;
    if(st.badHours && badHours[p.open.getHours()]) return false;
    if(st.badDays && badDays[p.open.getDay()]) return false;
    return true;
  });
  var A=statsOf(D.P), B=statsOf(keep); PRO.wi.A=A; PRO.wi.B=B;
  function row(l,va,vb,fmtf,better){ var d=vb-va, good=better==='up'?d>0:d<0;
    return '<tr><td>'+l+'</td><td class="mono">'+fmtf(va)+'</td><td class="mono">'+fmtf(vb)+'</td><td class="mono '+(Math.abs(d)<1e-9?'neu':(good?'pos':'neg'))+'">'+(Math.abs(d)<1e-9?'=':(d>0?'+':'−')+fmtf(Math.abs(d)).replace(/^[+−]/,''))+'</td></tr>'; }
  var f$=function(v){return money(v);}, fp=function(v){return pct(v);}, fn=function(v){return String(Math.round(v));}, ff=function(v){return isFinite(v)?nf(v):'∞';};
  document.getElementById('wiTable').innerHTML='<thead><tr><th>Métrica</th><th>Real</th><th>Simulado</th><th>Diferença</th></tr></thead><tbody>'
    +row('Resultado',A.net,B.net,f$,'up')+row('Operações',A.n,B.n,fn,'none')+row('Acerto',A.wr,B.wr,fp,'up')
    +row('Fator de lucro',isFinite(A.pf)?A.pf:99,isFinite(B.pf)?B.pf:99,ff,'up')+row('Queda máxima ($)',A.dd,B.dd,f$,'down')+'</tbody>';
  requestAnimationFrame(drawWhatIf);
}
function drawWhatIf(){
  if(!PRO||!PRO.wi.A) return;
  var c=document.getElementById('wiChart'); var dpr=window.devicePixelRatio||1, W=c.getBoundingClientRect().width, H=200; if(!W) return;
  c.width=W*dpr; c.height=H*dpr; var x=c.getContext('2d'); x.setTransform(dpr,0,0,dpr,0,0); x.clearRect(0,0,W,H);
  var A=PRO.wi.A.cum, B=PRO.wi.B.cum, all=A.concat(B), mn=Math.min.apply(null,all), mx=Math.max.apply(null,all); if(mx===mn){mx+=1;mn-=1;}
  var step=niceStep(mx-mn), lo=Math.floor(mn/step)*step, hi=Math.ceil(mx/step)*step;
  var P={t:12,r:12,b:22,l:62}, cw=W-P.l-P.r, ch=H-P.t-P.b;
  function Y(v){return P.t+ch-(v-lo)/(hi-lo)*ch;}
  x.font='10px "JetBrains Mono", Consolas, monospace';
  for(var g=lo; g<=hi+1e-9; g+=step){ var y=Y(g); x.strokeStyle=Math.abs(g)<1e-9?'rgba(136,152,187,.55)':'rgba(38,50,72,.9)'; x.beginPath(); x.moveTo(P.l,y); x.lineTo(W-P.r,y); x.stroke();
    x.fillStyle='#5B6F8F'; x.textAlign='right'; x.fillText((g<0?'−':'')+'$'+Math.abs(g).toLocaleString('pt-BR'),P.l-6,y+3.5); }
  function line(arr,col,wd){ var n=arr.length-1||1; x.beginPath(); arr.forEach(function(v,i){ var px=P.l+i/n*cw, py=Y(v); i?x.lineTo(px,py):x.moveTo(px,py); }); x.strokeStyle=col; x.lineWidth=wd; x.stroke(); }
  line(A,'rgba(136,152,187,.8)',1.4); line(B,'#0ECFA8',2);
  x.fillStyle='#5B6F8F'; x.textAlign='left'; x.fillText('eixo: operações em ordem de fechamento',P.l,H-6);
}

/* ================= orquestração ================= */
function renderPro(r,a){
  var D=proPrepare(r,a);
  var rets=D.P.map(function(p){return p.pct;}).filter(function(v){return isFinite(v);});
  PRO={D:D,rets:rets,lot:{},mc:{N:100,mult:1},wi:{bots:{},syms:{},badHours:false,badDays:false},heat:heatData(D)};

  var mcBase=rets.length>=10?monteCarlo(rets,100,1,1000,7):null;
  var mcHalf=rets.length>=10?monteCarlo(rets,100,.5,1000,7):null;
  var S=proScore(D,mcBase);
  renderScore(D,S,proPlan(D,S,mcBase,mcHalf,PRO.heat));

  /* lote */
  var bal=isFinite(a.endBal)&&a.endBal>0?a.endBal:1000;
  PRO.lot={bal:bal,risk:1,stops:{},model:lotModel(D)};
  var bi=document.getElementById('lotBal'), ri=document.getElementById('lotRisk');
  bi.value=Math.round(bal*100)/100; ri.value=1;
  bi.onchange=function(){ var v=num(bi.value); if(v>0){PRO.lot.bal=v; renderLots();} };
  ri.onchange=function(){ var v=num(ri.value); if(v>0){PRO.lot.risk=v; syncChips('riskChips',v); renderLots();} };
  wireChips('riskChips',function(v){ PRO.lot.risk=v; ri.value=v; renderLots(); });
  syncChips('riskChips',1);
  renderLots();

  /* monte carlo */
  wireChips('mcN',function(v){ PRO.mc.N=v; renderMC(); }); syncChips('mcN',100);
  wireChips('mcMult',function(v){ PRO.mc.mult=v; renderMC(); }); syncChips('mcMult',1);
  renderMC();

  renderHeat(PRO.heat);
  renderRR(D);

  /* e se */
  var opts=[];
  a.bots.forEach(function(b,i){ opts.push('<label class="wi-opt"><input type="checkbox" id="wib'+i+'" data-k="bot" data-v="'+esc(b.name)+'"> Sem '+esc(b.name||'Trading Manual')+' <span class="mono '+cls(b.net)+'">'+moneyShort(b.net,true)+'</span></label>'); });
  a.syms.forEach(function(s,i){ opts.push('<label class="wi-opt"><input type="checkbox" id="wis'+i+'" data-k="sym" data-v="'+esc(s.s)+'"> Sem '+esc(s.s)+' <span class="mono '+cls(s.net)+'">'+moneyShort(s.net,true)+'</span></label>'); });
  opts.push('<label class="wi-opt"><input type="checkbox" id="wih" data-k="hours"> Sem os horários no prejuízo</label>');
  opts.push('<label class="wi-opt"><input type="checkbox" id="wid" data-k="days"> Sem os dias no prejuízo</label>');
  var box=document.getElementById('wiOpts'); box.innerHTML=opts.join('');
  Array.prototype.forEach.call(box.querySelectorAll('input'),function(inp){
    inp.onchange=function(){ var k=inp.getAttribute('data-k'), v=inp.getAttribute('data-v');
      if(k==='bot') PRO.wi.bots[v]=inp.checked; else if(k==='sym') PRO.wi.syms[v]=inp.checked;
      else if(k==='hours') PRO.wi.badHours=inp.checked; else PRO.wi.badDays=inp.checked;
      renderWhatIf(); };
  });
  renderWhatIf();
}

function wireChips(id,cb){
  Array.prototype.forEach.call(document.querySelectorAll('#'+id+' button'),function(b){
    b.onclick=function(){ var v=num(b.getAttribute('data-v')); syncChips(id,v); cb(v); };
  });
}
function syncChips(id,v){
  Array.prototype.forEach.call(document.querySelectorAll('#'+id+' button'),function(b){
    b.setAttribute('aria-pressed',String(Math.abs(num(b.getAttribute('data-v'))-v)<1e-9)); });
}
function drawProCharts(){ drawMC(); drawWhatIf(); }
window.addEventListener('resize',drawProCharts);
window.addEventListener('beforeprint',drawProCharts);
