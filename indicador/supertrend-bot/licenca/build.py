# Gera ../Gerador-Licenca-SuperTrendBot.html embutindo o modelo RickEA_SuperTrend_Bot_V2_Licenca.mq5.
# Rode de novo sempre que alterar o .mq5 modelo:  python3 build.py
import json, os
d = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(d, '..', 'RickEA_SuperTrend_Bot_V2_Licenca.mq5'), 'rb').read().decode('ascii')
tpl = open(os.path.join(d, 'gerador.template.html'), encoding='utf-8').read()
out = tpl.replace('__TEMPLATE__', json.dumps(src).replace('</', '<\\/'))
open(os.path.join(d, '..', 'Gerador-Licenca-SuperTrendBot.html'), 'w', encoding='utf-8').write(out)
print('ok', len(out))
