from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import settings

_kwargs: dict = {
    "key_func": get_remote_address,
    "default_limits": [settings.rate_limit],
}
if settings.redis_url.strip():
    _kwargs["storage_uri"] = settings.redis_url.strip()

limiter = Limiter(**_kwargs)
