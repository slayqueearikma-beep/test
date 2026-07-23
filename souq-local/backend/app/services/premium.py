"""Premium membership helpers — keep public flags consistent with expiry."""

from __future__ import annotations

from datetime import UTC, datetime

from app.models import SellerProfile, User


def is_premium_active(
    *,
    is_premium: bool,
    premium_until: datetime | None,
    now: datetime | None = None,
) -> bool:
    if not is_premium:
        return False
    if premium_until is None:
        return True
    clock = now or datetime.now(UTC)
    if premium_until.tzinfo is None:
        premium_until = premium_until.replace(tzinfo=UTC)
    return premium_until >= clock


def apply_seller_premium_expiry(seller: SellerProfile, *, persist: bool = False) -> bool:
    """Return effective premium and optionally clear stale ORM flags in-session."""
    owner: User | None = getattr(seller, "user", None)
    now = datetime.now(UTC)
    if owner is not None:
        active = is_premium_active(
            is_premium=bool(owner.is_premium or seller.is_premium),
            premium_until=owner.premium_until,
            now=now,
        )
        if persist and not active and (seller.is_premium or owner.is_premium):
            seller.is_premium = False
            owner.is_premium = False
        else:
            # Align response/sort flag with effective membership without forcing DB writes
            # when membership is still active.
            seller.is_premium = active
        return active

    # Without the owner row loaded, trust the denormalized flag.
    return bool(seller.is_premium)
