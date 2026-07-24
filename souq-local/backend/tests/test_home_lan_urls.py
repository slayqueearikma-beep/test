from app.config import _is_loopback_or_private_url


def test_private_lan_http_urls_are_allowed():
    assert _is_loopback_or_private_url("http://localhost:8000")
    assert _is_loopback_or_private_url("http://127.0.0.1:8000")
    assert _is_loopback_or_private_url("http://192.168.11.107:8000")
    assert _is_loopback_or_private_url("http://10.0.0.5:8000")
    assert not _is_loopback_or_private_url("http://margem.ma")
    assert not _is_loopback_or_private_url("http://8.8.8.8")
