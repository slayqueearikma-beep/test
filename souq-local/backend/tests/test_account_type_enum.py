"""Ensure AccountType persists lowercase enum values."""

from app.models import AccountType, account_type_enum


def test_account_type_values_for_postgres():
    values = account_type_enum.enums
    assert values == ["buyer", "seller"]
    assert AccountType.BUYER.value == "buyer"
    assert AccountType.SELLER.value == "seller"
