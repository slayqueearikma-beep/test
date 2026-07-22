from azure.core.credentials import AzureNamedKeyCredential

from app.services.azure_storage import extract_azure_account_key


class _LegacyCredential:
    account_key = "legacy-account-key"


def test_extract_key_from_named_key_credential():
    cred = AzureNamedKeyCredential("margemqc13", "secret-key-value==")
    assert extract_azure_account_key(cred) == "secret-key-value=="


def test_extract_key_from_legacy_account_key_attr():
    assert extract_azure_account_key(_LegacyCredential()) == "legacy-account-key"


def test_extract_key_missing_raises():
    try:
        extract_azure_account_key(object())
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "Unable to read" in str(exc)
