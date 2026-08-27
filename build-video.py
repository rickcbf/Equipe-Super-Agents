"""
Build the MCP TradingView Gold sales video.
Combines PNG cards + MP3 narration into a single MP4.
"""
from moviepy import (
    ImageClip, AudioFileClip, concatenate_videoclips,
)
from moviepy.video.fx import FadeIn, FadeOut
import os

BASE = os.path.dirname(__file__)
PNG_DIR = os.path.join(BASE, "png")
AUDIO_DIR = os.path.join(BASE, "audio")
OUTPUT = os.path.join(BASE, "MCP-TradingView-Gold-VIDEO.mp4")

SCENES = [
    ("01-titulo.png",              "cena01-hook.mp3"),
    ("02-hook.png",                "cena02-dor.mp3"),
    ("01-titulo.png",              "cena03-reveal.mp3"),
    ("01-titulo.png",              "cena04-demo.mp3"),
    ("03-tool1-gold-snapshot.png", "cena05-snapshot.mp3"),
    ("04-tool2-market-context.png","cena06-context.mp3"),
    ("05-tool3-technical-analysis.png", "cena07-ta.mp3"),
    ("06-tool4-multi-timeframe.png",    "cena08-mtf.mp3"),
    ("07-tool5-entry-filters.png",      "cena09-filters.mp3"),
    ("08-preco-cta.png",          "cena10-install.mp3"),
    ("11-credibilidade.png",      "cena11-quem.mp3"),
    ("08-preco-cta.png",          "cena12-cta.mp3"),
    ("10-encerramento.png",       "cena13-fim.mp3"),
]

FADE = 0.5
FPS = 30

def build():
    clips = []
    for png_name, audio_name in SCENES:
        png_path = os.path.join(PNG_DIR, png_name)
        audio_path = os.path.join(AUDIO_DIR, audio_name)

        audio = AudioFileClip(audio_path)
        duration = audio.duration + 1.0

        img = (
            ImageClip(png_path)
            .with_duration(duration)
            .resized((1920, 1080))
            .with_audio(audio)
            .with_effects([FadeIn(FADE), FadeOut(FADE)])
        )
        clips.append(img)
        print(f"  {png_name} + {audio_name} -> {duration:.1f}s")

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
    print("\nVIDEO PRONTO!")

if __name__ == "__main__":
    build()
