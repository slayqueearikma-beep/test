from io import BytesIO

from PIL import Image

from sevenamidelmath.bracket import generate_bracket
from sevenamidelmath.bracket_image import bracket_image_filename, render_bracket_png


def players(count: int) -> list[dict]:
    return [
        {
            "user_id": index,
            "display_name": f"Player {index}",
        }
        for index in range(1, count + 1)
    ]


def tournament(mode: str) -> dict:
    return {
        "id": 42,
        "name": f"Test {mode} Tournament",
        "mode": mode,
    }


def test_renders_one_vs_one_bracket_png() -> None:
    bracket = generate_bracket(mode="1v1", participants=players(5))
    output = render_bracket_png(tournament("1v1"), bracket)

    assert output.getvalue().startswith(b"\x89PNG")
    image = Image.open(BytesIO(output.getvalue()))
    assert image.format == "PNG"
    assert image.width == 1400
    assert image.height > 300


def test_renders_five_vs_five_bracket_png() -> None:
    bracket = generate_bracket(mode="5v5", participants=players(23))
    output = render_bracket_png(tournament("5v5"), bracket)

    assert output.getvalue().startswith(b"\x89PNG")
    image = Image.open(BytesIO(output.getvalue()))
    assert image.format == "PNG"
    assert image.width == 1400
    assert image.height > 700


def test_bracket_image_filename_uses_tournament_id() -> None:
    assert bracket_image_filename(tournament("1v1")) == "7amidelmath-bracket-42.png"
