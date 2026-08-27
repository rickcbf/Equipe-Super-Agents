"""
Build the MCP TradingView Gold REELS version (60s, 1080x1920).
Condensed version for Instagram Reels / YouTube Shorts.
"""
from moviepy import ImageClip, AudioFileClip, concatenate_videoclips
from moviepy.video.fx import FadeIn, FadeOut
import os

BASE = os.path.dirname(__file__)
PNG_DIR = os.path.join(BASE, "png")
AUDIO_DIR = os.path.join(BASE, "audio")
OUTPUT = os.path.join(BASE, "MCP-TradingView-Gold-REELS.mp4")

SCENES = [
    ("12-hook-vertical.png",    "cena01-hook.mp3"),
    ("13-titulo-vertical.png",  "cena03-reveal.mp3"),
    ("03-tool1-gold-snapshot.png", "cena05-snapshot.mp3"),
    ("07-tool5-entry-filters.png", "cena09-filters.mp3"),
    ("14-preco-vertical.png",   "cena12-cta.mp3"),
    ("10-encerramento.png",     "cena13-fim.mp3"),
]

FADE = 0.4
FPS = 30

def build():
    clips = []
    for png_name, audio_name in SCENES:
        png_path = os.path.join(PNG_DIR, png_name)
        audio_path = os.path.join(AUDIO_DIR, audio_name)

        audio = AudioFileClip(audio_path)
        duration = audio.duration + 0.5

        img = (
            ImageClip(png_path)
            .with_duration(duration)
            .resized((1080, 1920))
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
    print("\nREELS PRONTO!")

if __name__ == "__main__":
    build()
