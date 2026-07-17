"""Seed categories and demo data for local development."""

import asyncio
import uuid

from sqlalchemy import select

from app.database import SessionLocal, engine
from app.models import AccountType, Base, Category, SellerProfile, User, WarningZone

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


async def seed() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as session:
        existing = await session.execute(select(Category).limit(1))
        if existing.scalar_one_or_none() is None:
            for slug, en, fr, ar, icon in CATEGORIES:
                session.add(Category(slug=slug, name_en=en, name_fr=fr, name_ar=ar, icon=icon))

        buyer = await session.execute(select(User).where(User.email == "buyer@demo.local"))
        if buyer.scalar_one_or_none() is None:
            session.add(
                User(
                    firebase_uid="demo-buyer-uid",
                    email="buyer@demo.local",
                    account_type=AccountType.BUYER,
                    display_name="Demo Buyer",
                )
            )

        seller_user_result = await session.execute(
            select(User).where(User.email == "seller@demo.local")
        )
        seller_user = seller_user_result.scalar_one_or_none()
        if seller_user is None:
            seller_user = User(
                firebase_uid="demo-seller-uid",
                email="seller@demo.local",
                account_type=AccountType.SELLER,
                display_name="Demo Seller",
            )
            session.add(seller_user)
            await session.flush()

        seller_profile = await session.execute(
            select(SellerProfile).where(SellerProfile.business_name == "Hana Chicken")
        )
        if seller_profile.scalar_one_or_none() is None:
            food_cat = await session.execute(select(Category).where(Category.slug == "food"))
            food = food_cat.scalar_one()
            session.add(
                SellerProfile(
                    user_id=seller_user.id,
                    business_name="Hana Chicken",
                    description="Crispy fried chicken and local favorites in the heart of Casablanca.",
                    address="Boulevard Zerktouni, Casablanca",
                    city="Casablanca",
                    latitude=33.5899,
                    longitude=-7.6039,
                    phone="+212 522 000 000",
                    cover_image_url="",
                    categories=[food],
                )
            )

        warning = await session.execute(select(WarningZone).limit(1))
        if warning.scalar_one_or_none() is None:
            session.add(
                WarningZone(
                    name="High-risk market area",
                    description="Buyers reported scam attempts in this zone. Stay alert.",
                    city="Casablanca",
                    latitude=33.5731,
                    longitude=-7.5898,
                    radius_meters=250,
                )
            )

        await session.commit()
        print("Seed data ready.")


if __name__ == "__main__":
    asyncio.run(seed())
