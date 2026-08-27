"""
Build MCP TradingView Gold sales video v4.
- Faster narration (rate +15%, pitch +2Hz)
- Shorter padding between scenes (0.5s instead of 1.0s)
- Tighter fade transitions (0.3s)
- All 3 screen recordings + caricature in cards
"""
from moviepy import (
    ImageClip, AudioFileClip, VideoFileClip, concatenate_videoclips,
)
from moviepy.video.fx import FadeIn, FadeOut
import os

BASE = os.path.dirname(__file__)
PNG_DIR = os.path.join(BASE, "png")
AUDIO_DIR = os.path.join(BASE, "audio")
OUTPUT = os.path.join(BASE, "MCP-TradingView-Gold-VIDEO-v4.mp4")

DEMO_GOLD = os.path.join(BASE, "demo-gold-snapshot.mp4")
DEMO_FILTERS = os.path.join(BASE, "demo-entry-filters.mp4")
DEMO_INSTALL = os.path.join(BASE, "demo-instalacao.mp4")

FADE = 0.3
PAD = 0.5
FPS = 30


def make_image_scene(png_name, audio_name):
    png_path = os.path.join(PNG_DIR, png_name)
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    audio = AudioFileClip(audio_path)
    duration = audio.duration + PAD
    clip = (
        ImageClip(png_path)
        .with_duration(duration)
        .resized((1920, 1080))
        .with_audio(audio)
        .with_effects([FadeIn(FADE), FadeOut(FADE)])
    )
    return clip, duration


def make_demo_scene(demo_file, audio_name, start_time=0, end_time=None):
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    narration = AudioFileClip(audio_path)
    duration = narration.duration + PAD

    demo = VideoFileClip(demo_file)
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

    scenes = [
        ("01 Hook", lambda: make_image_scene("01-titulo.png", "cena01-hook.mp3")),
        ("02 Dor", lambda: make_image_scene("02-hook.png", "cena02-dor.mp3")),
        ("03 Reveal", lambda: make_image_scene("01-titulo.png", "cena03-reveal.mp3")),
        ("04 Demo (REC)", lambda: make_demo_scene(DEMO_GOLD, "cena04-demo.mp3", 0, 14)),
        ("05 Snapshot (REC)", lambda: make_demo_scene(DEMO_GOLD, "cena05-snapshot.mp3", 14, 26)),
        ("06 Context", lambda: make_image_scene("04-tool2-market-context.png", "cena06-context.mp3")),
        ("07 TA", lambda: make_image_scene("05-tool3-technical-analysis.png", "cena07-ta.mp3")),
        ("08 MTF", lambda: make_image_scene("06-tool4-multi-timeframe.png", "cena08-mtf.mp3")),
        ("09 Filters (REC)", lambda: make_demo_scene(DEMO_FILTERS, "cena09-filters.mp3", 0)),
        ("10 Install (REC)", lambda: make_demo_scene(DEMO_INSTALL, "cena10-install.mp3", 0)),
        ("11 Cred", lambda: make_image_scene("11-credibilidade.png", "cena11-quem.mp3")),
        ("12 CTA", lambda: make_image_scene("08-preco-cta.png", "cena12-cta.mp3")),
        ("13 Fim", lambda: make_image_scene("10-encerramento.png", "cena13-fim.mp3")),
    ]

    for name, builder in scenes:
        c, d = builder()
        clips.append(c)
        print(f"  {name} -> {d:.1f}s")

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
    print(f"\nVIDEO v4 PRONTO! (dinamico, rate +15%)")


if __name__ == "__main__":
    build()
