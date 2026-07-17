from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Category, WarningZone
from app.schemas import CategoryOut, WarningZoneOut

router = APIRouter(tags=["catalog"])


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(session: AsyncSession = Depends(get_db)) -> list[Category]:
    result = await session.execute(select(Category).order_by(Category.name_en))
    return list(result.scalars().all())


@router.get("/warning-zones", response_model=list[WarningZoneOut])
async def list_warning_zones(
    city: str | None = None,
    session: AsyncSession = Depends(get_db),
) -> list[WarningZone]:
    stmt = select(WarningZone).where(WarningZone.is_active.is_(True))
    if city:
        stmt = stmt.where(WarningZone.city.ilike(city))
    result = await session.execute(stmt)
    return list(result.scalars().all())
