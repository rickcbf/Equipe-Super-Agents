"""
Build MCP TradingView Gold sales video v2.
Uses real screen recording for demo scenes.
"""
from moviepy import (
    ImageClip, AudioFileClip, VideoFileClip, concatenate_videoclips,
)
from moviepy.video.fx import FadeIn, FadeOut
import os

BASE = os.path.dirname(__file__)
PNG_DIR = os.path.join(BASE, "png")
AUDIO_DIR = os.path.join(BASE, "audio")
OUTPUT = os.path.join(BASE, "MCP-TradingView-Gold-VIDEO-v2.mp4")

DEMO_FILE = os.path.join(BASE, "demo-gold-snapshot.mp4")

FADE = 0.5
FPS = 30

def make_image_scene(png_name, audio_name):
    png_path = os.path.join(PNG_DIR, png_name)
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    audio = AudioFileClip(audio_path)
    duration = audio.duration + 1.0
    clip = (
        ImageClip(png_path)
        .with_duration(duration)
        .resized((1920, 1080))
        .with_audio(audio)
        .with_effects([FadeIn(FADE), FadeOut(FADE)])
    )
    return clip, duration

def make_demo_scene(audio_name, start_time=0, end_time=None):
    """Use real screen recording with narration audio overlay."""
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    narration = AudioFileClip(audio_path)
    duration = narration.duration + 1.0

    demo = VideoFileClip(DEMO_FILE)
    if end_time:
        demo = demo.subclipped(start_time, min(end_time, demo.duration))
    else:
        demo = demo.subclipped(start_time, min(start_time + duration, demo.duration))

    demo = (
        demo
        .with_duration(min(duration, demo.duration))
        .resized((1920, 1080))
        .without_audio()
        .with_audio(narration)
        .with_effects([FadeIn(FADE), FadeOut(FADE)])
    )
    return demo, duration

def build():
    clips = []

    # Cena 01 - Hook (card)
    c, d = make_image_scene("01-titulo.png", "cena01-hook.mp3")
    clips.append(c)
    print(f"  01 Hook (card) -> {d:.1f}s")

    # Cena 02 - Dor (card)
    c, d = make_image_scene("02-hook.png", "cena02-dor.mp3")
    clips.append(c)
    print(f"  02 Dor (card) -> {d:.1f}s")

    # Cena 03 - Reveal (card)
    c, d = make_image_scene("01-titulo.png", "cena03-reveal.mp3")
    clips.append(c)
    print(f"  03 Reveal (card) -> {d:.1f}s")

    # Cena 04 - Demo ao vivo (SCREEN RECORDING real!)
    c, d = make_demo_scene("cena04-demo.mp3", start_time=0, end_time=16)
    clips.append(c)
    print(f"  04 Demo ao vivo (SCREEN RECORDING) -> {d:.1f}s")

    # Cena 05 - Gold Snapshot (SCREEN RECORDING continuacao)
    c, d = make_demo_scene("cena05-snapshot.mp3", start_time=16, end_time=28)
    clips.append(c)
    print(f"  05 Gold Snapshot (SCREEN RECORDING) -> {d:.1f}s")

    # Cena 06 - Market Context (card)
    c, d = make_image_scene("04-tool2-market-context.png", "cena06-context.mp3")
    clips.append(c)
    print(f"  06 Market Context (card) -> {d:.1f}s")

    # Cena 07 - Technical Analysis (card)
    c, d = make_image_scene("05-tool3-technical-analysis.png", "cena07-ta.mp3")
    clips.append(c)
    print(f"  07 Technical Analysis (card) -> {d:.1f}s")

    # Cena 08 - Multi-Timeframe (card)
    c, d = make_image_scene("06-tool4-multi-timeframe.png", "cena08-mtf.mp3")
    clips.append(c)
    print(f"  08 Multi-Timeframe (card) -> {d:.1f}s")

    # Cena 09 - Entry Filters (card)
    c, d = make_image_scene("07-tool5-entry-filters.png", "cena09-filters.mp3")
    clips.append(c)
    print(f"  09 Entry Filters (card) -> {d:.1f}s")

    # Cena 10 - Instalacao (card)
    c, d = make_image_scene("08-preco-cta.png", "cena10-install.mp3")
    clips.append(c)
    print(f"  10 Instalacao (card) -> {d:.1f}s")

    # Cena 11 - Credibilidade (card)
    c, d = make_image_scene("11-credibilidade.png", "cena11-quem.mp3")
    clips.append(c)
    print(f"  11 Credibilidade (card) -> {d:.1f}s")

    # Cena 12 - CTA (card)
    c, d = make_image_scene("08-preco-cta.png", "cena12-cta.mp3")
    clips.append(c)
    print(f"  12 CTA (card) -> {d:.1f}s")

    # Cena 13 - Encerramento (card)
    c, d = make_image_scene("10-encerramento.png", "cena13-fim.mp3")
    clips.append(c)
    print(f"  13 Encerramento (card) -> {d:.1f}s")

    print("\nConcatenando clips...")
    final = concatenate_videoclips(clips, method="compose")
    total = final.duration
    print(f"Duracao total: {int(total//60)}:{int(total%60):02d}")
    print(f"Exportando para: {OUTPUT}")

    final.write_videofile(
        OUTPUT,
        fps=FPS,
        codec="libx264",
        audio_codec="aac",
        audio_bitrate="192k",
        preset="medium",
        threads=4,
    )
    print("\nVIDEO v2 PRONTO!")

if __name__ == "__main__":
    build()
