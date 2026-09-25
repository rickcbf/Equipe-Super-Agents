# Gera ../Gerador-Licenca-FiboGrid.html embutindo o modelo RickEA_FiboGrid_v4_Licenca.mq5.
# Rode de novo sempre que alterar o .mq5 modelo:  python3 build.py
import json, os
d = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(d, '..', 'RickEA_FiboGrid_v4_Licenca.mq5'), 'rb').read().decode('ascii')
tpl = open(os.path.join(d, 'gerador.template.html'), encoding='utf-8').read()
out = tpl.replace('__TEMPLATE__', json.dumps(src).replace('</', '<\\/'))
open(os.path.join(d, '..', 'Gerador-Licenca-FiboGrid.html'), 'w', encoding='utf-8').write(out)
print('ok', len(out))
