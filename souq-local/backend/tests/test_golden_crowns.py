import pytest

from app.services.ratings import compute_achievement_stars, compute_golden_crowns


@pytest.mark.parametrize(
    ("five_stars", "crowns", "stars"),
    [
        (0, 0, 0),
        (99, 0, 0),
        (100, 0, 1),
        (999, 0, 9),
        (1000, 1, 0),
        (1099, 1, 0),
        (1100, 1, 1),
        (2500, 2, 5),
    ],
)
def test_thousand_five_stars_become_golden_crown(five_stars: int, crowns: int, stars: int):
    assert compute_golden_crowns(five_stars) == crowns
    assert compute_achievement_stars(five_stars) == stars
