from uuid import uuid4

import pytest

from app.services.upload_security import sanitize_upload_filename, validate_media_url, validate_upload_content_type


def test_sanitize_filename():
    assert sanitize_upload_filename("../evil.jpg") == "evil.jpg"
    assert sanitize_upload_filename("photo name.png").startswith("photo")


def test_content_type():
    validate_upload_content_type("image/jpeg")
    with pytest.raises(ValueError):
        validate_upload_content_type("application/pdf")


def test_media_url_owner_prefix():
    user_id = uuid4()
    url = f"https://acct.blob.core.windows.net/margem-media/{user_id}/file.jpg?sv=1"
    assert validate_media_url(url, owner_user_id=user_id, container="margem-media").startswith("https://")
    with pytest.raises(ValueError):
        validate_media_url(url, owner_user_id=uuid4(), container="margem-media")
    assert validate_media_url("", owner_user_id=user_id, container="margem-media") == ""
    with pytest.raises(ValueError):
        validate_media_url("http://evil.com/x.jpg", owner_user_id=user_id, container="margem-media")
