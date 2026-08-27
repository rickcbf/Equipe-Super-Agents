import edge_tts, asyncio

async def main():
    voices = await edge_tts.list_voices()
    for v in voices:
        if 'pt-BR' in v['ShortName']:
            print(f"{v['ShortName']} — {v['Gender']} — {v['FriendlyName']}")

asyncio.run(main())
