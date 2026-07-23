from datetime import UTC, datetime, timedelta

from app.services.premium import apply_seller_premium_expiry, is_premium_active


def test_is_premium_active_respects_expiry():
    now = datetime(2026, 7, 21, tzinfo=UTC)
    assert is_premium_active(is_premium=True, premium_until=None, now=now) is True
    assert (
        is_premium_active(
            is_premium=True,
            premium_until=now + timedelta(days=1),
            now=now,
        )
        is True
    )
    assert (
        is_premium_active(
            is_premium=True,
            premium_until=now - timedelta(seconds=1),
            now=now,
        )
        is False
    )
    assert is_premium_active(is_premium=False, premium_until=now + timedelta(days=1), now=now) is False


class _Owner:
    def __init__(self, *, is_premium: bool, premium_until):
        self.is_premium = is_premium
        self.premium_until = premium_until


class _Seller:
    def __init__(self, *, is_premium: bool, user=None):
        self.is_premium = is_premium
        self.user = user


def test_apply_seller_premium_expiry_clears_stale_flags():
    owner = _Owner(is_premium=True, premium_until=datetime.now(UTC) - timedelta(days=1))
    seller = _Seller(is_premium=True, user=owner)
    assert apply_seller_premium_expiry(seller, persist=True) is False
    assert seller.is_premium is False
    assert owner.is_premium is False
