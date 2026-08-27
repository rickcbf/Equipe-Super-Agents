"""
Build MCP TradingView Gold REELS v2 (1080x1920, vertical).
- Fast narration (rate +15%)
- Screen recordings cropped to vertical
- CTA overlay "COMPRE AGORA - link na bio" on last scenes
- ~60s max for Instagram Reels
"""
from moviepy import (
    ImageClip, AudioFileClip, VideoFileClip, TextClip,
    CompositeVideoClip, concatenate_videoclips,
)
from moviepy.video.fx import FadeIn, FadeOut, Crop
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(__file__)
PNG_DIR = os.path.join(BASE, "png")
AUDIO_DIR = os.path.join(BASE, "audio")
OUTPUT = os.path.join(BASE, "MCP-TradingView-Gold-REELS-v2.mp4")

DEMO_GOLD = os.path.join(BASE, "demo-gold-snapshot.mp4")
DEMO_FILTERS = os.path.join(BASE, "demo-entry-filters.mp4")

FADE = 0.3
PAD = 0.3
FPS = 30
W, H = 1080, 1920


def make_cta_overlay(duration):
    """Create a 'COMPRE AGORA' button overlay at the bottom."""
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    btn_w, btn_h = 600, 80
    btn_x = (W - btn_w) // 2
    btn_y = H - 200

    draw.rounded_rectangle(
        [btn_x, btn_y, btn_x + btn_w, btn_y + btn_h],
        radius=12,
        fill=(200, 164, 78, 240),
    )

    try:
        font = ImageFont.truetype("arial.ttf", 32)
    except:
        font = ImageFont.load_default()

    text = "COMPRE AGORA - R$ 49"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = btn_x + (btn_w - tw) // 2
    ty = btn_y + (btn_h - th) // 2 - 2
    draw.text((tx, ty), text, fill=(10, 10, 10, 255), font=font)

    link_text = "Link na bio"
    bbox2 = draw.textbbox((0, 0), link_text, font=font)
    lw = bbox2[2] - bbox2[0]
    lx = (W - lw) // 2
    draw.text((lx, btn_y + btn_h + 16), link_text, fill=(200, 200, 200, 200), font=font)

    arr = np.array(img)
    overlay = ImageClip(arr).with_duration(duration)
    return overlay


def make_image_scene(png_name, audio_name, with_cta=False):
    png_path = os.path.join(PNG_DIR, png_name)
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    audio = AudioFileClip(audio_path)
    duration = audio.duration + PAD

    clip = (
        ImageClip(png_path)
        .with_duration(duration)
        .resized((W, H))
        .with_effects([FadeIn(FADE), FadeOut(FADE)])
    )

    if with_cta:
        cta = make_cta_overlay(duration)
        clip = CompositeVideoClip([clip, cta]).with_duration(duration)

    clip = clip.with_audio(audio)
    return clip, duration


def make_demo_vertical(demo_file, audio_name, start_time=0, end_time=None, with_cta=False):
    """Crop horizontal screen recording to vertical center."""
    audio_path = os.path.join(AUDIO_DIR, audio_name)
    narration = AudioFileClip(audio_path)
    duration = narration.duration + PAD

    demo = VideoFileClip(demo_file)
    if end_time:
        demo = demo.subclipped(start_time, min(end_time, demo.duration))
    else:
        demo = demo.subclipped(start_time, min(start_time + duration, demo.duration))

    dw, dh = demo.size
    target_ratio = 9 / 16
    crop_w = int(dh * target_ratio)
    crop_x = (dw - crop_w) // 2

    demo = (
        demo
        .with_effects([Crop(x1=crop_x, x2=crop_x + crop_w)])
        .with_duration(min(duration, demo.duration))
        .resized((W, H))
        .without_audio()
        .with_effects([FadeIn(FADE), FadeOut(FADE)])
    )

    if with_cta:
        cta = make_cta_overlay(min(duration, demo.duration))
        demo = CompositeVideoClip([demo, cta]).with_duration(min(duration, demo.duration))

    demo = demo.with_audio(narration)
    return demo, duration


def build():
    clips = []

    # Cena 1 - Hook (vertical card)
    c, d = make_image_scene("12-hook-vertical.png", "cena01-hook.mp3")
    clips.append(c)
    print(f"  01 Hook -> {d:.1f}s")

    # Cena 2 - Reveal (vertical card)
    c, d = make_image_scene("13-titulo-vertical.png", "cena03-reveal.mp3")
    clips.append(c)
    print(f"  02 Reveal -> {d:.1f}s")

    # Cena 3 - Demo gold snapshot (screen recording vertical crop)
    c, d = make_demo_vertical(DEMO_GOLD, "cena04-demo.mp3", 0, 14)
    clips.append(c)
    print(f"  03 Demo gold (REC vertical) -> {d:.1f}s")

    # Cena 4 - Entry Filters (screen recording vertical crop)
    c, d = make_demo_vertical(DEMO_FILTERS, "cena09-filters.mp3", 0, with_cta=False)
    clips.append(c)
    print(f"  04 Entry Filters (REC vertical) -> {d:.1f}s")

    # Cena 5 - CTA/Preco (vertical card + botao COMPRE AGORA)
    c, d = make_image_scene("14-preco-vertical.png", "cena12-cta.mp3", with_cta=True)
    clips.append(c)
    print(f"  05 CTA + COMPRE AGORA -> {d:.1f}s")

    # Cena 6 - Encerramento
    c, d = make_image_scene("10-encerramento.png", "cena13-fim.mp3", with_cta=True)
    clips.append(c)
    print(f"  06 Encerramento -> {d:.1f}s")

    print("\nConcatenando clips...")
    final = concatenate_videoclips(clips, method="compose")
    total = final.duration
    print(f"Duracao total: {int(total//60)}:{int(total%60):02d}")

    if total > 90:
        print(f"AVISO: Video com {total:.0f}s - considere cortar cenas para < 90s")

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
    print(f"\nREELS v2 PRONTO! ({total:.0f}s)")
    print(f"Hotmart: https://pay.hotmart.com/M106450067D")
    print(f"Coloque o link na bio do Instagram!")


if __name__ == "__main__":
    build()
