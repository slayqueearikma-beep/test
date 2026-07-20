"""Seed category taxonomy (reference data only)

Revision ID: 002
Revises: 001
Create Date: 2026-07-18
"""

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

CATEGORIES = [
    ("food", "Food", "Nourriture", "طعام", "restaurant"),
    ("clothing", "Clothing", "Vêtements", "ملابس", "checkroom"),
    ("electronics", "Electronics", "Électronique", "إلكترونيات", "devices"),
    ("beauty", "Beauty", "Beauté", "جمال", "spa"),
    ("services", "Services", "Services", "خدمات", "build"),
    ("home", "Home & Garden", "Maison", "منزل", "home"),
    ("health", "Health", "Santé", "صحة", "local_hospital"),
    ("sports", "Sports", "Sport", "رياضة", "sports_soccer"),
]


def upgrade() -> None:
    categories = sa.table(
        "categories",
        sa.column("id", sa.Uuid),
        sa.column("slug", sa.String),
        sa.column("name_en", sa.String),
        sa.column("name_fr", sa.String),
        sa.column("name_ar", sa.String),
        sa.column("icon", sa.String),
    )
    op.bulk_insert(
        categories,
        [
            {
                "id": uuid4(),
                "slug": slug,
                "name_en": en,
                "name_fr": fr,
                "name_ar": ar,
                "icon": icon,
            }
            for slug, en, fr, ar, icon in CATEGORIES
        ],
    )


def downgrade() -> None:
    bind = op.get_bind()
    for slug, *_ in CATEGORIES:
        bind.execute(sa.text("DELETE FROM categories WHERE slug = :slug"), {"slug": slug})
