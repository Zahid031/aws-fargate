from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.hero.models import Hero
from src.modules.hero.schemas import HeroCreate


class HeroRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, data: HeroCreate) -> Hero:
        hero = Hero(**data.model_dump())
        self.session.add(hero)
        await self.session.commit()
        await self.session.refresh(hero)
        return hero

    async def get_all(self, offset: int, limit: int) -> list[Hero]:
        result = await self.session.execute(select(Hero).offset(offset).limit(limit))
        return list(result.scalars().all())

    async def get_by_id(self, hero_id: int) -> Hero | None:
        return await self.session.get(Hero, hero_id)

    async def delete(self, hero: Hero) -> None:
        await self.session.delete(hero)
        await self.session.commit()
