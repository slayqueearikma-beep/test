"""Casablanca-only launch city enforcement."""

import pytest
from pydantic import ValidationError

from app.schemas import SellerCreate


def test_seller_create_rejects_non_casablanca_city():
    with pytest.raises(ValidationError, match="Casablanca"):
        SellerCreate(
            business_name="Shop",
            address="12 Rue Example",
            city="Rabat",
            latitude=34.0,
            longitude=-6.8,
            phone="+212600000099",
        )


def test_seller_create_accepts_casablanca():
    payload = SellerCreate(
        business_name="Shop",
        address="12 Rue Example",
        city="casablanca",
        latitude=33.57,
        longitude=-7.58,
        phone="+212600000099",
    )
    assert payload.city == "Casablanca"
