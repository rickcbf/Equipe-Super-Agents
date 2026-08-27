import edge_tts, asyncio, os

VOICE = "pt-BR-AntonioNeural"
RATE = "-5%"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "audio")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SCENES = [
    ("cena01-hook", "Você ainda perde tempo alternando entre TradingView, planilhas e anotações pra analisar ouro?"),
    ("cena02-dor", "Abre o TradingView... confere RSI... olha o DXY... verifica a sessão... calcula o risco... e quando termina — o setup já passou."),
    ("cena03-reveal", "Eu criei uma ferramenta que resolve isso. O MCP TradingView Gold conecta o Claude AI direto no TradingView. Você pergunta — ele responde com dados ao vivo."),
    ("cena04-demo", "Olha isso: eu pergunto como está o ouro e em segundos recebo preço atualizado, RSI, ADX, EMAs, MACD, Bollinger Bands — tudo direto do TradingView. Sem abrir nenhuma aba."),
    ("cena05-snapshot", "Gold Snapshot — preço, RSI, ADX, MACD e recomendação em qualquer timeframe. Do minuto ao mensal."),
    ("cena06-context", "Market Context — análise pré-mercado automática: ouro mais DXY com correlações e detecção de sessão."),
    ("cena07-ta", "Análise técnica completa pra qualquer ativo — forex, crypto, índices, ações."),
    ("cena08-mtf", "Multi-Timeframe — quatro timeframes de uma vez com detecção automática de alinhamento HTF. Bull, bear ou misto."),
    ("cena09-filters", "E a mais poderosa: Check Entry Filters. Cinco filtros de entrada automatizados — tendência, estrutura, momentum, sessão e risco. PASS ou FAIL instantâneo. Acabou o achismo."),
    ("cena10-install", "Instala em dois minutos. Clicou, rodou, pronto. Instalador automático — não precisa ser programador. Não precisa de API key. Não precisa de conta no TradingView."),
    ("cena11-quem", "Meu nome é Rick, RicharTrader. Eu opero XAUUSD profissionalmente e construo ferramentas de trading com inteligência artificial. Essa ferramenta é a mesma que eu uso no meu dia a dia."),
    ("cena12-cta", "Tudo isso por apenas noventa e sete reais. Garantia de sete dias — se não gostar, devolvemos seu dinheiro. Clica no link aqui embaixo e começa a operar com dados ao vivo do TradingView dentro do Claude AI."),
    ("cena13-fim", "RicharTrader. Opere com inteligência."),
]

async def generate():
    for name, text in SCENES:
        out_path = os.path.join(OUTPUT_DIR, f"{name}.mp3")
        communicate = edge_tts.Communicate(text, VOICE, rate=RATE)
        await communicate.save(out_path)
        print(f"OK: {name}.mp3")

asyncio.run(generate())
print(f"\nTodos os {len(SCENES)} audios gerados em video-assets/audio/")
