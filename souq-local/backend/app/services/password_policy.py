import re

_PASSWORD_RULES = (
    (r".{8,128}", "Password must be 8–128 characters"),
    (r"[A-Z]", "Password must include an uppercase letter"),
    (r"[a-z]", "Password must include a lowercase letter"),
    (r"\d", "Password must include a number"),
)


def validate_password_strength(password: str) -> None:
    for pattern, message in _PASSWORD_RULES:
        if not re.search(pattern, password):
            raise ValueError(message)
