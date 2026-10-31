#!/usr/bin/env python3
"""Regenerate Noctalia palettes and previews from pinned Omarchy colors."""

import json
import tomllib
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent / "noctalia-v5" / "omarchy-themes"
OMARCHY_REV = "bda3aaf6955404712dbd46541e6c8a75a2b16b7c"
SOLARIZED_REV = "236840f05449f1becfafd1f5995c2c5c9c79ca70"
THEMES = (
    ("catppuccin", "Catppuccin"),
    ("catppuccin-latte", "Catppuccin Latte"),
    ("everforest", "Everforest"),
    ("flexoki-light", "Flexoki Light"),
    ("gruvbox", "Gruvbox"),
    ("kanagawa", "Kanagawa"),
    ("matte-black", "Matte Black"),
    ("nord", "Nord"),
    ("ristretto", "Ristretto"),
    ("rose-pine", "Rose Pine"),
    ("solarized", "Solarized"),
    ("tokyo-night", "Tokyo Night"),
)


def read_toml(url):
    with urllib.request.urlopen(url, timeout=20) as response:
        return tomllib.loads(response.read().decode())


def rgb(color):
    return tuple(int(color[index:index + 2], 16) for index in (1, 3, 5))


def luminance(color):
    channels = [value / 255 for value in rgb(color)]
    channels = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return sum(a * b for a, b in zip(channels, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    light, dark = sorted((luminance(first), luminance(second)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def on_color(color, background, foreground):
    return max((background, foreground), key=lambda candidate: contrast(color, candidate))


def omarchy_colors(slug):
    url = f"https://raw.githubusercontent.com/omacom/omarchy/{OMARCHY_REV}/themes/{slug}/colors.toml"
    return read_toml(url)


def solarized_colors():
    url = f"https://raw.githubusercontent.com/Gazler/omarchy-solarized-theme/{SOLARIZED_REV}/alacritty.toml"
    source = read_toml(url)["colors"]
    normal, bright = source["normal"], source["bright"]
    return {
        "mode": "dark",
        "accent": normal["blue"],
        "selection": normal["black"],
        "muted": bright["green"],
        "background": source["primary"]["background"],
        "dark_background": source["primary"]["background"],
        "darker_background": source["primary"]["background"],
        "lighter_background": normal["black"],
        "foreground": source["primary"]["foreground"],
        "light_foreground": bright["cyan"],
        "bright_foreground": bright["white"],
        **{name: normal[name] for name in ("red", "green", "yellow", "blue", "magenta", "cyan")},
        **{f"bright_{name}": bright[name] for name in ("red", "green", "yellow", "blue", "magenta", "cyan")},
        "terminal_normal": normal,
        "terminal_bright": bright,
    }


def palette(colors):
    background = colors["background"]
    foreground = colors["foreground"]
    normal = colors.get("terminal_normal") or {
        "black": background,
        "red": colors["red"],
        "green": colors["green"],
        "yellow": colors["yellow"],
        "blue": colors["blue"],
        "magenta": colors["magenta"],
        "cyan": colors["cyan"],
        "white": foreground,
    }
    bright = colors.get("terminal_bright") or {
        "black": colors["muted"],
        **{name: colors[f"bright_{name}"] for name in ("red", "green", "yellow", "blue", "magenta", "cyan")},
        "white": colors["bright_foreground"],
    }
    variant = {
        "primary": colors["accent"],
        "on_primary": on_color(colors["accent"], background, foreground),
        "secondary": colors["blue"],
        "on_secondary": on_color(colors["blue"], background, foreground),
        "tertiary": colors["magenta"],
        "on_tertiary": on_color(colors["magenta"], background, foreground),
        "error": colors["red"],
        "on_error": on_color(colors["red"], background, foreground),
        "surface": background,
        "on_surface": foreground,
        "surface_container": colors["lighter_background"],
        "on_surface_variant": colors["light_foreground"],
        "outline_variant": colors["muted"],
        "shadow": colors["darker_background"],
        "hover": colors["selection"],
        "on_hover": foreground,
        "terminal": {
            "background": background,
            "foreground": foreground,
            "cursor": colors["bright_foreground"],
            "cursor_text": background,
            "selection_bg": colors["selection"],
            "selection_fg": on_color(colors["selection"], background, foreground),
            "normal": normal,
            "bright": bright,
        },
    }
    return {"version": 2, "dark": variant, "light": variant}


def preview(path, title, colors):
    background = colors["background"]
    foreground = colors["foreground"]
    surface = colors["lighter_background"]
    accent = colors["accent"]
    image = Image.new("RGB", (640, 360), background)
    draw = ImageDraw.Draw(image)
    font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
    title_font = ImageFont.truetype(font_path, 30)
    body_font = ImageFont.truetype(font_path, 17)
    draw.rounded_rectangle((22, 20, 618, 64), radius=12, fill=surface)
    draw.ellipse((38, 34, 54, 50), fill=colors["red"])
    draw.ellipse((64, 34, 80, 50), fill=colors["yellow"])
    draw.ellipse((90, 34, 106, 50), fill=colors["green"])
    draw.text((128, 30), title, font=body_font, fill=foreground)
    draw.rounded_rectangle((34, 91, 606, 322), radius=18, fill=surface)
    draw.rounded_rectangle((54, 112, 586, 162), radius=10, fill=background)
    draw.text((70, 119), title, font=title_font, fill=accent)
    draw.text((58, 185), "The quick brown fox jumps over the lazy dog", font=body_font, fill=foreground)
    draw.rounded_rectangle((58, 234, 202, 281), radius=11, fill=accent)
    draw.text((78, 247), "Preview", font=body_font, fill=on_color(accent, background, foreground))
    for index, name in enumerate(("red", "yellow", "green", "cyan", "blue", "magenta")):
        x = 236 + index * 55
        draw.rounded_rectangle((x, 239, x + 38, 277), radius=8, fill=colors[name])
    image.save(path, optimize=True)


def main():
    palettes = ROOT / "palettes"
    previews = ROOT / "plugin" / "previews"
    palettes.mkdir(parents=True, exist_ok=True)
    previews.mkdir(parents=True, exist_ok=True)
    for slug, title in THEMES:
        colors = solarized_colors() if slug == "solarized" else omarchy_colors(slug)
        output = palettes / f"omarchy-{slug}.json"
        output.write_text(json.dumps(palette(colors), indent=2) + "\n")
        preview(previews / f"{slug}.png", title, colors)
        print(f"{title}: {colors['mode']}")


if __name__ == "__main__":
    main()
