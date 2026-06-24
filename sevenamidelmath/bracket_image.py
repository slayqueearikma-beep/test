from __future__ import annotations

from io import BytesIO
from math import ceil
from textwrap import wrap
from typing import Any

from PIL import Image, ImageDraw, ImageFont


CANVAS_WIDTH = 1400
BACKGROUND = "#111827"
PANEL = "#1f2937"
PANEL_ALT = "#273449"
TEXT = "#f9fafb"
MUTED = "#cbd5e1"
ACCENT = "#f59e0b"
ACCENT_BLUE = "#38bdf8"
SUCCESS = "#22c55e"
LINE = "#475569"


def render_bracket_png(tournament: dict[str, Any], bracket: dict[str, Any]) -> BytesIO:
    if bracket["mode"] == "1v1":
        image = _render_one_vs_one(tournament, bracket)
    elif bracket["mode"] == "5v5":
        image = _render_five_vs_five(tournament, bracket)
    else:
        raise ValueError(f"Unsupported bracket mode: {bracket['mode']}")

    output = BytesIO()
    image.save(output, format="PNG", optimize=True)
    output.seek(0)
    return output


def bracket_image_filename(tournament: dict[str, Any]) -> str:
    return f"7amidelmath-bracket-{tournament['id']}.png"


def _render_one_vs_one(tournament: dict[str, Any], bracket: dict[str, Any]) -> Image.Image:
    matches = bracket["rounds"][0]["matches"]
    byes = bracket["rounds"][0]["byes"]
    card_width = 610
    card_height = 150
    gap = 28
    columns = 2
    rows = max(1, ceil(len(matches) / columns))
    bye_height = 90 if byes else 0
    height = 250 + rows * (card_height + gap) + bye_height + 70
    image, draw = _base_image(height)
    fonts = _fonts()

    _draw_header(draw, tournament, "Random 1 vs 1 Bracket", fonts)
    for index, match in enumerate(matches):
        row = index // columns
        column = index % columns
        x = 70 + column * (card_width + gap)
        y = 205 + row * (card_height + gap)
        _match_card(
            draw,
            x,
            y,
            card_width,
            card_height,
            f"Match {match['match_number']}",
            _display_name(match["player_a"]),
            _display_name(match["player_b"]),
            fonts,
        )

    if byes:
        y = 220 + rows * (card_height + gap)
        _bye_card(draw, 70, y, CANVAS_WIDTH - 140, byes, fonts)

    return image


def _render_five_vs_five(tournament: dict[str, Any], bracket: dict[str, Any]) -> Image.Image:
    teams = bracket["teams"]
    matches = bracket["rounds"][0]["matches"]
    byes = bracket["rounds"][0]["byes"]
    reserves = bracket["reserves"]

    team_card_width = 610
    team_card_height = 210
    match_card_width = 610
    match_card_height = 135
    gap = 28
    columns = 2
    team_rows = max(1, ceil(len(teams) / columns))
    match_rows = max(1, ceil((len(matches) + len(byes)) / columns))
    reserve_height = 110 if reserves else 0
    height = (
        315
        + team_rows * (team_card_height + gap)
        + 95
        + match_rows * (match_card_height + gap)
        + reserve_height
        + 70
    )
    image, draw = _base_image(height)
    fonts = _fonts()

    _draw_header(draw, tournament, "Random 5 vs 5 Team Bracket", fonts)
    draw.text((70, 205), "Generated teams", fill=TEXT, font=fonts["section"])

    for index, team in enumerate(teams):
        row = index // columns
        column = index % columns
        x = 70 + column * (team_card_width + gap)
        y = 255 + row * (team_card_height + gap)
        _team_card(draw, x, y, team_card_width, team_card_height, team, fonts)

    matches_y = 270 + team_rows * (team_card_height + gap)
    draw.text((70, matches_y), "Round 1 matchups", fill=TEXT, font=fonts["section"])
    match_items = [("match", match) for match in matches] + [("bye", team) for team in byes]
    for index, (item_type, item) in enumerate(match_items):
        row = index // columns
        column = index % columns
        x = 70 + column * (match_card_width + gap)
        y = matches_y + 50 + row * (match_card_height + gap)
        if item_type == "match":
            _match_card(
                draw,
                x,
                y,
                match_card_width,
                match_card_height,
                f"Match {item['match_number']}",
                item["team_a"]["name"],
                item["team_b"]["name"],
                fonts,
            )
        else:
            _team_bye_card(draw, x, y, match_card_width, match_card_height, item, fonts)

    if reserves:
        y = matches_y + 65 + match_rows * (match_card_height + gap)
        _reserves_card(draw, 70, y, CANVAS_WIDTH - 140, reserves, fonts)

    return image


def _base_image(height: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (CANVAS_WIDTH, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        blend = y / max(height, 1)
        red = int(17 + 12 * blend)
        green = int(24 + 18 * blend)
        blue = int(39 + 28 * blend)
        draw.line([(0, y), (CANVAS_WIDTH, y)], fill=(red, green, blue))
    return image, draw


def _fonts() -> dict[str, ImageFont.ImageFont]:
    return {
        "title": _font(48),
        "subtitle": _font(26),
        "section": _font(32),
        "card_title": _font(25),
        "player": _font(29),
        "body": _font(22),
        "small": _font(18),
    }


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def _draw_header(
    draw: ImageDraw.ImageDraw,
    tournament: dict[str, Any],
    subtitle: str,
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    draw.rounded_rectangle((50, 45, CANVAS_WIDTH - 50, 165), radius=28, fill=PANEL)
    draw.rectangle((50, 45, 65, 165), fill=ACCENT)
    draw.text((90, 65), "7amidelmath", fill=ACCENT, font=fonts["subtitle"])
    draw.text((90, 96), _fit_text(str(tournament["name"]), 42), fill=TEXT, font=fonts["title"])
    draw.text((980, 72), subtitle, fill=MUTED, font=fonts["subtitle"])
    draw.text((980, 111), f"Tournament #{tournament['id']}", fill=ACCENT_BLUE, font=fonts["body"])


def _match_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    height: int,
    title: str,
    side_a: str,
    side_b: str,
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    draw.rounded_rectangle((x, y, x + width, y + height), radius=22, fill=PANEL, outline=LINE, width=2)
    draw.text((x + 24, y + 20), title.upper(), fill=ACCENT, font=fonts["card_title"])
    center_y = y + height // 2 + 18
    draw.line((x + 24, center_y, x + width - 24, center_y), fill=LINE, width=2)
    draw.text((x + 24, y + 65), _fit_text(side_a, 28), fill=TEXT, font=fonts["player"])
    draw.text((x + 24, center_y + 18), _fit_text(side_b, 28), fill=TEXT, font=fonts["player"])
    draw.text((x + width - 96, y + 69), "VS", fill=ACCENT_BLUE, font=fonts["card_title"])


def _team_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    height: int,
    team: dict[str, Any],
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    draw.rounded_rectangle((x, y, x + width, y + height), radius=22, fill=PANEL, outline=LINE, width=2)
    draw.text((x + 24, y + 18), team["name"].upper(), fill=ACCENT, font=fonts["card_title"])
    for index, player in enumerate(team["players"], start=1):
        draw.text(
            (x + 36, y + 48 + index * 26),
            f"{index}. {_fit_text(_display_name(player), 35)}",
            fill=TEXT,
            font=fonts["body"],
        )


def _bye_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    players: list[dict[str, Any]],
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    names = ", ".join(_display_name(player) for player in players)
    draw.rounded_rectangle((x, y, x + width, y + 86), radius=22, fill=PANEL_ALT, outline=SUCCESS, width=2)
    draw.text((x + 24, y + 18), "BYE", fill=SUCCESS, font=fonts["card_title"])
    draw.text((x + 115, y + 21), _fit_text(f"{names} advances automatically", 70), fill=TEXT, font=fonts["player"])


def _team_bye_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    height: int,
    team: dict[str, Any],
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    draw.rounded_rectangle((x, y, x + width, y + height), radius=22, fill=PANEL_ALT, outline=SUCCESS, width=2)
    draw.text((x + 24, y + 22), "BYE", fill=SUCCESS, font=fonts["card_title"])
    draw.text((x + 24, y + 68), f"{team['name']} advances automatically", fill=TEXT, font=fonts["player"])


def _reserves_card(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    reserves: list[dict[str, Any]],
    fonts: dict[str, ImageFont.ImageFont],
) -> None:
    draw.rounded_rectangle((x, y, x + width, y + 104), radius=22, fill=PANEL_ALT, outline=ACCENT_BLUE, width=2)
    draw.text((x + 24, y + 18), "RESERVES", fill=ACCENT_BLUE, font=fonts["card_title"])
    names = ", ".join(_display_name(player) for player in reserves)
    lines = wrap(names, width=92)[:2]
    for index, line in enumerate(lines):
        draw.text((x + 160, y + 18 + index * 30), line, fill=TEXT, font=fonts["body"])


def _display_name(participant: dict[str, Any]) -> str:
    name = str(participant.get("display_name") or participant.get("name") or participant["user_id"])
    return name.replace("\n", " ").strip()


def _fit_text(value: str, max_chars: int) -> str:
    if len(value) <= max_chars:
        return value
    return value[: max_chars - 3].rstrip() + "..."
