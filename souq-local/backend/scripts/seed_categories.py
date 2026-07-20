"""Optional: seed marketplace category taxonomy (no users or businesses).

Run manually after migrations if categories table is empty:
  PYTHONPATH=/app python scripts/seed_categories.py
"""

import asyncio

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Category

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


async def seed_categories() -> None:
    async with SessionLocal() as session:
        existing = await session.execute(select(Category).limit(1))
        if existing.scalar_one_or_none() is not None:
            print("Categories already exist — skipping.")
            return

        for slug, en, fr, ar, icon in CATEGORIES:
            session.add(Category(slug=slug, name_en=en, name_fr=fr, name_ar=ar, icon=icon))

        await session.commit()
        print(f"Seeded {len(CATEGORIES)} categories.")


if __name__ == "__main__":
    asyncio.run(seed_categories())
