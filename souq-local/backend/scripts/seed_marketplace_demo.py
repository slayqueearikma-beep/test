"""Idempotent, realistic Casablanca marketplace demo data.

Run only against a non-production database:
  PYTHONPATH=. python scripts/seed_marketplace_demo.py

The seed uses deterministic UUIDs and a fixed random seed, so re-running it
updates the same records instead of creating endless duplicate demo content.
"""

from __future__ import annotations

import asyncio
import random
from datetime import UTC, datetime, timedelta
from uuid import NAMESPACE_URL, UUID, uuid5

from sqlalchemy import select

from app.database import SessionLocal
from app.models import (
    AccountType,
    Category,
    Conversation,
    Favorite,
    Message,
    Notification,
    Product,
    RecentlyViewed,
    Review,
    SavedSearch,
    SellerFollow,
    SellerProfile,
    User,
    UserRole,
    VerificationStatus,
)
from app.services.security import hash_password

RNG = random.Random(20260728)
NOW = datetime.now(UTC)
CITY = "Casablanca"

CATEGORIES = [
    ("electronics", "Electronics", "Électronique", "إلكترونيات", "devices"),
    ("phones", "Phones", "Téléphones", "هواتف", "smartphone"),
    ("laptops", "Laptops", "Ordinateurs portables", "حاسبات محمولة", "laptop"),
    ("gaming", "Gaming", "Jeux vidéo", "ألعاب", "sports_esports"),
    ("furniture", "Furniture", "Meubles", "أثاث", "chair"),
    ("home", "Home & Garden", "Maison", "المنزل", "home"),
    ("fashion", "Fashion", "Mode", "أزياء", "checkroom"),
    ("watches", "Watches", "Montres", "ساعات", "watch"),
    ("cars", "Cars", "Voitures", "سيارات", "directions_car"),
    ("motorcycles", "Motorcycles", "Motos", "دراجات نارية", "two_wheeler"),
    ("books", "Books", "Livres", "كتب", "menu_book"),
    ("sports", "Sports", "Sport", "رياضة", "sports_soccer"),
    ("instruments", "Musical Instruments", "Instruments", "آلات موسيقية", "music_note"),
    ("cameras", "Cameras", "Appareils photo", "كاميرات", "photo_camera"),
    ("appliances", "Appliances", "Électroménager", "أجهزة منزلية", "kitchen"),
    ("collectibles", "Collectibles", "Collection", "مقتنيات", "diamond"),
]

FIRST = ["Yassine", "Salma", "Amal", "Omar", "Nadia", "Karim", "Imane", "Mehdi", "Lina", "Hassan"]
LAST = ["El Amrani", "Bennani", "Alaoui", "Tazi", "Chraibi", "Fassi", "Zouhair", "Rami"]
NEIGHBORHOODS = ["Maarif", "Gauthier", "Bourgogne", "Racine", "Anfa", "Hay Hassani", "Sidi Maarouf", "Ain Diab"]
IMAGES = [
    "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1503602642458-232111445657?auto=format&fit=crop&w=1200&q=80",
]
PRODUCTS = {
    "electronics": ["Sony WH-1000XM5 headphones", "Nintendo Switch OLED", "JBL Charge 5 speaker"],
    "phones": ["iPhone 13 Pro 256GB", "Samsung Galaxy S23", "Google Pixel 7"],
    "laptops": ["MacBook Air M2", "Lenovo ThinkPad X1 Carbon", "Dell XPS 13"],
    "gaming": ["PlayStation 5 Slim", "Xbox Series X", "Steam Deck OLED"],
    "furniture": ["Walnut coffee table", "Bouclé lounge chair", "Oak dining table"],
    "home": ["Handwoven Moroccan rug", "Ceramic table lamp", "Olive wood mirror"],
    "fashion": ["Leather weekend bag", "Linen blazer", "Vintage denim jacket"],
    "watches": ["Seiko 5 Sports", "Casio G-Shock GA-2100", "Tissot PRX"],
    "cars": ["Renault Clio 2020", "Dacia Duster 2019", "Peugeot 208 2021"],
    "motorcycles": ["Yamaha MT-07", "Honda CB500F", "Vespa Primavera"],
    "books": ["The Atlas of Morocco", "French-Arabic Dictionary", "Designing Data-Intensive Applications"],
    "sports": ["Trek FX 3 bicycle", "Wilson Clash 100 racket", "Adidas Predator boots"],
    "instruments": ["Yamaha acoustic guitar", "Casio digital piano", "Pearl drum set"],
    "cameras": ["Canon EOS R50", "Sony A6400", "Fujifilm X-T30 II"],
    "appliances": ["Nespresso Vertuo", "Dyson V8 vacuum", "Samsung microwave"],
    "collectibles": ["Vintage Casablanca poster", "Moroccan ceramic vase", "Retro film camera"],
}


def uid(kind: str, index: int) -> UUID:
    return uuid5(NAMESPACE_URL, f"margem-demo/{kind}/{index}")


async def seed() -> None:
    async with SessionLocal() as session:
        categories: dict[str, Category] = {}
        for index, (slug, en, fr, ar, icon) in enumerate(CATEGORIES):
            row = (await session.execute(select(Category).where(Category.slug == slug))).scalar_one_or_none()
            if row is None:
                row = Category(id=uid("category", index), slug=slug, name_en=en, name_fr=fr, name_ar=ar, icon=icon)
                session.add(row)
            categories[slug] = row
        await session.flush()

        sellers: list[SellerProfile] = []
        seller_users: list[User] = []
        buyers: list[User] = []
        for i in range(92):
            first, last = FIRST[i % len(FIRST)], LAST[(i // len(FIRST)) % len(LAST)]
            name = f"{first} {last}"
            user = User(
                id=uid("user", i),
                firebase_uid=f"demo-{i}",
                email=f"{first.lower()}.{last.split()[0].lower()}.{i}@margem.demo",
                password_hash=hash_password("MarGemDemo2026!"),
                account_type=AccountType.SELLER if i < 80 else AccountType.BUYER,
                display_name=name,
                email_verified_at=NOW - timedelta(days=RNG.randint(10, 900)),
                role=UserRole.SELLER if i < 80 else UserRole.BUYER,
            )
            user = await session.merge(user)
            if i >= 80:
                buyers.append(user)
                continue
            premium = i % 11 == 0
            verified = i % 4 != 0
            neighborhood = NEIGHBORHOODS[i % len(NEIGHBORHOODS)]
            seller = SellerProfile(
                id=uid("seller", i),
                user_id=user.id,
                business_name=f"{name.split()[0]}'s {CATEGORIES[i % len(CATEGORIES)][1]} Atelier",
                description=f"Curated {CATEGORIES[i % len(CATEGORIES)][1].lower()} in {neighborhood}, Casablanca. Honest photos and quick replies.",
                address=f"{RNG.randint(4, 98)} Rue {neighborhood}",
                city=CITY,
                latitude=33.54 + RNG.random() * 0.08,
                longitude=-7.68 + RNG.random() * 0.08,
                phone=f"+2126{RNG.randint(10000000, 99999999)}",
                cover_image_url=IMAGES[i % len(IMAGES)],
                logo_image_url=IMAGES[(i + 3) % len(IMAGES)],
                average_rating=round(RNG.uniform(3.7, 5.0), 1),
                review_count=RNG.randint(4, 86),
                verification_status=VerificationStatus.VERIFIED if verified else VerificationStatus.UNVERIFIED,
                is_premium=premium,
                favorite_count=RNG.randint(8, 340),
                inquiry_count=RNG.randint(5, 180),
                avg_response_minutes=RNG.randint(4, 75),
                created_at=NOW - timedelta(days=RNG.randint(30, 1000)),
            )
            seller.categories = [categories[CATEGORIES[i % len(CATEGORIES)][0]]]
            sellers.append(await session.merge(seller))
            seller_users.append(user)
        await session.flush()

        products: list[Product] = []
        for i in range(240):
            seller = sellers[i % len(sellers)]
            category = CATEGORIES[i % len(CATEGORIES)][0]
            title = PRODUCTS[category][(i // len(CATEGORIES)) % 3]
            neighborhood = NEIGHBORHOODS[i % len(NEIGHBORHOODS)]
            product = Product(
                id=uid("product", i),
                seller_id=seller.id,
                name=f"{title} — {['excellent condition', 'carefully used', 'like new'][i % 3]}",
                description=f"Authentic {title.lower()} available in {neighborhood}. Inspected, photographed, and ready for pickup or local delivery.",
                price_mad=RNG.randint(180, 18000),
                price_negotiable=i % 3 == 0,
                image_url=IMAGES[i % len(IMAGES)],
                media_urls=[IMAGES[(i + j) % len(IMAGES)] for j in range(1, 4)],
                category_slug=category,
                stock_quantity=RNG.randint(1, 4),
                is_available=i % 17 != 0,
                is_featured=i % 19 == 0,
                created_at=NOW - timedelta(days=RNG.randint(0, 180)),
            )
            products.append(await session.merge(product))
        await session.flush()

        for i in range(320):
            seller = sellers[i % len(sellers)]
            buyer = buyers[(i // len(sellers)) % len(buyers)]
            score = 5 if i % 7 else 3
            review = Review(
                id=uid("review", i),
                seller_id=seller.id,
                buyer_id=buyer.id,
                rating=score,
                product_quality=score,
                customer_service=max(1, min(5, score + (1 if i % 5 else 0))),
                communication=score,
                trustworthiness=score,
                comment=[
                    "Exactly as described and easy to arrange pickup.",
                    "Quick replies and very fair price. Recommended.",
                    "Good item, though delivery took a little longer than expected.",
                    "Professional seller and the photos matched perfectly.",
                ][i % 4],
                created_at=NOW - timedelta(days=RNG.randint(1, 360)),
            )
            await session.merge(review)

        users = seller_users + buyers
        conversation_pairs = [
            (users[left], users[right])
            for left in range(len(users))
            for right in range(left + 1, len(users))
        ]
        for i in range(150):
            a, b = conversation_pairs[i]
            a_id, b_id = sorted([a.id, b.id], key=str)
            conversation = Conversation(
                id=uid("conversation", i),
                participant_a_id=a_id,
                participant_b_id=b_id,
                context_seller_id=sellers[i % len(sellers)].id,
                last_message_at=NOW - timedelta(minutes=i * 7),
            )
            conversation = await session.merge(conversation)
            for j in range(6):
                message = Message(
                    id=uid("message", i * 6 + j),
                    conversation_id=conversation.id,
                    sender_id=a.id if j % 2 == 0 else b.id,
                    body=[
                        "Hello, is this still available?",
                        "Yes, it is available. Would you like more photos?",
                        "Could we meet near the neighborhood this evening?",
                        "That works for me. I can reserve it until 19:00.",
                        "Great, thank you. Is the price negotiable?",
                        "A small offer is possible after you see it.",
                    ][j],
                    read_at=NOW - timedelta(minutes=i * 7 - j) if j < 5 else None,
                    created_at=NOW - timedelta(minutes=i * 7 + (6 - j)),
                )
                await session.merge(message)

        for i in range(120):
            await session.merge(Notification(
                id=uid("notification", i),
                user_id=users[i % len(users)].id,
                title=["New message", "New follower", "Listing favorited", "Review received"][i % 4],
                body=["A buyer asked about your listing.", "Someone started following your shop.", "Your listing is getting attention.", "A customer shared feedback."][i % 4],
                kind=["message", "follow", "favorite", "review"][i % 4],
                created_at=NOW - timedelta(minutes=i * 11),
            ))
        for i in range(60):
            await session.merge(Favorite(id=uid("favorite", i), user_id=buyers[i % len(buyers)].id, product_id=products[i].id, seller_id=products[i].seller_id))
        for i in range(50):
            await session.merge(RecentlyViewed(id=uid("view", i), user_id=buyers[i % len(buyers)].id, seller_id=products[i].seller_id, product_id=products[i].id, viewed_at=NOW - timedelta(hours=i)))
        for i in range(40):
            await session.merge(SavedSearch(id=uid("saved-search", i), user_id=buyers[i % len(buyers)].id, query=PRODUCTS[CATEGORIES[i % len(CATEGORIES)][0]][0].split()[0], city=CITY, category=CATEGORIES[i % len(CATEGORIES)][0]))
        for i in range(100):
            await session.merge(SellerFollow(
                id=uid("follow", i),
                user_id=buyers[(i + i // len(sellers)) % len(buyers)].id,
                seller_id=sellers[i % len(sellers)].id,
            ))

        await session.commit()
        print("Seeded 80 sellers, 240 products, 320 reviews, 150 conversations, 900 messages, 120 notifications.")


if __name__ == "__main__":
    asyncio.run(seed())
