"""Unit tests for ALLOWED_HOSTS parsing / normalization."""

from app.config import Settings, _normalize_host


def test_normalize_host_strips_port_and_scheme():
    assert _normalize_host("192.168.11.103:8000") == "192.168.11.103"
    assert _normalize_host("http://192.168.11.103:8000") == "192.168.11.103"


def test_allowed_hosts_csv_and_json():
    csv_settings = Settings(
        _env_file=None,
        app_env="development",
        allowed_hosts="localhost,192.168.11.103,192.168.11.103:8000",
    )
    assert "192.168.11.103" in csv_settings.allowed_hosts
    assert "192.168.11.103:8000" not in csv_settings.allowed_hosts
    assert "127.0.0.1" in csv_settings.allowed_hosts

    mangled = Settings(
        _env_file=None,
        app_env="development",
        allowed_hosts="[localhost,192.168.11.103]",
    )
    assert "192.168.11.103" in mangled.allowed_hosts
